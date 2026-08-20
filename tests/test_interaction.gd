extends RefCounted
## `P3-T1` — 상호작용 대상 선택.
##
## 검사하는 두 가지:
##   1. **결정적인가** — 같은 상황에서 항상 같은 대상이 잡히는가 (`SYS-003`)
##   2. **새지 않는가** — 미발견 함정의 존재/종류를 프롬프트가 알려주지 않는가 (`SYS-005`)


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return
	var env := AccessService.envelope_from_floor(&"player", def)
	var state := FloorPopulator.populate(def, 20260820)

	_test_reach(t, def, state, env)
	_test_deterministic_selection(t, def, state, env)
	_test_looted_disappears(t, def, state, env)
	_test_no_trap_leak(t, def, state, env)
	_test_envelope_limits_reach(t, def, state)
	_test_query_does_not_mutate(t, def, state, env)


## 사거리 밖은 후보가 아니고, 위에 서면 후보가 된다.
func _test_reach(t: TestCase, def: FloorDefinition, state: FloorState, env: AccessEnvelope) -> void:
	var lp: Dictionary = def.loot_points[0]
	var cell: Vector2i = lp["cell"]

	var on_top := InteractionService.candidates(def, state, env, cell)
	t.assert_true(on_top.size() >= 1, "파밍 지점 위에 서면 후보가 있어야 한다")
	t.assert_eq(on_top[0]["id"], lp["id"], "가장 가까운 후보는 발 밑이어야 한다")

	# 대각도 닿아야 한다 — 8방향 연속 이동이므로 대각만 안 되면 이상하다.
	var diagonal := InteractionService.candidates(def, state, env, cell + Vector2i(1, 1))
	var found := false
	for c in diagonal:
		if c["id"] == lp["id"]:
			found = true
	t.assert_true(found, "대각 한 칸도 사거리 안이어야 한다")

	var far := InteractionService.candidates(def, state, env, cell + Vector2i(9, 9))
	for c in far:
		t.assert_true(c["id"] != lp["id"], "사거리 밖 지점이 후보에 들어오면 안 된다")


## ★ 완료 조건 — 후보가 여러 개여도 선택이 결정적이어야 한다.
func _test_deterministic_selection(t: TestCase, def: FloorDefinition, state: FloorState,
		env: AccessEnvelope) -> void:
	# 인접한 파밍 지점 두 개를 인위적으로 만든 정의로 검사한다.
	var crowded := FloorDefinitionLoader.build({
		"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
		"rooms": [{"id": "r", "rect": [0, 0, 8, 8], "tags": []}],
		"start_points": [[1, 1]],
		"loot_points": [
			{"id": "zzz_last", "cell": [4, 4]},
			{"id": "aaa_first", "cell": [4, 4]},
			{"id": "mmm_far", "cell": [5, 5]},
		],
	})
	var st := FloorPopulator.populate(crowded, 7)
	var envc := AccessService.envelope_from_floor(&"player", crowded)

	var first := InteractionService.best(crowded, st, envc, Vector2i(4, 4))
	t.assert_eq(first["id"], &"aaa_first",
		"같은 거리면 id 순으로 결정된다 (실제 %s)" % first["id"])

	# 여러 번 호출해도 같아야 한다
	for i in 20:
		var again := InteractionService.best(crowded, st, envc, Vector2i(4, 4))
		t.assert_eq(again["id"], first["id"], "같은 상황에서 항상 같은 대상이어야 한다")

	# 정렬이 실제로 거리 우선인지 — 먼 것이 뒤로 가야 한다
	var list := InteractionService.candidates(crowded, st, envc, Vector2i(4, 4))
	t.assert_eq(list.size(), 3, "사거리 안 후보가 모두 들어와야 한다")
	t.assert_eq(list[2]["id"], &"mmm_far", "먼 후보가 뒤로 정렬돼야 한다")


## 이미 주운 지점은 후보에서 빠진다.
func _test_looted_disappears(t: TestCase, def: FloorDefinition, state: FloorState,
		env: AccessEnvelope) -> void:
	var lp: Dictionary = def.loot_points[0]
	var cell: Vector2i = lp["cell"]
	var before := InteractionService.candidates(def, state, env, cell).size()

	state.take_loot(lp["id"])
	var after := InteractionService.candidates(def, state, env, cell)
	for c in after:
		t.assert_true(c["id"] != lp["id"], "주운 지점은 후보에서 빠져야 한다")
	t.assert_eq(after.size(), before - 1, "정확히 하나만 빠져야 한다")

	# 원상복구 — 뒤 테스트에 영향을 주면 안 된다
	state.loot[lp["id"]]["looted"] = false


## ★ `SYS-005` — 함정이 상호작용 프롬프트로 새면 안 된다.
##
## 함정 위에 서 있어도 "여기 뭔가 있다"가 표시되면 그 자체가 정답 표시다.
func _test_no_trap_leak(t: TestCase, def: FloorDefinition, state: FloorState,
		env: AccessEnvelope) -> void:
	t.assert_true(def.traps.size() > 0, "테스트 전제: 함정이 있어야 한다")

	for tr in def.traps:
		var cell: Vector2i = tr["cell"]
		var list := InteractionService.candidates(def, state, env, cell)
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
	var on_loot := InteractionService.candidates(def, state, env, lp["cell"])
	for c in on_loot:
		var item_id := String(state.loot[c["id"]].get("item_id", ""))
		if not item_id.is_empty():
			t.assert_true(not String(c["label"]).contains(item_id),
				"라벨이 아이템 내용물을 노출하면 안 된다 (%s)" % item_id)


## 행동 반경 밖에는 손이 닿지 않는다 (`D-017` 4항 · `FLR-024`).
func _test_envelope_limits_reach(t: TestCase, def: FloorDefinition, state: FloorState) -> void:
	var lp: Dictionary = def.loot_points[0]
	var cell: Vector2i = lp["cell"]

	var blocked := AccessService.envelope_from_floor(&"player", def)
	blocked.deny_cell(cell)
	var list := InteractionService.candidates(def, state, blocked, cell)
	for c in list:
		t.assert_true(c["id"] != lp["id"],
			"허용 영역 밖 지점은 상호작용 후보가 아니어야 한다")

	# 봉투가 없으면 지형만 본다 — NPC·야생동물 경로
	var no_env := InteractionService.candidates(def, state, null, cell)
	var found := false
	for c in no_env:
		if c["id"] == lp["id"]:
			found = true
	t.assert_true(found, "봉투가 없으면 제약받지 않아야 한다 (FLR-023)")


## 조회는 상태를 바꾸지 않는다. 바꾸면 "보기만 했는데 주워졌다"가 된다.
func _test_query_does_not_mutate(t: TestCase, def: FloorDefinition, state: FloorState,
		env: AccessEnvelope) -> void:
	var before := JSON.stringify(state.to_save_dict())
	for lp in def.loot_points:
		InteractionService.candidates(def, state, env, lp["cell"])
		InteractionService.best(def, state, env, lp["cell"])
	t.assert_eq(JSON.stringify(state.to_save_dict()), before,
		"상호작용 조회가 FloorState를 바꾸면 안 된다")
