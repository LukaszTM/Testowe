class_name Ui
extends RefCounted

# Szata graficzna Kronikarza: gra wygląda jak rozłożona, stara księga —
# ciemna skóra oprawy, pergaminowe karty, złocone ramy i ornamenty.
# Pergamin i winieta powstają proceduralnie (szum + gradienty), więc nie
# wymagają żadnych plików graficznych; ornamenty to wektory z assets/art.

# ——— Paleta: ciemny atrament na pergaminie ———————————————————
const LEATHER    := Color("1d1108")   # oprawa księgi (tło okna)
const LEATHER_HI := Color("3a2413")   # jaśniejsza skóra przy krawędziach
const BG         := LEATHER
const PANEL      := Color("e6d9ba")   # pergamin karty
const PANEL_HI   := Color("f1e7ce")   # rozjaśniony pergamin
const BG_SOFT    := Color("d6c69f")   # wgłębienia: pola tekstowe, paski
const LINE       := Color("b39b6e")   # linie i ramki na pergaminie
const INK        := Color("3a2c1a")   # tekst główny
const INK_SOFT   := Color("5a4630")   # tekst pomocniczy
const MUTED      := Color("857055")   # podpisy, etykiety
const GOLD       := Color("8a6a1f")   # złoto czytelne na pergaminie
const GOLD_BRIGHT := Color("c9a227")  # złoto na ciemnym tle (przyciski)
const GOLD_DIM   := Color("6e561f")   # ciemne złoto: tło przycisku głównego
const WOOD       := Color("3a2a16")   # tło zwykłego przycisku
const WOOD_HI    := Color("4c3820")
const OXIDE      := Color("9c3b23")   # zdrowie, ostrzeżenia
const GREEN      := Color("5f7a3a")   # powodzenie
const AZURE      := Color("3f5f80")   # mana
const PARCH_TEXT := Color("e8d9b0")   # tekst na ciemnych przyciskach

# Globalna skala czcionki (ustawiana z GameState wg ustawień gracza).
static var scale: float = 1.0

static var _f_regular: FontFile
static var _f_medium: FontFile
static var _f_bold: FontFile
static var _f_quill: FontFile
static var _f_script: FontFile
static var _fonts_tried := false

static func _load_fonts() -> void:
	if _fonts_tried:
		return
	_fonts_tried = true
	_f_regular = _try_font("res://assets/fonts/EBGaramond-Regular.ttf")
	_f_medium = _try_font("res://assets/fonts/EBGaramond-Medium.ttf")
	_f_bold = _try_font("res://assets/fonts/EBGaramond-Bold.ttf")
	_f_quill = _try_font("res://assets/fonts/Almendra-Regular.ttf")
	_f_script = _try_font("res://assets/fonts/GreatVibes-Regular.ttf")

static func _try_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		return load(path)
	return null

static func fs(px: int) -> int:
	return int(round(px * scale))

static func _sb(fill: Color, radius := 8, border := 0, border_col := LINE, pad := 12) -> StyleBoxFlat:
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

# ——— Motyw ————————————————————————————————————————————————

static func build_theme() -> Theme:
	_load_fonts()
	var base := fs(17)
	var t := Theme.new()
	if _f_regular:
		t.default_font = _f_regular
	t.default_font_size = base

	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", base)

	# Przyciski: ciemne drewno w złoconej ramce — jak okucia na oprawie.
	t.set_stylebox("normal", "Button", _sb(WOOD, 6, 2, GOLD, 11))
	t.set_stylebox("hover", "Button", _sb(WOOD_HI, 6, 2, GOLD_BRIGHT, 11))
	t.set_stylebox("pressed", "Button", _sb(GOLD_DIM, 6, 2, GOLD_BRIGHT, 11))
	t.set_stylebox("disabled", "Button", _sb(Color("2b2016"), 6, 2, Color("6b5a3c"), 11))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PARCH_TEXT)
	t.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", Color("fdf3d8"))
	t.set_color("font_disabled_color", "Button", Color("8a7a60"))
	t.set_font_size("font_size", "Button", fs(19))
	if _f_quill:
		t.set_font("font", "Button", _f_quill)

	# Pola tekstowe: wgłębienie w pergaminie.
	for tp in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", tp, _sb(BG_SOFT, 5, 1, LINE, 9))
		t.set_stylebox("focus", tp, _sb(PANEL_HI, 5, 1, GOLD, 9))
		t.set_color("font_color", tp, INK)
		t.set_color("font_placeholder_color", tp, MUTED)
		t.set_color("caret_color", tp, GOLD)
		t.set_font_size("font_size", tp, base)
	t.set_stylebox("read_only", "LineEdit", _sb(BG_SOFT, 5, 1, LINE, 9))

	t.set_stylebox("normal", "OptionButton", _sb(BG_SOFT, 5, 1, LINE, 9))
	t.set_stylebox("hover", "OptionButton", _sb(PANEL_HI, 5, 1, GOLD, 9))
	t.set_stylebox("pressed", "OptionButton", _sb(PANEL_HI, 5, 1, GOLD, 9))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_hover_color", "OptionButton", GOLD)

	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, 8, 1, LINE, 16))
	t.set_stylebox("panel", "PopupMenu", _sb(PANEL, 5, 1, LINE, 8))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", GOLD)

	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", fs(18))
	if _f_regular:
		t.set_font("normal_font", "RichTextLabel", _f_regular)
	if _f_bold:
		t.set_font("bold_font", "RichTextLabel", _f_bold)

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", INK)
	return t

# ——— Tekstury proceduralne ————————————————————————————————

# Pergamin: łagodny szum przełożony na ciepłe odcienie kości słoniowej.
static func parchment_texture() -> NoiseTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color("d9c9a3"))
	grad.set_color(1, Color("f2e8cf"))
	grad.add_point(0.45, Color("e9dcbb"))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.0045
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	return tex

# Skóra oprawy: ciemny, drobnoziarnisty szum.
static func leather_texture() -> NoiseTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color("140b04"))
	grad.set_color(1, Color("3a2413"))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	return tex

# Winieta — przyciemnienie krawędzi ekranu, jak światło świecy.
static func vignette_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.75))
	grad.add_point(0.55, Color(0, 0, 0, 0.06))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

static func _art(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

# Karta pergaminu: tekstura + złocona ramka. Zwraca kontener na treść.
static func page(pad := 26) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _sb(PANEL, 6, 2, GOLD, 0))
	frame.clip_contents = true

	var stack := Control.new()   # warstwa tekstury pod treścią
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stack)

	var tex := TextureRect.new()
	tex.texture = parchment_texture()
	tex.stretch_mode = TextureRect.STRETCH_TILE
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(tex)

	var inner := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + s, pad)
	frame.add_child(inner)

	# Warstwa na ornamenty — PanelContainer rozciąga swoje dzieci, więc
	# narożniki muszą siedzieć w zwykłym Control, gdzie da się je ustawić.
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(overlay)

	frame.set_meta("content", inner)
	frame.set_meta("overlay", overlay)
	return frame

# Treść karty utworzonej przez page().
static func page_content(p: Control) -> Control:
	return p.get_meta("content") as Control

# Cztery narożne ornamenty nakładane na kartę.
static func add_corners(p: Control, size := 76) -> void:
	var t := _art("res://assets/art/corner.svg")
	if t == null or not p.has_meta("overlay"):
		return
	var overlay := p.get_meta("overlay") as Control
	# [poziomo, pionowo] dla czterech narożników
	for spec in [[0, 0], [1, 0], [0, 1], [1, 1]]:
		var ax := float(spec[0])
		var ay := float(spec[1])
		var c := TextureRect.new()
		c.texture = t
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.modulate = Color(1, 1, 1, 0.7)
		c.flip_h = ax > 0.5
		c.flip_v = ay > 0.5
		c.anchor_left = ax
		c.anchor_right = ax
		c.anchor_top = ay
		c.anchor_bottom = ay
		c.offset_left = 0.0 if ax < 0.5 else -float(size)
		c.offset_top = 0.0 if ay < 0.5 else -float(size)
		c.offset_right = c.offset_left + float(size)
		c.offset_bottom = c.offset_top + float(size)
		overlay.add_child(c)

# Ozdobna pozioma przerywka.
static func flourish(width := 300) -> Control:
	var t := _art("res://assets/art/divider.svg")
	if t == null:
		return hsep()
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(0, 18)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = Color(1, 1, 1, 0.8)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# ——— Fabryki kontrolek ———————————————————————————————————————

static func title(txt: String, size := 44) -> Label:
	_load_fonts()
	var l := Label.new()
	l.text = txt
	if _f_quill:
		l.add_theme_font_override("font", _f_quill)
	elif _f_bold:
		l.add_theme_font_override("font", _f_bold)
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", GOLD)
	return l

# Wielki, kaligraficzny tytuł — karta tytułowa księgi.
static func script_title(txt: String, size := 82) -> Label:
	_load_fonts()
	var l := Label.new()
	l.text = txt
	if _f_script:
		l.add_theme_font_override("font", _f_script)
	elif _f_bold:
		l.add_theme_font_override("font", _f_bold)
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_shadow_color", Color(0.15, 0.09, 0.03, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l

static func heading(txt: String, size := 22) -> Label:
	_load_fonts()
	var l := Label.new()
	l.text = txt
	if _f_quill:
		l.add_theme_font_override("font", _f_quill)
	elif _f_bold:
		l.add_theme_font_override("font", _f_bold)
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", INK)
	return l

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
	b.custom_minimum_size = Vector2(0, fs(46))
	if primary:
		b.add_theme_stylebox_override("normal", _sb(GOLD_DIM, 6, 2, GOLD_BRIGHT, 11))
		b.add_theme_stylebox_override("hover", _sb(Color("8a6c26"), 6, 2, Color("e3c766"), 11))
		b.add_theme_color_override("font_color", Color("fdf3d8"))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(func(): Audio.click())
	return b

static func field(label_txt: String, placeholder := "", initial := "") -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_child(subtle(label_txt.to_upper(), 13))
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text = initial
	box.add_child(le)
	return {"row": box, "edit": le}

static func text_field(label_txt: String, placeholder := "", min_h := 90) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_child(subtle(label_txt.to_upper(), 13))
	var te := TextEdit.new()
	te.placeholder_text = placeholder
	te.custom_minimum_size = Vector2(0, min_h)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(te)
	return {"row": box, "edit": te}

static func dropdown(label_txt: String, options: Array) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_child(subtle(label_txt.to_upper(), 13))
	var ob := OptionButton.new()
	for o in options:
		ob.add_item(str(o))
	box.add_child(ob)
	return {"row": box, "edit": ob}

static func card(pad := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.87, 0.80, 0.65, 0.55), 6, 1, LINE, pad))
	return p

static func hsep() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = LINE
	sb.thickness = 1
	s.add_theme_stylebox_override("separator", sb)
	return s

static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# ——— Portrety ————————————————————————————————————————————

static func medallion(display_name: String, size := 44) -> Control:
	_load_fonts()
	var h := absi(hash(display_name.to_lower()))
	var hue := float(h % 360) / 360.0
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.from_hsv(hue, 0.35, 0.34)
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
	if _f_quill:
		l.add_theme_font_override("font", _f_quill)
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

static func stat_bar(fill: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("c3b088")
	bg.set_corner_radius_all(5)
	bg.set_border_width_all(1)
	bg.border_color = Color("9a8259")
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(5)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb
