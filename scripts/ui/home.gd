# Home screen — embeds the same CombatStage that Quiz uses, so the menu
# feels alive (auto-attack loop) instead of frozen.
# Below: theme picker, sample buttons, navigation, drop hint.

extends Control

const QUIZ_SCENE := "res://scenes/Quiz.tscn"
const ENHANCE_SCENE := "res://scenes/Enhance.tscn"
const CHARACTER_DISPLAY := preload("res://scenes/CharacterDisplay.tscn")

var _theme_dropdown: OptionButton
var _weapon_badge: Label
var _xp_label: Label
var _status_label: Label
var _character_slot: Control


func _ready() -> void:
	_build_layout()
	_refresh()
	ProgressStore.progress_changed.connect(_refresh)
	ProgressStore.theme_changed.connect(func(_id): _refresh())
	get_window().files_dropped.connect(_on_files_dropped)


func _build_layout() -> void:
	# Outer margin (16:9 letterbox-ish padding)
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 48)
	outer.add_theme_constant_override("margin_right", 48)
	outer.add_theme_constant_override("margin_top", 32)
	outer.add_theme_constant_override("margin_bottom", 32)
	add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 20)
	outer.add_child(root)

	# ── Title bar
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 18)
	root.add_child(title_bar)

	var title := Label.new()
	title.text = "StudyGame"
	title.add_theme_font_size_override("font_size", 32)
	title_bar.add_child(title)

	var sub := Label.new()
	sub.text = "— Godot 포트"
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.65, 0.7, 0.85)
	sub.size_flags_vertical = SIZE_SHRINK_END
	title_bar.add_child(sub)

	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = SIZE_EXPAND_FILL
	title_bar.add_child(spacer1)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 16)
	title_bar.add_child(_xp_label)

	_weapon_badge = Label.new()
	_weapon_badge.add_theme_font_size_override("font_size", 16)
	_weapon_badge.modulate = Color(1, 0.85, 0.2)
	title_bar.add_child(_weapon_badge)

	# ── Hero stage — same side-scrolling combat scene Quiz uses, so the
	# Home screen also "feels alive" (idle bob + auto-attack projectile loop).
	# Real damage stays gated behind quiz answers (PackStore.feedback).
	var stage_wrap := Control.new()
	stage_wrap.size_flags_horizontal = SIZE_EXPAND_FILL
	stage_wrap.size_flags_vertical = SIZE_FILL
	stage_wrap.custom_minimum_size = Vector2(0, 300)
	stage_wrap.clip_contents = true
	root.add_child(stage_wrap)

	if _character_slot:
		_character_slot.queue_free()
	_character_slot = CHARACTER_DISPLAY.instantiate()
	_character_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(_character_slot)

	# ── Theme picker row
	var picker_row := HBoxContainer.new()
	picker_row.alignment = BoxContainer.ALIGNMENT_CENTER
	picker_row.add_theme_constant_override("separation", 12)
	root.add_child(picker_row)

	var picker_label := Label.new()
	picker_label.text = "캐릭터:"
	picker_row.add_child(picker_label)

	_theme_dropdown = OptionButton.new()
	_theme_dropdown.custom_minimum_size = Vector2(220, 36)
	for theme_id in ThemeStore.list_theme_ids():
		var t := ThemeStore.get_theme(theme_id)
		_theme_dropdown.add_item(t.get("display_name", theme_id))
		_theme_dropdown.set_item_metadata(_theme_dropdown.item_count - 1, theme_id)
	_select_active_theme_in_dropdown()
	_theme_dropdown.item_selected.connect(_on_theme_selected)
	picker_row.add_child(_theme_dropdown)

	# ── Sample/Open + Nav (one row, big buttons)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 16)
	root.add_child(action_row)

	var btn_clickhouse := _make_button("ClickHouse 기초", Vector2(200, 56))
	btn_clickhouse.pressed.connect(_on_load_sample.bind("res://data/quizzes/clickhouse-basics.json"))
	action_row.add_child(btn_clickhouse)

	var btn_otel := _make_button("OpenTelemetry 기초", Vector2(220, 56))
	btn_otel.pressed.connect(_on_load_sample.bind("res://data/quizzes/otel-basics.json"))
	action_row.add_child(btn_otel)

	var btn_open := _make_button("파일 열기…", Vector2(160, 56))
	btn_open.pressed.connect(_on_open_file)
	action_row.add_child(btn_open)

	var btn_enhance := _make_button("강화소 →", Vector2(140, 56))
	btn_enhance.pressed.connect(_open_scene.bind(ENHANCE_SCENE))
	action_row.add_child(btn_enhance)

	# ── Status hint (errors + drop hint)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = "샘플을 누르거나 .json / .yml 파일을 창에 드롭"
	_status_label.modulate = Color(0.55, 0.6, 0.72)
	root.add_child(_status_label)


func _make_button(label: String, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = size
	btn.add_theme_font_size_override("font_size", 16)
	return btn


func _refresh() -> void:
	_xp_label.text = "Lv %d  ·  %d XP" % [ProgressStore.get_level(), ProgressStore.get_xp()]
	_weapon_badge.text = "무기 +%d  ·  강화석 %d" % [
		ProgressStore.get_weapon_level(),
		ProgressStore.get_materials(),
	]
	# Embedded CharacterDisplay (CombatStage) refreshes itself via signals.


func _select_active_theme_in_dropdown() -> void:
	var active := ProgressStore.get_selected_theme_id()
	for i in _theme_dropdown.item_count:
		if _theme_dropdown.get_item_metadata(i) == active:
			_theme_dropdown.select(i)
			return


func _on_theme_selected(idx: int) -> void:
	var theme_id: String = _theme_dropdown.get_item_metadata(idx)
	ProgressStore.set_theme(theme_id)


func _on_load_sample(path: String) -> void:
	_load_pack(path)


func _on_open_file() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.json,*.yml,*.yaml", "퀴즈 팩 (.json / .yml / .yaml)")
	dialog.use_native_dialog = true
	dialog.file_selected.connect(_load_pack)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _on_files_dropped(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	_load_pack(paths[0])


func _load_pack(path: String) -> void:
	var result := PackStore.load_pack_from_path(path)
	if not result.get("ok", false):
		_status_label.text = "❌ %s — %s" % [result.get("code", "ERR"), result.get("message", "")]
		_status_label.modulate = Color(1, 0.4, 0.4)
		return
	_open_scene(QUIZ_SCENE)


func _open_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
