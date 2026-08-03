class_name CharacterCreation
extends Control

var _f := {}

const TRAITS := ["nieufny", "honorowy", "porywczy", "wyrachowany", "lojalny", "cyniczny",
	"ciekawski", "opanowany", "brawurowy", "skryty", "uparty", "ironiczny"]
const GOALS := ["odnaleźć prawdę, choćby miała zaboleć", "spłacić dług, który ciąży od lat",
	"ochronić kogoś, kto o tym nie wie", "odzyskać to, co komuś odebrano",
	"dowieść własnej niewinności", "zniknąć — ale najpierw dokończyć jedną sprawę"]
const WEAKNESSES := ["nie potrafi odpuścić", "ufa niewłaściwym ludziom", "ma coś do ukrycia",
	"działa, zanim pomyśli", "boi się jednej konkretnej rzeczy", "wciąż spłaca dawny błąd"]
const NAMES := ["Halina", "Marek", "Iwo", "Zofia", "Kasjan", "Nadia", "Bruno", "Lena",
	"Wit", "Roza", "Kaj", "Mira", "Otto", "Sława", "Emil", "Danka"]

func _ready() -> void:
	var prof := Game.profile()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 40)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(600, 0)
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	col.add_child(Ui.title("Twoja postać", 34))
	col.add_child(Ui.subtle("Świat „%s” czeka na bohatera. Wybierz, kim wejdziesz w jego historię." % Game.world.get("name", ""), 15))
	col.add_child(Ui.spacer(4))

	_f["name"] = _add(col, Ui.field("Imię", "np. Halina Grot"))

	var arch := Ui.dropdown("Archetyp", prof["archetypes"])
	_f["archetype"] = arch["edit"]
	col.add_child(arch["row"])

	_f["traits"] = _add(col, Ui.field("Cechy", "trzy przymiotniki, które ją definiują"))

	var goal := Ui.text_field("Cel", "Czego pragnie ponad wszystko?", 70)
	_f["goal"] = goal["edit"]
	col.add_child(goal["row"])

	_f["weakness"] = _add(col, Ui.field("Słabość", "co może ją zgubić"))

	var bg := Ui.text_field("Tło (opcjonalne)", "Skąd przychodzi, co zostawiła za sobą", 80)
	_f["background"] = bg["edit"]
	col.add_child(bg["row"])

	col.add_child(Ui.spacer(4))
	var roll_btn := Ui.button("Wylosuj postać")
	roll_btn.pressed.connect(_randomize)
	col.add_child(roll_btn)

	col.add_child(Ui.spacer(8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	var back := Ui.button("Wstecz")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): Game.router.goto("world"))
	row.add_child(back)

	var start := Ui.button("Rozpocznij opowieść", true)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_start)
	row.add_child(start)

	col.add_child(Ui.spacer(20))

	if not Game.character.is_empty():
		_restore()

func _add(col: VBoxContainer, spec: Dictionary) -> Control:
	col.add_child(spec["row"])
	return spec["edit"]

func _pick(arr: Array) -> String:
	return arr[randi() % arr.size()]

func _randomize() -> void:
	var prof := Game.profile()
	_f["name"].text = _pick(NAMES)
	(_f["archetype"] as OptionButton).select(randi() % prof["archetypes"].size())
	_f["traits"].text = "%s, %s, %s" % [_pick(TRAITS), _pick(TRAITS), _pick(TRAITS)]
	_f["goal"].text = _pick(GOALS).capitalize()
	_f["weakness"].text = _pick(WEAKNESSES)

func _restore() -> void:
	var c := Game.character
	_f["name"].text = c.get("name", "")
	_f["traits"].text = c.get("traits", "")
	_f["goal"].text = c.get("goal", "")
	_f["weakness"].text = c.get("weakness", "")
	_f["background"].text = c.get("background", "")

func _start() -> void:
	var prof := Game.profile()
	var hero_name: String = _f["name"].text.strip_edges()
	if hero_name == "":
		hero_name = "Bezimienny"
	Game.character = {
		"name": hero_name,
		"archetype": prof["archetypes"][(_f["archetype"] as OptionButton).selected],
		"traits": _f["traits"].text.strip_edges(),
		"goal": _f["goal"].text.strip_edges(),
		"weakness": _f["weakness"].text.strip_edges(),
		"background": _f["background"].text.strip_edges(),
	}
	Game.begin_adventure()
	Game.router.goto("play")
