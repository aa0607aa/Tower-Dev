class_name GroundItemView
extends Node2D
## 바닥에 놓인 물건의 greybox 표현. (`P3-T3`)
##
## ## `DebugOverlay`와 무엇이 다른가
## `DebugOverlay`는 **미발견 정보까지 전부** 보여주는 개발 도구라 `SYS-005`를 정면으로 어긴다.
## 이것은 반대다 — **바닥에 실제로 놓여 있어 눈에 보이는 것만** 그린다.
## 함정은 그리지 않는다. 아이템 종류도 구분하지 않는다.
##
## ## 왜 종류를 구분하지 않는가
## 색이나 모양으로 종류를 구분하면 **주워보기 전에 무엇인지 알게 된다.**
## 열매처럼 외형만으로 효과를 확정할 수 없는 물건이 있고(`ITM-002` `D-026`),
## 무기 품질도 `FLR-014`상 집어봐야 아는 영역이다. 지금은 "무언가 있다"까지만 말한다.
##
## `PHASE 8`에서 실제 도트가 들어오면 이 표현은 교체된다.

const CELL := 32
## 바닥 물건 표시 크기(px). greybox 값이며 canon 아님.
const MARK_SIZE := 10.0
## 잿빛 돌 바닥(`FLR-013`)에서 눈에 띄되 UI처럼 보이지 않는 색.
const MARK_COLOR := Color(0.86, 0.78, 0.42, 0.95)
const MARK_EDGE := Color(0.18, 0.16, 0.12, 0.9)

var world: WorldState = null
## 이 뷰가 그리는 region/layer (`P3-REV-003`).
## 비워두면 월드 전체를 그려 **다른 구역 바닥까지 보인다.**
var region_id: StringName = &""
var layer: int = 0


func _ready() -> void:
	z_index = 1


## 바닥 물건이 바뀌었을 때 호출한다. 매 프레임 다시 그리지 않는다.
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	# 지금 보고 있는 region/layer만 그린다 (`P3-REV-003`).
	# 순서는 결정적으로 유지해 디버그를 쉽게 한다.
	var ids: Array = world.ground_items_in(region_id, layer)
	for id in ids:
		var anchor: WorldAnchor = world.ground_items[id]["anchor"]
		if anchor == null:
			continue
		var center := Vector2(
			anchor.cell.x * CELL + CELL / 2.0,
			anchor.cell.y * CELL + CELL / 2.0)
		var rect := Rect2(center - Vector2(MARK_SIZE, MARK_SIZE) / 2.0,
			Vector2(MARK_SIZE, MARK_SIZE))
		draw_rect(rect, MARK_COLOR)
		draw_rect(rect, MARK_EDGE, false, 1.0)
