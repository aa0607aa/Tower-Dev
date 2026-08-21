extends RefCounted
## P2-T3 — 함정/파밍 정적·동적 분리와 결정성.
##
## `TEST_CHECKLIST` 2-3(동적 배치 결정성) · 3-1(함정 단서 강제) · `FLR-002` · `D-020`.

const SEED_A := 12345
const SEED_B := 99999


## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 그래서 남은 단언이 조용히 사라져도 러너에는 PASS로 보인다 — 실제로 겪었다.
## 하한을 못박아 두면 그런 유실이 실패로 드러난다.
## 단언을 **추가**할 때는 손댈 필요 없고, 의도적으로 **줄일** 때만 함께 낮춘다.
const MIN_ASSERTIONS := 181


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return

	_test_trap_definition_is_fixed(t, def)
	_test_lethal_traps_have_clues(t, def)
	_test_points_have_no_tier_hint(t, def)
	_test_points_are_walkable(t, def)
	_test_population_is_deterministic(t, def)
	_test_seed_changes_contents_not_terrain(t, def)
	_test_trap_one_shot(t, def)
	_test_weapon_quality_rule(t)
	t.done()


## `FLR-001` / `D-012` 정정 — 함정의 위치·종류·구조는 고정 정의에 있다.
func _test_trap_definition_is_fixed(t: TestCase, def: FloorDefinition) -> void:
	t.assert_true(def.traps.size() > 0, "함정 정의가 있어야 한다")
	for trap in def.traps:
		t.assert_true(trap.has("type") and trap["type"] != &"",
			"함정 `%s` 에 종류가 있어야 한다 (고정 정의)" % trap["id"])

	# 상태에는 타입이 없어야 한다 — 있으면 시드가 종류를 정할 수 있게 된다
	var state := FloorPopulator.populate(def, SEED_A)
	for trap_id in state.trap_states:
		var st: Dictionary = state.trap_states[trap_id]
		t.assert_true(not st.has("type"),
			"함정 런타임 상태에 종류가 있으면 안 된다 (`%s`) — 종류는 고정이다" % trap_id)
		t.assert_true(not st.has("clues"),
			"함정 런타임 상태에 단서가 있으면 안 된다 (`%s`) — 단서도 고정이다" % trap_id)


## ★ 3-1 — 치명 함정의 `clues[]`가 비면 실패. (`FLR-011`)
func _test_lethal_traps_have_clues(t: TestCase, def: FloorDefinition) -> void:
	for trap in def.traps:
		if not bool(trap["lethal"]):
			continue
		var clues: Array = trap["clues"]
		t.assert_true(clues.size() > 0,
			"치명 함정 `%s` 에 사전 단서가 있어야 한다 (FLR-011)" % trap["id"])
		for c in clues:
			t.assert_true(String(c).strip_edges().length() > 0,
				"치명 함정 `%s` 의 단서가 비어 있으면 안 된다" % trap["id"])


## `D-016` — 파밍 지점에 등급 힌트를 두지 않는다.
func _test_points_have_no_tier_hint(t: TestCase, def: FloorDefinition) -> void:
	for p in def.loot_points:
		t.assert_true(not p.has("tier_hint"),
			"파밍 지점 `%s` 에 tier_hint가 있으면 안 된다 (D-016)" % p["id"])
		t.assert_eq(p.keys().size(), 2,
			"파밍 지점 `%s` 은 id와 cell만 가져야 한다" % p["id"])


## 함정·파밍·스폰이 벽 안에 있으면 영원히 닿을 수 없다.
func _test_points_are_walkable(t: TestCase, def: FloorDefinition) -> void:
	for trap in def.traps:
		t.assert_true(def.is_walkable(trap["cell"]),
			"함정 `%s` 이 통행 가능한 칸에 있어야 한다" % trap["id"])
	for p in def.loot_points:
		t.assert_true(def.is_walkable(p["cell"]),
			"파밍 지점 `%s` 이 통행 가능한 칸에 있어야 한다" % p["id"])
	for p in def.spawn_points:
		t.assert_true(def.is_walkable(p["cell"]),
			"스폰 지점 `%s` 이 통행 가능한 칸에 있어야 한다" % p["id"])


## ★ 2-3 — 같은 시드면 같은 결과. 재로드해도 배치가 달라지면 안 된다.
func _test_population_is_deterministic(t: TestCase, def: FloorDefinition) -> void:
	var a := FloorPopulator.populate(def, SEED_A)
	var b := FloorPopulator.populate(def, SEED_A)

	t.assert_eq(a.to_save_dict().hash(), b.to_save_dict().hash(),
		"같은 시드면 실체화 결과가 완전히 같아야 한다 (2-3)")

	for pid in a.loot:
		t.assert_eq(a.loot[pid]["item_id"], b.loot[pid]["item_id"],
			"파밍 지점 `%s` 내용물이 같아야 한다" % pid)


## `FLR-002` — 시드는 내용물만 바꾼다. 지형·함정 정의는 건드리지 않는다.
func _test_seed_changes_contents_not_terrain(t: TestCase, def: FloorDefinition) -> void:
	var a := FloorPopulator.populate(def, SEED_A)
	var b := FloorPopulator.populate(def, SEED_B)

	# 지형·정의 해시는 시드와 무관
	t.assert_eq(a.definition_hash, b.definition_hash,
		"시드가 달라도 정의 해시는 같아야 한다 (FLR-001)")

	# 내용물은 달라져야 한다 — 안 달라지면 시드가 아무것도 안 하는 것이다
	var differing := 0
	for pid in a.loot:
		if a.loot[pid]["item_id"] != b.loot[pid]["item_id"]:
			differing += 1
	t.assert_true(differing > 0,
		"시드가 다르면 파밍 내용물이 달라져야 한다 (실제 차이 %d/%d)" % [differing, a.loot.size()])


## `FLR-012` — 발사형 함정은 한 번 소모되면 재충전되지 않는다.
func _test_trap_one_shot(t: TestCase, def: FloorDefinition) -> void:
	var state := FloorPopulator.populate(def, SEED_A)

	var one_shot_trap: Dictionary = {}
	var repeating_trap: Dictionary = {}
	for trap in def.traps:
		if bool(trap["one_shot"]) and one_shot_trap.is_empty():
			one_shot_trap = trap
		elif not bool(trap["one_shot"]) and repeating_trap.is_empty():
			repeating_trap = trap

	t.assert_true(not one_shot_trap.is_empty(), "발사형 함정이 하나는 있어야 한다")
	t.assert_true(state.trap_is_armed(one_shot_trap["id"]), "처음엔 활성 상태")
	state.fire_trap(one_shot_trap["id"], true)
	t.assert_true(state.trap_has_fired(one_shot_trap["id"]), "발동 기록이 남아야 한다")
	t.assert_true(not state.trap_is_armed(one_shot_trap["id"]),
		"발사형은 소모 후 재충전되지 않는다 (FLR-012)")

	# 낙하 같은 비발사형은 계속 위험해야 한다
	t.assert_true(not repeating_trap.is_empty(), "비발사형 함정도 하나는 있어야 한다")
	state.fire_trap(repeating_trap["id"], false)
	t.assert_true(state.trap_is_armed(repeating_trap["id"]),
		"비발사형은 발동 후에도 활성이어야 한다")


## ★ `D-020` / `FLR-014` — 1층 스폰 무기는 대체로 초기 대거보다 낫다.
func _test_weapon_quality_rule(t: TestCase) -> void:
	var dagger := FloorPopulator.starting_weapon_value()
	t.assert_true(dagger > 0, "초기 대거 기준값이 있어야 한다")

	var weapons := 0
	var better := 0
	var has_crossbow := false
	var has_firearm := false
	for e in FloorPopulator.loot_table_entries():
		var kind := String(e["kind"])
		if kind == "weapon" or kind == "ranged":
			weapons += 1
			if int(e["combat_value"]) > dagger:
				better += 1
		if String(e["id"]).contains("crossbow"):
			has_crossbow = true
		if String(e["id"]).contains("gun") or String(e["id"]).contains("firearm"):
			has_firearm = true

	t.assert_true(weapons > 0, "무기 항목이 있어야 한다")
	t.assert_eq(better, weapons,
		"1층 스폰 무기는 **전부** 초기 대거보다 나아야 한다 (D-020) — %d/%d" % [better, weapons])
	# FLR-014: 투사무기 상한은 석궁 수준, 총기는 극저확률
	t.assert_true(has_crossbow, "투사무기 상한인 석궁이 풀에 있어야 한다 (FLR-014)")
	t.assert_true(not has_firearm,
		"총기는 극저확률이므로 1층 기본 풀에 두지 않는다 (FLR-014)")
