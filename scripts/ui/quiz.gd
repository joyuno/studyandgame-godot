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
var _passage_panel: PanelContainer
var _passage_label: RichTextLabel
var _question_label: RichTextLabel
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
var _boost_button: Button
var _insure_button: Button
var _boost_label: Label
var _insure_label: Label
var _boost_icon: TextureRect
var _insure_icon: TextureRect

# Crystal-structure 3D figure (optional `figure` field) — zero-base learning aid.
# Panel appears only for supported figures; the 3D view + caption toggle on/off.
var _figure_panel: PanelContainer
var _figure_view: FigureView
var _figure_toggle: CheckButton
var _figure_caption: Label
var _current_figure: String = ""

var _glossary_box: VBoxContainer
# Set of the current question's card (glossary) words — excluded from dictionary
# tagging so cards and inline tap-words never duplicate.
var _card_words: Dictionary = {}
# Bundled JP→KO dictionary (word → "단어【읽기】 뜻"), loaded once, shared.
static var _dict: Dictionary = {}
static var _dict_loaded := false
# In-scene popover shown right below the tapped word (avoids the HiDPI screen-
# coordinate offset that a PopupPanel window suffered from).
var _word_popup: PanelContainer
var _word_popup_label: Label
var _word_popup_timer: Timer

# Cached scales so we can re-apply when font size changes.
var _font_sizes := {
	"question": 26, "answer": 18, "feedback": 17,
	"hud": 16, "combo": 18, "advance": 19, "back": 0,
}


func _ready() -> void:
	_build_layout()
	_load_dict()
	_apply_font_scale()
	if PackStore.questions_count() == 0:
		_question_label.text = "[center]퀴즈 팩이 로드되지 않았습니다. 홈으로 돌아가서 선택하세요.[/center]"
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
	ProgressStore.consumables_changed.connect(func(_s): _refresh_consumable_badges())
	_apply_timer_visibility()
	_refresh_consumable_badges()
	ProgressStore.achievement_unlocked.connect(_on_achievement)


func _on_achievement(id: String) -> void:
	_show_toast("🏆 업적 달성: %s" % Achievements.title_for(id), Color(1.0, 0.9, 0.5))


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

	_boost_icon = Icons.make("xp_boost", Color(1.0, 0.85, 0.3), 18)
	_boost_icon.visible = false
	top.add_child(_boost_icon)

	_boost_button = Button.new()
	_boost_button.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_boost_button.pressed.connect(_on_activate_boost)
	top.add_child(_boost_button)

	_insure_icon = Icons.make("combo_insure", Color(1.0, 0.5, 0.35), 18)
	_insure_icon.visible = false
	top.add_child(_insure_icon)

	_insure_button = Button.new()
	_insure_button.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_insure_button.pressed.connect(_on_arm_insurance)
	top.add_child(_insure_button)

	_boost_label = Label.new()
	_boost_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_boost_label.modulate = Color(1.0, 0.9, 0.4)
	top.add_child(_boost_label)

	_insure_label = Label.new()
	_insure_label.add_theme_font_size_override("font_size", _font_sizes["hud"])
	_insure_label.modulate = Color(1.0, 0.6, 0.4)
	top.add_child(_insure_label)

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
	# SwordDisplay's stage is 300×300; this slot reserves less height, so clip
	# the overflow — otherwise the blade + glow bleed onto the question below.
	_sword_slot = Control.new()
	_sword_slot.custom_minimum_size = Vector2(0, 200)
	_sword_slot.size_flags_horizontal = SIZE_EXPAND_FILL
	_sword_slot.clip_contents = true
	_sword_slot.visible = not ProgressStore.is_quiet_mode()
	if _sword_slot.visible:
		var display := SWORD_DISPLAY.instantiate()
		_sword_slot.add_child(display)
	root.add_child(_sword_slot)

	# ── Reading passage panel (독해 지문). Hidden unless q.passage is set.
	# Scrollable so a long N2 passage doesn't push the answer buttons off-screen.
	_passage_panel = PanelContainer.new()
	_passage_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_passage_panel.add_theme_stylebox_override("panel", _passage_stylebox())
	_passage_panel.visible = false
	root.add_child(_passage_panel)

	var passage_scroll := ScrollContainer.new()
	passage_scroll.custom_minimum_size = Vector2(0, 200)
	passage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_passage_panel.add_child(passage_scroll)

	var passage_margin := MarginContainer.new()
	passage_margin.size_flags_horizontal = SIZE_EXPAND_FILL
	passage_margin.add_theme_constant_override("margin_left", 22)
	passage_margin.add_theme_constant_override("margin_right", 22)
	passage_margin.add_theme_constant_override("margin_top", 16)
	passage_margin.add_theme_constant_override("margin_bottom", 16)
	passage_scroll.add_child(passage_margin)

	_passage_label = RichTextLabel.new()
	_passage_label.bbcode_enabled = true
	_passage_label.selection_enabled = true      # 마우스 드래그 선택 (문제 드래그 복사)
	_passage_label.context_menu_enabled = true   # 우클릭 복사 메뉴
	_passage_label.shortcut_keys_enabled = true  # Ctrl+C 복사
	_passage_label.fit_content = true
	_passage_label.scroll_active = false
	_passage_label.add_theme_font_size_override("normal_font_size", _font_sizes["answer"])
	_passage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passage_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_passage_label.modulate = Color(0.92, 0.94, 0.98)
	_passage_label.meta_clicked.connect(_on_gloss_meta)
	passage_margin.add_child(_passage_label)

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

	_question_label = RichTextLabel.new()
	_question_label.bbcode_enabled = true
	_question_label.selection_enabled = true      # 마우스 드래그 선택 (문제 드래그 복사)
	_question_label.context_menu_enabled = true   # 우클릭 복사 메뉴
	_question_label.shortcut_keys_enabled = true  # Ctrl+C 복사
	_question_label.fit_content = true
	_question_label.scroll_active = false
	_question_label.add_theme_font_size_override("normal_font_size", _font_sizes["question"])
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_question_label.meta_clicked.connect(_on_gloss_meta)
	q_margin.add_child(_question_label)

	# ── Crystal-structure 3D figure (optional `figure` field)
	# Sits right under the question. Shown only when the question carries a
	# supported figure; a "보기" toggle hides the 3D view (and persists the choice).
	_build_figure_panel(root)

	# ── Vocab gloss cards (N3+ words in the stem — reading + Korean meaning)
	# Populated per question from the optional `glossary` field. Helps the
	# learner read the prompt without revealing the tested word/answer.
	_glossary_box = VBoxContainer.new()
	_glossary_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_glossary_box.add_theme_constant_override("separation", 6)
	_glossary_box.visible = false
	root.add_child(_glossary_box)

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

	# ── Word popover (top-level so it floats above the layout, near the tap).
	_word_popup = PanelContainer.new()
	_word_popup.top_level = true
	_word_popup.z_index = 100
	_word_popup.visible = false
	_word_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_popup.add_theme_stylebox_override("panel", _word_popup_stylebox())
	_word_popup_label = Label.new()
	_word_popup_label.add_theme_font_size_override("font_size", 17)
	_word_popup_label.modulate = Color(0.96, 0.97, 1.0)
	_word_popup.add_child(_word_popup_label)
	add_child(_word_popup)

	_word_popup_timer = Timer.new()
	_word_popup_timer.one_shot = true
	_word_popup_timer.wait_time = 4.0
	_word_popup_timer.timeout.connect(_hide_word_popup)
	add_child(_word_popup_timer)


func _question_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.18)
	sb.border_color = Color(0.38, 0.45, 0.62)
	sb.set_border_width_all(1)
	sb.border_width_left = 4  # accent bar on left
	sb.border_color = Color(0.38, 0.55, 0.85)
	sb.set_corner_radius_all(10)
	return sb


func _passage_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.15)
	sb.border_color = Color(0.30, 0.40, 0.55)
	sb.set_border_width_all(1)
	sb.border_width_left = 4  # accent bar, distinct teal from question's blue
	sb.border_color = Color(0.35, 0.70, 0.65)
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
	if _question_label: _question_label.add_theme_font_size_override("normal_font_size", _font_sizes["question"])
	if _passage_label: _passage_label.add_theme_font_size_override("normal_font_size", _font_sizes["answer"])
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


func _on_activate_boost() -> void:
	if ProgressStore.activate_xp_boost():
		_refresh_consumable_badges()


func _on_arm_insurance() -> void:
	if ProgressStore.arm_combo_insurance():
		_refresh_consumable_badges()


func _refresh_consumable_badges() -> void:
	var boost_owned := ProgressStore.get_consumable("xp_boost")
	var boost_left := int(ProgressStore.get_progress_value("xp_boost_remaining", 0))
	var show_boost_btn: bool = boost_owned > 0 and boost_left == 0
	_boost_button.text = "부스터(%d)" % boost_owned
	_boost_button.visible = show_boost_btn
	_boost_icon.visible = show_boost_btn
	_boost_label.text = ("XP×2 (%d문제)" % boost_left) if boost_left > 0 else ""
	var insure_owned := ProgressStore.get_consumable("combo_insure")
	var armed := bool(ProgressStore.get_progress_value("combo_insure_armed", false))
	var show_insure_btn: bool = insure_owned > 0 and not armed
	_insure_button.text = "보험(%d)" % insure_owned
	_insure_button.visible = show_insure_btn
	_insure_icon.visible = show_insure_btn
	_insure_label.text = "보험 장착" if armed else ""


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
	_refresh_consumable_badges()
	_build_card_words(q.get("glossary", []))
	var passage := String(q.get("passage", ""))
	_passage_panel.visible = not passage.is_empty()
	if _passage_panel.visible:
		_passage_label.text = _gloss_markup(passage)
	_question_label.text = "[center]%s[/center]" % _gloss_markup(String(q.get("q", "(빈 문항)")))
	_current_figure = String(q.get("figure", ""))
	_update_figure()
	_render_glossary(q.get("glossary", []))
	_hide_word_popup()
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


# Collect this question's card words so the dictionary markup can skip them
# (cards already show them — no duplication).
func _build_card_words(entries) -> void:
	_card_words.clear()
	var list: Array = entries if typeof(entries) == TYPE_ARRAY else []
	for e in list:
		var parts := String(e).replace("|", "｜").split("｜")
		if parts.size() >= 1:
			var word := parts[0].strip_edges()
			if not word.is_empty():
				_card_words[word] = true


# Load the bundled JLPT dictionary once (word → "단어【읽기】 뜻"). Static cache
# is shared across quiz instances.
func _load_dict() -> void:
	if _dict_loaded:
		return
	_dict_loaded = true
	var path := "res://data/dict/jlpt-n2.json"
	if not FileAccess.file_exists(path):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for word in raw:
		if word == "_meta":
			continue
		var v = raw[word]
		if typeof(v) == TYPE_ARRAY and (v as Array).size() >= 2:
			_dict[word] = "%s【%s】  %s" % [word, v[0], v[1]]


# Tag dictionary words found in `text` that are NOT already shown as cards, so
# the learner can tap a non-card word for its reading + meaning. Longest-match +
# placeholder pass prevents a shorter word (在宅) re-matching inside a wrapped
# longer one (在宅勤務). Placeholders use private-use chars so digits in the text
# are never mistaken for a placeholder.
func _gloss_markup(text: String) -> String:
	var out := text.replace("[", "[lb]")
	if _dict.is_empty():
		return out
	var words: Array = []
	for w in _dict:
		if not _card_words.has(w) and text.find(w) != -1:
			words.append(w)
	words.sort_custom(func(a, b): return a.length() > b.length())
	var subs := {}
	var i := 0
	for w in words:
		if out.find(w) == -1:
			continue
		var ph := "%d" % i
		i += 1
		out = out.replace(w, ph)
		subs[ph] = "[color=#ffd95a][url=%s]%s[/url][/color]" % [w, w]
	for ph in subs:
		out = out.replace(ph, subs[ph])
	return out



# A tapped word → in-scene popover with reading + meaning, anchored just below
# the tap point. In-scene positioning uses canvas coords (get_global_mouse_
# position), so no HiDPI screen-coordinate offset. Auto-hides after a few sec.
func _on_gloss_meta(meta) -> void:
	var info := String(_dict.get(String(meta), ""))
	if info.is_empty():
		return
	_word_popup_label.text = info
	_word_popup.reset_size()
	var sz := _word_popup.size
	var p := get_global_mouse_position() + Vector2(-sz.x * 0.5, 16)
	var vp := get_viewport_rect().size
	p.x = clampf(p.x, 8.0, vp.x - sz.x - 8.0)
	p.y = clampf(p.y, 8.0, vp.y - sz.y - 8.0)
	_word_popup.global_position = p
	_word_popup.visible = true
	_word_popup_timer.start()


func _hide_word_popup() -> void:
	if _word_popup:
		_word_popup.visible = false
	if _word_popup_timer:
		_word_popup_timer.stop()


func _word_popup_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.16, 0.23)
	sb.border_color = Color(0.45, 0.62, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


# Build the crystal-structure figure panel (header + 보기 toggle + 3D view +
# caption). Hidden until a supported figure is rendered. The toggle state is
# read from / written to ProgressStore so it persists across sessions.
func _build_figure_panel(parent: Control) -> void:
	_figure_panel = PanelContainer.new()
	_figure_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	_figure_panel.add_theme_stylebox_override("panel", _gloss_stylebox())
	_figure_panel.visible = false
	parent.add_child(_figure_panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	_figure_panel.add_child(m)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	m.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "🧊 구조 그림 (제로베이스 도움)"
	title.add_theme_font_size_override("font_size", maxi(11, _font_sizes["hud"] - 2))
	title.modulate = Color(0.62, 0.76, 0.95)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_figure_toggle = CheckButton.new()
	_figure_toggle.text = "보기"
	_figure_toggle.button_pressed = ProgressStore.is_figures_enabled()
	_figure_toggle.toggled.connect(_on_figure_toggled)
	header.add_child(_figure_toggle)

	_figure_view = FigureView.new()
	_figure_view.custom_minimum_size = Vector2(0, 240)
	_figure_view.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_child(_figure_view)

	_figure_caption = Label.new()
	_figure_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_figure_caption.add_theme_font_size_override("font_size", 13)
	_figure_caption.modulate = Color(0.82, 0.86, 0.95)
	box.add_child(_figure_caption)


# Refresh the figure panel for the current question. The panel (incl. its toggle)
# shows whenever the question carries a supported figure; the 3D view + caption
# appear only when the player has the figure toggle on.
func _update_figure() -> void:
	var has := not _current_figure.is_empty() and FigureView.is_supported(_current_figure)
	_figure_panel.visible = has
	var show_figure := has and ProgressStore.is_figures_enabled()
	_figure_view.visible = show_figure
	_figure_caption.visible = show_figure
	if show_figure:
		_figure_view.set_figure(_current_figure)
		_figure_caption.text = FigureView.caption_for(_current_figure)


func _on_figure_toggled(pressed: bool) -> void:
	ProgressStore.set_figures_enabled(pressed)
	_update_figure()


func _render_glossary(entries) -> void:
	for child in _glossary_box.get_children():
		child.queue_free()
	var list: Array = entries if typeof(entries) == TYPE_ARRAY else []
	if list.is_empty():
		_glossary_box.visible = false
		return
	_glossary_box.visible = true
	var header := Label.new()
	header.text = "📖 용어·단어 카드 — 지문 속 핵심어 설명"
	header.add_theme_font_size_override("font_size", maxi(11, _font_sizes["hud"] - 3))
	header.modulate = Color(0.62, 0.76, 0.95)
	_glossary_box.add_child(header)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	_glossary_box.add_child(flow)
	for e in list:
		var card := _make_gloss_card(e)
		if card:
			flow.add_child(card)


# Build one vocab card from a 'word｜reading｜meaning' scalar.
func _make_gloss_card(entry) -> Control:
	var word := ""
	var reading := ""
	var meaning := ""
	if typeof(entry) == TYPE_DICTIONARY:
		word = String(entry.get("word", ""))
		reading = String(entry.get("reading", ""))
		meaning = String(entry.get("meaning", ""))
	else:
		var parts := String(entry).replace("|", "｜").split("｜")
		if parts.size() >= 1: word = parts[0].strip_edges()
		if parts.size() >= 2: reading = parts[1].strip_edges()
		if parts.size() >= 3: meaning = parts[2].strip_edges()
	if word.is_empty():
		return null

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _gloss_stylebox())
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	m.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)

	var word_label := Label.new()
	word_label.text = word
	word_label.add_theme_font_size_override("font_size", 18)
	word_label.modulate = Color(0.95, 0.96, 1.0)
	top.add_child(word_label)

	if not reading.is_empty():
		var reading_label := Label.new()
		reading_label.text = reading
		reading_label.add_theme_font_size_override("font_size", 13)
		reading_label.modulate = Color(0.7, 0.85, 0.7)
		reading_label.size_flags_vertical = SIZE_SHRINK_CENTER
		top.add_child(reading_label)

	var meaning_label := Label.new()
	meaning_label.text = meaning if not meaning.is_empty() else "—"
	meaning_label.add_theme_font_size_override("font_size", 13)
	meaning_label.modulate = Color(0.82, 0.86, 0.95)
	vb.add_child(meaning_label)

	return panel


func _gloss_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.21)
	sb.border_color = Color(0.30, 0.40, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	return sb


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
	var base_reward := int(info.get("base_reward", 1))
	var prefix := ("정답  (+%d 강화권)" % base_reward) if correct else "오답"
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
	var passage := String(q.get("passage", ""))
	if not passage.is_empty():
		lines.append("[지문]")
		lines.append(passage)
		lines.append("")
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
	var glossary = q.get("glossary", [])
	if typeof(glossary) == TYPE_ARRAY and not (glossary as Array).is_empty():
		lines.append("")
		lines.append("[단어]")
		for e in glossary:
			lines.append("· %s" % String(e).replace("｜", " / ").replace("|", " / "))
	if include_answer:
		var expl := String(q.get("explanation", ""))
		if not expl.is_empty():
			lines.append("")
			lines.append("해설: %s" % expl)
	return "\n".join(lines)


func _on_advance() -> void:
	PackStore.advance()


func _render_completion(record: Dictionary) -> void:
	_question_label.text = "[center]세션 완료[/center]"
	_progress_label.text = "%d / %d 정답  ·  최고 콤보 %d" % [
		record.get("correct", 0), record.get("total", 0), record.get("bestCombo", 0),
	]
	for child in _answer_area.get_children():
		child.queue_free()
	_feedback_box.visible = false
	_question_timer.visible = false
	_copy_button.visible = false
	_glossary_box.visible = false
	_passage_panel.visible = false
	_figure_panel.visible = false
	_hide_word_popup()
	_advance_button.text = "📓 오답노트로" if PackStore.is_review_mode else "홈으로"
	_advance_button.visible = true
	_advance_button.pressed.disconnect(_on_advance)
	if PackStore.is_review_mode:
		_advance_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/WrongNote.tscn"))
	else:
		_advance_button.pressed.connect(_go_home)
	_show_celebration(record)


# Animated congrats overlay on pack completion — bounce-in panel, pulsing title,
# light confetti, and the completion reward (강화권 +N). Sits on top of the
# completion screen; dismissed with its 확인 button.
func _show_celebration(record: Dictionary) -> void:
	var reward := int(record.get("reward_tickets", 0))
	if reward <= 0 and PackStore.is_review_mode:
		return  # review sessions: no celebration/reward

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _celebration_stylebox())
	panel.pivot_offset = Vector2(180, 130)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var title := Label.new()
	title.text = "🎉  축하합니다!  🎉"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(1.0, 0.9, 0.4)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "%s 완주!" % record.get("packTitle", "문제집")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(0.9, 0.93, 1.0)
	box.add_child(sub)

	var score := Label.new()
	score.text = "%d / %d 정답  ·  최고 콤보 %d" % [
		int(record.get("correct", 0)), int(record.get("total", 0)), int(record.get("bestCombo", 0)),
	]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 15)
	score.modulate = Color(0.75, 0.82, 0.95)
	box.add_child(score)

	if reward > 0:
		var reward_label := Label.new()
		reward_label.text = "🎟  강화권 +%d 지급!" % reward
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.add_theme_font_size_override("font_size", 22)
		reward_label.modulate = Color(0.55, 1.0, 0.7)
		box.add_child(reward_label)

	var ok := Button.new()
	ok.text = "확인"
	ok.custom_minimum_size = Vector2(160, 46)
	ok.add_theme_font_size_override("font_size", 17)
	ok.pressed.connect(func(): overlay.queue_free())
	var ok_row := HBoxContainer.new()
	ok_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ok_row.add_child(ok)
	box.add_child(ok_row)

	# Animate: dim fades in, panel bounces in, title pulses, confetti falls.
	panel.scale = Vector2(0.6, 0.6)
	var t := create_tween().set_parallel(true)
	t.tween_property(overlay, "color:a", 0.62, 0.25)
	t.tween_property(panel, "scale", Vector2(1.06, 1.06), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.12)
	var pulse := create_tween().set_loops()
	pulse.tween_property(title, "modulate", Color(1.0, 1.0, 0.65), 0.6)
	pulse.tween_property(title, "modulate", Color(1.0, 0.85, 0.3), 0.6)
	_spawn_confetti(overlay)


func _celebration_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.20)
	sb.border_color = Color(1.0, 0.85, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	return sb


func _spawn_confetti(parent: Control) -> void:
	var glyphs := ["🎉", "✨", "🎊", "⭐", "🌟"]
	for i in 14:
		var c := Label.new()
		c.text = glyphs[i % glyphs.size()]
		c.add_theme_font_size_override("font_size", 20 + (i % 3) * 8)
		c.position = Vector2(randf_range(40.0, size.x - 40.0), -30.0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(c)
		var fall := create_tween().set_parallel(true)
		var dur := randf_range(1.6, 2.8)
		fall.tween_property(c, "position:y", size.y + 40.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(c, "position:x", c.position.x + randf_range(-60.0, 60.0), dur)
		fall.tween_property(c, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
		fall.chain().tween_callback(c.queue_free)


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
