# CHANGELOG — 「탑」

형식은 Keep a Changelog를 느슨하게 따른다. 확정된 변경만 기록한다.

## [Unreleased]

### Added
- 협업 프로토콜 v1.0 (`COLLABORATION_PROTOCOL.md`) — 능력/환경 기준 역할표, Canon 충돌 에스컬레이션, WORK REPORT 핸드오프, PHASE→티켓→타당성→확정 루프, IMPLEMENTED/VERIFIED/PLAYTESTED 3단계.
- 통합 개발 가이드라인 v2.0 (`docs/DEVELOPMENT_GUIDE.md`) — 설정서 v1.1 정합화, PHASE 0~11 로드맵.
- 결정 이력 초기화 (`DECISIONS.md`) — D-001~D-011 Resolved, TBD 목록.
- 현재 상태(`CURRENT_STATE.md`) / 변경 이력(`CHANGELOG.md`) / README / Godot `.gitignore` 스캐폴딩.

- **PHASE 0 — 프로젝트 뼈대**
  - `project.godot` (Godot 4.7.1 stable, GL Compatibility, nearest 텍스처 필터, 1280×720).
  - 최소 실행 씬: `scenes/boot/Boot.tscn` → `scenes/world/Main.tscn` (게임 로직 없음, ESC 종료).
  - `scripts/core/game_log.gd` autoload — 콘솔 로그 전용, GameState 미접근.
  - `data/canon/canon.gd` — DECISIONS.md의 [Resolved] 상수만 (서든데스 3600초, 평균 스탯 10,
    오르골 8/12/14 참고값, 수명 100년, 타일 32px). [TBD] 수치는 넣지 않음.
  - 개발 가이드 §6 폴더 구조 전체 생성 (assets/data/scenes/scripts/tests/saves).
  - `docs/CANON_NOTES.md` · `docs/CODING_STYLE.md` · `docs/TEST_CHECKLIST.md` ·
    `assets/STYLE_GUIDE.md` · `tests/README.md`.
  - `.gitattributes` — LF 정규화(Godot 에디터의 CRLF 재저장으로 인한 전체 diff 방지).

- **세계관 canon 원본** `docs/SETTING_BIBLE_v1.1.docx` 저장소 배치 (오너).
- **Canon 색인 체계** (`docs/canon/`) — 설정서 v1.1 전문(§0~§27)을 대조해 canon을 ID 붙은
  낱개 항목 **133개 / 15개 도메인**으로 분해했다. `INDEX.md` 하나로 전체를 훑고,
  `FLR-004`·`RAC-002` 같은 ID로 코드 주석에서 근거를 인용한다.
  설정서 §26의 미정 영역 12개를 전부 TBD로 매핑해 다음 세션이 빈칸을 지어내는 사고를 차단한다.
  - `README.md`(체계 정의·대조 결과) · `INDEX.md`(색인)
  - `WLD`10 `HIS`5 `FLR`21 `CHR`17 `RAC`3 `SKL`9 `CBT`13 `MAG`5
    `ITM`6 `FAC`11 `NPC`4 `KGD`7 `DGN`5 `GOD`5 `SYS`12
  - **[CANON CONFLICT] 0건** — 개발 가이드 v2.0과 설정서 v1.1은 정합했다.

### Changed
- `docs/CANON_NOTES.md` 내용을 `docs/canon/`으로 통합하고 포인터만 남겼다.
  같은 canon을 두 곳에 두면 반드시 어긋나기 때문이다.
- `docs/DATAMINING_POLICY.md` — 데이터 마이닝 대응 정책 타당성 검토 (**PROPOSAL**, 오너 승인 대기).
- `DECISIONS.md` `D-012` [Proposed] — 데이터 마이닝 정책 3 Tier 분리안.

### Fixed
- `Boot._ready()`에서 `change_scene_to_file()`을 직접 호출해 발생하던
  "Parent node is busy adding/removing children" 런타임 에러 → 한 프레임 대기 후 전환하도록 수정.

### Notes
- **PHASE 0 완료 (VERIFIED).** 완료 조건 전부 충족 — 실행/종료 정상, Git 커밋·push 존재.
  ESC 종료는 오너가 직접 확인.
- 개발 PC 이슈: AMD 드라이버 설치로 OpenGL 3.3 실GPU 확보. 단 네이티브 OpenGL 종료 시
  `0xC0000409` 크래시가 있어(빈 프로젝트에서도 재현 — 엔진/드라이버 문제) 개발 실행은
  `--rendering-driver opengl3_angle`로 우회. `project.godot`은 건드리지 않음.
- 설정서 v1.1 원본(docx) 미입고 — `docs/canon/` 63항목과 `docs/CANON_NOTES.md`는 입고 후 대조 검수 필요.
- 다음: `D-012` 오너 결정 → 원본 대조 검수 → PHASE 1 (이동/카메라) 지시 대기.
