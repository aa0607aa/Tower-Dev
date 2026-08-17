# INDEX — Canon 전체 색인

> **canon을 찾을 때 여기부터 읽는다.** 체계 설명은 [README.md](README.md).
> 원본은 `docs/SETTING_BIBLE_v1.1.docx`이며 이 색인과 다르면 **원본이 이긴다.**

**현재 63개 항목** · CANON 41 · DESIGN 9 · TBD 12 · PROPOSAL 1
*(설정서 원본 미입고 — 전 항목 대조 검수 대기. README §현재 상태 참고)*

## 빠르게 찾기

```
grep -rn "TBD" docs/canon/            # 미정 항목 전부 — 임의 확정 금지 목록
grep -rn "PROPOSAL" docs/canon/       # 승인 대기 제안
grep -rn "FAC-" docs/canon/           # 계단·시설 관련 전부
grep -rn "FLR-004" . --include=*.gd   # 이 canon을 참조하는 코드
```

---

## WLD — 세계 구조 ([WLD.md](WLD.md))

| ID | 제목 | 상태 |
| --- | --- | --- |
| WLD-001 | 탑의 층 구조 (0층→1층→왕국→리프트→메인던전4) | CANON |
| WLD-002 | 회차 ⊃ 월드 | CANON |
| WLD-003 | 상태 3계층 RunState/WorldState/FloorState | CANON |
| WLD-004 | 죽음은 회귀가 아니라 새 회차 | CANON |
| WLD-005 | 유배자 총 수명 100년 | CANON |
| WLD-006 | 0층에서 100년을 전부 소모하면? | **TBD** |
| WLD-007 | 월드별 왕국까지의 층수 (30~80) | DESIGN |
| WLD-008 | 열매 효과는 월드별 고정 | CANON |
| WLD-009 | 세계 4축과 인과 그래프 | CANON / **TBD** |
| WLD-010 | 메인던전 4개, 심연 고정 | CANON / **TBD** |

## FLR — 층 ([FLR.md](FLR.md))

| ID | 제목 | 상태 |
| --- | --- | --- |
| FLR-001 | 1층 지형은 고정 | CANON |
| FLR-002 | 1층에서 랜덤인 것은 배치뿐 | CANON |
| FLR-003 | 1층에 프로시저럴 지형 생성기를 만들지 않는다 | CANON |
| FLR-004 | 1층 서든데스는 3600초 | CANON |
| FLR-005 | 서든데스는 즉사가 아니라 순차 붕괴 | CANON |
| FLR-006 | 1층에는 생명의 샘과 마인드맵이 없다 | CANON |
| FLR-007 | 초기 장비는 전 유배자 공통 대거 | CANON |
| FLR-008 | 1층 "시스템 미작동"의 정확한 범위 | CANON |
| FLR-009 | "2층 이후 탑 보정"의 세부 목록 | **TBD** |
| FLR-010 | 1층의 핵심 위협은 함정과 고참 유배자 | CANON |
| FLR-011 | 모든 치명 함정에는 사전 단서가 필수 | CANON |

## CHR — 캐릭터 ([CHR.md](CHR.md))

| ID | 제목 | 상태 |
| --- | --- | --- |
| CHR-001 | 플레이어는 랜덤 생성 유배자 | CANON |
| CHR-002 | 스탯은 힘·민첩·지능 3종 | CANON |
| CHR-003 | 인간 평균 스탯은 각 10 | CANON |
| CHR-004 | 오르골 초기 스탯 8/12/14는 참고값 | CANON |
| CHR-005 | v1.0의 "합계 65 vs 30" 충돌은 폐기됨 | CANON |
| CHR-006 | 레벨당 스탯 포인트 1, 3점 단위로 스킬 후보 | CANON |
| CHR-007 | 최종 효율 계산 구조 | DESIGN |
| CHR-008 | 성장곡선 기준점 | DESIGN |
| CHR-009 | 파생 능력식과 성장곡선 최종 수치 | **TBD** |
| CHR-010 | 랜덤 유배자 생성 규칙 | **TBD** |
| CHR-011 | 힘→민첩→지능 상성 | CANON / **TBD** |
| CHR-012 | 회차를 넘어 보존/초기화되는 것 | CANON |

## FAC — 특수 시설 ([FAC.md](FAC.md))

| ID | 제목 | 상태 |
| --- | --- | --- |
| FAC-001 | 계단은 파티별 귀속 특수 시설 | CANON |
| FAC-002 | 단일 stair_id로 모델링하지 않는다 | CANON |
| FAC-003 | 계단은 직접 발견해야 한다 | CANON |
| FAC-004 | 특수 시설은 NPC에게 투명하다 | CANON |
| FAC-005 | 파티 탈퇴 시 계단 처리 | **TBD** |
| FAC-006 | 리프트 규칙 | **TBD** |
| FAC-007 | 모루·만신전 규칙 | **TBD** |

## CBT — 전투 ([CBT.md](CBT.md))

| ID | 제목 | 상태 |
| --- | --- | --- |
| CBT-001 | 전투와 이동은 반실시간 | CANON |
| CBT-002 | 월드 시간은 별도 Simulation Clock이 관리 | DESIGN |
| CBT-003 | 4단계 피해 구조 | DESIGN |
| CBT-004 | 크리티컬은 랜덤 %가 아니다 | CANON |
| CBT-005 | 무기 수명 | CANON / **TBD** |
| CBT-006 | 명중/회피·급소·저항 수치 | **TBD** |
| CBT-007 | 기습은 피해량보다 관통·절삭에 작용 | DESIGN |
| CBT-008 | 공격은 wind-up → active → recovery | DESIGN |
| CBT-009 | 이동 속도 보정 요소 | DESIGN |

## SKL — 스킬·마인드맵 ([SKL.md](SKL.md))

| ID | 제목 | 상태 |
| --- | --- | --- |
| SKL-001 | 마인드맵을 열면 시뮬레이션 일시정지 | CANON |
| SKL-002 | 1층에서는 마인드맵을 쓸 수 없다 | CANON |
| SKL-003 | 스탯 3점 투자마다 스킬 후보 발생 | CANON |
| SKL-004 | 유니크 스킬은 회차 전체에서 유일성 관리 | CANON |
| SKL-005 | 전체 스킬 트리 | **TBD** |

## SYS — 메타 규칙 ([SYS.md](SYS.md))

| ID | 제목 | 상태 |
| --- | --- | --- |
| SYS-001 | 게임 엔진이 진실의 단일 출처(SSOT) | CANON |
| SYS-002 | AI는 GameState를 직접 수정하지 않는다 | CANON |
| SYS-003 | 모든 랜덤은 시드 또는 결과를 저장한다 | CANON |
| SYS-004 | 시각 오브젝트와 데이터 객체를 분리한다 | CANON |
| SYS-005 | 정보 비대칭 — 미발견 정보는 누출되지 않는다 | CANON |
| SYS-006 | AI는 이미 생성된 것을 바꾸지 않는다 | CANON |
| SYS-007 | AI가 꺼져도 게임은 동작한다 | CANON |
| SYS-008 | 정식 명칭은 「탑」 | CANON |
| SYS-009 | 데이터 마이닝 대응 정책 | **PROPOSAL** |

---

## TBD 전체 목록 (임의 확정 금지)

구현 중 이 항목이 필요해지면 **멈추고 오너에게 묻는다.** 기본값을 지어내지 않는다.

| ID | 미정인 것 | 언제 막히나 |
| --- | --- | --- |
| WLD-006 | 0층 100년 소진 결과 | 0층 구현 |
| WLD-009 | 세계 4축·인과 그래프 수치 | 왕국 단계 (MVP 이후) |
| WLD-010 | 심연 외 메인던전 11종 | MVP 이후 |
| FLR-009 | 2층 이후 탑 보정 세부 목록 | PHASE 6 |
| CHR-009 | 파생 능력식, 성장곡선 최종 수치 | PHASE 6 |
| CHR-010 | 랜덤 유배자 생성 규칙 | PHASE 6 |
| CHR-011 | 힘/민첩/지능 상성 보정 수치 | PHASE 4~6 |
| FAC-005 | 파티 탈퇴 시 계단 유지/재생성 | PHASE 7 |
| FAC-006 | 리프트 랭크·실패·키 보안 | MVP 이후 |
| FAC-007 | 모루 미니게임·만신전 규칙 | MVP 이후 |
| CBT-006 | 명중/회피·급소 배율·마법 저항·무기 가중치 | PHASE 4 |
| SKL-005 | 전체 스킬 트리 | MVP 이후 |

## 승인 대기 (PROPOSAL)

| ID | 제안 | 문서 | 대응 결정 |
| --- | --- | --- | --- |
| SYS-009 | 데이터 마이닝 대응 정책 | `docs/DATAMINING_POLICY.md` | DECISIONS `D-012` |
