extends RefCounted
## `P3-T2a` — `RunState → WorldState → FloorState` 소유권 경계. (`WLD-003` `FLR-023` `FLR-024`)
##
## ## 이 파일이 존재하는 이유
## `TerrainMutationState`는 처음부터 "`WorldState` 소유"라고 주석에 적혀 있었지만
## **정작 `WorldState`가 없었다.** 주석은 강제력이 없다. 계층이 코드로 존재하고
## 위반이 테스트로 잡혀야 canon이 지켜진다.


## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 그래서 남은 단언이 조용히 사라져도 러너에는 PASS로 보인다 — 실제로 겪었다.
## 하한을 못박아 두면 그런 유실이 실패로 드러난다.
## 단언을 **추가**할 때는 손댈 필요 없고, 의도적으로 **줄일** 때만 함께 낮춘다.
const MIN_ASSERTIONS := 74


func run(t: TestCase) -> void:
	_test_layers_exist(t)
	_test_inventory_belongs_to_run(t)
	_test_terrain_belongs_to_world(t)
	_test_ground_items_are_shared(t)
	_test_dropped_item_keeps_actual_position(t)
	_test_save_is_deterministic(t)
	_test_source_guards(t)
	_test_terrain_survives_save_roundtrip(t)
	_test_ground_items_are_addressed_by_anchor(t)
	_test_put_ground_item_rejects_foreign_world(t)
	_test_durability_grade_survives_roundtrip(t)
	t.done()


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
	var item := ItemInstance.new(&"i1", &"rusty_dagger", &"weapon", &"poor", &"lp_a")
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
	var item := ItemInstance.new(&"i9", &"stone", &"misc", &"", &"")
	var at := WorldAnchor.new(&"w", &"r", Vector2i(7, 8), 0)
	w.put_ground_item(item, at)

	t.assert_eq(w.ground_items_here(at).size(), 1, "그 주소에 물건이 있어야 한다")
	t.assert_eq(w.ground_items_here(WorldAnchor.new(&"w", &"r", Vector2i(0, 0), 0)).size(), 0,
		"다른 칸에는 없어야 한다")

	var got := w.take_ground_item(&"i9")
	t.assert_true(got != null and got.instance_id == &"i9", "집어 들면 그 개체가 나와야 한다")
	t.assert_eq(w.ground_items_here(at).size(), 0, "집어 든 뒤에는 바닥에 없어야 한다")
	t.assert_true(w.take_ground_item(&"i9") == null, "두 번 집으면 null — 복제 금지")

	# 같은 칸에 여러 개면 순서가 결정적이어야 한다 (SYS-003)
	w.put_ground_item(ItemInstance.new(&"zzz", &"a", &"misc", &"", &""), at)
	w.put_ground_item(ItemInstance.new(&"aaa", &"b", &"misc", &"", &""), at)
	var ids := w.ground_items_here(at)
	t.assert_eq(ids[0], &"aaa", "같은 칸의 물건 순서가 결정적이어야 한다")


## ★ 버린 물건은 **실제 버린 자리**에 있어야 한다. 원래 파밍 지점으로 돌아가면 안 된다.
func _test_dropped_item_keeps_actual_position(t: TestCase) -> void:
	var w := WorldState.new(&"w")
	var item := ItemInstance.new(&"i2", &"dagger", &"weapon", &"fair", &"lp_origin")
	var dropped_at := WorldAnchor.new(&"w", &"r", Vector2i(50, 60), 0)
	w.put_ground_item(item, dropped_at)

	var a := w.ground_item_anchor(&"i2")
	t.assert_eq(a.cell, Vector2i(50, 60), "버린 위치가 그대로 유지돼야 한다")
	t.assert_eq(item.origin_point_id, &"lp_origin",
		"출처는 사실이므로 버려도 바뀌지 않는다 — 다만 위치가 아니다")


func _test_save_is_deterministic(t: TestCase) -> void:
	var run := RunState.new(42)
	var w := run.ensure_world(&"w")
	w.put_ground_item(ItemInstance.new(&"zz", &"a", &"misc", &"", &""),
		WorldAnchor.new(&"w", &"r", Vector2i(1, 1), 0))
	w.put_ground_item(ItemInstance.new(&"aa", &"b", &"misc", &"", &""),
		WorldAnchor.new(&"w", &"r", Vector2i(2, 2), 0))
	run.add_to_inventory(&"player", ItemInstance.new(&"i1", &"c", &"misc", &"", &""))

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


## ★ `P3-REV-002` — 지형 변경이 저장/복원을 통과해야 한다.
##
## `WorldState.to_save_dict()`는 terrain을 저장했지만 `RunSave.from_text()`에
## **복원 코드가 아예 없었다.** 게다가 mutation record가 `WorldAnchor`·`CausalSource`
## **객체**를 그대로 들고 있어 `JSON.stringify()`를 지나면 사라졌다.
## 파괴한 벽이 로드하면 되살아나는 상태였다 (`FLR-027`).
func _test_terrain_survives_save_roundtrip(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	var defs := {def.floor_id: def}

	var run := RunState.new(777)
	var world := run.ensure_world(def.world_id)
	var anchor := WorldAnchor.new(def.world_id, def.world_region_ref, Vector2i(12, 34), 0)
	var cause := CausalSource.new(&"player", CausalSource.Kind.BODY)
	world.terrain.record(anchor, TerrainMutationState.Change.BREACHED, cause, 4242)

	# JSON을 실제로 통과시킨다 — 객체가 남아 있으면 여기서 깨진다.
	var text := RunSave.to_text(run)
	t.assert_true(not text.contains("Object("),
		"세이브에 엔진 객체가 직렬화되면 안 된다 (JSON-native여야 한다)")

	var r := RunSave.from_text(text, defs)
	var loaded: RunState = r["run"]
	t.assert_true(loaded != null, "로드가 되어야 한다")
	if loaded == null:
		return
	var w2 := loaded.world(def.world_id)
	t.assert_eq(w2.terrain.mutation_count(), 1, "지형 변경이 복원돼야 한다")
	t.assert_true(w2.terrain.has_mutation(anchor), "같은 앵커로 찾을 수 있어야 한다")

	var m := w2.terrain.get_mutation(anchor)
	t.assert_eq(int(m["change"]), int(TerrainMutationState.Change.BREACHED), "변경 종류 보존")
	t.assert_eq(int(m["at_tick"]), 4242, "발생 시각 보존")
	var restored_cause: CausalSource = m["caused_by"]
	t.assert_eq(restored_cause.exile_owner_id, &"player", "원인 유배자 보존")
	t.assert_eq(int(restored_cause.kind), int(CausalSource.Kind.BODY), "원인 종류 보존")
	var restored_anchor: WorldAnchor = m["anchor"]
	t.assert_true(restored_anchor.equals(anchor), "앵커 전체(world/region/cell/layer)가 보존돼야 한다")


## ★ `P3-REV-003` — 바닥 물건 주소는 `cell`이 아니라 `WorldAnchor` 전체다.
##
## 같은 월드의 **다른 region/layer에 같은 좌표**가 존재할 수 있다 (`FLR-023`).
## `cell`만 보면 옆 구역 바닥의 물건이 손에 잡힌다.
func _test_ground_items_are_addressed_by_anchor(t: TestCase) -> void:
	var w := WorldState.new(&"w")
	var here := WorldAnchor.new(&"w", &"region_a", Vector2i(5, 5), 0)
	var other_region := WorldAnchor.new(&"w", &"region_b", Vector2i(5, 5), 0)
	var other_layer := WorldAnchor.new(&"w", &"region_a", Vector2i(5, 5), 1)

	w.put_ground_item(ItemInstance.new(&"here", &"a", &"misc", &"", &""), here)
	w.put_ground_item(ItemInstance.new(&"other_region", &"b", &"misc", &"", &""), other_region)
	w.put_ground_item(ItemInstance.new(&"other_layer", &"c", &"misc", &"", &""), other_layer)

	var found := w.ground_items_here(here)
	t.assert_eq(found.size(), 1,
		"같은 좌표라도 region/layer가 다르면 잡히면 안 된다 (잡힌 수 %d)" % found.size())
	t.assert_eq(found[0], &"here", "현재 주소의 물건만 나와야 한다")

	# region/layer 단위 조회도 구분돼야 한다 — 표현 계층이 쓴다
	t.assert_eq(w.ground_items_in(&"region_a", 0).size(), 1, "region_a/layer0에 하나")
	t.assert_eq(w.ground_items_in(&"region_b", 0).size(), 1, "region_b/layer0에 하나")
	t.assert_eq(w.ground_items_in(&"region_a", 1).size(), 1, "region_a/layer1에 하나")

	# 상호작용도 현재 region 것만 잡아야 한다
	var def := FloorDefinitionLoader.build({
		"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "region_a",
		"rooms": [{"id": "r", "rect": [0, 0, 10, 10], "tags": []}],
		"start_points": [[1, 1]],
	})
	var env := AccessService.envelope_from_floor(&"player", def)
	var cands := InteractionService.candidates(def, w, env, Vector2i(5, 5))
	for c in cands:
		t.assert_true(c["id"] == &"here",
			"다른 region/layer 물건이 상호작용 후보에 들어오면 안 된다 (%s)" % c["id"])
	t.assert_eq(cands.size(), 1, "현재 region/layer의 물건 하나만 후보여야 한다")


## 다른 월드의 앵커를 넣으면 주소가 거짓말이 된다 (`P3-REV-003`).
func _test_put_ground_item_rejects_foreign_world(t: TestCase) -> void:
	var w := WorldState.new(&"world_a")
	var foreign := WorldAnchor.new(&"world_b", &"r", Vector2i(1, 1), 0)
	t.assert_true(not w.put_ground_item(ItemInstance.new(&"x", &"a", &"misc", &"", &""), foreign),
		"다른 월드의 앵커는 거부돼야 한다")
	t.assert_eq(w.ground_items.size(), 0, "거부된 물건이 들어가면 안 된다")

	var ok := WorldAnchor.new(&"world_a", &"r", Vector2i(1, 1), 0)
	t.assert_true(w.put_ground_item(ItemInstance.new(&"y", &"a", &"misc", &"", &""), ok),
		"같은 월드의 앵커는 받아야 한다")


## ★ `P3-REV-004` — 내구 **등급**이 저장/복원을 통과해야 한다.
##
## 파밍 테이블은 `poor`/`fair` 같은 등급 문자열을 준다. 전에는 `ItemInstance.durability`가
## `int`라 `int("poor") == 0`으로 **등급이 통째로 사라졌다.**
func _test_durability_grade_survives_roundtrip(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	var defs := {def.floor_id: def}
	var run := RunState.new(31337)
	var world := run.ensure_world(def.world_id)
	var state := FloorPopulator.populate(def, 31337)
	world.put_floor(state)
	ItemService.materialize_floor_loot(world, def, state)

	# 실제 floor1 파밍 결과에 등급이 들어 있어야 한다 (테스트 전제)
	var graded := 0
	for point in def.loot_points:
		var entry: Dictionary = state.loot[point["id"]]
		var grade := String(entry.get("durability", ""))
		if grade.is_empty():
			continue
		graded += 1
		var iid := StringName("%s/%s" % [def.floor_id, point["id"]])
		var inst: ItemInstance = world.ground_items[iid]["instance"]
		t.assert_eq(String(inst.durability_grade), grade,
			"실체화에서 등급이 보존돼야 한다 (`%s`)" % point["id"])
	t.assert_true(graded > 0, "테스트 전제: 등급이 있는 파밍 결과가 있어야 한다")

	# 줍고 → 저장 → 로드 후에도 등급이 남아야 한다
	var first_id := StringName("%s/%s" % [def.floor_id, def.loot_points[0]["id"]])
	var before: ItemInstance = world.ground_items[first_id]["instance"]
	var before_grade := before.durability_grade
	ItemService.pick_up(run, world, state, &"player", first_id)

	var r := RunSave.from_text(RunSave.to_text(run), defs)
	var loaded: RunState = r["run"]
	var after: ItemInstance = loaded.inventory(&"player")[0]
	t.assert_eq(after.durability_grade, before_grade,
		"세이브 왕복 후에도 내구 등급이 같아야 한다 (`%s`)" % before_grade)
	t.assert_true(not String(after.durability_grade).is_empty(),
		"등급이 빈 값으로 뭉개지면 안 된다 — int 변환으로 사라지던 버그")

