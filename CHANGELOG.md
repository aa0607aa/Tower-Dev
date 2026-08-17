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

### Fixed
- `Boot._ready()`에서 `change_scene_to_file()`을 직접 호출해 발생하던
  "Parent node is busy adding/removing children" 런타임 에러 → 한 프레임 대기 후 전환하도록 수정.

### Notes
- PHASE 0 실행 검증 완료: Godot 4.7.1-stable에서 임포트/헤드리스/창 실행 모두 exit 0, 에러 0.
- 설정서 v1.1 원본(docx) 미입고 — `docs/CANON_NOTES.md`는 입고 후 대조 검수 필요.
- 다음: PHASE 1 (이동/카메라) — 오너 지시 대기.
