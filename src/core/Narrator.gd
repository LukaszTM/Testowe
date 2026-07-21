extends Node

# Silnik narracji. Domyślnie działa w trybie OFFLINE (darmowym): składa sceny
# proceduralnie ze słownictwa profilu gatunkowego, dorzucając rzut kością, który
# nadaje działaniom stawkę. Opcjonalnie potrafi rozmawiać z lokalnym modelem
# językowym (Ollama) w trybie ONLINE — jeśli jest dostępny, inaczej cichy fallback.

signal ai_state(available: bool, note: String)

var _http: HTTPRequest

# Słowa kluczowe klasyfikujące swobodny opis akcji gracza.
const LOOK := ["rozglą", "obserw", "szuka", "badam", "sprawdz", "przygląd", "nasłuch",
	"patrz", "zaglądam", "analiz", "wypatr", "czytam", "przeszuk", "prześled"]
const TALK := ["pyta", "mówię", "mowie", "rozmaw", "zagad", "krzycz", "proszę", "prosze",
	"negocj", "przekonuj", "odpowiadam", "szept", "wołam", "wolam", "gadam", "wypyt", "targ"]
const MOVE := ["idę", "ide", "biegn", "wchodzę", "wchodze", "podchodzę", "skradam", "uciek",
	"cofam", "ruszam", "wspina", "przeskak", "jadę", "jade", "schodzę", "wychodzę",
	"chowam", "ukry", "przemyk", "wyrusz", "wsiad", "zejd", "przejd"]
const FIGHT := ["atak", "uderz", "walcz", "strzel", "ciosem", "dobywam", "tnę", "bronię",
	"bronie", "cios", "rzucam się", "duszę", "kopn", "wyrywam", "napieram", "naciśn", "naciskam"]

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

# ——— Tryb offline: rzut kością ———————————————————————————————

# Zwraca {die, mod, total, tier, tier_label, prefix}.
func roll_action(rng: RandomNumberGenerator, modifier := 0) -> Dictionary:
	var die := rng.randi_range(1, 20)
	var total := die + modifier
	var tier := ""
	var prefix := ""
	if die == 1:
		tier = "krytyczna porażka"
		prefix = "Wszystko idzie gorzej, niż powinno — drobny błąd zamienia się w problem, którego nie da się już zignorować."
	elif die == 20:
		tier = "krytyczny sukces"
		prefix = "Udaje się ponad oczekiwania; przez chwilę los wyraźnie sprzyja właśnie tobie."
	elif total >= 15:
		tier = "sukces"
		prefix = "Działanie przynosi efekt i sytuacja przesuwa się na twoją korzyść."
	elif total >= 9:
		tier = "częściowy sukces"
		prefix = "Osiągasz część celu, ale cena okazuje się odczuwalna."
	else:
		tier = "niepowodzenie"
		prefix = "Próba nie wychodzi tak, jak planowano — pojawia się komplikacja."
	return {"die": die, "mod": modifier, "total": total, "tier": tier, "prefix": prefix}

func classify(action: String) -> String:
	var s := action.to_lower()
	for w in LOOK:
		if s.contains(w): return "look"
	for w in TALK:
		if s.contains(w): return "talk"
	for w in FIGHT:
		if s.contains(w): return "fight"
	for w in MOVE:
		if s.contains(w): return "move"
	return "filler"

func _pick(rng: RandomNumberGenerator, pool: Array) -> String:
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]

# Scena otwierająca — offline.
func opening(world: Dictionary, character: Dictionary, prof: Dictionary, rng: RandomNumberGenerator) -> String:
	var loc := str(world.get("start_location", "")).strip_edges()
	if loc == "":
		loc = prof["hub"]["name"]
	var tone := str(world.get("tone", "")).strip_edges()
	if tone == "":
		tone = "tajemniczy"
	var when := _period(world)
	var lines: Array = []
	lines.append("%s stoi w miejscu, które nazwano tak: %s." % [character.get("name", "Bohater"), loc])
	lines.append(_pick(rng, prof["ambient"]))
	var intro := "To początek opowieści w świecie „%s” (%s)%s. Ton jest %s." % [
		world.get("name", "bez nazwy"), prof["label"], when, tone]
	lines.append(intro)
	var goal := str(character.get("goal", "")).strip_edges()
	if goal != "":
		lines.append("Kieruje tobą jedno: %s." % goal)
	var mystery := str(world.get("mystery", "")).strip_edges()
	if mystery != "":
		lines.append("Tuż obok pojawia się pierwszy szczegół, który może być tropem — jego cień pada wprost na główną tajemnicę: %s." % mystery)
	lines.append(_pick(rng, Genres.CLOSERS))
	return "\n\n".join(lines)

# Odpowiedź na akcję gracza — offline.
func respond(world: Dictionary, character: Dictionary, prof: Dictionary,
		action: String, roll: Dictionary, rng: RandomNumberGenerator) -> String:
	var kind := classify(action)
	var pool: Array = prof.get(kind, prof["filler"])
	var parts: Array = []
	if roll.has("prefix") and roll["prefix"] != "":
		parts.append(roll["prefix"])
	var body := _pick(rng, pool)
	if body != "":
		parts.append(body)
	parts.append(_pick(rng, prof["ambient"]))
	var out := " ".join(parts).strip_edges()
	if out == "":
		out = "%s działa dalej, a świat reaguje na ten ruch." % character.get("name", "Bohater")
	return out + " " + _pick(rng, Genres.CLOSERS)

func _period(world: Dictionary) -> String:
	var era := str(world.get("era", "")).strip_edges()
	var year := str(world.get("year", "")).strip_edges()
	if era != "" and year != "":
		return " — %s, %s" % [era, year]
	if era != "":
		return " — %s" % era
	if year != "":
		return " — %s" % year
	return ""

# ——— Tryb online: lokalny model (Ollama) ————————————————————

func ai_enabled() -> bool:
	return Game.settings.get("mode", "offline") == "ai"

# Zwraca tekst narracji z modelu AI albo pusty string, gdy się nie uda.
# Funkcja jest korutyną (await), więc ekran gry wywołuje ją jednolicie.
func ai_generate(prompt: String) -> String:
	var host := str(Game.settings.get("ai_host", "http://localhost:11434"))
	var model := str(Game.settings.get("ai_model", "bielik"))
	var url := host.rstrip("/") + "/api/generate"
	var payload := {"model": model, "prompt": prompt, "stream": false,
		"options": {"temperature": 0.9}}
	var headers := ["Content-Type: application/json"]
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("ai_state", false, "Nie udało się połączyć z modelem — przełączam na tryb offline.")
		return ""
	var res: Array = await _http.request_completed
	# res = [result, response_code, headers, body]
	if int(res[1]) != 200:
		emit_signal("ai_state", false, "Model odpowiedział błędem %d — używam trybu offline." % int(res[1]))
		return ""
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("response"):
		emit_signal("ai_state", true, "Narrację prowadzi model „%s”." % model)
		return str(parsed["response"]).strip_edges()
	emit_signal("ai_state", false, "Nieczytelna odpowiedź modelu — tryb offline.")
	return ""

# Buduje polecenie dla modelu z kontekstu świata, postaci i ostatnich wersów.
func build_prompt(world: Dictionary, character: Dictionary, history: Array, action: String) -> String:
	var recent: Array = []
	var start := maxi(0, history.size() - 6)
	for i in range(start, history.size()):
		var e: Dictionary = history[i]
		var who := "GRACZ" if e.get("role") == "player" else "NARRATOR"
		recent.append("%s: %s" % [who, e.get("text", "")])
	var sys := """Jesteś Mistrzem Gry w tekstowej grze fabularnej. Prowadź narrację po polsku,
w drugiej osobie, żywo i konkretnie. Nie decyduj za gracza. Zakończ pytaniem o jego kolejny ruch.
Trzymaj się konwencji świata i nie łam ustalonych realiów."""
	var setting := "ŚWIAT: %s | gatunek: %s | epoka: %s | rok: %s | ton: %s | tajemnica: %s" % [
		world.get("name", ""), Genres.label(world.get("genre_key", "fantasy")),
		world.get("era", ""), world.get("year", ""), world.get("tone", ""), world.get("mystery", "")]
	var hero := "POSTAĆ: %s — %s | cel: %s | słabość: %s" % [
		character.get("name", ""), character.get("archetype", ""),
		character.get("goal", ""), character.get("weakness", "")]
	return "%s\n\n%s\n%s\n\nDOTYCHCZAS:\n%s\n\nGRACZ: %s\n\nNARRATOR:" % [
		sys, setting, hero, "\n".join(recent), action]
