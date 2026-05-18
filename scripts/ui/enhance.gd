# Weapon enhancement screen.

extends Control

var _level_label: Label
var _materials_label: Label
var _rate_label: Label
var _result_label: Label
var _try_button: Button


func _ready() -> void:
	_build_layout()
	_refresh()
	ProgressStore.weapon_changed.connect(func(_lv): _refresh())
	ProgressStore.materials_changed.connect(func(_n): _refresh())
	ProgressStore.enhance_result.connect(_render_result)


func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top := HBoxContainer.new()
	var back := Button.new()
	back.text = "← 홈"
	back.pressed.connect(_go_home)
	top.add_child(back)
	root.add_child(top)

	var title := Label.new()
	title.text = "🗡  강화소"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 24)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_level_label)

	_materials_label = Label.new()
	_materials_label.add_theme_font_size_override("font_size", 18)
	_materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_materials_label)

	_rate_label = Label.new()
	_rate_label.add_theme_font_size_override("font_size", 18)
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rate_label.modulate = Color(0.7, 0.9, 1.0)
	root.add_child(_rate_label)

	_try_button = Button.new()
	_try_button.text = "강화 시도 (강화석 1)"
	_try_button.custom_minimum_size = Vector2(260, 60)
	_try_button.pressed.connect(_on_try)
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_try_button)
	root.add_child(center)

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_result_label)


func _refresh() -> void:
	var lv := ProgressStore.get_weapon_level()
	var mats := ProgressStore.get_materials()
	_level_label.text = "현재 무기 +%d  ·  데미지 ×%.2f" % [
		lv,
		Weapon.weapon_damage_multiplier(lv),
	]
	_materials_label.text = "강화석 %d 개" % mats
	if lv >= Weapon.ENHANCE_MAX_LEVEL:
		_rate_label.text = "최대 레벨 달성 — 더 이상 강화 불가"
		_try_button.disabled = true
	else:
		var rate := Weapon.success_rate_at(lv)
		_rate_label.text = "+%d → +%d 성공률: %s" % [lv, lv + 1, Weapon.format_percent(rate)]
		_try_button.disabled = mats < Weapon.ENHANCE_MATERIAL_COST


func _on_try() -> void:
	var result := ProgressStore.try_enhance()
	if not result.get("ok", false):
		_result_label.text = "재료 부족" if result.get("reason") == "not_enough_materials" else "최대 레벨"
		_result_label.modulate = Color(1, 0.6, 0.6)


func _render_result(success: bool, before: int, after: int, materials_left: int) -> void:
	if success:
		_result_label.text = "✨ 성공! +%d → +%d  (강화석 %d 남음)" % [before, after, materials_left]
		_result_label.modulate = Color(0.6, 1.0, 0.7)
	else:
		if before == after:
			_result_label.text = "💧 실패 — 보호 구간으로 유지 (+%d)" % after
		else:
			_result_label.text = "💥 실패 — +%d → +%d" % [before, after]
		_result_label.modulate = Color(1.0, 0.7, 0.4)


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
