# CHANGELOG — 「탑」

형식은 Keep a Changelog를 느슨하게 따른다. 확정된 변경만 기록한다.

## [Unreleased]

### Added

- **PHASE 1 — 이동/카메라 (완료, `PLAYTESTED`).**
  - `scripts/player/movement.gd` — 이동 계산을 노드 없는 순수 함수로 분리.
  - `scripts/player/player.gd` · `scenes/player/Player.tscn` — `CharacterBody2D` 8방향 연속 이동,
    Camera2D(드래그 여백 `0.2` · smoothing `10.0`).
  - `scenes/world/TestRoom.tscn` — PHASE 1 검증용 테스트 방. **Canon 지형 아님.**
  - `project.godot` — WASD + 방향키 입력.
  - `D-015` 자체 `SceneTree` 테스트 인프라.
  - 현재 기록: 단위 17단언 + 통합 17단언(충돌 10 + 실제 Player E2E 7), 구현 담당 실행에서 실패 0.
  - `tools/run.ps1` — Godot 실행 탐색 + 4.7.1 버전 확인/경고.

- 협업 프로토콜 v1.0 (`COLLABORATION_PROTOCOL.md`) — 역할/Canon 충돌/WORK REPORT/완료등급.
- 통합 개발 가이드 v2.0 (`docs/DEVELOPMENT_GUIDE.md`) — PHASE 0~11 로드맵.
- 결정 이력 (`DECISIONS.md`) — `D-001~D-023`.
- 월 단위 작업 로그 `docs/log/` — 요청·작업·근거·다음 AI·오너 결정·산출물 기록.
- **PHASE 0 — Godot 프로젝트 뼈대** 및 최소 Boot/Main 실행 구조.
- 세계관 원본 `docs/SETTING_BIBLE_v1.1.docx` + AI 검수용 기계 변환 사본 `SETTING_BIBLE_v1.1.md`.
- `tools/docx_to_md.ps1` — docx→md 변환 및 누락 자기검증.
- **Canon 색인 체계** (`docs/canon/`) — **149개 ID / 15도메인**, 통합 포인터 3개.
- `docs/DATAMINING_POLICY.md` — D-012 데이터 마이닝 정책 근거.
- `D-013` — 설정서 밖 성장 규칙 출처 정정/오너 확정.
- `D-014` — NPC 시뮬레이션 LOD + G-5 결정성 불변식.
- `D-015` — 자체 SceneTree 테스트 러너.
- `D-017` — **실제 월드 공간 · 유배자 행동 반경 · 와이드 맵 · 홀짝층 · 지형 물질성/파괴 가능** 복원/확정.
- **`D-018` / `SYS-015` — 회차 시작 시 `[@회차 시작! 행운을 빕니다!]` 고정 시스템 메시지.**
- **`D-019` — P2-T2 1층 greybox PLAYTEST용 시작 범위 승인.**
  긴 축 160~220 타일 / 주요 공간 14~20 / 소형 포켓 6~10 / 큰 루프 3~5.
- **`D-020` — 1층 스폰 무기 품질을 소설 원문 규칙으로 복원.**
  대체로 품질은 나쁘지만 초기 대거보다 낫다.
- **`D-023` — 마인드맵 경로형 스탯 투자·랜덤 스킬 개화·제한적 환원 규칙 확정.**
  빨강=STR / 초록=AGI / 파랑=INT, 노드 1개=스탯 +1, 가지 3노드 완성 시 즉시 랜덤 개화.
- `FLR-023~027` — 실제 월드 일부인 층, 유배자별 맵의 끝, 공유 월드 물리 상태, NPC/야생동물 경계 통과,
  와이드 맵, 홀수층 개인 목표/짝수층 공동 목표, 파괴 가능한 물질 지형.
- `FAC-012/013` — 계단은 층 진입 시 생성하고, 생성 후 월드 좌표에 고정되며 파괴 불가.
- `docs/design/PHASE2_WORLD_SPACE_EXTENSION.md` — D-016 오너 확정과 GPT 구현 제안을 분리한 설계 토의 문서.
- **`docs/design/PHASE2_IMPLEMENTATION_HANDOFF.md`** — D-016 최종 구현 인계. PHASE 2 P2-T0~T7 범위/완료조건.
- **`docs/reference/FLOOR1_NOVEL_SOURCE_NOTES.md`** — 오너 제공 소설 초반 1층 원문을 PHASE 2 greybox 참고용으로 정리.
  정확한 크기/방 수 수치는 원문에 없으며, 원문 단서와 DESIGN 시작값을 분리해 기록.
- **`docs/reference/EARLY_POE_PASSIVE_TREE_REFERENCE.md`** — 최신판이 아닌 **2011~2013 초기 Path of Exile** 패시브 트리의
  road/highway·cluster·연결 노드 UX를 마인드맵 설계 참고로 정리. PoE 규칙 자체는 Canon 아님.
- **지질 데이터 계약**:
  - `data/worlds/README.md`
  - `data/worlds/geology_profile.schema.json`
  - 실제 월드/천체는 `data/worlds/<world_id>/geology_profile.json`에 크기·지층 경계·성분/재료 비율·지역 프로필을 기록.
- `BACKLOG B-007` — 전체 행성 지질·굴착·붕괴 시뮬레이션. PHASE 2에서는 공간/material/mutation hook만 확보.

### Changed

- **D-012/SYS-014 정정** — 최초 데이터 마이닝 정리에서 설정서보다 넓혀 적었던
  "1층 함정 종류는 시드 랜덤"과 "계단 후보 지점은 고정" 해석을 폐기.
  - 1층 함정의 **위치·종류·구조는 고정**.
  - 동적인 것은 활성/소모, 루팅, 전투 흔적 등.
  - 계단은 고정 후보표가 아니라 층 진입 시 실제 월드 공간을 바탕으로 별도 실체화.
- `FLR-001/002/003` — **고정 = 초기 정의 고정**으로 정밀화. 이후 플레이어의 지형 파괴/mutation과 양립.
- `FLR-017` — `map_bounds`를 세계 끝으로 보지 않고 **유배자별 접근/인과 경계("맵의 끝")**로 정밀화.
- `FLR-024` — 같은 실제 월드 좌표를 보는 유배자들은 **지형 mutation·NPC 생존/위치·실제 물체 상태를 공유**한다고 확정.
  AccessEnvelope/목표/계단 귀속 같은 탑 규칙만 유배자별로 분리.
- 맵의 끝은 유배자 본체뿐 아니라 **유배자가 원인이 된 직접 영향**도 차단:
  소환물/통제 펫, 투사체, 기술/마법 효과, 던진 물체, 유배자에 의해 강제 이동 중인 NPC/물체가 경계를 넘을 수 없다.
- `FLR-014` — 고정 파밍 지점 `tier_hint`를 두지 않는 오너 결정 반영. 이후 `D-020`으로 무기 품질도 원문 복원:
  **1층 스폰 무기는 대체로 저품질이지만 초기 대거보다 낫다.**
- **D-016 PHASE 2 설계안 최종 확정 (`Resolved`)**:
  - 공간: `WorldTerrainDefinition/TerrainBody → FloorDefinition → FloorState + AccessEnvelope`.
  - 공유 물리 변화는 `WorldState.TerrainMutationState` 소유.
  - 계단: `Engine candidate → Hard Constraint → Engine scorer → Optional AI ranking → Validator → top-band seed 선택 → WorldAnchor 저장`.
  - AI가 꺼져도 엔진 scorer로 진행하는 fallback 필수.
  - 계단은 수학적 1등 좌표를 항상 고르지 않고 상위 후보 밴드에서 seed 기반 가중 선택.
  - 생성 결과 저장 + seed + `floor_definition_version/hash`.
  - 지질 정의는 실제 데이터 파일로 보존하되 전체 행성 시뮬레이션은 PHASE 2 범위 밖.
- **PHASE 2 진행 상태** — `P2-T1` 공간 데이터 타입 완료, `P2-T0` Canon 가드 및 AccessEnvelope 형태 기반 교체 완료.
  `D-019` 승인으로 **P2-T2 1층 greybox + loader는 바로 착수 가능**.
- **`SKL-003/SKL-006` 정밀화 (`D-023`)**:
  - 스탯 숫자 직접 배분 대신 연결된 색상 노드에 투자.
  - 가지의 3노드 완성 즉시 스킬이 랜덤 개화.
  - 설정서의 80/20은 내부 후보 풀/가중치로 사용.
  - 중심에서 멀어질수록 기존 스탯/스킬과의 연관성 강화, 일정 깊이 이후 무관 스킬 배제.
- **`RAC-003` 정정 (`D-023`)** — 종족 변경 시 전체 성장 초기화가 아니라
  새 종족에 부적합한 스킬과 그 하위 가지만 취소하고 해당 구간의 투자 포인트를 환원. 임의 respec 금지.

- `docs/CANON_NOTES.md` 내용을 `docs/canon/`으로 통합하고 포인터만 유지.
- B-004 자동 테스트 러너는 D-015로 종료.
- **G-2 출처 정확성 감사** — 원문과 구현 Hard Rule 분리, 잘못된 출처/뉘앙스 교정.
- **G-3 판단 근거 감사** — HIS-003/CBT-007/CBT-013/CHR-011/RAC-004/FLR-011 정밀화.
- **G-4 내용 중복 감사** — 정본 1곳 + 참조 구조로 정리.
- **G-5 NPC LOD 결정성 감사** — RNG 독립, 승격 전 catch-up, 동시사건 안정 순서,
  논리시각 이벤트, 결정성 상태 저장, 저LOD 전용 확률표 금지.

### Fixed

- `Boot._ready()` 즉시 씬 전환 오류 → 한 프레임 대기 후 전환.
- PHASE 1 테스트 러너 오탐 및 "통과하지만 실제 벽을 검증하지 않던" 충돌 테스트 수정.
- **실제 Player 경로를 물지 않던 프레임 독립성 회귀 테스트 구멍** — 변이 테스트로 증명 후
  `Input → Player._physics_process → move_and_slide()` E2E 추가.
- integration runner를 harness와 케이스로 분리.
- 카메라 짧은 왕복 이동 어지러움 → Camera2D drag margin 추가, 오너 PLAYTESTED.
- Canon 색인의 원문보다 강한 요약/과소·오인 출처와 내용 중복 교정.
- `FLR-014`의 **초기 대거 대비 1층 스폰 무기 품질**이 소설 원문과 충돌하던 문제를 `D-020`으로 해소.
- `RAC-003`의 "종족 변경=전체 초기화"가 오너 의도보다 강했던 문제를 `D-023`으로 해소.
- README/CHANGELOG의 오래된 Canon 항목 수와 PHASE 상태 정리.

### Notes

- **PHASE 0 완료 (VERIFIED).**
- **G-1~G-5 완료.**
- **PHASE 1 완료 (`PLAYTESTED`).**
- **PHASE 2 진행 중.**
- 마인드맵의 **전문화 임계 깊이·연관도 공식·태그 체계·새 가지 정확한 수/형태는 TBD**. `D-023`의 상위 구조만 확정.
- P2-T2의 160~220 / 14~20 / 6~10 / 3~5는 **최종 Canon 숫자가 아니라 오너 승인 DESIGN 기준선**이며 P2-T7 PLAYTEST에서 조정 가능.
- 1층 초기 지형은 고정이지만 플레이 중 지형 파괴는 `WorldState`의 공유 동적 mutation으로 허용된다.
- 개발 PC 네이티브 OpenGL 종료 크래시는 환경 이슈. 필요 시 로컬에서 `--rendering-driver opengl3_angle` 사용.
