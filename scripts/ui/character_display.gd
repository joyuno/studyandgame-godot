# Character + boss display + pulse FX. Re-tuned for the Kenney aliens which
# are crisp single-PNG sprites (~70x100). Uses STRETCH_KEEP_ASPECT_CENTERED
# so they scale up cleanly to fill the slot without distortion.

extends Control

var _character_rect: TextureRect
var _boss_rect: TextureRect
var _hp_bar: ProgressBar
var _splash_label: Label
var _boss_name_label: Label

const BOSS_MAX_HP_PER_STAGE := {
	Leveling.EffectStage.NOVICE: 5,
	Leveling.EffectStage.JUNIOR: 10,
	Leveling.EffectStage.SENIOR: 18,
	Leveling.EffectStage.LEGEND: 30,
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
	# Tinted backdrop so the slot reads as a stage.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#13182380")  # darker than the page bg, semi-transparent
	add_child(bg)

	# Center the character vs boss face-off
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 120)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	center.add_child(row)

	# Character on the left
	_character_rect = _make_sprite_rect()
	_character_rect.name = "character"
	row.add_child(_character_rect)

	# VS in the middle
	var vs := Label.new()
	vs.text = "VS"
	vs.add_theme_font_size_override("font_size", 26)
	vs.modulate = Color(0.5, 0.55, 0.7)
	vs.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(vs)

	# Boss on the right (vertical stack: name + HP + sprite)
	var boss_col := VBoxContainer.new()
	boss_col.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_col.add_theme_constant_override("separation", 6)
	row.add_child(boss_col)

	_boss_name_label = Label.new()
	_boss_name_label.add_theme_font_size_override("font_size", 14)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.modulate = Color(1, 0.7, 0.7)
	boss_col.add_child(_boss_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(200, 12)
	_hp_bar.value = 100
	boss_col.add_child(_hp_bar)

	_boss_rect = _make_sprite_rect()
	_boss_rect.name = "boss"
	boss_col.add_child(_boss_rect)

	# Floating splash for damage/wrong feedback
	_splash_label = Label.new()
	_splash_label.add_theme_font_size_override("font_size", 36)
	_splash_label.modulate = Color(1, 1, 1, 0)
	_splash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash_label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_splash_label)


func _make_sprite_rect() -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(180, 220)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size_flags_horizontal = SIZE_SHRINK_CENTER
	return rect


func _refresh_sprites() -> void:
	var stage_name := Leveling.effect_stage_name(_current_stage)
	_character_rect.texture = ThemeStore.texture_for_stage(stage_name)
	_boss_rect.texture = ThemeStore.texture_for_stage_boss(stage_name)
	var boss_id: String = ThemeStore.BOSS_FOR_STAGE.get(stage_name, "ant")
	_boss_name_label.text = ThemeStore.boss_display_name(boss_id)


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
	tw.tween_property(_character_rect, "position:x", origin.x - 10, 0.06)
	tw.tween_property(_character_rect, "position:x", origin.x + 10, 0.06)
	tw.tween_property(_character_rect, "position:x", origin.x, 0.06)


func _animate_splash() -> void:
	_splash_label.position.y = 0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_splash_label, "position:y", -50.0, 0.7)
	tw.tween_property(_splash_label, "modulate:a", 0.0, 0.7)
