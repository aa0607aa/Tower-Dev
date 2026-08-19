# PHASE 2 구현 인계 — D-016 최종안

> **상태: APPROVED DESIGN / PHASE 2 진행 중 / P2-T2 착수 가능**
>
> 오너 최종 승인: D-016/D-017(2026-08-18), D-019/D-020(2026-08-19)
> 구현 담당 Claude는 이 문서와 `DECISIONS.md D-016/D-017/D-019/D-020`을 기준으로 PHASE 2 티켓을 구현한다.
> 새로운 Canon/TBD가 필요하면 임의 확정하지 말고 중단 후 오너에게 요청한다.

---

## 1. 이번 승인으로 확정된 핵심

### 1.1 1층 함정

- 위치·종류·구조는 **고정**이다.
- 동적인 것은 활성/소모 상태, 루팅/전투 흔적 등이다.
- 치명 함정 단서는 `FLR-011`을 따른다.

### 1.2 실제 월드와 층

- 한 층은 독립 포켓맵이 아니라 **실제 월드 공간의 특정 영역**이다 (`D-017`).
- 물리적 진실은 `WorldState`에 하나만 존재한다.
- 같은 월드의 같은 좌표를 여러 유배자가 보게 되면 **지형 mutation, NPC 생존/위치, 실제 물체 상태 등 물리 상태를 공유**한다.
- 유배자별로 갈리는 것은 `AccessEnvelope`, 개인/공동 목표 상태, 계단 귀속/발견 같은 탑 규칙이다.

### 1.3 맵의 끝 — 인과 경계

`AccessEnvelope`는 캐릭터 몸만 막는 충돌벽이 아니다.

**경계를 넘을 수 없음**:
- 유배자 본체
- 유배자가 소환/직접 통제하는 소환물·펫
- 유배자가 발사한 투사체
- 유배자의 기술/마법/범위 효과가 만들어내는 직접 영향
- 유배자가 던진/발사한 물체
- 유배자의 공격·스킬·밀치기 등으로 강제 이동 중인 NPC/물체

**자유롭게 통과 가능**:
- 일반 NPC·야생동물이 자기 행동으로 이동하는 경우
- 유배자의 직접 인과에서 벗어난 독립적인 월드 시뮬레이션

경계에 닿은 투사체/효과를 파괴·소멸·충돌·절단 중 어떤 표현으로 처리할지는 DESIGN이다.
중요한 Hard Rule은 **유배자가 원인이 된 직접 영향이 경계 밖 월드에 효과를 발생시키지 못한다**는 것이다.

### 1.4 계단 배치 — 공정한 악의

계단은 층 진입 시 한 번 resolve/create한다 (`FAC-012`).
고정 후보 지점 테이블에서 단순 선택하지 않는다.

권장 파이프라인:

```text
1. Engine candidate generation
   - 스토리/POI/월드 공간/위험/지질/구조를 보고 희소 후보 생성

2. Hard constraints
   - 메인 스토리/층 목적과 정합
   - 층을 사실상 즉시 스킵하게 만드는 위치 금지
   - 허용 맵 규모 대비 최소 상대 거리 확보
   - 최종적으로 도달 가능해야 함
   - 서든데스/스토리 시간 예산 안에서 현실적인 공략 가능성이 있어야 함
   - 정상 바닥일 필요 없음: 보스 침소 아래, 천장 위 공동, 굴착 후 접근 가능한 공간 등 허용

3. Engine quantitative score
   - route-distance percentile
   - danger exposure
   - discovery cost
   - terrain/access cost
   - anti-skip score
   - story relevance
   - recent placement pattern repetition penalty 등

4. Optional AI ranking
   - AI는 후보를 새로 만들어 GameState를 직접 바꾸지 않는다.
   - 엔진이 준 합법 후보에 대해 스토리 의미/귀찮음/의외성을 구조화 점수와 근거로 반환한다.
   - AI 응답 실패 시 이 단계를 건너뛰고 엔진 점수만 사용한다 (`SYS-007`).

5. Engine validator
   - AI 점수와 무관하게 모든 Hard Constraint 재검증

6. Top-band seeded selection
   - 점수 1등 한 곳을 항상 고르지 않는다.
   - 상위 후보 밴드에서 seed 기반 가중 선택해 역산 가능성을 낮춘다.
   - 정확한 band/가중치는 DESIGN, 플레이테스트 조정 대상.

7. Materialize + save
   - `party_stairs[]`에 `WorldAnchor`로 실체화
   - 생성 결과가 진실. seed도 디버그용으로 저장
   - 로드 때 재계산/리롤 금지
```

계단은 생성 후 월드 좌표에 고정되고 파괴 불가다 (`FAC-013`).
지지 지형이 파괴되어도 계단 좌표와 존재는 유지된다.

### 1.5 공간/상태 구조

확정 방향:

```text
RunState
└─ WorldState
   ├─ WorldTerrainDefinition / TerrainBody
   │  ├─ 실제 공간/지질/재료 정의
   │  └─ TerrainMutationState     # 같은 월드의 모든 유배자가 공유
   │
   ├─ FloorDefinition
   │  ├─ world_region_ref
   │  ├─ geology_region_ref (자연 지형이면)
   │  ├─ story/objective graph
   │  ├─ authored overlay / POI
   │  └─ floor rules
   │
   └─ FloorState
      ├─ loot / NPC / trap dynamic state
      ├─ party_stairs[]
      ├─ sudden-death / event state
      └─ access_by_exile_or_party[] -> AccessEnvelope
```

**중요**:
- `TerrainMutationState`를 유배자별 `FloorState`에 복제하지 않는다.
- `AccessEnvelope`는 실제 월드의 끝이 아니다.
- `Rect2i`는 broad-phase 최적화용일 수 있지만 행동 반경 정본이 아니다.
- 1층 TileMapLayer는 저작/표시 입력으로 사용할 수 있다.
- `FloorDefinition`은 1층 authored map과 2층+ generator가 공통으로 출력/소비하는 불변 런타임 표현으로 둔다.

### 1.6 지질 정보는 실제 파일로 보존

완전한 행성 시뮬레이션을 PHASE 2에서 만들 필요는 없지만, **지질 정의 자체를 채팅/설정 산문에만 두지 않는다.**

- 계약: `data/worlds/README.md`
- 스키마: `data/worlds/geology_profile.schema.json`
- 실제 월드/천체가 작성될 때: `data/worlds/<world_id>/geology_profile.json`

행성이라면 최소한 다음 정도는 파일에 기록할 수 있어야 한다.
- 전체 반지름/크기
- 내핵·외핵·맨틀·지각 등 레이어 경계
- 레이어별 성분/재료 비율
- 지역 지질 프로필/재료 비율

값이 미정이면 숫자를 지어내지 않는다. `status=TBD`, `null`/빈 배열로 남긴다.

각 `FloorDefinition`은 자연 지형인 경우 `world_region_ref + geology_region_ref`로 이 정의를 참조한다.
1층 같은 인공 구조물은 material/structure/durability 인터페이스를 공유하되 행성 레이어를 억지로 만들지 않는다.

### 1.7 1층 greybox 시작 범위 — D-019

`P2-T2` 첫 구현은 아래를 **PLAYTEST용 DESIGN 기준선**으로 사용한다. 원문 Canon 숫자가 아니다.

- 긴 축 **160~220 타일**
- 주요 공간 **14~20개**
- 소형 파밍 포켓/막다른 길 **6~10개**
- 큰 순환 루프 **3~5개**
- 민첩 10 기준, 전투·루팅·함정 확인 없이 숙련자가 핵심 동선만 주행하면 **수 분대**

구조 원칙:
- 고대 사원풍 고정 미로이되 길찾기 자체가 주 난관이 될 정도로 과도하게 복잡하게 만들지 않는다.
- 여러 우회·매복·파밍 선택지는 확보한다.
- 초반 구간은 대체로 공평하게 두고, 위험은 진행하며 높아질 수 있다.
- 3600초를 순수 이동 거리로 채우지 않는다. 1시간은 탐색/함정/전투/루팅/추가 파밍 욕심까지 포함한 시간 예산이다.
- 최종 크기와 공간 수는 `P2-T7` 오너 PLAYTEST에서 DESIGN 범위로 조정할 수 있다.

참고 정본: `docs/reference/FLOOR1_NOVEL_SOURCE_NOTES.md`.

### 1.8 1층 파밍 무기 품질 — D-020

- 1층 스폰 무기는 **대체로 품질이 나쁘지만 초기 대거보다는 낫다** (`FLR-014`).
- 이전의 "대거보다 못할 수도 있다"는 일반 규칙은 폐기됐다.
- 파밍 지점 랜덤 배치, 석궁 수준 투사무기 상한, 총기 극저확률은 기존 규칙을 유지한다.
- 이 항목은 PHASE 3 아이템 구현에 직접 반영하고, P2-T2 greybox에서는 파밍 지점/공간 설계만 막히지 않게 준비한다.

---

## 2. PHASE 2 구현 범위

PHASE 2에서 **해야 하는 것**:

1. `WorldAnchor`, `TerrainBody`/월드 공간 참조, `FloorDefinition`, `FloorState`, `AccessEnvelope`의 최소 스키마 경계를 잡는다.
2. 1층 고정 greybox를 저작하고 `FloorDefinition`으로 로드한다.
3. 1층 함정 **고정 정의**와 동적 상태를 분리할 수 있는 포맷을 만든다.
4. `party_stairs[]` 수명주기와 저장 포맷을 만든다.
5. 계단 resolver의 **인터페이스와 Validator/결정성 경계**를 만든다. 실제 고급 AI ranking은 PHASE 9 AI Bridge까지 stub/fallback 가능.
6. 결과 저장 + seed + `floor_definition_version/hash`를 둔다.
7. 지질 profile 스키마와 floor→world/geology 참조 필드를 막히지 않게 둔다.
8. 공유 월드 mutation과 유배자별 AccessEnvelope가 데이터 책임상 섞이지 않도록 테스트한다.

PHASE 2에서 **하지 않는 것**:

- 전체 행성 복셀/지질 시뮬레이션
- 현실 물리 수준의 굴착/붕괴 계산
- 최종 재료 저항/도구 효율 수치
- AI API를 실제 계단 resolver의 필수 의존성으로 만들기
- 2층+ 전체 프로시저럴 월드 생성기 구현

---

## 3. 권장 티켓

### P2-T0 · Canon/스키마 가드 — 완료
- D-016/D-017 기준 테스트 계약 작성.
- 함정 타입 랜덤화, 단일 stair_id, 유배자별 terrain 복제 같은 금지 구조를 테스트/리뷰 체크로 박는다.

### P2-T1 · 공간 데이터 타입 — 완료
- `WorldAnchor`
- `TerrainBodyRef`
- `FloorDefinition`
- `FloorState`
- `AccessEnvelope`
- `TerrainMutationState` 소유권 경계

완료 조건: 같은 좌표의 물리 상태가 유배자 ID에 따라 복제되지 않는다.

### P2-T2 · 1층 greybox + loader — **지금 착수 가능**
- `TileMapLayer + meta` 저작
- loader → `FloorDefinition`
- 시드가 바뀌어도 초기 지형/함정 정의 해시 동일
- **D-019 기준선**: 긴 축 160~220 / 주요 공간 14~20 / 소형 포켓 6~10 / 큰 루프 3~5
- 숙련 핵심동선 수 분대를 목표로 하고, 3600초는 파밍/위험 감수까지 포함한 시간 예산으로 본다.
- `TestRoom.tscn`은 Canon 지형으로 승격하지 말고 이 단계에서 폐기/교체한다.

### P2-T3 · 1층 함정/파밍 정적·동적 분리
- 함정 위치/종류/구조 고정
- `armed/fired` 등만 상태
- loot 내용물/유배자 배치 등 기존 랜덤 범위 유지
- `tier_hint` 없음
- 무기 품질은 `D-020/FLR-014`: **저품질이어도 대체로 초기 대거보다 낫다**

### P2-T4 · AccessEnvelope 최소 구현
- 플레이어 이동 경계
- 경계 API가 actor/effect의 causal owner를 판정할 수 있는 구조
- PHASE 2에서는 모든 투사체/스킬 시스템을 구현하지 않더라도 이후 `can_cross_access_boundary(causal_owner, effect)` 류로 연결 가능해야 함

### P2-T5 · 계단 resolver skeleton
- 후보 생성 인터페이스
- Hard Constraint Validator
- engine scorer
- top-band seeded selection
- AI ranking adapter는 optional/no-op fallback
- `WorldAnchor` 결과 저장

### P2-T6 · save/load + version/hash
- 생성 결과 저장
- 동일 세이브 재로드 시 지형/함정 상태/계단 결과 동일
- 정의 변경 시 조용한 좌표 불일치 방지

### P2-T7 · 회귀/변이 테스트 + 오너 greybox PLAYTEST
- 고정 1층 초기 정의
- shared-world / per-exile-access 책임 분리
- 계단 도달 가능/안티 스킵 validator
- 실제 실행 경로를 통과하는 회귀 테스트
- 오너가 greybox 크기/탐색 동선 체감 확인
- D-019 시작값은 여기서 필요하면 조정한다. 조정은 DESIGN 튜닝이며 Canon 변경이 아니다.

---

## 4. 아직 TBD인 것 — 구현 편의로 만들지 말 것

- 재료별 실제 저항/굴착 작업량/붕괴 계산식
- AccessEnvelope 경계에 닿은 효과의 최종 연출(소멸/충돌/절단 등)
- 계단 scorer의 정확한 가중치와 top-band 비율
- 파티 탈퇴 시 기존 계단 유지 vs 신규 생성 확률/조건 (`FAC-007`)
- 1층 **최종** 크기/방 개수 — `D-019` 시작값은 승인됐으나 최종값은 greybox PLAYTEST로 조정 가능한 DESIGN

---

## 5. Claude 작업 시작 조건

**D-016 설계 차단은 해제됐고, D-019로 P2-T2 시작 범위도 승인됐다. P2-T2를 바로 시작해도 된다.**

착수 전에:
1. `COLLABORATION_PROTOCOL.md`
2. `docs/log/2026-08.md`
3. `DECISIONS.md D-016/D-017/D-019/D-020`
4. `docs/canon/FLR.md` (`FLR-001/002/014/015/017/023~027`)
5. `docs/canon/FAC.md` (`FAC-001/002/005~007/012/013`)
6. `docs/reference/FLOOR1_NOVEL_SOURCE_NOTES.md`
7. 이 문서

순으로 확인한다.

구현 중 위 설계가 Godot 4.7.1에서 불필요하게 복잡하다고 판단되면 **Canon을 줄이지 말고 구현 표현만 단순화하는 대안**을 먼저 제안한다.
