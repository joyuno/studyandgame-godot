# 검강화하기 home — quiz pack picker + sword preview + nav to Forge/Market.
# The idle-RPG CombatStage embed is retired; the sword is the focal point now.
# Title-bar counters (강화권 / 골드 / 주문서 / 검 등급) stay live via signals.

extends Control

const QUIZ_SCENE := "res://scenes/Quiz.tscn"
const FORGE_SCENE := "res://scenes/Forge.tscn"
const MARKET_SCENE := "res://scenes/Market.tscn"
const WRONG_NOTE_SCENE := "res://scenes/WrongNote.tscn"
const SETTINGS_SCENE := "res://scenes/Settings.tscn"
const SWORD_DISPLAY := preload("res://scenes/SwordDisplay.tscn")

var _tickets_label: Label
var _gold_label: Label
var _scrolls_label: Label
var _weapon_label: Label
var _xp_label: Label
var _status_label: Label
var _sword_slot: Control


func _ready() -> void:
	_build_layout()
	_refresh()
	ProgressStore.progress_changed.connect(_refresh)
	ProgressStore.tickets_changed.connect(func(_n): _refresh())
	ProgressStore.gold_changed.connect(func(_n): _refresh())
	ProgressStore.scrolls_changed.connect(func(_n): _refresh())
	ProgressStore.weapon_changed.connect(func(_lv): _refresh())
	get_window().files_dropped.connect(_on_files_dropped)


func _build_layout() -> void:
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
	root.add_theme_constant_override("separation", 18)
	outer.add_child(root)

	# ── Title bar
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 18)
	root.add_child(title_bar)

	var title := Label.new()
	title.text = "문제풀고 강화하자"
	title.add_theme_font_size_override("font_size", 30)
	title_bar.add_child(title)

	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = SIZE_EXPAND_FILL
	title_bar.add_child(spacer1)

	_xp_label = _make_counter("Lv 1 · 0 XP", Color(0.85, 0.9, 1.0))
	title_bar.add_child(_xp_label)

	_tickets_label = _make_counter("강화권 0", Color(0.7, 1.0, 0.85))
	title_bar.add_child(_tickets_label)

	_gold_label = _make_counter("골드 0", Color(1.0, 0.85, 0.3))
	title_bar.add_child(_gold_label)

	_scrolls_label = _make_counter("주문서 0", Color(0.9, 0.75, 1.0))
	title_bar.add_child(_scrolls_label)

	_weapon_label = _make_counter("검 +0", Color(1, 0.95, 0.7))
	title_bar.add_child(_weapon_label)

	# 차분 모드는 설정 화면에서도 토글 가능 — 여기선 빠른 액세스용
	var quiet_check := CheckBox.new()
	quiet_check.text = "차분 모드"
	quiet_check.add_theme_font_size_override("font_size", 14)
	quiet_check.button_pressed = ProgressStore.is_quiet_mode()
	quiet_check.toggled.connect(func(on: bool):
		ProgressStore.set_quiet_mode(on)
		_apply_quiet_mode()
	)
	ProgressStore.quiet_mode_changed.connect(func(on: bool):
		quiet_check.button_pressed = on
		_apply_quiet_mode()
	)
	title_bar.add_child(quiet_check)

	# ── Sword preview stage
	var stage_wrap := Control.new()
	stage_wrap.size_flags_horizontal = SIZE_EXPAND_FILL
	stage_wrap.size_flags_vertical = SIZE_FILL
	stage_wrap.custom_minimum_size = Vector2(0, 220)
	stage_wrap.clip_contents = true
	root.add_child(stage_wrap)

	_sword_slot = SWORD_DISPLAY.instantiate()
	_sword_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_wrap.add_child(_sword_slot)
	_apply_quiet_mode()

	# ── Quiz pack picker — auto-listed from res://data/quizzes/ so newly added
	# packs appear without editing this scene. .yml wins over a same-name .json.
	var pack_header := HBoxContainer.new()
	pack_header.add_theme_constant_override("separation", 12)
	root.add_child(pack_header)

	var pack_title := Label.new()
	pack_title.text = "📚 퀴즈 팩 선택"
	pack_title.add_theme_font_size_override("font_size", 17)
	pack_title.modulate = Color(0.85, 0.9, 1.0)
	pack_header.add_child(pack_title)

	var hsp := Control.new()
	hsp.size_flags_horizontal = SIZE_EXPAND_FILL
	pack_header.add_child(hsp)

	var btn_open := _make_button("파일 열기…", Vector2(140, 40))
	btn_open.pressed.connect(_on_open_file)
	pack_header.add_child(btn_open)

	var pack_scroll := ScrollContainer.new()
	pack_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	pack_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	pack_scroll.custom_minimum_size = Vector2(0, 130)
	root.add_child(pack_scroll)

	var pack_grid := GridContainer.new()
	pack_grid.columns = 2
	pack_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	pack_grid.add_theme_constant_override("h_separation", 12)
	pack_grid.add_theme_constant_override("v_separation", 10)
	pack_scroll.add_child(pack_grid)

	for entry in _list_packs():
		var btn := _make_button(entry["title"], Vector2(0, 46))
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.tooltip_text = entry["file"]
		btn.pressed.connect(_on_load_sample.bind(entry["path"]))
		pack_grid.add_child(btn)

	# ── Action row 2 — game nav
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 16)
	root.add_child(nav_row)

	var btn_forge := _make_button("🗡  강화소", Vector2(140, 50))
	btn_forge.pressed.connect(_open_scene.bind(FORGE_SCENE))
	nav_row.add_child(btn_forge)

	var btn_market := _make_button("🏪  시장", Vector2(120, 50))
	btn_market.pressed.connect(_open_scene.bind(MARKET_SCENE))
	nav_row.add_child(btn_market)

	var btn_wrong := _make_button("📓  오답노트", Vector2(150, 50))
	btn_wrong.pressed.connect(_open_scene.bind(WRONG_NOTE_SCENE))
	nav_row.add_child(btn_wrong)

	var btn_settings := _make_button("⚙  설정", Vector2(120, 50))
	btn_settings.pressed.connect(_open_scene.bind(SETTINGS_SCENE))
	nav_row.add_child(btn_settings)

	# ── Status hint
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = "퀴즈를 풀면 정답마다 강화권 1개를 얻습니다 — .json / .yml 드롭도 가능"
	_status_label.modulate = Color(0.55, 0.6, 0.72)
	root.add_child(_status_label)


func _apply_quiet_mode() -> void:
	if _sword_slot:
		_sword_slot.visible = not ProgressStore.is_quiet_mode()


func _make_counter(initial: String, color: Color) -> Label:
	var l := Label.new()
	l.text = initial
	l.add_theme_font_size_override("font_size", 15)
	l.modulate = color
	return l


func _make_button(label: String, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = size
	btn.add_theme_font_size_override("font_size", 16)
	return btn


# Scan res://data/quizzes/ and return [{title, path, file}] sorted by title.
# When a basename has both .yml and .json, the .yml (workbook/enhanced) wins so
# the same pack isn't listed twice.
func _list_packs() -> Array:
	var best: Dictionary = {}  # basename → { path, file, is_yaml }
	var dir := DirAccess.open("res://data/quizzes")
	if dir != null:
		dir.list_dir_begin()
		while true:
			var e := dir.get_next()
			if e.is_empty():
				break
			if dir.current_is_dir():
				continue
			var lower := e.to_lower()
			var is_yaml := lower.ends_with(".yml") or lower.ends_with(".yaml")
			if not (is_yaml or lower.ends_with(".json")):
				continue
			var base := e.get_basename()
			if best.has(base) and best[base]["is_yaml"] and not is_yaml:
				continue  # keep the .yml already recorded
			best[base] = {
				"path": "res://data/quizzes/%s" % e,
				"file": e,
				"is_yaml": is_yaml,
			}
		dir.list_dir_end()

	var out: Array = []
	for base in best.keys():
		var path: String = best[base]["path"]
		var title: String = String(base)
		var r := PackParser.parse_file(path)
		if r.get("ok", false):
			title = String((r["pack"] as Dictionary).get("meta", {}).get("title", base))
		out.append({ "title": title, "path": path, "file": best[base]["file"] })
	out.sort_custom(func(a, b): return String(a["title"]) < String(b["title"]))
	return out


func _refresh() -> void:
	_xp_label.text = "Lv %d · %d XP" % [ProgressStore.get_level(), ProgressStore.get_xp()]
	_tickets_label.text = "강화권 %d" % ProgressStore.get_enhance_tickets()
	_gold_label.text = "골드 %d" % ProgressStore.get_gold()
	_scrolls_label.text = "주문서 %d" % ProgressStore.get_protection_scrolls()
	_weapon_label.text = "검 +%d" % ProgressStore.get_weapon_level()


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
