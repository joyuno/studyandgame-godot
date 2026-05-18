# CLAUDE.md — StudyGame (Godot port) 작업 규율

이 파일은 이 repo 안에서 Claude Code가 따르는 프로젝트별 지침이다. 전역 `~/.claude/CLAUDE.md`의 보편 규칙(Karpathy 4원칙 + Superpowers + OMC) 위에 다음을 덧붙임.

## 0. 세션 시작 시
1. 이 파일을 먼저 읽는다.
2. `.claude/skills/godot-api/SKILL.md` 로딩 — Godot 4 API 답변 시 인용 우선.
3. 도메인 변경이 있으면 `tests/test_runner.gd` 케이스도 같이 갱신.

## 1. 언어·엔진 결정 (변경 금지)
- **Godot 4.6.2 stable** (GDScript). C# 추가 도입 금지 — .NET SDK 부담 없이 가는 게 핵심 결정.
- **JSON 퀴즈 포맷** (YAML 파서 번들 금지). YAML→JSON 변환은 외부에서 (workbook 플러그인 + node/python 한 줄).
- **렌더링**: Control 노드 + TextureRect + AtlasTexture. Sprite2D / Node2D 캔버스 패턴은 캐릭터 슬롯에만 한정.
- **상태 관리**: autoload(`ProgressStore`, `PackStore`, `ThemeStore`) + signal. 직접 노드 참조 → 양방향 결합 금지.

## 2. 디렉토리 컨벤션
- `scripts/domain/`: **순수 함수만.** Node·Scene 참조 금지. 헤드리스 테스트 100% 가능해야 함.
- `scripts/autoload/`: 글로벌 상태. 항상 atomic write (`_persist()` 패턴).
- `scripts/ui/`: `.tscn` 에 attach. 코드-우선 UI — `_ready()` 에서 노드 빌드.
- `scenes/*.tscn`: 골조만 (Control + 스크립트 부착). 디자인은 GDScript에서.
- `assets/`: PNG는 raw. 슬라이싱은 `*_frame.tres` AtlasTexture 로.
- `tests/test_runner.gd`: 단일 파일. 외부 의존 0.

## 3. 자산 정책
- 신규 PNG 추가 시:
  1. CC0 또는 CC-BY 만. `LICENSES.md` 갱신 의무.
  2. sprite sheet면 `*_frame.tres` 도 같이 작성.
  3. 추가 후 `--headless --import` 한 번 돌려 `.import` 메타 생성.
- 절대 금지: `src/renderer/assets/...` 같은 Electron-스타일 경로. `res://assets/characters/{theme}/...` 로 통일.

## 4. 코드 스타일
- GDScript 4: `class_name`, `static func`, `Array[T]` 타입 힌트 모두 사용.
- snake_case (Godot 컨벤션). camelCase 금지.
- `match` 문 선호 (긴 if/else 체인 대신).
- signal 이름은 과거형 (`progress_changed`, `enhance_result`).
- print/push_warning/push_error 적극 활용 — 디버그용 로그는 명시적.

## 5. 테스트
- 도메인 변경 시 `tests/test_runner.gd` 케이스 같이 갱신.
- 실행: `godot --headless --script res://tests/test_runner.gd`.
- 56/56 통과를 기준선으로 유지. 떨어지면 푸시 금지.

## 6. UI 변경 시
- 코드-우선이라 `.tscn` 파일은 거의 안 건드림. 노드 구조 바꾸려면 GDScript의 `_build_layout()` 함수 수정.
- 새 화면 추가 시: `scenes/{Name}.tscn` (3줄짜리 골조) + `scripts/ui/{name}.gd`.
- 라우팅: `get_tree().change_scene_to_file("res://scenes/X.tscn")`.

## 7. 데이터 마이그레이션
- `ProgressStore._default_progress()` 의 키는 Electron 원본 `defaultProgressV1()` 와 1:1 동일하게 유지.
- 새 필드 추가 시 `_load_from_disk()` 의 shallow merge 패턴이 자동 처리 — 옛 save도 안전.
- `schemaVersion` 올릴 일 생기면 별도 마이그레이션 함수 필수.

## 8. 빌드·배포
- `godot --export-release "Windows Desktop" exports/StudyGame.exe` (preset 먼저 에디터에서 설정).
- 배포 산출물은 `.gitignore` 에 들어있음 — repo에 안 올림.
- 새 export preset 추가 시 `export_presets.cfg` 도 같이 커밋 (단, 인증서·키 같은 secret 필드는 비워서).

## 9. 항체 (Electron 원본에서 가져온 학습)
- `AB-010` (한국어 quoting): YAML 입력 단계의 문제라 Godot 포트에서는 무관 — JSON으로 우회.
- `AB-011` (PIXI CSP worker-src): Godot 게임 엔진이라 무관.
- `AB-005` (Zustand derived selector 무한 루프): autoload + signal 패턴은 derived 반환 자체가 없어 무관.

## 10. 외부 의존 정책
- npm/python 패키지 신규 도입 금지 (godogen 외부 파이프라인 트랙은 별도).
- GDScript 라이브러리(addons) 도입 시 사용자 확인 필수. 한 줄 작성으로 끝나는 일이라면 도입하지 말 것.

## 11. README 갱신
- 새 도메인 모듈 추가 시 README "디렉토리 구조" 표 갱신.
- 퀴즈 포맷 변경 시 README 예시 + workbook README도 같이 갱신 (다른 repo지만 페어).
