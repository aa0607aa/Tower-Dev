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


## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 그래서 남은 단언이 조용히 사라져도 러너에는 PASS로 보인다 — 실제로 겪었다.
## 하한을 못박아 두면 그런 유실이 실패로 드러난다.
## 단언을 **추가**할 때는 손댈 필요 없고, 의도적으로 **줄일** 때만 함께 낮춘다.
const MIN_ASSERTIONS := 42


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
	_test_drop_is_transactional(t, def)
	_test_save_version_rejects_old(t, def, defs)
	t.done()


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
	var item := ItemInstance.new(&"held", &"stone", &"misc", &"", &"")
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


## ★ `P3-REV-006` — 버리기는 **트랜잭션**이어야 한다.
##
## 전에는 인벤토리에서 먼저 빼고 `put_ground_item()`의 반환값을 무시했다.
## 바닥에 놓는 것이 실패하면 **물건이 영구 소실**된다. 실패하면 양쪽 다 그대로여야 한다.
func _test_drop_is_transactional(t: TestCase, def: FloorDefinition) -> void:
	var run := RunState.new(1)
	var world := run.ensure_world(def.world_id)
	var item := ItemInstance.new(&"held", &"stone", &"misc", &"poor", &"")
	run.add_to_inventory(EXILE, item)

	var before_inv := JSON.stringify(run.to_save_dict())
	var before_ground := world.ground_items.size()

	# 다른 월드의 앵커 — `put_ground_item()`이 거부한다. 봉투는 일부러 없이 간다.
	var foreign := WorldAnchor.new(&"other_world", &"r", Vector2i(1, 1), 0)
	t.assert_true(not ItemService.drop(run, world, EXILE, &"held", foreign, null),
		"다른 월드에는 버릴 수 없어야 한다")

	t.assert_true(run.has_item(EXILE, &"held"),
		"실패한 버리기 뒤에도 물건이 손에 남아야 한다 — 영구 소실 금지 (P3-REV-006)")
	t.assert_eq(run.inventory(EXILE).size(), 1, "인벤토리 개수가 그대로여야 한다")
	t.assert_eq(JSON.stringify(run.to_save_dict()), before_inv,
		"실패한 버리기가 회차 상태를 바꾸면 안 된다")
	t.assert_eq(world.ground_items.size(), before_ground,
		"실패한 버리기가 바닥을 바꾸면 안 된다")

	# 같은 물건을 정상 위치에 버리면 성공해야 한다 — 위 실패가 물건을 망가뜨리지 않았다
	var ok := WorldAnchor.new(def.world_id, def.world_region_ref, def.start_points[0], 0)
	t.assert_true(ItemService.drop(run, world, EXILE, &"held", ok, null),
		"실패 뒤에도 정상 버리기는 되어야 한다")
	t.assert_eq(world.ground_items.size(), before_ground + 1, "이번에는 바닥에 놓여야 한다")


## `P3-REV-007` — 옛 세이브 포맷은 조용히 읽지 않는다.
##
## `ItemInstance`가 `durability: int` → `durability_grade`/`points`로 바뀌었다.
## v1을 그대로 읽으면 **등급이 빈 값으로 뭉개진다** — 잘못 읽느니 알린다.
func _test_save_version_rejects_old(t: TestCase, def: FloorDefinition, defs: Dictionary) -> void:
	# 스키마가 바뀔 때마다 올라간다. v2 = durability 분리, v3 = 전투 상태 추가.
	t.assert_true(RunSave.SAVE_VERSION >= 2,
		"스키마가 바뀌었으므로 버전이 올라가야 한다 (현재 %d)" % RunSave.SAVE_VERSION)

	var run := RunState.new(5)
	run.ensure_world(def.world_id)
	var current := RunSave.to_text(run)
	t.assert_eq(int(RunSave.from_text(current, defs)["status"]),
		int(FloorSave.LoadStatus.OK), "현재 버전은 정상 로드돼야 한다")

	var old_text := current.replace(
		'"save_version": %d' % RunSave.SAVE_VERSION, '"save_version": 1')
	var r := RunSave.from_text(old_text, defs)
	t.assert_eq(int(r["status"]), int(FloorSave.LoadStatus.VERSION_MISMATCH),
		"v1 세이브는 VERSION_MISMATCH로 알려야 한다")
	t.assert_true(r["run"] == null, "버전이 다르면 상태를 만들지 않아야 한다")

