# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-18

- **PHASE 1 (이동/카메라)**: **완료 (`PLAYTESTED`)**
- **다음 PHASE**: **2 — 착수 가능**
- **PHASE 2 설계**: `D-016` **Resolved**. 설계 차단 해제.
- **구현 인계**: `docs/design/PHASE2_IMPLEMENTATION_HANDOFF.md`
- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **엔진**: Godot `4.7.1-stable`
- **canon 색인**: **148개 ID / 15도메인 / 통합 포인터 3개**
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지, docx 개정 시 변환기 재실행

## D-016 최종 확정

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
- Rect2i는 broad bounds 최적화용일 수 있으나 행동 반경 정본이 아니다.
- 1층 TileMapLayer는 저작/표시 입력으로 사용 가능.
- `FloorDefinition`은 authored 1층과 2층+ generator가 공유할 불변 런타임 표현.

### 6. 지질 정보는 파일로 보존

완전한 행성 지질 시뮬레이션은 지금 만들지 않더라도 지질 정의를 채팅에만 남기지 않는다.

- 계약: `data/worlds/README.md`
- 스키마: `data/worlds/geology_profile.schema.json`
- 실제 월드: `data/worlds/<world_id>/geology_profile.json`

행성/천체 파일은 최소한 전체 크기, 레이어 경계, 레이어별 성분/재료 비율, 지역 지질 프로필을 기록할 수 있어야 한다.
미정값은 임의 숫자를 넣지 않고 `status=TBD` + `null`/빈 배열로 둔다.

## PHASE 2 구현 범위

구현 담당 Claude는 `docs/design/PHASE2_IMPLEMENTATION_HANDOFF.md`의 P2-T0~T7을 기준으로 착수한다.

핵심 범위:
- WorldAnchor / TerrainBodyRef / FloorDefinition / FloorState / AccessEnvelope 최소 스키마
- 1층 greybox + loader
- 함정 정적 정의 / 동적 상태 분리
- party_stairs[] 수명주기
- 계단 resolver skeleton + Validator + deterministic fallback
- 결과 저장 + seed + definition version/hash
- geology profile / world region 참조 훅
- shared-world와 per-exile-access 책임 분리 테스트

PHASE 2에서 하지 않는 것:
- 전체 행성 복셀/지질 시뮬레이션
- 최종 굴착/붕괴 물리
- 재료별 최종 저항 수치
- AI API를 계단 생성 필수 의존성으로 만들기
- 2층+ 전체 프로시저럴 생성기

## PHASE 1 결과 (완료)

- `CharacterBody2D` 이동/충돌 + Camera2D
- 대각선 정규화 / 프레임 독립성
- 오너 카메라 PLAYTESTED
- 테스트 러너 `D-015`: 자체 SceneTree
- Claude 보강 후 기록: unit 17 + integration 17, 실패 0
- 실제 Player/Input/physics E2E 회귀 테스트 포함
- integration harness와 test case 분리
- `tools/run.ps1` Godot 4.7.1 버전 경고 포함

PHASE 1 임시 `scenes/world/TestRoom.tscn`은 **Canon 지형이 아니며 PHASE 2에서 교체**한다.

## 구현 전 주의

- 1층 "고정"은 **초기 정의 고정**. 플레이 중 terrain mutation을 막는 뜻이 아니다.
- 계단은 일반 타일 오브젝트에 종속시키지 않는다. `WorldAnchor` 계열 주소를 사용한다.
- 같은 월드 좌표의 terrain/NPC/물체 상태를 유배자별로 복제하지 않는다.
- AccessEnvelope는 유배자 본체뿐 아니라 **유배자가 원인이 된 직접 영향**의 경계를 강제해야 한다.
- NPC LOD는 `D-014` G-5 결정성 불변식을 유지한다. 실제 월드는 플레이어 행동 반경 밖에서도 존재한다.
- 설정서 밖 새 확정 규칙은 `DECISIONS.md`와 관련 Canon 색인에 함께 남긴다.
- Markdown 끝 LF 유지. 다른 PC 작업은 Godot `--import` 먼저.

## 다음 작업

1. Claude가 `docs/design/PHASE2_IMPLEMENTATION_HANDOFF.md`를 읽고 P2-T0~T7 타당성을 현재 Godot 코드 기준으로 재검토한다.
2. Canon 의미를 줄이지 않는 선에서 구현 표현을 단순화할 필요가 있으면 대안을 제안한다.
3. 타당성 문제 없으면 PHASE 2 실제 구현 착수.
4. greybox가 플레이 가능해지면 오너 PLAYTEST로 1층 크기/동선을 조정한다.
