class_name MainMenu
extends Control

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(440, 0)
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var t := Ui.title("KRONIKARZ")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	var sub := Ui.subtle("Kroniki światów, których jeszcze nikt nie opowiedział", 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	col.add_child(Ui.spacer(18))

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

	col.add_child(Ui.spacer(24))
	var ver := Ui.subtle("wersja 3.0 · gra desktopowa · silnik Godot", 12)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)
