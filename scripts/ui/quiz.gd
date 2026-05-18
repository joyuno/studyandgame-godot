# Quiz screen — character display + question + answer area + feedback.

extends Control

var _character_slot: Control
var _question_label: Label
var _answer_area: VBoxContainer
var _feedback_box: PanelContainer
var _feedback_label: Label
var _progress_label: Label
var _back_button: Button
var _advance_button: Button

const CHARACTER_DISPLAY := preload("res://scenes/CharacterDisplay.tscn")


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
	var split := VBoxContainer.new()
	split.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	split.anchors_preset = Control.PRESET_FULL_RECT
	add_child(split)

	# ── Top bar
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	split.add_child(top)

	_back_button = Button.new()
	_back_button.text = "← 홈"
	_back_button.pressed.connect(_go_home)
	top.add_child(_back_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(spacer)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	top.add_child(_progress_label)

	# ── Character + boss display (hidden in quiet mode)
	_character_slot = Control.new()
	_character_slot.custom_minimum_size = Vector2(0, 220)
	_character_slot.size_flags_horizontal = SIZE_EXPAND_FILL
	_character_slot.visible = not ProgressStore.is_quiet_mode()
	if _character_slot.visible:
		var display := CHARACTER_DISPLAY.instantiate()
		_character_slot.add_child(display)
	split.add_child(_character_slot)

	# ── Question
	_question_label = Label.new()
	_question_label.add_theme_font_size_override("font_size", 20)
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_child(_question_label)

	# ── Answer area (filled per question)
	_answer_area = VBoxContainer.new()
	_answer_area.add_theme_constant_override("separation", 8)
	split.add_child(_answer_area)

	# ── Feedback panel (hidden until first submission)
	_feedback_box = PanelContainer.new()
	_feedback_box.visible = false
	split.add_child(_feedback_box)
	_feedback_label = Label.new()
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_box.add_child(_feedback_label)

	# ── Advance button (hidden until feedback)
	_advance_button = Button.new()
	_advance_button.text = "다음 ▶"
	_advance_button.custom_minimum_size = Vector2(160, 44)
	_advance_button.visible = false
	_advance_button.pressed.connect(_on_advance)
	split.add_child(_advance_button)


func _render_idle_button() -> void:
	for child in _answer_area.get_children():
		child.queue_free()
	var btn := Button.new()
	btn.text = "홈으로"
	btn.pressed.connect(_go_home)
	_answer_area.add_child(btn)


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
				btn.custom_minimum_size = Vector2(0, 40)
				btn.pressed.connect(_on_submit_mcq.bind(i))
				_answer_area.add_child(btn)
		"ox":
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 16)
			var btn_o := Button.new()
			btn_o.text = "O (true)"
			btn_o.custom_minimum_size = Vector2(140, 60)
			btn_o.pressed.connect(_on_submit_ox.bind(true))
			row.add_child(btn_o)
			var btn_x := Button.new()
			btn_x.text = "X (false)"
			btn_x.custom_minimum_size = Vector2(140, 60)
			btn_x.pressed.connect(_on_submit_ox.bind(false))
			row.add_child(btn_x)
			_answer_area.add_child(row)


func _on_submit_mcq(answer_index: int) -> void:
	for child in _answer_area.get_children():
		child.queue_free()
	PackStore.submit_answer(answer_index)


func _on_submit_ox(answer: bool) -> void:
	for child in _answer_area.get_children():
		child.queue_free()
	PackStore.submit_answer(answer)


func _render_feedback(correct: bool, explanation: String) -> void:
	_feedback_box.visible = true
	_feedback_box.modulate = Color(0.4, 1.0, 0.55) if correct else Color(1.0, 0.5, 0.5)
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
