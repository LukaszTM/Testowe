class_name WorldCreation
extends Control

var _f := {}          # referencje do pól formularza

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 40)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(620, 0)
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	col.add_child(Ui.title("Stwórz świat", 34))
	col.add_child(Ui.subtle("To Ty ustalasz reguły. Wybierz gatunek, a resztę pól dopasuj do własnej wizji — albo zostaw szablon.", 15))
	col.add_child(Ui.spacer(4))

	var genre := Ui.dropdown("Gatunek", Genres.labels_in_order())
	_f["genre"] = genre["edit"]
	genre["edit"].item_selected.connect(_apply_template)
	col.add_child(genre["row"])

	_f["name"] = _add(col, Ui.field("Nazwa świata", "np. Popioły Wschodniej Marchii"))
	_f["era"] = _add(col, Ui.field("Epoka", "np. Późne średniowiecze"))
	_f["year"] = _add(col, Ui.field("Rok / lata akcji", "np. 1247 albo „schyłek imperium”"))
	_f["climate"] = _add(col, Ui.field("Klimat i realia", "czym ten świat oddycha"))
	_f["supernatural"] = _add(col, Ui.field("Poziom nadnaturalności", "od twardego realizmu po pełną magię"))
	_f["tone"] = _add(col, Ui.field("Ton opowieści", "np. mroczny, przygodowy, kameralny"))
	_f["start_location"] = _add(col, Ui.field("Lokacja startowa", "gdzie zaczyna się historia"))

	var myst := Ui.text_field("Główna tajemnica", "Zagadka, wokół której obraca się opowieść", 90)
	_f["mystery"] = myst["edit"]
	col.add_child(myst["row"])

	col.add_child(Ui.spacer(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	var back := Ui.button("Wstecz")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): Game.router.goto("menu"))
	row.add_child(back)

	var next := Ui.button("Dalej — postać", true)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(_go_next)
	row.add_child(next)

	col.add_child(Ui.spacer(20))

	# Wstępnie wypełnij pierwszym gatunkiem, jeśli świat jest pusty.
	if Game.world.is_empty():
		_apply_template(0)
	else:
		_restore()

func _add(col: VBoxContainer, spec: Dictionary) -> Control:
	col.add_child(spec["row"])
	return spec["edit"]

func _apply_template(index: int) -> void:
	var key := Genres.key_at(index)
	var t := Genres.template(key)
	_f["era"].text = t.get("era", "")
	_f["year"].text = ""
	_f["climate"].text = t.get("climate", "")
	_f["supernatural"].text = t.get("supernatural", "")
	_f["tone"].text = t.get("tone", "")
	_f["start_location"].text = t.get("start_location", "")
	_f["mystery"].text = t.get("mystery", "")

func _restore() -> void:
	var w := Game.world
	_f["name"].text = w.get("name", "")
	_f["era"].text = w.get("era", "")
	_f["year"].text = w.get("year", "")
	_f["climate"].text = w.get("climate", "")
	_f["supernatural"].text = w.get("supernatural", "")
	_f["tone"].text = w.get("tone", "")
	_f["start_location"].text = w.get("start_location", "")
	_f["mystery"].text = w.get("mystery", "")
	_f["genre"].select(Genres.ORDER.find(w.get("genre_key", "fantasy")))

func _go_next() -> void:
	var key := Genres.key_at(_f["genre"].selected)
	var world_name: String = _f["name"].text.strip_edges()
	if world_name == "":
		world_name = "Świat bez nazwy"
	Game.world = {
		"name": world_name,
		"genre_key": key,
		"genre_label": Genres.label(key),
		"era": _f["era"].text.strip_edges(),
		"year": _f["year"].text.strip_edges(),
		"climate": _f["climate"].text.strip_edges(),
		"supernatural": _f["supernatural"].text.strip_edges(),
		"tone": _f["tone"].text.strip_edges(),
		"start_location": _f["start_location"].text.strip_edges(),
		"mystery": _f["mystery"].text.strip_edges(),
	}
	Game.router.goto("character")
