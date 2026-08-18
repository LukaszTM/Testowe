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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Ui.title_bar("Stwórz świat"))
	add_child(Ui.hint_page("Zanim ruszysz", [
		"Świat to reguły, w których będzie się toczyć Twoja opowieść.",
		"",
		"# Gatunek",
		"Podpowiada Mistrzowi Gry rekwizyty, miejsca i typ zagrożeń.",
		"# Charakter opowieści",
		"Decyduje o tonie. „Łagodna” prowadzi przygodowo i spokojnie, „mroczna” od pierwszej sceny podnosi stawkę.",
		"# Nadnaturalność",
		"Jeśli wpiszesz tu magię, Twoja postać dostanie pulę many.",
		"",
		"Żadne pole nie jest obowiązkowe — puste uzupełni szablon gatunku.",
	]))
	var c := Ui.scroll_column(Ui.M_BODY, 14)
	add_child(c["host"])
	var col: VBoxContainer = c["box"]

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
	col.add_child(Ui.note("„Łagodna” prowadzi historię przyjaźnie i przygodowo, bez nagłej sensacji; „mroczna” od początku podnosi stawkę."))

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

	col.add_child(Ui.spacer(10))
	var bar := Ui.action_bar()
	add_child(bar["host"])
	var row: HBoxContainer = bar["row"]

	var back := Ui.button("Wstecz")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): Game.router.goto("menu"))
	row.add_child(back)

	var next := Ui.button("Dalej — postać", true)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(_go_next)
	row.add_child(next)

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

# Wartość pola albo — gdy puste — propozycja z szablonu gatunku.
func _filled(field: String, tmpl: Dictionary) -> String:
	var v: String = _f[field].text.strip_edges()
	return v if v != "" else str(tmpl.get(field, ""))

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
	var tmpl := Genres.template(key)
	var world_name: String = _f["name"].text.strip_edges()
	if world_name == "":
		world_name = "Świat bez nazwy"
	# Ekran obiecuje, że puste pole uzupełni szablon gatunku — musi więc
	# naprawdę to robić, także wtedy, gdy gracz sam wyczyścił pole.
	Game.world = {
		"name": world_name,
		"genre_key": key,
		"genre_label": Genres.label(key),
		"era": _filled("era", tmpl),
		"year": _f["year"].text.strip_edges(),
		"climate": _filled("climate", tmpl),
		"supernatural": _filled("supernatural", tmpl),
		"tone": _filled("tone", tmpl),
		"start_location": _filled("start_location", tmpl),
		"mood": MOOD_KEYS[_mood.selected],
		# Tajemnica nie ma już swojej rubryki w kreatorze, ale szablon gatunku
		# ją niesie — szkoda, żeby leżała nieużywana.
		"mystery": str(tmpl.get("mystery", "")),
	}
	Game.router.goto("character")
