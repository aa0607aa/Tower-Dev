# CHANGELOG — 「탑」

형식은 Keep a Changelog를 느슨하게 따른다. 확정된 변경만 기록한다.

## [Unreleased]

### Added

- **PHASE 4 — 반실시간 전투 (자동 검증 완료, 오너 PLAYTEST 대기).**
  - `scripts/combat/damage_model.gd` — 설정서 §12.2의 4단계 피해식. **난수 없음**(`CBT-004`).
  - `scripts/combat/stat_curve.gd` · `data/curves/stat_efficiency.json` — `CHR-008` 성장곡선을
    데이터로. `CBT-010`의 √ 압축.
  - `scripts/combat/weapon_data.gd` · `data/items/weapons.json` — `CBT-012`대로 무기별
    스탯 비중을 **데이터에서** 정의. 코드에 무기 분기 없음.
  - `scripts/combat/attack_state.gd` — `CBT-008` wind-up/active/recovery. **초 단위**(프레임 아님).
  - `scripts/combat/combat_service.gd` — 공간 타격·급소 판정. 명중 굴림 없음(`CBT-006` TBD 회피).
  - `scripts/combat/combatant.gd` — 전투 상태 골격. `BodyResilience` 비노출(`CBT-011`).
  - `scripts/actors/enemy.gd` — 감지·추적·근접 공격. 함정도 밟는다(`FLR-028`).
  - `scripts/combat/thrown_object.gd` — 던지기. **`TrapSensor.sense_impact()`를 재사용**한다.
  - `scripts/world/time_scale.gd` — 전술 정지/슬로모션. 엔진 배속을 건드리지 않는다.
  - `RunState.combatants`(유배자, 층을 넘어 따라감) · `WorldState.combatants`(적, 월드 공유).
  - 세이브 v3 — 전투 상태 추가.
  - `project.godot` — 공격(좌클릭/J) · 대시(Shift) · 던지기(F) · 전술 정지(Tab).

### Changed

- 전투 입력을 `_unhandled_input` 이벤트에서 **폴링**으로 바꿨다. `Input.action_press()`는
  상태만 바꾸고 이벤트를 만들지 않아 **자동 테스트로 검증할 수 없었다** —
  `P3-REV-005`("게임 경로에만 있는 버그")와 같은 함정이다.


- **PHASE 3 — 상호작용·함정·파밍 (완료, `PLAYTESTED` 2026-08-20).**
  - 오너 판정: F1 없이 플레이해 함정 단서가 "잘 보인다". `FLR-011` 요건 충족.
  - 단서 밀도·진하기 조정은 도트 맵 완성 후(`PHASE 8`)로 보류.
  - 최종 자동 검증 **단위 929 단언 + 통합 25 단언**, 변이 검증 3건.
  - `scripts/world/run_state.gd` · `world_state.gd` — `RunState → WorldState → FloorState`
    3계층을 **코드로** 만들었다. 전에는 `FloorState`만 있었고 "`WorldState` 소유"라고
    적힌 `TerrainMutationState`는 소유자가 없었다.
  - `scripts/items/item_instance.gd` · `item_service.gd` — 개체 단위 물건과 소유권 이동.
    파밍 지점의 추첨 결과와 "그 물건이 지금 어디 있나"를 분리했다.
  - `scripts/interaction/interaction_service.gd` — 상호작용 대상 선택. 결정적 우선순위.
  - `scripts/traps/trap_stimulus.gd` · `trap_runtime.gd` — 함정을 **자극 기반**으로 판정.
    `body is Player` 금지 (`FLR-028`).
  - `scripts/world/ground_item_view.gd` · `clue_view.gd` — 배포 가능한 표현 계층.
  - `scripts/save/run_save.gd` — 회차 전체 저장/복원.
  - `project.godot` — `interact`(E/Enter) · `drop_item`(Q).
  - 저작 데이터에 함정 `accepts`/`min_mass` 추가. **DESIGN이며 canon 아님.**


- **PHASE 2 — 1층 공간/상태/계단/세이브 (완료, `PLAYTESTED` 2026-08-20).**
  - `P2-T0`~`P2-T7` 전 항목 + GPT 독립 검수 2회(`P2-REV-001~003`, `P2-REV-004~007`).
  - 오너가 통로 폭 수정 후 layout v2를 재플레이해 체감 판정까지 종료.
  - 최종 자동 검증 **단위 688 단언 + 통합 25 단언, 실패 0**. 변이 검증 6건.
  - 종료 근거: `docs/design/PHASE3_IMPLEMENTATION_HANDOFF.md` §1.

### Fixed

- `P2-REV-004` — 통로 폭이 저작값과 달랐다. GDScript 정수 나눗셈 때문에 `width=2`가
  실제로는 3칸이었다. 칸 수가 정확히 `width`가 되게 고치고 짝수 폭 치우침 방향을 고정했다.
  통행 셀 8759 → **8630**, 정의 해시 변경.
- `P2-REV-005` — AI ranking 어댑터에 **신뢰하는 후보 배열을 그대로** 넘기고 있었다.
  GDScript 참조 의미상 어댑터가 `anchor`·`cost`를 직접 고칠 수 있었다.
  원시값 사본만 전달하고, 반환값을 검증하고, AI 이후 엔진이 다시 Hard Constraint를 적용한다.
- `P2-REV-006` — 행동 반경을 `move_and_slide()` **이후**에 좌표만 되감고 있었다.
  물리 이동 전에 속도를 자르고, 중심점이 아니라 **몸체 AABB 전체**로 판정한다.
- `P2-REV-007` — 공간 의미 태그가 immutable definition hash에 빠져 있었다.
- `DOC-REV-001~003` — `D-025`가 문서 템플릿 코드블록 안에 들어가 있던 것, NSG-017 상태가
  문서마다 어긋나던 것, 테스트 수치가 낡았던 것을 정리했다.

### Decisions

- `D-025` — NSG-017 승격. 열매나무는 소규모 몬스터 집단 주변에 스폰되는 **경향**이 있다(`ITM-007`).
  확률·집단 규모·거리 반경은 TBD.
- `D-026` — 열매는 외형만으로 효과를 확정할 수 없지만, 감정·실험·경험·지식·분석으로는
  알아낼 수 있다. "섭취 전에는 어떤 방법으로도 알 수 없다"는 절대 규칙이 아니다.
- 설정서 v1.1 §24.1을 `D-021`대로 **8/11/15**로 직접 개정하고 `.md` 사본을 재생성했다.

- **PHASE 1 — 이동/카메라 (완료, `PLAYTESTED`).**
  - `scripts/player/movement.gd` — 이동 계산을 노드 없는 순수 함수로 분리.
  - `scripts/player/player.gd` · `scenes/player/Player.tscn` — `CharacterBody2D` 8방향 연속 이동,
    Camera2D(드래그 여백 `0.2` · smoothing `10.0`).
  - `scenes/world/TestRoom.tscn` — PHASE 1 검증용 테스트 방. **Canon 지형 아님.**
  - `project.godot` — WASD + 방향키 입력.
  - `D-015` 자체 `SceneTree` 테스트 인프라.
  - `tools/run.ps1` — Godot 실행 탐색 + 4.7.1 버전 확인/경고.

- 협업 프로토콜 v1.0 (`COLLABORATION_PROTOCOL.md`) — 역할/Canon 충돌/WORK REPORT/완료등급.
- 통합 개발 가이드 v2.0 (`docs/DEVELOPMENT_GUIDE.md`) — PHASE 0~11 로드맵.
- 결정 이력 (`DECISIONS.md`) — **`D-001~D-024`**.
- 월 단위 작업 로그 `docs/log/` — 요청·작업·근거·다음 AI·오너 결정·산출물 기록.
- **PHASE 0 — Godot 프로젝트 뼈대** 및 최소 Boot/Main 실행 구조.
- 세계관 원본 `docs/SETTING_BIBLE_v1.1.docx` + AI 검수용 기계 변환 사본 `SETTING_BIBLE_v1.1.md`.
- `tools/docx_to_md.ps1` — docx→md 변환 및 누락 자기검증.
- **Canon 색인 체계** (`docs/canon/`) — **155개 ID / 15도메인**, 통합 포인터 3개.
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
- **`D-024` — 소설 원작 근거 누락 6건 복원.**
  - `FLR-028`: 함정은 Player 전용 판정이 아니라 실제 trigger mechanism에 따라 돌·투척물·환경과 상호작용.
  - `SYS-016`: 랜덤 인카운터는 **저작된 시나리오 골격 + 허용된 세부 랜덤화**.
  - `WLD-011`: 미궁의 언어 통합과 이를 담당하는 **「바벨탑」**.
  - `NPC-006`: NPC/생물은 실제 경험·정보 경로를 통해 학습.
  - `NPC-007`: NPC 상세는 전지적 UI가 아니라 **대화·관찰·행동 결과·소문**으로 파악.
  - `WLD-012`: 왕국에 도달하지 못하는 유배자가 대다수인 난이도감. 원작의 70%는 고정값이 아닌 DESIGN 기준.
- `docs/reference/NOVEL_SOURCE_GAP_AUDIT.md` — 소설 원작 ↔ Canon 역대조 장부. D-024 해결 항목과 신규 `NSG-017` 추적.
- `FLR-023~028` — 실제 월드 일부인 층, 유배자별 맵의 끝, 공유 월드 물리 상태, 와이드 맵, 홀짝층,
  파괴 가능한 지형, 물리 메커니즘 기반 함정 상호작용.
- `FAC-012/013` — 계단은 층 진입 시 생성하고, 생성 후 월드 좌표에 고정되며 파괴 불가.
- `docs/design/PHASE2_WORLD_SPACE_EXTENSION.md` — D-016 오너 확정과 GPT 구현 제안을 분리한 설계 토의 문서.
- **`docs/design/PHASE2_IMPLEMENTATION_HANDOFF.md`** — D-016 최종 구현 인계. PHASE 2 P2-T0~T7 범위/완료조건.
- **`docs/reference/FLOOR1_NOVEL_SOURCE_NOTES.md`** — 오너 제공 소설 초반 1층 원문을 PHASE 2 greybox 참고용으로 정리.
- **`docs/reference/EARLY_POE_PASSIVE_TREE_REFERENCE.md`** — 2011~2013 초기 Path of Exile의 road/highway·cluster UX 참고. PoE 규칙 자체는 Canon 아님.
- **지질 데이터 계약** — `data/worlds/README.md`, `data/worlds/geology_profile.schema.json`.
- `BACKLOG B-007` — 전체 행성 지질·굴착·붕괴 시뮬레이션.

### Changed

- **D-012/SYS-014 정정** — "1층 함정 종류 시드 랜덤"과 "계단 후보 지점 고정" 해석 폐기.
  1층 함정 위치·종류·구조는 고정, 활성/소모 등만 동적. 계단은 층 진입 시 별도 실체화.
- `FLR-001/002/003` — **고정 = 초기 정의 고정**으로 정밀화. 이후 지형 파괴/mutation과 양립.
- `FLR-017/024` — 맵의 끝은 유배자별 접근/인과 경계이며, 겹치는 실제 월드 좌표의 물리 상태는 공유.
- 맵의 끝은 유배자 본체뿐 아니라 유배자가 원인이 된 소환물/투사체/기술/던진 물체/강제이동 효과도 차단.
- `FLR-014` — `tier_hint` 없음 + D-020에 따라 1층 스폰 무기는 대체로 초기 대거보다 낫다.
- **D-016 PHASE 2 설계안 최종 확정**:
  - `WorldTerrainDefinition/TerrainBody → FloorDefinition → FloorState + AccessEnvelope`.
  - 계단: `Engine candidate → Hard Constraint → Engine scorer → Optional AI ranking → Validator → top-band seed 선택 → WorldAnchor 저장`.
  - 결과 저장 + seed + `floor_definition_version/hash`.
- **P2-REV-001~003 처리**:
  - StairResolver BFS/fallback을 AccessEnvelope-aware로 수정.
  - `or true` 무효 테스트 제거, party ID가 RNG stream에 참여하는 표본 테스트로 교체.
  - `definition_hash`를 immutable floor-definition hash 계약으로 정리.
- **`SKL-003/SKL-006` 정밀화 (`D-023`)** — 색상 경로형 스탯 투자, 3노드 즉시 개화, 깊이에 따른 연관성 강화.
- **`RAC-003` 정정 (`D-023`)** — 종족 변경 시 부적합 subtree만 제거/환원, 전체 respec 금지.
- **원작 GAP 감사 (`D-024`)** — 기존 `NSG-001/003/004/005/006/008`을 Resolved로 전환하고 실제 Canon ID에 연결.
  새 발췌의 **열매 효과 랜덤/외형 비신뢰성은 `ITM-002`와 정합**함을 확인.
  다만 **`NSG-017` 열매나무가 소규모 몬스터 집단 주변에 자주 스폰되는 경향**은 아직 미확정으로 유지.

- `docs/CANON_NOTES.md` 내용을 `docs/canon/`으로 통합하고 포인터만 유지.
- B-004 자동 테스트 러너는 D-015로 종료.
- G-2 출처 정확성 / G-3 판단 근거 / G-4 중복 / G-5 NPC LOD 결정성 감사 완료.

### Fixed

- `Boot._ready()` 즉시 씬 전환 오류 → 한 프레임 대기 후 전환.
- PHASE 1 충돌 테스트 오탐 및 실제 Player E2E 프레임 독립성 테스트 구멍 수정.
- integration runner를 harness와 케이스로 분리.
- 카메라 짧은 왕복 이동 어지러움 → Camera2D drag margin 추가, 오너 PLAYTESTED.
- Canon 색인의 원문보다 강한 요약/과소·오인 출처와 내용 중복 교정.
- `FLR-014` 초기 대거 대비 품질 충돌을 D-020으로 해소.
- `RAC-003` "종족 변경=전체 초기화" 문제를 D-023으로 해소.
- README/CHANGELOG의 오래된 Canon 항목 수와 PHASE 상태 정리.

### Notes

- **PHASE 0 완료 (VERIFIED).**
- **G-1~G-5 완료.**
- **PHASE 1 완료 (`PLAYTESTED`).**
- **PHASE 2는 P2-REV 수정까지 완료, GPT 최종 diff 검토 + 오너 layout 밀도/규모 판정 대기.**
- PHASE 3 함정 구현은 `FLR-028`의 **물리 메커니즘 기반 trigger**를 적용해야 한다.
- 마인드맵 전문화 임계 깊이·연관도 공식·태그·새 가지 정확한 수/형태는 TBD.
- P2-T2 수치는 최종 Canon이 아니라 PLAYTEST용 DESIGN 기준선.
- 1층 초기 지형은 고정이지만 플레이 중 지형 파괴는 `WorldState` 공유 mutation으로 허용.
- **바벨탑 위치·외형·언어 통합 작동 원리는 TBD.**
- **NSG-017 열매나무/소규모 몬스터 인접 스폰은 아직 Canon 아님.**
- 개발 PC 네이티브 OpenGL 종료 크래시는 환경 이슈. 필요 시 로컬에서 `--rendering-driver opengl3_angle` 사용.
