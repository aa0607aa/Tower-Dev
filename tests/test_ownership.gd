extends RefCounted
## `P3-T2a` — `RunState → WorldState → FloorState` 소유권 경계. (`WLD-003` `FLR-023` `FLR-024`)
##
## ## 이 파일이 존재하는 이유
## `TerrainMutationState`는 처음부터 "`WorldState` 소유"라고 주석에 적혀 있었지만
## **정작 `WorldState`가 없었다.** 주석은 강제력이 없다. 계층이 코드로 존재하고
## 위반이 테스트로 잡혀야 canon이 지켜진다.


func run(t: TestCase) -> void:
	_test_layers_exist(t)
	_test_inventory_belongs_to_run(t)
	_test_terrain_belongs_to_world(t)
	_test_ground_items_are_shared(t)
	_test_dropped_item_keeps_actual_position(t)
	_test_save_is_deterministic(t)
	_test_source_guards(t)


func _test_layers_exist(t: TestCase) -> void:
	var run := RunState.new(123)
	var world := run.ensure_world(&"world_tutorial")
	t.assert_true(world != null, "RunState가 WorldState를 소유해야 한다")
	t.assert_eq(world.world_id, &"world_tutorial", "월드 id가 보존돼야 한다")
	t.assert_true(run.ensure_world(&"world_tutorial") == world,
		"같은 월드를 두 번 요청하면 같은 객체여야 한다 — 복제되면 공유가 깨진다")

	var def := FloorDefinitionLoader.load_from_file()
	var fs := FloorPopulator.populate(def, 5)
	world.put_floor(fs)
	t.assert_true(world.floor_state(def.floor_id) == fs,
		"WorldState가 FloorState를 소유해야 한다 (FLR-023 — 층은 월드의 일부)")


## ★ 인벤토리는 **회차**에 붙는다. 층에 두면 계단을 오를 때 사라진다.
func _test_inventory_belongs_to_run(t: TestCase) -> void:
	var run := RunState.new(1)
	var item := ItemInstance.new(&"i1", &"rusty_dagger", &"weapon", 10, &"lp_a")
	run.add_to_inventory(&"player", item)

	t.assert_true(run.has_item(&"player", &"i1"), "유배자가 물건을 들고 있어야 한다")

	# 층이 바뀌어도 인벤토리는 그대로여야 한다
	var w := run.ensure_world(&"w")
	var def := FloorDefinitionLoader.load_from_file()
	w.put_floor(FloorPopulator.populate(def, 1))
	t.assert_true(run.has_item(&"player", &"i1"),
		"층 상태가 생겨도 인벤토리는 유지돼야 한다 (층에 붙어 있으면 안 된다)")

	# 다른 유배자의 가방과 섞이면 안 된다
	t.assert_true(not run.has_item(&"other", &"i1"),
		"다른 유배자의 인벤토리와 섞이면 안 된다")

	var taken := run.remove_from_inventory(&"player", &"i1")
	t.assert_true(taken != null and taken.instance_id == &"i1", "내려놓으면 그 개체가 나와야 한다")
	t.assert_true(not run.has_item(&"player", &"i1"), "내려놓은 뒤에는 없어야 한다")
	t.assert_true(run.remove_from_inventory(&"player", &"i1") == null,
		"없는 물건을 빼면 null이어야 한다 — 복제 금지")


## ★ 지형 변경은 월드 공유다 (`FLR-024`). 유배자별 복제본이 생기면 안 된다.
func _test_terrain_belongs_to_world(t: TestCase) -> void:
	var run := RunState.new(1)
	var w := run.ensure_world(&"w")
	t.assert_true(w.terrain != null, "WorldState가 TerrainMutationState를 소유해야 한다")

	var anchor := WorldAnchor.new(&"w", &"r", Vector2i(3, 3), 0)
	w.terrain.record(anchor, TerrainMutationState.Change.EXCAVATED,
		CausalSource.new(&"player", CausalSource.Kind.BODY), 10)

	# 같은 월드를 보는 두 경로가 같은 지형을 봐야 한다
	var same := run.ensure_world(&"w")
	t.assert_true(same.terrain.has_mutation(anchor),
		"같은 월드를 보면 같은 지형 변경을 봐야 한다 (FLR-024 공유)")

	var other := run.ensure_world(&"other_world")
	t.assert_true(not other.terrain.has_mutation(anchor),
		"다른 월드는 영향을 받지 않아야 한다")


## 바닥 물건은 월드 공유다 — 누가 버렸든 그 자리에 실제로 있다.
func _test_ground_items_are_shared(t: TestCase) -> void:
	var w := WorldState.new(&"w")
	var item := ItemInstance.new(&"i9", &"stone", &"misc", 0, &"")
	var at := WorldAnchor.new(&"w", &"r", Vector2i(7, 8), 0)
	w.put_ground_item(item, at)

	t.assert_eq(w.ground_items_at(Vector2i(7, 8)).size(), 1, "그 칸에 물건이 있어야 한다")
	t.assert_eq(w.ground_items_at(Vector2i(0, 0)).size(), 0, "다른 칸에는 없어야 한다")

	var got := w.take_ground_item(&"i9")
	t.assert_true(got != null and got.instance_id == &"i9", "집어 들면 그 개체가 나와야 한다")
	t.assert_eq(w.ground_items_at(Vector2i(7, 8)).size(), 0, "집어 든 뒤에는 바닥에 없어야 한다")
	t.assert_true(w.take_ground_item(&"i9") == null, "두 번 집으면 null — 복제 금지")

	# 같은 칸에 여러 개면 순서가 결정적이어야 한다 (SYS-003)
	w.put_ground_item(ItemInstance.new(&"zzz", &"a", &"misc", 0, &""), at)
	w.put_ground_item(ItemInstance.new(&"aaa", &"b", &"misc", 0, &""), at)
	var ids := w.ground_items_at(Vector2i(7, 8))
	t.assert_eq(ids[0], &"aaa", "같은 칸의 물건 순서가 결정적이어야 한다")


## ★ 버린 물건은 **실제 버린 자리**에 있어야 한다. 원래 파밍 지점으로 돌아가면 안 된다.
func _test_dropped_item_keeps_actual_position(t: TestCase) -> void:
	var w := WorldState.new(&"w")
	var item := ItemInstance.new(&"i2", &"dagger", &"weapon", 5, &"lp_origin")
	var dropped_at := WorldAnchor.new(&"w", &"r", Vector2i(50, 60), 0)
	w.put_ground_item(item, dropped_at)

	var a := w.ground_item_anchor(&"i2")
	t.assert_eq(a.cell, Vector2i(50, 60), "버린 위치가 그대로 유지돼야 한다")
	t.assert_eq(item.origin_point_id, &"lp_origin",
		"출처는 사실이므로 버려도 바뀌지 않는다 — 다만 위치가 아니다")


func _test_save_is_deterministic(t: TestCase) -> void:
	var run := RunState.new(42)
	var w := run.ensure_world(&"w")
	w.put_ground_item(ItemInstance.new(&"zz", &"a", &"misc", 0, &""),
		WorldAnchor.new(&"w", &"r", Vector2i(1, 1), 0))
	w.put_ground_item(ItemInstance.new(&"aa", &"b", &"misc", 0, &""),
		WorldAnchor.new(&"w", &"r", Vector2i(2, 2), 0))
	run.add_to_inventory(&"player", ItemInstance.new(&"i1", &"c", &"misc", 0, &""))

	var a := JSON.stringify(run.to_save_dict())
	var b := JSON.stringify(run.to_save_dict())
	t.assert_eq(a, b, "같은 상태는 항상 같은 저장 형식이어야 한다 (SYS-003)")

	var items: Array = run.to_save_dict()["worlds"]["w"]["ground_items"]
	t.assert_eq(items[0]["instance"]["instance_id"], "aa",
		"바닥 물건이 id 순으로 정렬돼 저장돼야 한다")


## ★ 소스 가드 — 소유권을 코드 위치로도 강제한다.
func _test_source_guards(t: TestCase) -> void:
	var floor_state := FileAccess.get_file_as_string("res://scripts/world/floor_state.gd")
	t.assert_true(not floor_state.contains("inventor"),
		"FloorState가 인벤토리를 가지면 안 된다 (층을 넘으면 사라진다)")
	t.assert_true(not floor_state.contains("TerrainMutationState"),
		"FloorState가 지형 변경을 소유하면 안 된다 (FLR-024)")

	var world_state := FileAccess.get_file_as_string("res://scripts/world/world_state.gd")
	t.assert_true(not world_state.contains("inventories"),
		"WorldState가 유배자 인벤토리를 소유하면 안 된다 — 남의 가방을 뒤지게 된다")
	t.assert_true(world_state.contains("TerrainMutationState"),
		"WorldState가 지형 변경을 소유해야 한다 (FLR-024)")

	t.assert_true(FileAccess.file_exists("res://scripts/world/run_state.gd"),
		"RunState가 존재해야 한다 (WLD-003 3계층)")
