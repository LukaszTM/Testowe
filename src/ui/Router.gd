extends Control

# Korzeń aplikacji. Buduje oprawę księgi (skóra, winieta) i przełącza ekrany,
# które rozgrywają się „na kartach” w środku.

var _current: Control
var _stage: Control      # miejsce, w którym żyją ekrany

func _ready() -> void:
	theme = Ui.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Skórzana oprawa.
	var leather := TextureRect.new()
	leather.texture = Ui.leather_texture()
	leather.stretch_mode = TextureRect.STRETCH_TILE
	leather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(leather)

	# Miejsce na ekrany — z marginesem, żeby widać było oprawę dookoła.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	add_child(margin)

	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_stage)

	# Światło świecy: przyciemnione krawędzie ekranu.
	var vignette := TextureRect.new()
	vignette.texture = Ui.vignette_texture()
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

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
	_stage.add_child(node)
