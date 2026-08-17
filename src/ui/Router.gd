extends Control

# Korzeń aplikacji. Pod spodem leży płyta z grafiką księgi (menu albo rozgrywka),
# a ekrany dokładają na nią tylko żywe kontrolki: napisy, przyciski, pola.

var _current: Control
var _plate: TextureRect
var _stage: Control

# Który ekran korzysta z której płyty.
const PLATES := {
	"menu": "plate_menu",
	"world": "plate_menu",
	"character": "plate_menu",
	"play": "plate_play",
	"load": "plate_menu",
	"settings": "plate_menu",
}

func _ready() -> void:
	theme = Ui.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_plate = TextureRect.new()
	_plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	Game.router = self
	goto("menu")

func goto(screen: String, _arg = null) -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
	_plate.texture = Ui.art(str(PLATES.get(screen, "plate_play")))
	var node: Control
	match screen:
		"menu": node = MainMenu.new()
		"world": node = WorldCreation.new()
		"character": node = CharacterCreation.new()
		"play": node = PlayScreen.new()
		"load": node = LoadScreen.new()
		"settings": node = SettingsScreen.new()
		_: node = MainMenu.new()
	_current = node
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(node)
