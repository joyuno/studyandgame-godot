# Side-scrolling idle RPG combat stage.
#
# Replaces the static VS layout with a continuous auto-attack loop:
#   character (anchored bottom-left) shoots a projectile every ~1.5 sec at
#   boss (anchored bottom-right). The projectile does NOT damage the boss
#   on its own — that's just idle eye-candy. Real damage comes from
#   PackStore.feedback (correct answer): bigger projectile, damage number,
#   HP bar drops by `weapon_damage_multiplier(weapon level)`.
#
# Layout philosophy: both sprites stand on the same ground line, face each
# other, animate (bob, lunge, recoil) so the screen never looks frozen.
# Background is a simple sky + grass gradient — a forest .png can drop in
# later by swapping the bg ColorRects for a TextureRect.

extends Control

var _bg_sky: ColorRect
var _bg_grass: ColorRect
var _ground_line: ColorRect
var _character_rect: TextureRect
var _boss_rect: TextureRect
var _hp_bar: ProgressBar
var _boss_name_label: Label
var _splash_layer: Control     # holds floating damage numbers & status splashes
var _projectile_layer: Control # holds in-flight projectiles

# Idle attack loop
var _attack_timer: Timer
var _idle_t: float = 0.0       # ambient bob

const BOSS_MAX_HP_PER_STAGE := {
	Leveling.EffectStage.NOVICE: 5,
	Leveling.EffectStage.JUNIOR: 10,
	Leveling.EffectStage.SENIOR: 18,
	Leveling.EffectStage.LEGEND: 30,
}

var _current_stage: int = Leveling.EffectStage.NOVICE
var _current_hp: int = 5

const CHARACTER_X_RATIO := 0.22
const BOSS_X_RATIO := 0.74
const GROUND_Y_RATIO := 0.84  # sprites' baseline (= top of the grass band)


func _ready() -> void:
	_build_layout()
	_apply_stage_for_level(ProgressStore.get_level())
	_refresh_sprites()
	ProgressStore.theme_changed.connect(func(_id): _refresh_sprites())
	ProgressStore.progress_changed.connect(_on_progress_changed)
	PackStore.feedback.connect(_on_feedback)
	set_process(true)


func _build_layout() -> void:
	# Sky (top half) + grass (bottom half) for that idle-RPG outdoor feel.
	_bg_sky = ColorRect.new()
	_bg_sky.color = Color("#1d2a47")  # dusk blue
	_bg_sky.anchors_preset = Control.PRESET_FULL_RECT
	_bg_sky.set_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_sky)

	_bg_grass = ColorRect.new()
	_bg_grass.color = Color("#1e3a2a")  # mossy green
	_bg_grass.anchor_left = 0.0
	_bg_grass.anchor_right = 1.0
	_bg_grass.anchor_top = GROUND_Y_RATIO
	_bg_grass.anchor_bottom = 1.0
	add_child(_bg_grass)

	_ground_line = ColorRect.new()
	_ground_line.color = Color("#0d1a14")
	_ground_line.anchor_left = 0.0
	_ground_line.anchor_right = 1.0
	_ground_line.anchor_top = GROUND_Y_RATIO
	_ground_line.anchor_bottom = GROUND_Y_RATIO
	_ground_line.offset_bottom = 3.0
	add_child(_ground_line)

	# Boss name + HP bar (top right of the stage, away from the boss sprite)
	_boss_name_label = Label.new()
	_boss_name_label.add_theme_font_size_override("font_size", 14)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_name_label.modulate = Color(1, 0.85, 0.85)
	_boss_name_label.anchor_left = 0.50
	_boss_name_label.anchor_right = 0.96
	_boss_name_label.anchor_top = 0.03
	_boss_name_label.anchor_bottom = 0.10
	add_child(_boss_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.anchor_left = 0.55
	_hp_bar.anchor_right = 0.96
	_hp_bar.anchor_top = 0.11
	_hp_bar.anchor_bottom = 0.14
	_hp_bar.value = 100
	add_child(_hp_bar)

	# Character sprite — anchored at bottom-left, sprite baseline at GROUND_Y
	_character_rect = _make_sprite_rect(CHARACTER_X_RATIO)
	_character_rect.name = "character"
	add_child(_character_rect)

	# Boss sprite — anchored at bottom-right
	_boss_rect = _make_sprite_rect(BOSS_X_RATIO)
	_boss_rect.name = "boss"
	_boss_rect.flip_h = true  # boss faces left toward character
	add_child(_boss_rect)

	_projectile_layer = Control.new()
	_projectile_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_projectile_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_projectile_layer)

	_splash_layer = Control.new()
	_splash_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_splash_layer)

	# Auto-attack idle loop (visual only — real damage routes through feedback).
	# Interval is level-scaled via CombatStats.attack_interval().
	_attack_timer = Timer.new()
	_attack_timer.wait_time = CombatStats.attack_interval(ProgressStore.get_level())
	_attack_timer.autostart = true
	_attack_timer.timeout.connect(_ambient_attack)
	add_child(_attack_timer)


func _make_sprite_rect(x_ratio: float) -> TextureRect:
	var rect := TextureRect.new()
	# KEEP_ASPECT_CENTERED fits the sprite inside the Control rect, preserving
	# aspect. expand_mode IGNORE_SIZE makes the rect honour its anchored size
	# instead of growing to the native 512×512 source.
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Width ±10%, height extends from 33% above ground to slightly below it
	# so the character's transparent-padded feet visually rest on the grass.
	rect.anchor_left = x_ratio - 0.10
	rect.anchor_right = x_ratio + 0.10
	rect.anchor_top = GROUND_Y_RATIO - 0.55
	rect.anchor_bottom = GROUND_Y_RATIO + 0.08
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _refresh_sprites() -> void:
	var stage_name := Leveling.effect_stage_name(_current_stage)
	_character_rect.texture = ThemeStore.texture_for_stage(stage_name)
	_boss_rect.texture = ThemeStore.texture_for_stage_boss(stage_name)
	var boss_id: String = ThemeStore.BOSS_FOR_STAGE.get(stage_name, "bug_goblin")
	_boss_name_label.text = ThemeStore.boss_display_name(boss_id)


func _on_progress_changed() -> void:
	# Re-tune the auto-attack cadence as the player levels up.
	if _attack_timer:
		_attack_timer.wait_time = CombatStats.attack_interval(ProgressStore.get_level())
	var new_stage := Leveling.effect_stage_from_level(ProgressStore.get_level())
	if new_stage != _current_stage:
		_apply_stage_for_level(ProgressStore.get_level())
		_refresh_sprites()
		_spawn_splash("⬆ STAGE UP", Color(1, 0.85, 0.3, 1), 0.55)


func _apply_stage_for_level(level: int) -> void:
	_current_stage = Leveling.effect_stage_from_level(level)
	_current_hp = BOSS_MAX_HP_PER_STAGE.get(_current_stage, 5)
	_hp_bar.max_value = _current_hp
	_hp_bar.value = _current_hp


func _process(delta: float) -> void:
	_idle_t += delta
	# Gentle bob (vertical sine) so neither sprite looks frozen.
	if _character_rect:
		_character_rect.position.y = sin(_idle_t * 1.8) * 3.0
	if _boss_rect:
		_boss_rect.position.y = sin(_idle_t * 1.5 + 1.0) * 3.5


# Cosmetic-only periodic attack — visualizes the "always fighting" loop.
# Does NOT change HP. Real damage flows through _on_feedback.
func _ambient_attack() -> void:
	var style := WeaponStyles.for_theme(ProgressStore.get_selected_theme_id())
	_spawn_projectile(style, 0.7, 0.4)
	_lunge(_character_rect, +12.0, 0.18)


func _on_feedback(correct: bool, _explanation: String) -> void:
	if correct:
		_strike_correct()
	else:
		_strike_wrong()


func _strike_correct() -> void:
	var damage := CombatStats.final_damage(ProgressStore.get_level(), ProgressStore.get_weapon_level())
	_current_hp = max(0, _current_hp - damage)
	_hp_bar.value = _current_hp

	_lunge(_character_rect, +20.0, 0.15)
	var style := WeaponStyles.for_theme(ProgressStore.get_selected_theme_id())
	_spawn_projectile(style, 1.2, 0.32, func():
		_recoil(_boss_rect, +18.0, 0.18)
		_flash(_boss_rect, Color(1, 0.4, 0.4))
		_spawn_damage_number(damage)
	)

	if _current_hp <= 0:
		PackStore.register_boss_defeat()
		_spawn_splash("DEFEATED", Color(1, 0.95, 0.3, 1), 0.7)
		await get_tree().create_timer(0.6).timeout
		_current_hp = BOSS_MAX_HP_PER_STAGE.get(_current_stage, 5)
		_hp_bar.value = _current_hp
		_flash(_boss_rect, Color(0.8, 1.0, 0.8))


func _strike_wrong() -> void:
	_recoil(_character_rect, -16.0, 0.18)
	_flash(_character_rect, Color(1, 0.4, 0.4))
	_spawn_splash("!", Color(1, 0.45, 0.45, 1), 0.5)


# Visual helpers --------------------------------------------------------------

func _lunge(rect: TextureRect, dx: float, dur: float) -> void:
	if rect == null: return
	var tw := create_tween()
	tw.tween_property(rect, "position:x", dx, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "position:x", 0.0, dur * 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _recoil(rect: TextureRect, dx: float, dur: float) -> void:
	if rect == null: return
	var tw := create_tween()
	tw.tween_property(rect, "position:x", dx, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "position:x", 0.0, dur * 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _flash(rect: TextureRect, color: Color) -> void:
	if rect == null: return
	var tw := create_tween()
	rect.modulate = color
	tw.tween_property(rect, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_QUAD)


func _spawn_projectile(style: Dictionary, scale: float, duration: float, on_hit: Callable = func(): pass) -> void:
	if size.x <= 0:
		return
	var node := _build_projectile_node(style, scale)
	var half := node.size.x * 0.5
	node.position = Vector2(size.x * CHARACTER_X_RATIO + 24 - half, size.y * (GROUND_Y_RATIO - 0.30))
	_projectile_layer.add_child(node)

	var target_x := size.x * BOSS_X_RATIO - 24 - half
	var target_y := size.y * (GROUND_Y_RATIO - 0.28)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "position", Vector2(target_x, target_y), duration).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(node, "modulate:a", 0.7, duration)
	if style.get("shape", "") == "star":
		tw.tween_property(node, "rotation", TAU * 2.0, duration)
	tw.chain().tween_callback(func():
		node.queue_free()
		on_hit.call()
	)


# Build a projectile node based on the weapon style (color + shape).
# Uses Polygon2D for shapes that need rotation, ColorRect for simple ones.
func _build_projectile_node(style: Dictionary, scale: float) -> Control:
	var base_size: int = int(style.get("size", 14)) * scale
	var color: Color = style.get("color", Color.WHITE)
	var shape: String = style.get("shape", "orb")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(base_size, base_size)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.pivot_offset = Vector2(base_size * 0.5, base_size * 0.5)

	var poly := Polygon2D.new()
	poly.color = color
	poly.polygon = _shape_polygon(shape, base_size)
	holder.add_child(poly)

	# Outline for crispness
	var outline := Line2D.new()
	outline.default_color = Color(0, 0, 0, 0.55)
	outline.width = 2.0
	outline.points = poly.polygon
	outline.closed = true
	holder.add_child(outline)

	return holder


# Returns vertex array for the given shape, centered around (size/2, size/2).
func _shape_polygon(shape: String, s: float) -> PackedVector2Array:
	var hs := s * 0.5
	var verts := PackedVector2Array()
	match shape:
		"square":
			# Code-snippet block
			verts.append(Vector2(0, 0))
			verts.append(Vector2(s, 0))
			verts.append(Vector2(s, s))
			verts.append(Vector2(0, s))
		"orb":
			# Fireball — 12-vertex circle
			var n := 14
			for i in n:
				var a: float = TAU * i / n
				verts.append(Vector2(hs + cos(a) * hs, hs + sin(a) * hs))
		"star":
			# Shuriken — 4-point star
			verts.append(Vector2(hs, 0))
			verts.append(Vector2(hs + s * 0.18, hs - s * 0.18))
			verts.append(Vector2(s, hs))
			verts.append(Vector2(hs + s * 0.18, hs + s * 0.18))
			verts.append(Vector2(hs, s))
			verts.append(Vector2(hs - s * 0.18, hs + s * 0.18))
			verts.append(Vector2(0, hs))
			verts.append(Vector2(hs - s * 0.18, hs - s * 0.18))
		"arrow":
			# Horizontal arrow → head right
			verts.append(Vector2(0, hs * 0.6))
			verts.append(Vector2(s * 0.6, hs * 0.6))
			verts.append(Vector2(s * 0.6, hs * 0.3))
			verts.append(Vector2(s, hs))
			verts.append(Vector2(s * 0.6, hs * 1.7))
			verts.append(Vector2(s * 0.6, hs * 1.4))
			verts.append(Vector2(0, hs * 1.4))
		"pot":
			# Hot pot — rounded trapezoid
			verts.append(Vector2(s * 0.18, s * 0.30))
			verts.append(Vector2(s * 0.82, s * 0.30))
			verts.append(Vector2(s, s * 0.95))
			verts.append(Vector2(0, s * 0.95))
		_:
			# Default to a small diamond
			verts.append(Vector2(hs, 0))
			verts.append(Vector2(s, hs))
			verts.append(Vector2(hs, s))
			verts.append(Vector2(0, hs))
	return verts


func _spawn_damage_number(damage: int) -> void:
	var label := Label.new()
	label.text = "-%d" % damage
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(1, 0.95, 0.4, 1)
	label.position = Vector2(size.x * BOSS_X_RATIO - 20, size.y * (GROUND_Y_RATIO - 0.45))
	_splash_layer.add_child(label)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 60.0, 0.7).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(label, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(func(): label.queue_free())


func _spawn_splash(text: String, color: Color, dur: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.anchor_left = 0.4
	label.anchor_right = 0.6
	label.anchor_top = 0.30
	label.anchor_bottom = 0.36
	_splash_layer.add_child(label)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(func(): label.queue_free())
