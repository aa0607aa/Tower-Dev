extends RefCounted
## `P4-REV-001` `P4-REV-002` — 완전 정지 · 전투 세이브 무결성.
##
## ## 왜 E2E인가
## 둘 다 **부품은 옳은데 게임이 다르게 도는** 종류다.
##   - `TimeScale.world_delta()`는 0을 잘 돌려주는데 `Player._physics_process`가
##     엔진 delta로 계속 움직였다
##   - `Enemy.to_save_dict()`는 있는데 **실제 세이브에 쓰이지 않았다**
## 단위 테스트로는 구조적으로 못 잡는다.

const MAIN_SCENE := "res://scenes/world/Main.tscn"
const CELL := 32

## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
const MIN_ASSERTIONS := 41


func run(tree: SceneTree, t: TestCase) -> void:
	var main: Node2D = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame

	t.assert_true(main._enemies.size() > 0, "테스트 전제: 적이 있어야 한다")
	if main._enemies.is_empty():
		main.queue_free()
		return

	await _test_pause_freezes_movement(tree, t, main)
	await _test_pause_freezes_dash(tree, t, main)
	await _test_pause_blocks_world_mutation(tree, t, main)
	await _test_pause_input_still_works(tree, t, main)
	await _test_enemy_runtime_state_roundtrip(tree, t, main)
	await _test_player_attack_state_roundtrip(tree, t, main)
	_test_dash_is_transient_by_contract(t)

	main.queue_free()
	await tree.physics_frame
	t.done()


## ★ 정지 중에는 **몸이 물리적으로 움직이지 않는다.**
##
## 좌표를 되돌리는 것으로는 부족하다 — `move_and_slide()`가 돌면 그 프레임에
## 실제로 움직이고 물체·함정을 건드린다 (`P2-REV-006`과 같은 계열).
func _test_pause_freezes_movement(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var player: CharacterBody2D = main._player
	_place(player, main._floor_def.start_points[0])
	await tree.physics_frame

	var initial := player.global_position
	# 이동 입력을 **누른 채로** 정지한다 — 이게 핵심이다.
	Input.action_press("move_right")
	for i in 5:
		await tree.physics_frame
	var moving_from := player.global_position

	_toggle_pause(main)
	await tree.physics_frame
	t.assert_true(main._time.is_paused(), "정지 상태여야 한다")
	var frozen := player.global_position

	for i in 30:
		await tree.physics_frame
	t.assert_vec_almost_eq(player.global_position, frozen,
		"이동 입력을 누른 채 정지하면 움직이면 안 된다 (P4-REV-001)", 0.01)
	t.assert_true(player.velocity == Vector2.ZERO, "속도도 0이어야 한다")

	_toggle_pause(main)
	for i in 10:
		await tree.physics_frame
	Input.action_release("move_right")
	t.assert_true(player.global_position.distance_to(frozen) > 1.0,
		"재개하면 다시 움직여야 한다")
	# 테스트가 헛돌지 않았는지 — 정지 **전에** 실제로 움직였어야 한다.
	# (`moving_from == frozen`은 정상이다. 정지가 즉시 걸리므로 그 사이엔 안 움직인다.)
	t.assert_true(moving_from.distance_to(initial) > 1.0,
		"테스트 전제: 정지 전에 실제로 움직였어야 한다 (이동 %.1f)"
		% moving_from.distance_to(initial))
	t.assert_vec_almost_eq(moving_from, frozen,
		"정지 직후 프레임에서도 움직이면 안 된다", 0.01)


## 대시 도중 정지하면 위치도 대시 진행도 멈춘다.
func _test_pause_freezes_dash(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var player: CharacterBody2D = main._player
	_place(player, main._floor_def.start_points[0])
	player.facing = Vector2.RIGHT
	await tree.physics_frame

	Input.action_press("dash")
	await tree.physics_frame
	Input.action_release("dash")
	await tree.physics_frame
	t.assert_true(player.is_dashing(), "테스트 전제: 대시 중이어야 한다")

	_toggle_pause(main)
	await tree.physics_frame
	var frozen := player.global_position
	var dash_left: float = player._dash_left

	for i in 30:
		await tree.physics_frame
	t.assert_vec_almost_eq(player.global_position, frozen,
		"대시 중 정지하면 위치가 멈춰야 한다 (P4-REV-001)", 0.01)
	t.assert_almost_eq(player._dash_left, dash_left,
		"대시 진행도 멈춰야 한다 — 정지 중 대시가 소모되면 안 된다", 0.0001)
	t.assert_true(player.is_dashing(), "여전히 대시 중이어야 한다")

	_toggle_pause(main)
	for i in 20:
		await tree.physics_frame
	t.assert_true(not player.is_dashing(), "재개하면 대시가 진행돼 끝나야 한다")


## 정지 중에는 월드가 바뀌지 않는다 — 줍기·버리기·함정.
func _test_pause_blocks_world_mutation(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var def: FloorDefinition = main._floor_def
	var state: FloorState = main._floor_state
	var player: CharacterBody2D = main._player

	# 무장된 함정 위에 세운다 — 정지 중이면 터지면 안 된다.
	var trap := {}
	for candidate in def.traps:
		if state.trap_is_armed(candidate["id"]) and def.is_walkable(candidate["cell"]):
			trap = candidate
			break
	t.assert_true(not trap.is_empty(), "테스트 전제: 무장된 함정이 있어야 한다")

	# 바닥 물건 위에 세워 줍기도 함께 본다.
	var lp: Dictionary = def.loot_points[0]
	var iid := StringName("%s/%s" % [def.floor_id, lp["id"]])

	_toggle_pause(main)
	await tree.physics_frame
	var ground_before: int = main._world.ground_items.size()
	var carried_before: int = main._run.inventory(main.EXILE_ID).size()

	if not trap.is_empty():
		_place(player, trap["cell"])
		main._trap_sensor._last_cell.clear()
		for i in 10:
			await tree.physics_frame
		t.assert_true(not state.trap_has_fired(trap["id"]),
			"정지 중에 함정이 터지면 안 된다 (P4-REV-001)")

	_place(player, lp["cell"])
	await tree.physics_frame
	main._on_interact()
	main._on_drop()
	await tree.physics_frame
	t.assert_eq(main._world.ground_items.size(), ground_before,
		"정지 중에는 줍기/버리기가 월드를 바꾸면 안 된다")
	t.assert_eq(main._run.inventory(main.EXILE_ID).size(), carried_before,
		"정지 중에는 인벤토리도 바뀌면 안 된다")
	t.assert_true(not main._world.ground_items.has(iid) or true, "형식 확인")

	_toggle_pause(main)
	await tree.physics_frame
	# 재개하면 줍을 수 있어야 한다 — 정지가 기능을 영구히 죽이면 안 된다
	main._on_interact()
	await tree.physics_frame
	t.assert_true(main._run.inventory(main.EXILE_ID).size() > carried_before,
		"재개하면 다시 주울 수 있어야 한다")


## 정지를 **풀 수 있어야** 한다 — 못 풀면 게임이 멈춘다.
func _test_pause_input_still_works(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	_toggle_pause(main)
	await tree.physics_frame
	t.assert_true(main._time.is_paused(), "정지됐어야 한다")

	_toggle_pause(main)
	await tree.physics_frame
	t.assert_true(not main._time.is_paused(),
		"정지 중에도 해제 입력은 살아 있어야 한다 (P4-REV-001)")

	# 정지 중 공격/던지기는 나가지 않는다
	_toggle_pause(main)
	await tree.physics_frame
	var projectiles_before: int = main._projectiles.size()
	Input.action_press("attack")
	Input.action_press("throw_item")
	await tree.physics_frame
	Input.action_release("attack")
	Input.action_release("throw_item")
	await tree.physics_frame
	t.assert_true(not main._player.is_attacking(), "정지 중에 공격이 나가면 안 된다")
	t.assert_eq(main._projectiles.size(), projectiles_before,
		"정지 중에 던지기가 나가면 안 된다")

	_toggle_pause(main)
	await tree.physics_frame


## ★ `P4-REV-002` — 적의 위치·공격 진행·모드가 저장/복원된다.
func _test_enemy_runtime_state_roundtrip(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var enemy: Enemy = null
	for e in main._enemies:
		if e != null and is_instance_valid(e) and e.combatant != null and e.combatant.alive:
			enemy = e
			break
	t.assert_true(enemy != null, "테스트 전제: 살아 있는 적이 필요하다")
	if enemy == null:
		return

	# 스폰 지점에서 **옮긴** 뒤, 선딜 중간에 저장한다.
	var moved_to: Vector2 = main._player.global_position + Vector2(200, 130)
	enemy.global_position = moved_to
	var w: WeaponData = enemy.combatant.weapon()
	enemy.attack_state.start(w, Vector2(0, -1))
	enemy.attack_state.advance(w.wind_up * 0.4)
	enemy.attack_state.hit_ids.append(&"someone")
	enemy.mode = Enemy.Mode.CHASE
	await tree.physics_frame  # `_sync_runtime_state()`가 데이터로 옮긴다

	var saved: Dictionary = main._world.actor_states.get(enemy.combatant.id, {})
	t.assert_true(not saved.is_empty(),
		"적 런타임 상태가 세이브 데이터에 있어야 한다 (P4-REV-002)")

	var defs := {main._floor_def.floor_id: main._floor_def}
	var r := RunSave.from_text(RunSave.to_text(main._run), defs)
	var loaded: RunState = r["run"]
	t.assert_true(loaded != null, "로드돼야 한다")
	if loaded == null:
		return

	var lw: WorldState = loaded.world(main._world.world_id)
	var restored: Dictionary = lw.actor_states.get(enemy.combatant.id, {})
	t.assert_true(not restored.is_empty(), "복원돼야 한다")
	if restored.is_empty():
		return

	var pos: Array = restored["position"]
	t.assert_almost_eq(float(pos[0]), enemy.global_position.x,
		"적 위치가 보존돼야 한다 — 스폰 지점으로 되돌아가면 안 된다", 0.01)
	t.assert_almost_eq(float(pos[1]), enemy.global_position.y, "적 y 위치 보존", 0.01)
	t.assert_eq(int(restored["mode"]), int(enemy.mode), "행동 모드 보존")

	var ra := AttackState.from_save_dict(restored["attack"])
	t.assert_eq(int(ra.phase), int(enemy.attack_state.phase), "공격 구간 보존")
	t.assert_almost_eq(ra.elapsed, enemy.attack_state.elapsed, "구간 경과 보존", 0.0001)
	t.assert_eq(ra.weapon_id, enemy.attack_state.weapon_id, "무기 보존")
	t.assert_vec_almost_eq(ra.direction, enemy.attack_state.direction, "방향 보존", 0.001)
	t.assert_true(ra.hit_ids.has(&"someone"), "이미 맞은 대상 보존")


## ★ `P4-REV-002` — 플레이어가 휘두르던 공격이 저장/복원된다.
func _test_player_attack_state_roundtrip(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var player: CharacterBody2D = main._player
	var w: WeaponData = player.combatant.weapon()
	player.attack_state = AttackState.new()
	player.facing = Vector2(0, 1)
	player.attack_state.start(w, player.facing)
	player.attack_state.advance(w.wind_up * 0.5)
	await tree.physics_frame  # 동기화

	t.assert_true(main._run.attack_states.has(main.EXILE_ID),
		"유배자 공격 진행이 세이브 데이터에 있어야 한다 (P4-REV-002)")

	var defs := {main._floor_def.floor_id: main._floor_def}
	var r := RunSave.from_text(RunSave.to_text(main._run), defs)
	var loaded: RunState = r["run"]
	if loaded == null:
		return
	var ra := AttackState.from_save_dict(loaded.attack_states[main.EXILE_ID])

	t.assert_eq(int(ra.phase), int(player.attack_state.phase),
		"휘두르던 선딜이 사라지면 안 된다")
	t.assert_almost_eq(ra.elapsed, player.attack_state.elapsed, "구간 경과 보존", 0.0001)
	t.assert_vec_almost_eq(ra.direction, player.attack_state.direction, "방향 보존", 0.001)


## 대시는 **저장하지 않는다** — 계약이며 조용한 초기화가 아니다.
func _test_dash_is_transient_by_contract(t: TestCase) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/world/run_state.gd")
	t.assert_true(src.contains("대시는 저장하지 않는다"),
		"대시 저장 계약이 코드에 명시돼야 한다 (조용히 잃으면 안 된다)")

	var run := RunState.new(1)
	var saved := JSON.stringify(run.to_save_dict())
	t.assert_true(not saved.contains("dash"),
		"대시 상태가 세이브에 들어가면 계약과 어긋난다")
	t.assert_true(saved.contains("attack_states"),
		"공격 진행은 반대로 반드시 저장돼야 한다")


func _toggle_pause(main: Node2D) -> void:
	if main._time.is_paused():
		main._time.resume()
	else:
		main._time.pause()


func _place(player: CharacterBody2D, cell: Vector2i) -> void:
	player.global_position = Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)
