extends Node

# Dźwięk gry: krótkie odgłosy interfejsu i ścieżka muzyczna.
#
# Utwory nie są nigdzie wypisane — odtwarzacz sam skanuje katalog, więc
# dorzucenie kolejnego kawałka nie wymaga zmiany w kodzie. Czyta dwa miejsca:
#   res://assets/music  — utwory dołączone do gry,
#   user://muzyka       — utwory, które gracz wrzuci sobie sam.
# Kolejność jest losowa, bez powtórzenia tego samego utworu tuż po sobie,
# a przejście między kawałkami odbywa się przez przenikanie.

const SFX_CLICK := "res://assets/audio/click.wav"
const SFX_BACK := "res://assets/audio/back.wav"
const MUSIC_DIR := "res://assets/music"
const USER_MUSIC_DIR := "user://muzyka"
const AUDIO_EXT := [".mp3", ".ogg", ".wav"]

const FADE := 3.0        # sekundy przenikania między utworami
const SILENT_DB := -60.0

var _sfx: AudioStreamPlayer
var _click: AudioStream
var _back: AudioStream

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tracks: Array[String] = []
var _queue: Array[int] = []
var _last := -1
var _switching := false

func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_click = _res(SFX_CLICK)
	_back = _res(SFX_BACK)

	# Dwa odtwarzacze — jeden gra, drugi wchodzi pod spodem przy zmianie utworu.
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		p.finished.connect(_on_finished.bind(i))
		add_child(p)
		_players.append(p)

	DirAccess.make_dir_recursive_absolute(USER_MUSIC_DIR)
	rescan()

# ——— Odgłosy interfejsu ————————————————————————————————————

func click() -> void:
	_play_sfx(_click)

func back() -> void:
	_play_sfx(_back)

func _play_sfx(s: AudioStream) -> void:
	if s and bool(Game.settings.get("sfx_on", true)):
		_sfx.stream = s
		_sfx.volume_db = -7.0
		_sfx.play()

# ——— Ścieżka muzyczna ————————————————————————————————————

# Przeszukuje katalogi z muzyką. Wołane przy starcie i po zmianie ustawień.
func rescan() -> void:
	_tracks.clear()
	for dir in [MUSIC_DIR, USER_MUSIC_DIR]:
		for f in _audio_files(dir):
			_tracks.append(dir + "/" + f)
	_queue.clear()

func _audio_files(dir: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		# W wersji wyeksportowanej pliki źródłowe widać z dopiskiem „.import”.
		if f.ends_with(".import"):
			f = f.trim_suffix(".import")
		var low := f.to_lower()
		for ext in AUDIO_EXT:
			if low.ends_with(ext) and not out.has(f):
				out.append(f)
				break
	out.sort()
	return out

func track_count() -> int:
	return _tracks.size()

# Nazwa bieżącego utworu, do pokazania w ustawieniach.
func now_playing() -> String:
	var p := _players[_active]
	if not p.playing or _last < 0 or _last >= _tracks.size():
		return ""
	return pretty_name(_tracks[_last])

static func pretty_name(path: String) -> String:
	var base := path.get_file().get_basename().replace("_", " ").replace("-", " ")
	var words := base.split(" ", false)
	var out: Array = []
	for w in words:
		out.append(w.substr(0, 1).to_upper() + w.substr(1))
	return " ".join(out)

func music_on() -> bool:
	return bool(Game.settings.get("music_on", true)) and not _tracks.is_empty()

func play_music() -> void:
	if not music_on():
		return
	if _players[_active].playing:
		return
	_advance(1.5)

func stop_music() -> void:
	for p in _players:
		if p.playing:
			_fade(p, SILENT_DB, 1.2, true)

# Po zapisaniu ustawień: włącz, wycisz albo tylko popraw głośność.
func apply_settings() -> void:
	rescan()
	if not music_on():
		stop_music()
		return
	if _players[_active].playing:
		_fade(_players[_active], _target_db(), 0.4)
	else:
		_advance(1.5)

# Podgląd na żywo przy przeciąganiu suwaka w ustawieniach.
func preview_volume(v: float) -> void:
	Game.settings["music_volume"] = clampf(v, 0.0, 1.0)
	for p in _players:
		if p.playing:
			p.volume_db = _db(v)

# Katalog, do którego gracz może wrzucić własne utwory.
func user_music_path() -> String:
	return ProjectSettings.globalize_path(USER_MUSIC_DIR)

func skip() -> void:
	if music_on():
		_advance(1.0)

# ——— Mechanika odtwarzania ————————————————————————————————

func _process(_delta: float) -> void:
	if _switching or not music_on():
		return
	var p := _players[_active]
	if not p.playing or p.stream == null:
		return
	# Przenikanie zaczyna się na tyle wcześnie, żeby następny utwór zdążył wejść.
	var length := p.stream.get_length()
	if length > FADE * 2.0 and p.get_playback_position() >= length - FADE:
		_advance()

func _advance(fade_in := FADE) -> void:
	if _tracks.is_empty():
		return
	_switching = true
	var idx := _pick()
	var stream := _load_track(_tracks[idx])
	if stream == null:
		# Plik zniknął albo jest uszkodzony — wypada z listy i próbujemy dalej.
		_tracks.remove_at(idx)
		_queue.clear()
		_switching = false
		if not _tracks.is_empty():
			_advance(fade_in)
		return
	_last = idx

	var old := _players[_active]
	_active = 1 - _active
	var fresh := _players[_active]
	fresh.stream = stream
	fresh.volume_db = SILENT_DB
	fresh.play()
	_fade(fresh, _target_db(), fade_in)
	if old.playing:
		_fade(old, SILENT_DB, FADE, true)
	_switching = false

# Kolejka losowa; nowe rozdanie nie zaczyna się utworem, który właśnie grał.
func _pick() -> int:
	if _queue.is_empty():
		var order: Array[int] = []
		for i in range(_tracks.size()):
			order.append(i)
		order.shuffle()
		if order.size() > 1 and order[0] == _last:
			order.append(order.pop_front())
		_queue = order
	return _queue.pop_front()

func _on_finished(which: int) -> void:
	# Zapas na wypadek, gdyby długość utworu nie była znana i przenikanie
	# nie ruszyło samo.
	if which == _active and music_on() and not _switching:
		_advance(1.5)

func _fade(p: AudioStreamPlayer, to_db: float, time: float, stop_after := false) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, time)
	if stop_after:
		tw.tween_callback(p.stop)

func _target_db() -> float:
	return _db(float(Game.settings.get("music_volume", 0.55)))

func _db(vol: float) -> float:
	vol = clampf(vol, 0.0, 1.0)
	return SILENT_DB if vol <= 0.005 else linear_to_db(vol)

func _res(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null

# Utwory z res:// wczytuje Godot; te z katalogu gracza czytamy z dysku sami.
func _load_track(path: String) -> AudioStream:
	if path.begins_with("res://"):
		return load(path) if ResourceLoader.exists(path) else null
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var low := path.to_lower()
	if low.ends_with(".mp3"):
		var m := AudioStreamMP3.new()
		m.data = bytes
		return m
	if low.ends_with(".ogg"):
		return AudioStreamOggVorbis.load_from_buffer(bytes)
	# WAV z katalogu gracza pomijamy — Godot potrzebuje go zaimportowanego.
	return null
