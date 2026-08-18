# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-18

- **PHASE**: 1 (이동/카메라) — **완료 (`PLAYTESTED`)**
  - 1-1 벽 충돌 · 1-2 프레임 독립성 · 1-3 대각 정규화 → 구현/자동 테스트 완료
  - 1-4 조작감 · 1-5 카메라 → **PLAYTESTED** (오너 확정 2026-08-18)
- **다음 PHASE**: 2 — 1층 고정 지형 + 동적 배치. **아직 구현 착수 금지**
  - `D-016` 1층 데이터 포맷 설계안이 **Proposed** 상태다.
  - Claude 설계안 작성 후 GPT 교차검토 완료. Canon 정합성 2건과 Q0~Q5 오너 결정을 먼저 닫아야 한다.
- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **엔진**: Godot `4.7.1-stable`
- **canon 색인**: 141개 ID / 15도메인 / 통합 포인터 3개, canon 색인 PROPOSAL 0건
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지, docx 개정 시 변환기 재실행
- **오너 결정 대기**: **D-016 Q0~Q5**

## G-1 ~ G-5 상태

- [x] **G-1 자동 테스트 러너** — 자체 `SceneTree` 러너 확정 (`D-015`) 및 PHASE 1에서 구현 완료
- [x] **G-2 출처 정확성 재검수** — 원문 역대조 완료
- [x] **G-3 판단 근거 검수** — 완료
- [x] **G-4 내용 중복 검사** — 완료
- [x] **G-5 NPC-005 LOD 결정성 검수** — 완료

## PHASE 1 결과 (완료)

| 항목 | 결과 |
| --- | --- |
| `tests/runner.gd` | 자체 SceneTree 단위 러너 |
| `tests/integration_runner.gd` | 물리 통합 SceneTree harness |
| `tests/integration/test_player_movement_e2e.gd` | 실제 Input→Player→physics 경로 E2E |
| `tests/integration/test_player_collision.gd` | 충돌 케이스 분리 |
| `scripts/player/movement.gd` | 이동 계산 순수 함수 |
| `scripts/player/player.gd` · `scenes/player/Player.tscn` | `CharacterBody2D` + Camera2D |
| `scenes/world/TestRoom.tscn` | PHASE 1 전용 테스트 방 — PHASE 2에서 폐기 |
| `tools/run.ps1` | Godot 자동 탐색 + 4.7.1 버전 경고 |

현재 테스트: 단위 17단언 · 통합 17단언(충돌 10 + E2E 7) · 구현 담당 실행에서 전부 통과 · exit 0.
오너 2차 플레이테스트: 카메라 드래그 여백 적용 후 조작감/카메라 승인.

확정된 DESIGN 수치:

- `Player.BASE_SPEED = 160.0` — 민첩 10 기준선. **PHASE 6에서 `CHR-009` 확정 후 재검토.**
- Camera2D drag margin `0.2` / smoothing speed `10.0` — 오너 PLAYTESTED.

## PHASE 2 설계안 — D-016 Proposed

문서: `docs/design/PHASE2_FLOOR1_FORMAT.md`

Claude가 구현 전에 포맷을 먼저 토의하자는 제안으로 작성했고 GPT 교차검토까지 완료했다.
**큰 방향은 타당하지만 현재 형태 그대로 Resolved 하면 안 된다.**

### 구현 전 반드시 닫을 Canon 정합성 2건

1. **함정 타입: 고정 vs 시드 랜덤**
   - 설정서 §6.1 / D-003 / FLR-002: 1층 랜덤은 전리품·유배자·상태/활성 플래그.
   - SYS-014: 데이터 마이닝 정책 정리 과정에서 함정의 "활성 여부·종류"를 시드로 숨길 수 있다고 적음.
   - D-016 초안은 슬롯만 고정하고 타입·단서를 시드 결과로 둠.
   - GPT 권고: **원문 우선으로 타입/구조 고정, 활성·소모 상태만 동적.** 타입 랜덤을 원하면 오너가 명시적으로 확정.

2. **계단 후보 지점: 고정 Canon vs 아직 미정**
   - SYS-014는 고정 후보 지점을 이미 Canon처럼 적음.
   - 설정서 §6.1/FAC-001은 계단이 고정 맵 안의 파티 귀속 별도 상태라는 것까지만 직접 확정.
   - D-016은 이 문제를 Q2로 다시 올림.
   - GPT 권고: **고정 후보 지점**. 단, 오너가 재확인해 SYS-014 출처 의미를 명확히 할 것.

### GPT 권고안

- **Q1 지형 포맷**: TileMapLayer 저작 채택 + 불변 `FloorDefinition` 런타임 공통 표현.
  - 1층: `TileMapLayer scene + floor1_meta.tres → FloorDefinition → FloorState`
  - 2층+: `Generator → FloorDefinition → FloorState`
  - `FloorDefinition`을 별도 영구 정본 파일로 중복 저장하지 않는다.
- **Q2 계단 후보**: 고정 후보 지점 권고.
- **Q3 계단 생성 시점**: C안 권고 — 층 최초 진입 시 현재 솔로/파티 소유권을 resolve/create,
  파티 합류 시 새 계단을 만들지 않고 파티장의 기존 계단 이용권으로 전환, 탈퇴는 FAC-006/007.
- **Q4 `tier_hint`**: 두지 않음 권고.
- **Q5 결정성**: 생성 결과 저장 + seed 보존. `floor_definition_version/hash`도 세이브에 기록.

### 스키마 보정

- `start_points: Array`를 이유 없이 랜덤 선택하지 않는다. 근거가 없으면 MVP는 `start_cell` 단일.
- `Rect2i map_bounds`는 broad bounds만. 실제 walkable/collision 영역은 TileMapLayer 정의를 따른다.
- `rooms: rect`로 지형을 중복 정의하지 않는다. semantic area는 셀 집합/영역 참조 또는 타일에서 파생.
- `trap_slots.shape`가 타입을 암시하지 않도록 한다.
- 포맷 가드 테스트는 마지막 T7이 아니라 **T1과 동시에** 만든다.
- 고정 후보제를 택하면 모든 시작점→모든 계단 후보 정적 도달성을 전수 검사하고 seed sweep은 생성기 검증으로 분리.

## 다음 작업

**오너와 D-016 토의 → Q0~Q5 확정 → Canon/DECISIONS 정합화 → 구현 담당이 티켓 타당성 확인 → PHASE 2 구현.**

D-016 확정 후 PHASE 2 착수 시:

- `scenes/world/TestRoom.tscn`은 폐기한다.
- 1층 지형은 `data/floors/floor1_fixed/`에서 로드 (`FLR-001`). 프로시저럴 지형 생성기 금지 (`FLR-003`).
- 계단은 `party_stairs[]`, 단일 `stair_id` 금지 (`FAC-002`).
- SYS-009 validator는 **일반 trap type 정의를 금지하는 것이 아니라, 정답 매핑만 금지**하도록 범위를 잡는다.
- 실제 1층 크기/방 개수는 Canon이 아니라 DESIGN. 회색박스에서 오너 플레이테스트로 조정한다.

## 테스트 러너 — D-015

```bash
godot --headless --path . --script res://tests/runner.gd
godot --headless --path . --script res://tests/integration_runner.gd
```

GUT 재검토 조건: fixture/mock/비동기/리포팅 요구가 반복되어 자체 runner/helper 유지보수가 실제 게임 테스트보다 부담이 될 때.

## 환경/협업 주의사항

- 개발 PC 네이티브 OpenGL 종료 크래시는 프로젝트 코드 문제가 아니다. 필요 시 `--rendering-driver opengl3_angle`.
- 다른 PC에서 처음 작업하면 `.godot/`이 없으므로 `--import` 먼저 실행.
- PowerShell 다중행 커밋 메시지는 `git commit -F <파일>` 사용. 성공 확인 후 SHA 기록.
- Markdown 끝 LF 유지.
- `docs/SETTING_BIBLE_v1.1.docx` 변경 시 `tools/docx_to_md.ps1` 즉시 재실행.
- 설정서 밖 새 확정 규칙은 `DECISIONS.md` + `docs/canon/INDEX.md` 정본 외 유래 표 동시 확인.

## 최근 WORK REPORT

```text
[WORK REPORT]
작업 ID: PHASE2-DESIGN-REVIEW-001
PHASE: PHASE 1 완료 / PHASE 2 설계
목표: Claude의 D-016 1층 포맷 설계안 교차검토
변경 파일:
- docs/design/PHASE2_FLOOR1_FORMAT.md
- CURRENT_STATE.md
- docs/log/2026-08.md
검토 내용:
- 고정/동적 경계와 SYS-009 검토
- FLR-002 ↔ SYS-014 함정 타입 랜덤 범위 충돌 발견
- SYS-014 ↔ D-016 계단 후보 고정 여부 충돌 발견
- TileMapLayer/FloorDefinition/FloorState 경계 제안
- 스키마·테스트·세이브 버전 보강 제안
테스트:
- 코드 구현 없음 / 런타임 테스트 대상 없음
설정 관련 결정:
- D-016 Proposed 유지, 오너 Q0~Q5 결정 필요
알려진 문제:
- Canon conflict 2건 미해결
다음 작업:
- 오너와 D-016 Q0~Q5 토의 후 Resolved 여부 결정
완료 등급: 설계 검토 완료 / 구현 미착수
Git commit:
<본 검토 커밋>
```
