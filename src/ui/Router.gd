extends Control

# Korzeń aplikacji. Trzyma tło i przełącza ekrany (menu, kreatory, rozgrywka).

var _current: Control

func _ready() -> void:
	theme = Ui.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Ui.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	Game.router = self
	goto("menu")

func goto(screen: String, arg = null) -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
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
	add_child(node)
