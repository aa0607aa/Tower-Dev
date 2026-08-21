# GPT PHASE 3 최종 재검토 — 2026-08-21 11:02 KST

> 월간 로그 병합용 보조 기록. 다음 로컬 작업 가능한 Claude는 이 내용을 `docs/log/2026-08.md` 맨 아래에 병합한 뒤 본 파일을 삭제한다.

## 일시
- 2026-08-21 11:02 KST
- 검수 기준 main 코드 HEAD: `4aba83296301d14b8a91fe69a999c5ef3a331ea8`
- 직전 GPT 검수: `b56ab9ce60df81bcad9bcfa110fe3766fb5e6ce6`
- 이번 검토 중 기존 보조 로그 `2026-08-21_GPT_PHASE3_REREVIEW.md`는 월간 로그에 이미 병합된 것을 확인하고 삭제함 (`d231a163...`).

## 요청
> 재검토해봐

## Claude 수정 재검토

### P3-REV-005 — 실제 플레이 wall_bolt 발동
**통과.** `main._check_trap_underfoot()`가 `TrapStimulus.from_body_entering()`을 통해 `PRESSURE + TOUCH`를 한 진입 사건으로 보내고, `TrapRuntime.apply_all()`이 같은 함정의 중복 발동을 막는다.

새 통합 테스트 `tests/integration/test_trap_play_path_e2e.gd`는 `Main.tscn`을 실제로 띄우고 `Input.action_press()`로 Player를 wall_bolt 칸까지 이동시킨 뒤 `FloorState` 발동/무장해제를 확인한다. 이전처럼 runtime만 직접 호출하는 테스트가 아니라 실제 게임 경로를 탄다.

### P3-REV-006 — drop 트랜잭션
**통과.** 목적지/소유 여부를 제거 전에 검증하고, `put_ground_item()`이 실패할 경우 인벤토리로 복구한다. foreign-world anchor + envelope=null 실패 경로에서 같은 item instance가 인벤토리에 남고 ground state가 변하지 않는 회귀 테스트가 추가됐다. `materialize_floor_loot()`도 실제 삽입 성공만 카운트한다.

### P3-REV-007 — RunSave version
**통과.** `RunSave.SAVE_VERSION = 2`. v1은 `VERSION_MISMATCH` + `run=null`로 명시 거부한다. 출시 전이라 migration을 만들지 않은 판단도 적절하다.

### DOC-REV-004
**통과.** `main.gd`의 PHASE 2/3 stale 주석과 반복형 함정 흔적 설명, `CURRENT_STATE`의 역사적 RunState/WorldState 진단 표기가 정리됐다.

### 자동 검증
Claude 기록: 단위 `998` 단언 + 통합 `37` 단언, 실패 0. P3-REV-005/006/007 관련 변이 검증도 통과.

## 이번 재검토에서 남은 1건

### P3-REV-008 [BLOCKER TO PHASE 4] — 비플레이어 물리 자극의 **실제 게임/E2E 경로가 아직 없음**

`docs/design/PHASE3_IMPLEMENTATION_HANDOFF.md`의 `P3-T5` 완료 조건은 다음을 명시한다:
- 정상 메커니즘을 만족하는 **비플레이어 물리 자극으로도 발동 가능한 E2E를 반드시 둔다** (`FLR-028`).

현재 상태:
- `test_traps.gd`는 `TrapStimulus.from_thrown()` / `from_independent()`를 직접 만들고 `TrapRuntime`에 넣어 규칙을 검증한다. 이것은 runtime 단위 검증으로는 좋다.
- 그러나 실제 `Main` 게임 경로가 생산하는 자극은 현재 Player body 진입(`from_body_entering`)뿐이다.
- 던지기 입력/월드 물체 충돌→TrapStimulus adapter는 아직 없다. Claude 작업 로그도 `from_thrown()`은 현재 테스트 전용이며 던지기 입력은 아직 없다고 적었다.
- 즉 직전 `P3-REV-005`에서 드러났던 것과 같은 종류의 사각지대가 **비플레이어 자극 쪽에는 아직 남아 있다**: runtime은 가능하지만 게임이 그 자극을 실제로 생산하는지는 검증되지 않았다.

#### 최소 수정 요구
전체 투척/전투 시스템을 PHASE 3에 당겨올 필요는 없다.
다만 PHASE 3 인계서의 완료 조건을 지키려면 최소한 production 경로로 재사용할 **물리 접촉/충격→TrapStimulus adapter**를 하나 두고, 테스트용 비플레이어 물체가 그 adapter를 통해 wall_bolt를 실제로 발동하는 integration/E2E를 추가한다.

예시 방향(구조는 Claude가 결정):
- `TrapContactAdapter` / `TrapEventService` 같은 production adapter
- Player body 진입도 가능하면 같은 adapter를 사용
- 테스트에서는 dummy thrown/independent body 또는 충격 사건을 실제 adapter에 전달
- `TrapRuntime` 직접 호출만으로 완료 처리하지 않는다
- 유배자가 던진 물체라면 `CausalSource.THROWN` + `AccessEnvelope` 경계를 실제 경로에서 유지

새 Canon을 만들지 않는다. `PRESSURE/TOUCH/IMPACT`는 계속 DESIGN이다.

## PLAYTEST 상태

`TEST_CHECKLIST` 규칙상 `PLAYTESTED`는 오너만 판정한다.
오너의 기존 `3-4 잘 보여` 판정은 단서 표현에 대해서는 유효하지만, 그 뒤 `P3-REV-005`로 **실제 wall_bolt 플레이 동작이 변경**됐다.
따라서 코드/자동검증은 통과했지만 최신 수정본의 PHASE 3 전체 상태를 다시 `PLAYTESTED`로 잠그기 전에 오너가 wall_bolt 하나를 직접 지나가 확인하는 것이 맞다.

권장 확인: `tr_bolt_plaza (24,58)` — 지나갈 때 `함정이 작동했다` 표시, one-shot 무장해제 후 해당 단서 흔적 소멸.

## 문서 후처리

- `CURRENT_STATE.md`는 아직 PHASE 3를 `PLAYTESTED` 완료로 표시한다. P3-REV-008/오너 재확인 전에는 엄밀히 최신 상태와 어긋난다.
- `docs/TEST_CHECKLIST.md`의 PHASE 3 종료 문단은 아직 `929/25`로 적혀 있으나 현재 기록은 `998/37`이다.
- `3-5`는 VERIFIED로 표시돼 있지만 원래 PHASE3 인계서가 요구한 **비플레이어 E2E**가 아직 충족되지 않았다.

다음 Claude 작업 때 위 3개 문서를 함께 동기화한다.

## 판정

- `P3-REV-005~007`, `DOC-REV-004`: **재검토 통과**.
- 새 코드 회귀는 발견하지 못했다.
- 다만 원래 PHASE 3 완료 조건 `P3-T5`의 비플레이어 물리 자극 E2E가 아직 엄밀히 미충족이므로 **PHASE 4는 한 번만 더 보류**.
- `P3-REV-008` 최소 E2E 추가 + 오너 wall_bolt 직접 확인 후 PHASE 3를 최종 `PLAYTESTED`로 닫고 PHASE 4 진입 권장.

## 다음 AI에게
- [ ] `P3-REV-008`: 비플레이어 물리 자극을 production adapter를 거쳐 실제 함정에 전달하는 integration/E2E 추가.
- [ ] 가능하면 Player 진입도 같은 adapter를 써서 stimulus 생산 경로를 하나로 모은다.
- [ ] 외부 물체가 유배자 인과면 AccessEnvelope를 실제 경로에서 검증한다.
- [ ] 전체 단위/통합 테스트 재실행 + 변이/실패 주입으로 새 E2E 유효성 확인.
- [ ] `CURRENT_STATE.md`/`TEST_CHECKLIST.md` 수치·상태 동기화.
- [ ] 오너가 wall_bolt 직접 확인하면 PLAYTESTED 최종 확정.
- [ ] 본 보조 로그를 `2026-08.md`에 병합 후 삭제.

## 오너 결정 필요
새 설정 결정 없음. 오너에게 필요한 것은 수정 후 wall_bolt 실제 플레이 확인뿐이다.
