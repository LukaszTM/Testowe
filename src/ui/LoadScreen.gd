class_name LoadScreen
extends Control

var _list: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Ui.title_bar("Zapisane kroniki"))
	add_child(Ui.hint_page("Kroniki", [
		"Każda opowieść zapisuje się do własnego pliku — nowa gra nigdy nie nadpisze poprzedniej.",
		"",
		"Gra zapisuje się sama po każdej turze, a także przy wyjściu do menu.",
		"",
		"Pliki leżą w katalogu danych gry, w podfolderze „zapisy”.",
	]))
	var c := Ui.scroll_column(Ui.M_BODY, 12)
	add_child(c["host"])
	var col: VBoxContainer = c["box"]


	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)
	_populate()

	var bar := Ui.action_bar()
	add_child(bar["host"])
	var back := Ui.button("Wstecz")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(bar["row"] as HBoxContainer).add_child(back)
	back.pressed.connect(func(): Game.router.goto("menu"))

func _populate() -> void:
	for c in _list.get_children():
		c.queue_free()
	var saves := Saves.list_saves()
	if saves.is_empty():
		_list.add_child(Ui.subtle("Nie masz jeszcze żadnej zapisanej kroniki.", 15))
		return
	for s in saves:
		_list.add_child(_row(s))

func _row(s: Dictionary) -> Control:
	var card := Ui.card(14)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(info)
	info.add_child(Ui.heading(s["name"], 19))
	info.add_child(Ui.subtle("%s · bohater: %s · tura %d" % [s["genre"], s["hero"], s["turn"]], 13))
	if s.get("saved_at", "") != "":
		info.add_child(Ui.subtle("zapis: %s" % s["saved_at"], 12))

	var load_btn := Ui.small_button("Wczytaj", true)
	load_btn.custom_minimum_size = Vector2(140, 48)
	load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_btn.pressed.connect(func():
		if Saves.load_into_game(s["path"]):
			Game.router.goto("play"))
	box.add_child(load_btn)

	var del := Ui.small_button("Usuń")
	del.custom_minimum_size = Vector2(110, 48)
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.pressed.connect(func():
		Saves.delete_save(s["path"])
		_populate())
	box.add_child(del)
	return card
