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
	print("--- %d passed, %d failed ---" % [_passes, _failures])
	quit(0 if _failures == 0 else 1)


# -----------------------------------------------------------------------------
# Weapon
# -----------------------------------------------------------------------------
func _test_weapon() -> void:
	_section("Weapon")
	_eq(Weapon.ENHANCE_MAX_LEVEL, 15, "max level = 15")
	_eq(Weapon.success_rate_at(0), 1.0, "+0 → 100%")
	_eq(Weapon.success_rate_at(5), 0.4, "+5 → 40%")
	_eq(Weapon.success_rate_at(15), 0.0, "+15 → cap (0)")
	_eq(Weapon.success_rate_at(99), 0.0, "way over cap → 0")

	_eq(Weapon.next_level_after_attempt(0, true), 1, "success at +0 → +1")
	_eq(Weapon.next_level_after_attempt(7, true), 8, "success at +7 → +8")
	_eq(Weapon.next_level_after_attempt(15, true), 15, "success at cap stays at cap")

	for lv in range(0, 6):
		_eq(Weapon.next_level_after_attempt(lv, false), lv,
			"failure protected at +%d" % lv)

	_eq(Weapon.next_level_after_attempt(6, false), 4, "failure at +6 → -2")
	_eq(Weapon.next_level_after_attempt(10, false), 8, "failure at +10 → -2")
	_eq(Weapon.next_level_after_attempt(15, false), 13, "failure at +15 → -2")
	_eq(Weapon.next_level_after_attempt(1, false), 1, "failure floor cannot go below current in protected zone")

	_eq(Weapon.weapon_damage_multiplier(0), 1.0, "+0 → ×1.0")
	_eq(Weapon.weapon_damage_multiplier(5), 1.75, "+5 → ×1.75")
	_eq(Weapon.weapon_damage_multiplier(10), 2.5, "+10 → ×2.5")
	_eq(Weapon.weapon_damage_multiplier(15), 3.25, "+15 → ×3.25")
	_eq(Weapon.weapon_damage_multiplier(-3), 1.0, "negative → ×1.0")

	_eq(Weapon.format_percent(1.0), "100%", "100%")
	_eq(Weapon.format_percent(0.5), "50%", "50%")
	_eq(Weapon.format_percent(0.005), "1%", "rounds 0.5% up to 1%")
	_eq(Weapon.format_percent(0.0), "0%", "0%")


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
