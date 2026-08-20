class_name Intro
extends Control

# Animacja otwarcia księgi, grana raz przy starcie gry.
#
# Klatki leżą w assets/intro i są wykrywane automatycznie — dołożenie albo
# usunięcie klatki nie wymaga zmiany w kodzie. Brak katalogu lub brak klatek
# oznacza po prostu, że gra startuje od razu w menu.
#
# Klatki wczytujemy strumieniowo, kilka do przodu i w tle. Czterdzieści kadrów
# pełnoekranowych trzymanych naraz to ćwierć gigabajta pamięci; przy tym
# podejściu w pamięci siedzi ich najwyżej kilka.

signal finished

const DIR := "res://assets/intro"
const EXT := [".png", ".jpg", ".jpeg", ".webp"]
const AHEAD := 5          # ile klatek wczytujemy z wyprzedzeniem
# Krótkie wygaszenie na końcu. Menu jest już zbudowane pod spodem, więc
# animacja po prostu w nie przechodzi — a drobna różnica między ostatnią
# klatką a tłem menu przestaje być widoczna jako przeskok.
const FADE_OUT := 0.35

var _paths: Array = []
var _cache := {}          # indeks klatki -> Texture2D
var _pending := {}        # indeks klatki -> trwa wczytywanie
var _index := 0
var _elapsed := 0.0
var _spf := 0.04
var _view: TextureRect
var _closed := false

# Czy w ogóle jest co grać — Router pyta o to przed utworzeniem ekranu.
static func available() -> bool:
	return not _frame_paths().is_empty()

static func _frame_paths() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for f in DirAccess.get_files_at(DIR):
		# W wersji wyeksportowanej pliki źródłowe widać z dopiskiem „.import”.
		if f.ends_with(".import"):
			f = f.trim_suffix(".import")
		var low := f.to_lower()
		for e in EXT:
			if low.ends_with(e) and not out.has(f):
				out.append(f)
				break
	out.sort()
	var full: Array = []
	for f in out:
		full.append(DIR + "/" + f)
	return full

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paths = _frame_paths()
	if _paths.is_empty():
		_close()
		return

	var seconds := clampf(float(Game.settings.get("intro_seconds", 1.6)), 0.4, 6.0)
	_spf = seconds / float(_paths.size())

	var bg := ColorRect.new()
	bg.color = Ui.LEATHER
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_view = TextureRect.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	var hint := Ui.subtle("dowolny klawisz — pomiń", 14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -320
	hint.offset_top = -46
	hint.offset_right = -28
	hint.offset_bottom = -18
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_theme_color_override("font_color", Color(0.72, 0.62, 0.44, 0.55))
	add_child(hint)

	# Pierwszą klatkę bierzemy od razu, żeby ekran nie mrugnął czernią.
	_request(0)
	var first: Texture2D = _take(0)
	if first:
		_view.texture = first
	for i in range(1, AHEAD):
		_request(i)

func _process(delta: float) -> void:
	if _closed or _paths.is_empty():
		return
	_elapsed += delta
	while _elapsed >= _spf:
		_elapsed -= _spf
		_index += 1
		if _index >= _paths.size():
			_finish_with_fade()
			return
		var tex: Texture2D = _take(_index)
		if tex:
			_view.texture = tex
		# Klatka odegrana już nie wróci — puszczamy ją, żeby pamięć nie rosła.
		_cache.erase(_index - 2)
		_request(_index + AHEAD)

# Ostatnia klatka zostaje na ekranie i płynnie ustępuje miejsca menu.
func _finish_with_fade() -> void:
	if _closed:
		return
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(_close)

func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	var skip := false
	if event is InputEventKey and event.pressed and not event.echo:
		skip = true
	elif event is InputEventMouseButton and event.pressed:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_close()

# ——— Wczytywanie w tle ————————————————————————————————————

func _request(i: int) -> void:
	if i < 0 or i >= _paths.size() or _cache.has(i) or _pending.has(i):
		return
	if ResourceLoader.load_threaded_request(_paths[i]) == OK:
		_pending[i] = true

func _take(i: int) -> Texture2D:
	if _cache.has(i):
		return _cache[i] as Texture2D
	if i < 0 or i >= _paths.size():
		return null
	var path: String = _paths[i]
	if _pending.has(i):
		# load_threaded_get czeka na dokończenie, jeśli wątek jeszcze pracuje.
		var loaded := ResourceLoader.load_threaded_get(path) as Texture2D
		_pending.erase(i)
		if loaded:
			_cache[i] = loaded
			return loaded
	if ResourceLoader.exists(path):
		var direct := load(path) as Texture2D
		if direct:
			_cache[i] = direct
		return direct
	return null

func _close() -> void:
	if _closed:
		return
	_closed = true
	set_process(false)
	emit_signal("finished")
