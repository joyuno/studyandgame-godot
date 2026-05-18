# Home screen — theme picker · weapon badge · pack selection / file drop.
# Code-first UI: scene file is just a Control + script attachment.

extends Control

const QUIZ_SCENE := "res://scenes/Quiz.tscn"
const ENHANCE_SCENE := "res://scenes/Enhance.tscn"

var _theme_dropdown: OptionButton
var _weapon_badge: Label
var _xp_label: Label
var _status_label: Label


func _ready() -> void:
	_build_layout()
	_refresh_badges()
	ProgressStore.progress_changed.connect(_refresh_badges)
	# OS-level file drop — drag .json onto the window to load.
	get_window().files_dropped.connect(_on_files_dropped)


func _build_layout() -> void:
	# Vertical stack centered horizontally.
	var root := VBoxContainer.new()
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.add_theme_constant_override("separation", 20)
	root.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	add_child(root)

	# ── Title row
	var title := Label.new()
	title.text = "StudyGame — Godot 포트"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "퀴즈 .json 파일을 창에 끌어다 놓거나 샘플을 선택"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.7, 0.75, 0.85)
	root.add_child(subtitle)

	# ── Status row (XP, weapon level, theme)
	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 24)
	root.add_child(status_row)

	_xp_label = Label.new()
	_xp_label.add_theme_font_size_override("font_size", 16)
	status_row.add_child(_xp_label)

	_weapon_badge = Label.new()
	_weapon_badge.add_theme_font_size_override("font_size", 16)
	_weapon_badge.modulate = Color(1, 0.85, 0.2)
	status_row.add_child(_weapon_badge)

	_theme_dropdown = OptionButton.new()
	_theme_dropdown.custom_minimum_size = Vector2(180, 0)
	for theme_id in ThemeStore.list_theme_ids():
		var t := ThemeStore.get_theme(theme_id)
		_theme_dropdown.add_item("%s" % t.get("display_name", theme_id), _theme_dropdown.item_count)
		_theme_dropdown.set_item_metadata(_theme_dropdown.item_count - 1, theme_id)
	_select_active_theme_in_dropdown()
	_theme_dropdown.item_selected.connect(_on_theme_selected)
	status_row.add_child(_theme_dropdown)

	# ── Sample pack buttons
	var sample_row := HBoxContainer.new()
	sample_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sample_row.add_theme_constant_override("separation", 12)
	root.add_child(sample_row)

	var btn_clickhouse := Button.new()
	btn_clickhouse.text = "ClickHouse 기초"
	btn_clickhouse.custom_minimum_size = Vector2(180, 44)
	btn_clickhouse.pressed.connect(_on_load_sample.bind("res://data/quizzes/clickhouse-basics.json"))
	sample_row.add_child(btn_clickhouse)

	var btn_otel := Button.new()
	btn_otel.text = "OpenTelemetry 기초"
	btn_otel.custom_minimum_size = Vector2(180, 44)
	btn_otel.pressed.connect(_on_load_sample.bind("res://data/quizzes/otel-basics.json"))
	sample_row.add_child(btn_otel)

	var btn_file := Button.new()
	btn_file.text = "파일에서 열기…"
	btn_file.custom_minimum_size = Vector2(180, 44)
	btn_file.pressed.connect(_on_open_file)
	sample_row.add_child(btn_file)

	# ── Navigation row
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 12)
	root.add_child(nav_row)

	var btn_enhance := Button.new()
	btn_enhance.text = "강화소 →"
	btn_enhance.custom_minimum_size = Vector2(140, 36)
	btn_enhance.pressed.connect(_open_scene.bind(ENHANCE_SCENE))
	nav_row.add_child(btn_enhance)

	# ── Status (drag-drop hint / error display)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = "(샘플을 누르거나 .json 파일을 창에 드롭)"
	_status_label.modulate = Color(0.55, 0.6, 0.7)
	root.add_child(_status_label)


func _refresh_badges() -> void:
	_xp_label.text = "Lv %d  ·  %d XP" % [ProgressStore.get_level(), ProgressStore.get_xp()]
	_weapon_badge.text = "무기 +%d  ·  강화석 %d" % [
		ProgressStore.get_weapon_level(),
		ProgressStore.get_materials(),
	]


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
	dialog.add_filter("*.json", "퀴즈 팩 (.json)")
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
