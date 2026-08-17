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
| `DECISIONS.md` | 결정 이력 (Resolved / Proposed / TBD) |
| `CURRENT_STATE.md` | 현재 작업 상태 (WORK REPORT 최신본) |
| `CHANGELOG.md` | 확정된 변경 이력 |

## 진실의 우선순위

오너 직접 지시/승인 → 설정서 v1.1 → DECISIONS.md의 Resolved → 개발 가이드(구현 방식에 한해) → 미승인 Proposal. 세계 설정이 충돌하면 항상 설정서 v1.1이 이긴다.
