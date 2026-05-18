# Active quiz pack — autoloaded. Holds the current pack + cursor + combo state.
# Replaces useQuizStore from the Electron port.

extends Node

signal pack_loaded(meta: Dictionary, total: int)
signal question_changed(index: int, question: Dictionary)
signal feedback(correct: bool, explanation: String)
signal session_completed(record: Dictionary)
signal boss_defeated

const SESSION_PHASES = ["IDLE", "IN_QUESTION", "FEEDBACK", "COMPLETED"]

var pack: Dictionary = {}
var question_index: int = 0
var correct_count: int = 0
var combo_count: int = 0
var best_combo_this_session: int = 0
var boss_kill_count: int = 0
var session_started_at_unix: float = 0.0
var phase: String = "IDLE"


func load_pack_from_path(path: String) -> Dictionary:
	var result := PackParser.parse_file(path)
	if not result.get("ok", false):
		return result
	pack = result["pack"]
	_reset_session()
	pack_loaded.emit(pack.get("meta", {}), questions_count())
	if questions_count() > 0:
		phase = "IN_QUESTION"
		question_changed.emit(0, current_question())
	return { "ok": true, "title": pack.get("meta", {}).get("title", "") }


func questions_count() -> int:
	var q = pack.get("questions", [])
	return (q as Array).size() if typeof(q) == TYPE_ARRAY else 0


func current_question() -> Dictionary:
	var qs = pack.get("questions", [])
	if typeof(qs) != TYPE_ARRAY or question_index >= (qs as Array).size():
		return {}
	return qs[question_index]


func submit_answer(answer) -> void:
	var q := current_question()
	if q.is_empty():
		return
	var is_correct := _check_answer(q, answer)
	if is_correct:
		correct_count += 1
		combo_count += 1
		if combo_count > best_combo_this_session:
			best_combo_this_session = combo_count
		var multiplier := Leveling.combo_multiplier(combo_count)
		var xp_award := int(round(Leveling.XP_PER_CORRECT * multiplier))
		ProgressStore.add_xp(xp_award)
	else:
		combo_count = 0
		_register_wrong(q, answer)
	feedback.emit(is_correct, q.get("explanation", ""))
	phase = "FEEDBACK"


func advance() -> void:
	question_index += 1
	if question_index >= questions_count():
		_complete_session()
		return
	phase = "IN_QUESTION"
	question_changed.emit(question_index, current_question())


func register_boss_defeat() -> void:
	boss_kill_count += 1
	boss_defeated.emit()


# Reset the in-memory cursor — call when re-entering a pack fresh.
func _reset_session() -> void:
	question_index = 0
	correct_count = 0
	combo_count = 0
	best_combo_this_session = 0
	boss_kill_count = 0
	session_started_at_unix = Time.get_unix_time_from_system()
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
		"durationMs": int((Time.get_unix_time_from_system() - session_started_at_unix) * 1000),
	}
	ProgressStore.record_session(record)
	ProgressStore.roll_material_drop(boss_kill_count)
	session_completed.emit(record)


# Stable hash of question text + type — same shape as the Electron version
# so wrong-note SRS state migrates across engines if needed.
func _hash_question(q: Dictionary) -> String:
	var key := "%s::%s" % [q.get("type", ""), q.get("q", "")]
	return str(key.hash())
