# Ninja Adventure Theme — 사용자 가이드

> **라이선스**: CC0 (Creative Commons Zero). 상업적 사용 OK, 크레딧 의무 없음 (그래도 적어주면 좋음).
>
> **출처**: pixel-boy의 Ninja Adventure Asset Pack — https://pixel-boy.itch.io/ninja-adventure-asset-pack
>
> **분량**: 89 MB 전체 팩 (50+ 캐릭터, 9 보스, 30+ 몬스터, SFX, BGM). 게임은 일부만 사용한다.

## 빠른 시작 (5분)

### 1단계: 다운로드
1. https://pixel-boy.itch.io/ninja-adventure-asset-pack 접속
2. "Download" 클릭 (가격 0원 입력 가능)
3. zip 파일 받기 (`Ninja_Adventure_Asset_Pack_*.zip`)

### 2단계: 압축 해제
zip을 임시 폴더에 풀면 다음과 같은 구조가 보인다 (실제 경로는 팩 버전에 따라 약간 다를 수 있음):
```
NinjaAdventureAssetPack/
├── Actor/
│   ├── Characters/
│   │   ├── Villager1/SeparateAnim/Idle.png  ← lv01_idle 후보
│   │   ├── NinjaGreen/SeparateAnim/Idle.png ← lv05_idle 후보
│   │   ├── NinjaBlue/SeparateAnim/Idle.png  ← lv10_idle 후보
│   │   └── NinjaRed/SeparateAnim/Idle.png   ← lv20_idle 후보 (또는 다른 special)
│   └── Monsters/
│       ├── Goblin/...
│       ├── Dragon/...
│       └── ...
```

### 3단계: 본 폴더에 복사

이 README가 있는 폴더(`src/renderer/assets/characters/ninja/`)에 정확한 파일명으로 배치한다:

| 본 폴더 경로 | Ninja Adventure 팩 내부 추천 |
|--------------|------------------------------|
| `lv01_idle.png` | `Actor/Characters/Villager1/SeparateAnim/Idle.png` (학원생) |
| `lv05_idle.png` | `Actor/Characters/NinjaGreen/SeparateAnim/Idle.png` (주니어) |
| `lv10_idle.png` | `Actor/Characters/NinjaBlue/SeparateAnim/Idle.png` (시니어) |
| `lv20_idle.png` | `Actor/Characters/NinjaRed/SeparateAnim/Idle.png` (전설) |
| `bosses/goblin.png` | `Actor/Monsters/Goblin/...Idle.png` |
| `bosses/dragon.png` | `Actor/Monsters/Dragon/...Idle.png` |
| `bosses/hydra.png` | `Actor/Monsters/Hydra/...Idle.png` 또는 multi-head 후보 |
| `bosses/behemoth.png` | `Actor/Monsters/Golem/...Idle.png` 또는 가장 큰 보스 |

> 파일명만 정확하면 어떤 sprite를 골라도 OK. 본인 취향대로.

### 4단계: 게임 재시작

```powershell
npm run dev
```

Vite가 `import.meta.glob`로 자동 픽업. 홈 화면 테마 스위처에서 "Ninja Adventure"를 선택하면 즉시 적용.

PNG가 없거나 일부만 있으면 누락된 부분만 Graphics 폴백.

## 안내

- **파일을 git에 커밋할지 결정**: CC0이라 재배포 가능하지만 89MB 원본을 그대로 커밋하면 리포 크기 폭증. **선별한 8장만 커밋 권장** (각 PNG 수 KB).
- **이 README는 git에 커밋**, PNG는 `.gitignore`에 추가하거나 선별 커밋.
- **공식 권장 attribution** (선택):
  ```
  Ninja Adventure Asset Pack — © pixel-boy, licensed under CC0.
  https://pixel-boy.itch.io/ninja-adventure-asset-pack
  ```

## 다른 테마 추가는?

`src/renderer/effects/themes/{theme-name}.ts` 작성 + `themes/index.ts` REGISTRY에 등록.
`_workspace/riff-3.5/asset-research.md` §2에 7개 테마 후보 URL이 나와있다.
