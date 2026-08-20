# GPT PHASE 2 최종 독립 검수 — 2026-08-20 10:13 KST

> **월간 로그 병합용 보조 기록.**
> `docs/log/2026-08.md`가 매우 커 GitHub connector로 전체 교체하지 않는다.
> 다음 로컬 작업 가능한 Claude/AI는 이 항목을 월간 로그 맨 아래에 병합한 뒤 본 파일을 삭제한다.

## 일시

- **2026-08-20 10:13 KST** — 최초 작업 로그 커밋 `205c02522a3b0f031cb12ce8822255bb0109865e`의 GitHub 시각(10:13:27 KST)
- 기준 main: `8d1acc14289fb22acb8db064a9e70dd48322d8e5`
- 검수 문서 커밋: `69c64207e2f1c86b418688220b6244483307513c` (10:12:46 KST)

## 담당

GPT — PHASE 2 독립 코드/테스트/Canon 정합성 검수

## 요청

오너 요청:

> 클로드한테 017 허용하라고 하고 본문 고치라고 시켜뒀거든?
> 페이즈 2는 얼추 끝난 것 같으니까 그것 좀 검토해줄래?

같은 요청에서 열매 식별 규칙을 보충 확정:

- 같은 외형이라도 월드마다 효과가 달라질 수 있으므로 **외형만으로 효과를 확정할 수 없다**.
- 감정 스킬·실험·경험·지식·분석 등으로는 알아낼 수 있다.
- 물리 시험(예: 칼로 찔러 반응 관찰)도 분석 수단이 될 수 있다.
- 따라서 원작의 "먹어보기 전에는 알 방법이 없다"를 모든 비섭취 식별 수단 금지로 확대하지 않는다.

## 작업

1. 최신 main 및 월간 로그를 재확인했다.
2. Claude가 NSG-017을 실제로 `D-025/ITM-007`로 승격했고 설정서 §24.1도 8/11/15로 수정한 것을 확인했다.
3. P2-T0~T7과 P2-REV-001~003 최종 구현을 독립 정적 검수했다.
4. 다음 파일/경계를 집중 검토했다.
   - `floor_definition.gd`
   - `floor_definition_loader.gd`
   - `floor_populator.gd`
   - `floor_state.gd`
   - `floor_save.gd`
   - `access_envelope.gd` / `access_service.gd`
   - `player.gd`
   - `stair_resolver.gd`
   - PHASE 2 관련 단위/통합 테스트
   - `floor1_layout.json`
5. 기존 P2-REV-001~003은 정상 반영됐다고 판정했다.
6. 새 수정 필요사항 `P2-REV-004~007`, 문서 정합성 `DOC-REV-001~003`을 발견해
   `docs/design/PHASE2_FINAL_REVIEW_2026-08-20.md`에 상세 인계했다.
7. 오너의 이번 열매 식별 보충을 `ITM-002`에 즉시 반영했다 (`a3c8c0f8d80ef12e440d9fe9b8984e18d43f332e`).

## 근거 / 발견사항

### P2-REV-004 — BLOCKER

`FloorDefinitionLoader._fill_segment()`가 `half = width / 2` 후 `range(-half, half + 1)`을 사용한다.
GDScript의 int/int 나눗셈은 정수 나눗셈이므로 `width=2`가 실제 3칸으로 만들어진다.
현재 1층 authored JSON은 폭 2를 의도적으로 여러 번 사용하므로 실제 레이아웃 정의 오류다.

### P2-REV-005 — BLOCKER

`StairResolver` 주석/설계는 Optional AI ranking 뒤 Validator 재검증을 요구하지만 실제 코드는
Hard Constraint를 AI 전 한 번만 적용한다. 더구나 AI ranker에 trusted `Array[Dictionary]`를 그대로 넘긴다.
GDScript Array/Dictionary는 reference 공유이므로 adapter가 후보 자체를 변경할 수 있다.
AI에는 projection을 넘기고 결과 적용 후 엔진 원본 후보를 재검증해야 한다.

### P2-REV-006 — BLOCKER before PHASE 3

Player는 `move_and_slide()` 후 최종 위치를 AccessEnvelope로 되감는다.
최종 좌표만 경계 안이어도 CharacterBody가 이미 물리 이동/충돌을 수행했으므로,
PHASE 3에서 경계 바깥 물체/상호작용이 붙기 전에 pre-physics 수준에서 경계를 막아야 한다.
일반 NPC/야생동물은 계속 자유 통과해야 한다.

### P2-REV-007 — MEDIUM

`definition_hash`는 immutable floor definition 전체를 호환 계약으로 정의했지만 `space.tags`가 빠져 있다.
`landmark`, `inner_complex` 등 의미 태그는 향후 gameplay semantics에 영향을 줄 수 있으므로 정규화 후 hash에 포함한다.

### 문서 정합성

- `D-025`가 `DECISIONS.md`의 `[Resolved]` 본문이 아니라 **결정 추가 양식 code block 안**에 잘못 들어갔다.
- `ITM-007`/INDEX에는 NSG-017 승격이 반영됐지만 `CURRENT_STATE`는 아직 155개/미확정이라고 적혀 있다.
- `NOVEL_SOURCE_GAP_AUDIT`는 표에서 RESOLVED라고 한 뒤 다음 AI 6번에서 다시 "아직 GAP"이라고 적는다.
- INDEX 총합은 156개지만 도메인 지도 ITM 수가 6으로 남아 있다(실제 7).
- TEST_CHECKLIST PHASE 2 실행수는 524+20으로 낡았고 최신 월간 로그는 652+20이다.

## 현재 판정

- **기존 P2-REV-001~003: 통과.**
- **PHASE 2 전체: 종료 보류.**
- P2-REV-004~006을 수정하기 전 PHASE 3 상호작용 구현으로 넘어가지 않는다.
- P2-REV-007과 문서 정합성도 가능하면 같은 수정 묶음에서 닫는다.

## 다음 AI에게

- [ ] `docs/design/PHASE2_FINAL_REVIEW_2026-08-20.md`를 먼저 읽는다.
- [ ] P2-REV-004: even corridor exact-width 수정 + 1/2/3/5 테스트.
- [ ] P2-REV-005: AI adapter에 trusted mutable state를 넘기지 않고 post-AI Validator 추가 + 악성 ranker 테스트.
- [ ] P2-REV-006: AccessEnvelope를 실제 motion 전에 적용 + CharacterBody E2E 경계 테스트.
- [ ] P2-REV-007: space tags를 immutable hash에 포함 + 태그 변경 hash 테스트.
- [ ] DOC-REV-001~003 정리.
- [x] **오너 열매 식별 보충을 `ITM-002`에 반영 완료** (`a3c8c0f8`). 외형 단독 판별 불가이지 감정/실험/경험/지식/분석 금지가 아니다.
- [ ] 전체 단위/통합/변이 테스트 재실행.
- [ ] 통로 폭 수정으로 실제 geometry/hash가 바뀌므로 오너에게 짧은 layout 재플레이 요청.
- [ ] 수정 완료 후 GPT에게 diff 재검토 요청.
- [ ] 이 로그를 `docs/log/2026-08.md`에 병합 후 삭제.

## 오너 결정 필요

없음. 현재 발견사항은 기존 Canon/Resolved 설계를 정확히 구현하기 위한 수정이며 새로운 Canon 결정을 요구하지 않는다.
열매 식별 규칙은 이번 메시지에서 오너가 이미 직접 확정했고 `ITM-002`에 반영됐다.

## 산출물

- `docs/design/PHASE2_FINAL_REVIEW_2026-08-20.md`
- `docs/log/2026-08-20_GPT_PHASE2_FINAL_REVIEW.md`
- `docs/canon/ITM.md` (`ITM-002` 식별 규칙 보충)
- 검수 문서 커밋 `69c64207e2f1c86b418688220b6244483307513c`
- 최초 로그 커밋 `205c02522a3b0f031cb12ce8822255bb0109865e`
- 열매 식별 Canon 보충 `a3c8c0f8d80ef12e440d9fe9b8984e18d43f332e`
