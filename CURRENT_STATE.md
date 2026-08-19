# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-19

- **PHASE 1 (이동/카메라)**: **완료 (`PLAYTESTED`)**
- **PHASE 2**: **진행 중**
  - [x] `P2-T1` 공간 데이터 타입 (`WorldAnchor`, `AccessEnvelope`, 공유 `TerrainMutationState`)
  - [x] `P2-T0` Canon 가드 테스트 + AccessEnvelope 형태 기반 교체
  - [ ] `P2-T2` 1층 greybox + loader — **착수 가능 (`D-019`)**
  - [ ] `P2-T3` 함정 정적 정의 / 동적 상태
  - [ ] `P2-T4` AccessEnvelope 실제 Player 이동 연결
  - [ ] `P2-T5` 계단 resolver
  - [ ] `P2-T6` save/load + version/hash
  - [ ] `P2-T7` 회귀 테스트 + 오너 PLAYTEST
- **D-016**: Resolved. 설계 차단 해제.
- **P2-T2 시작 범위**: `D-019` Resolved / DESIGN 기준선.
- **FLR-014 무기 품질 충돌**: `D-020`으로 해소. 소설 원문 규칙 채택.
- **구현 인계**: `docs/design/PHASE2_IMPLEMENTATION_HANDOFF.md`
- **1층 소설 원문 참고**: `docs/reference/FLOOR1_NOVEL_SOURCE_NOTES.md`
- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **엔진**: Godot `4.7.1-stable`
- **canon 색인**: **149개 ID / 15도메인 / 통합 포인터 3개**
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지, docx 개정 시 변환기 재실행

## 최신 오너 확정 — D-018~D-020

### D-018 · 회차 시작 고정 문구

각 회차 시작 시 시스템 메시지는 정확히 아래 문구를 사용한다.

`[@회차 시작! 행운을 빕니다!]`

- 문구 글자·띄어쓰기·기호는 고정.
- 층 입장마다 반복하는 메시지가 아니라 **회차 시작 이벤트**에 귀속.
- 위치/페이드/지속시간/효과음은 DESIGN.
- 정본: `D-018`, `SYS-015`.

### D-019 · P2-T2 1층 greybox 시작 범위

첫 플레이 가능한 greybox는 아래를 **PLAYTEST용 DESIGN 기준선**으로 사용한다.

- 긴 축 **160~220 타일**
- 주요 공간 **14~20개**
- 소형 파밍 포켓/막다른 길 **6~10개**
- 큰 순환 루프 **3~5개**
- 민첩 10 기준, 전투·루팅·함정 확인 없이 숙련 핵심동선은 **수 분대** 목표

이 값은 원문 Canon 숫자가 아니라 구현을 시작하기 위한 기준선이다. `P2-T7` 오너 PLAYTEST에서
크기/공간 수는 DESIGN 범위로 조정할 수 있다. **따라서 P2-T2는 더 이상 오너 결정 대기로 막혀 있지 않다.**

### D-020 · 1층 스폰 무기 품질

- 소설 원문 규칙을 따른다.
- 1층 스폰 무기는 **대체로 품질이 나쁘지만 초기 대거보다는 낫다** (`FLR-014`).
- 이전의 "대거보다 못할 수도 있다"는 일반 규칙은 폐기.
- 파밍 지점 랜덤 배치, 석궁 수준 투사무기 상한, 총기 극저확률은 유지.

## D-016 핵심 확정

### 1. 1층 함정

- 위치·종류·구조 **고정**.
- 활성/소모, 루팅/전투 흔적 등만 동적.
- `tier_hint` 없음.

### 2. 실제 월드와 층

- 한 층은 실제 월드의 특정 위치 중 유배자에게 허용된 일부 (`D-017`).
- **같은 월드 좌표의 물리 상태는 공유**한다.
  - 지형 mutation
  - NPC 생존/위치
  - 실제 물체 상태
- 유배자별로 갈리는 것은 AccessEnvelope, 목표 상태, 계단 귀속/발견 같은 탑 규칙이다.

### 3. 맵의 끝 = 유배자 영향의 인과 경계

경계를 넘을 수 없음:
- 유배자 본체
- 소환물/직접 통제 펫
- 투사체
- 기술/마법의 직접 효과
- 던진/발사한 물체
- 유배자 공격/스킬/밀치기로 강제 이동 중인 NPC/물체

자기 의지로 움직이는 일반 NPC·야생동물과 독립 월드 시뮬레이션은 경계를 통과할 수 있다.
경계에서 효과를 소멸/충돌/절단하는 최종 연출은 DESIGN이다.

### 4. 계단 배치 — 공정한 악의

층 진입 시 한 번 계산한다.

```text
Engine candidate generation
→ Hard Constraint
→ Engine scorer
→ Optional AI ranking
→ Engine Validator
→ 상위 점수 밴드에서 seed 기반 가중 선택
→ WorldAnchor로 실체화 + 결과 저장
```

핵심 조건:
- 메인 스토리/층 목표와 정합
- 즉시 층 스킵 방지
- 허용 맵 규모 대비 충분한 상대 경로 거리
- 최종 도달 가능
- 서든데스/스토리 시간 예산 안에서 공략 가능
- 정상 바닥일 필요 없음

AI는 엔진이 만든 합법 후보의 **의미/귀찮음 ranking만 보조**한다.
AI 실패/비사용 시 engine scorer만으로 끝까지 진행한다 (`SYS-007`).
1등 한 점을 고정하지 않고 상위 밴드에서 seed 선택해 역산 가능성을 낮춘다.

### 5. 공간 구조

```text
RunState
└─ WorldState
   ├─ WorldTerrainDefinition / TerrainBody
   │  └─ TerrainMutationState   # 월드 공유
   ├─ FloorDefinition
   │  ├─ world_region_ref
   │  ├─ geology_region_ref
   │  ├─ story/objective graph
   │  └─ authored overlay / POI
   └─ FloorState
      ├─ loot / NPC / trap dynamic state
      ├─ party_stairs[]
      ├─ sudden-death / event state
      └─ access_by_exile_or_party[] -> AccessEnvelope
```

- `TerrainMutationState`를 유배자별 FloorState에 복제하지 않는다.
- `AccessEnvelope`는 실제 월드의 끝이 아니다.
- `Rect2i`는 broad bounds 최적화용일 수 있으나 행동 반경 정본이 아니다.
- P2-T1 구현 뒤 AccessEnvelope는 **형태 목록 + 구멍/돌출 예외** 구조로 교체되어 와이드 맵 메모리 폭증을 피했다.
- 1층 TileMapLayer는 저작/표시 입력으로 사용 가능.

### 6. 지질 정보는 파일로 보존

완전한 행성 지질 시뮬레이션은 지금 만들지 않더라도 지질 정의를 채팅에만 남기지 않는다.

- 계약: `data/worlds/README.md`
- 스키마: `data/worlds/geology_profile.schema.json`
- 실제 월드: `data/worlds/<world_id>/geology_profile.json`

미정값은 임의 숫자를 넣지 않고 `status=TBD` + `null`/빈 배열로 둔다.

## P2-T2 — 1층 크기/방 수 설계 상태

설정서 v1.1과 2026-08-19 오너 제공 **소설 초반 캡처**를 대조했다.

### 직접 복원 가능한 숫자

**없음.** 정확한 미터/타일 크기나 방 개수는 어느 쪽에도 명시되지 않는다.

### 강한 원문 단서

- 1층은 고대 사원풍 **고정 미로**이고 반복 회차를 통해 외우는 것이 성장이다.
- 함정/매복/파밍 선택지는 충분히 많아야 한다.
- 반면 1층은 소설에서 **복잡할 것도 없고 난관도 적은 곳**, 과거 게임에서는
  **조작법 튜토리얼에 가까운 저난이도 스테이지**로 묘사된다.
- 서든데스 1시간은 지형을 걷는 데만 1시간 걸린다는 뜻이 아니라,
  파밍·함정 확인·전투·욕심을 얼마나 더 낼지 포함한 플레이 예산이다.
- 미로 초반은 대체로 공평하다는 서술이 있다.

### 승인된 첫 greybox 기준 — D-019

- 긴 축 **160~220 타일**
- 주요 공간 **14~20개**
- 소형 파밍 포켓/막다른 길 **6~10개**
- 큰 루프 **3~5개**

이 수치는 **Canon 숫자가 아니라 PLAYTEST용 DESIGN 시작점**이다.
Claude는 이 기준으로 `P2-T2`를 바로 구현할 수 있다.

## PHASE 1 결과 (완료)

- `CharacterBody2D` 이동/충돌 + Camera2D
- 대각선 정규화 / 프레임 독립성
- 오너 카메라 PLAYTESTED
- 테스트 러너 `D-015`: 자체 SceneTree
- 실제 Player/Input/physics E2E 회귀 테스트 포함
- integration harness와 test case 분리
- `tools/run.ps1` Godot 4.7.1 버전 경고 포함

## 구현 주의

- 1층 "고정"은 **초기 정의 고정**. 플레이 중 terrain mutation을 막는 뜻이 아니다.
- 계단은 일반 타일 오브젝트에 종속시키지 않는다. `WorldAnchor` 계열 주소를 사용한다.
- 같은 월드 좌표의 terrain/NPC/물체 상태를 유배자별로 복제하지 않는다.
- AccessEnvelope는 유배자 본체뿐 아니라 **유배자가 원인이 된 직접 영향**의 경계를 강제해야 한다.
- NPC LOD는 `D-014` G-5 결정성 불변식을 유지한다. 실제 월드는 플레이어 행동 반경 밖에서도 존재한다.
- `P2-T2` greybox는 `D-019` 시작값을 사용하되 최종값처럼 하드코딩하지 않는다. PLAYTEST 튜닝 가능하게 둔다.
- `P2-T3` 파밍 구현은 `D-020/FLR-014`의 무기 품질 규칙을 따른다.
- 설정서 밖 새 확정 규칙은 `DECISIONS.md`와 관련 Canon 색인에 함께 남긴다.
- Markdown 끝 LF 유지. 다른 PC 작업은 Godot `--import` 먼저.

## 다음 작업

1. **[Claude] `P2-T2` 1층 greybox + loader를 바로 착수.** `D-019` 시작범위 사용.
2. **[Claude]** `TestRoom.tscn`을 Canon 지형으로 승격하지 말고 P2-T2에서 교체/폐기.
3. **[Claude]** P2-T2 완료 뒤 자동 테스트와 실제 실행 결과를 로그에 기록하고 인계.
4. **[오너+GPT]** `P2-T0`/`P2-T1` 구현물 독립 검토는 별도로 남아 있음.
5. **[오너]** P2-T7에서 greybox 크기/동선 최종 체감 확인.
