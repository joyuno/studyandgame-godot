# 설정 패널 — 글자 크기 · 차분 모드 · 문항 타이머 ON/OFF.
# 값은 ProgressStore에 영구 저장되며 신호로 다른 화면에 즉시 반영.

extends Control

const SIZE_LABELS := ["작게", "보통", "크게"]


func _ready() -> void:
	_build_layout()


func _build_layout() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 48)
	outer.add_theme_constant_override("margin_right", 48)
	outer.add_theme_constant_override("margin_top", 32)
	outer.add_theme_constant_override("margin_bottom", 32)
	add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	outer.add_child(root)

	# Top bar
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := Button.new()
	back.text = "← 홈"
	back.custom_minimum_size = Vector2(90, 38)
	back.pressed.connect(_go_home)
	top.add_child(back)

	var title := Label.new()
	title.text = "⚙  설정"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# Font size
	var font_box := _panel("글자 크기", "퀴즈 화면 전반의 문항·보기·HUD 텍스트 크기.")
	root.add_child(font_box["panel"])
	var font_row := HBoxContainer.new()
	font_row.add_theme_constant_override("separation", 12)
	font_box["body"].add_child(font_row)
	var font_group := ButtonGroup.new()
	var current_size := ProgressStore.get_font_size_scale()
	for i in SIZE_LABELS.size():
		var b := Button.new()
		b.text = SIZE_LABELS[i]
		b.toggle_mode = true
		b.button_group = font_group
		b.custom_minimum_size = Vector2(110, 44)
		b.button_pressed = (i == current_size)
		var capture := i
		b.pressed.connect(func(): ProgressStore.set_font_size_scale(capture))
		font_row.add_child(b)

	# Quiet mode
	var quiet_box := _panel("차분 모드", "검 프리뷰·이펙트 등 게임 UI를 끄고 순수 퀴즈만 표시.")
	root.add_child(quiet_box["panel"])
	var quiet_check := CheckBox.new()
	quiet_check.text = "차분 모드 사용"
	quiet_check.add_theme_font_size_override("font_size", 15)
	quiet_check.button_pressed = ProgressStore.is_quiet_mode()
	quiet_check.toggled.connect(func(on: bool): ProgressStore.set_quiet_mode(on))
	quiet_box["body"].add_child(quiet_check)

	# Timer
	var timer_box := _panel("문항 타이머", "문항당 카운트다운 바 표시. 끄면 시간 압박 없이 풀이 가능.")
	root.add_child(timer_box["panel"])
	var timer_check := CheckBox.new()
	timer_check.text = "문항 타이머 표시"
	timer_check.add_theme_font_size_override("font_size", 15)
	timer_check.button_pressed = ProgressStore.is_timer_enabled()
	timer_check.toggled.connect(func(on: bool): ProgressStore.set_timer_enabled(on))
	timer_box["body"].add_child(timer_check)

	# Difficulty — applied to Weapon success/destroy rates at attempt time.
	# Hard tightens both: 0.85× success, 1.15× destroy.
	var diff_box := _panel("강화 난이도",
		"Easy: 공식 검강화하기 확률표.  Hard: 성공률 ×0.85, 파괴율 ×1.15.")
	root.add_child(diff_box["panel"])
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 12)
	diff_box["body"].add_child(diff_row)
	var diff_group := ButtonGroup.new()
	var current_diff: String = ProgressStore.get_difficulty()
	for value in ["easy", "hard"]:
		var b := Button.new()
		b.text = "Easy" if value == "easy" else "Hard"
		b.toggle_mode = true
		b.button_group = diff_group
		b.custom_minimum_size = Vector2(110, 44)
		b.button_pressed = (value == current_diff)
		var capture := value
		b.pressed.connect(func(): ProgressStore.set_difficulty(capture))
		diff_row.add_child(b)

	# Footer
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(spacer)

	var hint := Label.new()
	hint.text = "변경 사항은 즉시 저장됩니다."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.55, 0.6, 0.72)
	hint.add_theme_font_size_override("font_size", 13)
	root.add_child(hint)


# Returns { panel, body } — body is the VBox where caller adds controls.
func _panel(title: String, desc: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	box.add_child(t)

	var d := Label.new()
	d.text = desc
	d.modulate = Color(0.7, 0.75, 0.85)
	d.add_theme_font_size_override("font_size", 13)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(d)

	return { "panel": panel, "body": box }


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
