# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-18 12:34 KST

- **PHASE**: 1 (이동/카메라) — **완료 (`PLAYTESTED`)**
  - 1-1 벽 충돌 · 1-2 프레임 독립성 · 1-3 대각 정규화 → VERIFIED (자동 테스트)
  - 1-4 조작감 · 1-5 카메라 → **PLAYTESTED** (오너 확정 2026-08-18)
- **다음 PHASE**: 2 — 1층 고정 지형 + 동적 배치. **오너 지시 전 구현 착수 금지**
  - 착수 시 `scenes/world/TestRoom.tscn`을 버리고 `data/floors/floor1_fixed/` 로더로 교체한다.
    테스트 방은 canon 지형이 아니다 (`FLR-001`)
  - TileMapLayer 도입도 PHASE 2의 지형 포맷 설계와 함께 간다
- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **엔진**: Godot `4.7.1-stable`
- **canon 색인**: 141개 ID / 15도메인 / 통합 포인터 3개, PROPOSAL 0건
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지, docx 개정 시 변환기 재실행
- **오너 결정 대기**: 없음. `D-012`~`D-015` 모두 Resolved

## G-1 ~ G-5 상태

- [x] **G-1 자동 테스트 러너** — 자체 `SceneTree` 러너 확정 (`D-015`)
  - 외부 GUT 플러그인은 현재 도입하지 않는다.
  - 테스트 본문은 순수 함수 + 작은 assertion helper 중심으로 프레임워크 중립 유지.
  - PHASE 1 착수 시 `tests/runner.gd`부터 구현한다.
- [x] **G-2 출처 정확성 재검수** — 원문 역대조 완료.
- [x] **G-3 판단 근거 검수** — 완료.
  - `HIS-003` DESIGN 과승격 제거
  - `CBT-007` → CANON(방향)/TBD(수치)
  - `CBT-013`의 "히트박스만 가능" 과도한 구현 고정 완화
  - `CHR-011`은 상성만으로 승패를 확정하는 hard lock만 금지
  - `RAC-004` → 열린 목록 CANON / 상세 TBD
  - `FLR-011`의 `clues[]` 강제는 구현 Hard Rule임을 명시
- [x] **G-4 내용 중복 검사** — 완료.
  - `CBT-005 → ITM-003`
  - `CHR-006 → SKL-003` (3점 투자→스킬 후보)
  - `FAC-004 → NPC-003` (시설 경험 정보 전파)
  - `WLD-004 → CHR-012` (사망 시 보존/초기화 상세)
- [x] **G-5 NPC-005 LOD 결정성 검수** — 완료.
  - catch-up만으로 충분하지 않음.
  - RNG 독립성, 승격 전 catch-up, 안정적 사건 순서, 논리 시각 이벤트 반영,
    결정성 상태 저장, 저LOD 전용 확률표 금지를 `D-014`/`NPC-005`에 추가.
  - `TEST_CHECKLIST G-7` 신규.

## PHASE 1 결과 (완료)

| 항목 | 결과 |
| --- | --- |
| `tests/runner.gd` | 자체 SceneTree 단위 러너. 발견/실행/집계/종료 코드만 |
| `tests/integration_runner.gd` | 물리 충돌 검증용 별도 러너 |
| `scripts/player/movement.gd` | 이동 계산을 노드 없는 순수 함수로 분리 |
| `scripts/player/player.gd` · `scenes/player/Player.tscn` | `CharacterBody2D` + Camera2D |
| `scenes/world/TestRoom.tscn` | 960×640 테스트 방 (**canon 지형 아님, PHASE 2에서 폐기**) |
| `project.godot` | `move_left/right/up/down` (WASD + 방향키) |
| `tools/run.ps1` | Godot 자동 탐색 실행/테스트 헬퍼 |

자동 검증: 단위 17단언 · 통합 10단언 · 전부 통과 · exit 0.

확정된 DESIGN 수치 (canon 아님, 튜닝 가능):

- `Player.BASE_SPEED = 160.0` — **민첩 10 기준선** (`CHR-003`). 올리기 전 성장 여지를 계산할 것.
  `CBT-009`상 속도는 민첩·[신속]으로 빨라지므로 기준선이 높으면 성장 여지가 사라진다.
  **PHASE 6에서 민첩 보정(`CHR-009` 확정 후)과 함께 재확정한다.**
- Camera2D 드래그 여백 `0.2` / `position_smoothing_speed` `10.0` — 오너 확정.
  여백 없이 smoothing만 쓰면 짧은 왕복 이동에서 화면이 헤엄친다.

## 다음 작업

**PHASE 2 — 1층 고정 지형 + 동적 배치.** 오너 지시 전 구현 착수 금지.

착수 시 유의:

- `scenes/world/TestRoom.tscn`은 **버린다.** PHASE 1 검증용이며 canon 지형이 아니다.
- 1층 지형은 `data/floors/floor1_fixed/`에서 로드한다 (`FLR-001`). **생성기를 만들지 않는다** (`FLR-003`).
- 시드는 전리품·유배자·상태 **동적 배치 전용** (`FLR-002`).
- 계단은 `party_stairs[]` 구조. 단일 `stair_id`로 모델링하지 않는다 (`FAC-002`).
- 데이터 포맷 설계 시 `SYS-009` Tier 1·2를 적용한다 — 정답 테이블을 배포 파일에 두지 않고,
  `is_dummy` 플래그나 더미 전용 폴더를 만들지 않는다.
- TileMapLayer 도입은 이 단계의 지형 포맷 설계와 함께 간다. 구 `TileMap` 노드는 쓰지 않는다.
- Canon/TBD를 건드리는 변경은 금지한다.

## 테스트 러너 결정 — D-015

기본 실행 예정:

```bash
godot --headless --path . --script res://tests/runner.gd
```

GUT 재검토 조건: fixture/mock/비동기/리포팅 요구가 반복되어 자체 runner/helper 유지보수가 실제 게임 테스트보다 부담이 될 때.

## 환경/협업 주의사항

- 개발 PC 네이티브 OpenGL 종료 크래시는 프로젝트 코드 문제가 아니다. 필요 시
  `--rendering-driver opengl3_angle` 사용. `project.godot` 배포 설정으로 고정하지 않는다.
- 다른 PC에서 처음 작업하면 `.godot/`이 없으므로 `--import` 먼저 실행한다.
- PowerShell 다중행 커밋 메시지는 `git commit -F <파일>` 사용. 커밋 성공 확인 후 SHA 기록.
- Markdown 끝 LF 유지.
- `docs/SETTING_BIBLE_v1.1.docx`가 바뀌면 `tools/docx_to_md.ps1`을 즉시 재실행한다.
- 설정서 밖의 새 확정 규칙은 `DECISIONS.md`뿐 아니라 `docs/canon/INDEX.md`의 정본 외 유래 표도 함께 확인한다.

## 최근 WORK REPORT

```text
[WORK REPORT]
작업 ID: PRE-PHASE1-AUDIT-001
PHASE: PHASE 0 완료 / PHASE 1 착수 전
목표: G-1 테스트 러너 확정 + G-3/G-4/G-5 설계 감사 종료
결과:
- D-015: 자체 SceneTree 러너 Resolved
- G-3 판단 근거 감사 완료
- G-4 내용 중복 4묶음 정리
- G-5 NPC LOD 결정성 불변식 보강
- G-1~G-5 전부 완료
오너 결정 필요: 없음
다음 작업: 오너의 PHASE 1 착수 지시 대기
```
