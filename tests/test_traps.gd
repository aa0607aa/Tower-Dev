extends RefCounted
## `P3-T4` `P3-T5` — 함정 발동 메커니즘. (`FLR-011` `FLR-012` `FLR-028`)
##
## ## 가장 중요한 검사
## **플레이어 몸이 아니어도 메커니즘이 맞으면 발동해야 한다** (`FLR-028`).
## 원작에는 돌을 던져 벽 화살 함정을 먼저 터뜨려 제거하는 공략이 나온다.
## `body is Player`로 구현하면 그게 불가능해진다.
##
## 동시에 **모든 함정이 모든 물체에 반응하지는 않는다** — 각 함정이 선언한 메커니즘을 따른다.


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return

	_test_mechanism_is_data(t, def)
	_test_thrown_stone_fires_wall_bolt(t, def)
	_test_not_every_trap_reacts_to_everything(t, def)
	_test_one_shot_does_not_recharge(t, def)
	_test_independent_actor_can_trigger(t, def)
	_test_envelope_blocks_exile_caused_stimulus(t, def)
	_test_lethal_traps_have_clues(t, def)
	_test_no_actor_class_in_source(t)


## 메커니즘이 코드가 아니라 **데이터**에 있어야 한다.
func _test_mechanism_is_data(t: TestCase, def: FloorDefinition) -> void:
	for trap in def.traps:
		t.assert_true(trap.has("accepts"), "함정 `%s`에 accepts가 있어야 한다" % trap["id"])
		t.assert_true((trap["accepts"] as Array).size() > 0,
			"함정 `%s`가 아무 자극도 받지 않으면 조용히 죽는다" % trap["id"])

	# 정의가 바뀌면 세이브 의미가 바뀐다 → 해시에 들어가야 한다 (`P2-REV-003`)
	var base := {
		"floor_id": "t", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
		"rooms": [{"id": "r", "rect": [0, 0, 6, 6], "tags": []}],
		"start_points": [[1, 1]],
		"traps": [{"id": "x", "cell": [2, 2], "type": "pitfall", "lethal": true,
			"one_shot": false, "clues": ["c"], "accepts": ["pressure"], "min_mass": 25.0}],
	}
	var h0: String = FloorDefinitionLoader.build(base).definition_hash

	var changed_accepts := base.duplicate(true)
	changed_accepts["traps"][0]["accepts"] = ["impact"]
	t.assert_true(FloorDefinitionLoader.build(changed_accepts).definition_hash != h0,
		"accepts가 바뀌면 정의 해시가 달라져야 한다")

	var changed_mass := base.duplicate(true)
	changed_mass["traps"][0]["min_mass"] = 1.0
	t.assert_true(FloorDefinitionLoader.build(changed_mass).definition_hash != h0,
		"min_mass가 바뀌면 정의 해시가 달라져야 한다")

	# 서술 순서는 해시를 흔들면 안 된다
	var reordered := base.duplicate(true)
	reordered["traps"][0]["accepts"] = ["pressure"]
	t.assert_eq(FloorDefinitionLoader.build(reordered).definition_hash, h0,
		"같은 메커니즘이면 같은 해시여야 한다")


## ★★ `FLR-028` 핵심 — 던진 돌이 벽 화살 함정을 발동시킨다.
func _test_thrown_stone_fires_wall_bolt(t: TestCase, def: FloorDefinition) -> void:
	var bolt := _find_trap_of_type(def, &"wall_bolt")
	t.assert_true(not bolt.is_empty(), "테스트 전제: wall_bolt 함정이 있어야 한다")
	if bolt.is_empty():
		return

	var state := FloorPopulator.populate(def, 1)
	# 던진 돌 — 가볍고, 플레이어 몸이 아니다
	var stone := TrapStimulus.from_thrown(bolt["cell"], 0.5, &"player")

	t.assert_true(TrapRuntime.can_trigger(bolt, stone),
		"던진 돌이 벽 화살 함정을 발동시킬 수 있어야 한다 (FLR-028 원작 사례)")
	var fired := TrapRuntime.apply(def, state, stone)
	t.assert_true(fired.has(bolt["id"]), "실제로 발동해야 한다")
	t.assert_true(state.trap_has_fired(bolt["id"]), "fired 상태가 저장돼야 한다")

	# ★ 그리고 그 결과 유배자는 안전하게 지나갈 수 있어야 한다 — 공략이 성립해야 한다
	var walk := TrapStimulus.from_body(bolt["cell"], 70.0, &"player")
	t.assert_true(not TrapRuntime.should_fire(bolt, state, walk),
		"먼저 터뜨린 뒤에는 밟아도 발동하지 않아야 한다 (공략이 성립해야 한다)")


## 모든 함정이 모든 것에 반응하지는 않는다 (`FLR-028` 판단 항목).
func _test_not_every_trap_reacts_to_everything(t: TestCase, def: FloorDefinition) -> void:
	var pit := _find_trap_of_type(def, &"pitfall")
	t.assert_true(not pit.is_empty(), "테스트 전제: pitfall 함정이 있어야 한다")
	if pit.is_empty():
		return

	# 가벼운 돌은 약한 바닥을 무너뜨리지 못한다
	var stone := TrapStimulus.from_thrown(pit["cell"], 0.5, &"player")
	t.assert_true(not TrapRuntime.can_trigger(pit, stone),
		"가벼운 돌이 함정 바닥을 무너뜨리면 안 된다 — 메커니즘을 무시한 것이다")

	# 체중이 실리면 무너진다
	var body := TrapStimulus.from_body(pit["cell"], 70.0, &"player")
	t.assert_true(TrapRuntime.can_trigger(pit, body),
		"체중이 실리면 발동해야 한다")

	# 위치가 다르면 발동하지 않는다
	var elsewhere := TrapStimulus.from_body(pit["cell"] + Vector2i(3, 3), 70.0, &"player")
	t.assert_true(not TrapRuntime.can_trigger(pit, elsewhere),
		"다른 칸의 자극이 함정을 발동시키면 안 된다")


## `FLR-012` — 발사형은 재충전되지 않는다. 재로드해도 마찬가지다.
func _test_one_shot_does_not_recharge(t: TestCase, def: FloorDefinition) -> void:
	var bolt := _find_trap_of_type(def, &"wall_bolt")
	if bolt.is_empty():
		return
	t.assert_true(bolt["one_shot"], "테스트 전제: wall_bolt는 one_shot이어야 한다")

	var state := FloorPopulator.populate(def, 2)
	var s := TrapStimulus.from_thrown(bolt["cell"], 0.5, &"player")
	t.assert_true(TrapRuntime.trigger(bolt, state, s), "첫 발동은 성공")
	t.assert_true(not TrapRuntime.trigger(bolt, state, s), "두 번째는 발동하지 않아야 한다")

	# 저장 → 로드 후에도 재충전되지 않아야 한다
	var r := FloorSave.from_text(JSON.stringify(FloorSave.to_dict(state)), def)
	var loaded: FloorState = r["state"]
	t.assert_true(loaded.trap_has_fired(bolt["id"]), "fired가 로드로 복원돼야 한다")
	t.assert_true(not TrapRuntime.trigger(bolt, loaded, s),
		"재로드 후에도 재충전되면 안 된다 (FLR-012)")


## NPC·야생동물도 메커니즘이 맞으면 발동시킨다 — 플레이어 전용이 아니다.
func _test_independent_actor_can_trigger(t: TestCase, def: FloorDefinition) -> void:
	var pit := _find_trap_of_type(def, &"pitfall")
	if pit.is_empty():
		return
	var state := FloorPopulator.populate(def, 3)
	var beast := TrapStimulus.from_independent(
		TrapStimulus.Kind.PRESSURE, pit["cell"], 60.0)

	t.assert_true(TrapRuntime.can_trigger(pit, beast),
		"야생동물도 메커니즘이 맞으면 발동시켜야 한다 (FLR-028)")
	var fired := TrapRuntime.apply(def, state, beast)
	t.assert_true(fired.has(pit["id"]), "실제로 발동해야 한다")


## 유배자 인과 자극은 행동 반경을 넘지 못한다 (`D-017` 4항). 독립 시뮬레이션은 통과한다.
func _test_envelope_blocks_exile_caused_stimulus(t: TestCase, def: FloorDefinition) -> void:
	var pit := _find_trap_of_type(def, &"pitfall")
	if pit.is_empty():
		return
	var env := AccessService.envelope_from_floor(&"player", def)
	env.deny_cell(pit["cell"])

	var state := FloorPopulator.populate(def, 4)
	var thrown := TrapStimulus.from_thrown(pit["cell"], 70.0, &"player")
	t.assert_eq(TrapRuntime.apply(def, state, thrown, env).size(), 0,
		"유배자가 던진 물체는 경계 밖 함정을 건드릴 수 없어야 한다")
	t.assert_true(not state.trap_has_fired(pit["id"]), "상태도 바뀌면 안 된다")

	# 독립 시뮬레이션은 같은 경계에 막히지 않는다 (FLR-023)
	var beast := TrapStimulus.from_independent(TrapStimulus.Kind.PRESSURE, pit["cell"], 60.0)
	t.assert_true(TrapRuntime.apply(def, state, beast, env).size() > 0,
		"NPC·야생동물은 유배자 경계에 막히지 않아야 한다")


## `FLR-011` — 치명 함정은 사전 단서가 있어야 한다. (`3-1` 회귀 보호)
func _test_lethal_traps_have_clues(t: TestCase, def: FloorDefinition) -> void:
	for trap in def.traps:
		if bool(trap["lethal"]):
			t.assert_true((trap["clues"] as Array).size() > 0,
				"치명 함정 `%s`는 사전 단서가 있어야 한다 (FLR-011)" % trap["id"])


## ★ 소스 가드 — 함정 판정에 actor class 조건이 들어오면 안 된다 (`FLR-028`).
func _test_no_actor_class_in_source(t: TestCase) -> void:
	var runtime := FileAccess.get_file_as_string("res://scripts/traps/trap_runtime.gd")
	var code := ""
	for line in runtime.split("\n"):
		# 주석은 규칙을 설명하느라 단어를 쓸 수밖에 없다 — 실제 코드만 본다.
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		code += stripped + "\n"

	for forbidden in ["is Player", "is CharacterBody2D", "\"player\"", "&\"player\""]:
		t.assert_true(not code.contains(forbidden),
			"함정 판정이 actor class/id에 의존하면 안 된다 (FLR-028 — `%s` 발견)" % forbidden)


func _find_trap_of_type(def: FloorDefinition, type_name: StringName) -> Dictionary:
	for trap in def.traps:
		if trap["type"] == type_name:
			return trap
	return {}
