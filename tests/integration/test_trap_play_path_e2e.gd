extends RefCounted
## `P3-REV-005` — **실제 게임 경로**로 함정이 발동하는가. (`FLR-028` `FLR-011`)
##
## ## 이 파일이 존재하는 이유
## `test_traps.gd`는 `TrapRuntime`을 직접 불러 검사한다. 그래서 **runtime은 멀쩡한데
## 게임이 그 runtime에게 잘못된 자극을 보내는 버그**를 못 잡는다.
##
## 실제로 그 버그가 있었다:
##   - `floor1`의 `wall_bolt`는 `accepts = ["touch", "impact"]`
##   - `main._check_trap_underfoot()`는 `from_body()`(= `PRESSURE`)만 보냈다
##   - → **미발동 벽 화살 함정 위를 플레이어가 걸어도 아무 일도 일어나지 않았다**
##   - `test_traps.gd`는 `from_thrown()`(= `IMPACT`)으로만 검사해서 전부 통과했다
##
## 그래서 이 테스트는 우회로 없이 **진짜 경로**를 통과한다:
##   `Main.tscn` 로드 → `Input.action_press()` → `Player._physics_process()`
##   → `Main._check_trap_underfoot()` → `TrapRuntime` → `FloorState.fire_trap()`

const MAIN_SCENE := "res://scenes/world/Main.tscn"
const CELL := 32
## 한 칸을 걸어 들어가기에 넉넉한 프레임 수. 속도 160px/s, 칸 32px.
const WALK_FRAMES := 40


func run(tree: SceneTree, t: TestCase) -> void:
	var main: Node2D = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame

	var def: FloorDefinition = main._floor_def
	var state: FloorState = main._floor_state
	var player: CharacterBody2D = main._player
	t.assert_true(def != null and state != null, "Main이 층을 로드해야 한다")
	if def == null or state == null:
		main.queue_free()
		return

	await _test_walk_into_wall_bolt(tree, t, main, def, state, player)
	await _test_no_double_fire_on_single_entry(tree, t, main, def, state, player)

	main.queue_free()
	await tree.physics_frame


## ★ 미발동 `wall_bolt` → 실제 플레이어 이동 → 발동.
func _test_walk_into_wall_bolt(tree: SceneTree, t: TestCase, main: Node2D,
		def: FloorDefinition, state: FloorState, player: CharacterBody2D) -> void:
	var trap := _find_walkable_trap(def, &"wall_bolt")
	t.assert_true(not trap.is_empty(), "테스트 전제: 접근 가능한 wall_bolt 함정이 있어야 한다")
	if trap.is_empty():
		return

	var cell: Vector2i = trap["cell"]
	t.assert_true(state.trap_is_armed(trap["id"]), "테스트 전제: 함정이 무장 상태여야 한다")
	t.assert_true(not state.trap_has_fired(trap["id"]), "테스트 전제: 아직 발동 전이어야 한다")

	# 함정 칸 **왼쪽**에 세우고 오른쪽으로 걸어 들어간다.
	var from := cell + Vector2i(-1, 0)
	t.assert_true(def.is_walkable(from), "테스트 전제: 진입 칸이 통행 가능해야 한다")
	_place(player, from)
	# 진입을 실제 이동으로 만들기 위해 판정 캐시를 진입 칸으로 맞춘다.
	main._last_trap_cell = from
	await tree.physics_frame

	Input.action_press("move_right")
	var reached := false
	for i in WALK_FRAMES:
		await tree.physics_frame
		if _cell_of(player) == cell:
			reached = true
			break
	Input.action_release("move_right")
	await tree.physics_frame

	# 테스트가 헛돌지 않았는지 — 실제로 함정 칸에 들어갔어야 한다.
	t.assert_true(reached,
		"테스트 전제: 플레이어가 함정 칸 %v 에 실제로 도달해야 한다 (현재 %v)"
		% [cell, _cell_of(player)])
	if not reached:
		return

	t.assert_true(state.trap_has_fired(trap["id"]),
		"걸어 들어간 것만으로 wall_bolt가 발동해야 한다 (P3-REV-005) — 함정 `%s`" % trap["id"])
	t.assert_true(not state.trap_is_armed(trap["id"]),
		"발사형은 발동 후 무장이 풀려야 한다 (FLR-012)")


## 한 번 들어갔는데 두 번 터지면 안 된다 (`P3-REV-005`).
##
## 몸이 칸에 들어가면 압력과 접촉이 **동시에** 생긴다. 둘 다 받는 함정에 그냥
## 순서대로 적용하면 한 번의 진입이 두 번의 발동이 된다.
func _test_no_double_fire_on_single_entry(tree: SceneTree, t: TestCase, main: Node2D,
		def: FloorDefinition, state: FloorState, player: CharacterBody2D) -> void:
	# 압력과 접촉을 **모두** 받는 가상의 반복형 함정으로 검사한다.
	var trap := {
		"id": &"probe_repeating",
		"cell": Vector2i(0, 0),
		"type": &"probe",
		"lethal": false,
		"one_shot": false,
		"clues": ["표식"],
		"accepts": ["pressure", "touch"],
		"min_mass": 1.0,
	}
	var probe_def := FloorDefinitionLoader.build({
		"floor_id": "probe", "theme_id": "t", "world_id": "w", "world_region_ref": "r",
		"rooms": [{"id": "r", "rect": [0, 0, 6, 6], "tags": []}],
		"start_points": [[1, 1]],
		"traps": [{"id": "probe_repeating", "cell": [3, 3], "type": "pitfall",
			"lethal": false, "one_shot": false, "clues": ["표식"],
			"accepts": ["pressure", "touch"], "min_mass": 1.0}],
	})
	var probe_state := FloorPopulator.populate(probe_def, 1)
	var target: Dictionary = probe_def.traps[0]

	var stimuli := TrapStimulus.from_body_entering(target["cell"], 70.0, &"player")
	t.assert_eq(stimuli.size(), 2, "한 번의 진입은 압력과 접촉 두 자극을 만든다")

	var fired := TrapRuntime.apply_all(probe_def, probe_state, stimuli)
	t.assert_eq(fired.size(), 1,
		"한 번 들어갔으면 한 번만 발동해야 한다 (발동 %d회)" % fired.size())
	t.assert_true(probe_state.trap_has_fired(target["id"]), "발동은 실제로 일어나야 한다")
	t.assert_true(probe_state.trap_is_armed(target["id"]),
		"반복형이므로 여전히 무장 상태여야 한다")


## 사방이 통행 가능해 걸어 들어갈 수 있는 함정을 찾는다.
func _find_walkable_trap(def: FloorDefinition, type_name: StringName) -> Dictionary:
	for trap in def.traps:
		if trap["type"] != type_name:
			continue
		var cell: Vector2i = trap["cell"]
		if def.is_walkable(cell) and def.is_walkable(cell + Vector2i(-1, 0)):
			return trap
	return {}


func _place(player: CharacterBody2D, cell: Vector2i) -> void:
	player.global_position = Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)


func _cell_of(player: CharacterBody2D) -> Vector2i:
	return Vector2i(
		floori(player.global_position.x / CELL),
		floori(player.global_position.y / CELL))
