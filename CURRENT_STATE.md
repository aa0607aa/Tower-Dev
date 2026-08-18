# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 상세 시계열과 판단 근거는 `docs/log/2026-08.md`를 우선 확인한다.

## 현재 위치 — 2026-08-18 11:44 KST

- **PHASE**: 0 — 완료 (`VERIFIED`)
- **다음 PHASE**: 1 — 이동/카메라. **오너 지시 전 구현 착수 금지**
- **저장소**: `aa0607aa/Tower-Dev`, `main`
- **엔진**: Godot `4.7.1-stable`
- **canon 색인**: 141개 ID / 15도메인 / 통합 포인터 3개, PROPOSAL 0건
- **설정서 원본**: `docs/SETTING_BIBLE_v1.1.docx`
- **AI 검수용 사본**: `docs/SETTING_BIBLE_v1.1.md` — 직접 편집 금지, docx 개정 시 변환기 재실행
- **오너 결정 대기**: 없음. `D-012`~`D-015` 모두 Resolved

## G-1 ~ G-5 상태

- [x] **G-1 자동 테스트 러너** — 자체 `SceneTree` 러너 확정 (`D-015`)
  - 외부 GUT 플러그인은 현재 도입하지 않는다.
  - 테스트 본문은 순수 함수 + 작은 assertion helper 중심으로 프레임워크 중립 유지.
  - PHASE 1 착수 시 `tests/runner.gd`부터 구현한다.
- [x] **G-2 출처 정확성 재검수** — 원문 역대조 완료.
- [x] **G-3 판단 근거 검수** — 완료.
  - `HIS-003` DESIGN 과승격 제거
  - `CBT-007` → CANON(방향)/TBD(수치)
  - `CBT-013`의 "히트박스만 가능" 과도한 구현 고정 완화
  - `CHR-011`은 상성만으로 승패를 확정하는 hard lock만 금지
  - `RAC-004` → 열린 목록 CANON / 상세 TBD
  - `FLR-011`의 `clues[]` 강제는 구현 Hard Rule임을 명시
- [x] **G-4 내용 중복 검사** — 완료.
  - `CBT-005 → ITM-003`
  - `CHR-006 → SKL-003` (3점 투자→스킬 후보)
  - `FAC-004 → NPC-003` (시설 경험 정보 전파)
  - `WLD-004 → CHR-012` (사망 시 보존/초기화 상세)
- [x] **G-5 NPC-005 LOD 결정성 검수** — 완료.
  - catch-up만으로 충분하지 않음.
  - RNG 독립성, 승격 전 catch-up, 안정적 사건 순서, 논리 시각 이벤트 반영,
    결정성 상태 저장, 저LOD 전용 확률표 금지를 `D-014`/`NPC-005`에 추가.
  - `TEST_CHECKLIST G-7` 신규.

## 다음 작업

오너가 PHASE 1 착수를 지시하면 구현 담당이 저장소를 실제로 확인한 뒤 티켓 타당성을 검토하고 시작한다.
첫 구현 묶음:

1. `tests/runner.gd` — 자체 SceneTree 테스트 러너 골격
2. 이동 벡터 순수 로직 — 대각선 정규화/프레임 독립성을 자동 테스트 가능하게 분리
3. 플레이어 임시 노드 + `CharacterBody2D` 충돌/8방향 이동
4. 테스트 방 + 벽 충돌
5. Camera2D
6. headless 자동 테스트 + 창 실행 검증
7. 오너 로컬 PLAYTESTED — 이동감/미끄러움/카메라 감각

PHASE 1의 정확한 티켓은 구현 담당이 현재 노드 구조를 확인한 뒤 조정할 수 있다. Canon/TBD를 건드리는 변경은 금지한다.

## 테스트 러너 결정 — D-015

기본 실행 예정:

```bash
godot --headless --path . --script res://tests/runner.gd
```

GUT 재검토 조건: fixture/mock/비동기/리포팅 요구가 반복되어 자체 runner/helper 유지보수가 실제 게임 테스트보다 부담이 될 때.

## 환경/협업 주의사항

- 개발 PC 네이티브 OpenGL 종료 크래시는 프로젝트 코드 문제가 아니다. 필요 시
  `--rendering-driver opengl3_angle` 사용. `project.godot` 배포 설정으로 고정하지 않는다.
- 다른 PC에서 처음 작업하면 `.godot/`이 없으므로 `--import` 먼저 실행한다.
- PowerShell 다중행 커밋 메시지는 `git commit -F <파일>` 사용. 커밋 성공 확인 후 SHA 기록.
- Markdown 끝 LF 유지.
- `docs/SETTING_BIBLE_v1.1.docx`가 바뀌면 `tools/docx_to_md.ps1`을 즉시 재실행한다.
- 설정서 밖의 새 확정 규칙은 `DECISIONS.md`뿐 아니라 `docs/canon/INDEX.md`의 정본 외 유래 표도 함께 확인한다.

## 최근 WORK REPORT

```text
[WORK REPORT]
작업 ID: PRE-PHASE1-AUDIT-001
PHASE: PHASE 0 완료 / PHASE 1 착수 전
목표: G-1 테스트 러너 확정 + G-3/G-4/G-5 설계 감사 종료
결과:
- D-015: 자체 SceneTree 러너 Resolved
- G-3 판단 근거 감사 완료
- G-4 내용 중복 4묶음 정리
- G-5 NPC LOD 결정성 불변식 보강
- G-1~G-5 전부 완료
오너 결정 필요: 없음
다음 작업: 오너의 PHASE 1 착수 지시 대기
```
