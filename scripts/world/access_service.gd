class_name AccessService
extends RefCounted
## `AccessEnvelope`를 실제 이동에 적용하는 경계 판정기. (`P2-T4`)
##
## ## 왜 별도 서비스인가
## `AccessEnvelope`는 순수 데이터이고, 픽셀↔셀 변환이나 "이 이동을 허용할까"는 게임 규칙이다.
## 봉투에 그 로직을 넣으면 데이터가 좌표계를 알게 되고, `SYS-004`(시각/데이터 분리)가 흐려진다.
##
## ## 유배자 인과만 막는다 (`FLR-024` · `D-017` 4항)
## 경계는 유배자 몸을 막는 충돌벽이 아니라 **인과 제약**이다.
## NPC·야생동물이 스스로 움직이는 것은 통과하고, 유배자가 원인인 것은 전부 막힌다 —
## 본체·소환물·투사체·던진 물체·밀쳐진 NPC까지.
##
## PHASE 2 범위: 본체 이동만 연결한다. 투사체/소환물은 그 시스템이 생길 때
## 같은 `can_effect_reach()`를 부르면 된다 — 인터페이스를 지금 열어둔다.

const CELL := 32  # Canon.TILE_SIZE


## 픽셀 좌표 → 월드 anchor.
static func anchor_at(envelope: AccessEnvelope, world_position: Vector2, layer: int = 0) -> WorldAnchor:
	return WorldAnchor.new(
		envelope.world_id, envelope.region_id,
		Vector2i(floori(world_position.x / CELL), floori(world_position.y / CELL)),
		layer)


## 유배자 본체가 이 위치로 갈 수 있는가.
static func can_body_enter(envelope: AccessEnvelope, world_position: Vector2, layer: int = 0) -> bool:
	return envelope.can_owner_enter(anchor_at(envelope, world_position, layer))


## 임의의 효과가 이 위치에 도달할 수 있는가.
##
## 투사체·소환물·던진 물체·밀쳐진 NPC가 전부 이 함수를 거쳐야 한다.
## `source`가 독립 월드 시뮬레이션이면 경계 밖이어도 통과한다.
static func can_effect_reach(envelope: AccessEnvelope, source: CausalSource,
		world_position: Vector2, layer: int = 0) -> bool:
	return envelope.can_cross(source, anchor_at(envelope, world_position, layer))


## 물리 이동 **전에** 속도를 잘라 경계 밖 motion 자체를 막는다 (`P2-REV-006`).
##
## ## 왜 `clamp_move()`만으로는 부족한가
## `clamp_move()`는 `move_and_slide()`가 **이미 물리 이동과 충돌 질의를 끝낸 뒤**
## 최종 좌표만 경계 안으로 되감는다. 좌표는 돌아오지만 그 프레임에 CharacterBody가
## 경계 밖에서 실제로 움직였고 충돌을 만들었다.
##
## PHASE 2 회색박스에는 경계 밖에 아무것도 없어 티가 안 났지만, PHASE 3에서 함정·물체·
## `Area2D`가 붙으면 **경계 밖 대상을 건드리고 나서 좌표만 되돌리는** 상태가 된다.
## `D-017`/`FLR-024`상 유배자가 원인이 된 직접 영향은 경계 밖에 닿을 수 없다.
##
## ## 축별로 자른다
## 성분을 통째로 0으로 만들면 경계를 따라 미끄러지지 못하고 벽에 붙어 멈춘다.
## 대각선이 막히면 x만/y만 남겨 보고, 둘 다 안 되면 그때 멈춘다.
##
## ## NPC·야생동물은 대상이 아니다
## `envelope`이 없는 개체는 그대로 통과한다. 경계는 **유배자에게 걸린 인과 제약**이지
## 월드의 물리 벽이 아니다 (`FLR-023`).
static func limit_motion(envelope: AccessEnvelope, from: Vector2, velocity: Vector2,
		delta: float, half_extent: Vector2 = Vector2.ZERO, layer: int = 0) -> Vector2:
	if envelope == null or velocity == Vector2.ZERO or delta <= 0.0:
		return velocity

	var target := from + velocity * delta
	if can_body_occupy(envelope, target, half_extent, layer):
		return velocity

	# 대각선이 막혔다면 한 축만 살려본다 — 경계를 따라 미끄러지는 이동은 살린다.
	if can_body_occupy(envelope, Vector2(target.x, from.y), half_extent, layer):
		return Vector2(velocity.x, 0.0)
	if can_body_occupy(envelope, Vector2(from.x, target.y), half_extent, layer):
		return Vector2(0.0, velocity.y)
	return Vector2.ZERO


## 몸체 **전체**가 경계 안에 들어가는가.
##
## `can_body_enter()`는 중심점의 셀만 본다. 몸체는 크기가 있으므로 중심이 마지막 허용 셀에
## 있어도 옆면이 경계를 넘는다. 실제로 `P2-REV-006` E2E에서 경계 밖 `Area2D`에 몸이 닿았다 —
## 중심은 안에 있었는데도. 물리적 접촉을 막는 것이 목적이므로 **AABB가 덮는 모든 셀**을 본다.
##
## `half_extent`가 0이면 중심점 판정과 같다.
static func can_body_occupy(envelope: AccessEnvelope, center: Vector2,
		half_extent: Vector2 = Vector2.ZERO, layer: int = 0) -> bool:
	if half_extent == Vector2.ZERO:
		return can_body_enter(envelope, center, layer)

	# 경계면에 정확히 맞닿는 경우를 밖으로 세지 않도록 아주 살짝 안쪽을 본다.
	var eps := 0.001
	var min_c := Vector2i(
		floori((center.x - half_extent.x + eps) / CELL),
		floori((center.y - half_extent.y + eps) / CELL))
	var max_c := Vector2i(
		floori((center.x + half_extent.x - eps) / CELL),
		floori((center.y + half_extent.y - eps) / CELL))
	for cy in range(min_c.y, max_c.y + 1):
		for cx in range(min_c.x, max_c.x + 1):
			if not envelope.can_owner_enter(
					WorldAnchor.new(envelope.world_id, envelope.region_id, Vector2i(cx, cy), layer)):
				return false
	return true


## 이동을 경계 안으로 자른다.
##
## 막힌 축만 되돌린다 — 벡터 전체를 버리면 경계를 따라 미끄러지지 못해
## 벽에 붙었을 때 이동이 통째로 멈춘 것처럼 느껴진다.
## (`move_and_slide()`가 벽에서 미끄러지는 것과 같은 감각을 유지한다.)
static func clamp_move(envelope: AccessEnvelope, from: Vector2, to: Vector2, layer: int = 0) -> Vector2:
	if can_body_enter(envelope, to, layer):
		return to

	var slide_x := Vector2(to.x, from.y)
	if can_body_enter(envelope, slide_x, layer):
		return slide_x

	var slide_y := Vector2(from.x, to.y)
	if can_body_enter(envelope, slide_y, layer):
		return slide_y

	return from


## 층 정의의 통행 셀 전체를 허용 영역으로 만든다.
##
## PHASE 2의 1층은 "허용 영역 = 걸을 수 있는 곳 전부"다. 2층 이후에는 실제 월드가
## 더 넓고 그중 일부만 허용되므로(`FLR-023`) 이 함수가 아니라 층 설계가 봉투를 정한다.
## **행동 반경과 지형을 같은 것으로 굳히지 않기 위해** 이 함수는 여기 있고 로더에 없다.
static func envelope_from_floor(owner_id: StringName, def: FloorDefinition) -> AccessEnvelope:
	var env := AccessEnvelope.new(owner_id, def.world_id, def.world_region_ref)
	for space in def.spaces:
		env.allow_rect(space["rect"])
	# 방/포켓 사각형에 없는 통로 셀은 개별 허용으로 채운다.
	for cell in def.sorted_walkable_cells():
		if not env.contains(WorldAnchor.new(def.world_id, def.world_region_ref, cell, 0)):
			env.allow_cell(cell)

	# ## 사각형 안의 **구조물 칸을 도로 뺀다** (2026-08-21)
	# `allow_rect()`는 방 사각형을 통째로 허용하는데, `blocks`로 파낸 기둥·칸막이가
	# 그 안에 있다. 그대로 두면 **허용 영역이 통행 가능 칸보다 커진다.**
	#
	# 오너가 플레이에서 발견했다 — "투사체가 벽을 뚫어".
	# 투사체가 경계만 보고 날다가 기둥을 통과했다.
	#
	# 이 함수의 계약은 문서 그대로 "1층은 **걸을 수 있는 곳 전부**가 허용 영역"이다.
	# 사각형보다 크면 계약을 어기는 것이다.
	for space in def.spaces:
		var rect: Rect2i = space["rect"]
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				var c := Vector2i(x, y)
				if not def.is_walkable(c):
					env.deny_cell(c)
	return env
