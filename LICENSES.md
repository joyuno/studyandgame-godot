# Third-Party Asset Licenses

StudyGame 본체 코드는 사용자 작성이다. 본 문서는 게임에 임베드된 외부 자산의 출처와 라이선스를 명시한다.

## 캐릭터·보스 스프라이트 (선택적, 사용자 추가)

### Ninja Adventure Asset Pack — by pixel-boy (권장 1순위)
- **출처**: https://pixel-boy.itch.io/ninja-adventure-asset-pack
- **라이선스**: CC0 1.0 Universal (https://creativecommons.org/publicdomain/zero/1.0/)
- **사용처**: `src/renderer/assets/characters/ninja/**` (사용자가 추출해서 배치)
- 페이지 인용: *"They are released under the Creative Commons Zero (CC0) license. You can use any and all of the assets found in this package in your own games, even commercial ones. Attribution is not required but appreciated."*

### DungeonTileset II — by 0x72 (보강 옵션)
- **출처**: https://0x72.itch.io/dungeontileset-ii
- **라이선스**: CC0
- **사용처**: 마법사·기사 테마(`src/renderer/assets/characters/wizard/**`) 보강용

### Superdark 16x16 Fantasy RPG Characters (요리사 테마 후보)
- **출처**: https://superdark.itch.io/16x16-free-npc-pack
- **라이선스**: free-for-personal-and-commercial, redistribution 허용 (페이지 확인)

### Kenney 1-Bit Pack (로봇·사이버 테마 후보)
- **출처**: https://kenney.nl/assets/1-bit-pack
- **라이선스**: CC0

### Ansimuz Legacy Collection (탐험가 테마 후보)
- **출처**: https://ansimuz.itch.io/gothicvania-patreon-collection
- **라이선스**: CC0

## CC-BY 자산 사용 시 (현재 미사용)

만약 다음 자산을 게임에 포함하면 본 섹션에 추가:

```
"Animated Goblins" by Calciumtrice, licensed under CC-BY 3.0
(https://creativecommons.org/licenses/by/3.0/)
Source: https://opengameart.org/content/animated-goblins
```

## 실제 임베드된 PNG 자산 (Riff 7 — 2026-05-13 다운로드)

본 프로젝트에 직접 임베드된 PNG 자산. 모두 OpenGameArt CC0.

### programmer 테마
- `src/renderer/assets/characters/programmer/lv01_idle.png` — "Simple Character Base [16x16]" by zaphgames (CC0)
  - 원본: https://opengameart.org/sites/default/files/character_base_16x16_0.png
  - 페이지: https://opengameart.org/content/simple-character-base-16x16
- `src/renderer/assets/characters/programmer/lv05_idle.png` — "16x16 base sprites" — male (CC0)
  - 원본: https://opengameart.org/sites/default/files/base_male.png
- `src/renderer/assets/characters/programmer/lv10_idle.png` — "16x16 base sprites" — female (CC0)
  - 원본: https://opengameart.org/sites/default/files/base_female.png
- `src/renderer/assets/characters/programmer/bosses/dragon.png` — "DRAGON" by Mike Hackett (CC0, 1996 QBASIC port, x3 scale)
  - 원본: https://opengameart.org/sites/default/files/DRAGON_by_Mike_Hackett_x3.png
  - 페이지: https://opengameart.org/content/dragon-1

### wizard 테마
- `src/renderer/assets/characters/wizard/lv01_idle.png` — "16x16 Mage" (CC0)
- `src/renderer/assets/characters/wizard/lv05_idle.png` — "16x16 dark mage" (CC0)
- `src/renderer/assets/characters/wizard/lv10_idle.png` — "16x16 dark mage" variant (CC0)
- `src/renderer/assets/characters/wizard/bosses/dragon.png` — "DRAGON" by Mike Hackett (CC0)
- `src/renderer/assets/characters/wizard/bosses/goblin.png` — "Goblin monster" spritesheet 32x32 (CC0)
  - 원본: https://opengameart.org/sites/default/files/spritesheet-goblin-32x32-alpha.png
  - 페이지: https://opengameart.org/content/goblin-monster

### ninja 테마 (부분)
- `src/renderer/assets/characters/ninja/lv01_idle.png` — "16x16 Sprite Ninji" by Yura Zyuzyukin (CC0)
  - 원본: https://opengameart.org/sites/default/files/spritesheet_31.png
  - 페이지: https://opengameart.org/content/16x16-sprite-ninji

### 미배치 (사용자 추가 대기)
- wizard 보스 hydra/behemoth, programmer 보스 hydra/behemoth/goblin
- ninja lv05/lv10/lv20, 모든 보스
- chef/explorer/robot/animal 전 슬롯

미배치 슬롯은 Graphics 폴백으로 자동 동작 (코드 수정 불요).

> **알려진 제약**: 다운로드한 goblin/dragon은 **sprite sheet** (여러 프레임이 한 PNG에). 현재 StageManager는 전체 PNG를 단일 Sprite로 렌더하므로 시각적으로 어색할 수 있다. 정밀 슬라이싱은 향후 폴리시 라운드에서.

---

## AI 생성 자산 (프로그래머 테마 대안)

- **출처**: 사용자가 외부 도구(Stable Diffusion/DALL-E/Midjourney)로 직접 생성
- **프롬프트·시드**: `_workspace/riff-3/asset-spec.md`에 lock
- **시드**: 8421337
- **저작권**: 도구 약관에 따른 사용자 권리

## 폰트
- Inter (https://fonts.google.com/specimen/Inter) — SIL Open Font License 1.1 (시스템 fallback)
- Pretendard (https://github.com/orioncactus/pretendard) — SIL Open Font License 1.1 (시스템 fallback)

본 게임은 폰트를 번들하지 않고 시스템 fallback만 사용 — 별도 라이선스 의무 없음.

## 코드 의존성

`package.json`의 모든 npm 패키지 라이선스는 `npm-license-checker` 등으로 일괄 확인 가능. MIT/Apache-2.0/BSD가 대부분이고 GPL 계열은 없다 (CC-BY-SA viral 문제 없음).
