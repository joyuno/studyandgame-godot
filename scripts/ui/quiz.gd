# Quiz screen — sword preview + question + answers + live HUD.
#
# v0.5 HUD: 문항 타이머 바, 세션 누적 시간, 콤보 카운터(🔥 On Fire), 검 내구도 바,
# 보너스 강화권 토스트. quiet/timer 설정과 글자 크기 스케일은 ProgressStore에서 읽음.
#
# v0.5.1 폴리시:
#  - 기초검(+0)은 부러지지 않으므로 durability bar 대신 "🛡 기초검 보호" 표시
#  - 문항 폰트 26 (가독성), 답 버튼 키움 (높이 58, 폰트 18)
#  - 답 버튼 카드 스타일 stylebox 직접 지정 (구분 강화)
#  - feedback panel 좌측 컬러바 + 큰 아이콘, 보너스 토스트 fade tween
#  - 콤보 ON FIRE 펄스 애니메이션

extends Control

const SWORD_DISPLAY := preload("res://scenes/SwordDisplay.tscn")

const FONT_SCALE_FACTOR := [0.85, 1.0, 1.2]  # 0=small, 1=medium, 2=large

var _sword_slot: Control
var _question_label: Label
var _question_panel: PanelContainer
var _answer_area: VBoxContainer
var _feedback_box: PanelContainer
var _feedback_label: Label
var _feedback_icon: Label
var _progress_label: Label
var _copy_button: Button
var _tickets_label: Label
var _session_time_label: Label
var _combo_label: Label
var _advance_button: Button
var _question_timer: ProgressBar
var _durability_bar: ProgressBar
var _durability_label: Label
var _durability_row: HBoxContainer
var _bonus_toast: Label
var _toast_tween: Tween
var _fire_tween: Tween

# Cached scales so we can re-apply when font size changes.
var _font_sizes := {
	"question": 26, "answer": 18, "feedback": 17,
	"hud": 16, "combo": 18, "advance": 19, "back": 0,
}


func _ready() -> void:
	_build_layout()
	_apply_font_scale()
	if PackStore.questions_count() == 0:
		_question_label.text = "퀴즈 팩이 로드되지 않았습니다. 홈으로 돌아가서 선택하세요."
		_render_idle_button()
		_question_timer.visible = false
		_durability_row.visible = false
		_copy_button.disabled = true
		set_process(false)
		return
	_render_question(PackStore.question_index, PackStore.current_question())
	_apply_durability_view()
	PackStore.question_changed.connect(_render_question)
	PackStore.feedback.connect(_render_feedback)
	PackStore.session_completed.connect(_render_completion)
	PackStore.combo_changed.connect(_render_combo)
	PackStore.durability_changed.connect(_render_durability)
	PackStore.sword_broken.connect(_flash_sword_broken)
	ProgressStore.tickets_changed.connect(func(_n): _update_ticket_counter())
	ProgressStore.timer_enabled_changed.connect(func(_e): _apply_timer_visibility())
	ProgressStore.font_size_scale_changed.connect(func(_s): _apply_font_scale())
	ProgressStore.weapon_changed.connect(func(_lv): _apply_durability_view())
	_apply_timer_visibility()


func _build_layout() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 40)
	outer.add_theme_constant_override("margin_right", 40)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 24)
	add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	outer.add_child(root)

	# ── Top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)

	var back := Button.new()
	back.text = "← 홈"
	back.custom_minimum_size = Vector2(82, 36)
	back.pressed.connect(_go_home)
	top.add_child(back)

	if PackStore.is_review_mode:
		var badge := Label.new()
		badge.text = "📚 복습 모드"
		badge.add_theme_font_size_override("font_size", _font_sizes["hud"])
		badge.modulate = Color(0.85, 0.7, 1.0)
		top.add_child(badge)

	_session_time_label = Label.new()
	_session_time_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_session_time_label.modulate = Color(0.78, 0.85, 0.95)
	top.add_child(_session_time_label)

	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", _font_sizes["combo"])
	_combo_label.modulate = Color(0.85, 0.9, 1.0)
	_combo_label.visible = false
	top.add_child(_combo_label)

	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(sp)

	_tickets_label = Label.new()
	_tickets_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_tickets_label.modulate = Color(0.7, 1.0, 0.85)
	top.add_child(_tickets_label)
	_update_ticket_counter()

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	top.add_child(_progress_label)

	_copy_button = Button.new()
	_copy_button.text = "📋 복사"
	_copy_button.tooltip_text = "현재 문항을 클립보드로 복사 (답한 뒤에는 정답·해설 포함)"
	_copy_button.custom_minimum_size = Vector2(82, 36)
	_copy_button.pressed.connect(_on_copy_question)
	top.add_child(_copy_button)

	# ── Question timer bar (per-question countdown)
	_question_timer = ProgressBar.new()
	_question_timer.show_percentage = false
	_question_timer.custom_minimum_size = Vector2(0, 8)
	_question_timer.modulate = Color(0.55, 0.85, 1.0)
	root.add_child(_question_timer)

	# ── Sword durability row (or base sword protection badge)
	_durability_row = HBoxContainer.new()
	_durability_row.add_theme_constant_override("separation", 10)
	root.add_child(_durability_row)

	_durability_label = Label.new()
	_durability_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_durability_label.modulate = Color(0.95, 0.7, 0.6)
	_durability_row.add_child(_durability_label)

	_durability_bar = ProgressBar.new()
	_durability_bar.show_percentage = false
	_durability_bar.max_value = PackStore.SWORD_DURABILITY_THRESHOLD
	_durability_bar.value = 0
	_durability_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	_durability_bar.custom_minimum_size = Vector2(0, 10)
	_durability_bar.modulate = Color(1.0, 0.6, 0.55)
	_durability_row.add_child(_durability_bar)
	if PackStore.is_review_mode:
		_durability_row.visible = false

	# ── Sword preview (collapses under 차분 모드)
	_sword_slot = Control.new()
	_sword_slot.custom_minimum_size = Vector2(0, 170)
	_sword_slot.size_flags_horizontal = SIZE_EXPAND_FILL
	_sword_slot.visible = not ProgressStore.is_quiet_mode()
	if _sword_slot.visible:
		var display := SWORD_DISPLAY.instantiate()
		_sword_slot.add_child(display)
	root.add_child(_sword_slot)

	# ── Question panel (larger, accent border)
	_question_panel = PanelContainer.new()
	_question_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_question_panel.add_theme_stylebox_override("panel", _question_stylebox())
	root.add_child(_question_panel)

	var q_margin := MarginContainer.new()
	q_margin.add_theme_constant_override("margin_left", 32)
	q_margin.add_theme_constant_override("margin_right", 32)
	q_margin.add_theme_constant_override("margin_top", 26)
	q_margin.add_theme_constant_override("margin_bottom", 26)
	_question_panel.add_child(q_margin)

	_question_label = Label.new()
	_question_label.add_theme_font_size_override("font_size", _font_sizes["question"])
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_margin.add_child(_question_label)

	# ── Answer area
	_answer_area = VBoxContainer.new()
	_answer_area.size_flags_horizontal = SIZE_EXPAND_FILL
	_answer_area.add_theme_constant_override("separation", 12)
	root.add_child(_answer_area)

	# ── Feedback panel (with icon + colored left bar)
	_feedback_box = PanelContainer.new()
	_feedback_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_feedback_box.visible = false
	root.add_child(_feedback_box)

	var fb_margin := MarginContainer.new()
	fb_margin.add_theme_constant_override("margin_left", 22)
	fb_margin.add_theme_constant_override("margin_right", 22)
	fb_margin.add_theme_constant_override("margin_top", 14)
	fb_margin.add_theme_constant_override("margin_bottom", 14)
	_feedback_box.add_child(fb_margin)

	var fb_row := HBoxContainer.new()
	fb_row.add_theme_constant_override("separation", 14)
	fb_margin.add_child(fb_row)

	_feedback_icon = Label.new()
	_feedback_icon.add_theme_font_size_override("font_size", 32)
	_feedback_icon.size_flags_vertical = SIZE_SHRINK_BEGIN
	fb_row.add_child(_feedback_icon)

	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", _font_sizes["feedback"])
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.size_flags_horizontal = SIZE_EXPAND_FILL
	fb_row.add_child(_feedback_label)

	# ── Bonus toast (animated)
	_bonus_toast = Label.new()
	_bonus_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bonus_toast.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_bonus_toast.modulate = Color(1.0, 0.95, 0.6, 0)
	root.add_child(_bonus_toast)

	# ── Advance button
	var advance_row := HBoxContainer.new()
	advance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(advance_row)

	_advance_button = Button.new()
	_advance_button.text = "다음 ▶"
	_advance_button.custom_minimum_size = Vector2(220, 54)
	_advance_button.add_theme_font_size_override("font_size", _font_sizes["advance"])
	_advance_button.visible = false
	_advance_button.pressed.connect(_on_advance)
	advance_row.add_child(_advance_button)


func _question_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18)
	sb.border_color = Color(0.38, 0.45, 0.62)
	sb.set_border_width_all(1)
	sb.border_width_left = 4  # accent bar on left
	sb.border_color = Color(0.38, 0.55, 0.85)
	sb.set_corner_radius_all(10)
	return sb


func _feedback_stylebox(correct: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if correct:
		sb.bg_color = Color(0.10, 0.20, 0.13)
		sb.border_color = Color(0.35, 0.85, 0.55)
	else:
		sb.bg_color = Color(0.22, 0.10, 0.10)
		sb.border_color = Color(0.95, 0.45, 0.45)
	sb.border_width_left = 5
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(10)
	return sb


func _answer_stylebox(hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.17, 0.24) if not hover else Color(0.18, 0.24, 0.34)
	sb.border_color = Color(0.40, 0.52, 0.72) if hover else Color(0.30, 0.36, 0.48)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _process(_dt: float) -> void:
	# Live HUD ticks: session time + question countdown bar.
	if PackStore.session_started_at_unix > 0.0:
		_session_time_label.text = "⏱ %s" % _fmt_time(PackStore.session_elapsed_seconds())
	if not _question_timer.visible:
		return
	if PackStore.phase == "IN_QUESTION":
		var limit := PackStore.question_time_limit()
		var remaining := PackStore.time_remaining_for_question()
		_question_timer.max_value = limit
		_question_timer.value = remaining
		var ratio := remaining / maxf(0.001, limit)
		_question_timer.modulate = Color(1.0, ratio, ratio) if ratio < 0.4 else Color(0.55, 0.85, 1.0)
	else:
		_question_timer.value = 0


func _apply_timer_visibility() -> void:
	_question_timer.visible = ProgressStore.is_timer_enabled()


func _apply_font_scale() -> void:
	var idx: int = ProgressStore.get_font_size_scale()
	var f: float = FONT_SCALE_FACTOR[clampi(idx, 0, 2)]
	for k in _font_sizes:
		_font_sizes[k] = int(round(_default_size(k) * f))
	if _question_label: _question_label.add_theme_font_size_override("font_size", _font_sizes["question"])
	if _feedback_label: _feedback_label.add_theme_font_size_override("font_size", _font_sizes["feedback"])
	if _session_time_label: _session_time_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	if _combo_label: _combo_label.add_theme_font_size_override("font_size", _font_sizes["combo"])
	if _tickets_label: _tickets_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	if _progress_label: _progress_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	if _durability_label: _durability_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	if _advance_button: _advance_button.add_theme_font_size_override("font_size", _font_sizes["advance"])
	if _bonus_toast: _bonus_toast.add_theme_font_size_override("font_size", _font_sizes["hud"])


func _default_size(key: String) -> int:
	match key:
		"question": return 26
		"answer":   return 18
		"feedback": return 17
		"hud":      return 16
		"combo":    return 18
		"advance":  return 19
	return 16


func _fmt_time(secs: float) -> String:
	var s := int(secs)
	return "%d:%02d" % [s / 60, s % 60]


func _update_ticket_counter() -> void:
	_tickets_label.text = "강화권 %d" % ProgressStore.get_enhance_tickets()


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
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_bonus_toast.modulate.a = 0

	for child in _answer_area.get_children():
		child.queue_free()

	match q.get("type", ""):
		"mcq":
			var choices: Array = q.get("choices", [])
			for i in choices.size():
				var btn := Button.new()
				btn.text = "  %d.  %s" % [i + 1, str(choices[i])]
				btn.custom_minimum_size = Vector2(0, 58)
				btn.add_theme_font_size_override("font_size", _font_sizes["answer"])
				btn.add_theme_stylebox_override("normal", _answer_stylebox(false))
				btn.add_theme_stylebox_override("hover", _answer_stylebox(true))
				btn.add_theme_stylebox_override("pressed", _answer_stylebox(true))
				btn.add_theme_stylebox_override("focus", _answer_stylebox(true))
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.size_flags_horizontal = SIZE_EXPAND_FILL
				btn.pressed.connect(_on_submit_mcq.bind(i))
				_answer_area.add_child(btn)
		"ox":
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 40)
			var btn_o := Button.new()
			btn_o.text = "O"
			btn_o.custom_minimum_size = Vector2(200, 88)
			btn_o.add_theme_font_size_override("font_size", int(round(_font_sizes["answer"] * 1.8)))
			btn_o.add_theme_stylebox_override("normal", _answer_stylebox(false))
			btn_o.add_theme_stylebox_override("hover", _answer_stylebox(true))
			btn_o.pressed.connect(_on_submit_ox.bind(true))
			row.add_child(btn_o)
			var btn_x := Button.new()
			btn_x.text = "X"
			btn_x.custom_minimum_size = Vector2(200, 88)
			btn_x.add_theme_font_size_override("font_size", int(round(_font_sizes["answer"] * 1.8)))
			btn_x.add_theme_stylebox_override("normal", _answer_stylebox(false))
			btn_x.add_theme_stylebox_override("hover", _answer_stylebox(true))
			btn_x.pressed.connect(_on_submit_ox.bind(false))
			row.add_child(btn_x)
			_answer_area.add_child(row)


func _on_submit_mcq(answer_index: int) -> void:
	_disable_answers()
	PackStore.submit_answer(answer_index)


func _on_submit_ox(answer: bool) -> void:
	_disable_answers()
	PackStore.submit_answer(answer)


func _disable_answers() -> void:
	for child in _answer_area.get_children():
		if child is Button:
			child.disabled = true
		for grandchild in child.get_children():
			if grandchild is Button:
				grandchild.disabled = true


func _render_feedback(correct: bool, explanation: String, info: Dictionary) -> void:
	_feedback_box.visible = true
	_feedback_box.add_theme_stylebox_override("panel", _feedback_stylebox(correct))
	_feedback_icon.text = "✓" if correct else "✗"
	_feedback_icon.modulate = Color(0.4, 1.0, 0.6) if correct else Color(1.0, 0.55, 0.55)
	var prefix := "정답  (+1 강화권)" if correct else "오답"
	_feedback_label.text = "%s\n\n%s" % [prefix, explanation]
	_advance_button.visible = true
	var bonuses: Array = info.get("bonuses", [])
	if not bonuses.is_empty():
		_show_toast("  •  ".join(bonuses), Color(1.0, 0.95, 0.6))


func _show_toast(text: String, tint: Color) -> void:
	_bonus_toast.text = text
	_bonus_toast.modulate = Color(tint.r, tint.g, tint.b, 0)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_bonus_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_bonus_toast, "modulate:a", 0.0, 0.6)


func _render_combo(combo: int, on_fire: bool) -> void:
	if combo <= 1:
		_combo_label.visible = false
		if _fire_tween and _fire_tween.is_valid():
			_fire_tween.kill()
		return
	_combo_label.visible = true
	if on_fire:
		_combo_label.text = "🔥 %d 콤보 ON FIRE" % combo
		_combo_label.modulate = Color(1.0, 0.7, 0.3)
		# Pulse animation
		if _fire_tween and _fire_tween.is_valid():
			_fire_tween.kill()
		_fire_tween = create_tween().set_loops()
		_fire_tween.tween_property(_combo_label, "modulate", Color(1.0, 0.85, 0.45), 0.5)
		_fire_tween.tween_property(_combo_label, "modulate", Color(1.0, 0.65, 0.25), 0.5)
	else:
		_combo_label.text = "콤보 %d" % combo
		_combo_label.modulate = Color(0.85, 0.9, 1.0)
		if _fire_tween and _fire_tween.is_valid():
			_fire_tween.kill()


func _apply_durability_view() -> void:
	# Base sword (+0) is protected — no durability tracking, no scary bar.
	# Show a friendly "shield" badge instead so the player understands the floor.
	var lv := ProgressStore.get_weapon_level()
	if PackStore.is_review_mode:
		_durability_row.visible = false
		return
	_durability_row.visible = true
	if lv <= 0:
		_durability_bar.visible = false
		_durability_label.modulate = Color(0.7, 0.95, 0.85)
		_durability_label.text = "🛡 기초검 보호 — 부러지지 않음"
	else:
		_durability_bar.visible = true
		_durability_label.modulate = Color(0.95, 0.75, 0.65)
		_render_durability(PackStore.session_wrong_count, PackStore.SWORD_DURABILITY_THRESHOLD)


func _render_durability(wrong_count: int, threshold: int) -> void:
	if not _durability_bar.visible:
		return
	_durability_bar.max_value = threshold
	_durability_bar.value = wrong_count
	var remaining := threshold - wrong_count
	_durability_label.text = "🛡 검 내구도 %d/%d" % [remaining, threshold]


func _flash_sword_broken() -> void:
	_show_toast("💥 검이 부러졌습니다 — 검 -1 강제 강등", Color(1.0, 0.4, 0.4))
	# Update view in case sword fell to +0 (base protection).
	_apply_durability_view()


func _on_copy_question() -> void:
	# Copy the live question. Once the learner has answered (feedback panel is
	# up) include the correct answer + explanation so the clipboard is a full
	# study note; otherwise copy just the prompt + choices.
	var q := PackStore.current_question()
	if q.is_empty():
		return
	var answered := _feedback_box.visible
	DisplayServer.clipboard_set(_format_question_for_copy(q, answered))
	_show_toast("📋 클립보드에 복사됨", Color(0.7, 0.95, 1.0))


func _format_question_for_copy(q: Dictionary, include_answer: bool) -> String:
	var lines: Array[String] = []
	lines.append(String(q.get("q", "")))
	match q.get("type", ""):
		"mcq":
			var choices: Array = q.get("choices", [])
			var ans_idx := int(q.get("answer", -1))
			for i in choices.size():
				var mark := "  ✓" if (include_answer and i == ans_idx) else ""
				lines.append("%d) %s%s" % [i + 1, str(choices[i]), mark])
		"ox":
			lines.append("(O / X)")
			if include_answer:
				lines.append("정답: %s" % ("O" if bool(q.get("answer", false)) else "X"))
	if include_answer:
		var expl := String(q.get("explanation", ""))
		if not expl.is_empty():
			lines.append("")
			lines.append("해설: %s" % expl)
	return "\n".join(lines)


func _on_advance() -> void:
	PackStore.advance()


func _render_completion(record: Dictionary) -> void:
	_question_label.text = "세션 완료"
	_progress_label.text = "%d / %d 정답  ·  최고 콤보 %d" % [
		record.get("correct", 0), record.get("total", 0), record.get("bestCombo", 0),
	]
	for child in _answer_area.get_children():
		child.queue_free()
	_feedback_box.visible = false
	_question_timer.visible = false
	_copy_button.visible = false
	_advance_button.text = "📓 오답노트로" if PackStore.is_review_mode else "홈으로"
	_advance_button.visible = true
	_advance_button.pressed.disconnect(_on_advance)
	if PackStore.is_review_mode:
		_advance_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/WrongNote.tscn"))
	else:
		_advance_button.pressed.connect(_go_home)


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
