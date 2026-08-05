class_name PlayScreen
extends Control

var _log: RichTextLabel
var _input: TextEdit
var _send: Button
var _suggest_box: VBoxContainer
var _chronicle: VBoxContainer
var _status: Label
var _busy := false

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_build_topbar())

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	# Lewa kolumna: narracja + akcja.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.3
	split.add_child(left)

	var log_card := Ui.card(18)
	log_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(log_card)

	var log_scroll := ScrollContainer.new()
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_card.add_child(log_scroll)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("line_separation", 6)
	log_scroll.add_child(_log)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL

	left.add_child(_build_action_bar())

	# Prawa kolumna: Kronika.
	var right := Ui.card(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.custom_minimum_size = Vector2(280, 0)
	split.add_child(right)

	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(right_scroll)

	_chronicle = VBoxContainer.new()
	_chronicle.add_theme_constant_override("separation", 10)
	_chronicle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_chronicle)

	Game.chronicle_changed.connect(_refresh)
	Narrator.ai_state.connect(_on_ai_state)
	_refresh()
	_scroll_to_bottom()

func _build_topbar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	bar.custom_minimum_size = Vector2(0, 46)

	# W poziomym pasku etykiety NIE mogą mieć autozawijania — inaczej Godot
	# zwęża je do jednej litery i rozdmuchuje wysokość całego paska.
	var title := _plain(Game.world.get("name", "Kronika"), 22, Ui.INK)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(title)

	var tag := _plain("· %s" % Game.world.get("genre_label", ""), 15, Ui.MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(tag)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)

	_status = _plain(_mode_note(), 13, Ui.MUTED)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)

	var save := Ui.button("Zapisz")
	save.custom_minimum_size = Vector2(110, 40)
	save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	save.pressed.connect(_on_save)
	bar.add_child(save)

	var menu := Ui.button("Menu")
	menu.custom_minimum_size = Vector2(90, 40)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func(): Game.router.goto("menu"))
	bar.add_child(menu)
	return bar

# Etykieta bez zawijania — do poziomego paska.
func _plain(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _build_action_bar() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	_suggest_box = VBoxContainer.new()
	_suggest_box.add_theme_constant_override("separation", 8)
	box.add_child(_suggest_box)
	_rebuild_suggestions()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	# Pole akcji: zawija długi tekst i rośnie do trzech linii.
	_input = TextEdit.new()
	_input.placeholder_text = "Opisz, co robi Twoja postać…"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.scroll_fit_content_height = true
	_input.custom_minimum_size = Vector2(0, _input_height(1))
	_input.text_changed.connect(_resize_input)
	_input.gui_input.connect(_input_gui)
	row.add_child(_input)

	_send = Ui.button("Wykonaj", true)
	_send.custom_minimum_size = Vector2(130, 46)
	_send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_send.pressed.connect(func(): _submit(_input.text))
	row.add_child(_send)
	return box

# Wysokość pola dla danej liczby linii (z marginesami stylu).
func _input_height(lines: int) -> int:
	return int(_input.get_line_height() * lines + Ui.fs(22))

# Rośnie razem z tekstem, maksymalnie do trzech linii.
func _resize_input() -> void:
	var lines := clampi(_input.get_line_count(), 1, 3)
	# Zawijanie tworzy dodatkowe linie wizualne — uwzględnij je.
	var visual := 0
	for i in range(_input.get_line_count()):
		visual += _input.get_line_wrap_count(i) + 1
	lines = clampi(maxi(lines, visual), 1, 3)
	_input.custom_minimum_size = Vector2(0, _input_height(lines))

# Enter wysyła akcję; Shift+Enter przechodzi do nowej linii.
func _input_gui(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			if not ev.shift_pressed:
				get_viewport().set_input_as_handled()
				_submit(_input.text)

func _rebuild_suggestions() -> void:
	for c in _suggest_box.get_children():
		c.queue_free()
	# W trybie Mistrza Gry podpowiedzi pochodzą z bieżącej sceny; offline —
	# z puli gatunku.
	var pool: Array = Game.suggestions.duplicate()
	if pool.is_empty():
		pool = (Game.profile().get("suggestions", []) as Array).duplicate()
		pool.shuffle()
	if pool.is_empty():
		return
	_suggest_box.add_child(Ui.subtle("PODPOWIEDZI", 12))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	_suggest_box.add_child(grid)
	for i in range(mini(3, pool.size())):
		var text: String = str(pool[i])
		var chip := Ui.button(text)
		chip.custom_minimum_size = Vector2(0, 40)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 15)
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip.pressed.connect(_submit.bind(text))
		grid.add_child(chip)

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
	for e in Game.history:
		if e["role"] == "player":
			out += "[color=#cfa24a]➤ %s[/color]\n\n" % _esc(e["text"])
		else:
			if e.has("roll"):
				var r: Dictionary = e["roll"]
				out += "[color=#8a7f68]🎲 rzut %d → %s[/color]\n" % [r["die"], r["tier"]]
			out += "%s\n\n" % _esc(e["text"])
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
		_suggest_box.visible = false
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
			var plus := Ui.button("+")
			plus.custom_minimum_size = Vector2(34, 30)
			plus.add_theme_font_size_override("font_size", 15)
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
	sb.bg_color = Ui.BG_SOFT
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Ui.LINE
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

	var card := Ui.card(22)
	card.custom_minimum_size = Vector2(440, 0)
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
	var close := Ui.button("Zamknij")
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
