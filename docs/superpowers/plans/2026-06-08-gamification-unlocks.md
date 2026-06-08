# 게이미피케이션 확장 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 유저 레벨로 시장 콘텐츠를 단계 해금하고, 학습 루프를 보강하는 소비템 3종과 코스메틱 업적/칭호 수집을 추가한다.

**Architecture:** 순수 도메인(`Economy`, `Achievements`)이 해금 티어·업적 조건을 정의하고, `ProgressStore`(autoload)가 보유/구매/사용 상태와 업적 체크를 atomic write로 관리한다. UI(market/forge/quiz/collection)는 도메인·스토어를 읽어 표시만 한다.

**Tech Stack:** Godot 4.6.3 GDScript, 단일 파일 테스트 러너(`tests/test_runner.gd`, `_eq`/`_section`), JSON 데이터, Lucide SVG 아이콘.

---

## 파일 구조

**신규**
- `scripts/domain/economy.gd` — `class_name Economy`. 해금 티어, 검 구매 상한, 소비템 비용/효과 상수. 순수.
- `scripts/domain/achievements.gd` — `class_name Achievements`. 업적 테이블 + `check(progress)`. 순수.
- `data/achievements.json` — (선택) 현재는 코드 테이블로 충분 → **도입 안 함(YAGNI)**. 업적은 `achievements.gd`에 인라인.
- `scenes/Collection.tscn` + `scripts/ui/collection.gd` — 배지 그리드 + 칭호 장착.
- `assets/icons/*.svg` — Lucide 아이콘.

**수정**
- `scripts/domain/weapon.gd` — `try_attempt`에 `success_bonus` 파라미터.
- `scripts/autoload/progress_store.gd` — 신규 progress 필드, 소비템 구매/사용, `try_enhance(use_scroll, use_charm)`, `everDestroyed`, 업적 체크, 칭호, 신규 signal.
- `scripts/autoload/pack_store.gd` — submit_answer에 XP 부스터·콤보 보험 적용 + 세션/강화 후 업적 체크 훅(스토어 경유).
- `scripts/ui/forge.gd` — 행운 부적 토글.
- `scripts/ui/quiz.gd` — 부스터/보험 활성 뱃지.
- `scripts/ui/market.gd` — 레벨 게이팅 섹션 + 잠금 표시 + 소비상점.
- `scripts/ui/home.gd` — 장착 칭호 표시 + Collection 진입.
- `tests/test_runner.gd` — economy/achievements/소비템 효과 케이스.
- `LICENSES.md` — Lucide 표기.
- `project.godot` — (필요 시) Collection autoload 아님, 라우팅만.

---

## Phase 1 — 도메인 + 데이터

### Task 1: Economy 도메인 (해금 티어 + 검 구매 상한 + 소비템 상수)

**Files:**
- Create: `scripts/domain/economy.gd`
- Test: `tests/test_runner.gd` (`_test_economy` 추가)

- [ ] **Step 1: 실패 테스트 작성** — `tests/test_runner.gd`의 `_initialize()`에 `_test_economy()` 호출 추가하고 함수 작성:

```gdscript
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
```

- [ ] **Step 2: 실패 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: FAIL — `Identifier "Economy" not declared`.

- [ ] **Step 3: economy.gd 작성**

```gdscript
# 레벨 게이팅 해금 티어 + 소비템 비용/효과. 순수 — 상태 없음.
class_name Economy
extends RefCounted

const UNLOCK_CONSUMABLE_SHOP: int = 5
const UNLOCK_XP_BOOST: int = 10

# 소비템 비용 — 파편/골드 중 택1로 구매(둘 다 키 존재 시 UI가 둘 다 노출).
const LUCK_CHARM_COST: Dictionary = { "shards": 30, "gold": 800 }
const XP_BOOST_COST: Dictionary = { "gold": 500 }
const COMBO_INSURE_COST: Dictionary = { "shards": 20, "gold": 500 }

const LUCK_CHARM_BONUS: float = 0.10   # 강화 성공률 +10%p (1회)
const XP_BOOST_QUESTIONS: int = 10     # 다음 N문제 XP ×2

# 유저 레벨에서 살 수 있는 최고 검 단계(파편/골드 교환 상한). 0 = 구매 잠금.
static func max_buyable_sword_level(user_level: int) -> int:
	if user_level >= 20:
		return 12
	if user_level >= 10:
		return 9
	if user_level >= 5:
		return 5
	return 0

static func consumable_shop_unlocked(user_level: int) -> bool:
	return user_level >= UNLOCK_CONSUMABLE_SHOP

static func xp_boost_unlocked(user_level: int) -> bool:
	return user_level >= UNLOCK_XP_BOOST
```

- [ ] **Step 4: 통과 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: PASS — Economy 8케이스 통과.

- [ ] **Step 5: 커밋**

```bash
git add scripts/domain/economy.gd tests/test_runner.gd
git commit -m "feat(economy): 레벨 게이팅 해금 티어 + 소비템 상수 (도메인)"
```

### Task 2: Achievements 도메인 (테이블 + check)

**Files:**
- Create: `scripts/domain/achievements.gd`
- Test: `tests/test_runner.gd` (`_test_achievements` 추가)

- [ ] **Step 1: 실패 테스트 작성** — `_initialize()`에 `_test_achievements()` 추가하고:

```gdscript
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
	# 이미 보유한 건 다시 안 나옴
	p["achievements"] = ["first_enhance"]
	_eq(Achievements.check(p).has("first_enhance"), false, "보유분은 제외")
	_eq(Achievements.title_for("reach_10"), "미스릴 장인", "칭호 매핑")
```

- [ ] **Step 2: 실패 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: FAIL — `Identifier "Achievements" not declared`.

- [ ] **Step 3: achievements.gd 작성**

```gdscript
# 코스메틱 업적/칭호. 조건은 progress 필드로 순수 평가. 보너스 없음.
class_name Achievements
extends RefCounted

const LIST: Array = [
	{ "id": "first_enhance", "title": "견습 대장장이", "desc": "첫 강화 시도" },
	{ "id": "reach_5",       "title": "강철의 손",     "desc": "+5 달성" },
	{ "id": "reach_10",      "title": "미스릴 장인",   "desc": "+10 달성" },
	{ "id": "reach_15",      "title": "전설의 검공",   "desc": "+15 달성" },
	{ "id": "correct_100",   "title": "백문백답",      "desc": "누적 100정답" },
	{ "id": "correct_500",   "title": "천재 수험생",   "desc": "누적 500정답" },
	{ "id": "combo_20",      "title": "콤보 마스터",   "desc": "한 세션 콤보 20" },
	{ "id": "first_destroy", "title": "파괴를 본 자",  "desc": "검 파괴 경험" },
]

static func _max_session_combo(p: Dictionary) -> int:
	var best: int = 0
	var sessions = p.get("sessions", [])
	if typeof(sessions) == TYPE_ARRAY:
		for s in sessions:
			best = maxi(best, int(s.get("bestCombo", 0)))
	return best

static func _met(id: String, p: Dictionary) -> bool:
	var w: Dictionary = p.get("weapon", {})
	match id:
		"first_enhance": return int(w.get("attempts", 0)) >= 1
		"reach_5":       return int(w.get("highestEver", 0)) >= 5
		"reach_10":      return int(w.get("highestEver", 0)) >= 10
		"reach_15":      return int(w.get("highestEver", 0)) >= 15
		"correct_100":   return int(p.get("totalCorrect", 0)) >= 100
		"correct_500":   return int(p.get("totalCorrect", 0)) >= 500
		"combo_20":      return _max_session_combo(p) >= 20
		"first_destroy": return bool(p.get("everDestroyed", false))
	return false

# 조건 충족 + 미보유인 업적 id 배열 반환.
static func check(p: Dictionary) -> Array:
	var owned: Array = p.get("achievements", [])
	var newly: Array = []
	for a in LIST:
		var id: String = a["id"]
		if not owned.has(id) and _met(id, p):
			newly.append(id)
	return newly

static func title_for(id: String) -> String:
	for a in LIST:
		if a["id"] == id:
			return String(a["title"])
	return ""
```

- [ ] **Step 4: 통과 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add scripts/domain/achievements.gd tests/test_runner.gd
git commit -m "feat(achievements): 코스메틱 업적/칭호 테이블 + check (도메인)"
```

### Task 3: ProgressStore — 신규 필드 + getter/setter

**Files:**
- Modify: `scripts/autoload/progress_store.gd` (`_default_progress`, 신규 getter/signal)

- [ ] **Step 1: `_default_progress()`에 신규 키 추가** — 기존 반환 Dictionary에 아래 키를 추가(기존 키 불변):

```gdscript
	"consumables": { "luck_charm": 0, "xp_boost": 0, "combo_insure": 0 },
	"xp_boost_remaining": 0,
	"combo_insure_armed": false,
	"achievements": [],
	"title": "",
	"everDestroyed": false,
```

- [ ] **Step 2: 신규 signal 선언** — 파일 상단 signal 블록에 추가:

```gdscript
signal consumables_changed(state: Dictionary)
signal achievement_unlocked(id: String)
signal title_changed(title_id: String)
```

- [ ] **Step 3: getter 추가** (파일 내 기존 getter 옆):

```gdscript
func get_consumables() -> Dictionary:
	return progress.get("consumables", {}).duplicate()

func get_consumable(id: String) -> int:
	return int(progress.get("consumables", {}).get(id, 0))

func get_achievements() -> Array:
	return progress.get("achievements", []).duplicate()

func get_title() -> String:
	return String(progress.get("title", ""))

func set_title(id: String) -> void:
	progress["title"] = id
	_persist()
	title_changed.emit(id)
```

- [ ] **Step 4: 컴파일 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: PASS (기존 케이스 그대로; autoload 미인스턴스라 에러 없어야 함).

- [ ] **Step 5: 커밋**

```bash
git add scripts/autoload/progress_store.gd
git commit -m "feat(store): 게이미피케이션 progress 필드 + getter/signal"
```

---

## Phase 2 — 소비 아이템 효과

### Task 4: Weapon.try_attempt 성공률 보너스 파라미터

**Files:**
- Modify: `scripts/domain/weapon.gd:61` (`try_attempt` 시그니처)
- Test: `tests/test_runner.gd` (`_test_weapon`에 케이스 추가)

- [ ] **Step 1: 실패 테스트 추가** — `_test_weapon()` 끝에:

```gdscript
	# 행운 부적 성공률 보너스: roll 0.95에서 기본 실패지만 +0.10 보너스로도 +0(100%)엔 영향 없음.
	# +5(성공 0.40)에서 roll 0.45는 기본 실패(stay/destroy), 보너스 0.10이면 0.50 → 성공.
	_eq(Weapon.try_attempt(5, false, 0.45, "easy")["result"] == "success", false, "+5 roll0.45 보너스X → 실패")
	_eq(Weapon.try_attempt(5, false, 0.45, "easy", 0.10)["result"], "success", "+5 roll0.45 +10%p → 성공")
```

- [ ] **Step 2: 실패 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: FAIL — try_attempt이 5번째 인자를 받지 않음.

- [ ] **Step 3: try_attempt 수정** — `scripts/domain/weapon.gd`의 시그니처와 성공 판정:

```gdscript
static func try_attempt(level: int, use_scroll: bool, roll: float = -1.0, difficulty: String = "easy", success_bonus: float = 0.0) -> Dictionary:
	if level >= ENHANCE_MAX_LEVEL:
		return { "result": "max", "level": level, "shards": 0 }
	if level < 0 or level >= ENHANCE_TABLE.size():
		return { "result": "stay", "level": level, "shards": 0 }
	var success_rate: float = clampf(success_rate_at(level, difficulty) + maxf(0.0, success_bonus), 0.0, 1.0)
	var destroy_rate: float = destroy_rate_at(level, difficulty)
	var r: float = randf() if roll < 0.0 else roll
	if r < success_rate:
		return { "result": "success", "level": mini(ENHANCE_MAX_LEVEL, level + 1), "shards": 0 }
	if r < success_rate + destroy_rate:
		if use_scroll:
			return { "result": "stay_protected", "level": level, "shards": 0 }
		return { "result": "destroy", "level": 0, "shards": shard_reward_for_destroy(level) }
	return { "result": "stay", "level": level, "shards": 0 }
```

- [ ] **Step 4: 통과 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add scripts/domain/weapon.gd tests/test_runner.gd
git commit -m "feat(weapon): try_attempt 성공률 보너스 인자 (행운 부적용)"
```

### Task 5: ProgressStore — 소비템 구매/사용 + try_enhance(use_charm) + everDestroyed

**Files:**
- Modify: `scripts/autoload/progress_store.gd` (`try_enhance`, 신규 `buy_consumable`/`use_*`)

- [ ] **Step 1: `buy_consumable(id)` 작성** — 파편/골드 비용 차감 후 +1:

```gdscript
# id ∈ {"luck_charm","xp_boost","combo_insure"}. pay ∈ {"shards","gold"}.
func buy_consumable(id: String, pay: String) -> Dictionary:
	var cost: Dictionary
	match id:
		"luck_charm": cost = Economy.LUCK_CHARM_COST
		"xp_boost": cost = Economy.XP_BOOST_COST
		"combo_insure": cost = Economy.COMBO_INSURE_COST
		_: return { "ok": false, "reason": "unknown_item" }
	if not cost.has(pay):
		return { "ok": false, "reason": "bad_payment" }
	var amount: int = int(cost[pay])
	if pay == "gold":
		if not spend_gold(amount):
			return { "ok": false, "reason": "not_enough_gold" }
	else:
		if get_shards() < amount:
			return { "ok": false, "reason": "not_enough_shards" }
		progress["shards"] = get_shards() - amount
	var c: Dictionary = progress.get("consumables", {})
	c[id] = int(c.get(id, 0)) + 1
	progress["consumables"] = c
	_persist()
	progress_changed.emit()
	consumables_changed.emit(get_consumables())
	if pay == "shards":
		shards_changed.emit(get_shards())
	return { "ok": true }
```

- [ ] **Step 2: `try_enhance`에 `use_charm` 추가** — 기존 `try_enhance(use_scroll)` 시그니처를 확장하고 성공 보너스·소비·everDestroyed 반영. `scripts/autoload/progress_store.gd`의 `try_enhance` 본문에서 아래로 교체(핵심 변경부):

```gdscript
func try_enhance(use_scroll: bool = false, use_charm: bool = false) -> Dictionary:
	if get_enhance_tickets() < Weapon.ENHANCE_MATERIAL_COST:
		return { "ok": false, "reason": "not_enough_tickets" }
	var before := get_weapon_level()
	if before >= Weapon.ENHANCE_MAX_LEVEL:
		return { "ok": false, "reason": "max_level" }

	var scroll_armed := use_scroll and get_protection_scrolls() > 0
	var charm_armed := use_charm and get_consumable("luck_charm") > 0
	var bonus := Economy.LUCK_CHARM_BONUS if charm_armed else 0.0
	var outcome := Weapon.try_attempt(before, scroll_armed, -1.0, get_difficulty(), bonus)
	var result: String = outcome.get("result", "stay")
	var after: int = int(outcome.get("level", before))
	var shards_gained: int = int(outcome.get("shards", 0))
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
	if charm_armed:
		var c: Dictionary = progress.get("consumables", {})
		c["luck_charm"] = maxi(0, int(c.get("luck_charm", 0)) - 1)
		progress["consumables"] = c
	if result == "destroy":
		progress["everDestroyed"] = true
	if shards_gained > 0:
		progress["shards"] = get_shards() + shards_gained

	_persist()
	progress_changed.emit()
	weapon_changed.emit(after)
	tickets_changed.emit(get_enhance_tickets())
	materials_changed.emit(get_enhance_tickets())
	if scroll_consumed:
		scrolls_changed.emit(get_protection_scrolls())
	if charm_armed:
		consumables_changed.emit(get_consumables())
	if shards_gained > 0:
		shards_changed.emit(get_shards())
	enhance_result.emit(result, before, after, get_enhance_tickets(), shards_gained)
	_check_achievements()
	return { "ok": true, "result": result, "before": before, "after": after }
```

- [ ] **Step 3: `_check_achievements()` 작성** (업적 평가 + 알림):

```gdscript
func _check_achievements() -> void:
	var newly := Achievements.check(progress)
	if newly.is_empty():
		return
	var owned: Array = progress.get("achievements", [])
	for id in newly:
		owned.append(id)
		achievement_unlocked.emit(String(id))
	progress["achievements"] = owned
	_persist()
```

- [ ] **Step 4: 컴파일 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: PASS (기존 케이스 유지).

- [ ] **Step 5: 커밋**

```bash
git add scripts/autoload/progress_store.gd
git commit -m "feat(store): 소비템 구매 + try_enhance 행운부적/everDestroyed + 업적 체크"
```

### Task 6: PackStore — XP 부스터 + 콤보 보험 + 세션 후 업적 체크

**Files:**
- Modify: `scripts/autoload/pack_store.gd` (`submit_answer`, `_complete_session`)

- [ ] **Step 1: XP 부스터 적용** — `submit_answer`의 정답 분기에서 XP 계산 직후, ×2 적용:

```gdscript
		var multiplier := Leveling.combo_multiplier(combo_count)
		var xp_award := int(round(Leveling.XP_PER_CORRECT * multiplier))
		if ProgressStore.get_progress_value("xp_boost_remaining", 0) > 0:
			xp_award *= 2
			info["bonuses"].append("⚡ XP 부스터 ×2")
		ProgressStore.add_xp(xp_award)
```

  그리고 정답·오답 무관하게 부스터 카운트다운(함수 끝, feedback.emit 전):

```gdscript
	if ProgressStore.get_progress_value("xp_boost_remaining", 0) > 0:
		ProgressStore.decrement_xp_boost()
```

- [ ] **Step 2: 콤보 보험 적용** — 오답 분기에서 combo 리셋 전에 보험 확인:

```gdscript
	else:
		if ProgressStore.consume_combo_insurance_if_armed():
			info["bonuses"].append("🔥 콤보 보험 — 콤보 유지")
			# 콤보 유지: combo_count 변경 없음, combo_changed 재emit
			combo_changed.emit(combo_count, Leveling.is_on_fire(combo_count))
		else:
			combo_count = 0
			combo_changed.emit(0, false)
			# (기존 오답 처리: _register_wrong, 내구도 등) — 아래 기존 코드 유지
```

  ⚠️ 기존 오답 블록(`_register_wrong`, durability)은 보험으로 콤보를 살린 경우에도 *오답은 오답*이므로 그대로 실행한다(콤보만 보존). 위 if/else로 콤보 리셋만 분기하고, 오답 기록·내구도 로직은 분기 밖에서 기존대로 수행하도록 배치.

- [ ] **Step 3: ProgressStore 헬퍼 추가** — `scripts/autoload/progress_store.gd`:

```gdscript
func get_progress_value(key: String, fallback):
	return progress.get(key, fallback)

func decrement_xp_boost() -> void:
	progress["xp_boost_remaining"] = maxi(0, int(progress.get("xp_boost_remaining", 0)) - 1)
	_persist()

func activate_xp_boost() -> bool:
	if get_consumable("xp_boost") <= 0:
		return false
	var c: Dictionary = progress.get("consumables", {})
	c["xp_boost"] = int(c["xp_boost"]) - 1
	progress["consumables"] = c
	progress["xp_boost_remaining"] = Economy.XP_BOOST_QUESTIONS
	_persist()
	consumables_changed.emit(get_consumables())
	return true

func arm_combo_insurance() -> bool:
	if get_consumable("combo_insure") <= 0:
		return false
	var c: Dictionary = progress.get("consumables", {})
	c["combo_insure"] = int(c["combo_insure"]) - 1
	progress["consumables"] = c
	progress["combo_insure_armed"] = true
	_persist()
	consumables_changed.emit(get_consumables())
	return true

func consume_combo_insurance_if_armed() -> bool:
	if not bool(progress.get("combo_insure_armed", false)):
		return false
	progress["combo_insure_armed"] = false
	_persist()
	return true
```

- [ ] **Step 4: 세션 완료 후 업적 체크** — `pack_store.gd`의 `_complete_session()`에서 `ProgressStore.record_session(record)` 직후:

```gdscript
	ProgressStore.check_achievements_public()
```

  그리고 `progress_store.gd`에 공개 래퍼:

```gdscript
func check_achievements_public() -> void:
	_check_achievements()
```

- [ ] **Step 5: 통과 확인** — Run: `godot --headless --script res://tests/test_runner.gd`
  Expected: PASS (기존 100 케이스 유지).

- [ ] **Step 6: 커밋**

```bash
git add scripts/autoload/pack_store.gd scripts/autoload/progress_store.gd
git commit -m "feat(quiz): XP 부스터 ×2 + 콤보 보험 + 세션 후 업적 체크"
```

---

## Phase 3 — 레벨 게이팅 시장 UI

### Task 7: Forge — 행운 부적 토글

**Files:**
- Modify: `scripts/ui/forge.gd`

- [ ] **Step 1: 부적 체크박스 추가** — `_build_layout`의 scroll_row 아래에 `_charm_check` 생성(기존 `_scroll_check` 패턴 복제). 멤버 `var _charm_check: CheckBox`, `var _pending_charm := false` 추가.

```gdscript
	_charm_check = CheckBox.new()
	_charm_check.add_theme_font_size_override("font_size", 14)
	scroll_row.add_child(_charm_check)
```

- [ ] **Step 2: `_refresh()`에 부적 상태 표시** — scroll 토글 갱신 옆에:

```gdscript
	var charms := ProgressStore.get_consumable("luck_charm")
	if charms == 0:
		_charm_check.disabled = true
		_charm_check.button_pressed = false
		_charm_check.text = "행운 부적 — 보유 0개 (시장)"
	else:
		_charm_check.disabled = false
		_charm_check.text = "행운 부적 (+10%p) · 보유 %d개" % charms
```

- [ ] **Step 3: `_on_try`에서 부적 스냅샷 + `_do_enhance`에서 전달**:

```gdscript
	_pending_charm = _charm_check.button_pressed and ProgressStore.get_consumable("luck_charm") > 0
```
```gdscript
	var result := ProgressStore.try_enhance(_pending_scroll, _pending_charm)
```

- [ ] **Step 4: 실행 확인** — Run: `godot --path .` → 강화소에서 부적 토글 표시/활성 확인(보유 0이면 "보유 0개 (시장)").

- [ ] **Step 5: 커밋**

```bash
git add scripts/ui/forge.gd
git commit -m "feat(forge): 행운 부적 토글 + try_enhance 전달"
```

### Task 8: Market — 레벨 게이팅 섹션 + 소비상점 + 잠금 표시

**Files:**
- Modify: `scripts/ui/market.gd`

- [ ] **Step 1: 소비상점 섹션 추가** — `_build_layout`에 소비템 3종 구매 패널 추가. 각 아이템마다 파편/골드 버튼. `Economy.consumable_shop_unlocked(level)` false면 패널을 회색 + "Lv5 해금" 라벨 + 자물쇠 아이콘으로 표시(버튼 disabled).

```gdscript
func _make_consumable_row(id: String, name: String, cost: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var lbl := Label.new(); lbl.text = name; lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(lbl)
	if cost.has("shards"):
		var b := Button.new(); b.text = "파편 %d" % cost["shards"]
		b.pressed.connect(func(): _buy_consumable(id, "shards"))
		row.add_child(b)
	if cost.has("gold"):
		var b2 := Button.new(); b2.text = "골드 %d" % cost["gold"]
		b2.pressed.connect(func(): _buy_consumable(id, "gold"))
		row.add_child(b2)
	return row

func _buy_consumable(id: String, pay: String) -> void:
	var r := ProgressStore.buy_consumable(id, pay)
	_status_label.text = "✅ 구매 완료" if r.get("ok", false) else "구매 실패: %s" % r.get("reason", "")
	_refresh()
```

- [ ] **Step 2: 검 구매 게이팅** — 기존 검 구매(파편 교환) 옵션에서 `Economy.max_buyable_sword_level(level)`보다 높은 단계 버튼은 disabled + "Lv10 해금" 라벨. (기존 `exchange_shards_for_sword` 호출 유지, 상한만 게이팅.)

- [ ] **Step 3: `_refresh()`에서 해금 상태 반영** — 레벨 변동 시 잠금/활성 갱신. `ProgressStore.get_level()` 사용. `_refresh`를 `ProgressStore.totalXP`/level 변동에도 연결(이미 progress_changed 연결돼 있으면 그걸 사용).

- [ ] **Step 4: 실행 확인** — Run: `godot --path .` → 시장에서 Lv5 미만이면 소비상점 잠금, Lv5+면 구매 가능. 검 고단계는 레벨에 따라 잠금.

- [ ] **Step 5: 커밋**

```bash
git add scripts/ui/market.gd
git commit -m "feat(market): 레벨 게이팅 + 소비상점 + 잠금 표시"
```

### Task 9: Quiz — XP 부스터/콤보 보험 활성 뱃지 + 활성화 버튼

**Files:**
- Modify: `scripts/ui/quiz.gd`

- [ ] **Step 1: 상단바에 소비템 활성 버튼/뱃지 추가** — 보유 시 "⚡ 부스터 켜기"/"🔥 보험 켜기" 버튼(보유 0이면 숨김). 누르면 `ProgressStore.activate_xp_boost()` / `arm_combo_insurance()`. 활성 중이면 `xp_boost_remaining` 카운트·보험 장착 표시.

```gdscript
func _refresh_consumable_badges() -> void:
	var boost_left := ProgressStore.get_progress_value("xp_boost_remaining", 0)
	_boost_label.text = ("⚡ XP×2 (%d문제)" % boost_left) if boost_left > 0 else ""
	var armed := ProgressStore.get_progress_value("combo_insure_armed", false)
	_insure_label.text = "🔥 보험 장착" if armed else ""
```

  (이모지는 Task 13에서 Lucide 아이콘으로 교체.)

- [ ] **Step 2: 활성화 버튼 배선** — 보유 수량 있을 때만 노출, 활성화 후 `_refresh_consumable_badges()` 갱신.

- [ ] **Step 3: 실행 확인** — Run: `godot --path .` → 부스터/보험 보유 시 켜기, 활성 표시 확인.

- [ ] **Step 4: 커밋**

```bash
git add scripts/ui/quiz.gd
git commit -m "feat(quiz): 소비템 활성화 버튼 + 활성 뱃지"
```

---

## Phase 4 — 업적/칭호 + 수집 화면

### Task 10: 업적 달성 알림 (전역)

**Files:**
- Modify: `scripts/ui/forge.gd`, `scripts/ui/quiz.gd` (achievement_unlocked 토스트)

- [ ] **Step 1: 알림 연결** — forge·quiz `_ready`에 `ProgressStore.achievement_unlocked.connect(_on_achievement)`:

```gdscript
func _on_achievement(id: String) -> void:
	_show_toast("🏆 업적 달성: %s" % Achievements.title_for(id), Color(1.0, 0.9, 0.5))
```
  (forge는 `_result_label`에 표시, quiz는 기존 `_show_toast` 재사용.)

- [ ] **Step 2: 실행 확인** — Run: `godot --path .` → 첫 강화 시 "🏆 업적 달성: 견습 대장장이" 토스트.

- [ ] **Step 3: 커밋**

```bash
git add scripts/ui/forge.gd scripts/ui/quiz.gd
git commit -m "feat(ui): 업적 달성 토스트 알림"
```

### Task 11: Collection 화면 (배지 그리드 + 칭호 장착)

**Files:**
- Create: `scenes/Collection.tscn` (3줄 골조 — Control + collection.gd 부착), `scripts/ui/collection.gd`

- [ ] **Step 1: Collection.tscn 골조** — 기존 씬 패턴(예: Market.tscn) 복제, 루트 Control에 `collection.gd` 부착.

- [ ] **Step 2: collection.gd 작성** — `_build_layout`에서 `Achievements.LIST`를 그리드로 렌더. 획득(progress.achievements 포함)은 컬러+칭호, 미획득은 회색+자물쇠. 획득 배지 클릭 시 `ProgressStore.set_title(id)`로 칭호 장착.

```gdscript
extends Control
func _ready() -> void:
	_build_layout()
func _build_layout() -> void:
	var owned := ProgressStore.get_achievements()
	var current := ProgressStore.get_title()
	# ... HFlowContainer로 Achievements.LIST 순회, 각 배지 PanelContainer 생성 ...
	# owned.has(id) → 활성 스타일 + 클릭 시 set_title; else 회색+lock
```

- [ ] **Step 3: 실행 확인** — Run: `godot --path .` → Collection 진입(Task 12 후), 배지·칭호 장착 동작.

- [ ] **Step 4: 커밋**

```bash
git add scenes/Collection.tscn scripts/ui/collection.gd
git commit -m "feat(collection): 업적 배지 그리드 + 칭호 장착 화면"
```

### Task 12: Home — 칭호 표시 + Collection 진입

**Files:**
- Modify: `scripts/ui/home.gd`

- [ ] **Step 1: 장착 칭호 라벨** — 홈 상단/검 옆에 `ProgressStore.get_title()` → `Achievements.title_for(id)` 표시(빈 값이면 숨김). `title_changed` 연결로 갱신.

- [ ] **Step 2: Collection 진입 버튼** — `get_tree().change_scene_to_file("res://scenes/Collection.tscn")`.

- [ ] **Step 3: 실행 확인** — Run: `godot --path .` → 홈에서 칭호 표시 + Collection 진입.

- [ ] **Step 4: 커밋**

```bash
git add scripts/ui/home.gd
git commit -m "feat(home): 장착 칭호 표시 + Collection 진입"
```

---

## Phase 5 — Lucide 아이콘

### Task 13: Lucide SVG 번들 + 이모지 교체

**Files:**
- Create: `assets/icons/*.svg`
- Modify: `LICENSES.md`, 이모지 사용 UI(forge/quiz/market/collection/home)

- [ ] **Step 1: Lucide SVG 다운로드** — 아이콘별로 unpkg에서 받아 `assets/icons/`에 저장:

```bash
mkdir -p assets/icons
for n in clover zap flame scroll-text coins gem swords trophy badge-check lock sparkles; do
  curl -fsSL "https://unpkg.com/lucide-static@latest/icons/$n.svg" -o "assets/icons/$n.svg"
done
ls assets/icons
```

- [ ] **Step 2: import 생성** — Run: `godot --headless --import` (SVG → .ctex import 메타 생성).
  Expected: `.import` 파일 생성, 에러 없음.

- [ ] **Step 3: UI 이모지 교체** — forge/quiz/market/collection/home에서 🍀⚡🔥📜 등 이모지 Label을 `TextureRect`(아이콘 SVG, `modulate` 색)로 교체. 헬퍼:

```gdscript
func _icon(name: String, color: Color, size: int = 20) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/icons/%s.svg" % name)
	t.custom_minimum_size = Vector2(size, size)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = color
	return t
```

- [ ] **Step 4: LICENSES.md 갱신** — Lucide 항목 추가:

```markdown
## Icons
- Lucide (https://lucide.dev) — ISC License. UI/아이템 아이콘.
```

- [ ] **Step 5: 실행 확인** — Run: `godot --path .` → 아이콘이 이모지 대신 이미지로 표시.

- [ ] **Step 6: 커밋**

```bash
git add assets/icons LICENSES.md scripts/ui
git commit -m "feat(icons): Lucide SVG 번들 + UI 이모지 교체"
```

---

## 최종 검증

- [ ] `godot --headless --script res://tests/test_runner.gd` → 기존 100 + economy 8 + achievements 9 + weapon 보너스 2 케이스 전부 통과.
- [ ] `godot --path .` 실행 → 레벨별 해금/소비템/업적/칭호/아이콘 수동 확인.
- [ ] README "디렉토리 구조"에 economy.gd/achievements.gd/Collection 추가(CLAUDE.md §11).

## 범위 밖 (재확인)
검 스킨, 일일/출석 보상, 칭호 보너스, 강화권 골드 구매, 이벤트 상점 — 제외.
