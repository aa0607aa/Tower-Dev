# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-18 11:23 KST

- **PHASE**: 0 — 완료 (`VERIFIED`)
- **다음 PHASE**: 1 — 이동/카메라. **오너 지시 전 착수 금지**
- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **엔진**: Godot `4.7.1-stable`
- **canon**: `docs/canon/` 141항목 / 15도메인, PROPOSAL 0건
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지, docx 개정 시 변환기 재실행

## 현재 인계 우선순위

1. 🔴 **G-1 테스트 러너 결정 — PHASE 1 착수의 유일한 선행조건**
   - GUT 같은 외부 플러그인 vs 자체 `SceneTree` 러너
   - 구현 담당 의견: 자체 러너로 시작하되 테스트를 프레임워크 중립(순수 함수 + 단순 assert)으로 작성
   - `docs/BACKLOG.md` B-004, `docs/TEST_CHECKLIST.md` 참조
   - **오너 결정 필요**: 설계 담당 검토 후 최종 선택
2. 🟠 **G-3 판단 근거 검수**
   - 판단 필드 36건(기존 19 + G-2 과정 추가 17) 대조
   - PHASE 1과 병렬 가능하지만 코드가 canon 판단을 주석으로 인용하기 전 마치는 것이 바람직
3. 🟡 **G-4 내용 중복 잔존 검사**
   - WLD↔HIS/ITM/KGD, CHR↔RAC, CBT↔ITM 우선
4. 🟡 **G-5 NPC-005 LOD 결정성 검수**
   - catch-up만으로 SYS-003을 만족하는지 추가 제약 검토

**G-2 출처 정확성 재검수는 완료**됐고, 구현 담당이 원문과 재대조하여 지적 사항이 맞음을 확인했다.

## 최신 인계에서 확인된 주의사항

- `docs/log/2026-08.md`가 현재 가장 최신의 인계 기준이다.
- G-1만 PHASE 1 착수를 막는다. G-3/G-4/G-5는 구현과 병렬 진행 가능하다.
- 개발 PC 네이티브 OpenGL 종료 크래시는 프로젝트 코드 문제가 아니며, 로컬에서는 필요 시
  `--rendering-driver opengl3_angle`을 사용한다. 배포 설정으로 고정하지 않는다.
- 다른 PC에서 작업 시작 시 `.godot/`은 저장소에 없으므로 먼저 `--import`를 실행한다.
- PowerShell에서 여러 줄 커밋 메시지는 `git commit -F <파일>`을 사용한다.
  커밋 실패 뒤 `rev-parse HEAD`를 실행하면 이전 커밋 SHA가 나올 수 있으므로 성공 여부를 먼저 확인한다.
- Markdown 문서를 수정할 때 파일 끝 LF를 유지한다.

## 오너 결정 대기

- **G-1 자동 테스트 러너 선택** — 현재 유일한 즉시 결정 필요 항목.
- D-012, D-013, D-014는 모두 Resolved.

## 최근 WORK REPORT

```text
[WORK REPORT]
작업 ID: HANDOFF-001
PHASE: PHASE 0 완료 / PHASE 1 착수 전
목표: 최신 Git 인계 상태 동기화
확인:
- 최신 커밋 191b1f4까지 확인
- docs/log/2026-08.md 최신 미완료 G-1/G-3/G-4/G-5 확인
- DECISIONS D-001~D-014 확인
- BACKLOG B-004 테스트 러너 미결정 확인
- G-2 구현 담당 교차검증 완료 확인
발견한 문제:
- 기존 CURRENT_STATE의 "오너 결정 대기: 없음"이 최신 로그의 G-1 결정 대기와 불일치
조치:
- 본 파일을 최신 인계 기준으로 재작성
다음 작업:
- 오너 요청에 따라 G-1 판단 또는 G-3/G-4/G-5 검수 진행
완료 등급: VERIFIED (문서/커밋 인계 확인)
```
