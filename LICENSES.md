# Third-Party Asset Licenses

## 폰트

### Pretendard — by Kil Hyung-jin et al.
- **출처**: https://github.com/orioncactus/pretendard
- **라이선스**: SIL Open Font License 1.1
- **사용처**: `assets/fonts/Pretendard-{Regular,Bold}.otf`

## 캐릭터·보스 스프라이트 — AI 생성 (Pollinations.ai · Flux)

전체 캐릭터·보스 아트는 **Pollinations.ai의 Flux 모델**로 생성됨.

- **서비스**: https://pollinations.ai (무료, API 키 없음)
- **모델**: Flux (Stable Diffusion 계열 오픈 모델)
- **저작권**: Pollinations 약관상 생성물에 별도 권리 주장 없음. 상업·비상업 사용 자유.
- **재현 방법**: `scripts/gen-sprites.mjs` 안에 각 sprite의 prompt + seed가 명시되어 있어 똑같이 재생성 가능 (시드 결정성). 사후 처리는 `scripts/strip-bg.mjs` (sharp + flood fill).

### 캐릭터 (`assets/characters/characters/`)

| 파일 | Seed | Concept |
|------|------|---------|
| `programmer.png` | 142 | 안경 + 노트북 든 캐주얼 개발자 |
| `wizard.png`     | 271 | 보라 로브 + 마법 지팡이 (gandalf 풍) |
| `ninja.png`      | 308 | 검은 옷 + 카타나, 다이나믹 포즈 |
| `chef.png`       | 415 | 흰 토크 + 앞치마 + 냄비 |
| `explorer.png`   | 533 | 사파리 모자 + 베스트 + 지도 |

### 보스 (`assets/characters/bosses/`)

| 파일 | Seed | Concept |
|------|------|---------|
| `bug_goblin.png`      | 612 | 안테나 단 녹색 컴퓨터 버그 도깨비 — Novice 단계 |
| `null_dragon.png`     | 749 | 불 뿜는 빨간 드래곤 — Junior 단계 |
| `race_hydra.png`      | 856 | 3머리 청록 코브라 (Race Condition) — Senior 단계 |
| `tech_debt_giant.png` | 967 | 부서지는 보라 돌 거인 (Tech Debt) — Legend 단계 |
| `stack_ghost.png`     | 178 | 파란 유령 — 예비 |

## 폐기된 자산 트랙

- v0.1 (Electron 포팅 직후): OpenGameArt CC0 시트 23장 — 대부분 "naked base" 합성 키트라 단독 표시 불가
- v0.2 (Kenney pack): 5색 alien + 5 enemies — 단일 PNG로 정상이긴 했으나 학습 도메인 정체성을 잃음 (alien 색만 다름)
- v0.3 (현재): AI 생성 5직업 + 4보스 — study_game 원본의 직업·보스 컨셉 복원

이전 자산 출처·라이선스는 git 히스토리에 보존됨 (`joyuno/studyandgame-godot` 커밋 트리).
