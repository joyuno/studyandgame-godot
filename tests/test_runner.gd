# Run via:
#   godot --headless --script res://tests/test_runner.gd
# Exits non-zero on any failed assertion.
#
# We don't pull in GUT — single-file harness is enough for the small
# pure-function port surface and keeps the project dependency-free.

extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _initialize() -> void:
	print("--- test runner ---")
	_test_weapon()
	_test_srs()
	_test_leveling()
	_test_pack_parser()
	_test_sword_store()
	_test_economy()
	_test_achievements()
	print("--- %d passed, %d failed ---" % [_passes, _failures])
	quit(0 if _failures == 0 else 1)


# -----------------------------------------------------------------------------
# SwordStore — pure mappings (sell price + tier ranges).
# `--script` runs before autoloads, so we instantiate the script manually
# rather than relying on the SwordStore global name.
# -----------------------------------------------------------------------------
func _test_sword_store() -> void:
	_section("SwordStore")
	var Store: Node = (load("res://scripts/autoload/sword_store.gd") as GDScript).new()
	_eq(Store.sell_price(0), 50, "+0 sells for 50")
	_eq(Store.sell_price(5), 2550, "+5 sells for 2,550 (50 + 25*100)")
	_eq(Store.sell_price(10), 10050, "+10 sells for 10,050")
	_eq(Store.sell_price(15), 22550, "+15 sells for 22,550")

	_eq(Store.tier_for_level(0)["name"], "철검", "+0 → 철검")
	_eq(Store.tier_for_level(2)["name"], "철검", "+2 → 철검")
	_eq(Store.tier_for_level(3)["name"], "강철검", "+3 → 강철검")
	_eq(Store.tier_for_level(6)["name"], "미스릴검", "+6 → 미스릴검")
	_eq(Store.tier_for_level(9)["name"], "황금검", "+9 → 황금검")
	_eq(Store.tier_for_level(15)["name"], "전설검", "+15 → 전설검")

	_eq(Store.sprite_path_for_level(0), "res://assets/swords/sword_00.png", "+0 sprite path")
	_eq(Store.sprite_path_for_level(15), "res://assets/swords/sword_15.png", "+15 sprite path")
	# Clamp out-of-range to the spec sprites (no crashes on bad inputs).
	_eq(Store.sprite_path_for_level(99), "res://assets/swords/sword_15.png", "clamp 99 → +15")
	_eq(Store.sprite_path_for_level(-5), "res://assets/swords/sword_00.png", "clamp -5 → +0")
	Store.free()


# -----------------------------------------------------------------------------
# Weapon
# -----------------------------------------------------------------------------
func _test_weapon() -> void:
	_section("Weapon")
	_eq(Weapon.ENHANCE_MAX_LEVEL, 15, "max level = 15")

	# Success/destroy rate lookup at representative tiers.
	_eq(Weapon.success_rate_at(0), 1.0, "+0 → 100% success")
	_eq(Weapon.success_rate_at(5), 0.4, "+5 → 40% success")
	_eq(Weapon.success_rate_at(15), 0.0, "+15 → cap (0)")
	_eq(Weapon.success_rate_at(99), 0.0, "way over cap → 0")
	_eq(Weapon.destroy_rate_at(0), 0.0, "+0 → 0% destroy (safe zone)")
	_eq(Weapon.destroy_rate_at(2), 0.0, "+2 → 0% destroy (safe zone)")
	_eq(Weapon.destroy_rate_at(3), 0.02, "+3 → destroy starts at 2%")
	_eq(Weapon.destroy_rate_at(10), 0.35, "+10 → 35% destroy")
	_eq(Weapon.destroy_rate_at(15), 0.0, "+15 → cap, no further attempts")

	# Deterministic roll → exact outcome. Table at +10 is success 0.08,
	# destroy 0.35 → cumulative success cutoff 0.08, destroy cutoff 0.43.
	var hit = Weapon.try_attempt(10, false, 0.05)
	_eq(hit.get("result"), "success", "roll 0.05 at +10 → success")
	_eq(int(hit.get("level")), 11, "success at +10 → +11")

	var bust = Weapon.try_attempt(10, false, 0.20)
	_eq(bust.get("result"), "destroy", "roll 0.20 at +10 (within destroy band) → destroy")
	_eq(int(bust.get("level")), 0, "destroy → +0 reset")
	_eq(int(bust.get("shards")), 200, "destroy at +10 → 200 shards (10² × 2)")

	var miss = Weapon.try_attempt(10, false, 0.70)
	_eq(miss.get("result"), "stay", "roll 0.70 at +10 (above destroy band) → stay")
	_eq(int(miss.get("level")), 10, "stay → level unchanged")

	# Safe zone (+0..+2) — destroy roll band has zero width, so any miss is stay.
	var safe = Weapon.try_attempt(2, false, 0.99)
	_eq(safe.get("result"), "stay", "+2 with high roll → stay (no destroy in safe zone)")

	# Scroll converts a destroy into stay_protected, level unchanged, no shards.
	var saved = Weapon.try_attempt(10, true, 0.20)
	_eq(saved.get("result"), "stay_protected", "scroll absorbs destroy")
	_eq(int(saved.get("level")), 10, "scroll → level unchanged")
	_eq(int(saved.get("shards")), 0, "scroll → no shard payout")

	# Scroll has NO effect on a regular stay roll.
	var miss2 = Weapon.try_attempt(10, true, 0.70)
	_eq(miss2.get("result"), "stay", "scroll does nothing on a non-destroy miss")

	# +15 is terminal regardless of roll.
	var capped = Weapon.try_attempt(15, false, 0.0)
	_eq(capped.get("result"), "max", "+15 → max, no roll consumed")

	# shard_reward_for_destroy is level² × 2, clamped at 0 for negatives.
	_eq(Weapon.shard_reward_for_destroy(5), 50, "+5 destroy → 50 shards")
	_eq(Weapon.shard_reward_for_destroy(10), 200, "+10 destroy → 200 shards")
	_eq(Weapon.shard_reward_for_destroy(14), 392, "+14 destroy → 392 shards")
	_eq(Weapon.shard_reward_for_destroy(-3), 0, "negative level → 0 shards")

	_eq(Weapon.weapon_damage_multiplier(0), 1.0, "+0 → ×1.0")
	_eq(Weapon.weapon_damage_multiplier(5), 1.75, "+5 → ×1.75")
	_eq(Weapon.weapon_damage_multiplier(10), 2.5, "+10 → ×2.5")
	_eq(Weapon.weapon_damage_multiplier(15), 3.25, "+15 → ×3.25")
	_eq(Weapon.weapon_damage_multiplier(-3), 1.0, "negative → ×1.0")

	_eq(Weapon.format_percent(1.0), "100%", "100%")
	_eq(Weapon.format_percent(0.5), "50%", "50%")
	_eq(Weapon.format_percent(0.005), "1%", "rounds 0.5% up to 1%")
	_eq(Weapon.format_percent(0.0), "0%", "0%")

	# Difficulty multipliers — easy is identity, hard pinches both rates.
	_eq(Weapon.success_rate_at(5, "easy"), 0.4, "easy +5 success identity")
	_eq(snapped(Weapon.success_rate_at(5, "hard"), 0.001), 0.34,
		"hard +5 success = 0.4 × 0.85 = 0.34")
	_eq(absf(Weapon.destroy_rate_at(10, "hard") - 0.4025) < 0.0001, true,
		"hard +10 destroy ≈ 0.35 × 1.15 = 0.4025")
	# Hard at +14: success 0.0255, destroy clamped so success+destroy ≤ 1.
	var s_hard_14: float = Weapon.success_rate_at(14, "hard")
	var d_hard_14: float = Weapon.destroy_rate_at(14, "hard")
	_eq(s_hard_14 + d_hard_14 <= 1.0001, true, "hard +14 success+destroy ≤ 1")

	# 행운 부적 성공률 보너스
	_eq(Weapon.try_attempt(5, false, 0.45, "easy")["result"] == "success", false, "+5 roll0.45 보너스X → 실패")
	_eq(Weapon.try_attempt(5, false, 0.45, "easy", 0.10)["result"], "success", "+5 roll0.45 +10%p → 성공")


# -----------------------------------------------------------------------------
# SRS
# -----------------------------------------------------------------------------
func _test_srs() -> void:
	_section("SRS")
	_eq(SRS.SRS_INTERVAL_DAYS, [1, 3, 7, 14, 30, 90], "interval ladder")
	_eq(SRS.SRS_GRADUATE_LEVEL, 6, "graduate at stage 6")

	var t0: float = 1_700_000_000.0  # fixed epoch for determinism
	var initial := SRS.initial_next_review_at(t0)
	_truthy(initial.length() > 0, "initial_next_review_at returns ISO string")

	var stage_0_correct := SRS.grade_review(0, true, t0)
	_eq(stage_0_correct.get("review_level"), 1, "stage 0 correct → 1")

	var stage_5_correct := SRS.grade_review(5, true, t0)
	_truthy(stage_5_correct.is_empty(), "stage 5 correct → graduated (empty dict)")

	var any_wrong := SRS.grade_review(3, false, t0)
	_eq(any_wrong.get("review_level"), 0, "wrong → reset to stage 0")

	_truthy(SRS.is_due("", t0), "missing timestamp counts as due")
	var past_iso := Time.get_datetime_string_from_unix_time(int(t0 - 3600), true)
	_truthy(SRS.is_due(past_iso, t0), "past timestamp is due")
	var future_iso := Time.get_datetime_string_from_unix_time(int(t0 + 86400), true)
	_truthy(not SRS.is_due(future_iso, t0), "future timestamp is not due")


# -----------------------------------------------------------------------------
# Leveling
# -----------------------------------------------------------------------------
func _test_leveling() -> void:
	_section("Leveling")
	_eq(Leveling.level_from_xp(0), 1, "0 xp → lv 1")
	_eq(Leveling.level_from_xp(50), 1, "50 xp → lv 1 (under 100)")
	_eq(Leveling.level_from_xp(100), 2, "100 xp → lv 2")
	_eq(Leveling.level_from_xp(300), 3, "300 xp → lv 3")
	_eq(Leveling.level_from_xp(600), 4, "600 xp → lv 4")

	_eq(Leveling.combo_multiplier(0), 1.0, "combo 0 → 1.0")
	_eq(Leveling.combo_multiplier(2), 1.5, "combo 2 → 1.5")
	_eq(Leveling.combo_multiplier(5), 2.0, "combo 5 → 2.0 (On Fire)")
	_eq(Leveling.combo_multiplier(10), 3.0, "combo 10 → 3.0")

	_truthy(not Leveling.is_on_fire(4), "combo 4 not on fire")
	_truthy(Leveling.is_on_fire(5), "combo 5 on fire")

	_eq(Leveling.effect_stage_from_level(1), Leveling.EffectStage.NOVICE, "lv 1 → novice")
	_eq(Leveling.effect_stage_from_level(5), Leveling.EffectStage.JUNIOR, "lv 5 → junior")
	_eq(Leveling.effect_stage_from_level(10), Leveling.EffectStage.SENIOR, "lv 10 → senior")
	_eq(Leveling.effect_stage_from_level(20), Leveling.EffectStage.LEGEND, "lv 20 → legend")


# -----------------------------------------------------------------------------
# PackParser
# -----------------------------------------------------------------------------
func _test_pack_parser() -> void:
	_section("PackParser")
	var valid := JSON.stringify({
		"meta": { "title": "test", "version": "0.1.0" },
		"questions": [
			{ "type": "mcq", "q": "1+1=?", "choices": ["1", "2", "3"], "answer": 1 },
			{ "type": "ox", "q": "earth is round", "answer": true },
		],
	})
	var ok := PackParser.parse_string(valid)
	_truthy(ok.get("ok") == true, "valid pack parses")

	var bad_mcq := JSON.stringify({
		"meta": { "title": "bad", "version": "0.1.0" },
		"questions": [{ "type": "mcq", "q": "?", "choices": ["a", "b"], "answer": 5 }],
	})
	var bad := PackParser.parse_string(bad_mcq)
	_eq(bad.get("code"), "ERR_MCQ_ANSWER_OUT_OF_RANGE", "out-of-range answer caught")

	var bad_ox := JSON.stringify({
		"meta": { "title": "bad", "version": "0.1.0" },
		"questions": [{ "type": "ox", "q": "?", "answer": "true" }],
	})
	var bad2 := PackParser.parse_string(bad_ox)
	_eq(bad2.get("code"), "ERR_OX_ANSWER_NOT_BOOL", "string \"true\" rejected as ox answer")

	var unknown := JSON.stringify({
		"meta": { "title": "bad", "version": "0.1.0" },
		"questions": [{ "type": "typing", "q": "?" }],
	})
	var bad3 := PackParser.parse_string(unknown)
	_eq(bad3.get("code"), "ERR_UNKNOWN_TYPE", "typing type rejected")

	# Real sample (JSON)
	var sample := PackParser.parse_file("res://data/quizzes/clickhouse-basics.json")
	_truthy(sample.get("ok") == true, "real clickhouse-basics.json parses")

	_test_yaml_parser()


# -----------------------------------------------------------------------------
# YAML parser (subset)
# -----------------------------------------------------------------------------
func _test_yaml_parser() -> void:
	_section("YAMLPackParser")
	var simple := """
meta:
  title: Tiny
  version: 0.1.0
  default_time: 25
  tags: [a, b]

questions:
  - type: mcq
    q: 'What is 1+1?'
    choices:
      - '1'
      - '2'
      - '3'
    answer: 1
    explanation: |
      basic arithmetic
      newline preserved
    tags: [math]
  - type: ox
    q: 'Earth is round.'
    answer: true
"""
	var result := PackParser.parse_yaml_string(simple)
	_truthy(result.get("ok") == true,
		"inline yaml parses: %s" % str(result))
	if result.get("ok"):
		var pack: Dictionary = result["pack"]
		_eq(pack["meta"]["title"], "Tiny", "yaml meta.title")
		_eq(pack["meta"]["tags"], ["a", "b"], "yaml inline list")
		_eq(pack["questions"].size(), 2, "yaml two questions")
		_eq(pack["questions"][0]["type"], "mcq", "yaml first type=mcq")
		_eq(pack["questions"][0]["answer"], 1, "yaml first answer=1")
		_eq(pack["questions"][0]["choices"], ["1", "2", "3"], "yaml choices preserved as strings")
		_truthy(pack["questions"][0]["explanation"].contains("newline preserved"),
			"yaml literal block keeps body")
		_eq(pack["questions"][1]["answer"], true, "yaml ox boolean")

	# Real-world workbook output: clickhouse mergetree basics
	var real := PackParser.parse_file("res://data/quizzes/clickhouse-mergetree-basics.yml")
	_truthy(real.get("ok") == true,
		"clickhouse-mergetree-basics.yml parses: %s" % str(real))
	if real.get("ok"):
		var p: Dictionary = real["pack"]
		_truthy((p["questions"] as Array).size() > 5, "real yaml has many questions")
		_truthy(p["questions"][0].has("explanation"), "real yaml preserves explanation")

	var otel := PackParser.parse_file("res://data/quizzes/otel-collector-architecture.yml")
	_truthy(otel.get("ok") == true,
		"otel-collector-architecture.yml parses: %s" % str(otel))

	# YAML schema errors
	var bad_yaml := PackParser.parse_yaml_string("meta:\n  title: x\nquestions:\n  - type: typing\n    q: 'nope'\n")
	_eq(bad_yaml.get("code"), "ERR_UNKNOWN_TYPE",
		"yaml validates schema after parse")

	# Multi-line plain scalar — workbook sometimes splits a long q across lines
	# with a deeper-indented continuation. Fold it into one value.
	var folded_yaml := """
meta:
  title: Fold
  version: 0.1.0

questions:
  - type: mcq
    q: First line

      `code on the second paragraph`
    choices:
      - a
      - b
    answer: 0
    explanation: ok
"""
	var folded_result := PackParser.parse_yaml_string(folded_yaml)
	_truthy(folded_result.get("ok") == true,
		"folded plain scalar parses: %s" % str(folded_result))
	if folded_result.get("ok"):
		var q_text: String = folded_result["pack"]["questions"][0]["q"]
		_truthy(q_text.contains("First line"), "fold keeps head text")
		_truthy(q_text.contains("`code on the second paragraph`"), "fold absorbs deeper continuation")


# -----------------------------------------------------------------------------
# Economy
# -----------------------------------------------------------------------------
func _test_economy() -> void:
	_section("Economy")
	_eq(Economy.max_buyable_sword_level(4), 0, "Lv4 → 검 구매 잠금")
	_eq(Economy.max_buyable_sword_level(5), 5, "Lv5 → 최대 +5 구매")
	_eq(Economy.max_buyable_sword_level(10), 9, "Lv10 → 최대 +9 구매")
	_eq(Economy.max_buyable_sword_level(20), 12, "Lv20 → 최대 +12 구매")
	_eq(Economy.consumable_shop_unlocked(4), false, "Lv4 소비상점 잠금")
	_eq(Economy.consumable_shop_unlocked(5), true, "Lv5 소비상점 해금")
	_eq(Economy.xp_boost_unlocked(9), false, "Lv9 부스터 잠금")
	_eq(Economy.xp_boost_unlocked(10), true, "Lv10 부스터 해금")


# -----------------------------------------------------------------------------
# Achievements
# -----------------------------------------------------------------------------
func _test_achievements() -> void:
	_section("Achievements")
	var empty := { "weapon": {}, "achievements": [] }
	_eq(Achievements.check(empty).has("first_enhance"), false, "0시도 → first_enhance 미달")
	var p := {
		"weapon": { "attempts": 3, "highestEver": 10 },
		"totalCorrect": 100, "everDestroyed": true,
		"sessions": [ { "bestCombo": 21 } ], "achievements": [],
	}
	var got := Achievements.check(p)
	_eq(got.has("first_enhance"), true, "3시도 → first_enhance")
	_eq(got.has("reach_5"), true, "highest10 → reach_5")
	_eq(got.has("reach_10"), true, "highest10 → reach_10")
	_eq(got.has("reach_15"), false, "highest10 → reach_15 미달")
	_eq(got.has("correct_100"), true, "100정답 → correct_100")
	_eq(got.has("combo_20"), true, "콤보21 → combo_20")
	_eq(got.has("first_destroy"), true, "파괴경험 → first_destroy")
	p["achievements"] = ["first_enhance"]
	_eq(Achievements.check(p).has("first_enhance"), false, "보유분은 제외")
	_eq(Achievements.title_for("reach_10"), "미스릴 장인", "칭호 매핑")


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _section(name: String) -> void:
	print("\n[%s]" % name)


func _eq(actual, expected, label: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_pass(label)
	else:
		_fail(label, "expected %s, got %s" % [str(expected), str(actual)])


func _truthy(condition: bool, label: String) -> void:
	if condition:
		_pass(label)
	else:
		_fail(label, "expected truthy")


func _pass(label: String) -> void:
	_passes += 1
	print("  ✓ %s" % label)


func _fail(label: String, reason: String) -> void:
	_failures += 1
	push_error("  ✗ %s — %s" % [label, reason])
	print("  ✗ %s — %s" % [label, reason])
