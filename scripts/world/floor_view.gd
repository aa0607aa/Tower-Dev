extends Node2D
class_name FloorView
## `FloorDefinition`을 화면과 충돌로 만든다.
##
## ## 이것은 뷰다. 진실이 아니다 (`SYS-004`)
## 지형의 진실은 `FloorDefinition`이고 여기서 만드는 노드는 그것의 표현일 뿐이다.
## 게임 로직은 이 노드가 아니라 `FloorDefinition.is_walkable()`을 본다.
## 스프라이트가 화면에서 사라져도 데이터가 사라진 것이 아니다.
##
## ## PHASE 8까지는 회색박스다
## `FLR-013`(고대 사원풍 잿빛 돌)의 실제 도트는 PHASE 8이다. 지금은 통행/벽 구분만 된다.
##
## ## TileMapLayer를 아직 쓰지 않는 이유
## PHASE 2의 완료 조건은 지형이 **정확히 로드되고 벽을 뚫지 않는 것**이며, 타일셋 리소스를
## 만드는 것은 아트 단계(PHASE 8)의 일이다. 타일셋 없이 TileMapLayer를 두면 빈 껍데기가 된다.
## 지금은 통행 셀 밖을 벽 콜리전으로 만들고, 아트가 들어올 때 이 파일만 바꾸면 된다 —
## `FloorDefinition`은 그대로다.

const CELL := 32  # Canon.TILE_SIZE

var definition: FloorDefinition


func build(def: FloorDefinition) -> void:
	definition = def
	for child in get_children():
		child.queue_free()
	_build_floor_visual(def)
	_build_wall_collision(def)


## 통행 가능 셀을 바닥색으로 칠한다. 셀마다 노드를 만들면 8천 개가 되므로 한 번에 그린다.
func _build_floor_visual(def: FloorDefinition) -> void:
	var painter := _FloorPainter.new()
	painter.definition = def
	painter.z_index = -10
	add_child(painter)


## 통행 셀에 인접한 바깥 셀을 벽으로 세운다.
##
## 전체 bounds를 채우지 않는 이유: bounds는 8000칸 통행 셀을 감싸는 사각형이라
## 그 안 대부분이 벽이 된다. 인접 셀만 세우면 콜리전 수가 **둘레**에 비례한다.
func _build_wall_collision(def: FloorDefinition) -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)

	var wall_cells := {}
	var dirs := [
		Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	for cell in def.sorted_walkable_cells():
		for d in dirs:
			var n: Vector2i = cell + d
			if not def.is_walkable(n):
				wall_cells[n] = true

	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL, CELL)
	var keys := wall_cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for cell in keys:
		var col := CollisionShape2D.new()
		col.shape = shape  # 같은 셰이프를 공유한다 — 8천 개를 따로 만들 이유가 없다
		col.position = Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)
		body.add_child(col)

	_wall_cells = keys


var _wall_cells: Array = []


func wall_cell_count() -> int:
	return _wall_cells.size()


## 벽까지 한 번에 그리는 내부 드로어. 노드 수를 늘리지 않기 위해 `_draw()`를 쓴다.
class _FloorPainter:
	extends Node2D

	const CELL := 32
	const FLOOR_COLOR := Color(0.164706, 0.160784, 0.180392)
	const WALL_COLOR := Color(0.317647, 0.309804, 0.34902)

	var definition: FloorDefinition

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		if definition == null:
			return
		# 벽 배경을 bounds 전체에 깔고 통행 셀만 바닥색으로 덮는다.
		var b := definition.bounds
		draw_rect(Rect2(b.position.x * CELL, b.position.y * CELL,
			b.size.x * CELL, b.size.y * CELL), WALL_COLOR)
		for cell in definition.sorted_walkable_cells():
			draw_rect(Rect2(cell.x * CELL, cell.y * CELL, CELL, CELL), FLOOR_COLOR)
