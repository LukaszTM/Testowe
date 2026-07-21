class_name SettingsScreen
extends Control

var _mode: OptionButton
var _host: LineEdit
var _model: LineEdit
var _scale: HSlider
var _scale_val: Label
var _ai_rows: VBoxContainer

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 40)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	col.add_child(Ui.title("Ustawienia", 32))
	col.add_child(Ui.spacer(2))

	# Tryb narracji.
	var mode := Ui.dropdown("Tryb narracji", ["Offline — narracja proceduralna (darmowa)", "Online — model językowy (AI)"])
	_mode = mode["edit"]
	_mode.select(1 if Game.settings.get("mode", "offline") == "ai" else 0)
	_mode.item_selected.connect(func(_i): _toggle_ai())
	col.add_child(mode["row"])

	col.add_child(Ui.subtle("Tryb offline działa w pełni bez internetu i bez żadnych kluczy. Tryb AI łączy się z lokalnym modelem uruchomionym w Ollamie (np. Bielik) i prowadzi swobodną rozmowę z Mistrzem Gry.", 13))

	_ai_rows = VBoxContainer.new()
	_ai_rows.add_theme_constant_override("separation", 12)
	col.add_child(_ai_rows)

	var host := Ui.field("Adres modelu (Ollama)", "http://localhost:11434", Game.settings.get("ai_host", "http://localhost:11434"))
	_host = host["edit"]
	_ai_rows.add_child(host["row"])

	var model := Ui.field("Nazwa modelu", "np. bielik, llama3, mistral", Game.settings.get("ai_model", "bielik"))
	_model = model["edit"]
	_ai_rows.add_child(model["row"])

	col.add_child(Ui.hsep())

	# Skala czcionki.
	col.add_child(Ui.subtle("WIELKOŚĆ TEKSTU", 13))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	col.add_child(srow)
	_scale = HSlider.new()
	_scale.min_value = 0.85
	_scale.max_value = 1.35
	_scale.step = 0.05
	_scale.value = Game.settings.get("font_scale", 1.0)
	_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scale.value_changed.connect(func(v): _scale_val.text = "%d%%" % int(round(v * 100)))
	srow.add_child(_scale)
	_scale_val = Ui.body("%d%%" % int(round(_scale.value * 100)))
	srow.add_child(_scale_val)

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

	_toggle_ai()

func _toggle_ai() -> void:
	_ai_rows.visible = _mode.selected == 1

func _save() -> void:
	Game.settings["mode"] = "ai" if _mode.selected == 1 else "offline"
	Game.settings["ai_host"] = _host.text.strip_edges()
	Game.settings["ai_model"] = _model.text.strip_edges()
	Game.settings["font_scale"] = _scale.value
	Game.save_settings()
	# Przebuduj motyw, by od razu zastosować skalę tekstu.
	if Game.router:
		(Game.router as Control).theme = Ui.build_theme()
	Game.router.goto("menu")
