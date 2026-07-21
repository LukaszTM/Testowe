class_name Ui
extends RefCounted

# Warstwa prezentacji Kronikarza: paleta barw oraz fabryki gotowych kontrolek.
# Klimat celowo odchodzi od "webowego" wyglądu — ciepły atrament na ciemnym
# pergaminie, wąskie kolumny tekstu, złote akcenty jak w starej księdze.

const BG        := Color("13100c")
const BG_SOFT   := Color("1b1712")
const PANEL     := Color("221c15")
const PANEL_HI  := Color("2c241b")
const LINE      := Color("3a3020")
const INK       := Color("e7ddc9")
const INK_SOFT  := Color("b7ac93")
const MUTED     := Color("8a7f68")
const GOLD      := Color("cfa24a")
const GOLD_DIM  := Color("6e561f")
const OXIDE     := Color("b04a34")
const GREEN     := Color("7f9c5a")

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

# Motyw aplikowany na korzeń sceny — dziedziczą go wszystkie kontrolki.
static func build_theme() -> Theme:
	var scale: float = 1.0
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root.get_node_or_null("Game"):
		scale = float(Game.settings.get("font_scale", 1.0))
	var base := int(round(17 * scale))
	var t := Theme.new()
	t.default_font_size = base

	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", base)

	# Przyciski — stonowane, z podświetleniem złotem przy najechaniu.
	t.set_stylebox("normal", "Button", _sb(PANEL, 8, 1, LINE, 11))
	t.set_stylebox("hover", "Button", _sb(PANEL_HI, 8, 1, GOLD_DIM, 11))
	t.set_stylebox("pressed", "Button", _sb(GOLD_DIM, 8, 1, GOLD, 11))
	t.set_stylebox("disabled", "Button", _sb(BG_SOFT, 8, 1, LINE, 11))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font_size("font_size", "Button", base)

	# Pola tekstowe.
	for tp in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", tp, _sb(BG_SOFT, 6, 1, LINE, 9))
		t.set_stylebox("focus", tp, _sb(BG_SOFT, 6, 1, GOLD_DIM, 9))
		t.set_color("font_color", tp, INK)
		t.set_color("font_placeholder_color", tp, MUTED)
		t.set_color("caret_color", tp, GOLD)
		t.set_font_size("font_size", tp, base)
	t.set_stylebox("read_only", "LineEdit", _sb(BG, 6, 1, LINE, 9))

	# OptionButton — własne tło, żeby pasowało do pól tekstowych.
	t.set_stylebox("normal", "OptionButton", _sb(BG_SOFT, 6, 1, LINE, 9))
	t.set_stylebox("hover", "OptionButton", _sb(PANEL_HI, 6, 1, GOLD_DIM, 9))
	t.set_stylebox("pressed", "OptionButton", _sb(PANEL_HI, 6, 1, GOLD, 9))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", INK)

	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, 12, 1, LINE, 16))
	t.set_stylebox("panel", "PopupMenu", _sb(PANEL, 6, 1, LINE, 8))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", GOLD)

	# RichTextLabel — log narracji.
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font_size("normal_font_size", "RichTextLabel", int(round(18 * scale)))

	# ScrollContainer — cichy pasek przewijania.
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	return t

# ——— Fabryki kontrolek ———————————————————————————————————————

static func title(txt: String, size := 44) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l

static func heading(txt: String, size := 22) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	return l

static func subtle(txt: String, size := 15) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
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
	b.custom_minimum_size = Vector2(0, 46)
	if primary:
		b.add_theme_stylebox_override("normal", _sb(GOLD_DIM, 8, 1, GOLD, 11))
		b.add_theme_stylebox_override("hover", _sb(Color("8a6c26"), 8, 1, GOLD, 11))
		b.add_theme_color_override("font_color", Color("fdf3d8"))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b

static func field(label_txt: String, placeholder := "", initial := "") -> Dictionary:
	# Zwraca wiersz formularza oraz referencję do pola, by ekran mógł czytać wartość.
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
	p.add_theme_stylebox_override("panel", _sb(PANEL, 12, 1, LINE, pad))
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
