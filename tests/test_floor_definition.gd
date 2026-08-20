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
	_test_hash_covers_immutable_definition(t)
	_test_corridor_width_is_exact(t)
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


## 해시는 **불변 정의**를 반영하고 서술 포맷은 반영하지 않아야 한다 (`P2-REV-003`).
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


## `P2-REV-003` — 저장된 회차의 **의미**를 바꾸는 고정 정의는 전부 해시에 들어가야 한다.
##
## 전에는 설명이 "기하만 반영"인데 실제로는 함정 위치·종류까지 넣으면서
## `lethal`·`one_shot`·`clues`는 빠뜨렸다. 치명 여부나 단서가 바뀌면
## **같은 세이브가 다른 게임이 된다** — 호환 판정이 그걸 놓치면 안 된다.
func _test_hash_covers_immutable_definition(t: TestCase) -> void:
	var base := {
		"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
		"layout_version": 1, "objective_scope": "INDIVIDUAL",
		"rooms": [{"id": "a", "rect": [0, 0, 6, 6], "tags": ["landmark"]}],
		"start_points": [[1, 1]],
		"traps": [{"id": "tr", "cell": [2, 2], "type": "pitfall",
			"lethal": true, "one_shot": false, "clues": ["갈라진 바닥"]}],
		"loot_points": [{"id": "lp", "cell": [3, 3]}],
		"spawn_points": [{"id": "sp", "cell": [4, 4]}],
	}
	var base_hash: String = FloorDefinitionLoader.build(base).definition_hash

	# 각각 하나씩만 바꿔서 해시가 실제로 달라지는지 본다.
	var mutations := {
		"함정 치명 여부": func(d: Dictionary) -> void: d["traps"][0]["lethal"] = false,
		"함정 일회성": func(d: Dictionary) -> void: d["traps"][0]["one_shot"] = true,
		"함정 사전 단서": func(d: Dictionary) -> void: d["traps"][0]["clues"] = ["다른 단서"],
		"함정 종류": func(d: Dictionary) -> void: d["traps"][0]["type"] = "wall_bolt",
		"시작점 후보": func(d: Dictionary) -> void: d["start_points"] = [[1, 1], [2, 1]],
		"층 정체성(floor_id)": func(d: Dictionary) -> void: d["floor_id"] = "other",
		"레이아웃 버전": func(d: Dictionary) -> void: d["layout_version"] = 2,
		"목표 범위": func(d: Dictionary) -> void: d["objective_scope"] = "SHARED",
		"파밍 지점 위치": func(d: Dictionary) -> void: d["loot_points"][0]["cell"] = [5, 3],
		# `P2-REV-007` — 좌표가 같아도 의미 태그가 바뀌면 다른 정의다.
		"공간 태그": func(d: Dictionary) -> void: d["rooms"][0]["tags"] = ["inner_complex"],
		"공간 태그 추가": func(d: Dictionary) -> void: d["rooms"][0]["tags"] = ["landmark", "open"],
	}
	for label in mutations:
		var changed: Dictionary = base.duplicate(true)
		(mutations[label] as Callable).call(changed)
		t.assert_true(FloorDefinitionLoader.build(changed).definition_hash != base_hash,
			"%s 가 바뀌면 해시가 달라져야 한다 (P2-REV-003)" % label)

	# 태그는 **서술 순서**에 흔들리면 안 된다 — 정렬해서 넣는 이유다 (`SYS-003`).
	var reordered_tags: Dictionary = base.duplicate(true)
	reordered_tags["rooms"][0]["tags"] = ["landmark"]
	var two_a: Dictionary = base.duplicate(true)
	two_a["rooms"][0]["tags"] = ["landmark", "open"]
	var two_b: Dictionary = base.duplicate(true)
	two_b["rooms"][0]["tags"] = ["open", "landmark"]
	t.assert_eq(FloorDefinitionLoader.build(two_a).definition_hash,
		FloorDefinitionLoader.build(two_b).definition_hash,
		"태그 순서만 다르면 해시가 같아야 한다 (P2-REV-007)")

	# 같은 정의를 다시 만들면 같아야 한다 — 위 비교가 우연이 아님을 보인다.
	t.assert_eq(FloorDefinitionLoader.build(base.duplicate(true)).definition_hash, base_hash,
		"같은 정의는 항상 같은 해시여야 한다")


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


## `P2-REV-004` — 통로 폭이 저작 값과 **정확히** 같아야 한다.
##
## `half = width / 2` + `-half..half`는 GDScript 정수 나눗셈 때문에 짝수 폭에서 한 칸이
## 더 생겼다. `width = 2`가 실제로는 3칸이었다. 저작 데이터가 폭 1·2·3·5를 구분해
## 쓰고 있었으므로 **저작한 지형과 실제 통행 지형이 달랐다.**
func _test_corridor_width_is_exact(t: TestCase) -> void:
	for width in [1, 2, 3, 5]:
		# 가로 통로 — 세로 방향 두께를 센다
		var h := FloorDefinitionLoader.build({
			"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
			"corridors": [{"id": "c", "width": width, "segments": [[10, 20, 14, 20]]}],
			"start_points": [[10, 20]],
		})
		var h_thick := 0
		for dy in range(-6, 7):
			if h.is_walkable(Vector2i(12, 20 + dy)):
				h_thick += 1
		t.assert_eq(h_thick, width,
			"가로 통로 폭 %d 는 정확히 %d칸이어야 한다 (P2-REV-004)" % [width, width])

		# 세로 통로 — 가로 방향 두께
		var v := FloorDefinitionLoader.build({
			"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
			"corridors": [{"id": "c", "width": width, "segments": [[20, 10, 20, 14]]}],
			"start_points": [[20, 10]],
		})
		var v_thick := 0
		for dx in range(-6, 7):
			if v.is_walkable(Vector2i(20 + dx, 12)):
				v_thick += 1
		t.assert_eq(v_thick, width,
			"세로 통로 폭 %d 는 정확히 %d칸이어야 한다 (P2-REV-004)" % [width, width])

		# 홀수는 중심선 대칭, 짝수는 음수 쪽으로 한 칸 치우친다 — 규칙을 고정해둔다.
		t.assert_true(h.is_walkable(Vector2i(12, 20)),
			"폭 %d 통로는 중심선을 반드시 포함해야 한다" % width)
		if width % 2 == 0:
			t.assert_true(h.is_walkable(Vector2i(12, 20 - width / 2)),
				"짝수 폭 %d 는 음수 쪽으로 치우쳐야 한다" % width)
			t.assert_true(not h.is_walkable(Vector2i(12, 20 + width / 2)),
				"짝수 폭 %d 가 양수 쪽으로 넘치면 안 된다" % width)

