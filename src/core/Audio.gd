extends Node

# Dźwięki interfejsu (kliknięcia przycisków). Pliki są opcjonalne — jeśli
# któregoś brak, gra działa dalej w ciszy. Włącznik: ustawienie "sfx_on".

const CLICK_PATH := "res://assets/audio/click.wav"
const BACK_PATH := "res://assets/audio/back.wav"

var _sfx: AudioStreamPlayer
var _click_stream: AudioStream
var _back_stream: AudioStream

func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Master"
	add_child(_sfx)
	_click_stream = _load(CLICK_PATH)
	_back_stream = _load(BACK_PATH)

func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func click() -> void:
	if _click_stream and bool(Game.settings.get("sfx_on", true)):
		_sfx.stream = _click_stream
		_sfx.play()

func back() -> void:
	if _back_stream and bool(Game.settings.get("sfx_on", true)):
		_sfx.stream = _back_stream
		_sfx.play()
