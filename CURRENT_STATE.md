# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-19

- **PHASE 0**: 완료 (`VERIFIED`)
- **PHASE 1 (이동/카메라)**: 완료 (`PLAYTESTED`)
- **PHASE 2 (1층 공간/상태/계단/세이브)**: **구현 완료에 가깝지만 최종 `PLAYTESTED` 전 검토/수정 대기**
  - [x] `P2-T0` Canon 가드 테스트
  - [x] `P2-T1` 공간 데이터 타입 (`WorldAnchor`, `AccessEnvelope`, 공유 `TerrainMutationState`)
  - [x] `P2-T2` 1층 고정 greybox + loader
  - [x] `P2-T3` 함정/파밍 정적 정의와 동적 상태 분리
  - [x] `P2-T4` AccessEnvelope 실제 Player 이동 연결
  - [x] `P2-T5` 계단 resolver
  - [x] `P2-T6` save/load + definition hash
  - [x] `P2-T7` 자동 회귀/변이 검증
  - [ ] **GPT 독립 검토에서 나온 pre-PHASE3 수정사항 처리**
  - [ ] **오너가 1층 layout v2 재플레이 후 최종 체감 판정**
- **PHASE 3**: 아직 착수하지 않는다. 위 두 항목을 닫은 뒤 진행.

- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **현재 검토 기준 HEAD**: `9e2b120fc2fb4135e1d4eba7e5f8828a648e9e1b`
- **엔진**: Godot `4.7.1-stable`
- **Canon 색인**: **149개 ID / 15도메인 / 통합 포인터 3개**
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지

## 최신 오너 확정 — D-018~D-023

### D-018 · 회차 시작 고정 문구

`[@회차 시작! 행운을 빕니다!]`

- 회차 시작 때 한 번 표시.
- 글자·띄어쓰기·기호 고정.
- 층 진입마다 반복하는 문구가 아니다.

### D-019 · 1층 greybox DESIGN 기준선

최종 Canon 숫자가 아니라 PLAYTEST 시작값:
- 긴 축 **160~220 타일**
- 주요 공간 **14~20개**
- 소형 파밍 포켓/막다른 길 **6~10개**
- 큰 순환 루프 **3~5개**

현재 layout v2는 긴 축 **172타일**, 방 17 + 포켓 8의 범위 안에 있다.

### D-020 · 1층 스폰 무기 품질

1층 스폰 무기는 **대체로 품질이 나쁘지만 초기 대거보다는 낫다.**
현재 `data/items/floor1_loot_table.json`의 무기/투사무기는 초기 대거 비교값보다 높게 두었다.

### D-021 · 오르골 초기 스탯 정정

- 힘 **8** / 민첩 **11** / 지능 **15**.
- ⚠ 설정서 v1.1 §24.1은 아직 8/12/14이므로 다음 설정서 개정 때 반영해야 한다.
- 그때까지 `D-021`이 정본이다.

### D-022 · 1층 시작 위치 랜덤화

- 1층 고정 지형과 별개로 시작 위치는 회차 시드로 선택한다.
- 후보 목록은 `FloorDefinition`, 실제 선택 결과는 `FloorState.start_cell`에 저장한다.
- 지형 고정(`FLR-001`)과 충돌하지 않는다.

### D-023 · 마인드맵 성장 구조

- 빨강=STR / 초록=AGI / 파랑=INT 고정.
- 숫자창 직접 배분이 아니라 연결된 색상 노드에 스탯 포인트를 투자.
- **노드 1개 = 포인트 1 = 대응 스탯 +1**.
- 한 가지의 스탯 노드 3개를 모두 채우면 스킬 노드에 도달하고 **즉시 랜덤 개화**.
- 개화 스킬에서 새 가지가 뻗으며, 중심에서 멀수록 기존 빌드와 연관성이 강해진다.
- 일정 전문화 깊이 이후 완전히 무관한 스킬은 후보에서 제외.
- 임의 respec은 기본 불가.
- 종족 변경 시 새 종족에 부적합한 스킬 subtree만 제거하고 해당 투자 포인트를 환원.
- 정확한 전문화 깊이/연관도 공식/태그/가지 수·형태는 TBD.
- 초기 PoE(2011~2013)는 `docs/reference/EARLY_POE_PASSIVE_TREE_REFERENCE.md`의 UX 참고일 뿐 Canon 출처가 아니다.

## PHASE 2 현재 구현 요약

### 1. 공간/월드 모델

- `WorldAnchor`: 실제 월드 공간 주소.
- `AccessEnvelope`: 유배자별 허용 영역/인과 경계.
- `TerrainMutationState`: 유배자별이 아니라 월드가 공유하는 지형 변경 상태.
- `FloorDefinition`: 1층의 고정 초기 정의.
- `FloorState`: 전리품/스폰/함정 상태/계단/발견/시작점 등 회차의 동적 결과.

### 2. 1층 layout v2

`data/floors/floor1_fixed/floor1_layout.json`을 구역별로 차별화했다.

- 서쪽 회랑: 열주형
- 입구 광장: 열린 공간
- 서쪽 납골: 분할된 좁은 셀
- 북쪽: 좁은 미로/회랑
- 중앙 대청: 큰 공간 + 내부 구조물
- 남쪽: 붕괴/공동처럼 불규칙한 공간
- 동쪽: 넓은 통로
- 최동단: 열린 큰 홀

통로 폭은 1/2/3/5칸을 섞고 꺾임을 추가했다.
`blocks`로 내부 기둥/칸막이를 파내며, `space_anchor_cell()`이 막힌 기하학적 중심 대신 실제 통행 가능한 대표 칸을 선택한다.

**GPT 검토 판단:** 구역 다양화 방향은 좋다. 다만 데이터 태그 `city`는 미래 시스템이 실제 도시 의미로 오해할 수 있으므로 `inner_complex`/`courtyard_complex` 같은 중립 이름으로 바꾸는 것을 권장한다. `opencaves`도 고대 사원의 붕괴·침식 구역이라는 테마 연결을 유지한다.

### 3. 계단 resolver

현재 구조:

```text
Engine candidate
→ Hard Constraint
→ Engine score
→ Optional AI ranking
→ Validator
→ 상위 band seeded selection
→ WorldAnchor 저장
```

BFS 실제 경로 비용을 사용하고, AI가 없어도 동작한다. 시작 위치는 `D-022`의 실제 `start_cell`을 사용한다.

**GPT 독립 검토 지적 — 2026-08-19 처리 완료:**

- ✅ **P2-REV-001 — AccessEnvelope-aware 경로 계산** (`a385668`)
  - 현재 BFS는 `FloorDefinition`의 모든 walkable 셀을 탐색하고, 후보 지점만 envelope 안인지 확인한다.
  - 향후 구멍/부분 허용 영역에서는 **경계 밖으로 나갔다 다시 들어오는 경로**를 유효 경로로 오판할 수 있다.
  - hard constraint의 경로 탐색 자체가 AccessEnvelope를 존중해야 한다.
  - fallback 후보도 반드시 envelope 내부에서만 선택해야 한다.
  - 현재 1층은 envelope가 초기 walkable 전체라 증상이 드러나지 않는다.
  - **처리**: BFS·fallback이 `envelope`을 받아 허용된 칸만 통과한다(`_passable()`).
    차단 띠로 지형은 이어져 있지만 허용 영역 안에서는 끊긴 회귀 테스트 추가.
  - **변이 검증**: envelope 검사를 제거하니 차단 띠 너머 **3645칸을 도달 가능으로 오판**하고
    fallback이 좁은 허용 영역 밖 `(173,18)`에 계단을 놓았다. 가상의 문제가 아니었다.

- ✅ **P2-REV-002 — 의미 없는 항상-참 테스트 제거** (`a385668`)
  - `tests/test_stair_resolver.gd`의 `p1.key() != p2.key() or true`는 항상 참이므로 아무것도 검증하지 않는다.
  - 같은 파티+시드 결정성은 유지하고, 서로 다른 party ID가 독립 stream에 참여함을 여러 seed에서 검증하거나 해당 assertion을 제거한다.
  - **처리**: 시드 120개 표본에서 party_1/party_2 결과가 다른 건수가 1건 이상임을 단언.
    한 시드에서 다르길 요구하지 않는다 — 우연히 같을 수 있다는 canon 유지.

### 4. 세이브/definition hash

- 실체화 결과를 저장하며 로드시 seed로 다시 생성하지 않는다.
- `FloorSave`는 `definition_hash`가 달라지면 `DEFINITION_CHANGED`를 반환한다.

**GPT 독립 검토 지적 — 2026-08-19 처리 완료:**

- ✅ **P2-REV-003 — definition_hash 계약 정리** (`35d43b1`)
  - 로더 주석은 “기하만 해시”라고 설명하지만 실제 해시는 방/통로/blocks뿐 아니라 trap/loot/spawn 위치·일부 속성도 포함한다.
  - 반대로 trap `lethal`, `one_shot`, `clues` 등 저장된 회차의 의미를 바꿀 수 있는 고정 정의 일부는 포함하지 않는다.
  - 따라서 **정말 spatial compatibility hash인지, immutable floor-definition hash인지 계약을 하나로 정한 뒤** 필드를 맞춰야 한다.
  - 장기 세이브 계약이 굳기 전인 지금 정리하는 편이 싸다.
  - **처리**: GPT 권고대로 **immutable floor-definition hash**를 택했다.
    함정 `lethal`/`one_shot`/`clues`, 시작점 후보, 층 정체성(floor_id·테마·월드·scope·layout_version)을 반영.
  - **변이 검증**: 함정 성질을 해시에서 빼니 3단언 실패.
  - ⚠ 해시가 `b4b3bf46 → 61c43cdb`로 바뀌었다. 배포된 세이브가 없어 영향은 없다.

### 5. AccessEnvelope 향후 주의

1층은 현재 `envelope_from_floor()`가 초기 walkable 영역을 허용한다.
그러나 `FLR-027`상 지형은 나중에 파괴/굴착 가능하므로, **행동 반경을 초기 통행 가능 셀과 영구적으로 동일시하면 안 된다.**
현재 구현은 PHASE 2 편의 함수로 분리되어 있어 구조 변경 여지는 확보돼 있다.

## PHASE 2 테스트 상태

Claude 기록 기준 최신 layout v2에서:

P2-REV 처리 후 (2026-08-19):

- 단위 **652 단언** 통과 (576 → 652, 회귀 테스트 +76)
- 통합 **20 단언** 통과
- 반복 3회 안정성 확인
- 변이 검증 3건 모두 실패 확인 — `velocity *= delta` / envelope 무시 / 함정 성질 해시 제외

GPT는 이 세션에서 Godot 런타임을 직접 재실행한 것이 아니라 **GitHub 코드/테스트/로그 정합성을 독립 검토**했다.

## PHASE 3 전에 할 일

1. ✅ **[Claude] P2-REV-001** — `a385668`. 변이 검증 완료.
2. ✅ **[Claude] P2-REV-002** — `a385668`. 표본 기반 검증으로 교체.
3. ✅ **[Claude] P2-REV-003** — `35d43b1`. immutable definition hash 채택, 변이 검증 완료.
4. ✅ **[Claude] 문서/주석 정리** — `main.gd` 상단, `FloorPopulator`의 `D-022` 누락 보완.
5. ✅ **[Claude] 태그 중립화** — `city` → `inner_complex`, `opencaves` → `collapsed_undercroft`.
   기하는 그대로다. 남쪽 공동을 별도 생태가 아니라 **무너진 사원 하부**로 못박았다 (`FLR-013`).
6. ✅ **[Claude]** 전체 재실행 — 단위 652 + 통합 20 통과, 변이 3건 검증.
7. ⏳ **[오너]** layout v2 재플레이 — **"지형이 훨씬 낫다"** 판정 받음(2026-08-19).
   밀도·규모 세부 판정은 아직 열려 있다.
8. ⏳ **[GPT]** P2-REV 수정 diff 재검토. 이상 없으면 PHASE 2를 닫고 PHASE 3로 이동.

## 구현 주의 / 장기 인계

- `D-021`: 다음 설정서 개정 때 오르골 8/11/15 반영.
- `D-023`: `CHR-020`의 “레벨 3당 스킬 후보” 표현은 PHASE 6 전에 “레벨당 포인트 DESIGN + 가지 3노드 완성 시 개화”로 정합화한다.
- 마인드맵 전문화 임계 깊이/연관도/태그/가지 수는 TBD — 구현 편의로 임의 확정 금지.
- `BASE_SPEED`는 PHASE 6에서 민첩 보정과 함께 재확정.
- PHASE 3에서 실제 함정/아이템 상호작용이 붙으면 `debug_overlay.gd` 삭제 예정.
- 다른 PC 작업 시 Godot `--import` 먼저.
- 배포 렌더링 경로는 PHASE 11 (`B-003`).
