# Active quiz pack — autoloaded. Holds the current pack + cursor + combo state.
# Replaces useQuizStore from the Electron port.
#
# v0.5 — 학습 UI 복원 + 검강화 신규 메카닉 (Riff 1, 2026-05-21):
#   * question_started_at_unix / time_remaining_for_question() → 문항 타이머
#   * session_wrong_count → 검 내구도 바
#   * combo 보너스: 5콤보 도달마다 +1 강화권 추가
#   * 빠른 정답 보너스: default_time의 1/3 이내 정답 시 +1 강화권 추가
#   * sword durability: 세션 누적 오답이 SWORD_DURABILITY_THRESHOLD 도달 시
#     검 강제 강등 (-1) — ProgressStore.demote_sword() 호출

extends Node

signal pack_loaded(meta: Dictionary, total: int)
signal question_changed(index: int, question: Dictionary)
signal feedback(correct: bool, explanation: String, info: Dictionary)
signal session_completed(record: Dictionary)
signal combo_changed(combo: int, on_fire: bool)
signal durability_changed(wrong_count: int, threshold: int)
signal sword_broken  # 강제 강등 직후

const SESSION_PHASES = ["IDLE", "IN_QUESTION", "FEEDBACK", "COMPLETED"]

const COMBO_BONUS_EVERY: int = 5    # 5콤보 = +1 보너스 강화권
const FAST_ANSWER_DIVISOR: float = 3.0  # default_time / 3 이내 정답 = +1 보너스
const SWORD_DURABILITY_THRESHOLD: int = 5  # 세션 누적 오답 5개 = 강제 강등
const DEFAULT_QUESTION_TIME: float = 25.0

var pack: Dictionary = {}
var question_index: int = 0
var correct_count: int = 0
var combo_count: int = 0
var best_combo_this_session: int = 0
var session_wrong_count: int = 0
var session_started_at_unix: float = 0.0
var question_started_at_unix: float = 0.0
var phase: String = "IDLE"

# Review mode — when true, `pack.questions` came from ProgressStore.wrong_note
# snapshots, and submit_answer additionally pipes the result through SRS to
# update / remove the wrong-note entry. Sword durability + wrong-note re-
# registration are suppressed in review mode to avoid double-counting.
var is_review_mode: bool = false
var review_hashes: Array[String] = []
var review_levels: Array[int] = []


func load_pack_from_path(path: String) -> Dictionary:
	var result := PackParser.parse_file(path)
	if not result.get("ok", false):
		return result
	is_review_mode = false
	review_hashes.clear()
	review_levels.clear()
	pack = result["pack"]
	_reset_session()
	pack_loaded.emit(pack.get("meta", {}), questions_count())
	if questions_count() > 0:
		phase = "IN_QUESTION"
		question_started_at_unix = Time.get_unix_time_from_system()
		question_changed.emit(0, current_question())
	return { "ok": true, "title": pack.get("meta", {}).get("title", "") }


# Build a session out of wrong-note entries. Each entry's question snapshot
# becomes a question, and the entry hash + current SRS level are captured
# in parallel arrays so submit_answer can grade them automatically.
# Returns false if there are no usable entries.
func load_review_session(entries: Array) -> bool:
	var questions: Array = []
	var hashes: Array[String] = []
	var levels: Array[int] = []
	for e in entries:
		var snap = e.get("questionSnapshot", null)
		if typeof(snap) != TYPE_DICTIONARY or String(snap.get("q", "")).is_empty():
			continue
		questions.append(snap)
		hashes.append(String(e.get("questionHash", "")))
		levels.append(int(e.get("reviewLevel", 0)))
	if questions.is_empty():
		return false
	is_review_mode = true
	review_hashes = hashes
	review_levels = levels
	pack = {
		"meta": {
			"title": "📚 오답 복습 (%d문항)" % questions.size(),
			"version": "review",
			"default_time": 30,
		},
		"questions": questions,
	}
	_reset_session()
	pack_loaded.emit(pack["meta"], questions.size())
	phase = "IN_QUESTION"
	question_started_at_unix = Time.get_unix_time_from_system()
	question_changed.emit(0, current_question())
	return true


func questions_count() -> int:
	var q = pack.get("questions", [])
	return (q as Array).size() if typeof(q) == TYPE_ARRAY else 0


func current_question() -> Dictionary:
	var qs = pack.get("questions", [])
	if typeof(qs) != TYPE_ARRAY or question_index >= (qs as Array).size():
		return {}
	return qs[question_index]


# Seconds the player has left for the current question. Uses q.time if set,
# else pack.meta.default_time, else DEFAULT_QUESTION_TIME. Returns 0 once
# elapsed — UI decides whether to auto-submit or just hide the bar.
func time_remaining_for_question() -> float:
	if phase != "IN_QUESTION":
		return 0.0
	var limit := question_time_limit()
	var elapsed := Time.get_unix_time_from_system() - question_started_at_unix
	return max(0.0, limit - elapsed)


func question_time_limit() -> float:
	var q := current_question()
	if q.has("time"):
		return float(q["time"])
	var meta = pack.get("meta", {})
	return float(meta.get("default_time", DEFAULT_QUESTION_TIME))


func session_elapsed_seconds() -> float:
	if session_started_at_unix <= 0.0:
		return 0.0
	return Time.get_unix_time_from_system() - session_started_at_unix


func submit_answer(answer) -> void:
	var q := current_question()
	if q.is_empty():
		return
	var elapsed_for_q := Time.get_unix_time_from_system() - question_started_at_unix
	var is_correct := _check_answer(q, answer)
	var info := {
		"correct": is_correct,
		"elapsed": elapsed_for_q,
		"bonuses": [],  # list of strings describing extra tickets awarded
	}
	if is_correct:
		correct_count += 1
		combo_count += 1
		if combo_count > best_combo_this_session:
			best_combo_this_session = combo_count
		var multiplier := Leveling.combo_multiplier(combo_count)
		var xp_award := int(round(Leveling.XP_PER_CORRECT * multiplier))
		ProgressStore.add_xp(xp_award)
		# Base reward — 1 강화권 per correct answer
		ProgressStore.add_enhance_ticket(1)
		# Bonus 1: combo milestone (5콤보마다 +1 보너스)
		if combo_count > 0 and combo_count % COMBO_BONUS_EVERY == 0:
			ProgressStore.add_enhance_ticket(1)
			info["bonuses"].append("🔥 %d콤보 보너스 +1" % combo_count)
		# Bonus 2: fast answer (default_time / 3 이내)
		var fast_threshold := question_time_limit() / FAST_ANSWER_DIVISOR
		if elapsed_for_q <= fast_threshold and elapsed_for_q > 0.0:
			ProgressStore.add_enhance_ticket(1)
			info["bonuses"].append("⚡ 빠른 정답 +1 (%.1fs)" % elapsed_for_q)
		combo_changed.emit(combo_count, Leveling.is_on_fire(combo_count))
	else:
		combo_count = 0
		combo_changed.emit(0, false)
		# Review mode: skip both wrong-note re-registration (entry already
		# exists) and sword durability (safer review). The SRS update below
		# handles tracking instead.
		if not is_review_mode:
			_register_wrong(q, answer)
			# +0 base sword is protected — no durability tracking at floor.
			# Otherwise the bar would fill up with no consequence (since
			# demote_sword() can't go below 0), which is confusing UX.
			if ProgressStore.get_weapon_level() > 0:
				session_wrong_count += 1
				durability_changed.emit(session_wrong_count, SWORD_DURABILITY_THRESHOLD)
				if session_wrong_count >= SWORD_DURABILITY_THRESHOLD:
					var demoted := ProgressStore.demote_sword()
					if demoted:
						session_wrong_count = 0
						sword_broken.emit()
						durability_changed.emit(0, SWORD_DURABILITY_THRESHOLD)
						info["bonuses"].append("💥 검 내구도 0 — 강제 강등 -1")
	# Review mode: pipe answer through SRS to update / remove the wrong-note
	# entry. Graduated entries (SRS returns empty) get pulled from the list.
	if is_review_mode and question_index < review_hashes.size():
		var hkey := review_hashes[question_index]
		var prev_level := review_levels[question_index]
		var next_state := SRS.grade_review(prev_level, is_correct)
		if next_state.is_empty():
			ProgressStore.remove_wrong_entry(hkey)
			info["bonuses"].append("🎓 졸업 — 오답노트에서 제거")
		else:
			ProgressStore.update_wrong_entry_srs(
				hkey,
				int(next_state.get("review_level", prev_level)),
				String(next_state.get("next_review_at", "")),
			)
	feedback.emit(is_correct, q.get("explanation", ""), info)
	phase = "FEEDBACK"


func advance() -> void:
	question_index += 1
	if question_index >= questions_count():
		_complete_session()
		return
	phase = "IN_QUESTION"
	question_started_at_unix = Time.get_unix_time_from_system()
	question_changed.emit(question_index, current_question())


# Reset the in-memory cursor — call when re-entering a pack fresh.
func _reset_session() -> void:
	question_index = 0
	correct_count = 0
	combo_count = 0
	best_combo_this_session = 0
	session_wrong_count = 0
	session_started_at_unix = Time.get_unix_time_from_system()
	question_started_at_unix = 0.0
	phase = "IDLE"


func _check_answer(q: Dictionary, answer) -> bool:
	match q.get("type", ""):
		"mcq":
			return int(answer) == int(q.get("answer", -1))
		"ox":
			return bool(answer) == bool(q.get("answer", false))
	return false


func _register_wrong(q: Dictionary, user_answer) -> void:
	var entry := {
		"packTitle": pack.get("meta", {}).get("title", ""),
		"questionHash": _hash_question(q),
		"questionSnapshot": q,
		"userAnswer": user_answer,
		"timesWrong": 1,
		"lastWrongAt": Time.get_datetime_string_from_system(true),
		"reviewLevel": 0,
		"nextReviewAt": SRS.initial_next_review_at(),
	}
	ProgressStore.add_wrong_entry(entry)


func _complete_session() -> void:
	phase = "COMPLETED"
	var record := {
		"startedAt": Time.get_datetime_string_from_unix_time(int(session_started_at_unix), true),
		"packTitle": pack.get("meta", {}).get("title", ""),
		"packVersion": pack.get("meta", {}).get("version", "0.0.0"),
		"total": questions_count(),
		"correct": correct_count,
		"bestCombo": best_combo_this_session,
		"sessionWrongs": session_wrong_count,
		"durationMs": int((Time.get_unix_time_from_system() - session_started_at_unix) * 1000),
	}
	ProgressStore.record_session(record)
	session_completed.emit(record)


# Stable hash of question text + type — same shape as the Electron version
# so wrong-note SRS state migrates across engines if needed.
func _hash_question(q: Dictionary) -> String:
	var key := "%s::%s" % [q.get("type", ""), q.get("q", "")]
	return str(key.hash())
