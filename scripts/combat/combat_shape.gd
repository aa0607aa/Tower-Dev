class_name CombatShape
extends RefCounted
## 전투 판정에 쓰는 **몸의 형태**. (`P4-REV-006` · `CBT-008`)
##
## ## 왜 필요한가
## 전에는 근접이 **대상 중심점**만 비교하고, 투사체는 **같은 32px 칸에 있는지**만 봤다.
## 실제 `CollisionShape2D`가 판정에 참여하지 않아서 두 가지가 다 일어났다:
##   - 같은 칸이면 궤적이 몸을 지나지 않아도 **맞았다**
##   - 칸 경계 반대편에서는 몸 가장자리를 통과해도 **놓쳤다**
##
## `CBT-008`은 **"무기 리치·방향·충돌 박스는 전부 실제 데이터로 존재하며 텍스트 판정이
## 아니다"** 라고 정한다. 칸 비교는 그 취지에 어긋난다.
##
## ## 물리 형태에서 가져온다 — 두 벌을 만들지 않는다
## 몸 크기를 전투용으로 따로 적으면 물리와 전투가 갈라지고, 한쪽만 고치면 조용히 어긋난다.
## 그래서 노드의 `CollisionShape2D`를 읽는다. **하나의 진실.**
##
## ## ⚠ 원으로 근사한다 — DESIGN이다
## 사각형 몸을 원으로 근사한다. `P4-REV-004`의 비canon 규칙을 따르며
## 정확한 히트박스 형태는 `PHASE 6`/`PHASE 8`에서 다시 본다.
##
## **내접원(짧은 변의 절반)** 을 쓴다. 외접원을 쓰면 모서리 바깥이 맞는 것으로 잡혀
## "스쳤는데 맞았다"가 된다. 덜 맞는 쪽이 덜 나쁘다.

## 형태를 못 찾았을 때의 반지름(px). **DESIGN.**
## 0으로 두면 점이 되어 "칸 비교"보다도 못한 판정이 된다.
const FALLBACK_RADIUS := 8.0


## 노드의 충돌 형태에서 전투용 반지름을 얻는다.
##
## `CollisionShape2D`를 자식에서 찾는다. 없으면 `FALLBACK_RADIUS`.
static func radius_of(node: Node) -> float:
	if node == null:
		return FALLBACK_RADIUS
	for child in node.get_children():
		if child is CollisionShape2D:
			var shape: Shape2D = (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				var size: Vector2 = (shape as RectangleShape2D).size
				# 내접원 — 짧은 변의 절반
				return minf(size.x, size.y) * 0.5
			if shape is CircleShape2D:
				return (shape as CircleShape2D).radius
			if shape is CapsuleShape2D:
				return (shape as CapsuleShape2D).radius
	return FALLBACK_RADIUS


## 점에서 원까지의 거리. 원 안이면 0.
static func distance_to_circle(point: Vector2, center: Vector2, radius: float) -> float:
	return maxf(0.0, point.distance_to(center) - radius)


## **선분**이 원을 지나는가. (`P4-REV-006` — 투사체)
##
## 칸 비교가 아니라 실제 궤적을 본다. 프레임률이 달라도 같은 결과가 나온다.
static func segment_hits_circle(from: Vector2, to: Vector2,
		center: Vector2, radius: float) -> bool:
	return segment_distance_to_point(from, to, center) <= radius


## 선분과 점 사이의 최단 거리.
static func segment_distance_to_point(from: Vector2, to: Vector2, point: Vector2) -> float:
	var seg := to - from
	var length_squared := seg.length_squared()
	if length_squared <= 0.0:
		return from.distance_to(point)
	# 선분 위로 사영하되 [0, 1] 밖으로 나가지 않게 자른다 — 직선이 아니라 **선분**이다.
	var t := clampf((point - from).dot(seg) / length_squared, 0.0, 1.0)
	return (from + seg * t).distance_to(point)


## **부채꼴**이 원과 겹치는가. (`P4-REV-006` — 근접)
##
## 중심점만 보면 몸이 커도 리치 끝에서 놓치고, 각도 경계에서도 몸 절반이 들어와 있는데
## 빗나간다. 대상의 반지름을 각도·거리 양쪽에 반영한다.
##
## `CBT-006`(명중률)은 TBD이므로 **굴림은 없다.** 순수한 기하 판정이다.
static func arc_hits_circle(origin: Vector2, direction: Vector2, reach: float,
		half_arc_radians: float, center: Vector2, radius: float) -> bool:
	var to_target := center - origin
	var distance := to_target.length()

	# 몸 안에 있으면 무조건 닿는다 (거리 0)
	if distance <= radius:
		return true
	# 리치 밖 — 몸 가장자리까지 재야 한다
	if distance - radius > reach:
		return false

	# 대상이 차지하는 각폭. 가까울수록 넓다.
	var angular_radius := asin(clampf(radius / distance, -1.0, 1.0))
	var offset := absf(direction.angle_to(to_target))
	return offset - angular_radius <= half_arc_radians
