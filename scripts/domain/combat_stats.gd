# Combat stats derived from the player's level + weapon enhance.
# Pure functions so they're easy to unit-test and the UI / stage can both
# read the same numbers.
#
# Design intent (idle-RPG curve):
#   attack_interval  starts slow (1.5 s) and ramps to fast (0.6 s) by Lv 20
#   base_damage      starts at 1 and grows linearly with level
#   final_damage     = base_damage × weapon_damage_multiplier(weapon_level)

class_name CombatStats
extends RefCounted

const BASE_ATTACK_INTERVAL: float = 1.5
const MIN_ATTACK_INTERVAL: float = 0.6
const ATTACK_INTERVAL_FLOOR_LEVEL: int = 20  # cap reached here

const BASE_DAMAGE: int = 1
const DAMAGE_PER_LEVEL: float = 0.1   # +1 base damage every 10 levels


# Returns attack interval in seconds. Linearly interpolates between
# BASE and MIN over levels 1..ATTACK_INTERVAL_FLOOR_LEVEL.
static func attack_interval(level: int) -> float:
	if level <= 1:
		return BASE_ATTACK_INTERVAL
	if level >= ATTACK_INTERVAL_FLOOR_LEVEL:
		return MIN_ATTACK_INTERVAL
	var t: float = float(level - 1) / float(ATTACK_INTERVAL_FLOOR_LEVEL - 1)
	return lerp(BASE_ATTACK_INTERVAL, MIN_ATTACK_INTERVAL, t)


static func base_damage(level: int) -> int:
	return BASE_DAMAGE + int(floor(max(0, level - 1) * DAMAGE_PER_LEVEL))


# Final damage for a single attack (correct answer) — base × weapon enhance.
static func final_damage(level: int, weapon_level: int) -> int:
	var base := base_damage(level)
	var mult := Weapon.weapon_damage_multiplier(weapon_level)
	return max(1, int(round(base * mult)))
