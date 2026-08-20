# TEST_CHECKLIST.md — 「탑」 테스트 기준

개발 가이드 §13을 실행 가능한 체크리스트로 옮긴 것이다.
각 항목은 **IMPLEMENTED / VERIFIED / PLAYTESTED** 중 어느 등급까지 필요한지 표시한다.
(COLLABORATION_PROTOCOL.md §5 — 마지막 PLAYTESTED는 **오너만** 판정한다.)

---

## PHASE 0 — 뼈대

| # | 항목 | 필요 등급 | 상태 |
| --- | --- | --- | --- |
| 0-1 | Godot 4.7.1 stable로 프로젝트가 열린다 (임포트 오류 0) | VERIFIED | ✅ `--import` exit 0 |
| 0-2 | Boot → Main 씬 전환이 되고 빈 화면이 뜬다 | VERIFIED | ✅ headless / 창 실행 모두 |
| 0-3 | ESC 또는 창 닫기로 **정상 종료**된다 (크래시·행 없음) | VERIFIED | ✅ **오너가 직접 ESC 눌러 확인** (2026-08-17) |
| 0-4 | 콘솔에 스크립트 에러/경고가 없다 | VERIFIED | ✅ (초기 `remove_child` 에러 수정 완료) |
| 0-5 | Git 첫 커밋이 존재하고 원격에 push돼 있다 | VERIFIED | ✅ `26be95f` |
| 0-6 | 폴더 구조가 개발 가이드 §6과 일치한다 | IMPLEMENTED | ✅ |
| 0-7 | 저장소 전체에 "오르골의 탑" 명칭이 남아 있지 않다 | VERIFIED | ✅ (개발 가이드의 개명 이력 서술만 잔존) |

### ⚠ 개발 PC 환경 이슈 — 네이티브 OpenGL 종료 크래시

이 개발 PC(Dell OptiPlex 9020 · AMD Radeon R5 240 · 드라이버 23.20.806.256)에서는
**네이티브 OpenGL 창 모드로 실행하면 종료 시 `0xC0000409`로 크래시한다.**

우리 코드 문제가 아니다. 격리 테스트로 확인:

| 조건 | 결과 |
| --- | --- |
| headless (GL 없음) | exit 0 |
| 네이티브 OpenGL 창 (「탑」) | `0xC0000409` — 3/3 재현 |
| **네이티브 OpenGL 창 (빈 프로젝트, Node2D 하나)** | **`0xC0000409` — 3/3 재현** |
| Vulkan/D3D12 강제 | 이 카드 미지원 → OpenGL 폴백 → 동일 크래시 |
| **ANGLE 강제 (D3D11 변환)** | **exit 0 — 3/3 정상** |

**이 PC의 개발용 실행 명령은 ANGLE을 쓴다:**

```bash
godot --path . --rendering-driver opengl3_angle
```

`project.godot`에는 넣지 않는다. 프로젝트 설정으로 박으면 배포 시 모든 Windows 플레이어가
ANGLE을 강제로 쓰게 되며, 그건 개발 PC 한 대의 드라이버 버그로 결정할 사안이 아니다.
(배포 렌더링 경로 결정은 PHASE 11 또는 오너 결정 사항 → BACKLOG)

## PHASE 1 — 이동/카메라

| # | 항목 | 필요 등급 | 상태 |
| --- | --- | --- | --- |
| 1-1 | 테스트 방에서 벽을 뚫지 않는다 | VERIFIED | ✅ 통합 5케이스 + 오너 실제 이동 확인 |
| 1-2 | 30 / 60 / 120 FPS 상당의 서로 다른 delta sequence에서도 동일 시간 이동 거리가 같다 | VERIFIED | ✅ 단위(수학) + **E2E(실제 Player 경로)** 이중 |
| 1-3 | 8방향 대각 이동 속도가 직선 이동보다 빠르지 않다 | VERIFIED | ✅ 4방향 전부 |
| 1-4 | 조작감 — 미끄러움·관성이 의도대로인가 | **PLAYTESTED** | ✅ 오너 확정 2026-08-18 |
| 1-5 | 카메라가 플레이어를 따라가고 화면이 흔들리지 않는다 | **PLAYTESTED** | ✅ 오너 확정 2026-08-18 |

> **PHASE 1 완료 조건은 유지한다 (2026-08-18).**
> 1차 플레이테스트에서 "짧은 이동을 반복할 때 카메라가 어지럽다"는 지적이 나와
> 카메라에 **드래그 여백**을 추가하고(`0.2`, smoothing `10.0`) 2차에서 확정받았다.
>
> GPT 독립 코드 리뷰에서 현재 `player.gd`가 `CharacterBody2D.velocity` + `move_and_slide()`를
> 올바르게 사용해 delta를 중복 곱하지 않는 것을 확인했다.
> 함께 지적된 회귀 테스트 부채 3건은 **PHASE 2 착수 전에 전부 해소했다 (2026-08-18)**:
>
> - **P1-TEST-001 해소** — `tests/integration/test_player_movement_e2e.gd` 추가.
>   `Input.action_press()` → `Player._physics_process()` → `move_and_slide()`의 **실제 경로**를 통과한다.
> - **P1-TEST-002 해소** — `integration_runner.gd`를 harness로만 남기고 케이스를
>   `tests/integration/`으로 분리했다 (`D-015` 원칙 1).
> - **P1-TOOL-001 해소** — `tools/run.ps1`이 Godot 버전을 확인하고 `4.7.1`이 아니면 경고한다.
>
> ### 지적이 옳았음을 변이 테스트로 증명했다
>
> `player.gd`에 `velocity *= delta`(delta 중복 곱)를 주입하고 돌린 결과:
>
> | 시점 | 단위 | 통합 | 결과 |
> | --- | --- | --- | --- |
> | 보강 **전** | 17단언 통과 | 10단언 통과 | **버그를 못 잡음** (플레이어가 초당 2.7px로 기어감) |
> | 보강 **후** | 17단언 통과 | **4단언 실패** | 잡음 — 30/60/120 tick에서 각각 2.67 / 1.33 / 0.67px |
>
> 틱레이트가 두 배가 될 때마다 거리가 절반이 되는 것이 프레임 의존성의 서명이다.
> **테스트를 추가할 때는 "실제로 실행되는 경로를 통과하는가"를 항상 확인할 것.**
> 아무도 호출하지 않는 함수를 검사하는 테스트는 초록불만 줄 뿐 아무것도 지키지 않는다.
>
> `BASE_SPEED`(160, 민첩 10 기준선)는 **PHASE 6에서 민첩 보정과 함께 재확정**한다.

### 실행

```
powershell -ExecutionPolicy Bypass -File tools/run.ps1 -Mode test      # 둘 다 (권장)

godot --headless --path . --script res://tests/runner.gd              # 단위 (순수 로직)
godot --headless --path . --script res://tests/integration_runner.gd  # 통합 (물리)
```

```
tests/
  runner.gd              # 단위 harness — tests/test_*.gd 탐색
  integration_runner.gd  # 통합 harness — tests/integration/test_*.gd 탐색
  lib/                   # 헬퍼 (탐색에서 제외되도록 하위 폴더에 둔다)
  test_*.gd              # 단위 케이스
  integration/test_*.gd  # 통합 케이스 — run(tree, t), await tree.physics_frame
```

harness 두 개 모두 **발견/실행/집계/종료 코드만** 담당한다 (`D-015` 원칙 1).
테스트 로직을 harness에 넣지 않는다.

> **1-1 케이스를 추가할 때 반드시 지킬 것**: "경계를 넘지 않았다"만 단언하면
> **엉뚱한 장애물에 막혀도 통과한다.** 초기 구현이 실제로 그랬다 — 오른쪽 벽(x=950) 테스트가
> 안쪽 블록(x=608)에 막혀 x=598에서 멈췄는데 `x <= 950`이 참이라 통과했다.
> 그래서 지금은 **목표 벽에 실제로 닿았는지**도 함께 단언한다. 두 단언을 항상 쌍으로 넣는다.

## PHASE 2 — 1층 고정 지형 + 동적 배치

| # | 항목 | 필요 등급 | 상태 |
| --- | --- | --- | --- |
| 2-1 | **1층 고정성**: 시드를 바꿔도 지형이 항상 동일하다 | VERIFIED | ✅ 전역 시드를 흔들어도 해시 동일 |
| 2-2 | **경로 보장**: 시드 100~1000개에서 시작점→계단 접근 불가 0건 | VERIFIED | ✅ 시드 120개 · 접근 불가 0 · 안티 스킵 위반 0 |
| 2-3 | **동적 배치 결정성**: 동일 시드/세이브 재로드 시 전리품·유배자·상태 위치 불변 | VERIFIED | ✅ 저장→로드 왕복 동일 |
| 2-4 | 계단이 `party_stairs[]` 구조로 저장된다 (단일 stair_id 아님) | VERIFIED | ✅ 파티 3개 독립 + 저장 형식 |
| 2-5 | 1층 코드에 프로시저럴 **지형** 생성기가 없다 | VERIFIED | ✅ 가드 + 로더가 시드를 받지 않음 |
| 3-1 | **함정 단서 강제**: 치명 함정의 `clues[]`가 비면 실패 | VERIFIED | ✅ (PHASE 3 항목이나 P2-T3에서 선행 확보) |

> **PHASE 2 완료 — `PLAYTESTED` (2026-08-20).** 단위 **688단언** + 통합 **25단언**, 실패 0.
> `2-6` 오너 greybox PLAYTEST 완료 — 구역별 성격 분화(layout v2)와 통로 폭 수정본을 모두 재플레이했다.
> GPT 최종 독립 재검토에서 새 BLOCKER 없음.
> `D-019` 수치는 **Canon이 아니라 DESIGN 기준선**이므로 `floor1_layout.json`만 고치면 조정된다.
>
> 수치 이력: 524/20 (P2-T7) → 652/20 (`P2-REV-001~003`) → **688/25** (`P2-REV-004~007`).
>
> ### `P2-REV-004~007`에서 늘어난 회귀 테스트
>
> | 항목 | 추가한 것 |
> |---|---|
> | `P2-REV-004` | 통로 폭 1·2·3·5가 **정확히 그 폭**인지 (짝수 치우침 방향 포함) |
> | `P2-REV-005` | 악성 AI 어댑터 5종 — 후보 훼손·모르는 ID·NaN/INF·거대 점수·쓰레기 반환 |
> | `P2-REV-006` | 경계 밖 `Area2D` 접촉 E2E — 좌표가 아니라 **물리 접촉**을 본다 |
> | `P2-REV-007` | 공간 태그가 정의 해시에 들어가는지 + 태그 순서 무관성 |
>
> ### 변이 테스트로 가드 유효성을 증명했다
> 위반 3종을 실제로 주입하고 잡히는지 확인했다:
>
> | 주입한 위반 | 잡은 것 |
> | --- | --- |
> | 배포 데이터에 `tier_hint` 키 | 가드 (`D-016`) |
> | 치명 함정의 `clues[]` 제거 | `test_floor_population` (`FLR-011`) |
> | `FloorState`가 `TerrainMutationState` 소유 | 가드 (`FLR-024`) |
>
> **가드를 추가할 때는 항상 이 절차를 밟는다.** 통과만 하는 가드는 초록불만 준다.

## PHASE 3 — 상호작용/함정/파밍

| # | 항목 | 필요 등급 |
| --- | --- | --- |
| 3-1 | **함정 단서 강제**: 치명 함정의 `clues[]`가 비면 테스트 실패 | VERIFIED |
| 3-2 | 줍기/버리기/재로드 결과가 일관된다 | VERIFIED |
| 3-3 | 발사형 함정은 1회성이고 `fired` 상태가 저장된다 | VERIFIED |
| 3-4 | 함정 단서를 화면만 보고 알아챌 수 있는가 (도트 가독성) | **PLAYTESTED** |

## PHASE 4~5 — 전투 / 시간

| # | 항목 | 필요 등급 |
| --- | --- | --- |
| 4-1 | 세이브/로드 후 전투 상태가 무결하다 | VERIFIED |
| 4-2 | 공격 선딜·대시의 손맛, 적 공격 회피 난이도 | **PLAYTESTED** |
| 5-1 | 디버그 가속으로 3600초 재현 시 붕괴가 가장자리부터 순차 진행 | VERIFIED |
| 5-2 | 서든데스 상수가 `data/canon/`에서만 온다 (하드코딩 산발 없음) | VERIFIED |
| 5-3 | 계단 진입 시 2층 전환 | VERIFIED |

## 전 PHASE 공통 (회귀 테스트)

| # | 항목 | 필요 등급 |
| --- | --- | --- |
| G-1 | **AI 비의존성**: API 키 없음/네트워크 오류에도 핵심 루프가 플레이 가능 | VERIFIED |
| G-2 | **정보 비대칭**: 미발견 함정·계단·비밀이 UI나 AI 대화로 누출되지 않는다 | VERIFIED |
| G-3 | **세이브 마이그레이션**: 구조 변경 시 버전 상승 + 이전 세이브 처리 방식 기록 | VERIFIED |
| G-4 | **결정성**: 모든 랜덤은 시드 또는 결과가 저장돼 재로드 시 동일 복원 | VERIFIED |
| G-5 | AI가 GameState를 직접 mutate하는 코드 경로가 없다 | VERIFIED |
| G-6 | 스탯이 STR/AGI/INT 3종뿐이고 6스탯 잔재가 없다 | VERIFIED |
| G-7 | **NPC LOD 불변성**: 동일 seed/논리 시간에서 플레이어 경로로 LOD 승격·강등 시점이 달라도 NPC Canon 상태와 외부 사건 로그가 동일하다 | VERIFIED |

---

## 테스트 실행 방법 — D-015

PHASE 1부터 자동 테스트 러너는 **자체 `SceneTree` 스크립트**를 사용한다.
GUT 같은 외부 플러그인은 현재 도입하지 않는다.

```bash
godot --headless --path . --script res://tests/runner.gd
```

러너 계약:

- `tests/runner.gd`는 발견/실행/집계/종료 코드만 담당한다.
- 실제 테스트 로직은 가능한 한 순수 함수와 작은 assertion helper로 작성해 **프레임워크 중립**으로 유지한다.
- 테스트 1개라도 실패하면 non-zero exit code.
- runner/helper 유지비가 커지거나 fixture/mock/비동기/리포팅 요구가 반복되면 GUT 등 외부 프레임워크를 재검토한다.

기존 smoke test도 병행한다:

```bash
godot --headless --path . --import
godot --headless --path . --quit-after 180
godot --path .                         # 실제 창 실행 (개발 PC는 필요 시 ANGLE 옵션)
```
