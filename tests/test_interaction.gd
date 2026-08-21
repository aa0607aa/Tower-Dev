extends RefCounted
## `P3-T1` — 상호작용 대상 선택.
##
## 검사하는 두 가지:
##   1. **결정적인가** — 같은 상황에서 항상 같은 대상이 잡히는가 (`SYS-003`)
##   2. **새지 않는가** — 미발견 함정의 존재/종류를 프롬프트가 알려주지 않는가 (`SYS-005`)


## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 그래서 남은 단언이 조용히 사라져도 러너에는 PASS로 보인다 — 실제로 겪었다.
## 하한을 못박아 두면 그런 유실이 실패로 드러난다.
## 단언을 **추가**할 때는 손댈 필요 없고, 의도적으로 **줄일** 때만 함께 낮춘다.
const MIN_ASSERTIONS := 38


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return
	var env := AccessService.envelope_from_floor(&"player", def)
	var state := FloorPopulator.populate(def, 20260820)
	var run := RunState.new(20260820)
	var world := run.ensure_world(def.world_id)
	world.put_floor(state)

	var made := ItemService.materialize_floor_loot(world, def, state)
	t.assert_eq(made, def.loot_points.size(),
		"주워지지 않은 파밍 지점이 전부 바닥에 실체화돼야 한다")

	# 멱등해야 한다 — 로드 직후 다시 부르면 물건이 복제된다
	var again := ItemService.materialize_floor_loot(world, def, state)
	t.assert_eq(again, 0, "두 번 실체화하면 물건이 복제된다 — 멱등해야 한다")
	t.assert_eq(world.ground_items.size(), def.loot_points.size(),
		"바닥 물건 수가 늘어나면 안 된다")

	_test_reach(t, def, world, env)
	_test_deterministic_selection(t)
	_test_picked_up_disappears(t, def, run, world, state, env)
	_test_no_trap_leak(t, def, world, env)
	_test_envelope_limits_reach(t, def, world)
	_test_query_does_not_mutate(t, def, world, state, env)
	t.done()


## 사거리 밖은 후보가 아니고, 위에 서면 후보가 된다.
func _test_reach(t: TestCase, def: FloorDefinition, world: WorldState, env: AccessEnvelope) -> void:
	var lp: Dictionary = def.loot_points[0]
	var cell: Vector2i = lp["cell"]
	var expect_id := StringName("%s/%s" % [def.floor_id, lp["id"]])

	var on_top := InteractionService.candidates(def, world, env, cell)
	t.assert_true(on_top.size() >= 1, "물건 위에 서면 후보가 있어야 한다")
	t.assert_eq(on_top[0]["id"], expect_id, "가장 가까운 후보는 발 밑이어야 한다")

	# 대각도 닿아야 한다 — 8방향 연속 이동이므로 대각만 안 되면 이상하다.
	var diagonal := InteractionService.candidates(def, world, env, cell + Vector2i(1, 1))
	var found := false
	for c in diagonal:
		if c["id"] == expect_id:
			found = true
	t.assert_true(found, "대각 한 칸도 사거리 안이어야 한다")

	var far := InteractionService.candidates(def, world, env, cell + Vector2i(9, 9))
	for c in far:
		t.assert_true(c["id"] != expect_id, "사거리 밖 물건이 후보에 들어오면 안 된다")


## ★ 완료 조건 — 후보가 여러 개여도 선택이 결정적이어야 한다.
func _test_deterministic_selection(t: TestCase) -> void:
	var crowded := FloorDefinitionLoader.build({
		"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
		"rooms": [{"id": "r", "rect": [0, 0, 8, 8], "tags": []}],
		"start_points": [[1, 1]],
	})
	var envc := AccessService.envelope_from_floor(&"player", crowded)
	var w := WorldState.new(&"w")
	# 같은 칸에 둘, 대각에 하나
	w.put_ground_item(ItemInstance.new(&"zzz_last", &"a", &"misc", &"", &""),
		WorldAnchor.new(&"w", &"r", Vector2i(4, 4), 0))
	w.put_ground_item(ItemInstance.new(&"aaa_first", &"b", &"misc", &"", &""),
		WorldAnchor.new(&"w", &"r", Vector2i(4, 4), 0))
	w.put_ground_item(ItemInstance.new(&"mmm_far", &"c", &"misc", &"", &""),
		WorldAnchor.new(&"w", &"r", Vector2i(5, 5), 0))

	var first := InteractionService.best(crowded, w, envc, Vector2i(4, 4))
	t.assert_eq(first["id"], &"aaa_first",
		"같은 거리면 id 순으로 결정된다 (실제 %s)" % first["id"])

	for i in 20:
		var again := InteractionService.best(crowded, w, envc, Vector2i(4, 4))
		t.assert_eq(again["id"], first["id"], "같은 상황에서 항상 같은 대상이어야 한다")

	var list := InteractionService.candidates(crowded, w, envc, Vector2i(4, 4))
	t.assert_eq(list.size(), 3, "사거리 안 후보가 모두 들어와야 한다")
	t.assert_eq(list[2]["id"], &"mmm_far", "먼 후보가 뒤로 정렬돼야 한다")


## 이미 주운 지점은 후보에서 빠진다.
func _test_picked_up_disappears(t: TestCase, def: FloorDefinition, run: RunState,
		world: WorldState, state: FloorState, env: AccessEnvelope) -> void:
	var lp: Dictionary = def.loot_points[0]
	var cell: Vector2i = lp["cell"]
	var iid := StringName("%s/%s" % [def.floor_id, lp["id"]])
	var before := InteractionService.candidates(def, world, env, cell).size()

	t.assert_true(ItemService.pick_up(run, world, state, &"player", iid), "주울 수 있어야 한다")
	var after := InteractionService.candidates(def, world, env, cell)
	for c in after:
		t.assert_true(c["id"] != iid, "주운 물건은 후보에서 빠져야 한다")
	t.assert_eq(after.size(), before - 1, "정확히 하나만 빠져야 한다")
	t.assert_true(state.is_looted(lp["id"]), "파밍 지점이 수확됨으로 표시돼야 한다")

	# 원상복구 — 뒤 테스트에 영향을 주면 안 된다
	ItemService.drop(run, world, &"player", iid,
		WorldAnchor.new(def.world_id, def.world_region_ref, cell, 0), env)


## ★ `SYS-005` — 함정이 상호작용 프롬프트로 새면 안 된다.
##
## 함정 위에 서 있어도 "여기 뭔가 있다"가 표시되면 그 자체가 정답 표시다.
func _test_no_trap_leak(t: TestCase, def: FloorDefinition, world: WorldState,
		env: AccessEnvelope) -> void:
	t.assert_true(def.traps.size() > 0, "테스트 전제: 함정이 있어야 한다")

	for tr in def.traps:
		var cell: Vector2i = tr["cell"]
		var list := InteractionService.candidates(def, world, env, cell)
		for c in list:
			t.assert_true(c["kind"] != &"trap",
				"함정이 상호작용 후보로 노출되면 안 된다 (%s)" % tr["id"])
			t.assert_true(c["id"] != tr["id"],
				"함정 id가 후보에 나타나면 안 된다 (%s)" % tr["id"])
			# 라벨에 함정 정보가 섞이면 안 된다
			var label := String(c["label"])
			t.assert_true(not label.contains(String(tr["type"])),
				"라벨이 함정 종류를 노출하면 안 된다 (%s)" % label)
			for clue in tr["clues"]:
				t.assert_true(not label.contains(String(clue)),
					"라벨이 함정 단서를 노출하면 안 된다")

	# 라벨은 내용물도 말하지 않는다 (`ITM-002` `D-026` — 외형만으로 효과를 알 수 없다)
	var lp: Dictionary = def.loot_points[0]
	var on_loot := InteractionService.candidates(def, world, env, lp["cell"])
	for c in on_loot:
		var inst: ItemInstance = world.ground_items[c["id"]]["instance"]
		if not String(inst.item_id).is_empty():
			t.assert_true(not String(c["label"]).contains(String(inst.item_id)),
				"라벨이 아이템 내용물을 노출하면 안 된다 (%s)" % inst.item_id)


## 행동 반경 밖에는 손이 닿지 않는다 (`D-017` 4항 · `FLR-024`).
func _test_envelope_limits_reach(t: TestCase, def: FloorDefinition, world: WorldState) -> void:
	var lp: Dictionary = def.loot_points[0]
	var cell: Vector2i = lp["cell"]
	var iid := StringName("%s/%s" % [def.floor_id, lp["id"]])

	var blocked := AccessService.envelope_from_floor(&"player", def)
	blocked.deny_cell(cell)
	var list := InteractionService.candidates(def, world, blocked, cell)
	for c in list:
		t.assert_true(c["id"] != iid,
			"허용 영역 밖 물건은 상호작용 후보가 아니어야 한다")

	# 봉투가 없으면 제약이 없다 — NPC·야생동물 경로 (FLR-023)
	var no_env := InteractionService.candidates(def, world, null, cell)
	var found := false
	for c in no_env:
		if c["id"] == iid:
			found = true
	t.assert_true(found, "봉투가 없으면 제약받지 않아야 한다 (FLR-023)")


## 조회는 상태를 바꾸지 않는다. 바꾸면 "보기만 했는데 주워졌다"가 된다.
func _test_query_does_not_mutate(t: TestCase, def: FloorDefinition, world: WorldState,
		state: FloorState, env: AccessEnvelope) -> void:
	var before_state := JSON.stringify(state.to_save_dict())
	var before_world := JSON.stringify(world.to_save_dict())
	for lp in def.loot_points:
		InteractionService.candidates(def, world, env, lp["cell"])
		InteractionService.best(def, world, env, lp["cell"])
	t.assert_eq(JSON.stringify(state.to_save_dict()), before_state,
		"상호작용 조회가 FloorState를 바꾸면 안 된다")
	t.assert_eq(JSON.stringify(world.to_save_dict()), before_world,
		"상호작용 조회가 WorldState를 바꾸면 안 된다")
