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
