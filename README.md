# 탑 (The Tower)

2D 도트 그래픽 · **반실시간 던전 크롤러** · Godot 4.7.1 stable + GDScript

플레이어는 랜덤 생성된 유배자로 시작해 실제 맵을 탐색한다. 맵·함정·계단·아이템·NPC·전투는 실제 게임 데이터로 존재하며, AI는 엔진을 대신하지 않고 NPC 대화·비정형 행동 같은 비정형 영역만 담당한다. (오르골은 기본 주인공이 아니라 특수 개체다.)

---

## 새 작업을 시작하는 에이전트/사람은 이 순서로 읽는다

1. **COLLABORATION_PROTOCOL.md** — 협업 규칙 (필수, 가장 먼저)
2. **docs/SETTING_BIBLE** — 세계관 canon (v1.1)
3. **DECISIONS.md** — 확정된 결정 이력
4. **CURRENT_STATE.md** — 지금 어디까지 왔나
5. **CHANGELOG.md** — 무엇이 바뀌었나
6. 최근 **Git diff / 관련 코드** — 실제 상태

## 문서 지도

| 파일 | 역할 |
| --- | --- |
| `COLLABORATION_PROTOCOL.md` | 다중 에이전트 협업 규칙 (개발 가이드와 독립 관리) |
| `docs/DEVELOPMENT_GUIDE.md` | 통합 개발 가이드라인 v2.0 (구현 방식) |
| `docs/SETTING_BIBLE_v1.1_README.md` | 세계관 canon 원본 배치 안내 |
| **`docs/SETTING_BIBLE_v1.1.docx`** | **세계관 canon 원본 — 진실. 충돌 시 항상 이긴다** |
| `docs/SETTING_BIBLE_v1.1.md` | 위의 자동 생성 사본 (canon 아님 · 직접 편집 금지) |
| `tools/docx_to_md.ps1` | 사본 생성기 — docx 개정 시 재실행 |
| **`docs/canon/INDEX.md`** | **Canon 전체 색인 (133항목/15도메인) — 찾을 때 여기부터** |
| `docs/canon/README.md` | Canon 색인 체계의 정의 (ID 규칙·상태·작성법) |
| `docs/CANON_NOTES.md` | (비움 — `docs/canon/`으로 통합) |
| `docs/DATAMINING_POLICY.md` | 데이터 마이닝 대응 정책 (승인됨 — D-012) |
| `docs/BACKLOG.md` | 나중에 할 것 / MVP 제외 범위 |
| `docs/CODING_STYLE.md` | GDScript 코딩 규칙 + 아키텍처 규칙 |
| `docs/TEST_CHECKLIST.md` | PHASE별 테스트 기준 및 필요 완료 등급 |
| `DECISIONS.md` | 결정 이력 (Resolved / Proposed / TBD) |
| `CURRENT_STATE.md` | 현재 작업 상태 (WORK REPORT 최신본) |
| `CHANGELOG.md` | 확정된 변경 이력 |
| `assets/STYLE_GUIDE.md` | 도트 아트 규칙 (PHASE 8에서 확정) |

> `DECISIONS.md`는 협업 프로토콜 §6에 따라 **저장소 루트**에 둔다.
> (개발 가이드 §6의 폴더 그림은 `docs/DECISIONS.md`로 그려져 있으나, 협업 프로토콜이 우선한다.)

## 프로젝트 구조

```
tower/
├─ project.godot          # Godot 4.7.1 stable · GL Compatibility · nearest filter
├─ icon.svg
├─ assets/                # characters enemies tilesets items effects ui + STYLE_GUIDE.md
├─ data/                  # canon run world floors/floor1_fixed items enemies traps skills fruits curves
├─ scenes/                # boot world player npc combat ui
├─ scripts/               # core world player combat npc items save ai
├─ tests/
└─ saves/                 # 로컬 테스트용 (git 제외)
```

## 다른 PC에서 이어받기

```
git clone https://github.com/aa0607aa/Tower-Dev.git tower
cd tower
winget install --id GodotEngine.GodotEngine -e --version 4.7.1
godot --path . --headless --import      # 최초 1회: 에셋 임포트
```

`.godot/` 폴더는 **일부러 저장소에 올리지 않는다.** Godot이 프로젝트를 열 때 자동 생성하는
캐시라서, 커밋하면 PC마다 내용이 달라 매번 충돌한다. `--import` 한 번이면 재생성된다.

> 새 PC에서는 렌더링 드라이버 옵션이 다를 수 있다. 아래 실행 절의 ANGLE 옵션은
> **현재 개발 PC 전용 우회**이므로, 다른 PC에서는 먼저 옵션 없이 실행해 보고
> 종료 시 크래시가 나면 그때만 붙인다.

## 실행

```
godot --path . --headless --import                  # 임포트/파스 오류 확인
godot --path .                                      # 창 실행 (ESC로 종료)
godot --path . --rendering-driver opengl3_angle     # ↑가 종료 시 크래시하면 이걸로
```

> `--rendering-driver opengl3_angle`은 **현재 개발 PC 전용 우회**다.
> 이 PC의 AMD 드라이버가 네이티브 OpenGL 종료 시 크래시하기 때문이며, 다른 환경에서는
> 그냥 `godot --path .`로 실행하면 된다. 자세한 근거는 `docs/TEST_CHECKLIST.md`.

## 진실의 우선순위

오너 직접 지시/승인 → 설정서 v1.1 → DECISIONS.md의 Resolved → 개발 가이드(구현 방식에 한해) → 미승인 Proposal. 세계 설정이 충돌하면 항상 설정서 v1.1이 이긴다.
