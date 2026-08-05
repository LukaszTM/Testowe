extends Node

# Stan bieżącej sesji: świat, postać, Kronika (miejsca, odkrycia, wątki),
# przebieg narracji oraz ustawienia. Autoload dostępny globalnie jako `Game`.

signal chronicle_changed

var router: Node          # ustawiane przez Router.gd, do przełączania ekranów

var world: Dictionary = {}
var character: Dictionary = {}
var history: Array = []        # [{role:"narrator"/"player", text, roll?}]
var locations: Array = []      # [{name, note}]
var discoveries: Array = []    # [{title, type, time}]
var quests: Array = []         # [{title, note, status}]
var npcs: Array = []           # [{imie, plec, rola, relacja, tura}] — biblioteka postaci
var suggestions: Array = []    # podpowiedzi na bieżącą turę (od Mistrza Gry)
var save_path := ""            # plik tej kroniki (pusty = jeszcze niezapisana)

const ATTR_KEYS := ["sila", "zrecznosc", "intelekt", "charyzma"]
const ATTR_LABELS := {"sila": "Siła", "zrecznosc": "Zręczność", "intelekt": "Intelekt", "charyzma": "Charyzma"}
var turn: int = 0
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var started := false

var settings: Dictionary = {
	"mode": "offline",                    # "offline" / "claude" / "ollama"
	"claude_api_key": "",                 # klucz z platform.claude.com lub bramki zgodnej z API Anthropic
	"claude_base_url": "https://api.anthropic.com",
	"claude_model": "claude-opus-5",
	"ai_host": "http://localhost:11434",  # Ollama (model lokalny)
	"ai_model": "bielik",
	"font_scale": 1.0,
	"resolution": "1280x720",             # "SZERxWYS"
	"window_mode": "windowed",            # "windowed" / "borderless" / "fullscreen"
	"sfx_on": true,
	"dice_mode": "risk",                  # "risk" / "always" / "off"
}

const SETTINGS_PATH := "user://ustawienia.json"

func _ready() -> void:
	load_settings()
	apply_display()

# ——— Ekran: rozdzielczość i tryb okna ————————————————————————

# Rozdzielczości do wyboru — automatycznie ograniczone do wielkości ekranu,
# z dopisaną rozdzielczością natywną.
func available_resolutions() -> Array:
	var common := [
		Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1366, 768),
		Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1920, 1080),
		Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160),
	]
	var scr := DisplayServer.window_get_current_screen()
	var native := DisplayServer.screen_get_size(scr)
	var out: Array = []
	for r in common:
		if r.x <= native.x and r.y <= native.y and not out.has(r):
			out.append(r)
	if not out.has(native):
		out.append(native)
	out.sort_custom(func(a, b): return a.x * a.y < b.x * b.y)
	return out

func native_resolution() -> Vector2i:
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

func apply_display() -> void:
	var win := get_window()
	if win == null:
		return
	var mode := str(settings.get("window_mode", "windowed"))
	match mode:
		"fullscreen":
			win.mode = Window.MODE_FULLSCREEN
		"borderless":
			win.mode = Window.MODE_WINDOWED
			win.borderless = true
			_resize_and_center(win)
		_:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			_resize_and_center(win)

func _resize_and_center(win: Window) -> void:
	var parts := str(settings.get("resolution", "1280x720")).split("x")
	if parts.size() != 2:
		return
	var w := int(parts[0])
	var h := int(parts[1])
	if w <= 0 or h <= 0:
		return
	win.size = Vector2i(w, h)
	var scr := DisplayServer.window_get_current_screen()
	var scr_pos := DisplayServer.screen_get_position(scr)
	var scr_size := DisplayServer.screen_get_size(scr)
	win.position = scr_pos + (scr_size - Vector2i(w, h)) / 2

func profile() -> Dictionary:
	return Genres.profile(world.get("genre_key", "fantasy"))

# ——— Statystyki postaci (HP, mana, PD, atrybuty) ————————————————

# Mana istnieje tylko w światach z realną nadnaturalnością.
func world_has_mana() -> bool:
	var s := str(world.get("supernatural", "")).strip_edges().to_lower()
	return s != "" and not s.begins_with("brak")

# Uzupełnia brakujące pola postaci (nowe postacie i stare zapisy).
func ensure_character_stats() -> void:
	if not character.has("gender"):
		character["gender"] = "Mężczyzna"
	if not character.has("avatar"):
		character["avatar"] = ""
	if typeof(character.get("attrs")) != TYPE_DICTIONARY:
		character["attrs"] = {}
	for k in ATTR_KEYS:
		if not character["attrs"].has(k):
			character["attrs"][k] = 5
	for pair in [["level", 1], ["xp", 0], ["attr_points", 0], ["hp_max", 100],
			["hp", 100], ["mana_max", 0], ["mana", 0], ["dead", false]]:
		if not character.has(pair[0]):
			character[pair[0]] = pair[1]
	recompute_maxima()

# Atrybuty realnie kształtują postać: Siła podnosi maksymalne Zdrowie,
# Intelekt — maksymalną Manę. Każdy punkt ponad 5 daje +5.
func recompute_maxima() -> void:
	var attrs: Dictionary = character.get("attrs", {})
	character["hp_max"] = 100 + (int(attrs.get("sila", 5)) - 5) * 5
	if world_has_mana():
		character["mana_max"] = 100 + (int(attrs.get("intelekt", 5)) - 5) * 5
	else:
		character["mana_max"] = 0
	character["hp"] = clampi(int(character.get("hp", 100)), 0, int(character["hp_max"]))
	character["mana"] = clampi(int(character.get("mana", 0)), 0, int(character["mana_max"]))

# Wydanie punktu atrybutu (przycisk „+” w Kronice).
func spend_attr(key: String) -> void:
	ensure_character_stats()
	if int(character.get("attr_points", 0)) <= 0 or not ATTR_KEYS.has(key):
		return
	character["attrs"][key] = int(character["attrs"][key]) + 1
	character["attr_points"] = int(character["attr_points"]) - 1
	recompute_maxima()
	Saves.save_character(character)
	emit_signal("chronicle_changed")

# ——— Rozpoczęcie i przebieg przygody ————————————————————————

func new_world() -> void:
	world = {}
	character = {}

func begin_adventure() -> void:
	# Ustala ziarno na podstawie świata — ta sama opowieść jest odtwarzalna.
	var basis := "%s|%s|%s" % [world.get("name", ""), world.get("genre_key", ""), Time.get_unix_time_from_system()]
	seed_value = hash(basis)
	rng.seed = seed_value
	history.clear()
	locations.clear()
	discoveries.clear()
	quests.clear()
	npcs.clear()
	suggestions.clear()
	save_path = ""       # nowa kronika = nowy plik, nie nadpisuje poprzednich
	turn = 0
	started = true

	# Statystyki: poziom/atrybuty/PD niesie postać (magazyn postaci),
	# ale zdrowie i mana zaczynają pełne w każdej nowej opowieści.
	ensure_character_stats()
	recompute_maxima()
	character["hp"] = int(character["hp_max"])
	character["mana"] = int(character["mana_max"])
	character["dead"] = false
	Saves.save_character(character)

	var prof := profile()
	# Startowy punkt zaczepienia w Kronice.
	_add_location(prof["hub"])
	var opening := Narrator.opening(world, character, prof, rng)
	history.append({"role": "narrator", "text": opening})
	emit_signal("chronicle_changed")

# Wykonuje ruch gracza. Korutyna: w trybie AI czeka na model, w offline zwraca od razu.
func take_action(action: String) -> void:
	action = action.strip_edges()
	if action == "":
		return
	turn += 1
	history.append({"role": "player", "text": action})

	var prof := profile()
	var text := ""
	var state := {}

	# Rzut zapada PRZED narracją i obowiązuje w obu trybach — to gra rozstrzyga
	# próbę, a Mistrz Gry (także AI) tylko opisuje jej skutek.
	var roll := {}
	if _should_roll(action):
		roll = Narrator.roll_action(rng, _attr_modifier(action))

	if Narrator.ai_enabled():
		# Akcja gracza jest już ostatnim wpisem historii.
		text = await Narrator.ai_generate(world, character, history, roll)
		if text != "":
			var pr := Narrator.parse_state(text)
			text = pr["text"]
			state = pr["state"]

	if text == "":
		# Tryb offline (także fallback, gdy AI zawiedzie).
		text = Narrator.respond(world, character, prof, action, roll, rng)

	var entry := {"role": "narrator", "text": text}
	if not roll.is_empty():
		entry["roll"] = roll
	history.append(entry)
	_update_memory(action, text)
	_apply_turn_effects(action, roll, state)
	emit_signal("chronicle_changed")
	# Autozapis co pięć tur — długiej rozgrywki nie wolno stracić.
	if turn % 5 == 0:
		Saves.save_current()

# ——— Efekty tury: zdrowie, mana, doświadczenie, biblioteka postaci ————

func _apply_turn_effects(action: String, roll: Dictionary, state: Dictionary) -> void:
	ensure_character_stats()
	var hp_delta := 0
	var mana_delta := 0
	var xp_gain := 0

	if not state.is_empty():
		# Tryb AI: wartości z ukrytego bloku stanu (z bezpiecznymi granicami).
		hp_delta = clampi(int(state.get("hp", 0)), -40, 25)
		mana_delta = clampi(int(state.get("mana", 0)), -60, 25)
		xp_gain = clampi(int(state.get("pd", 8)), 0, 40)
		_merge_npcs(state.get("postacie", []))
		_set_suggestions(state.get("podpowiedzi", []))
	else:
		# Tryb offline: proste reguły.
		xp_gain = 8
		if not roll.is_empty():
			match str(roll.get("tier", "")):
				"krytyczny sukces":
					xp_gain = 30
				"sukces":
					xp_gain = 20
				"częściowy sukces":
					xp_gain = 12
				"niepowodzenie":
					xp_gain = 6
					hp_delta = -6
				"krytyczna porażka":
					xp_gain = 4
					hp_delta = -12
		if character["mana_max"] > 0 and _uses_magic(action):
			mana_delta -= 12

	# Powolna regeneracja — tylko w spokojnej turze. Rany odniesione teraz
	# nie zabliźniają się w tej samej scenie.
	if hp_delta >= 0:
		hp_delta += 2
	if mana_delta >= 0:
		mana_delta += 5

	character["hp"] = clampi(int(character["hp"]) + hp_delta, 0, int(character["hp_max"]))
	if int(character["mana_max"]) > 0:
		character["mana"] = clampi(int(character["mana"]) + mana_delta, 0, int(character["mana_max"]))
	character["xp"] = int(character["xp"]) + xp_gain

	_check_level_up()
	_check_death()

func _uses_magic(action: String) -> bool:
	var s := action.to_lower()
	for w in ["czar", "zaklę", "zakle", "magi", "moc", "rytuał", "rytual", "urok", "przywoł", "przywol"]:
		if s.contains(w):
			return true
	return false

# Próg kolejnego poziomu: 100 × obecny poziom PD.
func _check_level_up() -> void:
	var leveled := false
	while int(character["xp"]) >= 100 * int(character["level"]):
		character["xp"] = int(character["xp"]) - 100 * int(character["level"])
		character["level"] = int(character["level"]) + 1
		character["attr_points"] = int(character["attr_points"]) + 2
		leveled = true
	if leveled:
		history.append({"role": "narrator", "text":
			"✦ %s osiąga poziom %d! Masz %d pkt atrybutów do rozdania — panel bohatera w Kronice." % [
				character.get("name", "Bohater"), int(character["level"]), int(character["attr_points"])]})
		Saves.save_character(character)
		Saves.save_current()

func _check_death() -> void:
	if int(character["hp"]) > 0 or bool(character.get("dead", false)):
		return
	character["dead"] = true
	history.append({"role": "narrator", "text":
		"Świat ciemnieje. %s osuwa się na ziemię — ta kronika dobiega końca. Możesz wrócić do menu i rozpocząć nową opowieść." % character.get("name", "Bohater")})
	Saves.save_current()

# Podpowiedzi na następną turę, przygotowane przez Mistrza Gry do bieżącej sceny.
func _set_suggestions(arr) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	var out: Array = []
	for s in arr:
		var t := str(s).strip_edges()
		if t != "" and out.size() < 3:
			out.append(t)
	if not out.is_empty():
		suggestions = out

# Scala postacie z bloku stanu z biblioteką (po imieniu, bez rozróżniania wielkości liter).
func _merge_npcs(arr) -> void:
	if typeof(arr) != TYPE_ARRAY:
		return
	for n in arr:
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var imie := str(n.get("imie", "")).strip_edges()
		if imie == "" or imie.to_lower() == str(character.get("name", "")).to_lower():
			continue
		var found := false
		for x in npcs:
			if str(x["imie"]).to_lower() == imie.to_lower():
				x["rola"] = str(n.get("rola", x.get("rola", "")))
				x["relacja"] = str(n.get("relacja", x.get("relacja", "")))
				x["plec"] = str(n.get("plec", x.get("plec", "")))
				found = true
				break
		if not found and npcs.size() < 40:
			npcs.append({
				"imie": imie,
				"plec": str(n.get("plec", "")),
				"rola": str(n.get("rola", "")),
				"relacja": str(n.get("relacja", "")),
				"tura": turn,
			})

# Decyduje, czy dane działanie wymaga rzutu kością — zależnie od trybu w ustawieniach.
func _should_roll(action: String) -> bool:
	match str(settings.get("dice_mode", "risk")):
		"always":
			return true
		"off":
			return false
		_:
			# "risk": tylko starcia i ryzykowne, fizyczne akcje.
			if Narrator.classify(action) == "fight":
				return true
			var s := action.to_lower()
			for w in ["skrad", "uciek", "wspina", "przeskak", "wykrad", "forsuj",
					"wywa", "przemyk", "ryzyk", "napieram", "wdrap", "skacz"]:
				if s.contains(w):
					return true
			return false

# Modyfikator rzutu z atrybutu dobranego do rodzaju działania.
# Atrybuty startują na 5 (mod 0); każdy pełny +2 ponad 5 daje +1 do rzutu.
func _attr_modifier(action: String) -> int:
	ensure_character_stats()
	var attr := ""
	match Narrator.classify(action):
		"fight":
			attr = "sila"
		"move":
			attr = "zrecznosc"
		"look":
			attr = "intelekt"
		"talk":
			attr = "charyzma"
		_:
			return 0
	return int(floor((int(character["attrs"].get(attr, 5)) - 5) / 2.0))

# ——— Kronika: dopisywanie miejsc, odkryć i wątków ——————————————

func _add_location(loc: Dictionary) -> void:
	if str(loc.get("name", "")) == "":
		return
	for x in locations:
		if x["name"] == loc["name"]:
			return
	locations.append(loc.duplicate())

func _add_discovery(title: String, kind: String) -> void:
	for d in discoveries:
		if d["title"] == title:
			return
	discoveries.append({"title": title, "type": kind, "time": _clock()})

func _add_quest(title: String, note: String) -> void:
	for q in quests:
		if q["title"] == title:
			return
	quests.append({"title": title, "note": note, "status": "aktywne"})

func _update_memory(action: String, answer: String) -> void:
	var prof := profile()
	var ctx := (action + " " + answer).to_lower()
	if _any(ctx, ["bar", "karcz", "gospod", "saloon", "kawiar", "tawern", "knajp", "mesa", "herbaciar", "schronieni"]):
		_add_location(prof["hub"])
	if _any(ctx, ["las", "puszcz", "pustkowi", "obrzeż", "preri", "dok", "przedmieś", "rogatk", "dzielnic", "mgł", "sektor"]):
		_add_location(prof["edge"])
	if _any(ctx, ["podziem", "tunel", "piwnic", "loch", "kopal", "ładown", "kotłow", "metro", "kanał", "serwer"]):
		_add_location(prof["depth"])
	if _any(ctx, ["klucz", "kod", "hasł", "przepustk"]):
		_add_discovery("Klucz / kod dostępu", "Przedmiot")
	if _any(ctx, ["map", "plan", "szkic", "schemat"]):
		_add_discovery("Mapa / plan okolicy", "Wiedza")
	if _any(ctx, ["list", "notatk", "dziennik", "wiadomoś", "log"]):
		_add_discovery("Zapisana wiadomość", "Trop")
	if _any(ctx, ["zagin", "zniknął", "zniknęła", "porwan"]):
		_add_quest("Zaginiony trop", "Ustal, kto lub co zniknęło i dlaczego.")

func _any(s: String, subs: Array) -> bool:
	for sub in subs:
		if s.contains(sub):
			return true
	return false

func _clock() -> String:
	return "tura %d" % turn

# ——— Zapis stanu do słownika (dla SaveManager) —————————————————

func to_dict() -> Dictionary:
	return {
		"version": 3,
		"saved_at": Time.get_datetime_string_from_system(),
		"world": world,
		"character": character,
		"history": history,
		"locations": locations,
		"discoveries": discoveries,
		"quests": quests,
		"npcs": npcs,
		"suggestions": suggestions,
		"turn": turn,
		"seed": seed_value,
	}

func from_dict(d: Dictionary) -> void:
	world = d.get("world", {})
	character = d.get("character", {})
	history = d.get("history", [])
	locations = d.get("locations", [])
	discoveries = d.get("discoveries", [])
	quests = d.get("quests", [])
	npcs = d.get("npcs", [])
	suggestions = d.get("suggestions", [])
	turn = int(d.get("turn", 0))
	seed_value = int(d.get("seed", 0))
	rng.seed = seed_value
	started = true
	ensure_character_stats()
	emit_signal("chronicle_changed")

# ——— Ustawienia ———————————————————————————————————————————

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))
		f.close()

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in parsed.keys():
					settings[k] = parsed[k]
	Ui.scale = float(settings.get("font_scale", 1.0))
