class_name ItemInstance
extends RefCounted
## 실체화된 **개별 물건 하나**. (`P3-T2b` · `ITM-001` `SYS-003`)
##
## ## 왜 파밍 지점과 분리하는가
## 전에는 `FloorState.loot[point_id] = { item_id, ..., looted }` 하나로 끝냈다.
## `looted = true`가 "플레이어가 갖고 있다"를 뜻했다. 그러면 이런 것들이 표현이 안 된다:
##   - 주웠다가 **다른 곳에 버린** 물건 — 원래 지점으로 돌아가지도, 사라지지도 않아야 한다
##   - 층을 넘어 **따라오는** 물건
##   - 같은 종류 물건 여러 개를 **구별**하는 것
##
## 그래서 "이 파밍 지점에서 무엇이 나왔나"(층의 사실)와
## "이 물건이 지금 어디 있나"(월드/유배자의 사실)를 나눈다.
##
## ## `instance_id`는 안정적이어야 한다
## 저장·로드를 거쳐도 같은 물건은 같은 id다. 재생성하지 않는다 (`SYS-003`).
## 시드에서 다시 뽑는 것이 아니라 **실체화 결과를 저장**한다.
##
## ## 여기 없는 것
## 무게·장비 스탯·전투 성능은 `PHASE 6`이고 수치식은 TBD다.
## `durability`는 파밍 실체화가 이미 만들어 쓰던 값이라 옮겨만 왔다 —
## 소모 규칙(`ITM-003` 무기 수명)은 아직 구현하지 않는다.

## 이 물건 하나를 가리키는 안정적 식별자. 종류가 아니라 **개체**다.
var instance_id: StringName
## 물건의 종류. 같은 `item_id`를 가진 개체가 여럿일 수 있다.
var item_id: StringName
var kind: StringName
var durability: int = 0
## 어느 파밍 지점에서 나왔는가. 추적·디버그용이며 위치가 아니다.
## 버려진 뒤에도 이 값은 바뀌지 않는다 — "어디서 왔나"는 사실이기 때문이다.
var origin_point_id: StringName = &""


func _init(p_instance_id: StringName = &"", p_item_id: StringName = &"",
		p_kind: StringName = &"", p_durability: int = 0,
		p_origin: StringName = &"") -> void:
	instance_id = p_instance_id
	item_id = p_item_id
	kind = p_kind
	durability = p_durability
	origin_point_id = p_origin


## 파밍 지점 실체화 결과에서 개체를 만든다.
##
## `instance_id`는 층·지점에서 **결정적으로** 만든다. 난수를 쓰면 같은 세이브를
## 두 번 로드할 때 id가 달라진다 (`SYS-003`).
static func from_loot(floor_id: StringName, point_id: StringName,
		entry: Dictionary) -> ItemInstance:
	return ItemInstance.new(
		StringName("%s/%s" % [floor_id, point_id]),
		StringName(entry.get("item_id", "")),
		StringName(entry.get("kind", "")),
		int(entry.get("durability", 0)),
		point_id)


func to_save_dict() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"item_id": String(item_id),
		"kind": String(kind),
		"durability": durability,
		"origin_point_id": String(origin_point_id),
	}


static func from_save_dict(d: Dictionary) -> ItemInstance:
	return ItemInstance.new(
		StringName(d.get("instance_id", "")),
		StringName(d.get("item_id", "")),
		StringName(d.get("kind", "")),
		int(d.get("durability", 0)),
		StringName(d.get("origin_point_id", "")))
