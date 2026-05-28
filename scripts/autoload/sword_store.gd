# Sword sprite + tier registry for the 검강화하기 game mode.
# Maps the player's weapon enhancement level (+0..+15) onto one of 16 AI-
# generated sword sprites + a tier label + a glow tint for the display panel.
#
# Sprites are AI-generated via Pollinations.ai (Flux model, 16-bit pixel art
# prompt). See scripts/gen-sprites.mjs + strip-bg.mjs. Each +N has its own
# sprite; visual energy ramps tier by tier (iron → steel → mithril → gold →
# legendary).

extends Node

# Display tier covers a range of levels — keeps the curve manageable for UI
# (tier label + glow + sell-price multiplier all key off this).
const TIERS: Array = [
	{ "min": 0,  "max": 2,  "name": "철검",    "color": Color("#9aa0a6") },  # iron grey
	{ "min": 3,  "max": 5,  "name": "강철검",  "color": Color("#cfd2d6") },  # steel
	{ "min": 6,  "max": 8,  "name": "미스릴검", "color": Color("#5ec5ff") },  # cyan
	{ "min": 9,  "max": 11, "name": "황금검",  "color": Color("#ffd24a") },  # gold
	{ "min": 12, "max": 15, "name": "전설검",  "color": Color("#c7a8ff") },  # legendary purple
]

const SPRITE_DIR := "res://assets/swords/"
const FX_SUCCESS := "res://assets/swords/fx_success.png"
const FX_FAIL    := "res://assets/swords/fx_fail.png"
const FX_DESTROY := "res://assets/swords/fx_destroy.png"

const ATTRIBUTION := "Pollinations.ai (Flux) — free generative AI, no rights reserved. https://pollinations.ai"


func sprite_path_for_level(level: int) -> String:
	var lv: int = clampi(level, 0, 15)
	return "%ssword_%02d.png" % [SPRITE_DIR, lv]


func texture_for_level(level: int) -> Texture2D:
	var path := sprite_path_for_level(level)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func tier_for_level(level: int) -> Dictionary:
	for t in TIERS:
		if level >= int(t["min"]) and level <= int(t["max"]):
			return t
	return TIERS[0]


func tier_name(level: int) -> String:
	var t := tier_for_level(level)
	return "%s +%d" % [t["name"], level]


func glow_color(level: int) -> Color:
	return tier_for_level(level)["color"]


# Resale price grows non-linearly so the player has a real incentive to push
# higher (and the sting of losing a +10 sword to -2 protection failure is real).
# Formula: 50 + level^2 * 100. Matches "검강화하기" feel: a +0 sells for 50,
# a +5 for 2,550, a +10 for 10,050, a +15 for 22,550.
func sell_price(level: int) -> int:
	return 50 + level * level * 100


func texture_for_fx(name: String) -> Texture2D:
	match name:
		"success":
			return _load_or_null(FX_SUCCESS)
		"fail":
			return _load_or_null(FX_FAIL)
		"destroy":
			return _load_or_null(FX_DESTROY)
	return null


func _load_or_null(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
