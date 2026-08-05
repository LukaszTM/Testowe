class_name WorldCreation
extends Control

var _f := {}          # referencje do pól formularza
var _mood: OptionButton

const MOOD_KEYS := ["lagodna", "wywazona", "mroczna"]
const MOOD_LABELS := [
	"Przygodowa — łagodna i przyjazna",
	"Wyważona — spokój i napięcie na zmianę",
	"Mroczna — sensacyjna, wysokie stawki",
]

# Części losowych nazw światów.
const NAME_A := ["Popioły", "Cienie", "Wrota", "Echa", "Kroniki", "Serce",
	"Zmierzch", "Przystań", "Szepty", "Ostatnie dni"]
const NAME_B := ["Północy", "Starego Traktu", "Zatoki", "Żelaznej Doliny",
	"Siódmego Miasta", "Pogranicza", "Mgły", "Bursztynu", "Kamiennych Pól", "Utraconych"]

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 40)
	add_child(margin)

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
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var rsp := Control.new()
	rsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(rsp)

	col.add_child(Ui.title("Stwórz świat", 34))
	col.add_child(Ui.subtle("To Ty ustalasz reguły. Wybierz gatunek, a resztę pól dopasuj do własnej wizji — albo zostaw szablon.", 15))
	col.add_child(Ui.spacer(4))

	var genre := Ui.dropdown("Gatunek", Genres.labels_in_order())
	_f["genre"] = genre["edit"]
	genre["edit"].item_selected.connect(_apply_template)
	col.add_child(genre["row"])

	var mood := Ui.dropdown("Charakter opowieści", MOOD_LABELS)
	_mood = mood["edit"]
	_mood.select(1)
	col.add_child(mood["row"])
	col.add_child(Ui.subtle("„Łagodna” prowadzi historię przyjaźnie i przygodowo, bez nagłej sensacji; „mroczna” od początku podnosi stawkę.", 12))

	var rand_btn := Ui.button("Losuj świat")
	rand_btn.pressed.connect(_randomize_world)
	col.add_child(rand_btn)

	_f["name"] = _add(col, Ui.field("Nazwa świata", "np. Popioły Wschodniej Marchii"))
	_f["era"] = _add(col, Ui.field("Epoka", "np. Późne średniowiecze"))
	_f["year"] = _add(col, Ui.field("Rok / lata akcji", "np. 1247 albo „schyłek imperium”"))
	_f["climate"] = _add(col, Ui.field("Klimat i realia", "czym ten świat oddycha"))
	_f["supernatural"] = _add(col, Ui.field("Poziom nadnaturalności", "od twardego realizmu po pełną magię"))
	_f["tone"] = _add(col, Ui.field("Ton opowieści", "np. mroczny, przygodowy, kameralny"))
	_f["start_location"] = _add(col, Ui.field("Lokacja startowa", "gdzie zaczyna się historia"))

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

func _randomize_world() -> void:
	var i := randi() % Genres.ORDER.size()
	_f["genre"].select(i)
	_apply_template(i)
	_f["name"].text = "%s %s" % [NAME_A[randi() % NAME_A.size()], NAME_B[randi() % NAME_B.size()]]

func _restore() -> void:
	var w := Game.world
	_mood.select(maxi(0, MOOD_KEYS.find(str(w.get("mood", "wywazona")))))
	_f["name"].text = w.get("name", "")
	_f["era"].text = w.get("era", "")
	_f["year"].text = w.get("year", "")
	_f["climate"].text = w.get("climate", "")
	_f["supernatural"].text = w.get("supernatural", "")
	_f["tone"].text = w.get("tone", "")
	_f["start_location"].text = w.get("start_location", "")
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
		"mood": MOOD_KEYS[_mood.selected],
		"mystery": "",
	}
	Game.router.goto("character")
