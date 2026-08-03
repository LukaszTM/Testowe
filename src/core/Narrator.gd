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
	_http.timeout = 90.0
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

# ——— Tryb online: Mistrz Gry (Claude API w chmurze albo lokalna Ollama) ———
#
# Claude API to usługa hostowana przez Anthropic (api.anthropic.com) — nie
# wymaga żadnego serwera po stronie gracza i działa niezależnie od jego
# komputera. Potrzebny jest tylko klucz API (platform.claude.com).

const CLAUDE_URL := "https://api.anthropic.com/v1/messages"
const CLAUDE_VERSION := "2023-06-01"
const MAX_HISTORY := 30   # ile ostatnich wpisów kroniki trafia do modelu

func provider() -> String:
	var m := str(Game.settings.get("mode", "offline"))
	if m == "ai":
		return "ollama"   # zgodność ze starszymi zapisami ustawień
	return m

func ai_enabled() -> bool:
	return provider() != "offline"

# Zwraca odpowiedź Mistrza Gry albo pusty string, gdy się nie uda (wtedy
# rozgrywka po cichu wraca do trybu offline). Korutyna — wywołuj przez await.
func ai_generate(world: Dictionary, character: Dictionary, history: Array) -> String:
	var system := _gm_system(world, character)
	var messages := _build_messages(history)
	match provider():
		"claude":
			return await _claude_request(system, messages)
		"ollama":
			return await _ollama_request(system, messages)
	return ""

# Rola Mistrza Gry: świat, postacie niezależne i dialogi — nie sam narrator.
func _gm_system(world: Dictionary, character: Dictionary) -> String:
	var lines := [
		"Jesteś Mistrzem Gry prowadzącym tekstową grę fabularną po polsku. Nie jesteś tylko narratorem — odgrywasz cały świat:",
		"- Twórz i odgrywaj postacie niezależne: nadawaj im imiona, charaktery, własne cele i sekrety. Wprowadzaj je aktywnie do scen.",
		"- Gdy postać mówi, zapisuj jej wypowiedź w cudzysłowie po imieniu, np.: Marta unosi wzrok znad ksiąg. „Nie powinieneś tu wracać po zmroku.”",
		"- Reaguj wprost na to, co napisał gracz. Jego decyzje mają konsekwencje, a postacie pamiętają wcześniejsze rozmowy i zachowują się spójnie.",
		"- Nigdy nie decyduj za postać gracza: nie wkładaj jej słów w usta, nie opisuj jej uczuć ani działań, których gracz nie zadeklarował.",
		"- Prowadź narrację w drugiej osobie, konkretnie i zmysłowo. Pisz 2–4 krótkie akapity na turę.",
		"- Trzymaj się gatunku, epoki i ustalonych faktów świata. Główną tajemnicę odsłaniaj powoli, trop po tropie.",
		"- Kończ turę czymś, co zaprasza do reakcji: pytaniem postaci, napięciem albo wyborem — niekoniecznie wprost pytaniem do gracza.",
	]
	lines.append("")
	lines.append("ŚWIAT „%s” — gatunek: %s; epoka: %s%s; klimat: %s; nadnaturalność: %s; ton: %s." % [
		world.get("name", ""), Genres.label(world.get("genre_key", "fantasy")),
		world.get("era", ""),
		(", rok: " + str(world.get("year", ""))) if str(world.get("year", "")) != "" else "",
		world.get("climate", ""), world.get("supernatural", ""), world.get("tone", "")])
	lines.append("GŁÓWNA TAJEMNICA: %s" % world.get("mystery", ""))
	lines.append("POSTAĆ GRACZA: %s — %s; cechy: %s; cel: %s; słabość: %s." % [
		character.get("name", ""), character.get("archetype", ""),
		character.get("traits", ""), character.get("goal", ""), character.get("weakness", "")])
	if not Game.locations.is_empty():
		var locs: Array = []
		for l in Game.locations:
			locs.append(str(l.get("name", "")))
		lines.append("ZNANE MIEJSCA: %s." % ", ".join(locs))
	if not Game.quests.is_empty():
		var qs: Array = []
		for q in Game.quests:
			qs.append(str(q.get("title", "")))
		lines.append("OTWARTE WĄTKI: %s." % ", ".join(qs))
	return "\n".join(lines)

# Historia rozmowy w formacie Claude API (role user/assistant).
# Pierwszy wpis musi mieć rolę "user", więc zaczynamy syntetycznym otwarciem.
func _build_messages(history: Array) -> Array:
	var messages: Array = [{"role": "user", "content": "Rozpocznij opowieść w opisanym świecie."}]
	var start := maxi(0, history.size() - MAX_HISTORY)
	for i in range(start, history.size()):
		var e: Dictionary = history[i]
		var role := "user" if e.get("role") == "player" else "assistant"
		var text := str(e.get("text", "")).strip_edges()
		if text != "":
			messages.append({"role": role, "content": text})
	return messages

# ——— Claude API (chmura, bez własnego serwera) ————————————————

func _claude_request(system: String, messages: Array) -> String:
	var key := str(Game.settings.get("claude_api_key", "")).strip_edges()
	if key == "":
		emit_signal("ai_state", false, "Brak klucza Claude API — wpisz go w Ustawieniach. Gram w trybie offline.")
		return ""
	var payload := {
		"model": str(Game.settings.get("claude_model", "claude-opus-5")),
		"max_tokens": 1024,
		"system": system,
		"messages": messages,
	}
	var headers := [
		"content-type: application/json",
		"x-api-key: " + key,
		"anthropic-version: " + CLAUDE_VERSION,
	]
	var err := _http.request(CLAUDE_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("ai_state", false, "Nie udało się połączyć z Claude API — tryb offline.")
		return ""
	var res: Array = await _http.request_completed
	var code := int(res[1])
	var body := (res[3] as PackedByteArray).get_string_from_utf8()
	if code == 401:
		emit_signal("ai_state", false, "Claude API odrzuciło klucz (401) — sprawdź go w Ustawieniach.")
		return ""
	if code == 429:
		emit_signal("ai_state", false, "Limit zapytań Claude API (429) — spróbuj za chwilę.")
		return ""
	if code != 200:
		emit_signal("ai_state", false, "Claude API zwróciło błąd %d — tryb offline." % code)
		return ""
	var parsed = JSON.parse_string(body)
	if typeof(parsed) != TYPE_DICTIONARY:
		emit_signal("ai_state", false, "Nieczytelna odpowiedź Claude API — tryb offline.")
		return ""
	if str(parsed.get("stop_reason", "")) == "refusal":
		emit_signal("ai_state", false, "Model odmówił odpowiedzi na tę akcję — tryb offline dla tej tury.")
		return ""
	var out := ""
	for block in parsed.get("content", []):
		if typeof(block) == TYPE_DICTIONARY and block.get("type") == "text":
			out += str(block.get("text", ""))
	out = out.strip_edges()
	if out != "":
		emit_signal("ai_state", true, "Mistrz Gry: Claude (chmura)")
	return out

# ——— Ollama (model lokalny na komputerze gracza) ———————————————

func _ollama_request(system: String, messages: Array) -> String:
	var host := str(Game.settings.get("ai_host", "http://localhost:11434"))
	var model := str(Game.settings.get("ai_model", "bielik"))
	var flat: Array = []
	for m in messages:
		var who := "GRACZ" if m.get("role") == "user" else "MISTRZ GRY"
		flat.append("%s: %s" % [who, m.get("content", "")])
	var prompt := "%s\n\nDOTYCHCZAS:\n%s\n\nMISTRZ GRY:" % [system, "\n".join(flat)]
	var payload := {"model": model, "prompt": prompt, "stream": false,
		"options": {"temperature": 0.9}}
	var err := _http.request(host.rstrip("/") + "/api/generate",
		["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		emit_signal("ai_state", false, "Nie udało się połączyć z Ollamą — tryb offline.")
		return ""
	var res: Array = await _http.request_completed
	if int(res[1]) != 200:
		emit_signal("ai_state", false, "Ollama zwróciła błąd %d — tryb offline." % int(res[1]))
		return ""
	var parsed = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("response"):
		emit_signal("ai_state", true, "Mistrz Gry: %s (lokalnie)" % model)
		return str(parsed["response"]).strip_edges()
	emit_signal("ai_state", false, "Nieczytelna odpowiedź Ollamy — tryb offline.")
	return ""
