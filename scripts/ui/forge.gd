# 강화소 — the core 검강화하기 loop.
# Center: big SwordDisplay (sprite + tier glow + result flash).
# Below:  success rate, ticket count, scroll toggle, enhance button.
# Top:    nav back to Home + counters (tickets / gold / scrolls).
#
# Real probability + downgrade logic lives in Weapon.gd (preserved from the
# Electron port). This file is just UI + button wiring.

extends Control

const SWORD_DISPLAY := preload("res://scenes/SwordDisplay.tscn")

# Charge-up suspense before the roll resolves. The blade glows for CHARGE_TIME,
# then the actual try_enhance() roll happens at the reveal.
const CHARGE_TIME := 1.2

var _sword_slot: Control
var _tickets_label: Label
var _gold_label: Label
var _scrolls_label: Label
var _shards_label: Label
var _rate_label: Label
var _result_label: Label
var _try_button: Button
var _scroll_check: CheckBox
var _charging := false
var _pending_scroll := false


func _ready() -> void:
	_build_layout()
	_refresh()
	ProgressStore.weapon_changed.connect(func(_lv): _refresh())
	ProgressStore.tickets_changed.connect(func(_n): _refresh())
	ProgressStore.gold_changed.connect(func(_n): _refresh())
	ProgressStore.scrolls_changed.connect(func(_n): _refresh())
	ProgressStore.shards_changed.connect(func(_n): _refresh())
	ProgressStore.difficulty_changed.connect(func(_d): _refresh())
	ProgressStore.enhance_result.connect(_render_result)


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

	_tickets_label = _make_counter("강화권 0", Color(0.7, 1.0, 0.85))
	top.add_child(_tickets_label)
	_gold_label = _make_counter("골드 0", Color(1.0, 0.85, 0.3))
	top.add_child(_gold_label)
	_scrolls_label = _make_counter("주문서 0", Color(0.9, 0.75, 1.0))
	top.add_child(_scrolls_label)
	_shards_label = _make_counter("파편 0", Color(0.95, 0.6, 0.55))
	top.add_child(_shards_label)

	# ── Title
	var title := Label.new()
	title.text = "🗡  강화소"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	# ── Sword display (large, central)
	var stage := Control.new()
	stage.size_flags_horizontal = SIZE_EXPAND_FILL
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 360)
	stage.clip_contents = true
	root.add_child(stage)

	_sword_slot = SWORD_DISPLAY.instantiate()
	_sword_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_sword_slot)

	# ── Rate + scroll toggle row
	_rate_label = Label.new()
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rate_label.add_theme_font_size_override("font_size", 18)
	_rate_label.modulate = Color(0.7, 0.9, 1.0)
	root.add_child(_rate_label)

	var scroll_row := HBoxContainer.new()
	scroll_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(scroll_row)

	_scroll_check = CheckBox.new()
	_scroll_check.text = "주문서 사용 (파괴 방지)"
	_scroll_check.add_theme_font_size_override("font_size", 14)
	scroll_row.add_child(_scroll_check)

	# ── Enhance button
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(btn_row)

	_try_button = Button.new()
	_try_button.text = "강화 시도 (강화권 1)"
	_try_button.custom_minimum_size = Vector2(260, 60)
	_try_button.add_theme_font_size_override("font_size", 18)
	_try_button.pressed.connect(_on_try)
	btn_row.add_child(_try_button)

	# ── Result text under the button
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_result_label)


func _make_counter(initial: String, color: Color) -> Label:
	var l := Label.new()
	l.text = initial
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = color
	return l


func _refresh() -> void:
	var lv := ProgressStore.get_weapon_level()
	var tickets := ProgressStore.get_enhance_tickets()
	var scrolls := ProgressStore.get_protection_scrolls()
	_tickets_label.text = "강화권 %d" % tickets
	_gold_label.text = "골드 %d" % ProgressStore.get_gold()
	_scrolls_label.text = "주문서 %d" % scrolls
	_shards_label.text = "파편 %d" % ProgressStore.get_shards()
	var diff: String = ProgressStore.get_difficulty()
	if lv >= Weapon.ENHANCE_MAX_LEVEL:
		_rate_label.text = "최대 레벨 +%d — 더 이상 강화 불가" % Weapon.ENHANCE_MAX_LEVEL
		_try_button.disabled = true
	else:
		var rate := Weapon.success_rate_at(lv, diff)
		var destroy_rate := Weapon.destroy_rate_at(lv, diff)
		var destroy_warning := ""
		if destroy_rate > 0.0:
			destroy_warning = "  ·  파괴 %s" % Weapon.format_percent(destroy_rate)
		var diff_tag: String = "  [Hard]" if diff == "hard" else ""
		_rate_label.text = "+%d → +%d  ·  성공 %s%s%s" % [
			lv, lv + 1, Weapon.format_percent(rate), destroy_warning, diff_tag,
		]
		_try_button.disabled = tickets < Weapon.ENHANCE_MATERIAL_COST
	# Scroll toggle is only useful where destroy can actually happen (+3+).
	_scroll_check.disabled = scrolls == 0 or Weapon.destroy_rate_at(lv, diff) <= 0.0
	if scrolls == 0:
		_scroll_check.button_pressed = false


func _on_try() -> void:
	if _charging:
		return
	# Pre-validate so we never play the charge-up and then fail.
	if ProgressStore.get_weapon_level() >= Weapon.ENHANCE_MAX_LEVEL:
		_result_label.text = "이미 최대 레벨입니다"
		_result_label.modulate = Color(1, 0.65, 0.65)
		return
	if ProgressStore.get_enhance_tickets() < Weapon.ENHANCE_MATERIAL_COST:
		_result_label.text = "강화권이 부족합니다 — 퀴즈를 풀어 모으세요"
		_result_label.modulate = Color(1, 0.65, 0.65)
		return

	# Snapshot the scroll choice now; the roll happens when the blade finishes
	# charging.
	_pending_scroll = _scroll_check.button_pressed and ProgressStore.get_protection_scrolls() > 0
	_charging = true
	_try_button.disabled = true
	_scroll_check.disabled = true
	_result_label.text = "⚡ 강화 중..."
	_result_label.modulate = Color(0.8, 0.9, 1.0)

	# Charge glow layered on the sword; roll when it finishes.
	_sword_slot.play_charge(CHARGE_TIME)
	var tw := create_tween()
	tw.tween_interval(CHARGE_TIME)
	tw.tween_callback(_do_enhance)


# Charge done → roll now. try_enhance() emits enhance_result (→ SwordDisplay
# flashes the result fx on the blade) and weapon/ticket signals (→ _refresh),
# all synchronously, so text + button state are already correct on return.
func _do_enhance() -> void:
	_charging = false
	var result := ProgressStore.try_enhance(_pending_scroll)
	if not result.get("ok", false):
		var reason: String = result.get("reason", "")
		_result_label.text = "강화 실패: %s" % reason
		_result_label.modulate = Color(1, 0.65, 0.65)
		_refresh()


func _render_result(result: String, before: int, after: int, tickets_left: int, shards_gained: int) -> void:
	match result:
		"success":
			_result_label.text = "✨ 성공! +%d → +%d  (강화권 %d 남음)" % [before, after, tickets_left]
			_result_label.modulate = Color(0.6, 1.0, 0.7)
		"stay":
			_result_label.text = "💧 실패 — +%d 유지" % after
			_result_label.modulate = Color(0.85, 0.85, 0.6)
		"stay_protected":
			_result_label.text = "📜 주문서가 파괴를 막았습니다 — +%d 유지" % after
			_result_label.modulate = Color(0.9, 0.7, 1.0)
		"destroy":
			_result_label.text = "💥 파괴! +%d → +0  ·  파편 +%d 회수" % [before, shards_gained]
			_result_label.modulate = Color(1.0, 0.4, 0.4)
		_:
			_result_label.text = ""


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
