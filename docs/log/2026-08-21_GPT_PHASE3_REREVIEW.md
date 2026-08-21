# GPT PHASE 3 재재검토 — 2026-08-21 10:16 KST

> 월간 로그 병합용 보조 기록. 다음 로컬 작업 가능한 Claude는 이 내용을 `docs/log/2026-08.md` 맨 아래에 병합한 뒤 본 파일을 삭제한다.

## 일시
- 2026-08-21 10:16 KST
- 검수 기준 main: `bc54f497897c8f8d264f333e13aced4d9e862ec3`
- 직전 GPT 검수 기준: `0438045c24a01579a2703e42a9bc353cf466ae9c`

## 담당
- 오너: Claude 재작업 지시 및 GPT 재검토 요청
- Claude: `P3-REV-001~004` + TrapRuntime null 계약 + 회귀/변이 테스트 수정
- GPT: 최신 main 독립 정적 재검토

## 요청
> 클로드 작업 다시 시켰으니까 재검토해봐

## 기존 지적 4건 재검토

### P3-REV-001 — 반복형 함정 단서
**통과.** `ClueView.shows_trace_for()`가 `fired`가 아니라 `armed`를 기준으로 판단한다. 반복형 치명 함정은 첫 발동 뒤에도 armed이므로 단서를 유지하고, one-shot 발사형은 disarm 뒤 단서를 숨긴다. 테스트도 복제 조건이 아니라 실제 `shows_trace_for()`를 호출하도록 보강됐다.

### P3-REV-002 — TerrainMutation RunSave
**통과.** `TerrainMutationState`가 JSON-native save schema와 `from_save_dict()`를 갖고, `WorldAnchor`/`CausalSource`도 복원 가능한 값으로 직렬화된다. `RunSave.from_text()`가 terrain을 실제 복원하며, 실제 `to_text → from_text` 왕복 테스트가 anchor/change/cause/tick을 확인한다.

### P3-REV-003 — 바닥 물건 WorldAnchor 주소
**통과.** `ground_items_here(WorldAnchor)` / `ground_items_in(region, layer)`로 교체했고 `InteractionService`와 `GroundItemView`가 region/layer를 구분한다. `put_ground_item()`은 다른 world의 anchor를 거부한다. 같은 cell·다른 region/layer 회귀 테스트가 추가됐다.

### P3-REV-004 — 내구 등급 손실
**통과.** `durability_grade`와 미래용 `durability_points`를 분리했고, `poor/fair` 등 저작 등급을 그대로 보존한다. 실제 floor1 loot → ItemInstance → RunSave 왕복 테스트가 추가됐다.

### 추가 정리
- `TrapRuntime.should_fire(state=null)` → false: 적절.
- envelope가 있는데 `stimulus.source==null`이면 차단: fail-closed로 적절.
- Claude 기록: 단위 986 + 통합 25, 실패 0, 변이 검증 4건 통과.

## 이번 재검토에서 새로 발견한 이슈

### P3-REV-005 [BLOCKER] — 실제 플레이 경로에서 wall_bolt가 플레이어에게 발동하지 않음

현재 데이터:
- wall_bolt: `accepts = ["touch", "impact"]`
- pitfall: `pressure`
- snare: `touch`, `pressure`

현재 실제 플레이 경로:
- `main._check_trap_underfoot()`는 플레이어가 새 cell에 들어갈 때 항상 `TrapStimulus.from_body(...)`만 만든다.
- `from_body()`는 항상 `Kind.PRESSURE`다.
- 따라서 **미발동 wall_bolt 위를 플레이어가 걸어도 `PRESSURE`는 accepts에 없어서 발동하지 않는다.**
- `from_thrown()`은 현재 실제 던지기 입력이 아직 없어서 테스트 전용 경로다.

기존 `test_traps.gd`의 wall_bolt 검증은 던진 돌 `IMPACT`로 먼저 발동시킨 뒤 body로 지나갈 때 다시 발동하지 않는지를 본다. 이때 body가 실패하는 이유는 one-shot 소모 때문일 수도 있지만, 애초에 `PRESSURE`가 wall_bolt에 허용되지 않아서일 수도 있다. 즉 **미발동 wall_bolt가 실제 플레이어의 정상 이동/접촉으로 발동 가능한지 검사하지 않는다.**

#### 수정 요구
- 새 Canon을 만들지 않는다. `PRESSURE/TOUCH/IMPACT` 분류 자체는 DESIGN이다.
- 다만 1층 저작 wall_bolt가 실제 플레이에서 죽은 함정이 되면 안 된다.
- 플레이어 본체 이동이 발생시키는 물리 사건을 한 종류의 `PRESSURE`로 과도하게 축약하지 말고, 저작 trigger mechanism과 실제 접촉이 연결되도록 구현한다.
- 구현 선택지는 Claude가 구조에 맞게 정한다. 예: body contact용 `TOUCH` 자극을 함께 평가하거나, 이동 접촉 사건을 여러 stimulus로 변환하는 adapter. **같은 함정을 한 프레임/한 진입에서 중복 발동시키지 않도록 한다.**
- 회귀 테스트는 반드시 **미발동 wall_bolt + 실제 live player traversal 경로**가 발동하는지를 본다. `TrapRuntime` 순수 함수만 호출하는 테스트로 끝내지 않는다.
- 가능하면 오너가 수정 후 wall_bolt를 한 번 직접 밟아/지나가 실제 발동을 확인한다.

### P3-REV-006 [BLOCKER] — `ItemService.drop()` 실패 시 아이템 소실 가능

`WorldState.put_ground_item()`은 이제 bool을 반환하며 foreign-world anchor 등을 거부한다. 그러나 `ItemService.drop()`은:
1. 인벤토리에서 먼저 `remove_from_inventory()`
2. `world.put_ground_item(instance, at)` 호출
3. 반환값을 무시하고 `true` 반환

한다.

현재 main은 envelope를 넘겨 foreign-world를 앞에서 막으므로 정상 UI 경로에서는 잘 드러나지 않는다. 하지만 `drop()`의 envelope 인자는 optional이고 서비스 계약은 **실패하면 상태를 바꾸지 않고, 복제/소실이 없어야 한다**고 스스로 명시한다. `envelope=null + foreign-world anchor`로 호출하면 아이템이 인벤토리에서 빠진 뒤 월드 삽입이 거부되어 **영구 소실**될 수 있다.

#### 수정 요구
- 가능한 한 remove 전에 destination/world 정합성을 검증한다. 또는 put 실패 시 동일 instance를 정확히 rollback한다.
- `drop()` 성공/실패를 transaction처럼 취급해 실패 시 인벤토리/월드 어느 쪽도 변하지 않아야 한다.
- 회귀 테스트: held item → `drop(... foreign anchor, envelope=null)` → false, 인벤토리에 같은 instance 유지, ground_items 변화 없음.
- `materialize_floor_loot()`도 `put_ground_item()` 반환값을 무시한 채 `made += 1`하므로, 같은 원칙으로 성공한 삽입만 카운트하거나 world/anchor 정합성을 assert/검증한다.

### P3-REV-007 [HIGH] — RunSave schema가 바뀌었는데 SAVE_VERSION이 여전히 1

`ItemInstance` 저장 필드가 `durability`에서 `durability_grade`/`durability_points`로 비호환 변경됐고 terrain mutation 저장 구조도 실질적으로 바뀌었다. 그런데 `RunSave.SAVE_VERSION`은 여전히 `1`이다.

출시 전 개발 세이브라 당장 사용자 데이터 문제는 작지만, 같은 version으로 옛 save를 받아 조용히 grade를 비우는 것은 save contract상 좋지 않다.

#### 수정 요구
- 가장 단순한 방법: `RunSave.SAVE_VERSION = 2`로 올리고 v1은 VERSION_MISMATCH 처리.
- 또는 정말 v1을 살려야 한다면 명시 migration을 구현한다.
- 현재 단계에서는 migration보다 version bump가 더 단순해 보인다. 이는 구현 결정이며 새 Canon이 아니다.

### DOC-REV-004 [LOW] — stale 문구 잔존

- `CURRENT_STATE.md` 뒤쪽의 역사적 "PHASE 3 티켓 타당성 검토"가 현재도 `RunState`/`WorldState`가 없다고 현재형으로 적혀 있다. 현재 상태 SSOT에서는 역사 기록으로 명확히 구분하거나 정리해야 한다.
- `scripts/core/main.gd` 상단에 여전히 `아직 없는 것: 상호작용... PHASE 3`, `DebugOverlay는 그때 삭제` 문구가 남아 있는데 둘 다 현재 사실과 다르다.
- `_check_trap_underfoot()` 발동 후 주석 `터진 함정의 흔적은 지운다 — 위험이 사라졌다`도 반복형 함정에서는 거짓이다. 실제 코드는 `refresh()` 후 `ClueView`가 armed 기준으로 올바르게 판단한다.

## 판정

- `P3-REV-001~004`: **재검토 통과**.
- Claude의 986/25 테스트와 4개 변이 검증은 유효하다.
- 그러나 `P3-REV-005`와 `P3-REV-006`이 새로 확인되어 **PHASE 4 착수는 아직 보류**한다.
- `P3-REV-007`과 `DOC-REV-004`도 이번에 함께 정리 권장.
- 005/006 수정 후 GPT가 해당 diff를 집중 재검토하고, wall_bolt 실제 경로를 오너가 짧게 확인하면 PHASE 3를 최종 확정하고 PHASE 4로 넘어갈 수 있다.

## 다음 AI에게
- [ ] `P3-REV-005` live player → wall_bolt trigger 경로를 실제 게임/E2E까지 수정·검증.
- [ ] `P3-REV-006` drop no-loss transaction 보장 + 실패 회귀 테스트.
- [ ] `P3-REV-007` RunSave version bump 또는 명시 migration.
- [ ] `DOC-REV-004` stale CURRENT_STATE/main 주석 정리.
- [ ] 전체 단위/통합 테스트 재실행.
- [ ] 005/006 각각 변이 또는 실패 주입으로 테스트가 실제 버그를 잡는지 확인.
- [ ] 본 보조 로그를 `docs/log/2026-08.md`에 병합 후 삭제.
- [ ] 완료 후 GPT 재검토 요청.

## 오너 결정 필요
현재 없음. 위 항목은 이미 확정된 Canon/서비스 불변식을 구현에 맞게 지키는 수정이며 새 세계관 결정을 요구하지 않는다.
