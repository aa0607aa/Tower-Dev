class_name WorldAnchor
extends RefCounted
## 실제 월드 공간의 한 지점. 값 객체(불변).
##
## **왜 `Vector2i` 하나로 안 되는가** — `FAC-013`:
## 계단은 생성 후 월드 좌표에 고정되며, 그 자리의 바닥·천장·벽이 굴착·붕괴로 사라져도
## **계단의 좌표와 존재는 유지**된다. 즉 주소가 타일 데이터에 종속되면 안 된다.
## `FLR-027`(지형은 파괴 가능한 물질)과 함께 보면, 지형은 변해도 anchor는 남아야 한다.
##
## `FLR-023`: 층은 독립 포켓맵이 아니라 실제 월드의 일부다.
## 그래서 주소에 `world_id`와 `region_id`가 들어간다 — 층 번호가 아니다.
##
## 층은 `FloorDefinition.world_region_ref`로 이 공간을 참조할 뿐,
## 좌표계를 소유하지 않는다.

var world_id: StringName
var region_id: StringName
## 지역 내 셀 좌표. 타일 데이터가 아니라 공간 좌표다.
var cell: Vector2i
## 고도/깊이 밴드. 천장 위 공동, 지하 공간 등을 표현한다.
## `FAC-012`상 계단이 "정상 바닥"에만 있지 않으므로 필요하다.
var layer: int


func _init(p_world_id: StringName, p_region_id: StringName, p_cell: Vector2i, p_layer: int = 0) -> void:
	world_id = p_world_id
	region_id = p_region_id
	cell = p_cell
	layer = p_layer


## Dictionary 키로 쓰기 위한 안정 문자열.
## 결정성(`SYS-003`)상 순회 순서가 흔들리면 안 되므로 정렬 가능한 형태로 만든다.
func key() -> String:
	return "%s/%s/%d,%d@%d" % [world_id, region_id, cell.x, cell.y, layer]


func equals(other: WorldAnchor) -> bool:
	if other == null:
		return false
	return world_id == other.world_id \
		and region_id == other.region_id \
		and cell == other.cell \
		and layer == other.layer


func with_cell(new_cell: Vector2i) -> WorldAnchor:
	return WorldAnchor.new(world_id, region_id, new_cell, layer)


func _to_string() -> String:
	return "WorldAnchor(%s)" % key()
