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
