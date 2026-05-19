# Quiz screen — fluid layout, big character stage at top, question + answers below.

extends Control

const CHARACTER_DISPLAY := preload("res://scenes/CharacterDisplay.tscn")

var _character_slot: Control
var _question_label: Label
var _answer_area: VBoxContainer
var _feedback_box: PanelContainer
var _feedback_label: Label
var _progress_label: Label
var _advance_button: Button


func _ready() -> void:
	_build_layout()
	if PackStore.questions_count() == 0:
		_question_label.text = "퀴즈 팩이 로드되지 않았습니다. 홈으로 돌아가서 선택하세요."
		_render_idle_button()
		return
	_render_question(PackStore.question_index, PackStore.current_question())
	PackStore.question_changed.connect(_render_question)
	PackStore.feedback.connect(_render_feedback)
	PackStore.session_completed.connect(_render_completion)


func _build_layout() -> void:
	# Outer page margin
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 32)
	outer.add_theme_constant_override("margin_right", 32)
	outer.add_theme_constant_override("margin_top", 16)
	outer.add_theme_constant_override("margin_bottom", 24)
	add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	outer.add_child(root)

	# ── Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "← 홈"
	back.custom_minimum_size = Vector2(90, 38)
	back.pressed.connect(_go_home)
	top.add_child(back)

	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(sp)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 16)
	top.add_child(_progress_label)

	# ── Character + boss panel (about 45% of remaining vertical space)
	_character_slot = Control.new()
	_character_slot.custom_minimum_size = Vector2(0, 280)
	_character_slot.size_flags_horizontal = SIZE_EXPAND_FILL
	_character_slot.size_flags_vertical = SIZE_EXPAND_FILL
	_character_slot.visible = not ProgressStore.is_quiet_mode()
	if _character_slot.visible:
		var display := CHARACTER_DISPLAY.instantiate()
		_character_slot.add_child(display)
	root.add_child(_character_slot)

	# ── Question (large, centered, wraps)
	var question_panel := PanelContainer.new()
	question_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	root.add_child(question_panel)

	var q_margin := MarginContainer.new()
	q_margin.add_theme_constant_override("margin_left", 24)
	q_margin.add_theme_constant_override("margin_right", 24)
	q_margin.add_theme_constant_override("margin_top", 18)
	q_margin.add_theme_constant_override("margin_bottom", 18)
	question_panel.add_child(q_margin)

	_question_label = Label.new()
	_question_label.add_theme_font_size_override("font_size", 22)
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_margin.add_child(_question_label)

	# ── Answer area (filled per question)
	_answer_area = VBoxContainer.new()
	_answer_area.size_flags_horizontal = SIZE_EXPAND_FILL
	_answer_area.add_theme_constant_override("separation", 10)
	root.add_child(_answer_area)

	# ── Feedback panel (hidden until first submission)
	_feedback_box = PanelContainer.new()
	_feedback_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_feedback_box.visible = false
	root.add_child(_feedback_box)

	var fb_margin := MarginContainer.new()
	fb_margin.add_theme_constant_override("margin_left", 18)
	fb_margin.add_theme_constant_override("margin_right", 18)
	fb_margin.add_theme_constant_override("margin_top", 12)
	fb_margin.add_theme_constant_override("margin_bottom", 12)
	_feedback_box.add_child(fb_margin)

	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 16)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fb_margin.add_child(_feedback_label)

	# ── Advance button (hidden until feedback)
	var advance_row := HBoxContainer.new()
	advance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(advance_row)

	_advance_button = Button.new()
	_advance_button.text = "다음 ▶"
	_advance_button.custom_minimum_size = Vector2(200, 50)
	_advance_button.add_theme_font_size_override("font_size", 18)
	_advance_button.visible = false
	_advance_button.pressed.connect(_on_advance)
	advance_row.add_child(_advance_button)


func _render_idle_button() -> void:
	for child in _answer_area.get_children():
		child.queue_free()
	var btn := Button.new()
	btn.text = "홈으로"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(_go_home)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(btn)
	_answer_area.add_child(row)


func _render_question(index: int, q: Dictionary) -> void:
	_question_label.text = q.get("q", "(빈 문항)")
	_progress_label.text = "%d / %d" % [index + 1, PackStore.questions_count()]
	_feedback_box.visible = false
	_advance_button.visible = false

	for child in _answer_area.get_children():
		child.queue_free()

	match q.get("type", ""):
		"mcq":
			var choices: Array = q.get("choices", [])
			for i in choices.size():
				var btn := Button.new()
				btn.text = "%d) %s" % [i + 1, str(choices[i])]
				btn.custom_minimum_size = Vector2(0, 48)
				btn.add_theme_font_size_override("font_size", 16)
				btn.size_flags_horizontal = SIZE_EXPAND_FILL
				btn.pressed.connect(_on_submit_mcq.bind(i))
				_answer_area.add_child(btn)
		"ox":
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 32)
			var btn_o := Button.new()
			btn_o.text = "O (true)"
			btn_o.custom_minimum_size = Vector2(180, 70)
			btn_o.add_theme_font_size_override("font_size", 20)
			btn_o.pressed.connect(_on_submit_ox.bind(true))
			row.add_child(btn_o)
			var btn_x := Button.new()
			btn_x.text = "X (false)"
			btn_x.custom_minimum_size = Vector2(180, 70)
			btn_x.add_theme_font_size_override("font_size", 20)
			btn_x.pressed.connect(_on_submit_ox.bind(false))
			row.add_child(btn_x)
			_answer_area.add_child(row)


func _on_submit_mcq(answer_index: int) -> void:
	# Disable all answer buttons so the user can't double-submit while feedback animates.
	_disable_answers()
	PackStore.submit_answer(answer_index)


func _on_submit_ox(answer: bool) -> void:
	_disable_answers()
	PackStore.submit_answer(answer)


func _disable_answers() -> void:
	for child in _answer_area.get_children():
		if child is Button:
			child.disabled = true
		# OX row → disable inner buttons too
		for grandchild in child.get_children():
			if grandchild is Button:
				grandchild.disabled = true


func _render_feedback(correct: bool, explanation: String) -> void:
	_feedback_box.visible = true
	_feedback_box.modulate = Color(0.55, 1.0, 0.6) if correct else Color(1.0, 0.55, 0.55)
	var prefix := "✓ 정답" if correct else "✗ 오답"
	_feedback_label.text = "%s\n\n%s" % [prefix, explanation]
	_advance_button.visible = true


func _on_advance() -> void:
	PackStore.advance()


func _render_completion(record: Dictionary) -> void:
	_question_label.text = "세션 완료"
	_progress_label.text = "%d / %d 정답" % [record.get("correct", 0), record.get("total", 0)]
	for child in _answer_area.get_children():
		child.queue_free()
	_feedback_box.visible = false
	_advance_button.text = "홈으로"
	_advance_button.visible = true
	_advance_button.pressed.disconnect(_on_advance)
	_advance_button.pressed.connect(_go_home)


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
