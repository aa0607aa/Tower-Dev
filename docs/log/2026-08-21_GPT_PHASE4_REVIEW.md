# GPT PHASE 4 독립 검토 — 2026-08-21 14:17 KST

> 월간 로그 병합용 보조 기록. main을 직접 수정하지 않기 위해 `gpt/phase4-review-20260821` 브랜치에 기록한다. 다음 로컬 작업 가능한 Claude는 본 내용을 `docs/log/2026-08.md` 맨 아래에 병합한 뒤 본 보조 파일을 삭제한다.

## 요청
오너: "페이즈4 검토하자"

## 검수 기준
- 저장소: `aa0607aa/Tower-Dev`
- 기준 main HEAD: `b8594786a83668772358f6ef28f71ad9f578b14d`
- PHASE 4 구현: `4b9fd00`, `4938265`
- 후속 수정: `1d393b9`(비행 중 함정 자극), `20edc47`(투사체 경로 sweep/벽/AccessEnvelope)
- Claude 최신 실행 기록: P4-FIX-002 후 단위 **1218** + 통합 **91**, 실패 0.
- 오너 결정: 던지기 자원은 PHASE 6, 돌이 안 통하는 함정 피드백은 PHASE 8로 보류. 둘 다 이번 blocker로 다시 올리지 않는다.

## 잘 된 부분
- `CBT-004`: 피해/크리티컬 경로에 난수 없음. 사건 기반 이유 보존.
- `CBT-010`: 성장효율을 `sqrt` 압축.
- `CBT-011`: BodyResilience를 피해 결과에 노출하지 않음.
- `CBT-012`: 무기 파라미터를 `weapons.json`으로 분리.
- `CBT-008`: 공격을 초 단위 wind-up/active/recovery로 모델링.
- Player/Enemy 양방향 실제 전투 E2E 존재.
- 투척물이 `TrapSensor`를 재사용하고, P4-FIX-002에서 함정/지형/AccessEnvelope를 별개로 판정하도록 개선.
- 빠른 투사체가 셀을 건너뛰는 문제에 path sweep 회귀가 추가됨.

## 새로 발견한 이슈

### P4-REV-001 [BLOCKER] — 전술 정지가 플레이어/상호작용까지 멈추지 않는다

`Main`은 `TimeScale.world_delta()==0`이면 적·공격 진행·투사체만 정지시킨다. 그러나 `Player._physics_process(delta)`는 엔진 delta를 그대로 사용하며 TimeScale을 알지 못한다.

결과:
- Tab으로 정지한 뒤에도 WASD로 플레이어가 이동 가능.
- 대시 중 정지하면 `_dash_left`는 월드 시간이 0이라 줄지 않는데 `_physics_process`는 `_dash_left>0`을 보고 계속 DASH_SPEED로 움직일 수 있다.
- `Main._check_trap_underfoot()`는 pause 여부와 무관하게 매 `_process` 호출되므로 정지 중 이동으로 함정을 건드릴 수 있다.
- E/Q 상호작용은 `_unhandled_input` 경로라 pause gate가 없어 줍기/버리기로 월드 상태를 바꿀 수 있다.

현재 E2E는 pause 중 **적 위치만** 고정되는지 검사해 이 구멍을 못 잡는다.

수정 요구:
- 완전 정지에서는 플레이어 이동/대시의 실제 motion과 월드 mutation을 만드는 상호작용도 정지.
- UI/정지 해제 입력은 계속 받을 수 있어야 한다.
- `Engine.time_scale`로 뭉개지 말고 현재 별도 월드 시간 구조를 유지.
- E2E: 이동키를 누른 채 pause → 플레이어 위치 0 변화; dash 도중 pause → 위치/대시 시간 변화 없음; pickup/drop/trap state 변화 없음; resume 후 정상 진행.

### P4-REV-002 [BLOCKER] — `4-1 세이브/로드 후 전투 상태 무결`이 실제로는 일부만 저장된다

`RunSave v3`가 저장하는 전투 데이터는 `Combatant`(vitality/armor/stats/weapon/alive)뿐이다.

반면 실제 전투 상태에는:
- Enemy 위치
- Enemy `AttackState`(wind-up/active/recovery, elapsed, hit_ids, direction)
- Enemy mode
- Player `AttackState`
- 현재 대시 상태/방향/쿨다운
- 전투 중 실제 위치

등이 있다.

`Enemy.to_save_dict()`는 position/attack/mode를 이미 만들지만 `WorldState.to_save_dict()`는 `Combatant.to_save_dict()`만 기록하므로 사용되지 않는다. `AttackState.from_save_dict()`도 단위 테스트만 있고 `RunSave`에는 연결돼 있지 않다.

현재 `test_combat_e2e`의 4-1은 플레이어 vitality와 죽은 적 `alive=false`만 확인해서 "전투 상태 무결"을 과하게 선언하고 있다.

수정 요구:
- Scene Node를 세이브 정본으로 만들지 말고 적절한 Run/World/Floor 수명주기의 runtime combat state를 데이터로 저장.
- 최소 회귀: 적을 원래 spawn에서 이동 → 공격 wind-up 중 저장 → RunSave roundtrip → position/phase/elapsed/direction/hit_ids/mode가 동일. Player도 mid-attack state가 보존.
- 대시가 PHASE 4 save contract에 포함될지, transient로 취급해 명시적으로 취소할지는 구현 계약을 명시하고 테스트. 조용히 리셋은 금지.

### P4-REV-003 [BLOCKER] — 큰 delta가 active 전체를 건너뛰면 공격이 헛친다

`AttackState.advance()`는 한 delta가 여러 구간을 넘을 수 있게 while로 처리하고, WIND_UP→ACTIVE를 통과하면 `entered_active=true`를 반환한다. 하지만 그 delta가 ACTIVE까지 전부 지나 RECOVERY/IDLE에 도달한 뒤 caller가 `CombatService.targets_in_arc()`를 부르면, 이 함수는 **현재 state.phase가 ACTIVE일 때만** 타격 대상을 반환한다.

예: starting dagger wind_up=0.10, active=0.08. 공격 시작 직후 0.20초 hitch가 오면 ACTIVE를 통과했지만 최종 phase는 RECOVERY. `advance()`는 true, 실제 타격 판정은 phase!=ACTIVE라 0명.

Player와 Enemy 둘 다 같은 패턴을 쓴다. 현재 frame-independence 테스트는 최종 phase만 비교하고 **피해 결과가 같은지**는 검사하지 않는다.

수정 요구:
- active 구간을 통과했다는 사건을 최종 phase와 분리해서 전달하거나, 시간 구간을 substep하여 active 시점의 hit resolution을 실제로 실행.
- coarse one-step delta와 fine many-step delta가 동일한 target/hit count/damage를 내는 회귀 + 변이 검증.

### P4-REV-004 [REVIEW/BLOCKER] — 명시적 TBD 수치를 구현이 임의로 채우고 테스트가 고정한다

`CBT-006`은 **무기별 스탯 가중치 정확한 값**을 TBD로 두고 "임의로 확정하지 않는다"고 한다. 그런데 `weapons.json`에는 dagger 0.5/0.5, shortsword 0.7/0.3, stone 0.8/0.2 등 구체 비율이 들어가 실제 피해에 사용된다. 주석은 DESIGN이라고 밝히지만 현재 테스트가 이 데이터의 동작을 정상 기준으로 보호한다.

또 `CBT-007`은 기습 보정의 방향만 Canon이고 **정확한 배율은 TBD**인데 `DamageModel`은 `AMBUSH_REFERENCE_REACH=40` 및 `1 + 40/reach`라는 구체 함수를 도입했다. 테스트는 sword bonus >1, dagger bonus>sword, 실제 피해 증가까지 고정한다.

이는 Canon으로 승격됐다는 뜻은 아니지만, 프로젝트의 "TBD는 임의 해결 금지" 운영 규칙과 충돌한다.

처리 선택지:
1. 오너가 이 값들을 **임시 PLAYTEST용 DESIGN baseline**으로 명시 승인하고, 조정 가능/비Canon이라는 계약을 결정 기록에 남긴다.
2. 승인 전에는 exact TBD 항을 중립 placeholder/비활성으로 두고 구조·방향만 구현한다.

GPT가 임의로 어느 쪽을 정하지 않는다. 오너 결정 필요.

### P4-REV-005 [HIGH] — 투사체는 함정/벽 경로는 sweep하지만 전투 대상은 endpoint만 본다

P4-FIX-002로 `_cells_between()`을 통해 함정과 지형은 경로 전체를 훑는다. 그러나 적 타격 `_hit_target()`은 `global_position=next` 이후 **현재 endpoint와 대상 중심의 거리 <=12px**만 본다.

따라서 낮은 FPS/프레임 hitch에서 돌이 적 사이를 지나도 양 끝점에서 12px보다 멀면 적을 관통한다. trap/wall tunneling은 고쳤지만 combat target tunneling은 남아 있다.

수정 요구:
- 이전→다음 위치 구간에서 target collision도 sweep/continuous 판정.
- 벽/함정/대상 중 무엇을 먼저 만났는지 순서가 결정적이어야 한다.
- coarse delta와 fine delta가 같은 첫 충돌 대상/피해를 내는 회귀 테스트.

## 문서 정리 [LOW]
- `CURRENT_STATE.md`와 `TEST_CHECKLIST.md`의 PHASE4 기준선은 1209/86인데 최신 P4-FIX-002 로그는 **1218/91**이다.
- `scripts/core/main.gd` 상단은 아직 "PHASE 3까지 / 전투는 PHASE4에서"라고 적혀 있다.
- `scripts/player/player.gd` 상단도 "전투는 PHASE4"라는 과거 문구가 남아 있다.
- `test_combat_e2e.gd` 설명은 공격이 `_unhandled_input`을 탄다고 적지만 실제 구현은 polling이다.

## 판정

- PHASE 4의 큰 아키텍처와 Canon 방향은 좋다.
- P4-FIX-001/002도 유효한 수정이다.
- 그러나 `P4-REV-001~003`이 실제 gameplay/save correctness BLOCKER라 현재 PHASE 4를 닫을 수 없다.
- `P4-REV-004`는 오너가 임시 DESIGN baseline 허용 여부를 결정해야 한다.
- `P4-REV-005`는 투사체 프레임 독립성 HIGH이며 PHASE 4 종료 전 같이 닫는 것을 권장한다.
- `4-2` 손맛 PLAYTEST는 위 correctness 수정 후 다시 하는 편이 낫다.

## 다음 AI에게
1. P4-REV-001 pause: Player motion/dash/world interaction까지 완전 정지 + actual E2E.
2. P4-REV-002 save: combat runtime state를 수명주기 데이터에 넣고 RunSave 실제 roundtrip 강화.
3. P4-REV-003 attack hitch: active interval을 건너뛰어도 hit event 유실 금지; coarse/fine damage 동일.
4. P4-REV-005 projectile target sweep + collision ordering + coarse/fine 동일.
5. P4-REV-004 exact TBD 수치는 오너 결정 전 임의 확정 금지.
6. 전체 단위/통합 + 각 문제의 변이 테스트.
7. 문서 수치/헤더 동기화.
8. 완료 후 GPT 재검토 요청.

## 오너 결정 필요
- `P4-REV-004`: 무기별 exact stat weights와 ambush exact function을 **임시 DESIGN/PLAYTEST baseline으로 사용 허용할지** 결정 필요.
