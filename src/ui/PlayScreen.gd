class_name PlayScreen
extends Control

var _log: RichTextLabel
var _input: LineEdit
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

	var title := Ui.heading(Game.world.get("name", "Kronika"), 22)
	bar.add_child(title)

	var tag := Ui.subtle("· %s" % Game.world.get("genre_label", ""), 15)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(tag)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)

	_status = Ui.subtle(_mode_note(), 13)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)

	var save := Ui.button("Zapisz")
	save.custom_minimum_size = Vector2(110, 40)
	save.pressed.connect(_on_save)
	bar.add_child(save)

	var menu := Ui.button("Menu")
	menu.custom_minimum_size = Vector2(90, 40)
	menu.pressed.connect(func(): Game.router.goto("menu"))
	bar.add_child(menu)
	return bar

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

	_input = LineEdit.new()
	_input.placeholder_text = "Opisz, co robi Twoja postać…"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t): _submit(_input.text))
	row.add_child(_input)

	_send = Ui.button("Wykonaj", true)
	_send.custom_minimum_size = Vector2(130, 46)
	_send.pressed.connect(func(): _submit(_input.text))
	row.add_child(_send)
	return box

func _rebuild_suggestions() -> void:
	for c in _suggest_box.get_children():
		c.queue_free()
	var prof := Game.profile()
	var pool: Array = (prof.get("suggestions", []) as Array).duplicate()
	pool.shuffle()
	var lbl := Ui.subtle("PODPOWIEDZI", 12)
	_suggest_box.add_child(lbl)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	_suggest_box.add_child(grid)
	for i in range(min(3, pool.size())):
		var text: String = pool[i]
		var chip := Ui.button(text)
		chip.custom_minimum_size = Vector2(0, 40)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 15)
		chip.pressed.connect(_submit.bind(text))
		grid.add_child(chip)

func _submit(text: String) -> void:
	if _busy:
		return
	text = text.strip_edges()
	if text == "":
		return
	_input.text = ""
	_set_busy(true)
	await Game.take_action(text)
	_set_busy(false)
	_render_log()
	_rebuild_suggestions()
	_scroll_to_bottom()

func _set_busy(b: bool) -> void:
	_busy = b
	_send.disabled = b
	_input.editable = not b
	if b and Narrator.ai_enabled():
		_status.text = "Narrator myśli…"
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

func _render_chronicle() -> void:
	for c in _chronicle.get_children():
		c.queue_free()

	_chronicle.add_child(Ui.heading("Kronika", 20))
	_chronicle.add_child(Ui.subtle("Tura %d" % Game.turn, 13))
	_chronicle.add_child(Ui.hsep())

	# Postać.
	_chronicle.add_child(Ui.subtle("BOHATER", 12))
	_chronicle.add_child(Ui.body("%s — %s" % [Game.character.get("name", "?"), Game.character.get("archetype", "")]))
	if Game.character.get("goal", "") != "":
		_chronicle.add_child(Ui.subtle("Cel: %s" % Game.character["goal"], 13))
	_chronicle.add_child(Ui.hsep())

	_section("MIEJSCA", Game.locations, func(x): return x["name"], func(x): return x.get("note", ""))
	_section("ODKRYCIA", Game.discoveries, func(x): return x["title"], func(x): return x.get("type", ""))
	_section("WĄTKI", Game.quests, func(x): return x["title"], func(x): return x.get("note", ""))

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
	if Narrator.ai_enabled():
		return "Tryb AI · %s" % Game.settings.get("ai_model", "")
	return "Tryb offline · narracja proceduralna"
