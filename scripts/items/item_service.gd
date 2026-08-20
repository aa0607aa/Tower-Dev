class_name ItemService
extends RefCounted
## 물건의 **소유권 이동**. (`P3-T2b` `P3-T3` · `ITM-001` `SYS-003`)
##
## 바닥(월드 공유) ↔ 유배자 인벤토리(회차 귀속) 사이의 이동만 담당한다.
## 무게 제한·장비 성능은 `PHASE 6`/TBD다 — 여기서 임의 수치를 만들지 않는다.
##
## ## 불변식
## 물건은 **정확히 한 곳**에만 있다. 바닥에 있으면 인벤토리에 없고, 그 반대도 같다.
## 복제도 소실도 없어야 한다 — 실패하면 아무것도 바꾸지 않고 `false`를 돌려준다.


## 층에 진입할 때 아직 주워지지 않은 파밍 결과를 **바닥에 실체화**한다.
##
## ## 왜 멱등해야 하는가
## 로드할 때 이미 바닥에 있는 물건을 또 만들면 **물건이 복제된다.**
## `instance_id`가 `floor_id/point_id`로 결정적이므로 이미 있으면 건너뛴다 (`SYS-003`).
##
## 주운 지점(`looted`)은 다시 만들지 않는다 — 파밍 지점은 재생성되지 않는다.
static func materialize_floor_loot(world: WorldState, def: FloorDefinition,
		state: FloorState) -> int:
	var made := 0
	for point in def.loot_points:
		var point_id: StringName = point["id"]
		if state.is_looted(point_id):
			continue
		var entry: Dictionary = state.loot.get(point_id, {})
		if entry.is_empty():
			continue
		var instance := ItemInstance.from_loot(def.floor_id, point_id, entry)
		if world.ground_items.has(instance.instance_id):
			continue  # 이미 바닥에 있다 — 로드 직후 등
		world.put_ground_item(instance,
			WorldAnchor.new(def.world_id, def.world_region_ref, point["cell"], 0))
		made += 1
	return made


## 바닥 → 인벤토리.
##
## 파밍 지점에서 나온 물건이면 그 지점을 `looted`로 표시한다. **다시 생기지 않는다.**
static func pick_up(run: RunState, world: WorldState, state: FloorState,
		exile_id: StringName, instance_id: StringName) -> bool:
	var instance := world.take_ground_item(instance_id)
	if instance == null:
		return false
	run.add_to_inventory(exile_id, instance)
	if state != null and instance.origin_point_id != &"" \
			and state.loot.has(instance.origin_point_id):
		state.take_loot(instance.origin_point_id)
	return true


## 인벤토리 → 바닥.
##
## **버린 자리에 놓인다.** 원래 파밍 지점으로 돌아가지 않는다.
## 행동 반경 밖에는 놓을 수 없다 — 유배자가 원인인 직접 영향은 경계를 넘지 못한다
## (`D-017` 4항 · `FLR-024`).
static func drop(run: RunState, world: WorldState, exile_id: StringName,
		instance_id: StringName, at: WorldAnchor,
		envelope: AccessEnvelope = null) -> bool:
	if at == null:
		return false
	if envelope != null and not envelope.contains(at):
		return false
	var instance := run.remove_from_inventory(exile_id, instance_id)
	if instance == null:
		return false
	world.put_ground_item(instance, at)
	return true
