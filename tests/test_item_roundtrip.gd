extends RefCounted
## `P3-T2b` `P3-T3` — 줍기/버리기 소유권 왕복. (`ITM-001` `SYS-003` `WLD-003`)
##
## ## 완료 조건 그대로를 검사한다
## `줍기 → 저장 → 로드 → 버리기 → 저장 → 로드 → 다시 줍기`가 **같은 instance**를 유지해야 한다.
##
## ## 왜 이게 어려운 문제인가
## 전에는 `FloorState.loot[point_id].looted = true` 하나로 "주웠다"를 표현했다.
## 그러면 **버린 물건을 표현할 방법이 없다** — `looted`를 되돌리면 원래 파밍 지점에
## 다시 나타나고(순간이동), 되돌리지 않으면 물건이 사라진다.
## 그래서 "지점에서 무엇이 나왔나"와 "그 물건이 지금 어디 있나"를 나눴다.

const EXILE := &"player"


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return
	var defs := {def.floor_id: def}

	_test_full_roundtrip(t, def, defs)
	_test_no_duplication(t, def)
	_test_no_loss(t, def)
	_test_drop_outside_envelope_rejected(t, def)
	_test_materialize_does_not_revive_taken(t, def)


## ★ 완료 조건 — 전체 왕복에서 instance가 살아남는가.
func _test_full_roundtrip(t: TestCase, def: FloorDefinition, defs: Dictionary) -> void:
	var run := RunState.new(20260820)
	var world := run.ensure_world(def.world_id)
	var state := FloorPopulator.populate(def, 20260820)
	world.put_floor(state)
	ItemService.materialize_floor_loot(world, def, state)

	var lp: Dictionary = def.loot_points[0]
	var iid := StringName("%s/%s" % [def.floor_id, lp["id"]])
	var original_item_id: StringName = (world.ground_items[iid]["instance"] as ItemInstance).item_id

	# ① 줍기
	t.assert_true(ItemService.pick_up(run, world, state, EXILE, iid), "주울 수 있어야 한다")
	t.assert_true(run.has_item(EXILE, iid), "인벤토리에 들어가야 한다")
	t.assert_true(not world.ground_items.has(iid), "바닥에서 없어져야 한다")

	# ② 저장 → 로드
	var r1 := RunSave.from_text(RunSave.to_text(run), defs)
	t.assert_eq(int(r1["status"]), int(FloorSave.LoadStatus.OK), "로드가 정상이어야 한다")
	var run2: RunState = r1["run"]
	t.assert_true(run2.has_item(EXILE, iid), "로드 후에도 인벤토리에 있어야 한다")
	var kept: ItemInstance = run2.inventory(EXILE)[0]
	t.assert_eq(kept.instance_id, iid, "instance_id가 보존돼야 한다")
	t.assert_eq(kept.item_id, original_item_id, "물건 종류가 보존돼야 한다")
	t.assert_eq(kept.origin_point_id, lp["id"], "출처가 보존돼야 한다")

	# ③ 원래 지점이 아닌 **다른 곳**에 버리기
	var world2 := run2.world(def.world_id)
	var drop_cell: Vector2i = def.start_points[0]
	t.assert_true(drop_cell != lp["cell"], "테스트 전제: 버리는 곳이 원래 지점과 달라야 한다")
	var env := AccessService.envelope_from_floor(&"player", def)
	t.assert_true(ItemService.drop(run2, world2, EXILE, iid,
		WorldAnchor.new(def.world_id, def.world_region_ref, drop_cell, 0), env),
		"버릴 수 있어야 한다")
	t.assert_true(not run2.has_item(EXILE, iid), "인벤토리에서 빠져야 한다")

	# ④ 저장 → 로드
	var r2 := RunSave.from_text(RunSave.to_text(run2), defs)
	var run3: RunState = r2["run"]
	var world3 := run3.world(def.world_id)

	# ★ 버린 자리에 있어야 한다. 원래 파밍 지점으로 순간이동하면 안 된다.
	var anchor := world3.ground_item_anchor(iid)
	t.assert_true(anchor != null, "버린 물건이 바닥에 있어야 한다")
	t.assert_eq(anchor.cell, drop_cell, "**버린 자리**에 있어야 한다 (원래 지점 %v)" % lp["cell"])
	t.assert_true(anchor.cell != lp["cell"], "원래 파밍 지점으로 돌아가면 안 된다")

	# ⑤ 다시 줍기 — 같은 instance여야 한다
	var state3 := world3.floor_state(def.floor_id)
	t.assert_true(ItemService.pick_up(run3, world3, state3, EXILE, iid), "다시 주울 수 있어야 한다")
	var again: ItemInstance = run3.inventory(EXILE)[0]
	t.assert_eq(again.instance_id, iid, "왕복 후에도 같은 instance여야 한다")
	t.assert_eq(again.item_id, original_item_id, "왕복 후에도 같은 물건이어야 한다")


## 복제 금지 — 두 번 주울 수 없다.
func _test_no_duplication(t: TestCase, def: FloorDefinition) -> void:
	var run := RunState.new(1)
	var world := run.ensure_world(def.world_id)
	var state := FloorPopulator.populate(def, 1)
	world.put_floor(state)
	ItemService.materialize_floor_loot(world, def, state)

	var iid := StringName("%s/%s" % [def.floor_id, def.loot_points[0]["id"]])
	t.assert_true(ItemService.pick_up(run, world, state, EXILE, iid), "첫 줍기는 성공")
	t.assert_true(not ItemService.pick_up(run, world, state, EXILE, iid),
		"같은 물건을 두 번 주우면 안 된다 (복제)")
	t.assert_eq(run.inventory(EXILE).size(), 1, "인벤토리에 하나만 있어야 한다")

	# 실체화를 다시 불러도 되살아나지 않는다
	ItemService.materialize_floor_loot(world, def, state)
	t.assert_true(not world.ground_items.has(iid),
		"주운 물건이 재실체화로 되살아나면 안 된다")


## 소실 금지 — 실패한 연산은 아무것도 바꾸지 않는다.
func _test_no_loss(t: TestCase, def: FloorDefinition) -> void:
	var run := RunState.new(1)
	var world := run.ensure_world(def.world_id)
	var env := AccessService.envelope_from_floor(&"player", def)

	# 없는 물건 버리기 → false, 상태 변화 없음
	var before := JSON.stringify(run.to_save_dict())
	t.assert_true(not ItemService.drop(run, world, EXILE, &"nonexistent",
		WorldAnchor.new(def.world_id, def.world_region_ref, def.start_points[0], 0), env),
		"없는 물건을 버리면 실패해야 한다")
	t.assert_eq(JSON.stringify(run.to_save_dict()), before,
		"실패한 버리기가 상태를 바꾸면 안 된다")

	# 없는 물건 줍기 → false
	var state := FloorPopulator.populate(def, 1)
	t.assert_true(not ItemService.pick_up(run, world, state, EXILE, &"nonexistent"),
		"없는 물건을 주우면 실패해야 한다")
	t.assert_eq(run.inventory(EXILE).size(), 0, "실패한 줍기가 물건을 만들면 안 된다")


## 행동 반경 밖에는 버릴 수 없다 (`D-017` 4항 · `FLR-024`).
func _test_drop_outside_envelope_rejected(t: TestCase, def: FloorDefinition) -> void:
	var run := RunState.new(1)
	var world := run.ensure_world(def.world_id)
	var item := ItemInstance.new(&"held", &"stone", &"misc", 0, &"")
	run.add_to_inventory(EXILE, item)

	var env := AccessService.envelope_from_floor(&"player", def)
	var outside := WorldAnchor.new(def.world_id, def.world_region_ref, Vector2i(-500, -500), 0)
	t.assert_true(not env.contains(outside), "테스트 전제: 그 좌표가 경계 밖이어야 한다")

	t.assert_true(not ItemService.drop(run, world, EXILE, &"held", outside, env),
		"경계 밖에는 버릴 수 없어야 한다 (유배자 인과는 경계를 넘지 못한다)")
	t.assert_true(run.has_item(EXILE, &"held"),
		"거부된 버리기 뒤에도 물건은 손에 남아 있어야 한다 — 소실 금지")


## 이미 수확된 지점은 재실체화로 되살아나지 않는다.
func _test_materialize_does_not_revive_taken(t: TestCase, def: FloorDefinition) -> void:
	var run := RunState.new(9)
	var world := run.ensure_world(def.world_id)
	var state := FloorPopulator.populate(def, 9)
	world.put_floor(state)

	# 처음부터 수확된 것으로 표시
	var point_id: StringName = def.loot_points[0]["id"]
	state.take_loot(point_id)

	var made := ItemService.materialize_floor_loot(world, def, state)
	t.assert_eq(made, def.loot_points.size() - 1,
		"수확된 지점은 실체화되지 않아야 한다")
	t.assert_true(not world.ground_items.has(StringName("%s/%s" % [def.floor_id, point_id])),
		"수확된 지점의 물건이 바닥에 생기면 안 된다")
