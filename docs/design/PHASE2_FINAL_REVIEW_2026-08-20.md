# PHASE 2 최종 독립 검수 — GPT

> **검수 시각:** 2026-08-20 10:12 KST
> **검수 기준 main:** `8d1acc14289fb22acb8db064a9e70dd48322d8e5`
> **범위:** P2-T0~T7, P2-REV-001~003 반영본, 최신 D-024/D-025 문서 상태
> **판정:** **PHASE 2 종료 보류 — 수정 후 재검토 필요**
>
> 이 문서는 검수/인계 문서다. 아래 항목을 이유로 GPT가 구현 코드를 임의 수정하지 않았다.
> Claude가 수정·테스트한 뒤 GPT가 diff를 재검토하고, 오너 PLAYTEST 판정까지 확인한 후 PHASE 2를 닫는다.

---

## 1. 이미 통과한 부분

기존 GPT 지적 `P2-REV-001~003`은 현재 코드에 정상 반영되어 있다.

- `P2-REV-001`: 계단 BFS/fallback이 `AccessEnvelope`를 존중한다.
- `P2-REV-002`: `or true` 무효 assertion이 제거되고 party ID의 RNG 참여를 여러 seed 표본으로 검증한다.
- `P2-REV-003`: `definition_hash`가 함정의 `lethal/one_shot/clues`, 시작점 후보, 층 정체성 등 불변 의미를 포함한다.
- `FloorDefinition`과 `FloorState`의 정적/동적 책임 분리는 유지된다.
- `TerrainMutationState`는 `WorldState` 소유의 공유 물리 변경으로 분리되어 있고 `FloorState`에 복제되지 않는다.
- 1층 layout v2의 구역별 다양화와 `city/opencaves` 의미론적 태그 정리는 적절하다.
- Claude의 최신 기록상 단위 652단언 + 통합 20단언 통과, 반복 3회 및 변이 검증 기록이 존재한다.

GPT 환경에서는 Godot 4.7.1 바이너리를 직접 재실행하지 못하므로 위 실행 결과 자체는 Claude 로그를 근거로 하고, 코드는 독립 정적 검수했다.

---

## 2. PHASE 2 종료 전 수정할 항목

### P2-REV-004 — 2칸 통로가 실제로 3칸이 되는 로더 버그

**등급: BLOCKER / 실제 레이아웃 정의 오류**

`FloorDefinitionLoader._fill_segment()`는 다음 방식이다.

```gdscript
var half := width / 2
for dy in range(-half, half + 1):
```

GDScript에서 `int / int`는 정수 나눗셈이므로 `width = 2`이면 `half = 1`, 실제 오프셋은 `-1, 0, 1`의 **3칸**이 된다.

현재 `floor1_layout.json`은 통로 폭 `1/2/3/5`를 의도적으로 사용하고 있으며 주석도 2칸 통로를 별도 폭으로 취급한다. 따라서 저작 데이터와 실제 통행 지형이 다르다.

**수정 요구**
- 짝수/홀수 모두 `width`와 실제 생성 폭이 정확히 같게 `_fill_segment()`를 수정한다.
- `width=1,2,3,5`를 각각 독립 검증하는 회귀 테스트를 추가한다.
- 수정으로 실제 1층 기하가 바뀌므로 `definition_hash` 변경을 확인한다.
- 현재 배포 세이브가 없으므로 호환 마이그레이션은 필요 없지만, layout 체감이 변할 수 있어 오너가 짧게 재플레이한다.

---

### P2-REV-005 — Optional AI ranking 뒤에 실제 Validator가 없다

**등급: BLOCKER / `SYS-002`, `D-016` 신뢰 경계**

`StairResolver`의 문서화된 파이프라인은:

```text
Engine candidate → Hard Constraint → Engine score → Optional AI ranking
→ Validator 재검증 → top-band selection
```

이지만 실제 구현은 Hard Constraint를 **AI 호출 전에만** 적용한다. 이후:

```gdscript
var ranks = ai_ranker.call("rank", candidates)
```

처럼 엔진이 신뢰하는 `candidates` 배열/Dictionary/`WorldAnchor`를 그대로 AI adapter에 전달하고, AI 호출 이후 Hard Constraint를 다시 적용하지 않는다.

GDScript의 `Array`와 `Dictionary`는 reference 공유 객체다. 따라서 PHASE 9에서 붙는 잘못된/악의적인 adapter가 전달받은 후보의 `anchor`, `cost`, `score` 등을 직접 수정할 수 있다. 현재 `_NearStartRanker` 테스트는 점수 Dictionary만 반환하므로 이 경계를 검증하지 못한다.

**수정 요구**
- AI에는 trusted object reference가 아니라 deep-copy된/직렬화 가능한 **읽기 전용 projection**(`candidate_id`, story/score용 metadata 등)을 전달한다.
- AI 반환값은 알려진 candidate ID에 대한 제한된 score/ranking만 받는다.
- AI 결과 적용 후 **엔진이 원본 trusted candidate를 다시 Validator로 검증**한다.
- unknown ID, 후보 mutate 시도, NaN/비정상 점수, 경계 밖 anchor를 유도하는 테스트 ranker를 추가한다.
- AI가 실패해도 기존 engine scorer fallback은 그대로 유지한다.

---

### P2-REV-006 — AccessEnvelope를 물리 이동 후 되감는 구조

**등급: BLOCKER before PHASE 3 / P2-T4 실상호작용 경계**

현재 `player.gd`는:

```gdscript
var before := global_position
move_and_slide()
global_position = AccessService.clamp_move(access_envelope, before, global_position)
```

순서다. 최종 좌표는 경계 안으로 돌아오지만 `move_and_slide()`는 먼저 실제 물리 이동/충돌 질의를 수행한다. `D-017/FLR-024`는 유배자가 원인이 된 직접 영향이 맵의 끝 바깥에 영향을 주지 못하게 한다.

PHASE 2 회색박스에서는 경계 밖에 상호작용 대상이 거의 없어 문제가 보이지 않지만, PHASE 3에서 함정/물체/Area/상호작용이 붙으면 **최종 좌표만 되감는 것으로 인과 경계를 보장했다고 간주하면 안 된다.** 특히 CharacterBody 이동 자체가 경계 밖 물리 물체와 충돌/영향을 만들 수 있는 경로를 차단해야 한다.

**수정 요구**
- CharacterBody가 물리적으로 경계 밖 motion을 수행하기 전에 AccessEnvelope가 실제 허용 motion을 제한하도록 구조를 바꾼다.
- 방법은 구현 담당 판단: pre-motion 제한, 전용 boundary collision/gate, `test_move`/motion query 조합 등.
- 일반 NPC/야생동물은 이 boundary를 무시할 수 있어야 한다.
- 실제 CharacterBody E2E 테스트를 추가해 경계 밖 상호작용 대상에 접촉/영향이 발생하지 않음을 검증한다.

---

### P2-REV-007 — immutable definition hash에서 `space.tags` 누락

**등급: MEDIUM / PHASE 2 종료 전 수정 권장**

`P2-REV-003` 이후 주석은 `definition_hash`를 **저장된 회차 의미에 영향을 주는 불변 정의 전체**의 호환성 계약으로 정의한다.

그런데 room/pocket 로드 시 `tags`는 `FloorDefinition.spaces`에 저장되지만 hash part에는 `id + rect`만 들어간다. 현재 태그는 `inner_complex`, `landmark`, `collapsed_undercroft` 등이며 앞으로 계단 POI/인카운터/콘텐츠 의미 판단에 사용될 가능성이 높다.

따라서 동일 좌표라도 `landmark` 등 의미 태그가 바뀌면 정의 의미가 달라질 수 있는데, 현재 hash는 이를 감지하지 않는다.

**수정 요구**
- `tags`를 순서 비의존적으로 정규화(sort)해 immutable definition hash에 포함한다.
- 태그만 바꿨을 때 hash가 달라지는 테스트를 `test_hash_covers_immutable_definition()`에 추가한다.

---

## 3. 문서 정합성 오류 — D-025/NSG-017 반영 후 후처리 필요

### DOC-REV-001 — D-025가 `DECISIONS.md`의 코드 예시 안에 들어감

현재 `D-025` 본문이 `[Resolved]` 결정 목록이 아니라 파일 하단 `## 결정 추가 양식`의

```markdown
...
```

코드블록 안에 삽입돼 있다. `ITM-007` 자체는 Canon으로 존재하지만, 결정 이력 구조상 D-025가 실제 결정이 아니라 **예시 텍스트처럼 렌더링**된다.

**수정:** D-025를 D-024 다음의 `[Resolved]` 본문으로 이동하고, 결정 추가 양식에는 `D-0XX` 예시만 남긴다.

### DOC-REV-002 — NSG-017 상태가 문서끼리 충돌

- `ITM-007` / INDEX: NSG-017 승인 반영됨.
- `NOVEL_SOURCE_GAP_AUDIT.md`: 표에서는 RESOLVED라고 하면서 `다음 AI에게` 6번은 아직 GAP이라고 적음.
- `CURRENT_STATE.md`: Canon 155개, NSG-017 미확정이라고 적어 최신 156개/승격 상태와 어긋남.
- `docs/canon/INDEX.md`: 총합 156개와 ITM-007 행은 맞지만 도메인 지도의 ITM 항목 수가 **6**으로 낡아 있다(실제 7).

**수정:** 위 네 곳을 156개 / D-025 Resolved / ITM-007 상태로 통일한다.

### DOC-REV-003 — TEST_CHECKLIST의 PHASE 2 테스트 수가 낡음

`CURRENT_STATE`와 월간 로그는 P2-REV 이후 **단위 652 + 통합 20**으로 기록되어 있지만,
`docs/TEST_CHECKLIST.md` PHASE 2 설명은 아직 **단위 524 + 통합 20**이다.

**수정:** 최신 실행 기록 652/20으로 동기화하고, P2-REV-004~007의 회귀 테스트를 추가한 뒤 최종 수치를 다시 기록한다.

---

## 4. 오너의 2026-08-20 열매 식별 규칙 보충

오너가 이번 검수 요청에서 명시적으로 다음을 확정했다.

- 열매는 **외형만으로 효과를 확정할 수 없다.** 같은 외형이라도 월드에 따라 효과가 다를 수 있기 때문이다.
- 이것은 "먹기 전에는 어떤 방법으로도 알 수 없다"는 절대 규칙이 아니다.
- **감정 스킬, 실험, 경험, 지식, 분석 등 합법적인 정보 획득 수단으로 효과를 알아낼 수 있다.**
- 물리적인 시험도 분석의 일부가 될 수 있다. 예: 칼로 찔러 반응을 관찰하는 식.

현재 `ITM-002`는 "동일 외형이 동일 효과를 보장하지 않는다"까지만 명시하므로, 다음 문서 정리에서 이 식별 가능성도 오너 직접 확정으로 보강한다.

`ITM-007/D-025`의 **열매나무가 소규모 몬스터 집단 주변에 스폰되는 경향**은 현재 main에 실제 반영되어 있음을 확인했다. 확률·집단 규모·거리 반경은 계속 TBD다.

---

## 5. 최종 판정과 다음 Claude 순서

**PHASE 2는 아직 닫지 않는다.** 기존 구현의 큰 구조는 통과했지만, 위 항목 중 004~006은 PHASE 2가 책임진 지형/계단/행동반경 경계의 실제 정확성 문제다.

권장 처리 순서:

1. `P2-REV-004` — even corridor width 정확화 + 테스트
2. `P2-REV-005` — AI ranking trust boundary + post-validator + 악성 adapter 테스트
3. `P2-REV-006` — AccessEnvelope pre-physics 경계 + 실제 Player E2E
4. `P2-REV-007` — space tags hash 포함 + 테스트
5. `DOC-REV-001~003` 정리
6. 오너 열매 식별 규칙을 `ITM-002`/결정 이력에 기록
7. 전체 단위/통합/변이 테스트 실행
8. 오너가 폭 수정 후 layout v2를 짧게 재플레이
9. GPT가 diff 재검토 → 이상 없으면 PHASE 2 종료 판정

### 다음 AI에게

- 위 항목을 **편의상 생략하거나 PHASE 3로 조용히 넘기지 말 것.** PHASE 3는 함정/물체 상호작용을 붙이므로 P2-REV-006 경계가 먼저 안전해야 한다.
- P2-REV-005의 핵심은 "현재 AI가 없다"가 아니다. **PHASE 2가 만든 adapter 계약이 나중 AI에게 trusted mutable state를 넘기지 않도록 하는 것**이다.
- `D-025/ITM-007`은 이미 오너 승인 완료다. NSG-017을 다시 질문하지 않는다.
- 열매 효과 식별은 외형 단독 판별 불가이지, 감정/실험/경험/지식/분석 금지가 아니다.
