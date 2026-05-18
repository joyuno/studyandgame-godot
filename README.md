# StudyGame — Godot 4 port

방치형 + 강화 + 가차 학습 퀴즈 게임. 원래 Electron/React로 만든 [studyandgame](https://github.com/joyuno/studyandgame) 의 Godot 4 (GDScript) 포팅입니다. 도메인 로직(weapon · srs · leveling · pack parser)을 그대로 옮기고 UI 만 네이티브 Godot Control 노드로 다시 구성.

## 왜 Godot으로 다시 만들었나

원본 Electron 버전은 잘 동작하지만:
- 캐릭터·이펙트가 PixiJS + CSP 트릭(blob: worker 허용)에 의존 — 환경 마찰
- 빌드 산출물이 100MB+ (.exe NSIS) — 가벼운 게임치곤 무거움
- 자산 sprite sheet 슬라이싱이 휴리스틱 의존이라 들쭉날쭉

Godot은:
- `AtlasTexture .tres`로 sprite 슬라이싱이 명시적 + 재사용 가능
- 빌드가 압축 시 ~30MB
- 게임 엔진이라 애니메이션·트윈·신호가 1급 시민
- 회사에서 같은 .yml/.json 자산을 그대로 재활용

## 빠른 시작

### 에디터로 열기 (개발용)

```powershell
# Godot 4.6.2 stable 가 C:\Users\admin\Downloads\all_project\godot\ 에 압축 해제돼 있다고 가정
& "C:\Users\admin\Downloads\all_project\godot\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\admin\Downloads\all_project\study_game_godot"
```

또는 Godot을 그냥 더블클릭 → "Import" → 이 폴더의 `project.godot` 선택.

### 헤드리스로 자산 import + 테스트

```powershell
$GODOT = "C:\Users\admin\Downloads\all_project\godot\Godot_v4.6.2-stable_win64.exe"
& $GODOT --headless --import     # 모든 PNG/tres 메타 생성
& $GODOT --headless --script res://tests/test_runner.gd
# → "--- 56 passed, 0 failed ---"
```

### 배포 빌드

Godot 에디터 → Project → Export → Add Windows Desktop preset → Export. NSIS 같은 외부 도구 불필요.

## 디렉토리 구조

```
study_game_godot/
├── project.godot              엔진 설정 + autoload 등록
├── scenes/                    .tscn 파일 (Control 노드 + script 부착만)
│   ├── Home.tscn              메인 메뉴
│   ├── Quiz.tscn              풀이 화면
│   ├── Enhance.tscn           강화소
│   └── CharacterDisplay.tscn  캐릭터/보스 슬롯
├── scripts/
│   ├── autoload/              전역 스토어 (Zustand 대체)
│   │   ├── progress_store.gd  user://progress.json atomic save
│   │   ├── pack_store.gd      현재 퀴즈 + 콤보 + 보스 카운트
│   │   └── theme_store.gd     테마 레지스트리 → Texture2D 해석
│   ├── domain/                순수 함수 — 헤드리스 테스트 가능
│   │   ├── weapon.gd          강화 확률표 · 보호 구간 · 데미지 배수
│   │   ├── srs.gd             Anki 6단계 간격
│   │   ├── leveling.gd        XP→level · combo×
│   │   └── pack_parser.gd     JSON 스키마 검증 (Electron의 ERR_* 코드 동일)
│   └── ui/                    .tscn 에 attach 되는 스크립트
│       ├── home.gd · quiz.gd · enhance.gd · character_display.gd
├── assets/characters/         OpenGameArt CC0 PNG 23장 (원본 studyandgame에서 복사)
│   ├── programmer/, wizard/, ninja/, chef/, animal/, explorer/, robot/
│   └── */**/*_frame.tres      AtlasTexture (sprite sheet 첫 프레임 슬라이스)
├── data/quizzes/              샘플 .json 퀴즈 팩
│   ├── clickhouse-basics.json
│   └── otel-basics.json
├── tests/test_runner.gd       single-file 헤드리스 테스트 (assert 기반)
└── .claude/skills/godot-api/  godogen에서 발췌한 Godot 4 API 큐레이션
```

## 퀴즈 팩 포맷

YAML 대신 **JSON**을 씁니다 (Godot에 YAML 파서 내장 X, 외부 파서 가져오면 무게+버그↑). 스키마는 Electron 버전과 1:1 동일.

```json
{
  "meta": {
    "title": "ClickHouse MergeTree",
    "version": "0.1.0",
    "default_time": 25,
    "set_time": 100,
    "tags": ["clickhouse", "mergetree"]
  },
  "questions": [
    {
      "type": "mcq",
      "q": "MergeTree 엔진이 part 내부 정렬에 사용하는 기준은?",
      "choices": [
        "Hash sort",
        "ORDER BY로 지정된 primary key",
        "B+Tree 인덱스",
        "정렬 없음"
      ],
      "answer": 1,
      "explanation": "MergeTree는 part 내부를 primary key 기준으로 정렬해 저장한다."
    },
    {
      "type": "ox",
      "q": "MergeTree part는 background에서 자동 merge된다.",
      "answer": true,
      "explanation": "공식 docs — \"Parts are merged in background\""
    }
  ]
}
```

[workbook 플러그인](https://github.com/joyuno/workbook)으로 YAML을 생성한 뒤 JSON으로 변환:

```bash
# Node + js-yaml
node -e "console.log(JSON.stringify(require('js-yaml').load(require('fs').readFileSync(process.argv[1],'utf-8')),null,2))" input.yml > input.json

# 또는 Python + PyYAML
python -c "import yaml,json,sys; print(json.dumps(yaml.safe_load(open(sys.argv[1])),indent=2,ensure_ascii=False))" input.yml > input.json
```

## 진행 저장

`user://progress.json` (Windows에서는 `%APPDATA%\Godot\app_userdata\StudyGame (Godot port)\progress.json`)에 atomic write. Electron 버전의 `progress.json`과 같은 키를 사용하므로 향후 마이그레이션 스크립트 한 번이면 양쪽 호환.

## 테스트

```powershell
& $GODOT --headless --script res://tests/test_runner.gd
```

`tests/test_runner.gd` 단일 파일이 weapon · srs · leveling · pack_parser 56개 케이스 검증. GUT 같은 외부 프레임워크 안 씀 — 의존 0.

## Claude Code로 작업할 때

`.claude/skills/godot-api/` 에 godogen 에서 발췌한 Godot 4 API 큐레이션이 들어있습니다. Claude가 신규 노드/메서드를 쓸 때 자동으로 참조합니다.

추가 godot-api 풀 docs는 godogen의 `tools/ensure_doc_api.sh` 를 받아 실행하면 생성됨 (Linux/macOS 권장, 선택사항).

## 차이 — Electron 원본과 비교

| 항목 | Electron 원본 | Godot 포트 |
|------|---------------|-----------|
| 렌더링 | React + Tailwind + PixiJS | Godot Control + Sprite + AtlasTexture |
| 상태 관리 | Zustand store | autoload 노드 + signal |
| Sprite 시트 | sliceFirstFrame 휴리스틱 (들쭉날쭉) | `.tres` AtlasTexture (명시적) |
| 퀴즈 포맷 | YAML | JSON |
| 저장 | `userData/progress.json` atomic | `user://progress.json` atomic |
| 빌드 산출물 | NSIS .exe ~100MB | Godot export ~30MB |
| CSP | 엄격 (`worker-src` 등 신경) | 게임 엔진이라 무관 |
| 테스트 | Vitest 101 + Playwright 3 | 헤드리스 GDScript 56 |

도메인 로직은 100% 동등 (테스트 케이스도 같은 시나리오). UI/렌더링만 네이티브로.

## 라이선스

MIT — [LICENSE](LICENSE).

캐릭터 자산은 CC0 / CC-BY 혼합 — [LICENSES.md](LICENSES.md).

## 관련

- **[joyuno/studyandgame](https://github.com/joyuno/studyandgame)** — Electron 원본
- **[joyuno/workbook](https://github.com/joyuno/workbook)** — md/pdf/docx 자료 → YAML 퀴즈 변환 Claude Code 플러그인
- **[htdt/godogen](https://github.com/htdt/godogen)** — godot-api 스킬 출처
