# CURRENT_STATE.md — 현재 작업 상태

> 새 세션은 이 파일로 "지금 어디까지 왔는지"를 복원한다.
> 모든 작업 종료 시 최신 WORK REPORT로 이 파일을 갱신한다.

## 현재 위치

- **PHASE**: 0 (프로젝트 뼈대) — **완료 조건 충족, 오너 지시 대기**
- **저장소**: `https://github.com/aa0607aa/Tower-Dev.git` · `main` 브랜치
- **엔진**: Godot **4.7.1-stable** (`4.7.1.stable.official.a13da4feb`) 설치·실행 확인됨
- **다음 작업**: PHASE 1 (이동/카메라) — **오너 지시 전 착수 금지**

## 최근 WORK REPORT

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
