# Character + boss sprite + simple pulse FX on correct/wrong answers.
# Replaces src/renderer/effects/CharacterSlot.tsx + StageManager.ts.
#
# We use TextureRect (not Sprite2D) so the character lives inside the
# Control hierarchy and auto-scales with the parent slot. The slot is
# wide and short (boss right, character left), matching the redesign
# from study_game §UI redesign.

extends Control

var _character_rect: TextureRect
var _boss_rect: TextureRect
var _hp_bar: ProgressBar
var _splash_label: Label

# Tween-based pulse for correct/wrong feedback (replaces PIXI particles).
var _last_correct_unix: float = 0.0

const BOSS_MAX_HP_PER_STAGE := {
	Leveling.EffectStage.NOVICE: 5,
	Leveling.EffectStage.JUNIOR: 10,
	Leveling.EffectStage.SENIOR: 18,
	Leveling.EffectStage.LEGEND: 30,
}

const BOSS_SLOT_PER_STAGE := {
	Leveling.EffectStage.NOVICE: "goblin",
	Leveling.EffectStage.JUNIOR: "dragon",
	Leveling.EffectStage.SENIOR: "hydra",
	Leveling.EffectStage.LEGEND: "behemoth",
}

var _current_stage: int = Leveling.EffectStage.NOVICE
var _current_hp: int = 5


func _ready() -> void:
	_build_layout()
	_apply_stage_for_level(ProgressStore.get_level())
	_refresh_sprites()
	ProgressStore.theme_changed.connect(func(_id): _refresh_sprites())
	ProgressStore.progress_changed.connect(_on_progress_changed)
	PackStore.feedback.connect(_on_feedback)


func _build_layout() -> void:
	# Background panel — soft tinted bar so the slot reads as a stage.
	var bg := ColorRect.new()
	bg.set_offsets_preset(Control.PRESET_FULL_RECT)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.094, 0.106, 0.133)
	add_child(bg)

	# Character — left 20%
	_character_rect = TextureRect.new()
	_character_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_character_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_character_rect.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_character_rect.set_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	_character_rect.size_flags_horizontal = 0
	_character_rect.custom_minimum_size = Vector2(220, 0)
	add_child(_character_rect)

	# Boss — right 30%
	_boss_rect = TextureRect.new()
	_boss_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_boss_rect.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_boss_rect.set_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	_boss_rect.custom_minimum_size = Vector2(260, 0)
	add_child(_boss_rect)

	# Boss HP bar — above boss
	_hp_bar = ProgressBar.new()
	_hp_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hp_bar.offset_left = -280
	_hp_bar.offset_right = -20
	_hp_bar.offset_top = 8
	_hp_bar.offset_bottom = 18
	_hp_bar.show_percentage = false
	_hp_bar.value = 100
	add_child(_hp_bar)

	# Splash for pulse text
	_splash_label = Label.new()
	_splash_label.add_theme_font_size_override("font_size", 26)
	_splash_label.modulate = Color(1, 1, 1, 0)
	_splash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash_label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_splash_label)


func _refresh_sprites() -> void:
	var stage_name := Leveling.effect_stage_name(_current_stage)
	_character_rect.texture = ThemeStore.texture_for_stage(stage_name)
	var boss_slot: String = BOSS_SLOT_PER_STAGE.get(_current_stage, "goblin")
	_boss_rect.texture = ThemeStore.texture_for_boss(boss_slot)


func _on_progress_changed() -> void:
	var new_stage := Leveling.effect_stage_from_level(ProgressStore.get_level())
	if new_stage != _current_stage:
		_apply_stage_for_level(ProgressStore.get_level())
		_refresh_sprites()


func _apply_stage_for_level(level: int) -> void:
	_current_stage = Leveling.effect_stage_from_level(level)
	_current_hp = BOSS_MAX_HP_PER_STAGE.get(_current_stage, 5)
	_hp_bar.max_value = _current_hp
	_hp_bar.value = _current_hp


func _on_feedback(correct: bool, _explanation: String) -> void:
	if correct:
		_pulse_correct()
	else:
		_pulse_wrong()


func _pulse_correct() -> void:
	var multiplier := Weapon.weapon_damage_multiplier(ProgressStore.get_weapon_level())
	var damage: int = max(1, int(round(1 * multiplier)))
	_current_hp = max(0, _current_hp - damage)
	_hp_bar.value = _current_hp

	_splash_label.text = "-%d" % damage
	_splash_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
	_animate_splash()

	if _current_hp <= 0:
		PackStore.register_boss_defeat()
		await get_tree().create_timer(0.5).timeout
		_current_hp = BOSS_MAX_HP_PER_STAGE.get(_current_stage, 5)
		_hp_bar.value = _current_hp


func _pulse_wrong() -> void:
	_splash_label.text = "!"
	_splash_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
	_animate_splash()

	# Character shake
	var tw := create_tween()
	var origin := _character_rect.position
	tw.tween_property(_character_rect, "position:x", origin.x - 8, 0.06)
	tw.tween_property(_character_rect, "position:x", origin.x + 8, 0.06)
	tw.tween_property(_character_rect, "position:x", origin.x, 0.06)


func _animate_splash() -> void:
	_splash_label.position.y = 0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_splash_label, "position:y", -40.0, 0.6)
	tw.tween_property(_splash_label, "modulate:a", 0.0, 0.6)
