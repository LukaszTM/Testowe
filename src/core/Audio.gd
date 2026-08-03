extends Node

# Warstwa dźwięku: zapętlona ścieżka muzyczna w tle oraz efekty przycisków.
# Wszystkie pliki są opcjonalne — jeśli któregoś brak, gra działa dalej w ciszy.
# Własną ścieżkę dodasz, podmieniając plik res://assets/audio/theme.wav (albo
# .ogg) — patrz README.

const MUSIC_PATH := "res://assets/audio/theme.wav"
const CLICK_PATH := "res://assets/audio/click.wav"
const BACK_PATH := "res://assets/audio/back.wav"

var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _click_stream: AudioStream
var _back_stream: AudioStream
var _music_wanted := false

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Master"
	add_child(_sfx)

	_click_stream = _load(CLICK_PATH)
	_back_stream = _load(BACK_PATH)

	var m := _load(MUSIC_PATH)
	if m is AudioStreamWAV:
		# Zapętlenie bezszwowe na całej długości próbki.
		var wav := m as AudioStreamWAV
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif m is AudioStreamOggVorbis:
		(m as AudioStreamOggVorbis).loop = true
	_music.stream = m
	# Gdyby pętla zawiodła — wznów po zakończeniu.
	_music.finished.connect(_on_music_finished)

	apply_settings()

func _on_music_finished() -> void:
	if _music_wanted and _music.stream:
		_music.play()

func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

# Wywoływane przy starcie i po zmianie ustawień.
func apply_settings() -> void:
	var vol := float(Game.settings.get("music_volume", 0.4))
	_music_wanted = vol > 0.001 and _music.stream != null
	_music.volume_db = linear_to_db(clampf(vol, 0.0001, 1.0))
	if _music_wanted:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()

func click() -> void:
	if _click_stream and bool(Game.settings.get("sfx_on", true)):
		_sfx.stream = _click_stream
		_sfx.play()

func back() -> void:
	if _back_stream and bool(Game.settings.get("sfx_on", true)):
		_sfx.stream = _back_stream
		_sfx.play()
