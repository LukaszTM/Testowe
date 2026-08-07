class_name CharacterCreation
extends Control

var _f := {}
var _saved_pick: OptionButton
var _saved_list: Array = []
var _loaded: Dictionary = {}       # postać wczytana z magazynu (niesie poziom/atrybuty)
var _gender: OptionButton
var _arch: OptionButton
var _arch_custom: LineEdit
var _avatar_path := ""
var _avatar_slot: HBoxContainer
var _fd: FileDialog

const TRAITS := ["nieufny", "honorowy", "porywczy", "wyrachowany", "lojalny", "cyniczny",
	"ciekawski", "opanowany", "brawurowy", "skryty", "uparty", "ironiczny"]
const TRAITS_F := ["nieufna", "honorowa", "porywcza", "wyrachowana", "lojalna", "cyniczna",
	"ciekawska", "opanowana", "brawurowa", "skryta", "uparta", "ironiczna"]
const GOALS := ["odnaleźć prawdę, choćby miała zaboleć", "spłacić dług, który ciąży od lat",
	"ochronić kogoś, kto o tym nie wie", "odzyskać to, co komuś odebrano",
	"dowieść własnej niewinności", "zniknąć — ale najpierw dokończyć jedną sprawę"]
const WEAKNESSES := ["nie potrafi odpuścić", "ufa niewłaściwym ludziom", "ma coś do ukrycia",
	"działa, zanim pomyśli", "boi się jednej konkretnej rzeczy", "wciąż spłaca dawny błąd"]
const NAMES_M := ["Marek", "Iwo", "Kasjan", "Bruno", "Wit", "Kaj", "Otto", "Emil", "Gustaw", "Borys"]
const NAMES_F := ["Halina", "Zofia", "Nadia", "Lena", "Roza", "Mira", "Sława", "Danka", "Iga", "Wanda"]

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
	col.custom_minimum_size = Vector2(600, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var rsp := Control.new()
	rsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(rsp)

	col.add_child(Ui.title("Twoja postać", 34))
	col.add_child(Ui.subtle("Świat „%s” czeka na bohatera. Wybierz, kim wejdziesz w jego historię." % Game.world.get("name", ""), 15))
	col.add_child(Ui.spacer(4))

	# Magazyn postaci — użyj bohatera z poprzednich opowieści.
	_saved_list = Saves.list_characters()
	if not _saved_list.is_empty():
		var labels := ["— nowa postać —"]
		for s in _saved_list:
			labels.append("%s · poz. %d · %s" % [s["name"], s["level"], s["archetype"]])
		var sp := Ui.dropdown("Magazyn postaci", labels)
		_saved_pick = sp["edit"]
		_saved_pick.item_selected.connect(_on_saved_selected)
		col.add_child(sp["row"])

	var gd := Ui.dropdown("Płeć", ["Mężczyzna", "Kobieta"])
	_gender = gd["edit"]
	_gender.item_selected.connect(func(_i): _rebuild_archetypes())
	col.add_child(gd["row"])

	_f["name"] = _add(col, Ui.field("Imię", "np. Halina Grot"))

	var arch := Ui.dropdown("Archetyp", [])
	_arch = arch["edit"]
	_arch.item_selected.connect(func(_i): _toggle_custom_arch())
	col.add_child(arch["row"])

	var ca := Ui.field("Własny archetyp", "np. Kartograf zaginionych szlaków")
	_arch_custom = ca["edit"]
	col.add_child(ca["row"])
	_rebuild_archetypes()

	# Avatar z dysku (opcjonalny).
	col.add_child(Ui.subtle("AVATAR (OPCJONALNY)", 13))
	_avatar_slot = HBoxContainer.new()
	_avatar_slot.add_theme_constant_override("separation", 12)
	col.add_child(_avatar_slot)
	_fd = FileDialog.new()
	_fd.access = FileDialog.ACCESS_FILESYSTEM
	_fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_fd.filters = ["*.png, *.jpg, *.jpeg, *.webp ; Obrazy"]
	_fd.file_selected.connect(_on_avatar_picked)
	add_child(_fd)
	_refresh_avatar_slot()

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

func _add(col: VBoxContainer, spec: Dictionary) -> Control:
	col.add_child(spec["row"])
	return spec["edit"]

# ——— Archetypy zależne od płci + własny ————————————————————————

func _gender_index() -> int:
	return 1 if _gender.selected == 1 else 0

func _rebuild_archetypes(keep := -1) -> void:
	var prof := Game.profile()
	var gi := _gender_index()
	var prev := keep if keep >= 0 else _arch.selected
	_arch.clear()
	for pair in prof["archetypes"]:
		_arch.add_item(str(pair[gi]))
	_arch.add_item("Własny…")
	_arch.select(clampi(prev, 0, _arch.item_count - 1))
	_toggle_custom_arch()

func _is_custom_arch() -> bool:
	return _arch.selected == _arch.item_count - 1

func _toggle_custom_arch() -> void:
	_arch_custom.get_parent().visible = _is_custom_arch()

func _archetype_text() -> String:
	if _is_custom_arch():
		var t := _arch_custom.text.strip_edges()
		return t if t != "" else "Wędrowiec"
	return _arch.get_item_text(_arch.selected)

# ——— Avatar ———————————————————————————————————————————————

func _refresh_avatar_slot() -> void:
	for c in _avatar_slot.get_children():
		c.queue_free()
	var preview := Ui.avatar_or_medallion(
		{"avatar": _avatar_path, "name": _f["name"].text if _f.has("name") else "?"}, 72)
	_avatar_slot.add_child(preview)
	var pick := Ui.button("Wybierz obraz…")
	pick.custom_minimum_size = Vector2(180, 44)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.pressed.connect(func(): _fd.popup_centered(Vector2i(760, 520)))
	_avatar_slot.add_child(pick)
	if _avatar_path != "":
		var rm := Ui.button("Usuń")
		rm.custom_minimum_size = Vector2(90, 44)
		rm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rm.pressed.connect(func(): _avatar_path = ""; _refresh_avatar_slot())
		_avatar_slot.add_child(rm)
	var hint := Ui.subtle("PNG/JPG z dysku — obraz kopiuje się do danych gry. Bez obrazu postać dostaje medalion z inicjałami.", 12)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_avatar_slot.add_child(hint)

func _on_avatar_picked(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null:
		return
	# Przeskaluj do sensownego rozmiaru i zapisz kopię w danych gry.
	var m := maxi(img.get_width(), img.get_height())
	if m > 256:
		var k := 256.0 / m
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://avatary")
	var dst := "user://avatary/%d.png" % Time.get_ticks_msec()
	if img.save_png(dst) == OK:
		_avatar_path = dst
		_refresh_avatar_slot()

# ——— Magazyn postaci ————————————————————————————————————————

func _on_saved_selected(idx: int) -> void:
	if idx <= 0:
		_loaded = {}
		return
	var meta: Dictionary = _saved_list[idx - 1]
	_loaded = Saves.load_character(meta["path"])
	if _loaded.is_empty():
		return
	_gender.select(1 if str(_loaded.get("gender", "")) == "Kobieta" else 0)
	_f["name"].text = _loaded.get("name", "")
	_f["traits"].text = _loaded.get("traits", "")
	_f["goal"].text = _loaded.get("goal", "")
	_f["weakness"].text = _loaded.get("weakness", "")
	_f["background"].text = _loaded.get("background", "")
	_avatar_path = str(_loaded.get("avatar", ""))
	_refresh_avatar_slot()
	# Odtwórz archetyp: znany z listy albo jako własny.
	var prof := Game.profile()
	var gi := _gender_index()
	var target := str(_loaded.get("archetype", ""))
	var found := -1
	for i in range(prof["archetypes"].size()):
		if str(prof["archetypes"][i][gi]) == target:
			found = i
			break
	_rebuild_archetypes(found if found >= 0 else prof["archetypes"].size())
	if found < 0:
		_arch_custom.text = target
	_toggle_custom_arch()

# ——— Losowanie i start ————————————————————————————————————————

func _pick(arr: Array) -> String:
	return arr[randi() % arr.size()]

func _randomize() -> void:
	var prof := Game.profile()
	var female := _gender_index() == 1
	_f["name"].text = _pick(NAMES_F if female else NAMES_M)
	_arch.select(randi() % prof["archetypes"].size())
	_toggle_custom_arch()
	var pool := TRAITS_F if female else TRAITS
	_f["traits"].text = "%s, %s, %s" % [_pick(pool), _pick(pool), _pick(pool)]
	_f["goal"].text = _pick(GOALS)
	_f["weakness"].text = _pick(WEAKNESSES)
	_refresh_avatar_slot()

func _start() -> void:
	var hero_name: String = _f["name"].text.strip_edges()
	if hero_name == "":
		hero_name = "Bezimienna" if _gender_index() == 1 else "Bezimienny"
	# Wczytana postać niesie poziom, PD i atrybuty; nowa dostaje domyślne.
	var c := _loaded.duplicate(true) if not _loaded.is_empty() else {}
	c["name"] = hero_name
	c["gender"] = "Kobieta" if _gender_index() == 1 else "Mężczyzna"
	c["archetype"] = _archetype_text()
	c["traits"] = _f["traits"].text.strip_edges()
	c["goal"] = _f["goal"].text.strip_edges()
	c["weakness"] = _f["weakness"].text.strip_edges()
	c["background"] = _f["background"].text.strip_edges()
	c["avatar"] = _avatar_path
	Game.character = c
	Game.begin_adventure()
	Game.router.goto("play")
