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

# Scena otwierająca — offline. Miejsce startu i tajemnica świata to gotowe
# frazy w mianowniku, więc wchodzą do tekstu jako osobne zdania — doklejanie
# ich w środek zdania brzmiało jak wypełnianie formularza.
func opening(world: Dictionary, character: Dictionary, prof: Dictionary, rng: RandomNumberGenerator) -> String:
	var loc := str(world.get("start_location", "")).strip_edges().rstrip(".")
	if loc == "":
		loc = str(prof["hub"]["name"])
	var tone := str(world.get("tone", "")).strip_edges()
	if tone == "":
		tone = "tajemniczy"
	var when := _period(world)
	var who := "bohaterką" if str(character.get("gender", "")) == "Kobieta" else "bohaterem"
	var lines: Array = []
	lines.append("%s. Właśnie tu zaczyna się opowieść, której %s jesteś ty — %s." % [
		loc, who, character.get("name", "Bohater")])
	lines.append(_pick(rng, prof["ambient"]))
	lines.append("Kronika świata „%s” otwiera się na pierwszej karcie%s. Ton tej opowieści jest %s." % [
		world.get("name", "bez nazwy"), when, tone])
	var goal := str(character.get("goal", "")).strip_edges().rstrip(".")
	if goal != "":
		lines.append("Przywiodło cię tutaj jedno: %s." % goal)
	var mystery := str(world.get("mystery", "")).strip_edges().rstrip(".")
	if mystery != "":
		lines.append("O jednym mówi się tu wyłącznie półgłosem. %s." % mystery)
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
	# Tło sceny tylko co którąś turę — powtarzane za każdym razem szybko
	# zdradzało, że narracja składa się z tych samych klocków.
	if rng.randf() < 0.5:
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

const CLAUDE_DEFAULT_BASE := "https://api.anthropic.com"
const CLAUDE_VERSION := "2023-06-01"
const MAX_HISTORY := 40   # ile ostatnich wpisów kroniki trafia do modelu

func provider() -> String:
	var m := str(Game.settings.get("mode", "offline"))
	if m == "ai":
		return "ollama"   # zgodność ze starszymi zapisami ustawień
	return m

func ai_enabled() -> bool:
	return provider() != "offline"

# Zwraca odpowiedź Mistrza Gry albo pusty string, gdy się nie uda (wtedy
# rozgrywka po cichu wraca do trybu offline). Korutyna — wywołuj przez await.
func ai_generate(world: Dictionary, character: Dictionary, history: Array, roll := {}) -> String:
	var system := _gm_system(world, character)
	var messages := _build_messages(history, roll)
	match provider():
		"claude":
			return await _claude_request(system, messages)
		"ollama":
			return await _ollama_request(system, messages)
	return ""

# Rola Mistrza Gry: świat, postacie niezależne i dialogi — nie sam narrator.
func _gm_system(world: Dictionary, character: Dictionary) -> String:
	var has_mana: bool = Game.world_has_mana()
	var is_female := str(character.get("gender", "")) == "Kobieta"
	var lines := [
		"Jesteś Mistrzem Gry prowadzącym tekstową grę fabularną po polsku. Nie jesteś tylko narratorem — odgrywasz cały świat.",
		"",
		"NAJWAŻNIEJSZE — SŁUCHAJ GRACZA:",
		"- PIERWSZE zdanie odpowiedzi musi dotyczyć dokładnie tego, co gracz zrobił albo powiedział. Rozstrzygnij jego działanie, zanim dopiszesz cokolwiek od siebie.",
		"- Jeśli gracz zadał postaci pytanie, ta postać odpowiada wprost jeszcze w tej samej turze. Nie zbywaj go i nie zmieniaj tematu.",
		"- Jeśli gracz wymienił osobę, miejsce albo przedmiot, odnieś się właśnie do niego. Nigdy nie podmieniaj celu jego działania na inny.",
		"- Nie wprowadzaj nowych wątków, postaci ani zwrotów akcji, dopóki bieżąca scena się nie domknie albo gracz sam nie skręci. Reagujesz na gracza, nie wyprzedzasz go.",
		"",
		"NAZWY WŁASNE — ZASADA BEZWZGLĘDNA:",
		"- Imiona, nazwy miejscowości, przedmiotów i organizacji przepisuj DOKŁADNIE w brzmieniu, w jakim padły. Wolno je wyłącznie odmienić przez przypadki — nigdy nie zmieniaj rdzenia, nie skracaj, nie tłumacz i nie wymyślaj wariantów.",
		"- Przykład: skoro padło „Kazimierz Dolny”, piszesz „Kazimierz Dolny”, „do Kazimierza Dolnego”, „w Kazimierzu Dolnym” — nigdy „Kazimierz nad Wisłą” ani „Kazimierzów”.",
		"- Nie znasz nazwy, której gracz oczekuje? Każ postaci o nią zapytać albo opisz rzecz omownie. Nigdy nie zgaduj i nie wymyślaj nowej.",
		"",
		"JĘZYK I STYL:",
		"- Pisz naturalną, literacką polszczyzną. Bezbłędnie odmieniaj przez przypadki.",
		"- Unikaj powtarzania własnych zwrotów i konstrukcji z poprzednich tur. Dotyczy to stylu — NIE nazw własnych i NIE konkretów podanych przez gracza; te powtarzaj wiernie.",
		"",
		"PROWADZENIE ŚWIATA:",
		"- Twórz postacie niezależne i KAŻDEJ nadawaj imię od razu przy pierwszym pojawieniu (chyba że gracz nazwał ją pierwszy) oraz wyrazisty charakter, własne cele i sekrety.",
		"- Gdy postać mówi, zapisuj wypowiedź w cudzysłowie po imieniu, np.: Marta unosi wzrok znad ksiąg. „Nie powinieneś tu wracać po zmroku.”",
		"- Reaguj wprost na to, co napisał gracz. Decyzje mają konsekwencje, a postacie pamiętają wcześniejsze rozmowy i zachowują się spójnie.",
		"- Nigdy nie decyduj za postać gracza: nie wkładaj jej słów w usta, nie opisuj jej uczuć ani działań, których gracz nie zadeklarował.",
		"- Prowadź narrację w drugiej osobie, konkretnie i zmysłowo. Pisz 2–3 akapity, łącznie najwyżej 180 słów — zwięzłość jest ważniejsza niż rozmach.",
		"- Trzymaj się gatunku, epoki i ustalonych faktów świata.",
		"- Kończ turę czymś, co zaprasza do reakcji: pytaniem postaci, napięciem albo wyborem.",
		"- Gdy przy akcji gracza pojawi się nawias [MECHANIKA GRY — WYNIK RZUTU: …], to gra rozstrzygnęła próbę kością i atrybutami postaci. Ten wynik jest wiążący: opisz jego skutki wiernie, nawet gdy oznacza porażkę bohatera. Nigdy nie ujawniaj w narracji liczb ani samego istnienia rzutu.",
	]
	lines.append("- Postać gracza to %s — konsekwentnie używaj %s form gramatycznych, zwracając się do niej." % [
		"kobieta" if is_female else "mężczyzna",
		"żeńskich" if is_female else "męskich"])
	match str(world.get("mood", "wywazona")):
		"lagodna":
			lines.append("- TON OPOWIEŚCI: łagodny i przygodowy. Świat jest w gruncie rzeczy życzliwy: stawiaj na ciekawość, eksplorację, spotkania, ciepły humor i drobne codzienne zagadki. Zagrożenia są rzadkie i umowne, przemoc ogranicz do minimum. NIE eskaluj napięcia ani nie wprowadzaj nagłej sensacji, dopóki gracz sam wyraźnie jej nie szuka.")
		"mroczna":
			lines.append("- TON OPOWIEŚCI: mroczny i sensacyjny. Stawki są wysokie, zagrożenia realne, a napięcie gęste — od pierwszych scen.")
		_:
			lines.append("- TON OPOWIEŚCI: wyważony. Przeplataj spokojne, ludzkie sceny z momentami napięcia; eskaluj powoli i przede wszystkim w odpowiedzi na decyzje gracza, nie z własnej inicjatywy co turę.")
	if has_mana:
		lines.append("- W tym świecie istnieje nadnaturalna moc. Użycie jej przez gracza kosztuje Manę — uwzględniaj to w bloku stanu.")
	lines.append("")
	lines.append("ŚWIAT „%s” — gatunek: %s; epoka: %s%s; klimat: %s; nadnaturalność: %s; ton: %s." % [
		world.get("name", ""), Genres.label(world.get("genre_key", "fantasy")),
		world.get("era", ""),
		(", rok: " + str(world.get("year", ""))) if str(world.get("year", "")) != "" else "",
		world.get("climate", ""), world.get("supernatural", ""), world.get("tone", "")])
	if str(world.get("mystery", "")).strip_edges() != "":
		lines.append("TŁO FABULARNE: %s" % world.get("mystery", ""))
	var attrs: Dictionary = character.get("attrs", {})
	lines.append("POSTAĆ GRACZA: %s (%s) — %s; cechy: %s; cel: %s; słabość: %s." % [
		character.get("name", ""), character.get("gender", ""), character.get("archetype", ""),
		character.get("traits", ""), character.get("goal", ""), character.get("weakness", "")])
	lines.append("STATYSTYKI GRACZA: poziom %d; Siła %d, Zręczność %d, Intelekt %d, Charyzma %d; Zdrowie %d/%d%s." % [
		int(character.get("level", 1)),
		int(attrs.get("sila", 5)), int(attrs.get("zrecznosc", 5)),
		int(attrs.get("intelekt", 5)), int(attrs.get("charyzma", 5)),
		int(character.get("hp", 100)), int(character.get("hp_max", 100)),
		("; Mana %d/%d" % [int(character.get("mana", 0)), int(character.get("mana_max", 0))]) if has_mana else ""])
	if str(Game.summary).strip_edges() != "":
		lines.append("")
		lines.append("CO BYŁO DO TEJ PORY: %s" % Game.summary)

	# Kanon nazw. Model gubi nazwy własne, gdy widzi je tylko w odległej
	# historii — tutaj dostaje je co turę, w jedynym poprawnym brzmieniu.
	var canon: Array = []
	if not Game.npcs.is_empty():
		# Do kanonu idą postacie widziane najpóźniej, nie pierwsze poznane —
		# przy pełnej bibliotece świeżo poznany kluczowy przeciwnik nie może
		# wypadać z promptu tylko dlatego, że stoi na końcu listy.
		var npc_pool: Array = Game.npcs.duplicate()
		npc_pool.sort_custom(func(a, b):
			return int(a.get("ostatnio", a.get("tura", 0))) > int(b.get("ostatnio", b.get("tura", 0))))
		var known: Array = []
		for n in npc_pool.slice(0, 14):
			var who := str(n.get("imie", ""))
			var role := str(n.get("rola", "")).strip_edges()
			var rel := str(n.get("relacja", "")).strip_edges()
			var st := str(n.get("stan", "")).strip_edges().to_lower()
			if role != "":
				who += " — " + role
			if st != "" and st != "żywy":
				who += " [" + st.to_upper() + "]"
			if rel != "":
				who += " (" + rel + ")"
			known.append(who)
		canon.append("· Postacie: " + "; ".join(known))
	if not Game.locations.is_empty():
		var locs: Array = []
		for l in Game.locations:
			locs.append(str(l.get("name", "")))
		canon.append("· Miejsca: " + "; ".join(locs))
	if not Game.discoveries.is_empty():
		# Jak wyżej: najświeższe odkrycia, nie czternaście najstarszych.
		var ds_pool: Array = Game.discoveries.duplicate()
		ds_pool.sort_custom(func(a, b): return int(a.get("tura", 0)) > int(b.get("tura", 0)))
		var ds: Array = []
		for d in ds_pool.slice(0, 14):
			ds.append(str(d.get("title", "")))
		canon.append("· Przedmioty i odkrycia: " + "; ".join(ds))
	var qs: Array = []
	for q in Game.quests:
		if str(q.get("status", "")).to_lower() != "zamknięty":
			qs.append(str(q.get("title", "")))
	if not qs.is_empty():
		canon.append("· Otwarte wątki: " + "; ".join(qs))
	if not canon.is_empty():
		lines.append("")
		lines.append("KANON — jedyne poprawne brzmienia nazw. Przepisuj je dokładnie tak, jak stoją poniżej (wolno odmieniać przez przypadki). Nie zmieniaj ich, nie wymyślaj wariantów i nie zapominaj o tych osobach:")
		lines.append_array(canon)
	# Pamięć świata. Fakty kluczowe wracają zawsze, zwykłe — te najświeższe.
	# To one sprawiają, że setna tura może wynikać z trzeciej.
	var key_facts: Array = []
	var recent: Array = []
	for f in Game.facts:
		if str(f.get("waga", "")) == "kluczowy":
			key_facts.append("· [tura %d] %s" % [int(f.get("tura", 0)), str(f.get("tresc", ""))])
		else:
			recent.append("· [tura %d] %s" % [int(f.get("tura", 0)), str(f.get("tresc", ""))])
	# Fakty kluczowe wracają do modelu WSZYSTKIE, w każdej turze — obietnica
	# „kluczowy zostaje na zawsze” obejmuje też aktywną pamięć modelu, nie
	# tylko plik zapisu. Górną granicę trzyma _trim_facts() w GameState
	# (łączny limit kroniki), więc lista nie rośnie bez końca.
	if recent.size() > 10:
		recent = recent.slice(recent.size() - 10)
	if not key_facts.is_empty() or not recent.is_empty():
		lines.append("")
		lines.append("PAMIĘĆ ŚWIATA — fakty ustalone wcześniej. Obowiązują nadal i nie wolno im zaprzeczyć. Jeśli scena ich dotyka, oprzyj się na nich zamiast wymyślać na nowo:")
		lines.append_array(key_facts)
		lines.append_array(recent)

	lines.append("")
	lines.append("FORMAT ODPOWIEDZI (bezwzględny): PIERWSZA linia każdej odpowiedzi to blok stanu — jedna linia czystego JSON, bez bloku kodu:")
	lines.append('###STAN {"streszczenie":"Marta, zielarka z Kazimierza Dolnego, przyznała, że list przyszedł ze składu przy Starym Trakcie. Gracz szuka nadawcy; Marta boi się, że ktoś ją obserwuje.","postacie":[{"imie":"Marta","plec":"kobieta","rola":"zielarka","relacja":"nieufna, ale zaciekawiona graczem","stan":"żywy"}],"miejsca":[{"nazwa":"Skład przy Starym Trakcie","opis":"pusty magazyn za miastem"}],"odkrycia":[{"nazwa":"List bez podpisu","rodzaj":"Trop","opis":"znaleziony w piwnicy, bez pieczęci"}],"watki":[{"tytul":"Kto wysłał list","stan":"otwarty"}],"fakty":[{"tresc":"List bez podpisu przyszedł ze składu przy Starym Trakcie; Marta rozpoznała pismo wójta.","waga":"kluczowy"}],"wydarzenia":[{"opis":"Marta przyznała się do znajomości pisma na liście."}],"hp":0,"mana":0,"pd":10,"podpowiedzi":["Zapytaj Martę o list","Rozejrzyj się po składzie","Wróć do gospody na wieczerzę"]}')
	lines.append("Po niej pusta linia, a potem właściwa narracja. Gracz nie widzi bloku — nie wspominaj o nim w tekście.")
	lines.append("- streszczenie: 2–3 zdania streszczające CAŁĄ opowieść od początku — kto, gdzie, co się wydarzyło i co jest teraz stawką. Pisz je od nowa w każdej turze, dopisując najnowsze wydarzenia. Po starszych scenach zostanie tylko to streszczenie, więc nie pomijaj w nim nazw własnych.")
	lines.append("- postacie: WSZYSTKIE postacie niezależne obecne w tej scenie (także wspomniane wcześniej); w polu relacja krótko: aktualne uczucia i powiązania z graczem; w polu stan: „żywy”, „ranny”, „martwy” albo „zaginiony”.")
	lines.append("- miejsca: TYLKO miejsca, które pojawiły się albo zmieniły w tej turze — nazwa dokładnie tak, jak brzmi w opowieści, plus pół zdania opisu. Nie powtarzaj miejsc już znanych z KANONU.")
	lines.append("- odkrycia: TYLKO przedmioty, tropy i informacje zdobyte w tej turze; rodzaj to „Przedmiot”, „Trop” albo „Wiedza”; w opisie gdzie znaleziono i co to znaczy.")
	lines.append("- watki: otwarte wątki fabularne — krótki tytuł i stan („otwarty” albo „zamknięty”). Wątek domknięty w tej turze oznacz jako zamknięty.")
	lines.append("- fakty: prawdy o świecie ustalone w tej turze, które mają obowiązywać DO KOŃCA opowieści — kto kim naprawdę jest, kto kogo zdradził, co oznacza znaleziony przedmiot, co się nieodwracalnie stało. Pisz pełnym zdaniem, z nazwami własnymi. Waga „kluczowy” dla zwrotów akcji i tajemnic, „zwykly” dla reszty. Nie powtarzaj faktów, które już są w PAMIĘCI ŚWIATA.")
	lines.append("- wydarzenia: jedno zdanie podsumowujące, co wydarzyło się w tej turze — wpis do osi czasu.")
	lines.append("- Puste pola zostawiaj jako puste listy. Nie wymyślaj wpisów na siłę — Kronika ma zawierać wyłącznie to, co naprawdę padło w opowieści.")
	lines.append("- hp: zmiana Zdrowia gracza w tej turze (ujemna przy obrażeniach; zwykle 0).")
	lines.append("- mana: zmiana Many gracza (ujemna przy użyciu mocy%s)." % ("" if has_mana else "; w tym świecie zawsze 0"))
	lines.append("- pd: punkty doświadczenia za tę turę — 5–15 za zwykłe działania, do 30 za brawurowe, sprytne lub przełomowe.")
	lines.append("- podpowiedzi: dokładnie 3 krótkie (do 8 słów) propozycje następnego ruchu gracza, w trybie rozkazującym, ściśle wynikające z bieżącej sceny — sensowne, różnorodne opcje, nie oczywistości.")
	return "\n".join(lines)

# Wycina blok ###STAN z odpowiedzi modelu. Model bywa nieposłuszny: potrafi
# wstawić blok na końcu, opakować go w ```json, rozbić JSON na wiele linii albo
# pominąć sam znacznik. Szukamy więc pierwszego nawiasu klamrowego i czytamy
# zbalansowany obiekt, licząc klamry z pominięciem tych wewnątrz napisów.
# Zwraca {text, state}.
func parse_state(text: String) -> Dictionary:
	var marker := text.find("###STAN")
	var from := marker + 7 if marker != -1 else 0
	var open_brace := text.find("{", from)
	if open_brace == -1:
		return {"text": _clean_fences(text), "state": {}}
	# Bez znacznika ufamy tylko blokowi na samym początku odpowiedzi —
	# inaczej wzięlibyśmy klamrę z treści opowieści.
	if marker == -1 and text.substr(0, open_brace).strip_edges().replace("`", "").replace("json", "") != "":
		return {"text": _clean_fences(text), "state": {}}
	var close_brace := _match_brace(text, open_brace)
	if close_brace == -1:
		return {"text": _clean_fences(text), "state": {}}
	var parsed = JSON.parse_string(text.substr(open_brace, close_brace - open_brace + 1))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"text": _clean_fences(text), "state": {}}
	var cut_from := marker if marker != -1 else open_brace
	var rest := text.substr(close_brace + 1)
	return {"text": _clean_fences(text.substr(0, cut_from) + rest), "state": parsed}

# Indeks klamry zamykającej obiekt zaczynający się w „start”, albo -1.
func _match_brace(t: String, start: int) -> int:
	var depth := 0
	var in_str := false
	var escaped := false
	for i in range(start, t.length()):
		var c := t[i]
		if in_str:
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == "\"":
				in_str = false
			continue
		if c == "\"":
			in_str = true
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return i
	return -1

# Usuwa resztki ogrodzeń kodu, gdy model opakował blok w ```.
func _clean_fences(t: String) -> String:
	var out := ""
	for line in t.split("\n"):
		var trimmed := str(line).strip_edges()
		if trimmed == "```" or trimmed == "```json":
			continue
		out += str(line) + "\n"
	return out.strip_edges()

# Historia rozmowy w formacie Claude API (role user/assistant).
# Pierwszy wpis musi mieć rolę "user", więc zaczynamy syntetycznym otwarciem.
func _build_messages(history: Array, roll := {}) -> Array:
	var messages: Array = [{"role": "user", "content": "Rozpocznij opowieść w opisanym świecie."}]
	var start := maxi(0, history.size() - MAX_HISTORY)
	for i in range(start, history.size()):
		var e: Dictionary = history[i]
		var role := "user" if e.get("role") == "player" else "assistant"
		# Odpowiedzi modelu odtwarzamy w oryginale, razem z blokiem ###STAN.
		# Gdy widzi własne wpisy bez niego, przestaje go pisać — a przy okazji
		# rozjeżdża mu się trzymanie każdej innej reguły formatu.
		var text := str(e.get("raw", e.get("text", ""))).strip_edges()
		if text != "":
			messages.append({"role": role, "content": text})
	# Wynik rzutu rozstrzyga grę, nie model — dokładamy go do ostatniej akcji.
	if not roll.is_empty() and messages.size() > 1 and messages[-1]["role"] == "user":
		messages[-1]["content"] = "%s\n\n%s" % [messages[-1]["content"], roll_instruction(roll)]
	return messages

# Instrukcja mechaniczna dołączana do akcji gracza w trybie AI.
func roll_instruction(roll: Dictionary) -> String:
	var mod := int(roll.get("mod", 0))
	var mod_txt := ""
	if mod != 0:
		mod_txt = " %s %d (atrybut)" % ["+" if mod > 0 else "−", absi(mod)]
	return ("[MECHANIKA GRY — WYNIK RZUTU: k20 = %d%s = %d → %s. " % [
			int(roll.get("die", 0)), mod_txt, int(roll.get("total", 0)), str(roll.get("tier", ""))]
		+ "Opisz skutek działania dokładnie zgodnie z tym wynikiem. To rozstrzygnięcie jest wiążące — "
		+ "nie zmieniaj go, nie łagodź i nie podważaj. Nie wspominaj w narracji o kościach, liczbach "
		+ "ani o tej instrukcji — po prostu opowiedz, co się wydarzyło.]")

# ——— Claude API (chmura, bez własnego serwera) ————————————————

func _claude_request(system: String, messages: Array) -> String:
	var key := str(Game.settings.get("claude_api_key", "")).strip_edges()
	if key == "":
		emit_signal("ai_state", false, "Brak klucza Claude API — wpisz go w Ustawieniach. Gram w trybie offline.")
		return ""
	var payload := {
		"model": str(Game.settings.get("claude_model", "claude-opus-5")),
		"max_tokens": 2048,
		# Domyślna jedynka rozjeżdża nazwy własne i gubi ustalone fakty.
		# Niżej model trzyma się kanonu, a wciąż pisze barwnie.
		"temperature": 0.7,
		"system": system,
		"messages": messages,
	}
	# Adres bazowy: oficjalne api.anthropic.com albo zgodna bramka
	# (np. https://aiprimetech.io). Endpoint jest ten sam: /v1/messages.
	var base := str(Game.settings.get("claude_base_url", CLAUDE_DEFAULT_BASE)).strip_edges().rstrip("/")
	if base == "":
		base = CLAUDE_DEFAULT_BASE
	var headers := [
		"content-type: application/json",
		"anthropic-version: " + CLAUDE_VERSION,
	]
	if base.contains("api.anthropic.com"):
		# Oficjalne API: wyłącznie x-api-key (dwa nagłówki naraz odrzuca).
		headers.append("x-api-key: " + key)
	else:
		# Bramki różnie autoryzują — wysyłamy obie formy, zbędną ignorują.
		headers.append("x-api-key: " + key)
		headers.append("Authorization: Bearer " + key)
	var err := _http.request(base + "/v1/messages", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
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
	if str(parsed.get("stop_reason", "")) == "max_tokens":
		emit_signal("ai_state", false, "Odpowiedź Mistrza Gry urwała się na limicie długości.")
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

# ——— Test połączenia z Claude API (tylko wersja deweloperska) ————————
#
# Narzędzie deweloperskie. Przycisk, który je wywołuje, powstaje w ustawieniach
# tylko przy OS.is_debug_build(), więc w wyeksportowanej grze jest nieosiągalny.
# Wysyła minimalne zapytanie i zwraca {ok: bool, note: String}.
func dev_test_claude(key: String, base: String, model: String) -> Dictionary:
	key = key.strip_edges()
	base = base.strip_edges().rstrip("/")
	if base == "":
		base = CLAUDE_DEFAULT_BASE
	if key == "":
		return {"ok": false, "note": "Wpisz najpierw klucz API."}
	model = model.strip_edges()
	if model == "":
		model = "claude-opus-5"

	# Osobny HTTPRequest, żeby test nie kolidował z turą rozgrywki.
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	var payload := {
		"model": model,
		"max_tokens": 24,
		"messages": [{"role": "user", "content": "Odpowiedz dokładnie jednym słowem: OK"}],
	}
	var headers := [
		"content-type: application/json",
		"anthropic-version: " + CLAUDE_VERSION,
		"x-api-key: " + key,
	]
	if not base.contains("api.anthropic.com"):
		headers.append("Authorization: Bearer " + key)
	var err := http.request(base + "/v1/messages", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http.queue_free()
		return {"ok": false, "note": "Nie udało się wysłać zapytania — sprawdź adres API."}
	var res: Array = await http.request_completed
	http.queue_free()
	var result := int(res[0])
	var code := int(res[1])
	var body := (res[3] as PackedByteArray).get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "note": "Brak odpowiedzi serwera — sprawdź adres API i połączenie z internetem."}
	if code == 200:
		var parsed = JSON.parse_string(body)
		if typeof(parsed) == TYPE_DICTIONARY:
			var out := ""
			for b in parsed.get("content", []):
				if typeof(b) == TYPE_DICTIONARY and b.get("type") == "text":
					out += str(b.get("text", ""))
			var served := str(parsed.get("model", model))
			return {"ok": true, "note": "Połączenie działa ✓  Model %s odpowiedział: „%s”" % [served, out.strip_edges().left(40)]}
		return {"ok": true, "note": "Połączenie działa ✓ (kod 200)"}

	var msg := ""
	var parsed_err = JSON.parse_string(body)
	if typeof(parsed_err) == TYPE_DICTIONARY:
		var e = parsed_err.get("error", {})
		if typeof(e) == TYPE_DICTIONARY:
			msg = str(e.get("message", ""))
	if msg == "":
		msg = body.left(120)
	var hint := ""
	match code:
		401: hint = " (klucz odrzucony — sprawdź go)"
		403: hint = " (brak uprawnień — sprawdź konto/saldo)"
		404: hint = " (zły adres API albo nieznany model)"
		429: hint = " (limit zapytań — spróbuj za chwilę)"
	return {"ok": false, "note": "Błąd %d%s. %s" % [code, hint, msg.left(160)]}

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
		"options": {"temperature": 0.7}}
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
