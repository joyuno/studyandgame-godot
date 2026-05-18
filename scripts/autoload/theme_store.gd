# Character theme registry. Selects sprite resources per stage + boss slot.
# Replaces src/renderer/effects/themes/* from the Electron port.
#
# Each theme maps `EffectStage` → texture resource path. Prefer the
# pre-sliced AtlasTexture (.tres) when one exists; otherwise fall back to
# the raw PNG. Missing slots return null → CharacterDisplay shows a
# ColorRect placeholder instead.

extends Node

const DEFAULT_THEME_ID: String = "programmer"

const REGISTRY: Dictionary = {
	"programmer": {
		"display_name": "프로그래머",
		"description": "OpenGameArt CC0 픽셀 엔지니어 (학원생→주니어→시니어→전설).",
		"source": "cc0",
		"stages": {
			"novice": "res://assets/characters/programmer/lv01_idle_frame.tres",
			"junior": "res://assets/characters/programmer/lv05_idle.png",
			"senior": "res://assets/characters/programmer/lv10_idle.png",
			"legend": "",
		},
		"bosses": {
			"goblin": "res://assets/characters/programmer/bosses/goblin_frame.tres",
			"dragon": "res://assets/characters/programmer/bosses/dragon.png",
			"hydra": "",
			"behemoth": "",
		},
	},
	"wizard": {
		"display_name": "마법사·연금술사",
		"description": "DungeonTileset II (CC0). 어학·과학 학습자에 권장.",
		"source": "cc0",
		"stages": {
			"novice": "res://assets/characters/wizard/lv01_idle_frame.tres",
			"junior": "res://assets/characters/wizard/lv05_idle.png",
			"senior": "res://assets/characters/wizard/lv10_idle.png",
			"legend": "",
		},
		"bosses": {
			"goblin": "res://assets/characters/wizard/bosses/goblin_frame.tres",
			"dragon": "res://assets/characters/wizard/bosses/dragon.png",
			"hydra": "",
			"behemoth": "",
		},
	},
	"ninja": {
		"display_name": "Ninja Adventure (CC0)",
		"description": "pixel-boy Ninja Adventure 자산. 1프레임 슬라이싱 적용.",
		"source": "cc0",
		"stages": {
			"novice": "res://assets/characters/ninja/lv01_idle_frame.tres",
			"junior": "",
			"senior": "",
			"legend": "",
		},
		"bosses": { "goblin": "", "dragon": "", "hydra": "", "behemoth": "" },
	},
	"chef": {
		"display_name": "셰프",
		"description": "요리 도메인 학습자용 placeholder.",
		"source": "cc0",
		"stages": {
			"novice": "res://assets/characters/chef/lv01_idle.png",
			"junior": "res://assets/characters/chef/lv05_idle.png",
			"senior": "res://assets/characters/chef/lv10_idle.png",
			"legend": "res://assets/characters/chef/lv20_idle.png",
		},
		"bosses": { "goblin": "", "dragon": "", "hydra": "", "behemoth": "" },
	},
	"animal": {
		"display_name": "동물 친구",
		"description": "캐주얼 학습용.",
		"source": "cc0",
		"stages": {
			"novice": "res://assets/characters/animal/lv01_idle.png",
			"junior": "res://assets/characters/animal/lv05_idle.png",
			"senior": "res://assets/characters/animal/lv10_idle.png",
			"legend": "res://assets/characters/animal/lv20_idle.png",
		},
		"bosses": { "goblin": "", "dragon": "", "hydra": "", "behemoth": "" },
	},
	"explorer": {
		"display_name": "탐험가",
		"description": "역사·지리 학습자에 권장.",
		"source": "cc0",
		"stages": {
			"novice": "res://assets/characters/explorer/lv01_idle.png",
			"junior": "res://assets/characters/explorer/lv05_idle.png",
			"senior": "",
			"legend": "",
		},
		"bosses": {
			"goblin": "",
			"dragon": "res://assets/characters/explorer/bosses/dragon.png",
			"hydra": "", "behemoth": "",
		},
	},
	"robot": {
		"display_name": "로봇",
		"description": "공학·물리 학습자용.",
		"source": "placeholder",
		"stages": {
			"novice": "res://assets/characters/robot/lv01_idle.png",
			"junior": "", "senior": "", "legend": "",
		},
		"bosses": { "goblin": "", "dragon": "", "hydra": "", "behemoth": "" },
	},
}


func list_theme_ids() -> Array:
	return REGISTRY.keys()


func get_theme(id: String) -> Dictionary:
	return REGISTRY.get(id, REGISTRY[DEFAULT_THEME_ID])


# Returns a Texture2D (loaded resource) for the given stage of the active
# theme, or null if no asset was mapped. Tries the configured path first;
# automatically falls back to the .png sibling when a .tres lookup fails
# (handy when only the raw PNG has been imported so far).
func texture_for_stage(stage_name: String) -> Texture2D:
	var theme := get_theme(ProgressStore.get_selected_theme_id())
	var stages: Dictionary = theme.get("stages", {})
	var path: String = stages.get(stage_name, "")
	return _load_or_null(path)


func texture_for_boss(boss_slot: String) -> Texture2D:
	var theme := get_theme(ProgressStore.get_selected_theme_id())
	var bosses: Dictionary = theme.get("bosses", {})
	var path: String = bosses.get(boss_slot, "")
	return _load_or_null(path)


func _load_or_null(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		# Fallback: try the raw PNG if we asked for a .tres atlas.
		if path.ends_with("_frame.tres"):
			var png_path := path.replace("_frame.tres", ".png")
			if ResourceLoader.exists(png_path):
				return load(png_path) as Texture2D
		return null
	return load(path) as Texture2D
