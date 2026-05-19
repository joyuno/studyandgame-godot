# Character theme registry. Each theme = one alien color (single-PNG, no
# sprite-sheet acrobatics). Bosses are shared across themes and scale with
# the player's level (one boss per EffectStage).
#
# After the asset audit, we dropped the original 7-theme "naked base" /
# multi-frame sprite sheets in favor of Kenney's Platformer Pack (CC0):
# clean, single-character PNGs that need zero slicing.

extends Node

const DEFAULT_THEME_ID: String = "beige"

# Per-stage boss slot (shared by every theme — alien player vs creature boss).
const BOSS_FOR_STAGE := {
	"novice": "ant",
	"junior": "bee",
	"senior": "bat",
	"legend": "blockie",
}

const BOSS_DISPLAY_NAME := {
	"ant": "Ant",
	"bee": "Bee",
	"bat": "Bat",
	"blockie": "Blockie",
	"eater": "Eater",
}

const REGISTRY: Dictionary = {
	"beige": {
		"display_name": "베이지 (입문자)",
		"description": "차분한 베이지 외계인. 처음 시작하는 학습자에게 추천.",
		"source": "cc0",
		"sprite": "res://assets/characters/aliens/beige.png",
	},
	"blue": {
		"display_name": "블루 (집중형)",
		"description": "쿨한 블루 외계인. 데이터·인프라 학습자에게.",
		"source": "cc0",
		"sprite": "res://assets/characters/aliens/blue.png",
	},
	"green": {
		"display_name": "그린 (활동가)",
		"description": "활기찬 그린 외계인. 활발한 풀이 패턴에 어울림.",
		"source": "cc0",
		"sprite": "res://assets/characters/aliens/green.png",
	},
	"pink": {
		"display_name": "핑크 (창의가)",
		"description": "감각적인 핑크 외계인. 디자인·언어 학습자에게.",
		"source": "cc0",
		"sprite": "res://assets/characters/aliens/pink.png",
	},
	"yellow": {
		"display_name": "옐로 (탐험가)",
		"description": "발랄한 옐로 외계인. 신규 도메인 탐색용.",
		"source": "cc0",
		"sprite": "res://assets/characters/aliens/yellow.png",
	},
}

# Attribution for the entire pack (single source).
const ATTRIBUTION := "Kenney Platformer Pack — CC0. https://kenney.nl"


func list_theme_ids() -> Array:
	return REGISTRY.keys()


func get_theme(id: String) -> Dictionary:
	return REGISTRY.get(id, REGISTRY[DEFAULT_THEME_ID])


# Player sprite — always the same regardless of stage. Stage progression is
# communicated via aura/HP-bar/weapon level, not by morphing the character.
# (The Electron version had stage-specific sprites but those required
# composing layered sheets, which is what made the visuals look broken.)
func texture_for_stage(_stage_name: String) -> Texture2D:
	var theme := get_theme(ProgressStore.get_selected_theme_id())
	var path: String = theme.get("sprite", "")
	return _load_or_null(path)


# Boss texture for the player's current EffectStage.
func texture_for_stage_boss(stage_name: String) -> Texture2D:
	var boss_id: String = BOSS_FOR_STAGE.get(stage_name, "ant")
	return _load_or_null("res://assets/characters/bosses/%s.png" % boss_id)


# Compatibility shim — older CharacterDisplay code calls texture_for_boss(slot).
# We now derive the slot from the current stage, but keep the old signature.
func texture_for_boss(boss_slot: String) -> Texture2D:
	# Direct lookup by name first
	var direct := "res://assets/characters/bosses/%s.png" % boss_slot
	if ResourceLoader.exists(direct):
		return load(direct) as Texture2D
	# Map legacy slot names → new bosses
	var legacy_map := {
		"goblin": "ant",
		"dragon": "bee",
		"hydra": "bat",
		"behemoth": "blockie",
	}
	var mapped: String = legacy_map.get(boss_slot, "ant")
	return _load_or_null("res://assets/characters/bosses/%s.png" % mapped)


func boss_display_name(boss_id_or_slot: String) -> String:
	# Honor legacy slot names too
	var legacy_map := {
		"goblin": "ant",
		"dragon": "bee",
		"hydra": "bat",
		"behemoth": "blockie",
	}
	var key: String = legacy_map.get(boss_id_or_slot, boss_id_or_slot)
	return BOSS_DISPLAY_NAME.get(key, key.capitalize())


func _load_or_null(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
