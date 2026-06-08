# 게이미피케이션 확장: 레벨 게이팅 언락 + 소비템 + 업적/칭호

**날짜**: 2026-06-08
**상태**: 설계 승인됨, 구현 계획 대기
**목표 의도**: 보상 다양성 + 수집·과시 (학습 루프를 *우회*하지 않고 *보강*)

---

## 1. 개요

유저 레벨(XP 삼각곡선, `Leveling.level_from_xp`)에 따라 시장 콘텐츠를 단계적으로
해금하고, 학습 루프를 보강하는 소비 아이템 3종과 코스메틱 업적/칭호 수집을
추가한다. 기존 경제(골드=검 판매, 파편=검 파괴, 강화권=정답)와 시장 함수
(`exchange_shards_for_sword`, `buy_sword_with_gold`, `buy_scroll_bundle`) 위에 얹는다.

핵심 제약: **현금 결제 없음, 강화권을 직접 사는 우회 없음.** 모든 구매는 플레이로
번 골드/파편으로만 한다.

---

## 2. 레벨 마일스톤 해금 티어

기존 `Leveling.PROMOTION_LEVELS = [5, 10, 20]`을 해금 임계로 재사용한다.

| 레벨 | 해금 콘텐츠 |
|---|---|
| 시작(Lv1) | 검 판매, 보호 주문서 (현행 유지) |
| **Lv5** | 소비상점(행운 부적·콤보 보험), 중단계 검 구매 (목표 +3~+5) |
| **Lv10** | 고단계 검 구매 (목표 +6~+9), XP 부스터 |
| **Lv20** | 특수: 최고단계 검 구매 (목표 +10~+12) |

- 잠긴 항목은 시장에서 **회색 + "Lv10 해금" 라벨 + 자물쇠 아이콘**으로 노출 → 목표
  가시화(동기·과시). 숨기지 않는다.
- 검 구매 목표 레벨은 위 구간으로 클램프. 비용은 기존 `exchange_shards_for_sword`
  /`buy_sword_with_gold`의 공식을 그대로 사용(신규 가격표 도입 안 함).

## 3. 소비 아이템 3종

파편/골드로만 구매. 보유 수량은 progress에 저장. 시작 가격(튜닝 가능):

| 아이템 | 효과 | 구매가(시작값) | 사용처 |
|---|---|---|---|
| 🍀 행운 부적 | 다음 강화 1회 **성공률 +10%p** | 파편 30 또는 골드 800 | 강화소 토글(주문서와 별도), 시도 시 소비 |
| ⚡ XP 부스터 | 활성 후 **다음 10문제 XP ×2** | 골드 500 | 퀴즈 화면 활성화, 문제마다 카운트다운 |
| 🔥 콤보 보험 | 활성 시 **다음 오답 1회 콤보 유지** | 파편 20 또는 골드 500 | 퀴즈 화면 활성화, 오답 1회 소모 |

규칙:
- 행운 부적: `Weapon.try_attempt`에 `success_bonus` 파라미터 추가(순수 함수 유지).
  `try_enhance(use_scroll, use_charm)` — use_charm 시 성공률 +0.10(클램프), 시도 시 1개 소모.
- XP 부스터: `PackStore.submit_answer`에서 `xp_boost_remaining > 0`이면 XP ×2, 정답·오답
  무관하게 문제당 1 감소(0이면 비활성).
- 콤보 보험: 오답 시 `combo_insure_armed`면 콤보 유지 + 플래그 해제(1회 소모).

## 4. 업적 + 칭호/배지 (코스메틱, 보너스 없음)

`data/achievements.json` — 정의 테이블. 조건은 progress 필드로 평가(순수 함수).

시작 업적 세트(8종):

| id | 조건 | 칭호 |
|---|---|---|
| first_enhance | weapon.attempts ≥ 1 | 견습 대장장이 |
| reach_5 | weapon.highestEver ≥ 5 | 강철의 손 |
| reach_10 | weapon.highestEver ≥ 10 | 미스릴 장인 |
| reach_15 | weapon.highestEver ≥ 15 | 전설의 검공 |
| correct_100 | totalCorrect ≥ 100 | 백문백답 |
| correct_500 | totalCorrect ≥ 500 | 천재 수험생 |
| combo_20 | max(sessions[].bestCombo) ≥ 20 | 콤보 마스터 |
| first_destroy | everDestroyed == true | 파괴를 본 자 |

- 달성 시 알림 토스트 + 칭호 획득. 칭호는 **코스메틱**: 홈 화면/검 옆에 장착 칭호 표시.
  게임플레이 보너스 없음(밸런스 안전·단순).
- 신규 **수집 화면**(`Collection.tscn`): 획득/미획득 배지 그리드 + 칭호 장착 선택.
- 평가 시점: 강화 직후, 세션 완료 직후 `Achievements.check(progress)` 호출 →
  새로 달성된 id만 반환 → 저장 + 알림.

## 5. 아이콘 (Lucide SVG)

- shadcn이 쓰는 **Lucide** 아이콘 채택 (ISC/MIT, 무료, 출처표기 불필요).
  Icons8은 무료 티어 출처표기 의무라 회피.
- `res://assets/icons/`에 SVG 번들. Godot 4 SVG 네이티브 임포트 → `TextureRect`,
  item별 `modulate` 색. 이모지(🍀⚡🔥 등) 전부 실제 아이콘으로 교체.
- 필요 아이콘: clover, zap, flame, scroll-text, coins, gem, swords, trophy,
  badge-check, lock, sparkles.
- `LICENSES.md`에 Lucide 출처 추가.

## 6. 데이터 모델 (progress.json 신규 필드)

`_load_from_disk`의 shallow merge가 옛 세이브를 자동 호환(CLAUDE.md §7). 신규 필드:

```
consumables: { "luck_charm": 0, "xp_boost": 0, "combo_insure": 0 }
xp_boost_remaining: 0        # 남은 ×2 문제 수
combo_insure_armed: false    # 이번 세션 콤보 보험 장착 여부
achievements: []             # 달성한 업적 id 배열
title: ""                    # 장착 칭호 id (코스메틱)
everDestroyed: false         # 검 파괴를 한 번이라도 겪었는지 (first_destroy 업적용)
```

`everDestroyed`는 `try_enhance`에서 destroy 결과 시 true로 세팅(achievements.check는
progress만으로 순수 평가 가능해진다).

`_default_progress()`에 위 키 추가. 기존 키(weapon/materials/gold/shards 등)는 불변.

## 7. 아키텍처 / 파일

**신규 도메인 (순수, 헤드리스 테스트)**
- `scripts/domain/economy.gd` (`class_name Economy`): `unlocked_features(level) -> Dictionary`,
  `is_feature_unlocked(id, level) -> bool`, `max_buyable_sword_level(level) -> int`,
  소비템 비용/효과 상수.
- `scripts/domain/achievements.gd` (`class_name Achievements`): `ACHIEVEMENTS` 테이블,
  `check(progress) -> Array[String]` (조건 충족하지만 미보유 id 반환).

**autoload**
- `progress_store.gd`: 소비템 `buy_consumable(id)`/`use_*`, `xp_boost_remaining`,
  `combo_insure_armed`, 업적 체크 + `title` get/set. 신규 signal:
  `consumables_changed`, `achievement_unlocked(id)`, `title_changed`.
- `pack_store.gd`: submit_answer에 XP 부스터(×2)·콤보 보험 적용, 세션/강화 후 업적 체크 훅.

**UI**
- `market.gd`: 레벨 게이팅 섹션 + 잠금 표시 + 소비상점 섹션.
- `forge.gd`: 행운 부적 토글(주문서 토글 옆), try_enhance에 use_charm 전달.
- `quiz.gd`: XP 부스터/콤보 보험 활성 표시(HUD 뱃지).
- 신규 `scenes/Collection.tscn` + `scripts/ui/collection.gd`: 배지 그리드 + 칭호 장착.
- `home.gd`: 장착 칭호 표시 + Collection 진입 버튼.

**에셋/테스트**
- `assets/icons/*.svg` (Lucide) + `LICENSES.md` 갱신.
- `tests/test_runner.gd`: economy 해금 티어, achievements 조건, 소비템 효과(성공률 보너스·XP ×2·콤보 보험) 케이스 추가. 기준선 통과 유지.

## 8. 구현 단계 (phasing)

1. **도메인 + 데이터**: economy.gd, achievements.gd, progress_store 필드/함수 + 테스트.
2. **소비 아이템**: 구매(market) + 효과(forge/quiz/pack_store) 배선.
3. **레벨 게이팅 UI**: market 섹션·잠금 표시.
4. **업적·칭호 + 수집 화면**: Collection.tscn, home 칭호 표시.
5. **아이콘**: Lucide SVG 교체 + LICENSES.

## 9. 범위 밖 (YAGNI)

- 검 스킨/외형(신규 아트 비용) — 제외.
- 일일 보상·연속 출석·데일리 퀘스트(리텐션) — 이번 의도(다양성·수집)와 별개, 제외.
- 칭호 게임플레이 보너스 — 코스메틱만.
- 강화권 골드 구매(학습 우회) — 명시적 제외.
- 랜덤/시간제 이벤트 상점 — 후순위(이번 스펙 제외).

## 10. 성공 기준

- 레벨 5/10/20에서 시장에 새 항목이 해금되고, 그 전엔 잠금 표시로 보인다.
- 소비템 3종을 파편/골드로 사서 강화/퀴즈에 적용되고 1회 소모된다.
- 업적 8종이 조건 충족 시 달성·알림되고 수집 화면에 배지로 보인다. 칭호 장착이 홈에 표시된다.
- 이모지 대신 Lucide 아이콘 이미지가 게임 내 표시된다.
- `test_runner.gd` 기준선 통과 유지(도메인 신규 케이스 포함).
