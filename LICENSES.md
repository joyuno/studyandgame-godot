# Third-Party Asset Licenses

StudyGame 본체 코드는 사용자 작성이다. 본 문서는 게임에 임베드된 외부 자산의 출처와 라이선스를 명시한다.

## 폰트

### Pretendard — by Kil Hyung-jin et al.
- **출처**: https://github.com/orioncactus/pretendard
- **라이선스**: SIL Open Font License 1.1 (https://scripts.sil.org/OFL)
- **사용처**: `assets/fonts/Pretendard-Regular.otf`, `assets/fonts/Pretendard-Bold.otf`
- 임베드 + 재배포 OFL이 허용. 폰트명 변경 시 새 이름 사용 의무 (현재 그대로 유지).

## 캐릭터·보스 스프라이트 — Kenney Platformer Pack (CC0)

전체 캐릭터·보스 그래픽은 **Kenney의 Platformer Pack** 에서 가져왔다.

- **출처**: https://kenney.nl (저자 본인 사이트)
- **다운로드 mirror**: https://github.com/pigdevstudio/godot-sandbox (Godot용 재패키징)
- **라이선스**: CC0 1.0 Universal (https://creativecommons.org/publicdomain/zero/1.0/)
- 인용: *"All assets I make I release as Creative Commons (CC0) which means you can use them without restrictions, even commercially."* — Kenney

### 사용한 파일

**캐릭터 (`assets/characters/aliens/`):**
- `beige.png` — alienBeige_stand
- `blue.png` — alienBlue_stand
- `green.png` — alienGreen_stand
- `pink.png` — alienPink_stand
- `yellow.png` — alienYellow_stand

**보스 (`assets/characters/bosses/`):**
- `ant.png` — ant_01 (Novice 단계 보스)
- `bee.png` — bee_01 (Junior 단계 보스)
- `bat.png` — bat_01 (Senior 단계 보스)
- `blockie.png` — blockie_01 (Legend 단계 보스)
- `eater.png` — eater_01 (예비 — 향후 사용)

## 폐기된 자산 노트

이전 버전에는 OpenGameArt에서 가져온 7테마(programmer/wizard/ninja/chef/animal/robot/explorer) 23 PNG가 포함돼 있었으나, 다음 이유로 전부 교체:

- programmer/lv05·lv10: RPGMaker "naked base" 시트 — 옷·머리 레이어 합성을 전제로 한 베이스라 단독 표시 시 살색 인형으로 보임
- animal/lv01: 실제로는 "Tiny RPG" 광고 스크린샷 (캐릭터 아님)
- robot/lv01: 캐릭터 빌더 템플릿 (마젠타 배경, 다층 합성 필요)
- 보스 dragon/goblin: 거대 픽셀팩 안 좌표 추측 슬라이스로 fragile

새 Kenney 자산은 모두 **단일 캐릭터 완성형 PNG** — 슬라이싱 불필요, 어떤 조합이든 의도대로 보임. 옛 자산 출처는 Riff 7 코밋 히스토리에 보존됨 (joyuno/studyandgame, Electron 버전).
