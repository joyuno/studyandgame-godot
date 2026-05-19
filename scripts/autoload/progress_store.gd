# Player progress — autoloaded, persists to user://progress.json (atomic write).
# Ported from src/main/services/progressStore.ts. Same fields + same atomic
# rename strategy so a future migration tool could move saves between versions.
#
# Signal-based for UI reactivity (replaces Zustand subscribe in the Electron port).

extends Node

signal progress_changed
signal weapon_changed(level: int)
signal materials_changed(count: int)
signal theme_changed(theme_id: String)
signal quiet_mode_changed(enabled: bool)
signal enhance_result(success: bool, before: int, after: int, materials_left: int)
signal material_drop(amount: int)

const SCHEMA_VERSION: int = 1
const MAX_SESSION_HISTORY: int = 100
const SAVE_PATH: String = "user://progress.json"
const SAVE_PATH_TMP: String = "user://progress.json.tmp"

var progress: Dictionary = _default_progress()


func _ready() -> void:
	_load_from_disk()


# -----------------------------------------------------------------------------
# Read-only accessors (so UI doesn't depend on raw dict shape)
# -----------------------------------------------------------------------------
func get_xp() -> int:
	return int(progress.get("totalXP", 0))


func get_level() -> int:
	return Leveling.level_from_xp(get_xp())


func get_weapon_level() -> int:
	var w = progress.get("weapon", null)
	if typeof(w) != TYPE_DICTIONARY:
		return 0
	return int(w.get("level", 0))


func get_materials() -> int:
	return int(progress.get("materials", 0))


func get_selected_theme_id() -> String:
	return progress.get("selectedThemeId", "programmer")


func is_quiet_mode() -> bool:
	return bool(progress.get("quietMode", false))


func get_wrong_note() -> Array:
	var w = progress.get("wrongNote", [])
	return w if typeof(w) == TYPE_ARRAY else []


# -----------------------------------------------------------------------------
# Mutations
# -----------------------------------------------------------------------------
func add_xp(amount: int) -> void:
	var new_total: int = max(0, get_xp() + amount)
	progress["totalXP"] = new_total
	progress["level"] = Leveling.level_from_xp(new_total)
	_persist()
	progress_changed.emit()


func record_session(record: Dictionary) -> void:
	var sessions: Array = progress.get("sessions", [])
	sessions.append(record)
	if sessions.size() > MAX_SESSION_HISTORY:
		sessions = sessions.slice(sessions.size() - MAX_SESSION_HISTORY)
	progress["sessions"] = sessions
	progress["totalCorrect"] = int(progress.get("totalCorrect", 0)) + int(record.get("correct", 0))
	_persist()
	progress_changed.emit()


func add_wrong_entry(entry: Dictionary) -> void:
	var wrong: Array = progress.get("wrongNote", [])
	# Dedupe by question_hash
	var qh: String = entry.get("questionHash", "")
	for i in wrong.size():
		if wrong[i].get("questionHash", "") == qh:
			wrong[i]["timesWrong"] = int(wrong[i].get("timesWrong", 1)) + 1
			wrong[i]["lastWrongAt"] = entry.get("lastWrongAt", "")
			wrong[i]["userAnswer"] = entry.get("userAnswer", null)
			progress["wrongNote"] = wrong
			_persist()
			progress_changed.emit()
			return
	wrong.append(entry)
	progress["wrongNote"] = wrong
	_persist()
	progress_changed.emit()


func remove_wrong_entry(question_hash: String) -> void:
	var wrong: Array = progress.get("wrongNote", [])
	var filtered: Array = []
	for e in wrong:
		if e.get("questionHash", "") != question_hash:
			filtered.append(e)
	progress["wrongNote"] = filtered
	_persist()
	progress_changed.emit()


func update_wrong_entry_srs(question_hash: String, review_level: int, next_review_at: String) -> void:
	var wrong: Array = progress.get("wrongNote", [])
	for i in wrong.size():
		if wrong[i].get("questionHash", "") == question_hash:
			wrong[i]["reviewLevel"] = review_level
			wrong[i]["nextReviewAt"] = next_review_at
			progress["wrongNote"] = wrong
			_persist()
			progress_changed.emit()
			return


# Attempt weapon enhancement. Returns the same dict shape the UI consumes.
func try_enhance() -> Dictionary:
	if get_materials() < Weapon.ENHANCE_MATERIAL_COST:
		return { "ok": false, "reason": "not_enough_materials" }

	var before := get_weapon_level()
	if before >= Weapon.ENHANCE_MAX_LEVEL:
		return { "ok": false, "reason": "max_level" }

	var rate := Weapon.success_rate_at(before)
	var roll := randf()
	var success := roll < rate
	var after := Weapon.next_level_after_attempt(before, success)

	var w: Dictionary = progress.get("weapon", { "level": 0, "attempts": 0, "failures": 0, "highestEver": 0 })
	w["level"] = after
	w["attempts"] = int(w.get("attempts", 0)) + 1
	if not success:
		w["failures"] = int(w.get("failures", 0)) + 1
	w["highestEver"] = max(int(w.get("highestEver", 0)), after)
	progress["weapon"] = w
	progress["materials"] = get_materials() - Weapon.ENHANCE_MATERIAL_COST

	_persist()
	progress_changed.emit()
	weapon_changed.emit(after)
	materials_changed.emit(get_materials())
	enhance_result.emit(success, before, after, get_materials())
	return { "ok": true, "success": success, "before": before, "after": after }


# Roll for material drops at the end of a session.
# Returns the amount dropped (0+).
func roll_material_drop(boss_defeats: int) -> int:
	var dropped := 0
	if randf() < Weapon.MATERIAL_DROP_CHANCE:
		dropped += 1
	for _i in boss_defeats:
		if randf() < Weapon.BOSS_KILL_MATERIAL_CHANCE:
			dropped += 1
	if dropped > 0:
		progress["materials"] = get_materials() + dropped
		_persist()
		progress_changed.emit()
		materials_changed.emit(get_materials())
		material_drop.emit(dropped)
	return dropped


func set_theme(theme_id: String) -> void:
	if theme_id == get_selected_theme_id():
		return
	progress["selectedThemeId"] = theme_id
	_persist()
	progress_changed.emit()
	theme_changed.emit(theme_id)


func set_quiet_mode(enabled: bool) -> void:
	progress["quietMode"] = enabled
	_persist()
	progress_changed.emit()
	quiet_mode_changed.emit(enabled)


# -----------------------------------------------------------------------------
# Persistence — atomic write (tmp + rename)
# -----------------------------------------------------------------------------
func _persist() -> void:
	var f := FileAccess.open(SAVE_PATH_TMP, FileAccess.WRITE)
	if f == null:
		push_error("ProgressStore: failed to open %s for write (err=%d)" % [SAVE_PATH_TMP, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(progress, "  "))
	f.close()

	# Atomic-ish rename. Godot's DirAccess.rename overwrites on most platforms.
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("ProgressStore: cannot open user:// for rename")
		return
	if FileAccess.file_exists(SAVE_PATH):
		dir.remove(SAVE_PATH)
	var rename_err := dir.rename(SAVE_PATH_TMP, SAVE_PATH)
	if rename_err != OK:
		push_error("ProgressStore: rename failed (err=%d)" % rename_err)


func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var raw := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ProgressStore: %s exists but is not a JSON object — keeping defaults" % SAVE_PATH)
		return
	# Shallow merge with defaults so new fields land safely on old saves.
	var merged := _default_progress()
	for k in (parsed as Dictionary).keys():
		merged[k] = parsed[k]
	# Migration: legacy theme IDs that no longer exist → map back to jobs.
	# v0.2 briefly used Kenney alien colors (beige/blue/green/pink/yellow) as
	# a placeholder while we replaced the original RPGMaker-base sheets.
	# v0.3 restores the job-based identity using AI-generated sprites.
	var legacy_theme_map := {
		# Kenney alien colors → closest job
		"beige": "programmer",
		"blue": "wizard",
		"green": "ninja",
		"pink": "chef",
		"yellow": "explorer",
		# Old themes that mapped to bad sheets
		"robot": "programmer",
		"animal": "explorer",
	}
	var saved_theme: String = merged.get("selectedThemeId", "")
	if legacy_theme_map.has(saved_theme):
		merged["selectedThemeId"] = legacy_theme_map[saved_theme]
	progress = merged


func _default_progress() -> Dictionary:
	return {
		"schemaVersion": SCHEMA_VERSION,
		"totalXP": 0,
		"level": 1,
		"sessions": [],
		"wrongNote": [],
		"totalBossDefeats": 0,
		"totalCorrect": 0,
		"bestCombo": 0,
		"selectedThemeId": "programmer",
		"quietMode": false,
		"weapon": { "level": 0, "attempts": 0, "failures": 0, "highestEver": 0 },
		"materials": 0,
	}
