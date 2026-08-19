extends RefCounted
## P2-T6 — 저장/복원. (`TEST_CHECKLIST` 2-3 · `SYS-003` `SYS-011`)

const SEED := 20260819


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return

	_test_round_trip(t, def)
	_test_dynamic_state_survives(t, def)
	_test_definition_change_is_detected(t, def)
	_test_version_mismatch_is_detected(t, def)
	_test_no_terrain_mutation_in_floor_save(t, def)
	_test_save_is_byte_stable(t, def)


func _populated(def: FloorDefinition) -> FloorState:
	var state := FloorPopulator.populate(def, SEED)
	var env := AccessService.envelope_from_floor(&"player", def)
	state.party_stairs.append(StairResolver.new().resolve(def, env, &"party_1", SEED))
	return state


## ★ 2-3 — 저장 후 로드하면 배치가 완전히 같아야 한다.
func _test_round_trip(t: TestCase, def: FloorDefinition) -> void:
	var original := _populated(def)
	var text := JSON.stringify(FloorSave.to_dict(original), "  ", true)
	var result := FloorSave.from_text(text, def)

	t.assert_eq(result["status"], FloorSave.LoadStatus.OK, "정상 로드여야 한다")
	var restored: FloorState = result["state"]
	t.assert_true(restored != null, "상태가 복원돼야 한다")
	if restored == null:
		return

	t.assert_eq(restored.to_save_dict().hash(), original.to_save_dict().hash(),
		"저장→로드 후 상태가 완전히 같아야 한다 (2-3)")
	t.assert_eq(restored.generation_seed, original.generation_seed, "시드도 함께 보존")
	t.assert_eq(restored.definition_hash, original.definition_hash, "정의 해시 보존")


## 플레이 중 생긴 변화가 살아남아야 한다.
func _test_dynamic_state_survives(t: TestCase, def: FloorDefinition) -> void:
	var state := _populated(def)

	# 함정 하나 발동, 파밍 하나 회수, 셀 하나 발견
	var trap: Dictionary = def.traps[0]
	state.fire_trap(trap["id"], bool(trap["one_shot"]))
	var lp: Dictionary = def.loot_points[0]
	state.take_loot(lp["id"])
	state.discovered_cells[Vector2i(11, 12)] = true
	state.elapsed_seconds = 137.5

	var result := FloorSave.from_text(JSON.stringify(FloorSave.to_dict(state), "  ", true), def)
	var restored: FloorState = result["state"]

	t.assert_true(restored.trap_has_fired(trap["id"]), "함정 발동 기록이 살아남아야 한다")
	if bool(trap["one_shot"]):
		t.assert_true(not restored.trap_is_armed(trap["id"]),
			"발사형 소모 상태가 살아남아야 한다 (FLR-012)")
	t.assert_true(restored.is_looted(lp["id"]), "루팅 상태가 살아남아야 한다")
	t.assert_true(restored.discovered_cells.has(Vector2i(11, 12)), "발견 셀이 살아남아야 한다")
	t.assert_almost_eq(restored.elapsed_seconds, 137.5, "경과 시간 보존", 0.001)

	# 계단은 지형과 독립적으로 보존돼야 한다 (FAC-013)
	t.assert_eq(restored.party_stairs.size(), 1, "계단이 보존돼야 한다")
	var a: WorldAnchor = restored.party_stairs[0]["anchor"]
	var b: WorldAnchor = state.party_stairs[0]["anchor"]
	t.assert_true(a.equals(b), "계단 anchor가 정확히 복원돼야 한다")


## ★ 정의가 바뀌면 **조용히 진행하지 않는다.**
## 옛 세이브의 좌표가 새 지형의 엉뚱한 곳을 가리킬 수 있다.
func _test_definition_change_is_detected(t: TestCase, def: FloorDefinition) -> void:
	var state := _populated(def)
	var text := JSON.stringify(FloorSave.to_dict(state), "  ", true)

	# 방 하나를 넓힌 "패치된" 정의
	var patched_src := {
		"floor_id": "floor1", "theme_id": "ancient_temple",
		"world_id": "world_tutorial", "world_region_ref": "temple_plateau",
		"rooms": [{"id": "only", "rect": [0, 0, 10, 10], "tags": []}],
		"start_points": [[1, 1]],
	}
	var patched := FloorDefinitionLoader.build(patched_src)

	var result := FloorSave.from_text(text, patched)
	t.assert_eq(result["status"], FloorSave.LoadStatus.DEFINITION_CHANGED,
		"정의가 바뀌면 감지해야 한다")
	t.assert_true(String(result["message"]).length() > 0, "무엇이 달라졌는지 알려야 한다")
	# 상태 자체는 함께 돌려줘야 호출자가 마이그레이션을 판단할 수 있다
	t.assert_true(result["state"] != null, "감지했어도 상태는 함께 돌려줘야 한다")


func _test_version_mismatch_is_detected(t: TestCase, def: FloorDefinition) -> void:
	var d := FloorSave.to_dict(_populated(def))
	d["save_version"] = FloorSave.SAVE_VERSION + 99
	var result := FloorSave.from_text(JSON.stringify(d), def)
	t.assert_eq(result["status"], FloorSave.LoadStatus.VERSION_MISMATCH,
		"세이브 버전이 다르면 감지해야 한다")


## ★ `FLR-024` — 지형 변경은 `WorldState` 소유다. 층 세이브에 들어오면 안 된다.
func _test_no_terrain_mutation_in_floor_save(t: TestCase, def: FloorDefinition) -> void:
	var d := FloorSave.to_dict(_populated(def))
	for key in d:
		var k := String(key).to_lower()
		t.assert_true(not k.contains("terrain"),
			"층 세이브에 지형 키가 있으면 안 된다 (`%s`) — 지형은 WorldState 소유 (FLR-024)" % key)
		t.assert_true(not k.contains("mutation"),
			"층 세이브에 mutation 키가 있으면 안 된다 (`%s`)" % key)


## 같은 상태면 같은 바이트가 나와야 한다.
## Dictionary 순회 순서에 의존하면 아무것도 안 했는데 세이브가 달라진다 (`SYS-003`).
func _test_save_is_byte_stable(t: TestCase, def: FloorDefinition) -> void:
	var a := JSON.stringify(FloorSave.to_dict(_populated(def)), "  ", true)
	var b := JSON.stringify(FloorSave.to_dict(_populated(def)), "  ", true)
	t.assert_eq(a, b, "같은 상태는 같은 바이트로 직렬화돼야 한다")

	# 삽입 순서를 바꿔도 같아야 한다
	var s1 := FloorPopulator.populate(def, SEED)
	var s2 := FloorPopulator.populate(def, SEED)
	s1.event_flags[&"z_last"] = true
	s1.event_flags[&"a_first"] = true
	s2.event_flags[&"a_first"] = true
	s2.event_flags[&"z_last"] = true
	t.assert_eq(JSON.stringify(s1.to_save_dict()), JSON.stringify(s2.to_save_dict()),
		"삽입 순서가 달라도 직렬화 결과가 같아야 한다")
