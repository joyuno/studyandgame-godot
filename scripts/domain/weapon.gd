# Weapon enhancement system — 검강화하기 정통 트랙 (3-outcome).
#
# Each attempt resolves to one of three outcomes:
#   success → level + 1 (capped at ENHANCE_MAX_LEVEL)
#   stay    → level unchanged
#   destroy → level → 0, the player gains `shards` worth of fragments
#
# +0..+2 are safe (destroy rate 0). Destroy is introduced at +3 and ramps up
# with level. There is NO automatic -2 downgrade — that mechanic belonged to
# the earlier Lineage-style port and was retired when shards landed.
#
# A consumed protection scroll converts a destroy outcome into a stay (the
# success/stay split is unaffected). Scrolls are useless below +3.
#
# Static helpers — no state. ProgressStore holds the actual weapon level /
# tickets / shards.

class_name Weapon
extends RefCounted

# [success_rate, destroy_rate] per starting level (index = current level when
# trying +1). stay_rate = 1 - success_rate - destroy_rate. Values must sum
# to ≤ 1.0. Sourced from the 검강화하기 NBS flash game reference table.
const ENHANCE_TABLE: Array = [
	[1.00, 0.00],  #  +0 → +1  : 100% success
	[0.90, 0.00],  #  +1 → +2  : 90% / 10% stay / 0% destroy
	[0.80, 0.00],  #  +2 → +3  : 80% / 20% / 0
	[0.70, 0.02],  #  +3 → +4  : 70% / 28% / 2%        ← destroy starts here
	[0.55, 0.05],  #  +4 → +5  : 55% / 40% / 5%
	[0.40, 0.10],  #  +5 → +6  : 40% / 50% / 10%
	[0.30, 0.15],  #  +6 → +7  : 30% / 55% / 15%
	[0.20, 0.20],  #  +7 → +8  : 20% / 60% / 20%
	[0.15, 0.25],  #  +8 → +9  : 15% / 60% / 25%
	[0.10, 0.30],  #  +9 → +10 : 10% / 60% / 30%
	[0.08, 0.35],  # +10 → +11 :  8% / 57% / 35%
	[0.06, 0.40],  # +11 → +12 :  6% / 54% / 40%
	[0.05, 0.45],  # +12 → +13 :  5% / 50% / 45%
	[0.04, 0.50],  # +13 → +14 :  4% / 46% / 50%
	[0.03, 0.55],  # +14 → +15 :  3% / 42% / 55%
]

const ENHANCE_MAX_LEVEL: int = 15
const ENHANCE_MATERIAL_COST: int = 1

# Difficulty modifiers applied on top of ENHANCE_TABLE.
#   easy : table as-is (the published 검강화하기 numbers)
#   hard : success × 0.85, destroy × 1.15 — same balance idea as the flash
#          game's hard mode where the curve gets meaner across the board.
const DIFFICULTY_MULT: Dictionary = {
	"easy": { "success": 1.0,  "destroy": 1.0  },
	"hard": { "success": 0.85, "destroy": 1.15 },
}


# Per-attempt resolver. Returns:
#   { result: "success" | "stay" | "stay_protected" | "destroy" | "max",
#     level:  resulting weapon level,
#     shards: shards gained (only non-zero on destroy) }
# `roll` is exposed so tests can pass a deterministic value; callers should
# omit it for real attempts (randf() is sampled internally).
static func try_attempt(level: int, use_scroll: bool, roll: float = -1.0, difficulty: String = "easy", success_bonus: float = 0.0) -> Dictionary:
	if level >= ENHANCE_MAX_LEVEL:
		return { "result": "max", "level": level, "shards": 0 }
	if level < 0 or level >= ENHANCE_TABLE.size():
		return { "result": "stay", "level": level, "shards": 0 }
	var success_rate: float = clampf(success_rate_at(level, difficulty) + maxf(0.0, success_bonus), 0.0, 1.0)
	var destroy_rate: float = destroy_rate_at(level, difficulty)
	var r: float = randf() if roll < 0.0 else roll
	if r < success_rate:
		return {
			"result": "success",
			"level": mini(ENHANCE_MAX_LEVEL, level + 1),
			"shards": 0,
		}
	if r < success_rate + destroy_rate:
		if use_scroll:
			return { "result": "stay_protected", "level": level, "shards": 0 }
		return {
			"result": "destroy",
			"level": 0,
			"shards": shard_reward_for_destroy(level),
		}
	return { "result": "stay", "level": level, "shards": 0 }


# Shard payout when a +N sword is destroyed = N² × 2.
# +5 → 50,  +10 → 200,  +14 → 392,  +15 (impossible, terminal) → 450.
static func shard_reward_for_destroy(level_lost: int) -> int:
	var n: int = maxi(0, level_lost)
	return n * n * 2


static func success_rate_at(level: int, difficulty: String = "easy") -> float:
	if level >= ENHANCE_MAX_LEVEL:
		return 0.0
	if level < 0 or level >= ENHANCE_TABLE.size():
		return 0.0
	var base: float = float(ENHANCE_TABLE[level][0])
	var mult: float = float(DIFFICULTY_MULT.get(difficulty, DIFFICULTY_MULT["easy"])["success"])
	return clampf(base * mult, 0.0, 1.0)


static func destroy_rate_at(level: int, difficulty: String = "easy") -> float:
	if level >= ENHANCE_MAX_LEVEL:
		return 0.0
	if level < 0 or level >= ENHANCE_TABLE.size():
		return 0.0
	var base: float = float(ENHANCE_TABLE[level][1])
	var mult: float = float(DIFFICULTY_MULT.get(difficulty, DIFFICULTY_MULT["easy"])["destroy"])
	# Clamp so success + destroy can never exceed 1.0 even after hard multiplier.
	var success_after: float = success_rate_at(level, difficulty)
	return clampf(base * mult, 0.0, 1.0 - success_after)


# +0 = 1.0×, +5 = 1.75×, +10 = 2.5×, +15 = 3.25×. Linear 0.15 per level.
static func weapon_damage_multiplier(level: int) -> float:
	return 1.0 + maxi(0, level) * 0.15


static func format_percent(p: float) -> String:
	return "%d%%" % roundi(p * 100.0)
