class_name RunState
extends RefCounted
## 한 **회차**의 최상위 상태. (`WLD-003` 3계층 · `P3-T2a`)
##
## `RunState → WorldState → FloorState`. canon이 정한 계층을 코드로 옮긴 것이며
## **새 설정이 아니다.** 이전에는 `FloorState`만 있었고 `WorldState` 소유라고 적힌
## `TerrainMutationState`는 소유자가 없었다.
##
## ## 무엇이 여기 있는가
##   - **유배자가 들고 있는 물건.** 층을 넘어 따라다니므로 `FloorState`에 두면 안 된다
##   - 회차 시드 — 재현·디버그용이다. **재생성용 진실이 아니다** (`SYS-003`)
##   - 회차에 속한 월드들
##
## ## 인벤토리를 유배자별로 두는 이유
## `FLR-024`상 같은 월드를 여러 유배자가 공유한다. 인벤토리를 월드에 두면 남의 가방을
## 뒤지게 된다. 반대로 층에 두면 계단을 오르는 순간 사라진다.
##
## ## 여기 없는 것
## 운반 한도·무게 공식은 `PHASE 6`/TBD다 (`ITM-001` — 힘 계열 파생 성능).
## **여기서 임의 용량 수치를 만들지 않는다.** 지금은 담을 뿐 제한하지 않는다.

var run_seed: int = 0

## `world_id → WorldState`.
var worlds: Dictionary = {}

## `exile_id → Array[ItemInstance]`. 층을 넘어 따라간다.
var inventories: Dictionary = {}


func _init(p_run_seed: int = 0) -> void:
	run_seed = p_run_seed


func world(world_id: StringName) -> WorldState:
	return worlds.get(world_id, null)


func ensure_world(world_id: StringName) -> WorldState:
	if not worlds.has(world_id):
		worlds[world_id] = WorldState.new(world_id)
	return worlds[world_id]


func inventory(exile_id: StringName) -> Array:
	if not inventories.has(exile_id):
		inventories[exile_id] = []
	return inventories[exile_id]


## 유배자가 물건을 든다. **용량 제한은 아직 없다** (`PHASE 6` TBD).
func add_to_inventory(exile_id: StringName, instance: ItemInstance) -> void:
	inventory(exile_id).append(instance)


## 유배자가 물건을 내려놓는다. 없으면 `null`.
func remove_from_inventory(exile_id: StringName, instance_id: StringName) -> ItemInstance:
	var inv: Array = inventory(exile_id)
	for i in inv.size():
		if (inv[i] as ItemInstance).instance_id == instance_id:
			var it: ItemInstance = inv[i]
			inv.remove_at(i)
			return it
	return null


func has_item(exile_id: StringName, instance_id: StringName) -> bool:
	for it in inventory(exile_id):
		if (it as ItemInstance).instance_id == instance_id:
			return true
	return false


func to_save_dict() -> Dictionary:
	var world_ids: Array = worlds.keys()
	world_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var worlds_out := {}
	for wid in world_ids:
		worlds_out[String(wid)] = (worlds[wid] as WorldState).to_save_dict()

	var exile_ids: Array = inventories.keys()
	exile_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var inv_out := {}
	for eid in exile_ids:
		var arr := []
		# 소지품 순서는 유배자가 정한 것이므로 정렬하지 않는다 — 순서 자체가 상태다.
		for it in inventories[eid]:
			arr.append((it as ItemInstance).to_save_dict())
		inv_out[String(eid)] = arr

	return {
		"run_seed": run_seed,
		"worlds": worlds_out,
		"inventories": inv_out,
	}
