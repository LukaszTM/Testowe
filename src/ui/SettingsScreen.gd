class_name SettingsScreen
extends Control

var _mode: OptionButton
var _claude_key: LineEdit
var _claude_url: LineEdit
var _claude_model: LineEdit
var _claude_rows: VBoxContainer
var _host: LineEdit
var _model: LineEdit
var _ollama_rows: VBoxContainer
var _dice: OptionButton
var _res: OptionButton
var _winmode: OptionButton
var _sfx: CheckButton
var _scale: HSlider
var _scale_val: Label

# [DEV] Test API — do usunięcia w wersji finalnej.
var _test_btn: Button
var _test_result: Label

var _res_values: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Ui.title_bar("Ustawienia"))
	add_child(Ui.hint_page("Co tu ustawisz", [
		"# Obraz",
		"Gra rysuje się zawsze w tej samej przestrzeni i skaluje do okna, więc każda rozdzielczość pokazuje ten sam układ księgi.",
		"# Wielkość tekstu",
		"Podnieś, jeśli czytasz z daleka albo na dużym ekranie. Działa po zapisaniu.",
		"# Mistrz Gry",
		"Offline to prosta narracja proceduralna. Claude API prowadzi pełną rozgrywkę: tworzy postacie, ich dialogi i reaguje na Twoje decyzje.",
		"# Klucz API",
		"Zapisuje się tylko na tym komputerze, w pliku ustawień.",
	]))
	var c := Ui.scroll_column(Ui.R_PAGE_L, 12)
	add_child(c["host"])
	var col: VBoxContainer = c["box"]


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

	# ——— Mistrz Gry ———
	col.add_child(Ui.heading("Mistrz Gry", 19))
	var mode := Ui.dropdown("Kto prowadzi opowieść", [
		"Offline — narracja proceduralna (prosta, darmowa)",
		"Claude API — pełny Mistrz Gry w chmurze (zalecane)",
		"Ollama — model lokalny na tym komputerze"])
	_mode = mode["edit"]
	_mode.select({"offline": 0, "claude": 1, "ollama": 2, "ai": 2}.get(str(Game.settings.get("mode", "offline")), 0))
	_mode.item_selected.connect(func(_i): _toggle_ai())
	col.add_child(mode["row"])

	_claude_rows = VBoxContainer.new()
	_claude_rows.add_theme_constant_override("separation", 10)
	col.add_child(_claude_rows)
	_claude_rows.add_child(Ui.subtle("Usługa w chmurze — nie stawiasz żadnego serwera i działa niezależnie od Twojego komputera. Klucz z platform.claude.com (oficjalne API Anthropic) albo ze zgodnej bramki, np. aiprimetech.io — wtedy wpisz jej adres poniżej. Klucz zapisuje się tylko lokalnie.", 12))
	var ckey := Ui.field("Klucz API", "sk-...", Game.settings.get("claude_api_key", ""))
	_claude_key = ckey["edit"]
	_claude_key.secret = true
	_claude_rows.add_child(ckey["row"])
	var curl := Ui.field("Adres API", "https://api.anthropic.com", Game.settings.get("claude_base_url", "https://api.anthropic.com"))
	_claude_url = curl["edit"]
	_claude_rows.add_child(curl["row"])
	_claude_rows.add_child(Ui.subtle("Oficjalne API: https://api.anthropic.com · AI Prime Tech: https://aiprimetech.io", 12))
	var warn := Ui.subtle("Uwaga: klucz jest wysyłany pod podany adres i przechowywany zwykłym tekstem w pliku ustawień. Wpisuj wyłącznie adresy, którym ufasz — operator obcej bramki zobaczy Twój klucz oraz treść rozgrywki.", 12)
	warn.add_theme_color_override("font_color", Ui.OXIDE)
	_claude_rows.add_child(warn)
	var cmodel := Ui.field("Model", "claude-opus-5", Game.settings.get("claude_model", "claude-opus-5"))
	_claude_model = cmodel["edit"]
	_claude_rows.add_child(cmodel["row"])

	# [DEV] Przycisk testu połączenia — do usunięcia w wersji finalnej
	# (razem z Narrator.dev_test_claude i polami _test_btn/_test_result).
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	_claude_rows.add_child(trow)
	_test_btn = Ui.small_button("Testuj połączenie")
	_test_btn.custom_minimum_size = Vector2(240, 48)
	_test_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_test_btn.pressed.connect(_on_test_api)
	trow.add_child(_test_btn)
	_test_result = Ui.subtle("", 13)
	_test_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(_test_result)

	_ollama_rows = VBoxContainer.new()
	_ollama_rows.add_theme_constant_override("separation", 10)
	col.add_child(_ollama_rows)
	var host := Ui.field("Adres Ollamy", "http://localhost:11434", Game.settings.get("ai_host", "http://localhost:11434"))
	_host = host["edit"]
	_ollama_rows.add_child(host["row"])
	var model := Ui.field("Nazwa modelu", "np. bielik, llama3", Game.settings.get("ai_model", "bielik"))
	_model = model["edit"]
	_ollama_rows.add_child(model["row"])

	col.add_child(Ui.spacer(10))
	var bar := Ui.action_bar()
	add_child(bar["host"])
	var row: HBoxContainer = bar["row"]
	var back := Ui.button("Wstecz")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func(): Game.router.goto("menu"))
	row.add_child(back)
	var save := Ui.button("Zapisz ustawienia", true)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_save)
	row.add_child(save)

	_toggle_ai()

# Etykieta wartości (np. „%”) bez zawijania — stała szerokość, do rzędów z suwakiem.
func _value_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.custom_minimum_size = Vector2(52, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_color", Ui.INK_SOFT)
	return l

func _current_res_index() -> int:
	var cur := str(Game.settings.get("resolution", "1280x720"))
	for i in range(_res_values.size()):
		var r: Vector2i = _res_values[i]
		if "%dx%d" % [r.x, r.y] == cur:
			return i
	return 0

func _toggle_ai() -> void:
	_claude_rows.visible = _mode.selected == 1
	_ollama_rows.visible = _mode.selected == 2

# [DEV] Obsługa testu API — do usunięcia w wersji finalnej.
func _on_test_api() -> void:
	_test_btn.disabled = true
	_test_result.add_theme_color_override("font_color", Ui.MUTED)
	_test_result.text = "Testuję połączenie…"
	var r: Dictionary = await Narrator.dev_test_claude(
		_claude_key.text, _claude_url.text, _claude_model.text)
	_test_result.text = str(r.get("note", ""))
	_test_result.add_theme_color_override("font_color",
		Ui.GREEN if bool(r.get("ok", false)) else Ui.OXIDE)
	_test_btn.disabled = false

func _save() -> void:
	Game.settings["mode"] = ["offline", "claude", "ollama"][_mode.selected]
	Game.settings["claude_api_key"] = _claude_key.text.strip_edges()
	var cu := _claude_url.text.strip_edges().rstrip("/")
	Game.settings["claude_base_url"] = cu if cu != "" else "https://api.anthropic.com"
	var cm := _claude_model.text.strip_edges()
	Game.settings["claude_model"] = cm if cm != "" else "claude-opus-5"
	Game.settings["ai_host"] = _host.text.strip_edges()
	Game.settings["ai_model"] = _model.text.strip_edges()
	Game.settings["dice_mode"] = ["risk", "always", "off"][_dice.selected]
	Game.settings["window_mode"] = ["windowed", "borderless", "fullscreen"][_winmode.selected]
	if _res_values.size() > 0:
		var r: Vector2i = _res_values[clampi(_res.selected, 0, _res_values.size() - 1)]
		Game.settings["resolution"] = "%dx%d" % [r.x, r.y]
	Game.settings["sfx_on"] = _sfx.button_pressed
	Game.settings["font_scale"] = _scale.value

	Ui.scale = _scale.value
	Game.save_settings()
	Game.apply_display()
	if Game.router:
		(Game.router as Control).theme = Ui.build_theme()
	Game.router.goto("menu")
