class_name SettingsScreen
extends Control

var _mode: OptionButton
var _host: LineEdit
var _model: LineEdit
var _ai_rows: VBoxContainer
var _dice: OptionButton
var _res: OptionButton
var _winmode: OptionButton
var _music: HSlider
var _music_val: Label
var _sfx: CheckButton
var _scale: HSlider
var _scale_val: Label

var _res_values: Array = []

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 36)
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
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var rsp := Control.new()
	rsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(rsp)

	col.add_child(Ui.title("Ustawienia", 32))

	# ——— Obraz ———
	col.add_child(Ui.heading("Obraz", 19))
	var res_labels: Array = []
	_res_values = Game.available_resolutions()
	var native := Game.native_resolution()
	for r in _res_values:
		var lbl := "%d × %d" % [r.x, r.y]
		if r == native:
			lbl += "  (natywna)"
		res_labels.append(lbl)
	var res := Ui.dropdown("Rozdzielczość", res_labels)
	_res = res["edit"]
	_res.select(_current_res_index())
	col.add_child(res["row"])

	var wm := Ui.dropdown("Tryb okna", ["W oknie", "Bez ramki (cały pulpit)", "Pełny ekran"])
	_winmode = wm["edit"]
	_winmode.select({"windowed": 0, "borderless": 1, "fullscreen": 2}.get(Game.settings.get("window_mode", "windowed"), 0))
	col.add_child(wm["row"])

	col.add_child(Ui.subtle("W trybie „W oknie” i „Bez ramki” obowiązuje wybrana rozdzielczość; pełny ekran używa natywnej.", 12))

	col.add_child(Ui.hsep())

	# ——— Dźwięk ———
	col.add_child(Ui.heading("Dźwięk", 19))
	col.add_child(Ui.subtle("MUZYKA W TLE", 13))
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 12)
	col.add_child(mrow)
	_music = HSlider.new()
	_music.min_value = 0.0
	_music.max_value = 1.0
	_music.step = 0.05
	_music.value = float(Game.settings.get("music_volume", 0.4))
	_music.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music.value_changed.connect(_on_music_changed)
	mrow.add_child(_music)
	_music_val = _value_label("%d%%" % int(round(_music.value * 100)))
	mrow.add_child(_music_val)

	_sfx = CheckButton.new()
	_sfx.text = "Dźwięki przycisków"
	_sfx.button_pressed = bool(Game.settings.get("sfx_on", true))
	col.add_child(_sfx)

	col.add_child(Ui.hsep())

	# ——— Rozgrywka ———
	col.add_child(Ui.heading("Rozgrywka", 19))
	var dice := Ui.dropdown("Rzuty kością", [
		"Tylko przy starciach i ryzyku (zalecane)", "Zawsze", "Nigdy"])
	_dice = dice["edit"]
	_dice.select({"risk": 0, "always": 1, "off": 2}.get(Game.settings.get("dice_mode", "risk"), 0))
	col.add_child(dice["row"])
	col.add_child(Ui.subtle("Kością rozstrzygamy tylko działania, w których coś realnie stawiasz na szali — nie zwykłe rozmowy czy rozglądanie się.", 12))

	col.add_child(Ui.hsep())

	# ——— Tekst ———
	col.add_child(Ui.subtle("WIELKOŚĆ TEKSTU", 13))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	col.add_child(srow)
	_scale = HSlider.new()
	_scale.min_value = 0.85
	_scale.max_value = 1.4
	_scale.step = 0.05
	_scale.value = float(Game.settings.get("font_scale", 1.0))
	_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scale.value_changed.connect(func(v): _scale_val.text = "%d%%" % int(round(v * 100)))
	srow.add_child(_scale)
	_scale_val = _value_label("%d%%" % int(round(_scale.value * 100)))
	srow.add_child(_scale_val)
	col.add_child(Ui.subtle("Zmiana wielkości tekstu zadziała po zapisaniu ustawień.", 12))

	col.add_child(Ui.hsep())

	# ——— Narracja ———
	col.add_child(Ui.heading("Narracja", 19))
	var mode := Ui.dropdown("Tryb narracji", [
		"Offline — proceduralna (darmowa)", "Online — model językowy (AI)"])
	_mode = mode["edit"]
	_mode.select(1 if Game.settings.get("mode", "offline") == "ai" else 0)
	_mode.item_selected.connect(func(_i): _toggle_ai())
	col.add_child(mode["row"])

	_ai_rows = VBoxContainer.new()
	_ai_rows.add_theme_constant_override("separation", 10)
	col.add_child(_ai_rows)
	var host := Ui.field("Adres modelu (Ollama)", "http://localhost:11434", Game.settings.get("ai_host", "http://localhost:11434"))
	_host = host["edit"]
	_ai_rows.add_child(host["row"])
	var model := Ui.field("Nazwa modelu", "np. bielik, llama3", Game.settings.get("ai_model", "bielik"))
	_model = model["edit"]
	_ai_rows.add_child(model["row"])

	col.add_child(Ui.spacer(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var back := Ui.button("Wstecz")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): Game.router.goto("menu"))
	row.add_child(back)
	var save := Ui.button("Zapisz ustawienia", true)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_save)
	row.add_child(save)

	col.add_child(Ui.spacer(20))
	_toggle_ai()

# Etykieta wartości (np. „%”) bez zawijania — stała szerokość, do rzędów z suwakiem.
func _value_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.custom_minimum_size = Vector2(52, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", Ui.INK_SOFT)
	return l

func _on_music_changed(v: float) -> void:
	_music_val.text = "%d%%" % int(round(v * 100))
	# Podgląd na żywo.
	Game.settings["music_volume"] = v
	Audio.apply_settings()

func _current_res_index() -> int:
	var cur := str(Game.settings.get("resolution", "1280x720"))
	for i in range(_res_values.size()):
		var r: Vector2i = _res_values[i]
		if "%dx%d" % [r.x, r.y] == cur:
			return i
	return 0

func _toggle_ai() -> void:
	_ai_rows.visible = _mode.selected == 1

func _save() -> void:
	Game.settings["mode"] = "ai" if _mode.selected == 1 else "offline"
	Game.settings["ai_host"] = _host.text.strip_edges()
	Game.settings["ai_model"] = _model.text.strip_edges()
	Game.settings["dice_mode"] = ["risk", "always", "off"][_dice.selected]
	Game.settings["window_mode"] = ["windowed", "borderless", "fullscreen"][_winmode.selected]
	if _res_values.size() > 0:
		var r: Vector2i = _res_values[clampi(_res.selected, 0, _res_values.size() - 1)]
		Game.settings["resolution"] = "%dx%d" % [r.x, r.y]
	Game.settings["music_volume"] = _music.value
	Game.settings["sfx_on"] = _sfx.button_pressed
	Game.settings["font_scale"] = _scale.value

	Ui.scale = _scale.value
	Game.save_settings()
	Game.apply_display()
	Audio.apply_settings()
	if Game.router:
		(Game.router as Control).theme = Ui.build_theme()
	Game.router.goto("menu")
