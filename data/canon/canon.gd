class_name Canon
extends RefCounted
## Canon 상수 — DECISIONS.md의 [Resolved] 항목만 담는다.
##
## 규칙:
## - 여기 없는 수치를 코드에 하드코딩하지 않는다. (개발 가이드 §B1-6)
## - [TBD] 항목(파생 능력식, 성장곡선 최종 수치, 명중/회피 등)은 절대 여기 넣지 않는다.
##   임의로 채우면 canon 위조가 된다. 필요하면 [CANON CONFLICT]로 오너에게 올린다.
## - 밸런스 튜닝 대상(DESIGN) 수치는 이후 data/curves/ 등 데이터 파일로 분리한다.

## D-010: 1층 서든데스 — 눈을 뜬 뒤 정확히 3600초.
const FLOOR1_SUDDEN_DEATH_SECONDS: float = 3600.0

## D-005: 스탯은 힘·민첩·지능 3종. 인간 평균은 각 10.
const HUMAN_AVERAGE_STAT: int = 10

## D-021: 오르골(특수 개체) 초기 스탯 8/11/15. (합 34)
##
## ⚠ 설정서 v1.1 §24.1은 아직 8/12/14다. 오너가 소설 원문으로 배분을 정정했고
## 우선순위 1(오너 직접 지시)이 설정서보다 앞선다. 다음 설정서 개정 때 반영한다.
##
## 참고값일 뿐이며 랜덤 유배자 생성에 자동 적용하지 않는다. (D-002)
const ORGEL_INITIAL_STATS := {"STR": 8, "AGI": 11, "INT": 15}

## 설정서 v1.1: 유배자 총 수명 100년.
const EXILE_LIFESPAN_YEARS: int = 100

## 개발 가이드 §9 (DESIGN): 맵 타일 32×32 기준.
## 캐릭터 스프라이트 크기(48/64)는 프로토타입 비교 후 확정 — 아직 여기 넣지 않는다.
const TILE_SIZE: int = 32
