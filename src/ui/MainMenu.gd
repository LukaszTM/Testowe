class_name MainMenu
extends Control

func _ready() -> void:
	var spread := HBoxContainer.new()
	spread.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spread.add_theme_constant_override("separation", 6)
	add_child(spread)

	spread.add_child(_title_page())
	spread.add_child(_spine())
	spread.add_child(_menu_page())

# Cienki grzbiet między kartami.
func _spine() -> Control:
	var t: Texture2D = load("res://assets/art/spine.svg") if ResourceLoader.exists("res://assets/art/spine.svg") else null
	var c := Control.new()
	c.custom_minimum_size = Vector2(26, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t:
		var r := TextureRect.new()
		r.texture = t
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.modulate = Color(1, 1, 1, 0.5)
		c.add_child(r)
	return c

# Lewa karta: kaligraficzny tytuł i motto.
func _title_page() -> Control:
	var page := Ui.page(30)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.add_corners(page, 78)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	Ui.page_content(page).add_child(col)

	var t := Ui.script_title("Kronikarz", 76)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	col.add_child(Ui.flourish())

	var sub := Ui.subtle("Kroniki światów, których\njeszcze nikt nie opowiedział", 17)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	return page

# Prawa karta: wybór z księgi.
func _menu_page() -> Control:
	var page := Ui.page(30)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.add_corners(page, 78)

	var center := CenterContainer.new()
	Ui.page_content(page).add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	var has_saves := not Saves.list_saves().is_empty()

	var new_btn := Ui.button("Nowa opowieść", true)
	new_btn.pressed.connect(func(): Game.new_world(); Game.router.goto("world"))
	col.add_child(new_btn)

	var load_btn := Ui.button("Wczytaj kronikę")
	load_btn.disabled = not has_saves
	load_btn.pressed.connect(func(): Game.router.goto("load"))
	col.add_child(load_btn)

	var set_btn := Ui.button("Ustawienia")
	set_btn.pressed.connect(func(): Game.router.goto("settings"))
	col.add_child(set_btn)

	var quit_btn := Ui.button("Zakończ")
	quit_btn.pressed.connect(func(): get_tree().quit())
	col.add_child(quit_btn)

	col.add_child(Ui.spacer(18))
	col.add_child(Ui.flourish())
	var ver := Ui.subtle("wersja 3.0 · gra desktopowa · silnik Godot", 12)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)
	return page
