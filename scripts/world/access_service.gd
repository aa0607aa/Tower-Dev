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
	return env
