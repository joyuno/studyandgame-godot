# Weapon enhancement system (Lineage/Maple style).
# Ported from shared/constants/weapon.ts in the original Electron study_game.
# Static helpers — no state. ProgressStore holds the actual weapon level/materials.

class_name Weapon
extends RefCounted

# Success probability per attempt. Index = current level when trying +1.
const ENHANCE_SUCCESS_RATE: Array[float] = [
	1.0,   #  +0 → +1
	0.95,  #  +1 → +2
	0.85,  #  +2 → +3
	0.7,   #  +3 → +4
	0.55,  #  +4 → +5
	0.4,   #  +5 → +6
	0.3,   #  +6 → +7
	0.2,   #  +7 → +8
	0.15,  #  +8 → +9
	0.1,   #  +9 → +10
	0.08,  # +10 → +11
	0.06,  # +11 → +12
	0.05,  # +12 → +13
	0.04,  # +13 → +14
	0.03,  # +14 → +15
]

const ENHANCE_MAX_LEVEL: int = 15
const ENHANCE_MATERIAL_COST: int = 1
const MATERIAL_DROP_CHANCE: float = 0.35
const BOSS_KILL_MATERIAL_CHANCE: float = 0.5


# Success → level+1 (capped).
# Failure ≤ +5 → keep level (protected zone).
# Failure ≥ +6 → max(0, level-2).
static func next_level_after_attempt(current_level: int, success: bool) -> int:
	if success:
		return min(ENHANCE_MAX_LEVEL, current_level + 1)
	if current_level <= 5:
		return current_level
	return max(0, current_level - 2)


static func success_rate_at(level: int) -> float:
	if level >= ENHANCE_MAX_LEVEL:
		return 0.0
	if level < 0 or level >= ENHANCE_SUCCESS_RATE.size():
		return 0.0
	return ENHANCE_SUCCESS_RATE[level]


# +0 = 1.0×, +5 = 1.75×, +10 = 2.5×, +15 = 3.25×. Linear 0.15 per level.
static func weapon_damage_multiplier(level: int) -> float:
	return 1.0 + max(0, level) * 0.15


static func format_percent(p: float) -> String:
	return "%d%%" % roundi(p * 100.0)
