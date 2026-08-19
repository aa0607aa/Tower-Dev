# GPT PHASE 2 독립 검토 — 2026-08-19 13:24 KST

> **월간 로그 인계용 보조 기록.**
> GitHub 커넥터의 기존 `docs/log/2026-08.md` 갱신은 파일 전체 교체 방식인데, 현재 월간 로그가 약 100KB이고 직전 merge conflict 이력까지 있어
> 불완전한 본문으로 덮어쓰는 위험을 피하기 위해 이번 검토를 우선 이 파일에 보존한다.
> **다음 로컬 작업이 가능한 AI는 이 항목을 `docs/log/2026-08.md` 맨 아래에 병합한 뒤 이 보조 파일을 삭제할 것.**

## 담당

GPT — 코드/테스트/Canon/문서 독립 검토

## 요청

> 한도 때문에 잠깐 쉬고있는데 지금까지 된거 검토해볼래?

## 검토 범위

- Git `main` HEAD 및 최근 PHASE 2/layout v2 커밋
- `data/floors/floor1_fixed/floor1_layout.json`
- `FloorDefinition`, `FloorDefinitionLoader`, `FloorState`, `FloorPopulator`
- `AccessEnvelope`, `AccessService`
- `StairResolver`, `tests/test_stair_resolver.gd`
- `FloorSave`
- `scripts/core/main.gd`
- D-021/D-022/D-023 및 현재 Canon/인계 정합성

## 판정

**PHASE 2의 큰 구조와 layout v2 방향은 양호하다.**
다만 PHASE 3 진입 전에 고치는 것이 싼 **차단급 2건 + 세이브 계약 1건**이 발견됐다.
오너의 layout v2 재플레이도 아직 필요하므로 현재 PHASE 2를 `PLAYTESTED`로 닫지 않는다.

## P2-REV-001 — StairResolver의 경로 계산/fallback이 AccessEnvelope를 완전히 존중하지 않음

현재 resolver는 BFS 경로를 `FloorDefinition.walkable` 전체에서 계산하고 후보 위치에 대해서만 `AccessEnvelope.contains()`를 본다.
따라서 향후 허용 영역에 구멍이 있거나 월드의 일부만 유배자에게 허용되는 층에서는 다음 문제가 가능하다.

1. 후보 자체는 허용 영역 안이지만, **경계 밖으로 나갔다 다시 들어와야만 도달 가능한 경로**를 도달 가능하다고 오판.
2. hard constraint 후보가 0개일 때 fallback이 envelope 필터 없이 최장거리 walkable을 고르면 **맵의 끝 밖에 계단이 생길 가능성**.

현재 1층 `envelope_from_floor()`는 사실상 초기 walkable 전체를 허용하므로 기존 테스트로 증상이 가려져 있다.

### Claude에게

- BFS가 envelope를 받아 **허용된 셀만 통과**하도록 수정.
- fallback도 envelope 안에서만 후보 선택.
- 테스트용 envelope에 구멍/차단 띠를 만들고, 원래 지형 그래프는 연결됐지만 envelope 안에서는 끊긴 케이스를 추가.
- hard constraint 후보가 0개가 되는 케이스를 강제해 fallback도 envelope 밖으로 나가지 않는지 검증.

## P2-REV-002 — 파티별 계단 테스트에 항상 참인 assertion 존재

`tests/test_stair_resolver.gd`에 다음 형태가 있다.

```gdscript
t.assert_true(p1.key() != p2.key() or true, ...)
```

`or true` 때문에 이 단언은 어떤 구현에서도 통과하며 실제 회귀 방지 효과가 없다.

### Claude에게

- 이 단언을 제거하거나,
- 같은 `party_id + seed`는 항상 동일하다는 결정성을 유지하면서,
- 서로 다른 party ID가 RNG key에 실제로 참여하는지를 여러 seed 표본에서 검증하는 테스트로 교체.
- 단, 서로 다른 파티가 우연히 같은 좌표를 받을 수 있다는 Canon은 유지할 것.

## P2-REV-003 — `definition_hash`의 의미와 실제 포함 필드가 불일치

`FloorDefinitionLoader`의 설명은 해시를 “기하만 반영”한다고 하지만 실제 hash에는
방/통로/blocks뿐 아니라 trap/loot/spawn 위치 및 trap type도 일부 포함된다.
반대로 저장된 회차의 의미를 바꿀 수 있는 trap의 `lethal`, `one_shot`, `clues` 같은 고정 정의는 빠져 있다.

`FloorSave`는 이 hash를 **과거 세이브가 현재 층 정의와 호환되는지 판단하는 계약**으로 사용하므로 지금 의미를 정리해야 한다.

### Claude에게

둘 중 하나를 명확히 택할 것.

1. **spatial compatibility hash**: 저장 좌표가 어긋나는 변경만 반영하고 이름/주석도 그렇게 변경.
2. **immutable floor-definition hash**: 저장된 회차의 의미에 영향을 주는 불변 정의를 전부 canonical serialization한 뒤 hash.

GPT 권고는 2번이다. PHASE 2 시점에는 데이터가 작고 세이브 포맷도 아직 굳지 않아 지금 고치는 비용이 낮다.

## layout v2 검토

구역별 성격 분화 자체는 **v1보다 명백히 개선 방향**이다.
좁은 회랑/열주, 열린 광장, 납골 셀, 북쪽 미로, 중앙 대청, 남쪽 붕괴 공동, 넓은 동쪽 통로, 최동단 홀처럼
동선 밀도와 통로 폭을 섞은 것은 `FLR-013` 고대 사원풍과 충돌하지 않는다.

다만 JSON 태그의 `city`는 DCSS의 레이아웃 용어를 그대로 가져온 **구현 참고어**라 미래 AI/콘텐츠 시스템이 실제 “도시” 의미로 오해할 수 있다.
기하를 바꾸지 않고 `inner_complex`, `courtyard_complex`, `compound` 같은 세계관 중립 태그로 교체하는 것을 권장한다.
`opencaves`도 별도 생태 바이옴이라기보다 **무너진/침식된 사원 하부 공동**으로 연출해 한 사원이라는 통일감을 유지한다.

## D-022 검토

**문제 없음.**
1층 초기 지형/함정 구조가 고정이라는 `FLR-001`과, 유배자가 어느 고정 후보에서 시작하는지가 회차마다 바뀌는 것은 별개다.
오히려 특정 한 경로만 외우는 대신 맵 전체 지식을 요구하므로 `FLR-015`의 지형 암기 성장과 잘 맞는다.

## `space_anchor_cell()` 검토

**현재 PHASE 2 구현으로는 타당하다.**
불규칙한 공간에서 기하학적 중심이 block 안에 들어가는 문제를 결정적으로 회피하고, 대표 칸을 후보 생성 입력으로 쓰는 것은 `FAC-012/D-016`과 충돌하지 않는다.

다만 “named space당 대표 셀 1개”를 최종 Canon 계단 후보 시스템으로 굳히면 안 된다.
D-016의 최종 계단 시스템은 스토리/POI/위험/지형 접근비용 및 정상 바닥이 아닌 WorldAnchor까지 후보로 확장된다.
현재 방식은 PHASE 2 skeleton이다.

## AccessEnvelope 장기 주의

현재 1층 편의 함수는 초기 walkable을 허용 영역으로 만든다.
하지만 `FLR-027`상 벽/지형은 미래에 파괴·굴착될 수 있으므로 **AccessEnvelope = 최초 통행 가능 셀**로 영구 정의해서는 안 된다.
굴착으로 벽을 뚫었는데 바로 맵의 끝에 막히는 일이 생길 수 있다.
현재 코드가 AccessEnvelope를 별도 객체로 분리해둔 것은 맞는 방향이며, 지형 파괴 구현 전에 authored access region으로 독립시켜야 한다.

## 문서/주석 정합성

- `CURRENT_STATE.md`가 P2-T2~T7을 아직 미착수처럼 표시하고 있어 이번 GPT 검토에서 최신 상태로 동기화했다.
- `scripts/core/main.gd` 상단 주석은 아직 “P2-T3/T4/T5/T6 없음”이라고 적지만 실제 코드는 이미 population/access/stair를 사용한다. 다음 코드 수정 때 주석 갱신.
- `FloorPopulator` 상단 “시드가 정하는 것” 설명에 `D-022` 시작 위치가 빠져 있다. 코드 자체는 시작 위치를 별도 RNG stream으로 정상 처리한다.
- `D-021` 8/11/15는 현재 정본이며 다음 Setting Bible 개정 때 §24.1을 반드시 수정.

## 테스트/구현 상태 평가

Claude 기록 기준 layout v2 최신 실행:
- 단위 576 단언 통과
- 통합 20 단언 통과
- 반복 3회 안정성 확인
- 실제 Player E2E 변이 테스트도 `velocity *= delta` 주입 시 실패 확인

테스트를 변이 주입으로 검증하는 습관과 FloorDefinition/FloorState 분리는 전반적으로 잘 되어 있다.
이번에 발견한 문제는 “테스트 수가 부족하다”기보다 **현재 1층 envelope가 넓어 경계 케이스가 존재하지 않아 구조적 구멍이 가려진 것**에 가깝다.

## 다음 AI에게

- [ ] **[Claude] P2-REV-001** — StairResolver route/fallback을 AccessEnvelope-aware로 수정 + 구멍/차단 envelope 회귀 테스트.
- [ ] **[Claude] P2-REV-002** — `or true` 무효 테스트 제거/대체.
- [ ] **[Claude] P2-REV-003** — definition_hash 계약을 하나로 정하고 포함 필드/테스트 정리. GPT는 immutable definition hash 권고.
- [ ] **[Claude]** `main.gd`, `floor_populator.gd`의 오래된 PHASE/seed 설명 주석 정리.
- [ ] **[Claude] 권고** — layout `city` 태그를 세계관 중립 이름으로 변경. 기하 자체는 유지.
- [ ] **[Claude]** 수정 후 전체 단위/통합/변이 테스트 실행 및 `docs/log/2026-08.md`에 결과 기록.
- [ ] **[Claude]** 이 보조 로그의 내용을 월간 `docs/log/2026-08.md` 맨 아래에 병합하고 이 파일 삭제.
- [ ] **[오너]** layout v2 재플레이: 구역별 차이가 실제로 체감되는지, 밀도/규모가 적절한지 판정.
- [ ] **[GPT]** Claude 수정 diff를 빠르게 재검토. 이상 없고 오너 PLAYTEST 통과 시 PHASE 2 종료 후 PHASE 3 진입.

## 오너 결정 필요

새 Canon 결정은 **없음**.
오너에게 필요한 것은 layout v2의 **체감 PLAYTEST 판정**뿐이다.

## 산출물

- `CURRENT_STATE.md` 최신 상태 동기화
- 이 GPT PHASE 2 독립 검토 로그
