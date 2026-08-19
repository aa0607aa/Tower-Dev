extends RefCounted
## P2-T2 — 1층 고정 정의 로더. `TEST_CHECKLIST` 2-1, 2-5.
##
## 2-2(시드 100~1000개 경로 보장)는 계단이 생긴 뒤(`P2-T5`)에야 완전히 검증할 수 있다.
## 여기서는 그 전제인 **지형 자체의 연결성**을 본다 — 지형이 끊겨 있으면 계단을 어디에 두든 실패한다.


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return

	_test_identity(t, def)
	_test_scale_matches_d019(t, def)
	_test_seed_independence(t, def)
	_test_hash_ignores_formatting(t)
	_test_connectivity(t, def)
	_test_start_point_is_walkable(t, def)
	_test_blocks_are_carved(t, def)


func _test_identity(t: TestCase, def: FloorDefinition) -> void:
	t.assert_eq(def.floor_id, &"floor1", "floor_id")
	t.assert_eq(def.theme_id, &"ancient_temple", "테마는 고대 사원풍 (FLR-013)")
	# FLR-023: 층은 독립 포켓맵이 아니라 실제 월드의 일부다
	t.assert_true(def.world_region_ref != &"", "실제 월드 지역을 참조해야 한다 (FLR-023)")
	# FLR-026: 1층은 홀수층이므로 개인 목표
	t.assert_eq(def.objective_scope, FloorDefinition.ObjectiveScope.INDIVIDUAL,
		"홀수층은 개인 목표 (FLR-026)")
	# D-017 9항: 1층은 인공 구조물이라 행성 지질을 억지로 붙이지 않는다
	t.assert_eq(def.geology_region_ref, &"", "1층(인공 구조물)에 지질 참조를 강제하지 않는다")


## D-019 승인 범위 안인가. **Canon 숫자가 아니라 PLAYTEST 기준선**이므로
## 벗어났다고 canon 위반은 아니지만, 벗어나면 의도한 것인지 확인해야 한다.
func _test_scale_matches_d019(t: TestCase, def: FloorDefinition) -> void:
	var axis := def.long_axis()
	t.assert_true(axis >= 160 and axis <= 220,
		"긴 축이 D-019 범위(160~220) 안이어야 한다 — 실제 %d" % axis)

	var rooms := def.space_count("room")
	t.assert_true(rooms >= 14 and rooms <= 20,
		"주요 공간이 D-019 범위(14~20) 안 — 실제 %d" % rooms)

	var pockets := def.space_count("pocket")
	t.assert_true(pockets >= 6 and pockets <= 10,
		"소형 포켓이 D-019 범위(6~10) 안 — 실제 %d" % pockets)


## ★ 2-1 — 시드를 바꿔도 지형이 동일하다.
##
## 로더가 시드를 **받지 않는 것**이 구조적 보장이지만, 그것만으로는 나중에 누가
## 전역 RNG를 몰래 쓰는 것을 막지 못한다. 여러 번 로드해 결과가 같은지 직접 본다.
func _test_seed_independence(t: TestCase, def: FloorDefinition) -> void:
	for i in 3:
		# 전역 RNG를 흔들어도 지형이 달라지면 안 된다
		seed(i * 7919)
		var other := FloorDefinitionLoader.load_from_file()
		t.assert_eq(other.definition_hash, def.definition_hash,
			"시드 %d 에서도 지형 해시가 같아야 한다 (2-1)" % i)
		t.assert_eq(other.walkable_count(), def.walkable_count(),
			"시드 %d 에서도 통행 셀 수가 같아야 한다" % i)


## 해시는 기하만 반영해야 한다.
## 포맷 정리·주석 추가만으로 해시가 바뀌면 옛 세이브가 "정의 변경"으로 거부당한다 (P2-T6).
func _test_hash_ignores_formatting(t: TestCase) -> void:
	var base := {
		"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
		"rooms": [{"id": "a", "rect": [0, 0, 4, 4], "tags": []}],
		"corridors": [{"id": "c", "width": 3, "segments": [[4, 2, 8, 2]]}],
		"start_points": [[1, 1]],
	}
	# 같은 기하, 다른 서술 순서 + 주석 추가
	var reordered := {
		"_comment": ["주석은 해시에 영향을 주면 안 된다"],
		"corridors": [{"id": "c", "width": 3, "segments": [[4, 2, 8, 2]]}],
		"world_region_ref": "r", "world_id": "w",
		"rooms": [{"id": "a", "rect": [0, 0, 4, 4], "tags": []}],
		"theme_id": "t", "floor_id": "t",
		"start_points": [[1, 1]],
	}
	t.assert_eq(FloorDefinitionLoader.build(reordered).definition_hash,
		FloorDefinitionLoader.build(base).definition_hash,
		"주석·키 순서가 달라도 기하가 같으면 해시가 같아야 한다")

	# 기하가 실제로 바뀌면 해시도 바뀌어야 한다 — 아니면 정의 변경을 못 잡는다
	var moved := base.duplicate(true)
	moved["rooms"][0]["rect"] = [0, 0, 5, 4]
	t.assert_true(FloorDefinitionLoader.build(moved).definition_hash
			!= FloorDefinitionLoader.build(base).definition_hash,
		"기하가 바뀌면 해시가 달라져야 한다")


## 지형이 하나로 이어져 있는가.
##
## 2-2("시작점→계단 접근 불가 0건")의 전제다. 지형이 끊겨 있으면 계단을 어디에 두든 실패하고,
## 그때 원인이 계단 배치인지 지형인지 가려내기 어렵다. 여기서 먼저 잘라둔다.
func _test_connectivity(t: TestCase, def: FloorDefinition) -> void:
	t.assert_true(def.start_points.size() >= 2,
		"시작점 후보가 여러 개여야 한다 (D-022 — 회차마다 달라진다)")
	var start: Vector2i = def.start_points[0]

	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for d in dirs:
			var nxt: Vector2i = cur + d
			if reached.has(nxt) or not def.is_walkable(nxt):
				continue
			reached[nxt] = true
			queue.append(nxt)

	t.assert_eq(reached.size(), def.walkable_count(),
		"모든 통행 셀이 시작점에서 도달 가능해야 한다 (고립 %d칸)" % (def.walkable_count() - reached.size()))

	# 각 이름 있는 공간이 실제로 도달 가능한가 — 방 하나가 통째로 떠 있으면 위에서 수치로만 보인다
	for s in def.spaces:
		var rect: Rect2i = s["rect"]
		var center := rect.position + rect.size / 2
		# 중심이 아니라 **대표 칸**을 본다 — city/divisions는 중심이 구조물 안일 수 있다.
		# 공간이 도달 가능한지가 요점이지 중심이 뚫려 있는지가 아니다.
		var anchor := def.space_anchor_cell(s)
		t.assert_true(reached.has(anchor),
			"공간 `%s` 에 도달할 수 있어야 한다 (대표 칸 %v)" % [s["id"], anchor])


func _test_start_point_is_walkable(t: TestCase, def: FloorDefinition) -> void:
	for p in def.start_points:
		t.assert_true(def.is_walkable(p), "시작점 후보 %v 가 통행 가능해야 한다" % p)

	# D-022: 어느 후보에서 시작하든 맵 전체에 닿아야 한다.
	# 하나라도 고립되면 그 회차는 시작하자마자 갇힌다.
	for sp in def.start_points:
		var reached := {sp: true}
		var queue: Array[Vector2i] = [sp]
		var head := 0
		var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		while head < queue.size():
			var cur: Vector2i = queue[head]
			head += 1
			for d in dirs:
				var nxt: Vector2i = cur + d
				if reached.has(nxt) or not def.is_walkable(nxt):
					continue
				reached[nxt] = true
				queue.append(nxt)
		t.assert_eq(reached.size(), def.walkable_count(),
			"시작점 후보 %v 에서 맵 전체에 도달할 수 있어야 한다 (D-022)" % sp)


## 내부 구조물(blocks)이 실제로 파였는가. 안 파이면 "큰 방 하나"로 남는다.
func _test_blocks_are_carved(t: TestCase, def: FloorDefinition) -> void:
	# grand_hall 안에 넣은 기둥 자리가 통행 불가여야 한다
	t.assert_true(not def.is_walkable(Vector2i(82, 44)),
		"grand_hall 내부 기둥이 파여야 한다 (blocks)")
	t.assert_true(not def.is_walkable(Vector2i(98, 56)),
		"grand_hall 중앙 구조물이 파여야 한다")
	# 기둥 옆은 여전히 통행 가능해야 한다 — 방을 통째로 막으면 안 된다
	t.assert_true(def.is_walkable(Vector2i(92, 44)), "기둥 옆은 통행 가능")
