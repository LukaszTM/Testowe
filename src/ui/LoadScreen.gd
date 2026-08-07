class_name LoadScreen
extends Control

var _list: VBoxContainer

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 40)
	# Karta pergaminu pod całą zawartością ekranu.
	var page := Ui.page(0)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	Ui.add_corners(page, 70)
	Ui.page_content(page).add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var lsp := Control.new()
	lsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(lsp)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var rsp := Control.new()
	rsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(rsp)

	col.add_child(Ui.title("Zapisane kroniki", 32))
	col.add_child(Ui.spacer(4))

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)
	_populate()

	col.add_child(Ui.spacer(8))
	var back := Ui.button("Wstecz")
	back.pressed.connect(func(): Game.router.goto("menu"))
	col.add_child(back)

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

	var load_btn := Ui.button("Wczytaj", true)
	load_btn.custom_minimum_size = Vector2(120, 42)
	load_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_btn.pressed.connect(func():
		if Saves.load_into_game(s["path"]):
			Game.router.goto("play"))
	box.add_child(load_btn)

	var del := Ui.button("Usuń")
	del.custom_minimum_size = Vector2(90, 42)
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.pressed.connect(func():
		Saves.delete_save(s["path"])
		_populate())
	box.add_child(del)
	return card
