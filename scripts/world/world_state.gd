class_name WorldState
extends RefCounted
## 한 **월드**의 공유 상태. (`WLD-003` · `FLR-023` `FLR-024` `FLR-027`)
##
## ## 왜 이 클래스가 생겼는가 (`P3-T2a`)
## `TerrainMutationState`는 처음부터 "`WorldState` 소유"라고 주석에 적혀 있었지만
## **정작 `WorldState`가 없었다.** 테스트에서만 생성되고 실제 게임 경로에는 소유자가 없었다.
## `RunState → WorldState → FloorState` 3계층 canon이 코드에는 `FloorState` 한 층뿐이었다.
##
## `P3-T2`에서 인벤토리를 만들려면 "`FloorState`에 두면 안 되는 것"이 살 자리가 필요하다.
## 그래서 canon이 이미 정해둔 계층을 코드로 옮긴다. **새 설정을 만드는 것이 아니다.**
##
## ## 무엇이 여기 있는가
## **여러 유배자가 공유하는 물리적 진실.** 같은 월드 좌표를 보는 사람이 둘이면
## 둘 다 같은 것을 본다 (`FLR-024`).
##   - 지형 변경 (`TerrainMutationState`)
##   - 층별 동적 상태 (`FloorState`) — 층은 월드의 일부이지 독립 포켓맵이 아니다 (`FLR-023`)
##   - 바닥에 떨어진 물건 — 누가 버렸든 그 자리에 실제로 있다
##
## ## 무엇이 여기 없는가
##   - **유배자가 들고 있는 물건** → `RunState`의 유배자 인벤토리. 층을 넘어 따라다닌다
##   - 회차 진행·선결정 데이터 → `RunState`
##
## ## 열매 효과 (`ITM-002` `WLD-008`)
## "월드별로 고정"이므로 자리는 여기가 맞다. 다만 실제 열매 시스템은 MVP 범위 밖이라
## 그릇만 두고 채우지 않는다. 빈 채로 두는 것이 임의 수치를 만드는 것보다 낫다.

var world_id: StringName

## 층별 동적 상태. `floor_id → FloorState`.
var floors: Dictionary = {}

## 지형 변경 델타. **유배자별로 복제하지 않는다** (`FLR-024`).
var terrain: TerrainMutationState = null

## 바닥에 실제로 존재하는 물건. `item_instance_id → { instance, anchor }`.
## 파밍 지점에서 주워지지 않은 것도, 유배자가 버린 것도 전부 여기 있다.
## **버린 물건이 원래 파밍 지점으로 순간이동하지 않는다** — 실제 버린 위치를 들고 있다.
var ground_items: Dictionary = {}

## 열매 효과 월드 선결정 (`ITM-002`). MVP 범위 밖 — 그릇만 둔다.
var fruit_effects: Dictionary = {}


func _init(p_world_id: StringName = &"") -> void:
	world_id = p_world_id
	terrain = TerrainMutationState.new()


func floor_state(floor_id: StringName) -> FloorState:
	return floors.get(floor_id, null)


func put_floor(state: FloorState) -> void:
	floors[state.floor_id] = state


## 물건을 이 월드의 바닥에 놓는다. **위치는 실제 놓인 곳**이다.
func put_ground_item(instance: ItemInstance, anchor: WorldAnchor) -> void:
	ground_items[instance.instance_id] = {"instance": instance, "anchor": anchor}


## 바닥에서 집어 든다. 없으면 `null`.
func take_ground_item(instance_id: StringName) -> ItemInstance:
	var e: Dictionary = ground_items.get(instance_id, {})
	if e.is_empty():
		return null
	ground_items.erase(instance_id)
	return e["instance"]


func ground_item_anchor(instance_id: StringName) -> WorldAnchor:
	var e: Dictionary = ground_items.get(instance_id, {})
	return e.get("anchor", null)


## 이 칸에 놓여 있는 물건들. id 순으로 **결정적으로** 반환한다 (`SYS-003`).
func ground_items_at(cell: Vector2i) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in ground_items:
		var a: WorldAnchor = ground_items[id]["anchor"]
		if a != null and a.cell == cell:
			out.append(id)
	out.sort_custom(func(x: StringName, y: StringName) -> bool: return String(x) < String(y))
	return out


func to_save_dict() -> Dictionary:
	var floor_ids: Array = floors.keys()
	floor_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var floor_out := {}
	for fid in floor_ids:
		floor_out[String(fid)] = (floors[fid] as FloorState).to_save_dict()

	var item_ids: Array = ground_items.keys()
	item_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	var items_out := []
	for iid in item_ids:
		var e: Dictionary = ground_items[iid]
		items_out.append({
			"instance": (e["instance"] as ItemInstance).to_save_dict(),
			"anchor": (e["anchor"] as WorldAnchor).to_save_dict(),
		})

	return {
		"world_id": String(world_id),
		"floors": floor_out,
		"terrain": terrain.to_save_dict() if terrain != null else {},
		"ground_items": items_out,
	}
