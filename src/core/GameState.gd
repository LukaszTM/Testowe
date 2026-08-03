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
var turn: int = 0
var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var started := false

var settings: Dictionary = {
	"mode": "offline",                    # "offline" / "claude" / "ollama"
	"claude_api_key": "",                 # klucz z platform.claude.com
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
	turn = 0
	started = true

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
	var roll := {}

	if Narrator.ai_enabled():
		# Akcja gracza jest już ostatnim wpisem historii.
		text = await Narrator.ai_generate(world, character, history)

	if text == "":
		# Tryb offline (także fallback, gdy AI zawiedzie).
		# Rzut kością tylko wtedy, gdy działanie faktycznie stawia coś na szali.
		if _should_roll(action):
			roll = Narrator.roll_action(rng, _archetype_modifier())
		text = Narrator.respond(world, character, prof, action, roll, rng)

	var entry := {"role": "narrator", "text": text}
	if not roll.is_empty():
		entry["roll"] = roll
	history.append(entry)
	_update_memory(action, text)
	emit_signal("chronicle_changed")

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

# Delikatny modyfikator do rzutu zależny od archetypu — nic ekstremalnego.
func _archetype_modifier() -> int:
	var a := str(character.get("archetype", "")).to_lower()
	if a.contains("najemn") or a.contains("rewolwer") or a.contains("żołn") or a.contains("łowca"):
		return 2
	if a.contains("uczon") or a.contains("naukow") or a.contains("inżynier") or a.contains("netrun"):
		return 1
	return 0

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
	turn = int(d.get("turn", 0))
	seed_value = int(d.get("seed", 0))
	rng.seed = seed_value
	started = true
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
