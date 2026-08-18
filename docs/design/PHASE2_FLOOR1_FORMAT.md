# PHASE 2 설계안 — 1층/월드 공간 데이터 포맷 (v2 토의본)

> **상태: PROPOSAL — 부분 오너 확정, 최종 구조 승인 대기.** `DECISIONS.md` `D-016`.
> **승인 전에는 이 문서를 근거로 PHASE 2 구현을 시작하지 않는다.**
>
> 최초안: 2026-08-18 Claude · 1차 GPT 검토 후 오너 응답 반영.
> 상세 세계 공간/계단/지형 파괴 논의: `docs/design/PHASE2_WORLD_SPACE_EXTENSION.md`.

---

## 0. v1에서 무엇이 바뀌었나

최초안은 1층을 `TileMapLayer + floor1_meta → FloorDefinition → FloorState` 정도의 독립 맵으로 보았다.
오너 토의에서 다음 세계 규칙이 복원/추가되어 이 전제를 수정해야 한다.

- 1층 **함정 위치·종류·구조는 고정**, 활성/소모 상태만 동적.
- 계단은 고정 후보표가 아니라 **층 진입 시 실제 세계 공간을 보고 계산**한다.
- 계단은 생성 후 월드 좌표 고정·파괴 불가이며 정상 바닥이 아닌 숨은 공간에도 존재할 수 있다.
- 한 층은 실제 월드의 특정 위치 중 유배자에게 허용된 일부다. 경계 밖 세계도 존재한다.
- "맵의 끝"은 유배자별 접근 제약이며 NPC/야생동물은 통과한다. 허용 영역은 서로 겹칠 수 있다.
- 와이드 맵과 홀수층 개인 목표 / 짝수층 공동 목표 규칙이 복원됐다.
- 지형은 물질이며 충분한 힘·도구·시간으로 파괴/굴착 가능하다.

따라서 최초안의 `map_bounds`를 세계의 끝으로 보거나, `trap_slots → type 랜덤`,
`stair_candidates[]` 고정 목록을 두는 부분은 **폐기**한다.

---

## 1. 현재 확정된 Canon/오너 결정

| 항목 | 현재 규칙 |
| --- | --- |
| 1층 초기 지형 | 고정 (`FLR-001`) |
| 1층 함정 | 위치·종류·구조와 고정 단서는 고정, `armed/fired` 등 상태만 변동 |
| 1층 랜덤 | 전리품·유배자·루팅/전투 흔적·활성/소모 상태 (`FLR-002`) |
| 지형 파괴 | 초기 정의 이후 플레이어 행동으로 mutation 가능 (`FLR-027`) |
| 층 공간 | 실제 `WorldState` 공간의 일부 (`FLR-023`) |
| 맵의 끝 | 유배자/파티별 접근 영역. NPC·야생동물은 통과 (`FLR-024`) |
| 홀수/짝수층 | 홀수 개인 목표 / 짝수 공동 목표 (`FLR-026`) |
| 계단 시점 | 층 진입 시 resolve/create (`FAC-012`) |
| 계단 위치 | 생성 뒤 월드 좌표 고정, 파괴 불가 (`FAC-013`) |
| 파밍 tier_hint | 없음 |
| 결정성 | 실체화 결과 저장 + seed 보존 + definition version/hash |
| AI 권한 | AI가 GameState를 직접 쓰지 않음 (`SYS-002`), AI 없이도 게임 진행 (`SYS-007`) |

---

## 2. 데이터 책임 — GPT 제안, 오너 최종 승인 대기

### 권장 구조

```text
WorldState
  └─ WorldTerrainDefinition / TerrainBody
       ├─ 실제 월드 공간/지역/구조 주소
       ├─ 지질·재료·구조 profile (필요 시 lazy materialize)
       └─ TerrainMutationState

FloorDefinition
  ├─ floor_id
  ├─ world_region_ref
  ├─ authored overlay / POI
  ├─ story / objective graph
  ├─ trap fixed definitions
  ├─ loot/spawn points
  └─ floor rules

FloorState
  ├─ generation_seed
  ├─ definition_version/hash
  ├─ realized loot/NPC results
  ├─ trap runtime states
  ├─ party_stairs[]
  ├─ access_by_exile_or_party[]
  ├─ sudden_death / events
  └─ floor-relevant terrain mutation refs
```

### 왜 3층 구조가 필요한가

1. **WorldTerrainDefinition/TerrainBody** — 층 경계 밖에도 실제 세계가 존재한다.
2. **FloorDefinition** — 그 실제 세계 중 이번 층에서 어떤 스토리·목표·고정 위험·POI를 쓰는지 정의한다.
3. **FloorState** — 이번 플레이에서 무엇이 루팅/소모/발견/파괴됐는지를 저장한다.

`FloorState.map_bounds: Rect2i` 하나로 세계와 행동 반경을 동시에 표현하지 않는다.
Rect2i는 broad AABB 최적화에는 쓸 수 있지만 Canon 경계의 SSOT는 아니다.

### 1층 저작

- **TileMapLayer 사용 자체는 유지 가능**하다. 회색박스/아트 저작과 충돌·표시에는 Godot 에디터가 편하다.
- 단, TileMapLayer가 **전체 세계의 SSOT**는 아니다.
- 1층 저작 씬 + meta를 읽어 `FloorDefinition`을 만든다.
- 2층+ 생성기도 최종적으로 같은 `FloorDefinition` 계약을 출력하게 한다.
- `FloorDefinition`을 별도 사람이 수정하는 두 번째 파일로 중복 저장하지 않는다.

---

## 3. 1층 고정/동적 경계 — 오너 확정

| 고정 초기 정의 | 동적/세이브 상태 |
| --- | --- |
| 방·통로·막다른 길·주요 구조 | 지형 파괴/굴착 mutation |
| 함정 위치·종류·구조 | `armed`, `fired`, 파괴/소모 흔적 |
| 함정의 고정 사전 단서 | 이미 작동했다는 흔적 등 상황 단서 |
| 파밍/스폰 지점 자체 | 실제 아이템·유배자 배치, 루팅 상태 |
| 층 스토리/POI 정의 | 플레이어 행동으로 확정된 사건 결과 |
| — | 파티별 실제 계단 위치 |

데이터 마이닝 정책상 **고정 함정 구조가 공개되는 것은 허용**한다. 1층의 메타 성장은 이를 외우는 데 있다.
숨겨야 하는 것은 이번 회차의 동적 결과다.

`tier_hint`는 두지 않는다.

---

## 4. 계단 위치 — 오너 방향 + GPT 구현 제안

### 오너가 원하는 결과

한 문장으로는 **"플레이어 입장에서 빡치는 위치"**지만, 항상 단 하나의 수학적 최악 위치를 고르면
공식 역산이 가능해질 수 있으므로 다음 성격을 가진 위치를 원한다.

- **메인 스토리와 연관**되어 있다.
- 계단을 우연히 쉽게 찾아 **층을 스킵하기 어렵다.**
- 플레이어에게 부여된 허용 맵의 크기에 비해 **충분히 멀다**.
  - 고정 미터보다 허용 영역/유효 경로 크기의 비율로 평가한 뒤 실제 거리로 환산.
- 정상 바닥에 한정하지 않는다.
  - 보스 판정 NPC/몬스터의 침소 아래
  - 동굴 천장 위의 자연 공동
  - 지형/구조 내부 숨은 공간 등
- 단, 정상적인 게임 플레이로 최종 접근 가능해야 한다.

### GPT 보완: "공정한 악의(adversarial but solvable)"

#### Hard Constraint

후보는 최소한 다음을 모두 만족해야 한다.

1. 현재 활성 스토리/인과관계와 모순되지 않음.
2. **영구 소프트락이 아니며 최종 도달 가능**.
3. 시작 직후/짧은 직선 이동으로 층 스킵이 되지 않음.
4. 현재 또는 정상 스토리 진행으로 열릴 플레이어 접근 영역과 정합.
5. 굴착/파괴가 필요하다면 필요한 힘·도구·시간이 서든데스/스토리 시간 예산상 현실적으로 가능.
6. 실제 월드 공간에서 존재 가능한 anchor.

#### Soft Score 후보

- `story_relevance`
- `skip_resistance`
- `normalized_route_cost` — 유클리드 거리보다 path/geodesic cost percentile 우선
- `risk_exposure`
- `discovery_friction`
- `terrain_access_cost`
- `novelty` — 최근 회차와 같은 유형 반복 억제

정확한 가중치는 **DESIGN**이며 플레이테스트로 바꿀 수 있다.

#### 단일 argmax 금지 제안

항상 점수 1등 한 점을 고르지 않고 Hard Constraint 통과 후보 중 **상위 밴드**를 만든 뒤,
그 안에서 seed 기반 가중 랜덤으로 하나를 확정하는 것을 권고한다.

이렇게 하면 탑이 의도적으로 성가신 위치를 고르는 느낌은 유지하면서 "공식상 항상 1등 위치"라는
역산 지문과 반복 패턴을 줄일 수 있다.

---

## 5. AI를 어디까지 쓰나 — 제안

계단 위치 결정은 층 진입 시 **한 번**이므로 계산 시간 자체는 큰 문제가 아니다.
하지만 외부 AI가 직접 좌표를 GameState에 쓰면 `SYS-002`, AI가 없으면 계단을 못 만들면 `SYS-007` 위반이다.

권장:

```text
엔진: 현재 스토리 + 접근 영역 + 지형/POI/위험으로 희소 후보 생성
 → 엔진 Hard Constraint 필터
 → AI(선택적): 스토리 의미/악의적 적합성을 구조화 Proposal로 ranking
 → Validator
 → 엔진: 상위 밴드에서 seed 기반 최종 선택
 → party_stairs[] 실체화 + 결과 저장
```

AI가 실패/비활성화된 경우 **엔진 scorer만으로 동일한 절차를 완료**한다.
AI는 후보의 의미를 평가하는 보조자이지 월드의 진실을 직접 만드는 권한자가 아니다.

전 행성의 모든 좌표를 AI가 훑지 않는다. 현재 유배자의 허용 영역 + 정상 진행으로 열릴 영역에서
POI, 보스 구역, 막다른 길, 숨은 공간, 지하/상부 공동, 고위험 구역 등의 **희소 후보**만 만든다.

---

## 6. 지형 물질/파괴 — PHASE 2에서 어디까지 하나

### Canon 방향

- 지형은 실제 물질/구조다.
- 자연 세계는 행성의 지질/지층을 가진다.
- 충분한 힘·도구·시간이면 굴착/파괴 가능하다.
- 힘 10 일반 성인이 부적절한 도구로 큰 토량을 빠르게 파내는 식의 비현실적인 결과를 허용하지 않는다.

### 구현 권고

모든 행성 타일/복셀 값을 처음부터 저장하지 않는다.

```text
TerrainBody profile
 → core / mantle / crust / regional geology (자연 행성)
 → region seed + authored historical overrides
 → 실제 필요 chunk/layer만 deterministic materialize
 → 변경된 위치만 mutation delta 저장
```

1층 사원, 마법 구조물, 공허 위 시설에는 내핵/맨틀을 억지로 적용하지 않는다.
공통 `TerrainBody` 계약 아래 자연 행성/인공 구조물/마법 구조물이 서로 다른 material/structure profile을 갖게 한다.

현실성은 우선 다음 계열의 **작업량 모델**로 충분하다.

```text
required_work ≈ material_resistance × volume × structural_factor
work_rate ≈ STR-derived capacity × tool_efficiency × skill/state modifiers
```

정확한 수치/공학식은 TBD. 전체 유한요소 해석 대신 필요해질 때 로컬 support/collapse 규칙을 쓴다.

**PHASE 2에서는 완전한 굴착 시스템을 만들지 않는다.**
다만 spatial anchor / material hook / terrain mutation 상태가 나중에 들어갈 수 있는 데이터 경계를 확보한다.
전체 행성 지질·굴착·붕괴는 `BACKLOG B-007`.

---

## 7. 저장/결정성 — 오너 확정

- `generation_seed`: 재현/디버그용.
- 실제 전리품/NPC/계단 등 **실체화 결과가 진실**이며 세이브한다.
- `floor_definition_version/hash`를 기록해 고정 정의가 패치됐을 때 옛 세이브가 조용히 다른 좌표에 올라가지 않게 한다.
- 지형 mutation은 초기 정의에 대한 delta로 저장한다.
- 계단 `WorldAnchor`는 지형 mutation과 독립적으로 보존한다.

---

## 8. PHASE 2 티켓 — 최종 승인 후 재검토용 초안

```text
T0  D-016 최종 승인 + Canon/INDEX 정합화
T1  WorldTerrain/FloorDefinition/FloorState 최소 인터페이스 + 포맷 가드
T2  1층 TileMapLayer greybox + 고정 함정/POI meta → FloorDefinition 로더
T3  AccessEnvelope 최소 모델 + 실제 Player 경계 검증
T4  loot/exile/trap runtime state 실체화 + deterministic RNG
T5  결과 save/load + definition version/hash + terrain mutation hook
T6  party_stairs[] lifecycle + WorldAnchor + 계단 배치 scorer/fallback
T7  오너 greybox PLAYTEST → 맵 규모/동선/계단 체감 조정
```

최종 티켓은 Claude 구현 담당이 실제 Godot 구조와 비용을 다시 검토한 뒤 확정한다.

---

## 9. 아직 오너에게 남은 질문

### Q-A · 겹치는 유배자 행동 반경의 물리 상태

같은 실제 월드 좌표를 두 유배자 영역이 공유할 때 한 유배자가 벽을 부수거나 NPC를 죽이면
다른 유배자에게도 같은 결과가 보여야 하는가?

**GPT 권고: YES.** 같은 좌표인데 서로 다른 벽/NPC가 있으면 "실제 하나의 월드"가 아니라
플레이어별 평행 복제본이 되기 때문이다.

### Q-B · 맵의 끝이 플레이어 밖으로 뻗는 것에 미치는 영향

NPC/야생동물은 자유 통과가 확정됐다. 아직 다음은 미정:

- 플레이어가 발사한 투사체
- 소환물/펫
- 던진 아이템
- 플레이어가 밀어낸 물체

악용 가능성이 크므로 별도로 확정한다.

### Q-C · 계단 AI 파이프라인

§4~§5의 **엔진 후보 생성 + Hard Constraint + 선택적 AI rank + Validator + 상위밴드 seed 선택**을
D-016의 구현 방향으로 채택할지 최종 확인이 필요하다.

### Q-D · 공간 데이터 구조

§2의 `WorldTerrainDefinition/TerrainBody → FloorDefinition → FloorState` 경계를 PHASE 2 기본 구조로
채택할지 최종 확인이 필요하다.

---

## 10. 다음 AI에게

- 최초 v1의 `trap type 랜덤`, `stair_candidates[] 고정`, `map_bounds = 세계 끝`은 **폐기된 설계**다.
- 현재 오너 확정 규칙은 `D-017`, `FLR-023~027`, `FAC-012/013`, 수정된 `SYS-014`를 우선한다.
- Q-A~Q-D가 닫히기 전 PHASE 2 코드를 시작하지 않는다.
- 설정서 원본 v1.1에는 와이드 맵/홀짝층/바깥 세계 지속성 상세가 누락되어 있으며,
  2026-08-18 오너 직접 재확인으로 복원되었다.
