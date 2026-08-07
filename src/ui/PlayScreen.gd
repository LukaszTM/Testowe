class_name PlayScreen
extends Control

# Ekran rozgrywki. Grafika księgi jest pod spodem (Router), a tutaj siadają
# tylko żywe kontrolki — dokładnie w obszarach wyciętych z makiety.

var _log: RichTextLabel
var _input: TextEdit
var _input_host: Control
var _send: Button
var _hints_lbl: Control
var _hints_row: HBoxContainer
var _hints_host: Control
var _chronicle: VBoxContainer
var _status: Label
var _title: Label
var _busy := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_left()
	_build_right()

	Game.chronicle_changed.connect(_refresh)
	Narrator.ai_state.connect(_on_ai_state)
	_refresh()
	_rebuild_suggestions()
	_scroll_to_bottom()

# ——— Lewa karta: tytuł, narracja, podpowiedzi, pole polecenia ————————

func _build_left() -> void:
	var th := Ui.region(Ui.R_TITLE)
	add_child(th)
	var trow := HBoxContainer.new()
	trow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trow.add_theme_constant_override("separation", 12)
	th.add_child(trow)
	_title = Ui.title(str(Game.world.get("name", "Kronika")), 30)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(_title)
	var tag := Ui.subtle("· %s" % Game.world.get("genre_label", ""), 16)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tag)

	var host := Ui.region(Ui.R_PAGE_L)
	add_child(host)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(sc)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("line_separation", 8)
	sc.add_child(_log)

	_hints_lbl = Ui.region(Ui.R_HINTS_LBL)
	add_child(_hints_lbl)
	var hl := Ui.subtle("PODPOWIEDZI", 13)
	hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hints_lbl.add_child(hl)

	_hints_host = Ui.region(Ui.R_HINTS)
	add_child(_hints_host)
	_hints_row = HBoxContainer.new()
	_hints_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hints_row.add_theme_constant_override("separation", 10)
	_hints_host.add_child(_hints_row)

	_input_host = Ui.region(Ui.R_INPUT)
	add_child(_input_host)
	_input = TextEdit.new()
	_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input.placeholder_text = "Opisz, co robi Twoja postać…"
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.scroll_fit_content_height = true
	_input.text_changed.connect(_resize_input)
	_input.gui_input.connect(_input_gui)
	_input_host.add_child(_input)

	var eh := Ui.region(Ui.R_EXEC)
	add_child(eh)
	_send = Ui.small_button("Wykonaj", true)
	_send.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_send.add_theme_font_size_override("font_size", Ui.fs(21))
	_send.pressed.connect(func(): _submit(_input.text))
	eh.add_child(_send)

# ——— Prawa karta: stan Mistrza Gry, przyciski, Kronika ————————————

func _build_right() -> void:
	var sh := Ui.region(Ui.R_STATUS)
	add_child(sh)
	_status = Ui.subtle(_mode_note(), 14)
	_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.clip_text = true
	sh.add_child(_status)

	var ah := Ui.region(Ui.R_BTN_A)
	add_child(ah)
	var save := Ui.small_button("Zapisz")
	save.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save.pressed.connect(_on_save)
	ah.add_child(save)

	var bh := Ui.region(Ui.R_BTN_B)
	add_child(bh)
	var menu := Ui.small_button("Menu")
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Wyjście do menu zapisuje kronikę — nic nie przepada.
	menu.pressed.connect(func():
		Saves.save_current()
		Game.router.goto("menu"))
	bh.add_child(menu)

	var host := Ui.region(Ui.R_PAGE_R)
	add_child(host)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(sc)
	_chronicle = VBoxContainer.new()
	_chronicle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chronicle.add_theme_constant_override("separation", 9)
	sc.add_child(_chronicle)

# ——— Pole polecenia ————————————————————————————————————————

# Pole rośnie w górę, maksymalnie do trzech linii; wtedy chowa podpowiedzi.
func _resize_input() -> void:
	var visual := 0
	for i in range(_input.get_line_count()):
		visual += _input.get_line_wrap_count(i) + 1
	var lines := clampi(visual, 1, 3)
	var h: float = Ui.R_INPUT.size.y + float(lines - 1) * 26.0
	var bottom: float = Ui.R_INPUT.position.y + Ui.R_INPUT.size.y
	_input_host.offset_top = bottom - h
	var roomy := lines == 1
	_hints_host.visible = roomy and _hints_row.get_child_count() > 0
	_hints_lbl.visible = _hints_host.visible

# Enter wysyła akcję; Shift+Enter przechodzi do nowej linii.
func _input_gui(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			if not ev.shift_pressed:
				get_viewport().set_input_as_handled()
				_submit(_input.text)

func _rebuild_suggestions() -> void:
	for c in _hints_row.get_children():
		c.queue_free()
	# W trybie Mistrza Gry podpowiedzi pochodzą z bieżącej sceny; offline —
	# z puli gatunku.
	var pool: Array = Game.suggestions.duplicate()
	if pool.is_empty():
		pool = (Game.profile().get("suggestions", []) as Array).duplicate()
		pool.shuffle()
	var shown := mini(3, pool.size())
	for i in range(shown):
		var text: String = str(pool[i])
		var chip := Ui.chip_button(text)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_submit.bind(text))
		_hints_row.add_child(chip)
	var vis := shown > 0 and not bool(Game.character.get("dead", false))
	_hints_host.visible = vis
	_hints_lbl.visible = vis

func _submit(text: String) -> void:
	if _busy or bool(Game.character.get("dead", false)):
		return
	text = text.strip_edges()
	if text == "":
		return
	_input.text = ""
	_resize_input()
	_set_busy(true)
	await Game.take_action(text)
	_set_busy(false)
	_render_log()
	_rebuild_suggestions()
	_scroll_to_bottom()

func _set_busy(b: bool) -> void:
	_busy = b
	var dead := bool(Game.character.get("dead", false))
	_send.disabled = b or dead
	_input.editable = not b and not dead
	if dead:
		_status.text = "Kronika dobiegła końca"
	elif b and Narrator.ai_enabled():
		_status.text = "Mistrz Gry myśli…"
	else:
		_status.text = _mode_note()

func _render_log() -> void:
	var out := ""
	var first_scene := true
	for e in Game.history:
		if e["role"] == "player":
			out += "[color=#6d4f12]➤ %s[/color]\n\n" % _esc(e["text"])
		else:
			if e.has("roll"):
				var r: Dictionary = e["roll"]
				out += "[color=#857055]🎲 rzut %d → %s[/color]\n" % [r["die"], r["tier"]]
			var txt := _esc(e["text"])
			if first_scene and txt.length() > 1:
				# Iluminowany inicjał otwierający kronikę, jak w starej księdze.
				out += "[color=#8a6a1f][font_size=%d]%s[/font_size][/color]%s\n\n" % [
					Ui.fs(46), txt.left(1), txt.substr(1)]
				first_scene = false
			else:
				out += "%s\n\n" % txt
				first_scene = false
	_log.text = out.strip_edges()

func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var sc := _log.get_parent() as ScrollContainer
	if sc:
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

func _refresh() -> void:
	_render_log()
	_render_chronicle()
	# Po śmierci bohatera kronika jest zamknięta.
	if bool(Game.character.get("dead", false)):
		_input.editable = false
		_send.disabled = true
		_hints_host.visible = false
		_hints_lbl.visible = false
		_status.text = "Kronika dobiegła końca"

func _render_chronicle() -> void:
	for c in _chronicle.get_children():
		c.queue_free()

	_chronicle.add_child(Ui.heading("Kronika", 20))
	_chronicle.add_child(Ui.subtle("Tura %d" % Game.turn, 13))
	_chronicle.add_child(Ui.hsep())

	_render_hero_card()
	_render_npcs()

	_section("MIEJSCA", Game.locations, func(x): return x["name"], func(x): return x.get("note", ""))
	_section("ODKRYCIA", Game.discoveries, func(x): return x["title"], func(x): return x.get("type", ""))
	_section("WĄTKI", Game.quests, func(x): return x["title"], func(x): return x.get("note", ""))

# ——— Karta bohatera: avatar, zdrowie, mana, poziom, atrybuty ————————

func _render_hero_card() -> void:
	var c := Game.character
	Game.ensure_character_stats()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_chronicle.add_child(head)
	head.add_child(Ui.avatar_or_medallion(c, 52))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(Ui.heading(str(c.get("name", "?")), 18))
	hv.add_child(Ui.subtle("Poziom %d · %s" % [int(c.get("level", 1)), c.get("archetype", "")], 13))

	_stat_row("Zdrowie", int(c.get("hp", 0)), int(c.get("hp_max", 100)), Ui.OXIDE)
	if int(c.get("mana_max", 0)) > 0:
		_stat_row("Mana", int(c.get("mana", 0)), int(c.get("mana_max", 0)), Ui.AZURE)
	_stat_row("PD", int(c.get("xp", 0)), 100 * int(c.get("level", 1)), Ui.GOLD_DIM)

	var pts := int(c.get("attr_points", 0))
	var attrs: Dictionary = c.get("attrs", {})
	if pts > 0:
		_chronicle.add_child(Ui.subtle("PUNKTY ATRYBUTÓW: %d — rozdaj je!" % pts, 12))
	for k in Game.ATTR_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_chronicle.add_child(row)
		var lbl := Ui.subtle("%s: %d" % [Game.ATTR_LABELS[k], int(attrs.get(k, 5))], 13)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
		if pts > 0:
			var plus := Ui.small_button("+")
			plus.custom_minimum_size = Vector2(48, 40)
			plus.add_theme_font_size_override("font_size", Ui.fs(18))
			plus.pressed.connect(Game.spend_attr.bind(k))
			row.add_child(plus)
	_chronicle.add_child(Ui.hsep())

func _stat_row(label: String, val: int, maxv: int, color: Color) -> void:
	var cap := Ui.subtle("%s %d/%d" % [label, val, maxv], 12)
	_chronicle.add_child(cap)
	var bar := Ui.stat_bar(color)
	bar.max_value = maxv
	bar.value = val
	_chronicle.add_child(bar)

# ——— Biblioteka postaci niezależnych ————————————————————————

func _render_npcs() -> void:
	_chronicle.add_child(Ui.subtle("POSTACIE", 12))
	if Game.npcs.is_empty():
		_chronicle.add_child(Ui.subtle("— jeszcze nikogo nie poznałeś —", 13))
	else:
		for n in Game.npcs:
			_chronicle.add_child(_npc_tile(n))
	_chronicle.add_child(Ui.hsep())

# Klikalny kafelek postaci — otwiera jej kartę.
func _npc_tile(n: Dictionary) -> Control:
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.36, 0.27, 0.14, 0.12)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.54, 0.42, 0.20, 0.45)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	tile.add_theme_stylebox_override("panel", sb)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = "Kliknij, aby otworzyć kartę postaci"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tile.add_child(row)
	var med := Ui.medallion(str(n.get("imie", "?")), 28)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(med)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var title_txt := str(n.get("imie", "?"))
	if str(n.get("rola", "")) != "":
		title_txt += " · " + str(n.get("rola", ""))
	v.add_child(Ui.body(title_txt))
	if str(n.get("relacja", "")) != "":
		var rel := Ui.subtle(str(n.get("relacja", "")), 12)
		rel.max_lines_visible = 2
		v.add_child(rel)

	tile.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Audio.click()
			_show_npc_card(n))
	return tile

# Karta postaci — nakładka na cały ekran.
func _show_npc_card(n: Dictionary) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := _paper_card(26)
	card.custom_minimum_size = Vector2(520, 0)
	center.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	head.add_child(Ui.medallion(str(n.get("imie", "?")), 72))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 3)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hv)
	hv.add_child(Ui.heading(str(n.get("imie", "?")), 24))
	if str(n.get("rola", "")) != "":
		hv.add_child(Ui.subtle(str(n.get("rola", "")), 14))

	col.add_child(Ui.hsep())
	if str(n.get("plec", "")) != "":
		col.add_child(Ui.subtle("PŁEĆ", 12))
		col.add_child(Ui.body(str(n.get("plec", "")).capitalize()))
	col.add_child(Ui.subtle("POZNANO", 12))
	col.add_child(Ui.body("Tura %d" % int(n.get("tura", 0))))
	col.add_child(Ui.subtle("RELACJA I UCZUCIA", 12))
	var rel := Ui.body(str(n.get("relacja", "— jeszcze nieznane —")))
	col.add_child(rel)

	col.add_child(Ui.spacer(6))
	var close := Ui.small_button("Zamknij")
	close.pressed.connect(func(): overlay.queue_free())
	col.add_child(close)

	# Kliknięcie w tło również zamyka kartę.
	overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free())

func _section(title: String, items: Array, name_fn: Callable, note_fn: Callable) -> void:
	_chronicle.add_child(Ui.subtle(title, 12))
	if items.is_empty():
		_chronicle.add_child(Ui.subtle("— jeszcze pusto —", 13))
	else:
		for it in items:
			var entry_name := str(name_fn.call(it))
			var line := Ui.body("• " + entry_name)
			_chronicle.add_child(line)
			var note := str(note_fn.call(it))
			if note != "":
				var n := Ui.subtle("   " + note, 12)
				_chronicle.add_child(n)
	_chronicle.add_child(Ui.hsep())

func _on_save() -> void:
	Saves.save_current()
	_status.text = "Zapisano kronikę ✓"
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_status):
		_status.text = _mode_note()

func _on_ai_state(_available: bool, note: String) -> void:
	if is_instance_valid(_status) and not _busy:
		_status.text = note

func _mode_note() -> String:
	match Narrator.provider():
		"claude":
			return "Mistrz Gry: Claude (chmura)"
		"ollama":
			return "Mistrz Gry: %s (lokalnie)" % Game.settings.get("ai_model", "")
	return "Tryb offline · narracja proceduralna"

# Karta na ciemnej nakładce potrzebuje własnego kawałka pergaminu.
func _paper_card(pad := 24) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Ui.PANEL
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(3)
	sb.border_color = Ui.GOLD
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", sb)
	return p
