class_name Movement
extends RefCounted
## 이동 계산 — 순수 함수만 담는다.
##
## 노드에 의존하지 않으므로 headless 테스트로 전부 검증할 수 있다. (D-015 원칙 2)
## `Player`는 입력을 읽어 여기에 넘기고 결과를 `velocity`에 실을 뿐이다.
##
## canon 근거:
## - CBT-001: 전투와 이동은 반실시간. 턴제가 아니다
## - SYS-012: 칸 단위로 끊기지 않는다 — 연속 이동
## - CBT-009: 속도는 민첩·상태이상·장비 무게·[신속] 계열로 보정된다
##   PHASE 1은 기본 속도만 쓰고 보정 항은 PHASE 6에서 붙인다

## 대각선 이동이 직선보다 빨라지지 않게 정규화한다.
##
## 8방향 입력에서 (1,1)을 그대로 쓰면 길이가 √2 ≈ 1.414가 되어 대각 이동이 41% 빨라진다.
## 아날로그 입력(길이 < 1)은 세기를 보존해야 하므로 **길이가 1을 넘을 때만** 자른다.
static func normalize_direction(raw: Vector2) -> Vector2:
	if raw.length_squared() > 1.0:
		return raw.normalized()
	return raw


## 방향과 속도로 목표 속도를 만든다. 단위는 픽셀/초.
static func desired_velocity(direction: Vector2, speed: float) -> Vector2:
	return normalize_direction(direction) * speed


## delta만큼 흐른 뒤의 위치. 프레임 독립성 검증용이다.
##
## `velocity`가 픽셀/초이므로 delta를 곱한다. 프레임률이 달라도 같은 시간 동안
## 같은 거리를 이동해야 한다. (TEST_CHECKLIST 1-2)
static func step(position: Vector2, velocity: Vector2, delta: float) -> Vector2:
	return position + velocity * delta
