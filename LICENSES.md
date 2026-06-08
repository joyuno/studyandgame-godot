# Third-Party Asset Licenses

## 폰트

### Pretendard — by Kil Hyung-jin et al.
- **출처**: https://github.com/orioncactus/pretendard
- **라이선스**: SIL Open Font License 1.1
- **사용처**: `assets/fonts/Pretendard-{Regular,Bold}.otf`

## 검·이펙트 스프라이트 — AI 생성 (Pollinations.ai · Flux)

문제풀고 강화하자 (검 강화 모드)의 전체 아트는 **Pollinations.ai의 Flux 모델**로 생성됨.

- **서비스**: https://pollinations.ai (무료, API 키 없음)
- **모델**: Flux (Stable Diffusion 계열 오픈 모델)
- **저작권**: Pollinations 약관상 생성물에 별도 권리 주장 없음. 상업·비상업 사용 자유.
- **재현 방법**: `scripts/gen-sprites.mjs` 안에 각 sprite의 prompt + seed가 명시되어 있어 똑같이 재생성 가능 (시드 결정성). 사후 처리는 `scripts/strip-bg.mjs` (sharp + flood fill).

### 검 (`assets/swords/sword_*.png`)

| 파일 | Seed | 등급 | Concept |
|------|------|------|---------|
| `sword_00.png` | 1100 | 철검 | 녹슨 단순 철검 |
| `sword_01.png` | 1115 | 철검 | 기본 철검 |
| `sword_02.png` | 1130 | 철검 | 연마된 철검 |
| `sword_03.png` | 1145 | 강철검 | 은빛 강철 롱소드 |
| `sword_04.png` | 1160 | 강철검 | 루비 박힌 강철검 |
| `sword_05.png` | 1175 | 강철검 | 백색 오라 강철검 |
| `sword_06.png` | 1190 | 미스릴검 | 청록 미스릴 |
| `sword_07.png` | 1205 | 미스릴검 | 사파이어 미스릴 |
| `sword_08.png` | 1220 | 미스릴검 | 룬각 미스릴 |
| `sword_09.png` | 1235 | 황금검 | 황금 도신 |
| `sword_10.png` | 1250 | 황금검 | 보석 박힌 황금검 |
| `sword_11.png` | 1265 | 황금검 | 화염 황금검 |
| `sword_12.png` | 1280 | 전설검 | 백금 + 천사 날개 |
| `sword_13.png` | 1295 | 전설검 | 프리즘 신검 |
| `sword_14.png` | 1310 | 전설검 | 번개 + 드래곤 자루 |
| `sword_15.png` | 1325 | 전설검 | 우주·은하 궁극 검 |

### 이펙트 (`assets/swords/fx_*.png`)

| 파일 | Seed | 용도 |
|------|------|------|
| `fx_success.png` | 2100 | 강화 성공 — 별빛 폭발 |
| `fx_fail.png`    | 2115 | 등급 유지 실패 — 균열 |
| `fx_destroy.png` | 2130 | 등급 하락 — 산산조각 |

## 폐기된 자산 트랙 (idle-RPG 모드)

- v0.4 (현재 — 검강화하기): 16검 + 3이펙트로 전환. 직업·보스 idle-RPG 컨셉 폐기
- v0.3: AI 생성 5직업 + 5보스 (캐릭터 PNG는 `assets/characters/`에 보존됨 — 이전 모드 재현용)
- v0.2 (Kenney pack): 5색 alien + 5 enemies — 단일 PNG지만 학습 도메인 정체성을 잃음
- v0.1 (Electron 포팅 직후): OpenGameArt CC0 시트 23장

이전 자산 출처·라이선스는 git 히스토리에 보존됨 (`joyuno/studyandgame-godot` 커밋 트리).

## Icons
- Lucide (https://lucide.dev) — ISC License. UI / 아이템 아이콘 (assets/icons/).
