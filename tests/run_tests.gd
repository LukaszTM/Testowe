extends SceneTree

# Testy jednostkowe Kronikarza. Uruchomienie bez okna gry:
#
#     godot --headless --script tests/run_tests.gd
#
# Kod wyjścia 0 = wszystko przeszło, 1 = są błędy (nadaje się do CI).
# Testy celują w miejsca, w których cicha usterka jest najbardziej kosztowna:
# parser odpowiedzi modelu, zapis i wczytanie kroniki, rozwój postaci
# oraz migracja starych zapisów.

var _passed := 0
var _failed := 0
var _done := false

# MainLoop._process pierwszej klatki: autoloady (Game, Narrator, Saves) są już
# w drzewie. W _init() jeszcze ich nie ma.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	print("\n=== Kronikarz — testy ===\n")
	if root.get_node_or_null("Game") == null:
		push_error("Autoload Game niedostępny — uruchom z katalogu projektu.")
		quit(1)
		return
	_test_parser()
	_test_rng_state()
	_test_save_roundtrip()
	_test_migration()
	_test_progression()
	_test_chronicle_merge()
	_test_state_block()
	_test_prompt_memory()
	_test_intro()
	print("\n=== %d przeszło, %d nie przeszło ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

# ——— Narzędzia ————————————————————————————————————————————

func check(name: String, condition: bool, detail := "") -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % name)
	else:
		_failed += 1
		print("  ✗ %s %s" % [name, detail])

func eq(name: String, got, want) -> void:
	check(name, got == want, "— dostałem %s, oczekiwałem %s" % [str(got), str(want)])

# ——— Parser bloku stanu ————————————————————————————————————
# Model bywa nieposłuszny: wstawia blok na końcu, opakowuje w ``` albo rozbija
# JSON na linie. Każdy taki przypadek musi dać ten sam wynik.

func _test_parser() -> void:
	print("Parser ###STAN")
	var cases := [
		["blok na początku", "###STAN {\"pd\":10}\n\nRuszasz przed siebie.", 10, "Ruszasz przed siebie."],
		["JSON w wielu liniach", "###STAN {\n \"pd\": 12,\n \"postacie\": []\n}\n\nMarta milczy.", 12, "Marta milczy."],
		["opakowany w ```json", "```json\n###STAN {\"pd\":7}\n```\n\nDrzwi skrzypią.", 7, "Drzwi skrzypią."],
		["blok na końcu", "Wchodzisz do środka.\n\n###STAN {\"pd\":5}", 5, "Wchodzisz do środka."],
		["bez znacznika", "{\"pd\":9}\n\nCisza.", 9, "Cisza."],
		["klamra w narracji", "###STAN {\"pd\":3}\n\nNa ścianie znak {X}.", 3, "Na ścianie znak {X}."],
	]
	for c in cases:
		var r := Narrator.parse_state(str(c[1]))
		var state: Dictionary = r["state"]
		eq("%s — pd" % c[0], int(state.get("pd", -1)), int(c[2]))
		eq("%s — tekst" % c[0], str(r["text"]), str(c[3]))

	var none := Narrator.parse_state("Sam opis, bez stanu.")
	check("brak bloku zwraca pusty stan", (none["state"] as Dictionary).is_empty())
	eq("brak bloku nie rusza tekstu", str(none["text"]), "Sam opis, bez stanu.")

	var broken := Narrator.parse_state("###STAN {\"pd\":brak}\n\nTekst mimo wszystko.")
	check("uszkodzony JSON nie wywala parsera", (broken["state"] as Dictionary).is_empty())

	var loose := Narrator.parse_state("Widzisz napis {tajne} na drzwiach.")
	check("klamra w opowieści nie udaje bloku stanu", (loose["state"] as Dictionary).is_empty())

# ——— Stan generatora losowego ————————————————————————————————
# Zapis samego ziarna sprawiał, że po wczytaniu rzuty powtarzały wcześniejszą
# sekwencję. Zapisujemy pozycję generatora, nie tylko ziarno.

func _test_rng_state() -> void:
	print("\nGenerator losowy")
	var a := RandomNumberGenerator.new()
	a.seed = 12345
	for i in 20:
		a.randi_range(1, 20)
	var saved := a.state
	var next_expected := a.randi_range(1, 20)

	var b := RandomNumberGenerator.new()
	b.seed = 12345
	b.state = saved
	eq("wczytany generator kontynuuje sekwencję", b.randi_range(1, 20), next_expected)

	# Dla porównania: samo ziarno cofa generator na początek sekwencji —
	# tak działał zapis w 3.4 i dlatego rzuty po wczytaniu się powtarzały.
	var c := RandomNumberGenerator.new()
	c.seed = 12345
	a.seed = 12345
	eq("samo ziarno wraca na początek sekwencji", c.randi_range(1, 20), a.randi_range(1, 20))

# ——— Zapis i wczytanie kroniki ————————————————————————————————

func _test_save_roundtrip() -> void:
	print("\nZapis i wczytanie")
	Game.world = {"name": "Popioły Marchii", "genre_key": "fantasy", "supernatural": "pełna magia"}
	Game.character = {"name": "Halina Grot", "gender": "Kobieta", "archetype": "zielarka"}
	Game.ensure_character_stats()
	Game.recompute_maxima()
	Game.turn = 42
	Game.summary = "Halina szuka nadawcy listu."
	Game.facts = [{"tresc": "Wójt współpracuje z kultem.", "waga": "kluczowy", "tura": 17}]
	Game.events = [{"opis": "Marta przyznała się do znajomości pisma.", "tura": 17}]
	Game.npcs = [{"imie": "Marta", "plec": "kobieta", "rola": "zielarka",
		"relacja": "nieufna", "stan": "żywy", "tura": 3, "ostatnio": 17}]
	Game.rng.seed = 999
	for i in 5:
		Game.rng.randi()
	# Zapis powstaje TERAZ; expected_next to liczba, która wypadnie zaraz po nim.
	var snapshot := Game.to_dict()
	var expected_next := Game.rng.randi()
	# Psujemy stan, żeby mieć pewność, że wczytanie naprawdę go odbudowuje.
	Game.world = {}
	Game.character = {}
	Game.facts = []
	Game.events = []
	Game.npcs = []
	Game.turn = 0
	Game.summary = ""
	Game.from_dict(snapshot)

	eq("nazwa świata", str(Game.world.get("name", "")), "Popioły Marchii")
	eq("imię bohaterki", str(Game.character.get("name", "")), "Halina Grot")
	eq("numer tury", Game.turn, 42)
	eq("streszczenie", Game.summary, "Halina szuka nadawcy listu.")
	eq("liczba faktów", Game.facts.size(), 1)
	eq("waga faktu", str(Game.facts[0].get("waga", "")), "kluczowy")
	eq("oś czasu", Game.events.size(), 1)
	eq("postać w bibliotece", str(Game.npcs[0].get("imie", "")), "Marta")
	eq("wersja zapisu", int(snapshot.get("version", 0)), Game.SAVE_VERSION)
	check("zapis niesie stan generatora", str(snapshot.get("rng_state", "")) != "")
	# Po odtworzeniu stanu kolejny rzut ma być tym, który wypadłby bez zapisu.
	eq("generator kontynuuje po wczytaniu", Game.rng.randi(), expected_next)

# ——— Migracja starych zapisów ————————————————————————————————

func _test_migration() -> void:
	print("\nMigracja starego zapisu")
	var old := {
		"version": 3,
		"world": {"name": "Stary Świat"},
		"character": {"name": "Bohater"},
		"history": [{"role": "narrator", "text": "Początek."}],
		"locations": [], "discoveries": [], "quests": [],
		"npcs": [{"imie": "Kowal", "plec": "mężczyzna", "rola": "kowal", "relacja": "obojętny", "tura": 1}],
		"suggestions": [], "turn": 5, "seed": 7,
	}
	Game.from_dict(old)
	eq("świat wczytany", str(Game.world.get("name", "")), "Stary Świat")
	check("brakujące fakty zastąpione pustą listą", typeof(Game.facts) == TYPE_ARRAY and Game.facts.is_empty())
	check("brakująca oś czasu zastąpiona pustą listą", typeof(Game.events) == TYPE_ARRAY and Game.events.is_empty())
	eq("postaci dopisano stan", str(Game.npcs[0].get("stan", "")), "żywy")

# ——— Rozwój postaci ————————————————————————————————————————

func _test_progression() -> void:
	print("\nRozwój postaci")
	Game.character = {"name": "Test", "gender": "Mężczyzna"}
	Game.ensure_character_stats()
	Game.recompute_maxima()
	eq("start na 1 poziomie", int(Game.character["level"]), 1)

	var attrs: Dictionary = Game.character["attrs"]
	attrs["sila"] = 5
	Game.recompute_maxima()
	var base_hp := int(Game.character["hp_max"])
	attrs["sila"] = 7
	Game.recompute_maxima()
	check("Siła podnosi maksimum zdrowia", int(Game.character["hp_max"]) > base_hp,
		"— %d vs %d" % [int(Game.character["hp_max"]), base_hp])

	Game.character["attr_points"] = 1
	var before := int(attrs.get("zrecznosc", 5))
	Game.spend_attr("zrecznosc")
	eq("punkt podnosi atrybut", int((Game.character["attrs"] as Dictionary).get("zrecznosc", 0)), before + 1)
	eq("punkt został zużyty", int(Game.character["attr_points"]), 0)

	Game.character["attr_points"] = 0
	var frozen := int((Game.character["attrs"] as Dictionary).get("zrecznosc", 0))
	Game.spend_attr("zrecznosc")
	eq("bez punktów atrybut się nie zmienia",
		int((Game.character["attrs"] as Dictionary).get("zrecznosc", 0)), frozen)

# ——— Scalanie Kroniki ————————————————————————————————————————

func _test_chronicle_merge() -> void:
	print("\nScalanie Kroniki")
	Game.npcs = []
	Game.locations = []
	Game.discoveries = []
	Game.quests = []
	Game.facts = []
	Game.turn = 1
	Game.character = {"name": "Halina"}

	var state := {
		"postacie": [{"imie": "Marta", "plec": "kobieta", "rola": "zielarka", "relacja": "nieufna"}],
		"miejsca": [{"nazwa": "Skład przy Starym Trakcie", "opis": "pusty magazyn"}],
		"odkrycia": [{"nazwa": "List bez podpisu", "rodzaj": "Trop", "opis": "z piwnicy"}],
		"watki": [{"tytul": "Kto wysłał list", "stan": "otwarty"}],
		"fakty": [{"tresc": "Wójt zna nadawcę.", "waga": "kluczowy"}],
		"wydarzenia": [{"opis": "Marta wpuściła gracza do składu."}],
		"hp": 0, "mana": 0, "pd": 10, "podpowiedzi": ["Idź do składu"],
	}
	Game._merge_npcs(state["postacie"])
	Game._merge_locations(state["miejsca"])
	Game._merge_discoveries(state["odkrycia"])
	Game._merge_quests(state["watki"])
	Game._merge_facts(state["fakty"])
	Game._merge_events(state["wydarzenia"])

	eq("postać dodana", Game.npcs.size(), 1)
	eq("miejsce dodane", Game.locations.size(), 1)
	eq("odkrycie dodane", Game.discoveries.size(), 1)
	eq("notatka odkrycia", str(Game.discoveries[0].get("note", "")), "z piwnicy")
	eq("wątek dodany", Game.quests.size(), 1)
	eq("fakt dodany", Game.facts.size(), 1)
	eq("wydarzenie dodane", Game.events.size(), 1)

	# Powtórka tego samego stanu nie może zdublować wpisów.
	Game._merge_npcs(state["postacie"])
	Game._merge_locations(state["miejsca"])
	Game._merge_discoveries(state["odkrycia"])
	Game._merge_facts(state["fakty"])
	eq("brak duplikatów postaci", Game.npcs.size(), 1)
	eq("brak duplikatów miejsc", Game.locations.size(), 1)
	eq("brak duplikatów odkryć", Game.discoveries.size(), 1)
	eq("brak duplikatów faktów", Game.facts.size(), 1)

	# Inna wielkość liter to nadal ten sam wpis, nie drugi.
	Game._merge_locations([{"nazwa": "SKŁAD PRZY STARYM TRAKCIE", "opis": ""}])
	eq("scalanie nie rozróżnia wielkości liter", Game.locations.size(), 1)

	# Zamknięcie wątku zmienia stan, nie dokłada nowego.
	Game._merge_quests([{"tytul": "Kto wysłał list", "stan": "zamknięty"}])
	eq("wątek nie zdublowany", Game.quests.size(), 1)
	eq("wątek zamknięty", str(Game.quests[0].get("status", "")), "zamknięty")

# ——— Pełny blok stanu ————————————————————————————————————————
# Scena otwierająca gubiła kiedyś miejsca, odkrycia, wątki, fakty i wydarzenia,
# bo scalała tylko trzy pola. Teraz oba wejścia idą przez apply_state.

func _test_state_block() -> void:
	print("\nPełny blok stanu")
	Game.npcs = []
	Game.locations = []
	Game.discoveries = []
	Game.quests = []
	Game.facts = []
	Game.events = []
	Game.suggestions = []
	Game.summary = ""
	Game.turn = 1
	Game.character = {"name": "Halina"}

	Game.apply_state({
		"streszczenie": "Halina dotarła do Kazimierza Dolnego.",
		"postacie": [{"imie": "Wójt Bąk", "plec": "mężczyzna", "rola": "wójt",
			"relacja": "wymijający", "stan": "żywy"}],
		"miejsca": [{"nazwa": "Kazimierz Dolny", "opis": "miasteczko nad Wisłą"}],
		"odkrycia": [{"nazwa": "Pieczęć na liście", "rodzaj": "Trop", "opis": "herb wójta"}],
		"watki": [{"tytul": "Kto podpisał list", "stan": "otwarty"}],
		"fakty": [{"tresc": "Wójt Bąk zna nadawcę listu.", "waga": "kluczowy"}],
		"wydarzenia": [{"opis": "Halina rozpoznała pieczęć."}],
		"podpowiedzi": ["Zapytaj wójta", "Obejrzyj pieczęć", "Wróć na rynek"],
	})

	eq("streszczenie zapisane", Game.summary, "Halina dotarła do Kazimierza Dolnego.")
	eq("postać zapisana", Game.npcs.size(), 1)
	eq("miejsce zapisane", Game.locations.size(), 1)
	eq("odkrycie zapisane", Game.discoveries.size(), 1)
	eq("wątek zapisany", Game.quests.size(), 1)
	eq("fakt zapisany", Game.facts.size(), 1)
	eq("wydarzenie zapisane", Game.events.size(), 1)
	eq("podpowiedzi zapisane", Game.suggestions.size(), 3)
	eq("nazwa miejsca dokładna", str(Game.locations[0].get("name", "")), "Kazimierz Dolny")

	# Pusty blok nie może niczego wyczyścić ani dopisać.
	Game.apply_state({})
	eq("pusty blok nic nie zmienia", Game.facts.size(), 1)

# ——— Wybór pamięci do promptu ————————————————————————————————
# Kanon brał pierwszych 14 poznanych postaci, więc świeżo poznany przeciwnik
# mógł się w nim w ogóle nie znaleźć.

func _test_prompt_memory() -> void:
	print("\nWybór pamięci do promptu")
	Game.world = {"name": "Świat", "genre_key": "fantasy", "supernatural": "brak"}
	Game.character = {"name": "Bohater", "gender": "Mężczyzna"}
	Game.ensure_character_stats()
	Game.locations = []
	Game.discoveries = []
	Game.quests = []
	Game.events = []
	Game.summary = ""
	Game.turn = 40

	Game.npcs = []
	for i in range(20):
		Game.npcs.append({"imie": "Statysta%02d" % i, "rola": "przechodzień",
			"relacja": "obojętny", "stan": "żywy", "tura": i, "ostatnio": i})
	Game.npcs.append({"imie": "Nemezis", "rola": "łowca", "relacja": "wrogi",
		"stan": "żywy", "tura": 39, "ostatnio": 39})

	var prompt: String = Narrator._gm_system(Game.world, Game.character)
	check("świeżo poznana postać jest w kanonie", prompt.contains("Nemezis"))
	check("najstarsi statyści wypadli z kanonu", not prompt.contains("Statysta00"))

	# Fakty kluczowe: fundament kampanii nie może wypaść przy nadmiarze.
	Game.facts = []
	Game.facts.append({"tresc": "Bohater jest synem króla.", "waga": "kluczowy", "tura": 4})
	for i in range(30):
		Game.facts.append({"tresc": "Zwrot akcji numer %d." % i, "waga": "kluczowy", "tura": 10 + i})
	prompt = Narrator._gm_system(Game.world, Game.character)
	check("najstarszy fakt kluczowy zostaje w pamięci", prompt.contains("synem króla"))
	check("najnowszy fakt kluczowy zostaje w pamięci", prompt.contains("Zwrot akcji numer 29"))

# ——— Animacja otwarcia ————————————————————————————————————————
# Katalog klatek zawiera też README, a w wersji wyeksportowanej pliki widać
# z dopiskiem „.import”. Ani jedno, ani drugie nie może udawać klatki.

func _test_intro() -> void:
	print("\nAnimacja otwarcia")
	var frames := Intro._frame_paths()
	check("lista klatek to tablica", typeof(frames) == TYPE_ARRAY)
	var only_images := true
	for f in frames:
		var low := str(f).to_lower()
		var ok := false
		for e in Intro.EXT:
			if low.ends_with(e):
				ok = true
		if not ok:
			only_images = false
	check("w liście są wyłącznie obrazy", only_images)
	eq("available() zgadza się z listą", Intro.available(), not frames.is_empty())
