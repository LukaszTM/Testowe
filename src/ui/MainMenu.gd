class_name MainMenu
extends Control

# Menu główne. Karta tytułowa („Kronikarz”, panorama miasta, dewiza) jest
# częścią grafiki księgi — tutaj dokładamy tylko okucia przycisków na prawej
# stronie, dokładnie w miejscach, w których leżały na makiecie.

func _ready() -> void:
	var col := Ui.column(Ui.R_MENU, 14)
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
	b.custom_minimum_size = Vector2(0, 112)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Ui.fs(27))
	b.pressed.connect(action)
	return b
