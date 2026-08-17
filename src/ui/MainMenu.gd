class_name MainMenu
extends Control

# Menu główne. Karta tytułowa („Kronikarz”, panorama miasta, dewiza) jest
# częścią grafiki księgi — tutaj dokładamy tylko okucia przycisków na prawej
# stronie, dokładnie w miejscach, w których leżały na makiecie.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Lewa karta jest pusta — tytuł i dewizę wypisujemy sami.
	var th := Ui.region(Ui.M_TITLE)
	add_child(th)
	var t := Ui.script_title("Kronikarz", 112)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	th.add_child(t)

	var mh := Ui.region(Ui.M_MOTTO)
	add_child(mh)
	var mv := VBoxContainer.new()
	mv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mv.add_theme_constant_override("separation", 4)
	mh.add_child(mv)
	mv.add_child(Ui.flourish())
	var motto := Ui.subtle("Kroniki światów, których jeszcze nikt nie opowiedział", 19)
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(motto)

	var col := Ui.column(Ui.M_BUTTONS, 16)
	add_child(col["host"])
	var box: VBoxContainer = col["box"]

	box.add_child(_entry("Nowa opowieść", true, func():
		Game.new_world()
		Game.router.goto("world")))
	box.add_child(_entry("Wczytaj kronikę", false, func():
		Game.router.goto("load")))
	box.add_child(_entry("Ustawienia", false, func():
		Game.router.goto("settings")))
	box.add_child(_entry("Zakończ", false, func():
		get_tree().quit()))

func _entry(txt: String, primary: bool, action: Callable) -> Button:
	var b := Ui.button(txt, primary)
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Ui.fs(26))
	b.pressed.connect(action)
	return b
