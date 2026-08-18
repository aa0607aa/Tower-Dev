# CHANGELOG — 「탑」

형식은 Keep a Changelog를 느슨하게 따른다. 확정된 변경만 기록한다.

## [Unreleased]

### Added

- **PHASE 1 — 이동/카메라 (완료, `PLAYTESTED`).**
  - `scripts/player/movement.gd` — 이동 계산을 **노드 없는 순수 함수**로 분리해
    프레임 독립성·대각 정규화를 물리 없이 headless로 검증 가능하게 했다.
  - `scripts/player/player.gd` · `scenes/player/Player.tscn` — `CharacterBody2D` 8방향 연속 이동,
    Camera2D(드래그 여백 `0.2` · smoothing `10.0`).
  - `scenes/world/TestRoom.tscn` — 960×640 테스트 방 + 안쪽 장애물 3개.
    **canon 지형이 아니며 PHASE 2에서 `data/floors/floor1_fixed/` 로더로 교체한다** (`FLR-001`).
  - `project.godot` — `move_left/right/up/down` (WASD + 방향키, physical_keycode).
  - **자체 테스트 러너** (`D-015`) — `tests/runner.gd`(단위) + `tests/integration_runner.gd`(물리 충돌).
    러너는 발견/실행/집계/종료 코드만 담당하고, 테스트 본문은 프레임워크 중립으로 유지한다.
    단위 17단언 · 통합 10단언 전부 통과.
  - `tools/run.ps1` — Godot 실행 파일을 자동 탐색하는 실행/테스트 헬퍼.
  - 확정 DESIGN 수치: `BASE_SPEED = 160.0`(**민첩 10 기준선**, `CHR-003`).
    `CBT-009`상 속도는 성장으로 빨라지므로 기준선을 높이면 성장 여지가 사라진다.
    PHASE 6에서 민첩 보정과 함께 재확정한다.

### Fixed (PHASE 1)

- 카메라가 짧은 왕복 이동에서 헤엄치던 문제 — 여백 없이 position smoothing만 쓰면
  카메라가 상시 추적하며 방향 전환을 반복한다. **드래그 여백(deadzone)** 을 추가해
  짧은 이동이 여백 안에서 끝나도록 했다. 오너 PLAYTEST로 확정.
- 통합 테스트가 **통과하지만 검증하지 않던** 문제 — 오른쪽 벽(x=950) 케이스가 안쪽 블록(x=608)에
  막혀 x=598에서 멈췄는데 `x <= 950`이 참이라 통과했다. 각 케이스에 "목표에 실제로 도달했는지"
  단언을 추가하고 출발점을 장애물 없는 경로로 바꿨다.
- 테스트 러너 오탐 — 헬퍼 `test_case.gd`가 `test_*.gd` 패턴에 걸려 테스트로 오인됐다.
  `tests/lib/`로 옮겨 구조적으로 재발하지 않게 했다.

### Added
- 협업 프로토콜 v1.0 (`COLLABORATION_PROTOCOL.md`) — 능력/환경 기준 역할표, Canon 충돌 에스컬레이션,
  WORK REPORT 핸드오프, PHASE→티켓→타당성→확정 루프, IMPLEMENTED/VERIFIED/PLAYTESTED 3단계.
- 통합 개발 가이드라인 v2.0 (`docs/DEVELOPMENT_GUIDE.md`) — 설정서 v1.1 정합화, PHASE 0~11 로드맵.
- 결정 이력 (`DECISIONS.md`) — D-001~D-015 Resolved, TBD 목록.
- 현재 상태(`CURRENT_STATE.md`) / 변경 이력(`CHANGELOG.md`) / README / Godot `.gitignore` 스캐폴딩.
- 월 단위 작업 로그 `docs/log/` — 요청·작업·근거·다음 AI 인계·오너 결정 필요·산출물을 시계열 기록.

- **PHASE 0 — 프로젝트 뼈대**
  - `project.godot` (Godot 4.7.1 stable, GL Compatibility, nearest 텍스처 필터, 1280×720).
  - 최소 실행 씬: `scenes/boot/Boot.tscn` → `scenes/world/Main.tscn`.
  - `scripts/core/game_log.gd` autoload.
  - `data/canon/canon.gd` — Resolved 상수만, TBD 수치 없음.
  - 개발 가이드 §6 폴더 구조, 코딩/테스트/스타일 문서.

- **세계관 canon 원본** `docs/SETTING_BIBLE_v1.1.docx` + AI 검수용 기계 변환 사본
  `docs/SETTING_BIBLE_v1.1.md` (직접 편집 금지, 원본 우선).
- `tools/docx_to_md.ps1` — 설정서 docx→md 변환 및 문단 누락 자기검증.
- **Canon 색인 체계** (`docs/canon/`) — 141개 ID / 15도메인. ID는 재사용하지 않고,
  내용 중복을 제거한 항목은 포인터로 유지한다.
- `docs/BACKLOG.md` — B-001~B-006.
- `docs/DATAMINING_POLICY.md` — D-012 데이터 마이닝 정책 근거.
- **D-013** — 설정서에 없던 성장 규칙(레벨당 1포인트, 레벨/XP 초기화)을 오너 결정으로 추적.
- **D-014** — NPC 시뮬레이션 LOD. 거리·중요도에 따라 갱신 빈도를 낮추되 엔진 시뮬레이션과 AI 호출 예산을 분리.
- **D-015** — PHASE 1부터 자동 테스트 러너를 **자체 `SceneTree` 스크립트**로 사용.
  테스트 본문은 순수 함수 + 작은 assertion helper 중심으로 프레임워크 중립 유지.
  GUT은 fixture/mock/비동기/리포팅 등으로 자체 러너 유지비가 실제로 커질 때 재검토.
- `TEST_CHECKLIST G-7` — **NPC LOD 불변성** 회귀 테스트. 동일 seed/논리 시간에서 LOD 전환 시점이 달라도
  NPC Canon 상태와 외부 사건 로그가 동일해야 한다.

### Changed
- `docs/CANON_NOTES.md` 내용을 `docs/canon/`으로 통합하고 포인터만 유지.
- D-012 데이터 마이닝 정책: Tier 1·2 채택, 1층 지형 은닉 불가 전제 확정, Tier 3은 B-001로 보류.
- B-004 자동 테스트 러너는 **D-015로 종료**. GUT vs 자체 러너 미정 상태 해소.
- `tests/README.md`, `docs/TEST_CHECKLIST.md`에 자체 SceneTree 러너 계약과 실행 경로를 기록.

- **G-2 출처 정확성 감사**
  - `SETTING_BIBLE_v1.1.md`와 색인을 역대조해 설정서 직접 문장과 후속 구현 Hard Rule을 분리.
  - FLR-010 원문 뉘앙스 복원, CBT-001 CANON/DESIGN 분리, 잘못된 절 출처 정정,
    RAC-001 오크 주술사 수식어 복원 등.

- **G-3 판단 근거 감사**
  - 모든 CANON에 억지로 `판단`을 채우지 않고, 실제 해석이 개입한 항목만 기록하는 방침 유지.
  - `HIS-003`: 설정서 §5.5의 Event Node 블록 전체가 DESIGN이므로 과도한 CANON 승격 제거.
  - `CBT-007`: DESIGN → **CANON(방향) / TBD(수치)**.
  - `CBT-013`: "부위 히트박스만 가능"이라는 구현 고정 완화. 랜덤 크리티컬 우회 금지는 유지.
  - `CHR-011`: 상성만으로 승패를 확정하는 hard lock 금지로 문구 정밀화. 강한 유불리 자체는 TBD.
  - `RAC-004`: **열린 목록은 CANON / 추가 종족 상세는 TBD**로 상태 정밀화.
  - `FLR-011`: `clues[]` 필드와 자동 실패는 Canon을 강제하는 구현 Hard Rule임을 명시.

- **G-4 내용 중복 감사** — 정본 1곳 + 참조 구조로 정리.
  - `CBT-005 → ITM-003` (무기 수명)
  - `CHR-006 → SKL-003` (스탯 3점 투자→스킬 후보)
  - `FAC-004 → NPC-003` (시설 경험 정보 전파)
  - `WLD-004 → CHR-012` (사망 시 보존/초기화 상세)
  - `WLD-008 → ITM-002`, `WLD-009 → HIS-002/HIS-004`는 이전 감사에서 이미 통합.

- **G-5 NPC LOD 결정성 감사**
  - catch-up만으로는 SYS-003 결정성이 충분하지 않다고 판정.
  - `D-014`/`NPC-005`에 RNG 스트림 독립, 승격 전 catch-up, 동시 사건 안정 순서,
    논리 시각 이벤트 반영/예약, `last_sim_tick` 등 결정성 상태 저장, 저LOD 전용 확률표 금지 추가.

### Fixed
- `Boot._ready()`의 즉시 씬 전환으로 발생하던 `Parent node is busy adding/removing children` 오류를
  한 프레임 대기 후 전환하도록 수정.
- Canon 색인의 원문보다 강한 요약/과소·오인 출처와 내용 중복을 교정.
- `CURRENT_STATE.md`와 월간 로그의 인계 상태 불일치를 동기화.
- Markdown 파일 끝 LF 누락을 복구하고, 다음 작업에서도 유지하도록 로그에 규칙 기록.

### Notes
- **PHASE 0 완료 (VERIFIED).** 실행/종료/Git push 확인, ESC 종료는 오너 직접 확인.
- **G-1~G-5 모두 완료.** PHASE 1의 문서상 선행조건은 해소됐다.
- PHASE 1은 **오너의 별도 착수 지시 전 시작하지 않는다.** 착수 시 `tests/runner.gd` + 이동/카메라 구현부터.
- 개발 PC 네이티브 OpenGL 종료 크래시는 빈 프로젝트에서도 재현되는 환경 이슈다.
  필요 시 로컬 실행에서 `--rendering-driver opengl3_angle` 사용하며 프로젝트 배포 설정에는 고정하지 않는다.
