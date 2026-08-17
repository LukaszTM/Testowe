class_name Ui
extends RefCounted

# Szata graficzna Kronikarza. Cała oprawa — skórzana księga, pergaminowe karty,
# złocone okucia i ramy — pochodzi z grafik w assets/ui. Ekran jest rysowany
# w stałej przestrzeni 1672×941 (patrz project.godot: stretch „canvas_items”
# z zachowaniem proporcji), więc współrzędne poniżej są zawsze te same,
# niezależnie od rozdzielczości okna.

const REF := Vector2(1672, 941)

# ——— Obszary na płycie „menu” (menu i ekrany formularzy) ——————————
# Lewa karta ma u góry różę wiatrów, u dołu panoramę miasta — tekst siada
# pomiędzy nimi. Prawa karta jest pusta.
const M_TITLE   := Rect2(228, 288, 548, 150)   # kaligraficzny tytuł gry
const M_MOTTO   := Rect2(228, 448, 548, 64)    # dewiza pod tytułem
const M_BUTTONS := Rect2(900, 186, 456, 508)   # kolumna przycisków menu
const M_HEAD    := Rect2(230, 104, 546, 52)    # nagłówek ekranu
const M_BODY    := Rect2(228, 168, 546, 534)   # treść formularza
const M_ACTIONS := Rect2(228, 712, 546, 72)    # listwa akcji
const M_HINTS   := Rect2(890, 150, 470, 560)   # objaśnienia na prawej karcie

# ——— Obszary na płycie „rozgrywka” ————————————————————————————
# Lewa karta to jedna duża rama; prawa ma cztery gotowe pola.
const P_TITLE   := Rect2(220, 98, 566, 46)     # nazwa świata
const P_STORY   := Rect2(220, 152, 566, 408)   # narracja
const P_HINTS_L := Rect2(220, 570, 566, 24)    # napis „PODPOWIEDZI”
const P_HINTS   := Rect2(220, 598, 566, 64)    # trzy podpowiedzi
const P_INPUT   := Rect2(220, 674, 408, 76)    # pole polecenia
const P_EXEC    := Rect2(638, 674, 148, 76)    # przycisk „Wykonaj”
const P_BOX1    := Rect2(910, 118, 506, 208)   # bohater
const P_BOX2    := Rect2(906, 442, 222, 148)   # atrybuty
const P_BOX3    := Rect2(1190, 442, 230, 148)  # postacie
const P_BOX4    := Rect2(906, 654, 516, 110)   # stan i przyciski

# ——— Paleta zdjęta z grafik ————————————————————————————————
const INK         := Color("3b2c1c")   # tekst na pergaminie
const INK_SOFT    := Color("58432c")   # tekst pomocniczy
const MUTED       := Color("806a4c")
const LINE        := Color("a98f66")   # cienkie linie
const PANEL       := Color("d8c8a4")   # pergamin (gdy trzeba go domalować)
const PANEL_HI    := Color("ece0c2")
const BG_SOFT     := Color("cbb995")
const GOLD        := Color("8a6a1f")   # złoto czytelne na pergaminie
const GOLD_BRIGHT := Color("d8b556")
const GOLD_DIM    := Color("6e561f")
const WOOD        := Color("3b2a18")
const WOOD_HI     := Color("50391f")
const OXIDE       := Color("a33a22")   # zdrowie, ostrzeżenia
const GREEN       := Color("5f7a3a")   # powodzenie
const AZURE       := Color("41689a")   # mana
const PARCH_TEXT  := Color("ecdcb4")   # tekst na ciemnych okuciach
const LEATHER     := Color("140c05")   # tło poza księgą
const BG          := LEATHER

# Globalna skala czcionki (z ustawień gracza).
static var scale: float = 1.0

static var _f_regular: FontFile
static var _f_medium: FontFile
static var _f_bold: FontFile
static var _f_script: FontFile
static var _fonts_tried := false
static var _tex := {}

static func _load_fonts() -> void:
	if _fonts_tried:
		return
	_fonts_tried = true
	_f_regular = _try_font("res://assets/fonts/EBGaramond-Regular.ttf")
	_f_medium = _try_font("res://assets/fonts/EBGaramond-Medium.ttf")
	_f_bold = _try_font("res://assets/fonts/EBGaramond-Bold.ttf")
	_f_script = _try_font("res://assets/fonts/GreatVibes-Regular.ttf")

static func _try_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func fs(px: int) -> int:
	return int(round(px * scale))

# Tekstura z assets/ui — wczytywana raz i zapamiętywana.
static func art(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://assets/ui/%s.png" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = t
	return t

# ——— Warstwy i obszary ————————————————————————————————————

# Kontrolka ustawiona dokładnie w podanym obszarze karty.
static func region(r: Rect2) -> Control:
	var c := Control.new()
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y
	return c

# Obszar z pionowym układem treści w środku.
static func column(r: Rect2, sep := 12) -> Dictionary:
	var host := region(r)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", sep)
	host.add_child(box)
	return {"host": host, "box": box}

# Obszar przewijalny — treść dłuższa niż karta.
static func scroll_column(r: Rect2, sep := 12) -> Dictionary:
	var host := region(r)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", sep)
	sc.add_child(box)
	return {"host": host, "box": box, "scroll": sc}

# ——— Style z grafik ————————————————————————————————————————

# mx/my — marginesy 9-patcha (nierozciągane narożniki grafiki),
# cx/cy — ile miejsca zostawić na napis. To dwie różne rzeczy: ozdobne końcówki
# okucia mogą sięgać dalej niż obszar, w którym tekst i tak wygląda dobrze.
static func _sbt(name: String, mx: int, my: int, cx: int, cy: int,
		tint := Color.WHITE) -> StyleBox:
	var t := art(name)
	if t == null:
		return _sb(WOOD, 6, 2, GOLD, cx)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = mx
	sb.texture_margin_right = mx
	sb.texture_margin_top = my
	sb.texture_margin_bottom = my
	sb.content_margin_left = cx
	sb.content_margin_right = cx
	sb.content_margin_top = cy
	sb.content_margin_bottom = cy
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.modulate_color = tint
	return sb

static func _sb(fill: Color, radius := 6, border := 0, border_col := LINE, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_col
	return sb

const HOVER      := Color(1.12, 1.07, 0.95, 1.0)
const PRESS      := Color(0.76, 0.70, 0.60, 1.0)
const PRIMARY    := Color(1.16, 1.02, 0.66, 1.0)   # cieplejsze, „złote” okucie
const PRIMARY_HI := Color(1.30, 1.14, 0.74, 1.0)

# ——— Motyw ————————————————————————————————————————————————

static func build_theme() -> Theme:
	_load_fonts()
	var base := fs(19)
	var t := Theme.new()
	if _f_regular:
		t.default_font = _f_regular
	t.default_font_size = base

	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", base)

	# Przycisk = okucie z grafiki (9-patch), napis rysuje Godot.
	t.set_stylebox("normal", "Button", _sbt("btn_wide", 92, 33, 46, 14))
	t.set_stylebox("hover", "Button", _sbt("btn_wide_hover", 92, 33, 46, 14))
	t.set_stylebox("pressed", "Button", _sbt("btn_wide_down", 92, 33, 46, 14))
	t.set_stylebox("disabled", "Button", _sbt("btn_wide_off", 92, 33, 46, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PARCH_TEXT)
	t.set_color("font_hover_color", "Button", Color("fbeec6"))
	t.set_color("font_pressed_color", "Button", Color("fff8e2"))
	t.set_color("font_disabled_color", "Button", Color("9c8c72"))
	t.set_font_size("font_size", "Button", fs(20))
	if _f_medium:
		t.set_font("font", "Button", _f_medium)

	# Pola tekstowe = wgłębiona listwa z grafiki.
	for tp in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", tp, _sbt("field", 92, 22, 26, 10))
		t.set_stylebox("focus", tp, _sbt("field", 92, 22, 26, 10, Color(1.18, 1.12, 0.96, 1.0)))
		t.set_color("font_color", tp, Color("efe2c0"))
		t.set_color("font_placeholder_color", tp, Color("a08f70"))
		t.set_color("caret_color", tp, GOLD_BRIGHT)
		t.set_color("selection_color", tp, Color(0.55, 0.45, 0.20, 0.5))
		t.set_font_size("font_size", tp, base)
	t.set_stylebox("read_only", "LineEdit", _sbt("field", 92, 22, 26, 10))

	t.set_stylebox("normal", "OptionButton", _sbt("field", 92, 22, 26, 10))
	t.set_stylebox("hover", "OptionButton", _sbt("field", 92, 22, 26, 10, HOVER))
	t.set_stylebox("pressed", "OptionButton", _sbt("field", 92, 22, 26, 10, PRESS))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", Color("efe2c0"))
	t.set_color("font_hover_color", "OptionButton", Color("fbeec6"))
	t.set_font_size("font_size", "OptionButton", fs(18))

	# Rozwijana lista — ciemna karta na pergaminie.
	t.set_stylebox("panel", "PopupMenu", _sb(Color("2c2013"), 4, 2, GOLD, 8))
	t.set_color("font_color", "PopupMenu", Color("e8daba"))
	t.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	t.set_font_size("font_size", "PopupMenu", fs(18))

	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())

	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", fs(20))
	if _f_regular:
		t.set_font("normal_font", "RichTextLabel", _f_regular)
	if _f_bold:
		t.set_font("bold_font", "RichTextLabel", _f_bold)

	# Suwak: tor to rama paska, gałka wycięta z grafiki suwaka z paczki.
	t.set_stylebox("slider", "HSlider", _sbt("bar_frame", 34, 0, 0, 23))
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("a8842e")
	grab.set_corner_radius_all(7)
	grab.content_margin_left = 0
	grab.content_margin_right = 0
	grab.content_margin_top = 7
	grab.content_margin_bottom = 7
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var knob := art("slider_knob")
	if knob:
		t.set_icon("grabber", "HSlider", knob)
		t.set_icon("grabber_highlight", "HSlider", knob)
		t.set_icon("grabber_disabled", "HSlider", knob)
	t.set_constant("center_grabber", "HSlider", 1)

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", INK)
	t.set_font_size("font_size", "CheckButton", base)
	return t

# ——— Fabryki kontrolek ———————————————————————————————————————

static func title(txt: String, size := 32) -> Label:
	_load_fonts()
	var l := Label.new()
	l.text = txt
	if _f_medium:
		l.add_theme_font_override("font", _f_medium)
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", Color("42301c"))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func script_title(txt: String, size := 60) -> Label:
	_load_fonts()
	var l := Label.new()
	l.text = txt
	if _f_script:
		l.add_theme_font_override("font", _f_script)
	elif _f_bold:
		l.add_theme_font_override("font", _f_bold)
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", GOLD)
	return l

static func heading(txt: String, size := 21) -> Label:
	_load_fonts()
	var l := Label.new()
	l.text = txt
	if _f_medium:
		l.add_theme_font_override("font", _f_medium)
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", Color("46341f"))
	return l

# Nagłówek działu na karcie — wersaliki z cienką linią pod spodem.
static func section(txt: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var l := heading(txt.to_upper(), 17)
	l.add_theme_constant_override("outline_size", 0)
	box.add_child(l)
	box.add_child(hsep())
	return box

static func subtle(txt: String, size := 15) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func body(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(txt: String, primary := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 68)
	if primary:
		b.add_theme_stylebox_override("normal", _sbt("btn_wide", 92, 33, 46, 14, PRIMARY))
		b.add_theme_stylebox_override("hover", _sbt("btn_wide_hover", 92, 33, 46, 14, PRIMARY_HI))
		b.add_theme_color_override("font_color", Color("fff4d2"))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(func(): Audio.click())
	return b

# Mniejsze okucie — narożniki ekranu gry, przyciski w wierszach.
static func small_button(txt: String, primary := false) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 52)
	var tint := PRIMARY if primary else Color.WHITE
	b.add_theme_stylebox_override("normal", _sbt("btn_small", 46, 22, 24, 8, tint))
	b.add_theme_stylebox_override("hover", _sbt("btn_small", 46, 22, 24, 8, PRIMARY_HI if primary else HOVER))
	b.add_theme_stylebox_override("pressed", _sbt("btn_small", 46, 22, 24, 8, PRESS))
	b.add_theme_font_size_override("font_size", fs(18))
	if primary:
		b.add_theme_color_override("font_color", Color("fff4d2"))
	b.pressed.connect(func(): Audio.click())
	return b

# Podpowiedź w rzędzie pod narracją — płaska, szeroka płytka.
static func chip_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_stylebox_override("normal", _sbt("btn_med", 71, 25, 16, 4))
	b.add_theme_stylebox_override("hover", _sbt("btn_med_hover", 71, 25, 16, 4))
	b.add_theme_stylebox_override("pressed", _sbt("btn_med_down", 71, 25, 16, 4))
	b.add_theme_font_size_override("font_size", fs(15))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func(): Audio.click())
	return b

static func field(label_txt: String, placeholder := "", initial := "") -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(subtle(label_txt.to_upper(), 14))
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text = initial
	box.add_child(le)
	return {"row": box, "edit": le}

static func text_field(label_txt: String, placeholder := "", min_h := 90) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(subtle(label_txt.to_upper(), 14))
	var te := TextEdit.new()
	te.placeholder_text = placeholder
	te.custom_minimum_size = Vector2(0, min_h)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(te)
	return {"row": box, "edit": te}

static func dropdown(label_txt: String, options: Array) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(subtle(label_txt.to_upper(), 14))
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(0, 50)
	for o in options:
		ob.add_item(str(o))
	box.add_child(ob)
	return {"row": box, "edit": ob}

# Lekko przyciemniona karta na pergaminie — do wyliczeń i list.
static func card(pad := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.27, 0.14, 0.10)
	sb.set_corner_radius_all(4)
	sb.border_width_left = 2
	sb.border_color = Color(0.54, 0.42, 0.20, 0.55)
	sb.content_margin_left = pad + 6
	sb.content_margin_right = pad
	sb.content_margin_top = pad - 2
	sb.content_margin_bottom = pad - 2
	p.add_theme_stylebox_override("panel", sb)
	return p

static func hsep() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = Color(0.42, 0.32, 0.17, 0.5)
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	return s

# Ozdobna przerywka z grafiki.
static func flourish(_width := 300) -> Control:
	var t := art("ornament")
	if t == null:
		return hsep()
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(0, 26)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# ——— Zgodność z wcześniejszym układem ———————————————————————
# Karty pergaminu rysuje teraz płyta tła, więc page() to zwykły kontener.

static func page(pad := 26) -> Control:
	var frame := Control.new()
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + s, pad)
	frame.add_child(inner)
	frame.set_meta("content", inner)
	return frame

static func page_content(p: Control) -> Control:
	return p.get_meta("content") as Control

static func add_corners(_p: Control, _size := 76) -> void:
	pass   # narożniki są częścią grafiki księgi

# ——— Portrety ————————————————————————————————————————————

static func medallion(display_name: String, size := 44) -> Control:
	_load_fonts()
	var h := absi(hash(display_name.to_lower()))
	var hue := float(h % 360) / 360.0
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.from_hsv(hue, 0.30, 0.30)
	sb.set_corner_radius_all(size)
	sb.set_border_width_all(2)
	sb.border_color = GOLD
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	var l := Label.new()
	var words := display_name.strip_edges().split(" ", false)
	var initials := ""
	for i in range(mini(2, words.size())):
		initials += words[i].left(1).to_upper()
	l.text = initials if initials != "" else "?"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _f_medium:
		l.add_theme_font_override("font", _f_medium)
	l.add_theme_font_size_override("font_size", int(size * 0.44))
	l.add_theme_color_override("font_color", Color("f2ead6"))
	p.add_child(l)
	return p

static func avatar_or_medallion(character: Dictionary, size := 56) -> Control:
	var path := str(character.get("avatar", ""))
	if path != "" and FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(img)
			tr.custom_minimum_size = Vector2(size, size)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.clip_contents = true
			return tr
	return medallion(str(character.get("name", "?")), size)

# Pasek zdrowia / many / PD — grafika toru i wypełnienia z makiety.
static func stat_bar(fill: Color) -> Range:
	var which := "bar_fill_gold"
	if fill.is_equal_approx(OXIDE):
		which = "bar_fill_red"
	elif fill.is_equal_approx(AZURE):
		which = "bar_fill_blue"
	var under := art("bar_frame")
	var over := art(which)
	if under == null or over == null:
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 16)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("3a2a18")
		bg.set_corner_radius_all(7)
		var fg := StyleBoxFlat.new()
		fg.bg_color = fill
		fg.set_corner_radius_all(7)
		pb.add_theme_stylebox_override("background", bg)
		pb.add_theme_stylebox_override("fill", fg)
		return pb
	var tp := TextureProgressBar.new()
	tp.texture_under = under
	tp.texture_progress = over
	# Grafika ma tę samą wysokość, w jakiej ją rysujemy, więc rozciągamy tylko
	# w poziomie — ozdobne końcówki zostają nietknięte.
	tp.nine_patch_stretch = true
	tp.stretch_margin_left = 34
	tp.stretch_margin_right = 34
	tp.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	tp.custom_minimum_size = Vector2(0, 46)
	tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tp

# Przełącznik z ozdobnym znacznikiem z paczki.
static func toggle(txt: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = txt
	c.button_pressed = on
	var off_t := art("check_off")
	var on_t := art("check_on")
	if off_t and on_t:
		c.add_theme_icon_override("unchecked", off_t)
		c.add_theme_icon_override("checked", on_t)
		c.add_theme_icon_override("unchecked_disabled", off_t)
		c.add_theme_icon_override("checked_disabled", on_t)
		c.add_theme_constant_override("h_separation", 12)
	c.add_theme_color_override("font_color", INK)
	c.add_theme_color_override("font_hover_color", GOLD)
	c.add_theme_font_size_override("font_size", fs(18))
	c.toggled.connect(func(_v): Audio.click())
	return c

# ——— Gotowe fragmenty ekranów ————————————————————————————————

# Tytuł na górze lewej karty.
static func title_bar(txt: String) -> Control:
	var h := region(M_HEAD)
	var l := title(txt, 30)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h

# Listwa akcji u dołu lewej karty.
static func action_bar(sep := 18) -> Dictionary:
	var h := region(M_ACTIONS)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.offset_left = 0
	row.offset_right = 0
	row.offset_top = -34
	row.offset_bottom = 34
	row.add_theme_constant_override("separation", sep)
	h.add_child(row)
	return {"host": h, "row": row}

# Prawa karta na ekranach formularzy — krótka notka dla gracza.
static func hint_page(head: String, lines: Array) -> Control:
	var c := scroll_column(M_HINTS, 10)
	var box_: VBoxContainer = c["box"]
	box_.add_child(heading(head, 22))
	box_.add_child(flourish())
	box_.add_child(spacer(2))
	for l in lines:
		var t := str(l)
		if t == "":
			box_.add_child(spacer(8))
		elif t.begins_with("# "):
			box_.add_child(heading(t.substr(2), 17))
		else:
			box_.add_child(body(t))
	return c["host"]

# Ozdobna karta pergaminu na ciemnym tle — nakładki i karty postaci.
static func frame_card(pad := 34) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _sbt("card_frame", 96, 96, pad + 56, pad + 46)
	if sb is StyleBoxTexture:
		p.add_theme_stylebox_override("panel", sb)
	else:
		var f := StyleBoxFlat.new()
		f.bg_color = PANEL
		f.set_corner_radius_all(5)
		f.set_border_width_all(3)
		f.border_color = GOLD
		f.content_margin_left = pad
		f.content_margin_right = pad
		f.content_margin_top = pad
		f.content_margin_bottom = pad
		p.add_theme_stylebox_override("panel", f)
	return p

# Zawartość jednego z gotowych pól na prawej karcie ekranu gry.
static func box(r: Rect2, head := "", sep := 6) -> Dictionary:
	var c := scroll_column(r, sep)
	if head != "":
		var l := heading(head.to_upper(), 15)
		l.add_theme_color_override("font_color", MUTED)
		(c["box"] as VBoxContainer).add_child(l)
	return {"host": c["host"], "box": c["box"], "scroll": c["scroll"]}
