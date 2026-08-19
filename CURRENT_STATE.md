# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`와 최신 보조 로그를 확인한다.

## 현재 위치 — 2026-08-19

- **PHASE 0**: 완료 (`VERIFIED`)
- **PHASE 1 (이동/카메라)**: 완료 (`PLAYTESTED`)
- **PHASE 2 (1층 공간/상태/계단/세이브)**: **구현 및 P2-REV 수정 완료, 최종 종료 검수/PLAYTEST 대기**
  - [x] `P2-T0` Canon 가드 테스트
  - [x] `P2-T1` 공간 데이터 타입 (`WorldAnchor`, `AccessEnvelope`, 공유 `TerrainMutationState`)
  - [x] `P2-T2` 1층 고정 greybox + loader
  - [x] `P2-T3` 함정/파밍 정적 정의와 동적 상태 분리
  - [x] `P2-T4` AccessEnvelope 실제 Player 이동 연결
  - [x] `P2-T5` 계단 resolver
  - [x] `P2-T6` save/load + immutable definition hash
  - [x] `P2-T7` 자동 회귀/변이 검증
  - [x] Claude가 GPT의 `P2-REV-001~003` 수정 반영 및 테스트 완료
  - [ ] **GPT가 P2-REV 최종 diff 재검토**
  - [ ] **오너가 layout v2 밀도·규모 최종 체감 판정**
- **PHASE 3**: 위 두 항목을 닫은 뒤 진행. 함정 구현은 새 `FLR-028`을 반드시 적용.

- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **현재 문서 동기화 기준 HEAD**: `7ebdb99dcc2bebf0be1754e1d6029c00f0145128` (D-024 + 원작 GAP 장부)
- **엔진**: Godot `4.7.1-stable`
- **Canon 색인**: **155개 ID / 15도메인 / 통합 포인터 3개**
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지

## 최신 오너 확정 — D-018~D-024

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

### D-021 · 오르골 초기 스탯 정정

- 힘 **8** / 민첩 **11** / 지능 **15**.
- ⚠ 설정서 v1.1 §24.1은 아직 8/12/14이므로 다음 설정서 개정 때 반영.

### D-022 · 1층 시작 위치 랜덤화

- 고정 지형과 별개로 시작 위치는 회차 시드로 고정 후보 중 선택.
- 후보는 `FloorDefinition`, 결과는 `FloorState.start_cell`에 저장.

### D-023 · 마인드맵 성장 구조

- 빨강=STR / 초록=AGI / 파랑=INT 고정.
- 숫자 직접 배분이 아니라 연결된 색상 노드에 투자.
- **노드 1개 = 포인트 1 = 대응 스탯 +1**.
- 한 가지의 스탯 노드 3개 완성 → 즉시 랜덤 스킬 개화 → 해당 스킬에서 새 가지 발생.
- 중심에서 멀수록 기존 빌드 연관성 강화, 일정 깊이 이후 완전히 무관한 스킬 제외.
- 임의 respec 기본 불가. 종족 변경 시 부적합 skill subtree만 제거하고 해당 투자 포인트 환원.
- 전문화 임계/연관도 공식/태그/가지 수는 TBD.

### D-024 · 소설 원작 누락 6건 복원

1. **물리 함정 상호작용 — `FLR-028`**
   - 함정은 Player 전용 트리거가 아니다.
   - 실제 메커니즘상 돌·투척물·물체·환경 변화가 트리거를 건드릴 수 있으면 발동/소모/우회 가능.
   - PHASE 3에서 actor class보다 trigger mechanism을 먼저 모델링한다.
2. **랜덤 인카운터 — `SYS-016`**
   - 완전 즉흥 생성이 아니라 **저작된 시나리오 골격 + 허용된 세부 랜덤화**.
3. **언어 통합/바벨탑 — `WLD-011`**
   - 미궁/탑 내부에서는 서로 다른 언어권의 말이 통한다.
   - 이 기능을 담당하는 구조물은 **「바벨탑」**.
   - 위치·외형·작동 메커니즘은 TBD.
4. **NPC/생물 경험 학습 — `NPC-006`**
   - 직접 경험하거나 합법적인 정보 경로로 배운 위험/사건/단서가 이후 행동에 영향을 준다.
5. **왕국 도달 난이도 — `WLD-012`**
   - 왕국의 문에도 도달하지 못하는 유배자가 **대다수**인 체감을 유지.
   - 원작의 70%는 고정 통계가 아니라 DESIGN 밸런스 기준.
6. **NPC 정보 표현 — `NPC-007`**
   - 원작 속 과거 게임의 전지적 마우스오버보다 **소설 속 실제 세계 체험**을 따른다.
   - NPC의 미발견 상세는 대화·관찰·행동 결과·소문으로 파악.

## 최신 소설 source audit

- `docs/reference/NOVEL_SOURCE_GAP_AUDIT.md`가 원작 캡처 ↔ Canon 역대조 정본.
- `NSG-001/003/004/005/006/008`은 **D-024로 해결됨**.
- 새 발췌의 열매 효과 랜덤/외형 비신뢰성은 `ITM-002`와 MATCHED.
- **NSG-017**: "시스템 열매나무가 소규모 몬스터 집단 주변에 자주 스폰"은 아직 오너가 일반 규칙으로 확정하지 않았으므로 GAP 상태. 구현 상수로 만들지 않는다.
- 같은 발췌의 특정 사냥꾼 독성 저항/레벨은 SCENE-ONLY.

## PHASE 2 현재 구현 요약

### 공간/월드 모델

- `WorldAnchor`: 실제 월드 공간 주소.
- `AccessEnvelope`: 유배자별 허용 영역/인과 경계.
- `TerrainMutationState`: 월드가 공유하는 지형 변경 상태.
- `FloorDefinition`: 1층 고정 초기 정의.
- `FloorState`: 전리품/스폰/함정 상태/계단/발견/시작점 등 동적 결과.

### layout v2

- 서쪽 회랑: 열주형
- 입구 광장: 열린 공간
- 서쪽 납골: 분할된 좁은 셀
- 북쪽: 좁은 미로/회랑
- 중앙 대청: 큰 공간 + 내부 구조물
- 남쪽: 붕괴된 사원 하부 공동
- 동쪽: 넓은 통로
- 최동단: 열린 큰 홀

오너 1차 평가는 **"지형이 훨씬 낫다"**. 밀도·규모 최종 판정은 아직 열려 있다.

### 계단 resolver

```text
Engine candidate
→ Hard Constraint
→ Engine score
→ Optional AI ranking
→ Validator
→ 상위 band seeded selection
→ WorldAnchor 저장
```

- BFS 실제 경로 비용 사용.
- AI 없이도 정상 동작.
- D-022 실제 `start_cell` 사용.
- P2-REV-001에서 BFS/fallback을 AccessEnvelope-aware로 수정 완료.

### 세이브 / definition hash

- 실체화 결과를 저장하고 로드시 재추첨하지 않는다.
- `definition_hash`는 **immutable floor-definition hash** 계약으로 정리 완료.
- 함정 성질, 시작 후보, 층 정체성 등 불변 의미를 포함.

## PHASE 2 테스트 상태 — Claude 기록

P2-REV 처리 후:
- 단위 **652 단언** 통과
- 통합 **20 단언** 통과
- 반복 3회 안정성 확인
- 변이 3건(`velocity *= delta`, envelope 무시, 함정 성질 hash 제외) 모두 테스트가 실패하는 것을 확인

GPT는 이 실행을 현재 환경에서 직접 재실행한 것이 아니므로 최종 종료 시 diff/테스트 구조를 독립 재검토한다.

## PHASE 3 전에 할 일

1. ✅ P2-REV-001 — AccessEnvelope-aware route/fallback.
2. ✅ P2-REV-002 — `or true` 제거, party ID RNG 참여 표본 검증.
3. ✅ P2-REV-003 — immutable definition hash.
4. ✅ 오래된 주석 정리 및 layout 태그 중립화.
5. ✅ Claude 전체 단위/통합/변이 테스트.
6. ⏳ **[GPT] P2-REV 최종 diff 재검토**.
7. ⏳ **[오너] layout v2 밀도·규모 최종 PLAYTEST 판정**.
8. 이후 PHASE 2 종료 → PHASE 3.

## 구현 주의 / 장기 인계

- **PHASE 3 함정**: 반드시 `FLR-028`을 읽는다. Player collision 전용 트리거로 구현 금지.
- **2층+ 인카운터**: `SYS-016` authored template 구조를 따른다.
- **PHASE 7 NPC**: `NPC-006` 경험 학습 + `NPC-007` 정보 비공개를 함께 적용.
- **언어/왕국 사회**: `WLD-011` 바벨탑 존재는 Canon, 세부 메커니즘은 TBD.
- **왕국 밸런스**: `WLD-012`; 70%를 하드 상수로 만들지 않는다.
- **NSG-017** 열매나무/소규모 몬스터 인접 스폰은 아직 미확정.
- `D-021`: 다음 설정서 개정 때 오르골 8/11/15 반영.
- `D-023`: `CHR-020`의 레벨당 포인트 DESIGN과 가지 3노드 개화 구조를 PHASE 6 전에 정합 확인.
- 마인드맵 전문화 임계/연관도/태그/가지 수는 TBD.
- `BASE_SPEED`는 PHASE 6에서 민첩 보정과 함께 재확정.
- PHASE 3에서 실제 함정/아이템 상호작용이 붙으면 `debug_overlay.gd` 삭제 예정.
- 다른 PC 작업 시 Godot `--import` 먼저.
- 배포 렌더링 경로는 PHASE 11 (`B-003`).
