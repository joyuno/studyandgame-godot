# Character Theme Assets

이 폴더는 캐릭터 테마별 PNG 스프라이트를 담는다. 게임은 빈 폴더도 정상 작동한다 (Graphics 폴백).

## 폴더 구조

```
assets/characters/
├── README.md                 ← 이 파일
├── ninja/                    ← Ninja Adventure (CC0) 테마
│   ├── README.md             ← 사용자 가이드 (다운로드·추출 절차)
│   ├── lv01_idle.png         ← 학원생 (novice)
│   ├── lv05_idle.png         ← 주니어 (junior)
│   ├── lv10_idle.png         ← 시니어 (senior)
│   ├── lv20_idle.png         ← 전설 (legend)
│   └── bosses/
│       ├── goblin.png        ← Bug Goblin (novice)
│       ├── dragon.png        ← Null Pointer Dragon (junior)
│       ├── hydra.png         ← Race Condition Hydra (senior)
│       └── behemoth.png      ← Tech Debt Behemoth (legend)
├── programmer/               ← AI 생성 (사용자) — _workspace/riff-3/asset-spec.md 참조
└── wizard/, chef/, ...       ← 추후 테마 (선택)
```

## 명명 규칙

- `lv{NN}_idle.png` — 캐릭터 4단계 (`lv01`, `lv05`, `lv10`, `lv20` 정확히)
- `bosses/{slot}.png` — 4 보스 슬롯 (`goblin`, `dragon`, `hydra`, `behemoth`)

## 파일 형식

- PNG, 16×16 또는 32×32 권장 (PIXI에서 nearest-neighbor로 화면 크기에 맞춰 스케일)
- 투명 배경 필수
- 1MB 이하

## 자동 픽업 메커니즘

`src/renderer/effects/themes/{theme}.ts`가 Vite `import.meta.glob`로 PNG를 빌드 시점에 발견한다.
파일을 추가/제거한 뒤 `npm run dev` 재시작하면 즉시 반영.

## 라이선스 추적

각 테마 폴더의 `CREDITS.txt`(있다면) 또는 프로젝트 루트 `LICENSES.md`에 출처 명시 의무.
