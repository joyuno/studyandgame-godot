# Character theme registry — 5 jobs (programmer/wizard/ninja/chef/explorer)
# vs 4 stage-based bosses (bug_goblin → null_dragon → race_hydra → tech_debt_giant).
#
# All sprites are AI-generated via Pollinations.ai (Flux model, 16-bit pixel
# art prompt). Backgrounds were flood-filled to transparent so they sit
# cleanly on the dark theme panel. See scripts/gen-sprites.mjs + strip-bg.mjs.

extends Node

const DEFAULT_THEME_ID: String = "programmer"

const BOSS_FOR_STAGE := {
	"novice": "bug_goblin",
	"junior": "null_dragon",
	"senior": "race_hydra",
	"legend": "tech_debt_giant",
}

const BOSS_DISPLAY_NAME := {
	"bug_goblin":      "Bug Goblin",
	"null_dragon":     "Null Pointer Dragon",
	"race_hydra":      "Race Condition Hydra",
	"tech_debt_giant": "Tech Debt Behemoth",
	"stack_ghost":     "Stack Overflow Ghost",
}

const REGISTRY: Dictionary = {
	"programmer": {
		"display_name": "프로그래머",
		"description": "안경 + 노트북. 소프트웨어·DB·인프라 학습자.",
		"source": "ai-generated",
		"sprite": "res://assets/characters/characters/programmer.png",
	},
	"wizard": {
		"display_name": "마법사",
		"description": "보라 로브 + 마법 지팡이. 어학·수학·과학 학습자.",
		"source": "ai-generated",
		"sprite": "res://assets/characters/characters/wizard.png",
	},
	"ninja": {
		"display_name": "닌자",
		"description": "검은 옷 + 카타나. 빠른 풀이 + 집중형 학습자.",
		"source": "ai-generated",
		"sprite": "res://assets/characters/characters/ninja.png",
	},
	"chef": {
		"display_name": "셰프",
		"description": "흰 모자 + 냄비. 요리·생활기술 학습자.",
		"source": "ai-generated",
		"sprite": "res://assets/characters/characters/chef.png",
	},
	"explorer": {
		"display_name": "탐험가",
		"description": "사파리 모자 + 지도. 역사·지리·여행 학습자.",
		"source": "ai-generated",
		"sprite": "res://assets/characters/characters/explorer.png",
	},
}

const ATTRIBUTION := "Pollinations.ai (Flux) — free generative AI, no rights reserved. https://pollinations.ai"


func list_theme_ids() -> Array:
	return REGISTRY.keys()


func get_theme(id: String) -> Dictionary:
	return REGISTRY.get(id, REGISTRY[DEFAULT_THEME_ID])


# Player sprite — same regardless of stage. Stage progression is communicated
# via boss escalation + weapon level + on-fire glow, not by morphing the player.
func texture_for_stage(_stage_name: String) -> Texture2D:
	var theme := get_theme(ProgressStore.get_selected_theme_id())
	return _load_or_null(theme.get("sprite", ""))


# Boss texture for the player's current EffectStage.
func texture_for_stage_boss(stage_name: String) -> Texture2D:
	var boss_id: String = BOSS_FOR_STAGE.get(stage_name, "bug_goblin")
	return _load_or_null("res://assets/characters/bosses/%s.png" % boss_id)


# Compatibility shim — older CharacterDisplay code paths may still call this.
func texture_for_boss(boss_id_or_slot: String) -> Texture2D:
	var direct := "res://assets/characters/bosses/%s.png" % boss_id_or_slot
	if ResourceLoader.exists(direct):
		return load(direct) as Texture2D
	# Legacy slot names from earlier iterations.
	var legacy_map := {
		"goblin":   "bug_goblin",
		"dragon":   "null_dragon",
		"hydra":    "race_hydra",
		"behemoth": "tech_debt_giant",
		"ant":      "bug_goblin",
		"bee":      "null_dragon",
		"bat":      "race_hydra",
		"blockie":  "tech_debt_giant",
		"eater":    "stack_ghost",
	}
	var mapped: String = legacy_map.get(boss_id_or_slot, "bug_goblin")
	return _load_or_null("res://assets/characters/bosses/%s.png" % mapped)


func boss_display_name(boss_id_or_slot: String) -> String:
	var legacy_map := {
		"goblin":   "bug_goblin",
		"dragon":   "null_dragon",
		"hydra":    "race_hydra",
		"behemoth": "tech_debt_giant",
		"ant":      "bug_goblin",
		"bee":      "null_dragon",
		"bat":      "race_hydra",
		"blockie":  "tech_debt_giant",
		"eater":    "stack_ghost",
	}
	var key: String = legacy_map.get(boss_id_or_slot, boss_id_or_slot)
	return BOSS_DISPLAY_NAME.get(key, key.capitalize())


func _load_or_null(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
