class_name FloorPopulator
extends RefCounted
## 시드로 `FloorState`를 실체화한다. (`FLR-002` · `SYS-003`)
##
## ## 무엇을 시드가 정하는가
## 전리품 내용물 · 유배자 스폰 · 함정의 활성 상태, 그리고 **이번 회차의 시작 위치**(`D-022`)다.
## **지형과 함정의 위치·종류·구조는 시드와 무관하다** (`FLR-001`).
##
## 시작 위치는 고정 후보표에서 고르는 것이라 지형을 바꾸지 않는다.
## 계단 배치와 섞이지 않도록 **독립 RNG 스트림**을 쓴다 — 그러지 않으면 후보를
## 하나 더 넣는 것만으로 기존 회차의 전리품·계단이 전부 어긋난다.
##
## ## 결정성 규칙
## 1. **전역 RNG를 쓰지 않는다.** `RandomNumberGenerator`에 시드를 넣어 쓴다.
##    가드 테스트가 `randi()` 등을 금지한다 (`SYS-003`).
## 2. **소비 순서를 고정한다.** 정의의 배열 순서대로 돌며, 각 지점마다
##    `(seed, point_id)`로 만든 **독립 스트림**을 쓴다.
##    하나의 RNG를 순서대로 쓰면 나중에 지점을 하나 추가했을 때 그 뒤 전부가 달라진다 —
##    `D-014` G-5가 NPC LOD에서 요구한 것과 같은 이유다.
## 3. 결과가 진실이다. 로드할 때 이 함수를 다시 부르지 않는다.

const LOOT_TABLE_PATH := "res://data/items/floor1_loot_table.json"


static func populate(def: FloorDefinition, generation_seed: int) -> FloorState:
	var state := FloorState.new()
	state.floor_id = def.floor_id
	state.generation_seed = generation_seed
	state.definition_hash = def.definition_hash
	state.layout_version = def.layout_version

	# 시작 위치 (`D-022`). 후보는 고정이고 어느 것을 쓰느냐가 시드의 몫이다.
	# 계단과 **다른 스트림**을 쓴다 — 같은 스트림이면 시작점을 하나 늘렸을 때
	# 계단 위치까지 통째로 달라진다.
	if not def.start_points.is_empty():
		var srng := _stream(generation_seed, "start", def.floor_id)
		state.start_cell = def.start_points[srng.randi_range(0, def.start_points.size() - 1)]

	# 함정 — 위치·종류는 고정이고 여기서 정하는 것은 **초기 상태**뿐이다.
	for trap in def.traps:
		state.trap_states[trap["id"]] = {"armed": true, "fired": false}

	var table := _load_loot_table()
	for point in def.loot_points:
		var rng := _stream(generation_seed, "loot", point["id"])
		state.loot[point["id"]] = _roll_loot(rng, table)

	for point in def.spawn_points:
		var rng := _stream(generation_seed, "spawn", point["id"])
		# PHASE 2는 자리만 잡는다. 실제 유배자 생성 규칙은 `CHR-010` TBD다 —
		# 임의로 만들지 않는다.
		state.spawns[point["id"]] = {
			"npc_id": StringName("exile_%s_%d" % [point["id"], rng.randi() % 100000]),
			"alive": true,
		}

	return state


## 지점마다 독립 스트림. 지점을 추가·제거해도 다른 지점의 결과가 흔들리지 않는다.
static func _stream(base_seed: int, kind: String, point_id: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d/%s/%s" % [base_seed, kind, point_id])
	return rng


static func _roll_loot(rng: RandomNumberGenerator, table: Array) -> Dictionary:
	if table.is_empty():
		return {"item_id": &"", "kind": &"", "durability": &"", "looted": false}

	var total := 0
	for e in table:
		total += int(e["weight"])
	var pick := rng.randi_range(0, total - 1)
	for e in table:
		pick -= int(e["weight"])
		if pick < 0:
			return {
				"item_id": StringName(e["id"]),
				"kind": StringName(e["kind"]),
				"durability": StringName(e["durability"]),
				"looted": false,
			}
	var last: Dictionary = table[table.size() - 1]
	return {
		"item_id": StringName(last["id"]),
		"kind": StringName(last["kind"]),
		"durability": StringName(last["durability"]),
		"looted": false,
	}


static func _load_loot_table() -> Array:
	var f := FileAccess.open(LOOT_TABLE_PATH, FileAccess.READ)
	if f == null:
		push_error("파밍 테이블을 열 수 없다: %s" % LOOT_TABLE_PATH)
		return []
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("파밍 테이블 파싱 실패")
		return []
	return (parsed as Dictionary).get("entries", [])


## `D-020` 검증용 — 초기 대거의 비교 기준값.
static func starting_weapon_value() -> int:
	var f := FileAccess.open(LOOT_TABLE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int(((parsed as Dictionary).get("reference_starting_weapon", {}) as Dictionary).get("combat_value", 0))


static func loot_table_entries() -> Array:
	return _load_loot_table()
