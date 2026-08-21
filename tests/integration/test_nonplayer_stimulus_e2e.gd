extends RefCounted
## `P3-REV-008` — **비플레이어 물체**가 production 경로로 함정을 발동시킨다. (`FLR-028`)
##
## ## 이 파일이 존재하는 이유
## `P3-T5`의 완료 조건은 "정상 메커니즘을 만족하는 **비플레이어 물리 자극**으로도
## 발동 가능한 E2E"였다. 그런데 `test_traps.gd`는 `TrapStimulus`를 손으로 만들어
## `TrapRuntime`에 바로 넣는 **runtime 단위 검증**이었다.
##
## 그래서 "runtime은 옳은데 게임에 그 경로가 아예 없는" 상태를 못 잡았다 —
## 실제로 production에는 플레이어 몸이 걸어 들어가는 경로 **하나뿐**이었다.
## `FLR-028`의 "돌을 던져 벽 화살 함정을 먼저 터뜨리는 공략"이 게임에 존재하지 않았다.
##
## 이 테스트는 **`TrapSensor` 어댑터**(production 코드)를 통과한다.
## 물체는 테스트가 만들지만, **자극을 만드는 코드는 게임이 쓰는 것과 같은 것**이다.
##
## ## 여기서 하지 않는 것
## 던지기 입력·투사체 비행·전투는 `PHASE 4`다. 물체는 "움직이다 멈췄다"는
## 물리 사실만 어댑터에 전달한다.

const MAIN_SCENE := "res://scenes/world/Main.tscn"
const CELL := 32
## 돌 하나의 질량(kg). `wall_bolt`의 `min_mass`(0.3)보다 무겁고 `pitfall`(25)보다 가볍다.
## **DESIGN이며 canon 아님.**
const STONE_MASS := 0.5

## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 하한을 못박아 두면 그렇게 사라진 단언이 실패로 드러난다.
const MIN_ASSERTIONS := 23


func run(tree: SceneTree, t: TestCase) -> void:
	var main: Node2D = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame

	var def: FloorDefinition = main._floor_def
	var state: FloorState = main._floor_state
	var sensor: TrapSensor = main._trap_sensor
	var envelope: AccessEnvelope = main._player.access_envelope

	t.assert_true(def != null and state != null, "Main이 층을 로드해야 한다")
	t.assert_true(sensor != null, "Main이 TrapSensor 어댑터를 들고 있어야 한다")
	if def == null or state == null or sensor == null:
		main.queue_free()
		return

	_test_thrown_stone_fires_wall_bolt(t, def, state, sensor)
	_test_stone_does_not_break_floor(t, def, state, sensor)
	_test_envelope_blocks_thrown_stone(t, def, state, envelope)
	_test_independent_object_crosses_envelope(t, def, envelope)
	_test_impact_also_touches(t)
	_test_player_and_object_share_adapter(t)

	main.queue_free()
	await tree.physics_frame
	t.done()


## ★★ 던진 돌이 **어댑터를 통해** 벽 화살 함정을 터뜨린다 (`FLR-028` 원작 사례).
func _test_thrown_stone_fires_wall_bolt(t: TestCase, def: FloorDefinition,
		state: FloorState, sensor: TrapSensor) -> void:
	var bolt := _find_trap(def, &"wall_bolt")
	t.assert_true(not bolt.is_empty(), "테스트 전제: wall_bolt 함정이 있어야 한다")
	if bolt.is_empty():
		return
	t.assert_true(state.trap_is_armed(bolt["id"]), "테스트 전제: 무장 상태여야 한다")

	# 유배자가 던진 돌이 함정 칸에서 멈췄다 — 물리 사실만 전달한다.
	var stone := _stone_at(bolt["cell"])
	var fired := sensor.sense_impact(
		stone, STONE_MASS, CausalSource.new(&"player", CausalSource.Kind.THROWN))

	t.assert_true(fired.has(bolt["id"]),
		"던진 돌이 어댑터를 통해 벽 화살 함정을 발동시켜야 한다 (P3-REV-008 · FLR-028)")
	t.assert_true(state.trap_has_fired(bolt["id"]), "발동이 상태에 남아야 한다")
	t.assert_true(not state.trap_is_armed(bolt["id"]), "발사형은 무장이 풀려야 한다 (FLR-012)")

	# ★ 공략이 성립해야 한다 — 먼저 터뜨렸으니 이제 지나가도 안전하다.
	var walk := sensor.sense_body(&"probe_walker",
		_stone_at(bolt["cell"]), 70.0,
		CausalSource.new(&"player", CausalSource.Kind.BODY))
	t.assert_true(walk.is_empty(),
		"먼저 터뜨린 뒤에는 지나가도 발동하지 않아야 한다 — 공략이 성립해야 한다")


## 가벼운 돌은 함정 바닥을 무너뜨리지 못한다 — 모든 함정이 모든 것에 반응하지 않는다.
func _test_stone_does_not_break_floor(t: TestCase, def: FloorDefinition,
		state: FloorState, sensor: TrapSensor) -> void:
	var pit := _find_trap(def, &"pitfall")
	t.assert_true(not pit.is_empty(), "테스트 전제: pitfall 함정이 있어야 한다")
	if pit.is_empty():
		return

	var fired := sensor.sense_impact(_stone_at(pit["cell"]), STONE_MASS,
		CausalSource.new(&"player", CausalSource.Kind.THROWN))
	t.assert_true(fired.is_empty(),
		"가벼운 돌이 함정 바닥을 무너뜨리면 안 된다 (min_mass 미달)")
	t.assert_true(not state.trap_has_fired(pit["id"]), "상태도 바뀌면 안 된다")


## 유배자가 던진 물체는 **행동 반경을 넘지 못한다** (`D-017` 4항 · `FLR-024`).
## 실제 경로(`TrapSensor` + 실제 envelope)로 검증한다.
func _test_envelope_blocks_thrown_stone(t: TestCase, def: FloorDefinition,
		state: FloorState, envelope: AccessEnvelope) -> void:
	var bolt := _find_second_trap(def, &"wall_bolt")
	t.assert_true(not bolt.is_empty(), "테스트 전제: 두 번째 wall_bolt가 있어야 한다")
	if bolt.is_empty():
		return

	# 그 칸만 경계 밖으로 만든다.
	var blocked := AccessService.envelope_from_floor(&"player", def)
	blocked.deny_cell(bolt["cell"])
	var sensor := TrapSensor.new(def, state, blocked)

	var fired := sensor.sense_impact(_stone_at(bolt["cell"]), STONE_MASS,
		CausalSource.new(&"player", CausalSource.Kind.THROWN))
	t.assert_true(fired.is_empty(),
		"유배자가 던진 돌은 경계 밖 함정을 건드릴 수 없어야 한다 (CausalSource.THROWN)")
	t.assert_true(not state.trap_has_fired(bolt["id"]), "상태도 바뀌면 안 된다")
	t.assert_true(state.trap_is_armed(bolt["id"]), "무장 상태가 유지돼야 한다")


## 반대로 **독립 시뮬레이션**(NPC·야생동물)은 유배자 경계에 막히지 않는다 (`FLR-023`).
func _test_independent_object_crosses_envelope(t: TestCase, def: FloorDefinition,
		envelope: AccessEnvelope) -> void:
	var pit := _find_trap(def, &"pitfall")
	if pit.is_empty():
		return

	var state := FloorPopulator.populate(def, 999)
	var blocked := AccessService.envelope_from_floor(&"player", def)
	blocked.deny_cell(pit["cell"])
	var sensor := TrapSensor.new(def, state, blocked)

	# 야생동물이 걸어 들어갔다 — 유배자 인과가 아니다.
	var fired := sensor.sense_body(&"beast", _stone_at(pit["cell"]), 60.0,
		CausalSource.new(CausalSource.NO_OWNER, CausalSource.Kind.INDEPENDENT))
	t.assert_true(fired.has(pit["id"]),
		"NPC·야생동물은 유배자 경계에 막히지 않아야 한다 (FLR-023)")
	t.assert_true(state.trap_has_fired(pit["id"]), "실제로 발동해야 한다")


## 부딪힌 물체는 때리기만 하는 것이 아니라 **닿기도** 한다.
##
## 실선(`touch`)만 감지하는 함정을 던진 돌이 건드릴 수 있어야 한다.
## `floor1`의 `wall_bolt`는 `impact`도 받으므로 이 성질이 가려진다 —
## 변이 테스트에서 `TOUCH`를 빼도 잡히지 않았다. 그래서 전용 함정으로 따로 본다.
func _test_impact_also_touches(t: TestCase) -> void:
	var probe := FloorDefinitionLoader.build({
		"floor_id": "probe", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
		"rooms": [{"id": "r", "rect": [0, 0, 6, 6], "tags": []}],
		"start_points": [[1, 1]],
		"traps": [{"id": "tripline_only", "cell": [3, 3], "type": "snare",
			"lethal": false, "one_shot": true, "clues": ["팽팽한 줄"],
			"accepts": ["touch"], "min_mass": 0.1}],
	})
	var state := FloorPopulator.populate(probe, 1)
	var sensor := TrapSensor.new(probe, state, null)
	var trap: Dictionary = probe.traps[0]
	t.assert_eq((trap["accepts"] as Array), ["touch"],
		"테스트 전제: 접촉만 감지하는 함정이어야 한다")

	var fired := sensor.sense_impact(_stone_at(trap["cell"]), STONE_MASS,
		CausalSource.new(&"player", CausalSource.Kind.THROWN))
	t.assert_true(fired.has(trap["id"]),
		"던진 돌은 때리면서 닿기도 한다 — 실선 감지 함정을 건드려야 한다")
	t.assert_true(state.trap_has_fired(trap["id"]), "실제로 발동해야 한다")


## ★ 플레이어와 물체가 **같은 어댑터**를 쓴다 — 경로가 갈라지면 한쪽만 틀어진다.
func _test_player_and_object_share_adapter(t: TestCase) -> void:
	var main_code := _code_only(FileAccess.get_file_as_string("res://scripts/core/main.gd"))
	t.assert_true(main_code.contains("_trap_sensor.sense_body"),
		"플레이어 진입도 어댑터를 거쳐야 한다 (P3-REV-008)")
	t.assert_true(not main_code.contains("TrapRuntime.apply"),
		"main이 TrapRuntime을 직접 부르면 경로가 둘로 갈라진다")
	t.assert_true(not main_code.contains("TrapStimulus.from_"),
		"main이 자극을 직접 만들면 어댑터를 우회하는 것이다")


func _find_trap(def: FloorDefinition, type_name: StringName) -> Dictionary:
	for trap in def.traps:
		if trap["type"] == type_name:
			return trap
	return {}


func _find_second_trap(def: FloorDefinition, type_name: StringName) -> Dictionary:
	var seen := 0
	for trap in def.traps:
		if trap["type"] == type_name:
			seen += 1
			if seen == 2:
				return trap
	return {}


## 칸 중앙의 월드 좌표. 어댑터는 셀이 아니라 **월드 좌표**를 받는다.
func _stone_at(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)


func _code_only(src: String) -> String:
	var out := ""
	for line in src.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		out += stripped + "\n"
	return out
