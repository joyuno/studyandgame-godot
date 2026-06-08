# Player progress — autoloaded, persists to user://progress.json (atomic write).
# Ported from src/main/services/progressStore.ts. Same fields + same atomic
# rename strategy so a future migration tool could move saves between versions.
#
# Signal-based for UI reactivity (replaces Zustand subscribe in the Electron port).
#
# v0.4 — 검강화하기 mode pivot: `materials` retained on disk as the underlying
# storage for `enhance_tickets`. Added `gold` + `protectionScrolls`. Idle-RPG
# theme + boss material drops are retired; tickets come only from correct
# answers (PackStore.submit_answer).

extends Node

signal progress_changed
signal weapon_changed(level: int)
signal materials_changed(count: int)  # alias for tickets_changed — kept for compat
signal tickets_changed(count: int)
signal gold_changed(amount: int)
signal scrolls_changed(count: int)
signal shards_changed(count: int)
signal difficulty_changed(value: String)
signal theme_changed(theme_id: String)  # legacy; sword mode has only one progression line
signal quiet_mode_changed(enabled: bool)
signal timer_enabled_changed(enabled: bool)
signal font_size_scale_changed(scale: int)
# result ∈ {"success", "stay", "stay_protected", "destroy", "max"}.
# shards_gained is non-zero only when result == "destroy".
signal enhance_result(result: String, before: int, after: int, materials_left: int, shards_gained: int)
signal material_drop(amount: int)  # legacy; idle-RPG boss drops are off in sword mode

const SCHEMA_VERSION: int = 2
const MAX_SESSION_HISTORY: int = 100
const SAVE_PATH: String = "user://progress.json"
const SAVE_PATH_TMP: String = "user://progress.json.tmp"

# Sword mode economy constants.
const SCROLL_COST_GOLD: int = 500          # single-scroll buy
const NEW_SWORD_COST_GOLD: int = 200       # legacy "buy a fresh +0" — kept for save compat
const STARTER_GOLD: int = 1000             # one-time grant on a new save

# Scroll bundle pricing — bulk discounts grow with quantity so a player who
# has settled into +9~+12 grinding doesn't have to click 30 single buys.
#   single   : 1 × 500  =   500G    (baseline)
#   pack-3   :          = 1,200G  (-20% vs 1,500)
#   pack-10  :          = 3,500G  (-30% vs 5,000)
const SCROLL_BUNDLES: Dictionary = {
	1:  500,
	3:  1200,
	10: 3500,
}

# Shard → pre-enhanced sword exchange rates. The level you buy ↦ shards spent.
# Sized against Weapon.shard_reward_for_destroy(level)=level²×2 so a careless
# +12 destroy pays for roughly one +9 (200+800=1000 vs 288 reward at +12).
const SHARD_EXCHANGE: Dictionary = {
	3: 50,
	6: 200,
	9: 800,
	12: 2000,
}

# Gold-only pre-enhanced sword shop. Multipliers vs SwordStore.sell_price(N):
#   +3   : 2.1× sell  — entry tier, recoverable in a few sells
#   +6   : 2.2× sell  — mid-tier skip
#   +9   : 3.7× sell  — high-risk shortcut
#   +12  : 6.9× sell  — last-resort "buy your way past the wall" insurance
# Always more expensive than direct enhancement on a pure gold basis, so the
# shop never strictly dominates the grind — it trades gold for *certainty*.
const SWORD_GOLD_PRICE: Dictionary = {
	3:  2000,
	6:  8000,
	9:  30000,
	12: 100000,
}

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


# Tickets — the "강화권" earned per correct answer. Stored under the legacy
# `materials` key so old save files migrate transparently.
func get_enhance_tickets() -> int:
	return int(progress.get("materials", 0))


func get_materials() -> int:  # legacy alias
	return get_enhance_tickets()


func get_gold() -> int:
	return int(progress.get("gold", 0))


func get_protection_scrolls() -> int:
	return int(progress.get("protectionScrolls", 0))


func get_shards() -> int:
	return int(progress.get("shards", 0))


# "easy" (default) or "hard". Surfaced from settings UI; consumed by Weapon
# rate functions so the difficulty toggle is one-line plumbing.
func get_difficulty() -> String:
	var d: String = String(progress.get("difficulty", "easy"))
	return d if d == "easy" or d == "hard" else "easy"


func set_difficulty(value: String) -> void:
	var clean: String = value if value == "easy" or value == "hard" else "easy"
	if clean == get_difficulty():
		return
	progress["difficulty"] = clean
	_persist()
	progress_changed.emit()
	difficulty_changed.emit(clean)


func get_selected_theme_id() -> String:
	return progress.get("selectedThemeId", "programmer")


func is_quiet_mode() -> bool:
	return bool(progress.get("quietMode", false))


# Settings — added in v0.5 (Riff 1).
func is_timer_enabled() -> bool:
	return bool(progress.get("timerEnabled", true))


# 0 = small, 1 = medium (default), 2 = large
func get_font_size_scale() -> int:
	return int(progress.get("fontSizeScale", 1))


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


# Reward for a correct quiz answer in sword mode — one ticket per correct.
func add_enhance_ticket(n: int = 1) -> void:
	progress["materials"] = get_enhance_tickets() + max(0, n)
	_persist()
	progress_changed.emit()
	tickets_changed.emit(get_enhance_tickets())
	materials_changed.emit(get_enhance_tickets())


func add_gold(amount: int) -> void:
	progress["gold"] = max(0, get_gold() + amount)
	_persist()
	progress_changed.emit()
	gold_changed.emit(get_gold())


func spend_gold(amount: int) -> bool:
	if get_gold() < amount:
		return false
	progress["gold"] = get_gold() - amount
	_persist()
	progress_changed.emit()
	gold_changed.emit(get_gold())
	return true


# Sell the current sword. Returns the gold awarded and resets the sword to +0.
func sell_current_sword() -> Dictionary:
	var lv := get_weapon_level()
	var price := SwordStore.sell_price(lv)
	add_gold(price)
	_reset_sword()
	return { "ok": true, "price": price, "old_level": lv }


# Buy a fresh +0 sword. Only meaningful if the player explicitly nuked the
# current sword (sell+reset). The store offers this when level==0 so it's a
# no-op; kept for symmetry / future "shop" expansion.
func buy_new_sword() -> Dictionary:
	if not spend_gold(NEW_SWORD_COST_GOLD):
		return { "ok": false, "reason": "not_enough_gold" }
	_reset_sword()
	return { "ok": true }


func buy_protection_scroll() -> Dictionary:
	return buy_scroll_bundle(1)


# Generalised scroll buy — `qty` must match a SCROLL_BUNDLES key (1/3/10) or
# the call is rejected. The bundle price is paid once in gold and the wallet
# receives `qty` scrolls.
func buy_scroll_bundle(qty: int) -> Dictionary:
	if not SCROLL_BUNDLES.has(qty):
		return { "ok": false, "reason": "invalid_bundle" }
	var cost: int = int(SCROLL_BUNDLES[qty])
	if not spend_gold(cost):
		return { "ok": false, "reason": "not_enough_gold", "cost": cost }
	progress["protectionScrolls"] = get_protection_scrolls() + qty
	_persist()
	progress_changed.emit()
	scrolls_changed.emit(get_protection_scrolls())
	return {
		"ok": true,
		"scrolls": get_protection_scrolls(),
		"qty": qty,
		"cost": cost,
	}


# Exchange shards for a pre-enhanced sword. Replaces the current sword at the
# bought tier (the player's existing sword is wiped — the same shape as
# sell_current_sword() but paid in shards instead of awarding gold).
func exchange_shards_for_sword(target_level: int) -> Dictionary:
	if not SHARD_EXCHANGE.has(target_level):
		return { "ok": false, "reason": "invalid_tier" }
	var cost: int = int(SHARD_EXCHANGE[target_level])
	if get_shards() < cost:
		return { "ok": false, "reason": "not_enough_shards", "cost": cost }
	progress["shards"] = get_shards() - cost
	var w: Dictionary = progress.get("weapon", {})
	var highest: int = int(w.get("highestEver", 0))
	progress["weapon"] = {
		"level": target_level,
		"attempts": 0,
		"failures": 0,
		"highestEver": maxi(highest, target_level),
	}
	_persist()
	progress_changed.emit()
	shards_changed.emit(get_shards())
	weapon_changed.emit(target_level)
	return { "ok": true, "level": target_level, "shards_spent": cost }


# Same shape as exchange_shards_for_sword but paid in gold from the player's
# wallet. Always more expensive than the shard path — see SWORD_GOLD_PRICE.
func buy_sword_with_gold(target_level: int) -> Dictionary:
	if not SWORD_GOLD_PRICE.has(target_level):
		return { "ok": false, "reason": "invalid_tier" }
	var cost: int = int(SWORD_GOLD_PRICE[target_level])
	if not spend_gold(cost):
		return { "ok": false, "reason": "not_enough_gold", "cost": cost }
	var w: Dictionary = progress.get("weapon", {})
	var highest: int = int(w.get("highestEver", 0))
	progress["weapon"] = {
		"level": target_level,
		"attempts": 0,
		"failures": 0,
		"highestEver": maxi(highest, target_level),
	}
	_persist()
	progress_changed.emit()
	weapon_changed.emit(target_level)
	return { "ok": true, "level": target_level, "gold_spent": cost }


# ─── Quiz session resume — per-pack cursor so an interrupted pack can continue.
# Keyed by the pack's source path. Saved silently (no progress_changed) on each
# advance so leaving home / quitting mid-pack keeps the place; cleared on
# completion. Survives via the same atomic-write _persist().
func get_quiz_session(pack_id: String) -> Dictionary:
	var s = progress.get("quizSessions", {})
	if typeof(s) != TYPE_DICTIONARY:
		return {}
	var e = (s as Dictionary).get(pack_id, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


func save_quiz_session(pack_id: String, data: Dictionary) -> void:
	if pack_id.is_empty():
		return
	var s: Dictionary = progress.get("quizSessions", {})
	if typeof(s) != TYPE_DICTIONARY:
		s = {}
	s[pack_id] = data
	progress["quizSessions"] = s
	_persist()


func clear_quiz_session(pack_id: String) -> void:
	if pack_id.is_empty():
		return
	var s = progress.get("quizSessions", {})
	if typeof(s) != TYPE_DICTIONARY or not (s as Dictionary).has(pack_id):
		return
	(s as Dictionary).erase(pack_id)
	progress["quizSessions"] = s
	_persist()


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


# Attempt weapon enhancement (검강화하기 3-outcome). One ticket per attempt.
# If `use_scroll` is true and the player owns a scroll, a destroy outcome is
# absorbed (the sword stays at its current level instead of resetting to +0).
# The scroll has no effect on a plain "stay" outcome — only on destroys.
func try_enhance(use_scroll: bool = false) -> Dictionary:
	if get_enhance_tickets() < Weapon.ENHANCE_MATERIAL_COST:
		return { "ok": false, "reason": "not_enough_tickets" }

	var before := get_weapon_level()
	if before >= Weapon.ENHANCE_MAX_LEVEL:
		return { "ok": false, "reason": "max_level" }

	var scroll_armed := use_scroll and get_protection_scrolls() > 0
	var outcome := Weapon.try_attempt(before, scroll_armed, -1.0, get_difficulty())
	var result: String = outcome.get("result", "stay")
	var after: int = int(outcome.get("level", before))
	var shards_gained: int = int(outcome.get("shards", 0))

	# A scroll is consumed only when it actually saved the player from a destroy.
	var scroll_consumed: bool = (result == "stay_protected")

	var w: Dictionary = progress.get("weapon", { "level": 0, "attempts": 0, "failures": 0, "highestEver": 0 })
	w["level"] = after
	w["attempts"] = int(w.get("attempts", 0)) + 1
	if result != "success":
		w["failures"] = int(w.get("failures", 0)) + 1
	w["highestEver"] = maxi(int(w.get("highestEver", 0)), after)
	progress["weapon"] = w
	progress["materials"] = get_enhance_tickets() - Weapon.ENHANCE_MATERIAL_COST
	if scroll_consumed:
		progress["protectionScrolls"] = get_protection_scrolls() - 1
	if shards_gained > 0:
		progress["shards"] = get_shards() + shards_gained

	_persist()
	progress_changed.emit()
	weapon_changed.emit(after)
	tickets_changed.emit(get_enhance_tickets())
	materials_changed.emit(get_enhance_tickets())
	if scroll_consumed:
		scrolls_changed.emit(get_protection_scrolls())
	if shards_gained > 0:
		shards_changed.emit(get_shards())
	enhance_result.emit(result, before, after, get_enhance_tickets(), shards_gained)
	return {
		"ok": true,
		"result": result,
		"before": before,
		"after": after,
		"shards_gained": shards_gained,
		"scroll_consumed": scroll_consumed,
	}


# Legacy idle-RPG boss material drop — disabled in sword mode. Kept as a
# no-op so PackStore can still call it without conditionals.
func roll_material_drop(_boss_defeats: int) -> int:
	return 0


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


func set_timer_enabled(enabled: bool) -> void:
	progress["timerEnabled"] = enabled
	_persist()
	progress_changed.emit()
	timer_enabled_changed.emit(enabled)


func set_font_size_scale(scale: int) -> void:
	var clamped: int = clampi(scale, 0, 2)
	progress["fontSizeScale"] = clamped
	_persist()
	progress_changed.emit()
	font_size_scale_changed.emit(clamped)


# Forced sword demotion — called by PackStore when session wrong count
# exceeds the durability threshold. Returns true if a level was lost.
func demote_sword() -> bool:
	var w: Dictionary = progress.get("weapon", { "level": 0, "attempts": 0, "failures": 0, "highestEver": 0 })
	var lv := int(w.get("level", 0))
	if lv <= 0:
		return false
	w["level"] = lv - 1
	progress["weapon"] = w
	_persist()
	progress_changed.emit()
	weapon_changed.emit(lv - 1)
	return true


# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------
func _reset_sword() -> void:
	var w: Dictionary = progress.get("weapon", {})
	var highest := int(w.get("highestEver", 0))
	progress["weapon"] = { "level": 0, "attempts": 0, "failures": 0, "highestEver": highest }
	_persist()
	progress_changed.emit()
	weapon_changed.emit(0)


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
	var merged := _default_progress()
	for k in (parsed as Dictionary).keys():
		merged[k] = parsed[k]
	# Legacy theme IDs from earlier iterations — collapse onto a single id so
	# UI doesn't blow up. Sword mode doesn't actually use the theme anymore.
	var legacy_theme_map := {
		"beige": "programmer", "blue": "wizard", "green": "ninja",
		"pink": "chef", "yellow": "explorer",
		"robot": "programmer", "animal": "explorer",
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
		"timerEnabled": true,
		"fontSizeScale": 1,    # 0=small, 1=medium, 2=large
		"weapon": { "level": 0, "attempts": 0, "failures": 0, "highestEver": 0 },
		"materials": 0,        # 강화권 — earned one per correct answer
		"gold": STARTER_GOLD,  # 골드 — starter grant + earned by selling swords
		"protectionScrolls": 0,
		"shards": 0,           # 파편 — earned from destroyed swords; spent at the shop
		"difficulty": "easy",  # "easy" or "hard" — applied to Weapon rates
		"quizSessions": {},    # pack_path → { index, total, correct, ... } resume cursor
	}
