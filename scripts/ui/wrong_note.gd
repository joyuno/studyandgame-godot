# 오답노트 — 사용자가 틀린 문항을 다시 보고 SRS 등급을 매기는 학습 화면.
#
# ProgressStore.wrong_note 배열을 SRS.is_due(...) 기준으로 정렬해 표시.
# 각 카드는: 팩 제목, 문항, 사용자 답, 정답, 해설, [기억함 / 또 틀림] 버튼.
# [기억함] → SRS.grade_review(true) 호출, 진급. graduate 단계 도달 시 자동 제거.
# [또 틀림] → SRS.grade_review(false) 호출, stage 0으로 리셋.

extends Control

var _list: VBoxContainer
var _empty_label: Label
var _summary_label: Label
var _review_due_button: Button
var _review_all_button: Button


func _ready() -> void:
	_build_layout()
	_refresh()
	ProgressStore.progress_changed.connect(_refresh)


func _build_layout() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 32)
	outer.add_theme_constant_override("margin_right", 32)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 24)
	add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	outer.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "← 홈"
	back.custom_minimum_size = Vector2(90, 38)
	back.pressed.connect(_go_home)
	top.add_child(back)

	var title := Label.new()
	title.text = "📓  오답노트"
	title.add_theme_font_size_override("font_size", 26)
	top.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(sp)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 14)
	_summary_label.modulate = Color(0.7, 0.8, 0.95)
	top.add_child(_summary_label)

	# Review action row — "due only" + "all" replay
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	root.add_child(action_row)

	_review_due_button = Button.new()
	_review_due_button.text = "📚 복습 권장만 다시 풀기"
	_review_due_button.custom_minimum_size = Vector2(220, 44)
	_review_due_button.add_theme_font_size_override("font_size", 15)
	_review_due_button.pressed.connect(_start_review.bind(true))
	action_row.add_child(_review_due_button)

	_review_all_button = Button.new()
	_review_all_button.text = "📚 전체 다시 풀기"
	_review_all_button.custom_minimum_size = Vector2(180, 44)
	_review_all_button.add_theme_font_size_override("font_size", 15)
	_review_all_button.pressed.connect(_start_review.bind(false))
	action_row.add_child(_review_all_button)

	# Scrollable list of cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)

	_empty_label = Label.new()
	_empty_label.text = "오답이 없습니다 — 퀴즈를 풀면 여기에 쌓입니다."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.modulate = Color(0.6, 0.65, 0.8)
	_empty_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_empty_label)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var wrong: Array = ProgressStore.get_wrong_note().duplicate()
	# Due first, then by timesWrong desc, then by lastWrongAt desc.
	wrong.sort_custom(func(a, b):
		var a_due := SRS.is_due(a.get("nextReviewAt", ""))
		var b_due := SRS.is_due(b.get("nextReviewAt", ""))
		if a_due != b_due:
			return a_due  # due before not-due
		var a_times := int(a.get("timesWrong", 0))
		var b_times := int(b.get("timesWrong", 0))
		if a_times != b_times:
			return a_times > b_times
		return String(a.get("lastWrongAt", "")) > String(b.get("lastWrongAt", ""))
	)
	var due_count := 0
	for entry in wrong:
		if SRS.is_due(entry.get("nextReviewAt", "")):
			due_count += 1
	_summary_label.text = "전체 %d개  ·  복습 권장 %d개" % [wrong.size(), due_count]
	_empty_label.visible = wrong.is_empty()
	_review_due_button.disabled = due_count == 0
	_review_all_button.disabled = wrong.is_empty()
	for entry in wrong:
		_list.add_child(_make_card(entry))


func _make_card(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	# Header line: pack title + times wrong + due/snooze badge
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var pack_label := Label.new()
	pack_label.text = entry.get("packTitle", "(팩 정보 없음)")
	pack_label.add_theme_font_size_override("font_size", 13)
	pack_label.modulate = Color(0.7, 0.8, 0.95)
	header.add_child(pack_label)

	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(sp)

	var meta_label := Label.new()
	var due_str := "🔴 복습" if SRS.is_due(entry.get("nextReviewAt", "")) else "🕒 다음 복습 대기"
	meta_label.text = "%s  ·  %d회 오답  ·  Lv %d" % [
		due_str, int(entry.get("timesWrong", 0)), int(entry.get("reviewLevel", 0)),
	]
	meta_label.add_theme_font_size_override("font_size", 12)
	meta_label.modulate = Color(0.85, 0.85, 0.9)
	header.add_child(meta_label)

	# Question text
	var q_snapshot: Dictionary = entry.get("questionSnapshot", {})
	var q_label := Label.new()
	q_label.text = q_snapshot.get("q", "(문항 없음)")
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.add_theme_font_size_override("font_size", 16)
	box.add_child(q_label)

	# Choices (mcq) or O/X
	match q_snapshot.get("type", ""):
		"mcq":
			var choices: Array = q_snapshot.get("choices", [])
			var ans_idx := int(q_snapshot.get("answer", -1))
			var user_ans := int(entry.get("userAnswer", -1))
			for i in choices.size():
				var line := Label.new()
				var prefix := ""
				if i == ans_idx:
					prefix = "✓ "
				elif i == user_ans:
					prefix = "✗ "
				else:
					prefix = "   "
				line.text = "%s%d) %s" % [prefix, i + 1, str(choices[i])]
				line.add_theme_font_size_override("font_size", 14)
				if i == ans_idx:
					line.modulate = Color(0.6, 1.0, 0.7)
				elif i == user_ans:
					line.modulate = Color(1.0, 0.6, 0.6)
				box.add_child(line)
		"ox":
			var truth := bool(q_snapshot.get("answer", false))
			var user_b := bool(entry.get("userAnswer", false))
			var line := Label.new()
			line.text = "정답: %s   ·   당신의 답: %s" % [
				"O" if truth else "X", "O" if user_b else "X",
			]
			line.add_theme_font_size_override("font_size", 14)
			box.add_child(line)

	# Explanation
	var expl: String = String(q_snapshot.get("explanation", ""))
	if not expl.is_empty():
		var sep := HSeparator.new()
		box.add_child(sep)
		var expl_label := Label.new()
		expl_label.text = expl
		expl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		expl_label.add_theme_font_size_override("font_size", 13)
		expl_label.modulate = Color(0.8, 0.85, 0.95)
		box.add_child(expl_label)

	# Actions
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)

	var hash_key: String = entry.get("questionHash", "")
	var review_level := int(entry.get("reviewLevel", 0))

	var btn_remember := Button.new()
	btn_remember.text = "✓ 기억함"
	btn_remember.custom_minimum_size = Vector2(120, 36)
	btn_remember.pressed.connect(func(): _grade(hash_key, review_level, true))
	actions.add_child(btn_remember)

	var btn_forget := Button.new()
	btn_forget.text = "✗ 또 틀림"
	btn_forget.custom_minimum_size = Vector2(120, 36)
	btn_forget.pressed.connect(func(): _grade(hash_key, review_level, false))
	actions.add_child(btn_forget)

	var btn_delete := Button.new()
	btn_delete.text = "🗑 제거"
	btn_delete.custom_minimum_size = Vector2(90, 36)
	btn_delete.pressed.connect(func(): ProgressStore.remove_wrong_entry(hash_key))
	actions.add_child(btn_delete)

	return panel


func _grade(hash_key: String, review_level: int, correct: bool) -> void:
	var next_state := SRS.grade_review(review_level, correct)
	if next_state.is_empty():
		# Graduated — remove from wrong note.
		ProgressStore.remove_wrong_entry(hash_key)
	else:
		ProgressStore.update_wrong_entry_srs(
			hash_key,
			int(next_state.get("review_level", review_level)),
			String(next_state.get("next_review_at", "")),
		)


func _start_review(due_only: bool) -> void:
	var all_entries: Array = ProgressStore.get_wrong_note()
	var entries: Array = []
	for e in all_entries:
		if due_only and not SRS.is_due(e.get("nextReviewAt", "")):
			continue
		entries.append(e)
	if entries.is_empty():
		return
	if PackStore.load_review_session(entries):
		get_tree().change_scene_to_file("res://scenes/Quiz.tscn")


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
