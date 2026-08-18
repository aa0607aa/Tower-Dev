# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-18

- **PHASE 1 (이동/카메라)**: **완료 (`PLAYTESTED`)**
- **다음 PHASE**: 2 — 1층 고정 초기 지형 + 동적 상태/배치 기반
- **PHASE 2 구현 착수**: **아직 금지.** `D-016` 데이터/공간 구조의 마지막 설계 결정을 먼저 닫는다.
- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **엔진**: Godot `4.7.1-stable`
- **canon 색인**: **148개 ID / 15도메인 / 통합 포인터 3개**
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지, docx 개정 시 변환기 재실행

## 이번 D-016 토의에서 오너가 확정한 것

1. **1층 함정 위치·종류·구조는 고정**이다.
   - 변하는 것은 활성/소모(`armed/fired`), 루팅, 전투 흔적 등 동적 상태.
   - 기존 `SYS-014`의 "함정 종류는 시드 랜덤" 해석은 정정 완료.
2. **계단 위치는 층 진입 시 결정**한다.
   - 고정 후보표에서 하나를 고르는 방식은 사용하지 않는 방향.
   - 정상 바닥만이 아니라 보스 침소 아래, 동굴 천장 위 공동 등 실제 세계 공간의 숨은 좌표도 가능.
   - 생성 뒤에는 **월드 좌표에 고정 + 파괴 불가**. 지지 지형이 사라져도 계단 자체는 남는다.
   - 파티 합류는 파티장의 기존 계단 이용권으로 전환. 탈퇴 판정은 기존 `FAC-006/007`.
3. **파밍 지점 `tier_hint` 없음.**
4. **동적 생성 결과를 저장**한다. seed도 디버그/재현용으로 보존하고 definition version/hash를 둔다.
5. **층은 실제 월드의 특정 위치 중 유배자에게 허용된 일부**다 (`D-017`).
   - 경계 밖에도 환경/생태/NPC가 실제로 존재.
   - "맵의 끝"은 유배자 접근 제약이고 NPC/야생동물은 자유롭게 통과.
   - 유배자별 허용 영역은 겹칠 수도, 겹치지 않을 수도 있다.
   - 큰 허용 영역은 **와이드 맵**.
6. **튜토리얼 홀수층 = 개인별 목표 / 짝수층 = 공동 목표**.
   - 홀수층도 공간이 겹치면 다른 유배자와 만날 수 있다.
   - 짝수층은 협동/PvP/경쟁/생존 인원 제한 등 공통 목표가 가능하며 같은 행동 반경을 공유하는 경우가 많다.
7. **지형은 물질이며 파괴 가능**하다.
   - 자연 지형은 지질/지층 구조를 가지며 충분한 힘·도구·시간으로 굴착/파괴할 수 있다.
   - 현실적으로 납득되는 내구/작업량을 가진다.
   - 전체 행성 값을 미리 실체화하지 않고 필요 좌표만 결정적으로 materialize한 뒤 mutation을 저장할 수 있다.

정식 기록: `D-017`, `FLR-023~027`, `FAC-012/013`, 수정된 `FLR-001/002`, `SYS-014`.

## D-016 — 아직 남은 설계 승인

`D-016`은 **부분 확정된 Proposed** 상태다. 구현 전 아래를 최종 정리한다.

### A. 공간/지형 데이터 구조

GPT 제안:

```text
WorldState
  └─ WorldTerrainDefinition / TerrainBody
       ├─ 실제 월드의 연속 공간/지질/구조 정의
       └─ TerrainMutationState

FloorDefinition
  ├─ world_region_ref
  ├─ story/objective graph
  ├─ authored overlay / POI
  └─ floor rules

FloorState
  ├─ loot / NPC / trap state
  ├─ party_stairs[]
  ├─ sudden death / event state
  └─ access_by_exile_or_party[]
```

- 1층 `TileMapLayer`는 회색박스 **저작/표시 입력**으로 사용 가능.
- `Rect2i map_bounds`는 broad bounds 최적화일 뿐 "맵의 끝"의 정본이 아니다.
- 유배자별 실제 접근 영역은 polygon/cell mask/region graph 등 비정형 `AccessEnvelope`가 필요.
- 완전한 행성 지질/굴착 시뮬레이션은 PHASE 2에 전부 구현하지 않되, material/terrain mutation을 나중에 넣을 수 없는 스키마로 굳히지 않는다.

### B. 계단 배치 계산 구조

오너 의도:
> 플레이어 입장에서 빡치는 위치. 단, 단일한 "수학적으로 가장 최악"을 반복해 역산 가능하게 만들지는 않는다.

오너가 제시한 최소 축:
- 메인 스토리와의 연관성
- 쉽게 발견해 층을 스킵하지 못함
- 플레이어 허용 맵 크기에 대한 **상대적 거리**가 충분함

GPT 제안은 **공정한 악의(adversarial but solvable)**:

```text
엔진: 스토리/공간/위험/POI 기반 희소 후보 생성
  → Hard Constraint (스토리 정합성, 최종 도달 가능, 안티 스킵, 시간예산 등)
  → AI(선택): 의미/귀찮음 정도를 구조화 Proposal로 ranking
  → 엔진 Validator
  → 상위 점수 밴드 안에서 seed 기반 가중 선택
  → party_stairs[]에 실체화 + 결과 저장
```

AI 장애/비사용 시 엔진의 정량 scorer만으로 끝까지 진행하는 fallback을 둬 `SYS-007`을 지킨다.
정확한 가중치/percentile은 DESIGN이며 플레이테스트로 튜닝한다.

### C. 아직 오너에게 남은 경계 질문

- 겹치는 유배자 접근 영역이 같은 물리 장소를 가리킬 때 **동일 `WorldState`/terrain mutation/NPC 상태를 공유할지**.
  - GPT 권고: 공유. 같은 좌표인데 서로 다른 벽/NPC가 생기면 "같은 실제 세계" 설정과 어긋남.
- "맵의 끝"이 유배자 본체 외 **투사체·소환물/펫·던진 아이템·밀어낸 물체**에도 적용되는지.

## PHASE 1 결과 (완료)

- `CharacterBody2D` 이동/충돌 + Camera2D
- 대각선 정규화 / 프레임 독립성
- 오너 카메라 PLAYTESTED
- 테스트 러너 `D-015`: 자체 SceneTree
- Claude 보강 후 현재 기록: unit 17 + integration 17, 실패 0
- 실제 Player/Input/physics E2E 회귀 테스트 포함
- integration harness와 test case 분리
- `tools/run.ps1` Godot 4.7.1 버전 경고 포함

PHASE 1 임시 `scenes/world/TestRoom.tscn`은 **Canon 지형이 아니며 PHASE 2에서 교체**한다.

## 구현 전 주의

- 1층 "고정"은 **초기 정의 고정**이다. 플레이 중 지형 파괴/mutation까지 막는 뜻이 아니다.
- 계단은 일반 타일 오브젝트에 종속시키지 않는다. 장기적으로 `WorldAnchor(world/region/x/y/layer-or-depth)` 계열 주소가 필요하다.
- NPC LOD는 `D-014` G-5 결정성 불변식을 유지한다. 실제 월드는 플레이어 행동 반경 밖에서도 존재한다.
- 설정서 밖 새 확정 규칙은 `DECISIONS.md` + `docs/canon/INDEX.md`의 정본 외 유래 표에 같이 남긴다.
- Markdown 끝 LF 유지. 다른 PC 작업은 Godot `--import` 먼저.

## 다음 작업

1. 오너와 D-016 남은 설계(A/B/C) 토의/확정.
2. D-016을 Resolved로 바꾸기 전에 Claude 구현 담당이 새 월드 공간 모델이 실제 Godot 구조에서 과도한지 재검토.
3. 확정 후 PHASE 2 티켓을 새 구조 기준으로 다시 분해.
4. 그 뒤에만 실제 PHASE 2 구현 착수.

상세 설계 메모: `docs/design/PHASE2_WORLD_SPACE_EXTENSION.md`.
