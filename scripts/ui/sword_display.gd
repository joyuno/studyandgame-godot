# Central sword visual — used on Home, Forge, and Market.
# Listens to ProgressStore.weapon_changed and swaps the sprite; tier identity
# is now communicated through the level-badge font colour (no backdrop panel
# or ring — the prior style read as a stray button behind the blade).
#
# Layout: sword sprite stacked over an FX overlay (flash on enhance result),
# then the tier label + damage multiplier underneath in a VBox.

extends Control

const FLASH_DURATION: float = 0.45

var _root: VBoxContainer
var _stage: Control
var _sprite: TextureRect
var _fx_overlay: TextureRect
var _level_badge: Label
var _multiplier_label: Label
var _flash_tween: Tween


func _ready() -> void:
	_build_layout()
	_refresh()
	ProgressStore.weapon_changed.connect(_on_weapon_changed)
	ProgressStore.enhance_result.connect(_on_enhance_result)


func _build_layout() -> void:
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_theme_constant_override("separation", 8)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Stage — sprite + fx are centred inside this fixed-size Control. No
	# backdrop, no ring — the AI-rendered sword sits directly on the dark
	# theme background.
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(300, 300)
	_stage.size_flags_horizontal = SIZE_SHRINK_CENTER
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)

	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.size = Vector2(300, 300)
	_sprite.position = Vector2.ZERO
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_sprite)

	_fx_overlay = TextureRect.new()
	_fx_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fx_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fx_overlay.size = Vector2(300, 300)
	_fx_overlay.position = Vector2.ZERO
	_fx_overlay.modulate = Color(1, 1, 1, 0)
	_fx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_fx_overlay)

	_level_badge = Label.new()
	_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_badge.add_theme_font_size_override("font_size", 24)
	_level_badge.size_flags_horizontal = SIZE_EXPAND_FILL
	_root.add_child(_level_badge)

	_multiplier_label = Label.new()
	_multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multiplier_label.add_theme_font_size_override("font_size", 14)
	_multiplier_label.modulate = Color(0.75, 0.8, 0.9)
	_multiplier_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_root.add_child(_multiplier_label)


func _refresh() -> void:
	var lv := ProgressStore.get_weapon_level()
	_sprite.texture = SwordStore.texture_for_level(lv)
	_level_badge.text = SwordStore.tier_name(lv)
	_level_badge.add_theme_color_override("font_color", SwordStore.glow_color(lv))
	_multiplier_label.text = "데미지 ×%.2f" % Weapon.weapon_damage_multiplier(lv)


func _on_weapon_changed(_lv: int) -> void:
	_refresh()


func _on_enhance_result(success: bool, before: int, after: int, _tickets_left: int) -> void:
	var fx_name := "success"
	var tint := Color(1, 1, 1, 1)
	if not success:
		if after < before:
			fx_name = "destroy"
			tint = Color(1, 0.6, 0.6, 1)
		else:
			fx_name = "fail"
			tint = Color(1, 0.85, 0.7, 1)
	_play_fx(fx_name, tint)


func _play_fx(fx: String, tint: Color) -> void:
	var tex := SwordStore.texture_for_fx(fx)
	if tex == null:
		return
	_fx_overlay.texture = tex
	_fx_overlay.modulate = Color(tint.r, tint.g, tint.b, 0)
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_fx_overlay, "modulate:a", 1.0, FLASH_DURATION * 0.3)
	_flash_tween.tween_property(_fx_overlay, "modulate:a", 0.0, FLASH_DURATION * 0.7)
