class_name LoadScreen
extends Control

var _list: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Ui.title_bar("Zapisane kroniki"))
	add_child(Ui.hint_page("Kroniki", [
		"Każda opowieść zapisuje się do własnego pliku — nowa gra nigdy nie nadpisze poprzedniej.",
		"",
		"Gra zapisuje się sama po każdej ukończonej turze, a także przy wyjściu do menu.",
		"",
		"Pliki leżą w katalogu danych gry, w podfolderze „kroniki”.",
		"",
		"Każdy zapis powstaje najpierw jako plik tymczasowy i dopiero po sprawdzeniu podmienia poprzedni. Stara wersja zostaje jako kopia bezpieczeństwa.",
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
	if bool(s.get("broken", false)):
		return _broken_row(s)
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
		info.add_child(Ui.note("zapis: %s" % s["saved_at"]))

	var load_btn := Ui.small_button("Wczytaj", true)
	load_btn.custom_minimum_size = Vector2(140, 48)
	load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_btn.pressed.connect(func():
		if Saves.load_into_game(s["path"]):
			Game.router.goto("play")
		else:
			_populate())
	box.add_child(load_btn)

	box.add_child(_delete_button(s))
	return card

# Usunięcie kroniki jest nieodwracalne, więc wymaga drugiego kliknięcia.
func _delete_button(s: Dictionary) -> Button:
	var del := Ui.small_button("Usuń")
	del.custom_minimum_size = Vector2(130, 48)
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var armed := [false]
	del.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			del.text = "Na pewno?"
			del.add_theme_color_override("font_color", Ui.OXIDE)
			await get_tree().create_timer(4.0).timeout
			if is_instance_valid(del) and armed[0]:
				armed[0] = false
				del.text = "Usuń"
				del.remove_theme_color_override("font_color")
			return
		Saves.delete_save(s["path"])
		_populate())
	return del

# Plik, którego nie da się odczytać, nie może po prostu zniknąć z listy —
# dla gracza wyglądałoby to tak, jakby kampania przepadła bez śladu.
func _broken_row(s: Dictionary) -> Control:
	var card := Ui.card(14)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(info)
	var head := Ui.heading("Uszkodzony zapis", 19)
	head.add_theme_color_override("font_color", Ui.OXIDE)
	info.add_child(head)
	info.add_child(Ui.subtle(str(s.get("name", "")), 13))
	if bool(s.get("backup", false)):
		info.add_child(Ui.note("Jest kopia bezpieczeństwa — „Wczytaj” spróbuje z niej odtworzyć kronikę."))
		var try_btn := Ui.small_button("Wczytaj", true)
		try_btn.custom_minimum_size = Vector2(140, 48)
		try_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		try_btn.pressed.connect(func():
			if Saves.load_into_game(s["path"]):
				Game.router.goto("play")
			else:
				_populate())
		box.add_child(try_btn)
	else:
		info.add_child(Ui.note("Brak kopii bezpieczeństwa. Tej kroniki nie da się już odtworzyć."))
	box.add_child(_delete_button(s))
	return card
