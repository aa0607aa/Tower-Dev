class_name FloorDefinitionLoader
extends RefCounted
## 저작 기하 → `FloorDefinition` 전개기.
##
## ## 이것은 생성기가 아니다 (`FLR-003`)
## **시드를 받지 않고 랜덤을 쓰지 않는다.** 저작 파일의 방/통로 사각형을 셀로 펼칠 뿐이며,
## 같은 파일이면 항상 같은 결과가 나온다. `.tscn`의 사각형이 콜리전 셰이프로 펼쳐지는 것과 같다.
##
## 금지되는 것은 **1층 지형을 만들어내는 것**이고, 저작된 기하를 읽는 것은 로더의 일이다.
##
## ## 왜 셀 그리드를 저작하지 않았나
## 긴 축 160~220(`D-019`)이면 셀 그리드는 2만 자가 넘어 사람이 리뷰할 수 없다.
## 방/통로 기하는 **30줄 남짓**이라 diff에서 "어느 방이 어떻게 바뀌었는지"가 보인다.
## 나중에 오너가 Godot 에디터로 그리는 경로를 붙여도 **같은 `FloorDefinition`을 내면** 된다 —
## 게임 로직은 저작 포맷을 모른다.

const DEFAULT_PATH := "res://data/floors/floor1_fixed/floor1_layout.json"


static func load_from_file(path: String = DEFAULT_PATH) -> FloorDefinition:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("층 정의를 열 수 없다: %s" % path)
		return null
	var text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("층 정의 JSON 파싱 실패: %s" % path)
		return null

	return build(parsed as Dictionary)


static func build(src: Dictionary) -> FloorDefinition:
	var def := FloorDefinition.new()
	def.floor_id = StringName(src.get("floor_id", ""))
	def.theme_id = StringName(src.get("theme_id", ""))
	def.world_id = StringName(src.get("world_id", ""))
	def.world_region_ref = StringName(src.get("world_region_ref", ""))
	var geo: Variant = src.get("geology_region_ref", null)
	def.geology_region_ref = StringName(geo) if geo != null else &""
	def.layout_version = int(src.get("layout_version", 0))

	var scope := String(src.get("objective_scope", "INDIVIDUAL"))
	def.objective_scope = FloorDefinition.ObjectiveScope.SHARED if scope == "SHARED" \
		else FloorDefinition.ObjectiveScope.INDIVIDUAL

	# 해시는 **기하만** 반영한다. 주석·들여쓰기·키 순서가 바뀌어도 지형이 같으면 같은 해시여야
	# 한다 — 그러지 않으면 포맷 정리만 해도 옛 세이브가 "정의가 바뀌었다"고 거부당한다.
	var hash_parts: Array[String] = []

	for kind in ["rooms", "pockets"]:
		for entry in src.get(kind, []):
			var rect := _to_rect(entry["rect"])
			var id := StringName(entry.get("id", ""))
			var tags: Array = entry.get("tags", [])
			def.spaces.append({"id": id, "rect": rect, "tags": tags, "kind": kind.trim_suffix("s")})
			_fill_rect(def, rect)
			hash_parts.append("%s|%s|%d,%d,%d,%d" % [kind, id, rect.position.x, rect.position.y, rect.size.x, rect.size.y])

	for corridor in src.get("corridors", []):
		var width := int(corridor.get("width", 3))
		var cid := StringName(corridor.get("id", ""))
		for seg in corridor.get("segments", []):
			var a := Vector2i(int(seg[0]), int(seg[1]))
			var b := Vector2i(int(seg[2]), int(seg[3]))
			_fill_segment(def, a, b, width)
			hash_parts.append("corridor|%s|%d,%d,%d,%d,%d" % [cid, a.x, a.y, b.x, b.y, width])

	for p in src.get("start_points", []):
		def.start_points.append(Vector2i(int(p[0]), int(p[1])))

	# 함정 — 위치·종류·구조·단서 전부 고정. 상태(armed/fired)는 FloorState 소관이다.
	for tr in src.get("traps", []):
		var cell := Vector2i(int(tr["cell"][0]), int(tr["cell"][1]))
		var clues: Array[String] = []
		for c in tr.get("clues", []):
			clues.append(String(c))
		def.traps.append({
			"id": StringName(tr["id"]),
			"cell": cell,
			"type": StringName(tr["type"]),
			"lethal": bool(tr.get("lethal", false)),
			"one_shot": bool(tr.get("one_shot", false)),
			"clues": clues,
		})
		hash_parts.append("trap|%s|%d,%d|%s" % [tr["id"], cell.x, cell.y, tr["type"]])

	for lp in src.get("loot_points", []):
		var lc := Vector2i(int(lp["cell"][0]), int(lp["cell"][1]))
		def.loot_points.append({"id": StringName(lp["id"]), "cell": lc})
		hash_parts.append("loot|%s|%d,%d" % [lp["id"], lc.x, lc.y])

	for sp in src.get("spawn_points", []):
		var sc := Vector2i(int(sp["cell"][0]), int(sp["cell"][1]))
		def.spawn_points.append({"id": StringName(sp["id"]), "cell": sc})
		hash_parts.append("spawn|%s|%d,%d" % [sp["id"], sc.x, sc.y])

	# 순서에 의존하지 않는 해시 (SYS-003)
	hash_parts.sort()
	def._finalize(_compute_bounds(def), (" ".join(hash_parts)).sha256_text())
	return def


static func _to_rect(arr: Array) -> Rect2i:
	return Rect2i(int(arr[0]), int(arr[1]), int(arr[2]), int(arr[3]))


static func _fill_rect(def: FloorDefinition, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			def._add_walkable(Vector2i(x, y))


## 축 정렬 통로. 대각선 통로는 지금 필요 없고, 허용하면 저작 실수가 조용히 통과한다.
static func _fill_segment(def: FloorDefinition, a: Vector2i, b: Vector2i, width: int) -> void:
	if a.x != b.x and a.y != b.y:
		push_error("통로는 축 정렬이어야 한다: %v → %v" % [a, b])
		return
	var half := width / 2
	if a.y == b.y:
		var x0 := mini(a.x, b.x)
		var x1 := maxi(a.x, b.x)
		for x in range(x0, x1 + 1):
			for dy in range(-half, half + 1):
				def._add_walkable(Vector2i(x, a.y + dy))
	else:
		var y0 := mini(a.y, b.y)
		var y1 := maxi(a.y, b.y)
		for y in range(y0, y1 + 1):
			for dx in range(-half, half + 1):
				def._add_walkable(Vector2i(a.x + dx, y))


## 통행 셀을 감싸는 사각형 + 벽 두께 1.
##
## ⚠ 이것은 `AccessEnvelope`(맵의 끝)가 아니다. 지형이 그려진 범위일 뿐이며,
## 유배자의 행동 반경은 `FLR-024`상 별개다.
static func _compute_bounds(def: FloorDefinition) -> Rect2i:
	var cells := def.sorted_walkable_cells()
	if cells.is_empty():
		return Rect2i()
	var min_x := cells[0].x
	var max_x := cells[0].x
	var min_y := cells[0].y
	var max_y := cells[0].y
	for c in cells:
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
		min_y = mini(min_y, c.y)
		max_y = maxi(max_y, c.y)
	return Rect2i(min_x - 1, min_y - 1, (max_x - min_x) + 3, (max_y - min_y) + 3)
