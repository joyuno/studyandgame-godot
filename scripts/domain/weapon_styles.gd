# Per-job weapon visual + cosmetics for the auto-combat projectile.
# Style is purely *visual* — actual damage still comes from weapon level + leveling.
#
# Each job has:
#   color    : projectile tint
#   shape    : "orb" | "square" | "star" | "arrow" | "pot"
#   size     : base diameter in pixels (scales with weapon enhance level)
#   trail    : whether to leave a fading trail behind the projectile

class_name WeaponStyles
extends RefCounted

const STYLES: Dictionary = {
	"programmer": {
		"color": Color("#3dd6e0"),  # cyan code block
		"shape": "square",
		"size": 14,
		"trail": true,
		"label": "코드 스니펫",
	},
	"wizard": {
		"color": Color("#ff7a3a"),  # fire orange
		"shape": "orb",
		"size": 16,
		"trail": true,
		"label": "파이어볼",
	},
	"ninja": {
		"color": Color("#e6e6e6"),  # steel white
		"shape": "star",
		"size": 12,
		"trail": false,
		"label": "수리검",
	},
	"chef": {
		"color": Color("#8b5a2b"),  # cast iron brown
		"shape": "pot",
		"size": 16,
		"trail": false,
		"label": "뜨거운 냄비",
	},
	"explorer": {
		"color": Color("#fde047"),  # bright yellow arrow
		"shape": "arrow",
		"size": 18,
		"trail": false,
		"label": "화살",
	},
}


static func for_theme(theme_id: String) -> Dictionary:
	return STYLES.get(theme_id, STYLES["programmer"])
