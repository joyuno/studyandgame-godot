# 문제풀고 강화하자 — Godot 4

학습 퀴즈 + 검 강화 게임. 원래 Electron/React로 만든 [studyandgame](https://github.com/joyuno/studyandgame)의 Godot 4 (GDScript) 포팅에서 출발했지만, **v0.4부터 검 강화 모드로 전환**했습니다 — idle-RPG 컨셉은 폐기.

## 게임 루프

1. 퀴즈를 푼다 → 정답마다 **강화권 +1**
2. 강화권으로 검을 강화 (+0 → +15, Lineage/Maple 풍 확률표 그대로)
3. 검을 시장에서 판다 → **골드 +N²×100 + 50**
4. 골드로 **보호 주문서**(500G)를 사서 +6 이상 등급 하락을 막는다
5. 더 어려운 퀴즈팩 → 더 많은 강화권 → 더 높은 + 검

도메인 로직(weapon · srs · leveling · pack parser)은 원본 Electron 버전과 동일. UI 전체는 네이티브 Godot Control 노드.

## 빠른 시작

### 에디터로 열기 (개발용)

```powershell
# Godot 4.6.2 stable 가 C:\Users\admin\Downloads\all_project\godot\ 에 압축 해제돼 있다고 가정
& "C:\Users\admin\Downloads\all_project\godot\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\admin\Downloads\all_project\study_game_godot"
```

또는 Godot을 그냥 더블클릭 → "Import" → 이 폴더의 `project.godot` 선택.

### 헤드리스 자산 import + 테스트

```powershell
$GODOT = "C:\Users\admin\Downloads\all_project\godot\Godot_v4.6.2-stable_win64.exe"
& $GODOT --headless --import     # 모든 PNG/tres 메타 생성
& $GODOT --headless --script res://tests/test_runner.gd
```

### 스프라이트 재생성 (16검 + 3이펙트)

```powershell
node scripts/gen-sprites.mjs        # 19장 전부
node scripts/gen-sprites.mjs sword_07  # 한 장만 시드 바꿔 재시도
node scripts/strip-bg.mjs           # 흰 배경 → 투명
```

Pollinations.ai 무료 티어 (API 키 없음). 시드 결정성 — `gen-sprites.mjs`의 seed 값이 그대로 결과를 재현.

### 배포 빌드

Godot 에디터 → Project → Export → Windows Desktop preset → Export.

## 디렉토리 구조

```
study_game_godot/
├── project.godot              엔진 설정 + autoload 등록
├── scenes/                    .tscn (Control + script attach만)
│   ├── Home.tscn              메인 — 퀴즈 선택 + 검 프리뷰 + 강화소/시장 nav
│   ├── Quiz.tscn              풀이 화면 — 정답 시 강화권 +1
│   ├── Forge.tscn             강화소 — 검 강화 + 주문서 토글
│   ├── Market.tscn            시장 — 검 되팔기 + 주문서 구매
│   └── SwordDisplay.tscn      검 + 글로우 링 + 이펙트 오버레이 컴포넌트
├── scripts/
│   ├── autoload/              전역 스토어 (Zustand 대체)
│   │   ├── progress_store.gd  user://progress.json atomic save · 골드 · 강화권 · 주문서
│   │   ├── pack_store.gd      현재 퀴즈 + 콤보 — 정답 시 강화권 지급
│   │   ├── sword_store.gd     +N → 스프라이트 · 등급 · 판매가
│   │   └── theme_setup.gd     Pretendard 글로벌 Theme
│   ├── domain/                순수 함수 — 헤드리스 테스트 가능
│   │   ├── weapon.gd          강화 확률표 · 보호 구간 · 데미지 배수
│   │   ├── srs.gd             Anki 6단계 간격
│   │   ├── leveling.gd        XP→level · combo×
│   │   └── pack_parser.gd     JSON/YAML 스키마 검증 + yaml_pack_parser.gd
│   ├── ui/                    .tscn 에 attach 되는 스크립트
│   │   ├── home.gd · quiz.gd · forge.gd · market.gd · sword_display.gd
│   ├── gen-sprites.mjs        Pollinations.ai Flux 호출 (16검 + 3FX + legacy 10캐릭터)
│   └── strip-bg.mjs           sharp + 2-pass flood fill 으로 흰 배경 투명화
├── assets/
│   ├── swords/                AI 생성 16 검 + 3 이펙트
│   ├── characters/            v0.3 idle-RPG 캐릭터·보스 (현재 모드에서는 미사용)
│   └── fonts/                 Pretendard Regular/Bold (OFL)
├── data/quizzes/              샘플 .json / .yml 퀴즈 팩
├── tests/test_runner.gd       single-file 헤드리스 테스트
└── .claude/skills/godot-api/  godogen에서 발췌한 Godot 4 API
```

## 퀴즈 팩 포맷

JSON / YAML 둘 다 지원. 스키마는 Electron 버전과 1:1 동일.

```yaml
meta:
  title: ClickHouse MergeTree
  version: 0.1.0
  default_time: 25
  tags: [clickhouse, mergetree]

questions:
  - type: mcq
    q: 'MergeTree 엔진이 part 내부 정렬에 사용하는 기준은?'
    choices:
      - 'Hash sort'
      - 'ORDER BY로 지정된 primary key'
      - 'B+Tree 인덱스'
      - '정렬 없음'
    answer: 1
    explanation: 'MergeTree는 part 내부를 primary key 기준으로 정렬해 저장한다.'

  - type: ox
    q: 'MergeTree part는 background에서 자동 merge된다.'
    answer: true
    explanation: '공식 docs — Parts are merged in background'
```

### 독해(reading) 문항 — `passage` + `reward` + `time`

독해는 새 type이 아니라 **`mcq` + 선택 필드**로 표현한다. `passage`(지문)는 문제 위에
스크롤 패널로 표시되고, 정답은 100% 지문에서 도출되어야 한다. 한 문제에 시간이 더 드는
만큼 `time`(초)·`reward`(강화권 배수, 기본 1)로 보상을 비례시킨다.

```yaml
  - type: mcq
    passage: |
      在宅勤務が広まってから、多くの企業で働き方が大きく変わった。…
      専門家は、各自が意識して休憩を取り、定期的に同僚と連絡を取り合う…
    q: '専門家は在宅勤務を成功させるために何が必要だと述べているか。'
    choices: ['制度を導入しさえすればよい', '通勤を完全になくすこと',
              '休憩を取り、同僚と連絡を取り合う仕組みを整えること', '一人で集中し続けること']
    answer: 2
    explanation: '本文に「各自が意識して休憩を取り…仕組みを整えることが欠かせない」とある。'
    time: 90        # 短文 60 / 中文 90 / 長文·主張 120 (JLPT 평균 소요시간)
    reward: 3       # 短文 2 / 中文·長文 3
```

샘플: [`data/quizzes/jlpt-n2-reading.yml`](data/quizzes/jlpt-n2-reading.yml) (원본 지문 → `data/sources/`).

[workbook 플러그인](https://github.com/joyuno/workbook)으로 자료를 YAML 퀴즈로 변환 → 게임에 드래그 앤 드롭.

## 진행 저장

`user://progress.json` (Windows: `%APPDATA%\Godot\app_userdata\StudyGame (Godot port)\progress.json`)에 atomic write. 필드:

- `weapon.{level, attempts, failures, highestEver}` — 현재 검 상태
- `materials` — 강화권 보유 수 (legacy 이름 유지; 마이그레이션 호환)
- `gold` — 골드
- `protectionScrolls` — 보유 보호 주문서 수
- `wrongNote`, `sessions`, `totalCorrect`, `totalXP` — 퀴즈 학습 통계

## 테스트

```powershell
& $GODOT --headless --script res://tests/test_runner.gd
```

`tests/test_runner.gd` 단일 파일이 weapon · srs · leveling · pack_parser · yaml_pack_parser · sword_store 케이스를 검증.

## 라이선스

MIT — [LICENSE](LICENSE). 스프라이트 출처는 [LICENSES.md](LICENSES.md).

## 관련

- **[joyuno/studyandgame](https://github.com/joyuno/studyandgame)** — Electron 원본 (idle-RPG)
- **[joyuno/workbook](https://github.com/joyuno/workbook)** — md/pdf/docx → YAML 퀴즈 변환 Claude Code 플러그인
- **[htdt/godogen](https://github.com/htdt/godogen)** — godot-api 스킬 출처
