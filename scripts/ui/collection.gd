# 수집 화면 — 업적 배지 그리드 + 칭호 장착. 코스메틱(보너스 없음).
extends Control

var _grid_root: VBoxContainer

func _ready() -> void:
	_build_layout()
	ProgressStore.achievement_unlocked.connect(func(_id): _rebuild())
	ProgressStore.title_changed.connect(func(_t): _rebuild())

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
	title.text = "🏆 수집 — 업적 & 칭호"
	title.add_theme_font_size_override("font_size", 24)
	top.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(scroll)
	_grid_root = VBoxContainer.new()
	_grid_root.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_grid_root)
	_rebuild()

func _rebuild() -> void:
	for c in _grid_root.get_children():
		c.queue_free()
	var owned := ProgressStore.get_achievements()
	var current := ProgressStore.get_title()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_grid_root.add_child(flow)
	for a in Achievements.LIST:
		flow.add_child(_make_badge(a, owned.has(a["id"]), current == String(a["id"])))

func _make_badge(a: Dictionary, is_owned: bool, is_equipped: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 96)
	panel.add_theme_stylebox_override("panel", _badge_stylebox(is_owned, is_equipped))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)
	var name_label := Label.new()
	name_label.text = String(a["title"]) if is_owned else "🔒 ???"
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.modulate = Color(1.0, 0.95, 0.7) if is_owned else Color(0.55, 0.58, 0.65)
	vb.add_child(name_label)
	var desc := Label.new()
	desc.text = String(a["desc"])
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate = Color(0.8, 0.84, 0.92) if is_owned else Color(0.45, 0.48, 0.55)
	vb.add_child(desc)
	if is_owned:
		var btn := Button.new()
		btn.text = "장착 중" if is_equipped else "칭호 장착"
		btn.disabled = is_equipped
		btn.add_theme_font_size_override("font_size", 12)
		var id := String(a["id"])
		btn.pressed.connect(func(): ProgressStore.set_title(id))
		vb.add_child(btn)
	return panel

func _badge_stylebox(is_owned: bool, is_equipped: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.17, 0.24) if is_owned else Color(0.10, 0.11, 0.14)
	sb.border_color = Color(1.0, 0.85, 0.4) if is_equipped else (Color(0.4, 0.55, 0.8) if is_owned else Color(0.22, 0.24, 0.3))
	sb.set_border_width_all(2 if is_equipped else 1)
	sb.set_corner_radius_all(10)
	return sb

func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
