# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 모든 작업 종료 시 최신 WORK REPORT로 이 파일을 갱신한다.

## 현재 위치

- **PHASE**: 0 (프로젝트 뼈대) — **완료 (VERIFIED)**
- **저장소**: `https://github.com/aa0607aa/Tower-Dev.git` · `main` 브랜치
- **엔진**: Godot **4.7.1-stable** (`4.7.1.stable.official.a13da4feb`) 설치·실행 확인됨
- **현재 작업**: PHASE 1 착수 전 **설정(canon) 체계 정비 중** — 오너 지시
- **오너 결정 대기**: `D-012` 데이터 마이닝 대응 정책 (Q1/Q2/Q3)
- **canon**: `docs/SETTING_BIBLE_v1.1.docx` 입고 완료 · 전문 대조해
  `docs/canon/` **133항목 / 15도메인** 등재 완료. 충돌 0건
- **다음 작업**: PHASE 1 (이동/카메라) — **오너 지시 전 착수 금지**

## 최근 WORK REPORT

```
[WORK REPORT]
작업 ID: CANON-001
PHASE: 0 이후 / PHASE 1 착수 전 준비
목표: ① GPU 드라이버 문제 해결 ② canon 색인 체계 구축 ③ 데이터 마이닝 정책 검토
변경 파일:
- docs/SETTING_BIBLE_v1.1.docx (오너 배치 — canon 원본)
- docs/canon/README.md      (신규 — 색인 체계 정의 + 대조 결과)
- docs/canon/INDEX.md       (신규 — 전체 색인 133항목/15도메인)
- docs/canon/WLD.md  10  · HIS.md   5 · FLR.md  21 · CHR.md 17
- docs/canon/RAC.md   3  · SKL.md   9 · CBT.md  13 · MAG.md  5
- docs/canon/ITM.md   6  · FAC.md  11 · NPC.md   4 · KGD.md  7
- docs/canon/DGN.md   5  · GOD.md   5 · SYS.md  12
- docs/CANON_NOTES.md       (비움 — docs/canon/으로 통합, 포인터만 유지)
- docs/DATAMINING_POLICY.md (신규 — PROPOSAL)
- DECISIONS.md              (갱신 — D-012 Proposed 추가)
- docs/TEST_CHECKLIST.md    (갱신 — 0-3 검증 완료, 환경 이슈 기록)
- README.md                 (갱신 — 문서 지도, 실행 명령)
구현 내용:
- canon을 ID 붙은 낱개 항목으로 분해해 15개 도메인으로 분류. ID는 재사용 금지,
  코드 주석에서 근거로 인용 가능(`## FLR-004: ...`)
- 1차 색인 63항목(DECISIONS+개발가이드 기반) → 설정서 원본 입고 후 전문 대조 → **133항목으로 확장**
  신규 도메인 8개: HIS(역사·인과) RAC(종족) MAG(마법) ITM(아이템) NPC KGD(왕국·팩션)
  DGN(메인던전) GOD(신·신좌)
- 설정서 §26의 미정 영역 12개를 전부 TBD 항목으로 매핑 — "빈칸을 지어내는 사고"를 차단
- 데이터 마이닝 제안 타당성 검토 → 3 Tier 분리안으로 D-012 Proposed 등록
테스트:
- AMD 드라이버 설치 (Windows Update, 관리자 권한 승격):
  Microsoft 기본 디스플레이 어댑터 → AMD Radeon(TM) R5 240, OpenGL 3.3 Core Profile 실GPU
- 격리 테스트로 종료 크래시 원인 규명:
  headless exit 0 / 네이티브 GL 창 0xC0000409 (3/3) /
  **빈 프로젝트(Node2D 하나)도 동일 크래시 (3/3)** → 우리 코드 아님, 드라이버+엔진 문제
  Vulkan/D3D12 미지원 → GL 폴백 → 동일 / **ANGLE 강제 시 exit 0 (3/3)**
- 성공: ESC 종료 **오너가 직접 눌러 검증 완료** → PHASE 0 완료 조건 전부 충족
- 실패: 네이티브 OpenGL 종료 크래시 (환경 이슈, 우회 확보)
설정 관련 결정:
- **DECISION 필요**: D-012 데이터 마이닝 정책 Q1/Q2/Q3 — 특히 Q3(1층 지형 은닉 불가 확인)
- 새 canon을 만들지 않았다. 133항목 전부 설정서 원문 또는 DECISIONS.md에서 유래
- **[CANON CONFLICT] 0건** — 개발 가이드 v2.0과 설정서 v1.1은 정합했다
- 대조 중 발견한 주의점(충돌 아님): FAC-006 계단 리롤은 "의도된 변칙"으로 명시 허용 /
  RAC-002 거인 ×1.3과 "3배"는 다른 값 / CBT-010 성장곡선 효율을 공격력에 그대로 곱하면 안 됨 /
  SYS-012 레거시 텍스트 RPG 규칙은 canon에서 명시적으로 제거됨
알려진 문제:
- canon 색인 ID 재배정 1건 (FAC-006/007 → KGD-007/FAC-011). 원칙상 ID는 재사용 금지이나
  원본 입고 전 임시 색인 단계라 예외 처리. 흔적은 FAC.md 하단에 기록. 이후 재사용 없음
- 개발 PC 네이티브 OpenGL 종료 크래시 → `--rendering-driver opengl3_angle`로 우회.
  project.godot에는 넣지 않음(배포 렌더링 경로는 별도 결정 사항, BACKLOG)
- Mirage Driver(2008, 상태 Degraded)가 디스플레이 장치로 잡혀 있음 — 원격제어 SW 잔재로 추정
- 테스트 러너 미도입 (PHASE 1 착수 시 결정 필요)
다음 작업:
- 오너: D-012 결정, 설정서 docx 배치
- 이후: 원본 대조 검수 → PHASE 1 착수 지시 대기
완료 등급: VERIFIED (드라이버·크래시 원인 규명) / IMPLEMENTED (canon 색인 — 원본 대조 전)
Git commit: <CANON-001 커밋 해시로 채움>
```

## 이전 WORK REPORT

```
[WORK REPORT]
작업 ID: PHASE0-001
PHASE: 0 (프로젝트 뼈대)
목표: Godot 4.7.1 stable + GDScript 프로젝트 뼈대 생성, 실행 가능한 최소 Boot/Main 씬,
      개발 가이드 §6 폴더 구조, 코딩 규칙/CANON_NOTES/TEST_CHECKLIST 문서화
변경 파일:
- project.godot                        (신규)
- icon.svg                             (신규)
- .gitattributes                       (신규 — LF 정규화)
- res://scenes/boot/Boot.tscn          (신규)
- res://scenes/world/Main.tscn         (신규)
- res://scripts/core/boot.gd           (신규)
- res://scripts/core/main.gd           (신규)
- res://scripts/core/game_log.gd       (신규 — autoload)
- res://data/canon/canon.gd            (신규 — Resolved 상수만)
- docs/CANON_NOTES.md                  (신규)
- docs/CODING_STYLE.md                 (신규)
- docs/TEST_CHECKLIST.md               (신규)
- assets/STYLE_GUIDE.md                (신규)
- tests/README.md                      (신규)
- README.md                            (갱신 — 문서 지도/구조/실행법)
- CHANGELOG.md                         (갱신)
- CURRENT_STATE.md                     (갱신 — 이 파일)
- assets/ data/ scenes/ scripts/ 하위 폴더 (.gitkeep)
구현 내용:
- Godot 4.7.1 프로젝트 설정: GL Compatibility 렌더러, nearest 텍스처 필터(도트),
  1280x720 canvas_items 스트레치, main_scene = Boot.tscn
- 개발 가이드 §6 폴더 구조 전체 생성 (assets/data/scenes/scripts/tests/saves)
- Boot 씬 → 한 프레임 대기 후 Main 씬 전환. Main은 배경 + 상태 라벨만(게임 로직 없음),
  ESC / 창 닫기로 종료
- GameLog autoload (콘솔 로그 전용, GameState를 읽거나 쓰지 않음)
- data/canon/canon.gd 에 [Resolved] 상수만: 서든데스 3600초(D-010), 인간 평균 스탯 10(D-005),
  오르골 8/12/14 참고값(D-005, 자동 적용 금지), 수명 100년, 타일 32px.
  [TBD] 수치는 일절 넣지 않음
- 프로시저럴 지형 생성기 없음 (D-003). 6스탯 잔재 없음 (D-005). "오르골의 탑" 명칭 없음 (D-001)
테스트:
- 실행 명령:
  1) winget install --id GodotEngine.GodotEngine -e --version 4.7.1
  2) godot --version                                  → 4.7.1.stable.official.a13da4feb
  3) godot --headless --path . --import               → exit 0
  4) godot --headless --path . --quit-after 180       → exit 0
  5) godot --path . --quit-after 300  (실제 창)       → exit 0
- 성공:
  - 임포트 오류 0, 스크립트 파스 오류 0, 런타임 에러 0
  - Boot → Main 전환 로그 정상, 창 실행/종료 코드 0
- 실패 → 수정:
  - Boot._ready()에서 change_scene_to_file() 직접 호출 시
    "Parent node is busy adding/removing children, remove_child() can't be called"
    에러 발생 → `await get_tree().process_frame` 후 전환하도록 수정, 재실행하여 해소 확인
- 미검증 (오너 확인 필요):
  - **ESC 키 입력으로 종료**되는지 (자동 실행은 --quit-after로만 검증)
설정 관련 결정:
- 없음. 새 canon을 만들지 않았고 [TBD]를 임의로 채우지 않았다.
- 문서 위치 차이 1건은 협업 프로토콜 우선으로 처리:
  개발 가이드 §6은 docs/DECISIONS.md, 협업 프로토콜 §6은 루트 DECISIONS.md
  → 협업 프로토콜을 따라 **루트 유지**. README에 명시.
알려진 문제:
- 설정서 v1.1 원본(docx)이 docs/에 아직 없음. CANON_NOTES.md는 DECISIONS.md + 개발 가이드에서만
  유래했으므로 원본 입고 후 대조 검수 필요 (오너가 추가 예정)
- 이 PC에 OpenGL 3.3 지원 드라이버가 없어 Godot이 **ANGLE(Microsoft Basic Render Driver)**로
  폴백한다. 실행은 정상이나 GPU 가속이 아니므로 PHASE 8 도트 렌더링/성능 검증 결과는
  실제 사용자 환경과 다를 수 있다
- 테스트 러너 미도입 (PHASE 1 착수 시 GUT vs 자체 SceneTree 스크립트 결정 필요)
다음 작업:
- PHASE 1 (이동/카메라): 플레이어 임시 박스, 충돌, 8방향 연속 이동, 카메라, 벽 충돌
- 완료 조건: 테스트 방에서 벽 안 뚫고 부드럽게 이동 + 프레임 변화에 속도 안 흔들림
- **오너 지시 전 착수하지 않는다.**
완료 등급: VERIFIED
  (PHASE 0 완료 조건 "빈 화면까지 정상 실행·정상 종료 + Git 첫 커밋"은 충족.
   ESC 종료 키 입력만 오너 확인 대기 → 그 확인이 끝나면 PLAYTESTED 불필요 항목이므로 마감)
Git commit: 72c4ff4  (문서 스캐폴딩 초기 커밋: 26be95f)
```
