extends RefCounted
## `P4-T7` — **실제 공간 전투가 성립하는가.** (PHASE 4 완료 조건)
##
## ## 이 파일이 존재하는 이유
## `test_combat.gd`는 `CombatService`를 직접 부르는 단위 검증이다.
## `P3-REV-005`에서 배웠듯 **runtime은 옳은데 게임이 그걸 안 부르는** 버그를 못 잡는다.
##
## 그래서 여기서는 `Main.tscn`을 실제로 띄우고 **입력을 눌러** 검증한다:
##   `Input.action_press("attack")` → `Main._unhandled_input` → `Player.try_attack()`
##   → `Main._advance_combat()` → `CombatService` → `Combatant.apply_damage()`
##
## 전술 정지·대시·던지기도 같은 경로로 본다.

const MAIN_SCENE := "res://scenes/world/Main.tscn"
const CELL := 32

## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
const MIN_ASSERTIONS := 25


func run(tree: SceneTree, t: TestCase) -> void:
	var main: Node2D = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame

	var player0: CharacterBody2D = main._player
	t.assert_true(player0.combatant != null, "플레이어가 전투 상태를 가져야 한다")
	t.assert_true(main._enemies.size() > 0, "적이 배치돼야 한다 (테스트 전제)")
	if main._enemies.is_empty() or player0.combatant == null:
		main.queue_free()
		return

	await _test_attack_kills_enemy(tree, t, main)
	await _test_tactical_pause_stops_world(tree, t, main)
	await _test_dash_moves_further(tree, t, main)
	await _test_throw_creates_projectile(tree, t, main)
	await _test_enemy_attacks_player(tree, t, main)
	_test_combat_survives_save_load(t, main)

	main.queue_free()
	await tree.physics_frame
	t.done()


## ★ 실제 입력으로 적을 때려 죽일 수 있는가 — PHASE 4의 핵심.
func _test_attack_kills_enemy(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var enemy: Enemy = main._enemies[0]
	var player: CharacterBody2D = main._player
	var weapon: WeaponData = player.combatant.weapon()
	t.assert_true(weapon != null, "무기가 있어야 한다")
	if weapon == null:
		return

	# 적을 리치 안 정면에 세운다.
	player.facing = Vector2.RIGHT
	enemy.global_position = player.global_position + Vector2(weapon.reach * 0.5, 0.0)
	# 적이 반격해 테스트가 흔들리지 않게 잠시 떼어둔다.
	enemy.target = null

	var before: float = enemy.combatant.vitality
	t.assert_true(enemy.combatant.alive, "테스트 전제: 적이 살아 있어야 한다")

	# 죽을 때까지 실제 입력으로 때린다.
	var swings := 0
	while enemy.combatant.alive and swings < 40:
		Input.action_press("attack")
		await tree.physics_frame
		Input.action_release("attack")
		# 공격 한 사이클이 끝날 만큼 흘린다.
		for i in 20:
			await tree.physics_frame
			enemy.global_position = player.global_position + Vector2(weapon.reach * 0.5, 0.0)
		swings += 1

	t.assert_true(enemy.combatant.vitality < before,
		"실제 입력으로 적에게 피해가 들어가야 한다 (남은 %.1f / 시작 %.1f)"
		% [enemy.combatant.vitality, before])
	t.assert_true(not enemy.combatant.alive,
		"때리면 결국 죽어야 한다 (%d회 휘두름, 남은 %.1f)" % [swings, enemy.combatant.vitality])
	t.assert_true(swings > 1,
		"한 방에 죽으면 전투가 성립하지 않는다 (휘두른 횟수 %d)" % swings)

	# 시체는 더 이상 맞지 않는다
	var dead_vitality: float = enemy.combatant.vitality
	Input.action_press("attack")
	await tree.physics_frame
	Input.action_release("attack")
	for i in 20:
		await tree.physics_frame
	t.assert_almost_eq(enemy.combatant.vitality, dead_vitality,
		"시체는 더 이상 피해를 받지 않는다", 0.0001)


## ★ `CBT-001` — 전술 정지 중에는 월드가 멈춘다.
func _test_tactical_pause_stops_world(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var enemy: Enemy = _living_enemy(main)
	t.assert_true(enemy != null, "테스트 전제: 살아 있는 적이 있어야 한다")
	if enemy == null:
		return
	enemy.target = main._player
	enemy.global_position = main._player.global_position + Vector2(120, 0)

	Input.action_press("tactical_pause")
	await tree.physics_frame
	Input.action_release("tactical_pause")
	await tree.physics_frame
	t.assert_true(main._time.is_paused(), "Tab으로 월드가 정지해야 한다 (CBT-001)")

	var frozen: Vector2 = enemy.global_position
	for i in 30:
		await tree.physics_frame
	t.assert_vec_almost_eq(enemy.global_position, frozen,
		"정지 중에 적이 움직이면 정지가 의미가 없다", 0.01)

	Input.action_press("tactical_pause")
	await tree.physics_frame
	Input.action_release("tactical_pause")
	t.assert_true(not main._time.is_paused(), "다시 누르면 재개돼야 한다")

	for i in 30:
		await tree.physics_frame
	t.assert_true(enemy.global_position.distance_to(frozen) > 1.0,
		"재개하면 적이 다시 움직여야 한다")
	enemy.target = null


## 대시는 평소보다 멀리 간다.
func _test_dash_moves_further(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var player: CharacterBody2D = main._player
	# 벽에 막히지 않게 넓은 곳으로 옮긴다.
	var open_cell: Vector2i = main._floor_def.start_points[0]
	player.global_position = Vector2(open_cell.x * CELL + CELL / 2.0,
		open_cell.y * CELL + CELL / 2.0)
	await tree.physics_frame

	var start: Vector2 = player.global_position
	Input.action_press("move_right")
	for i in 8:
		await tree.physics_frame
	Input.action_release("move_right")
	var walked: float = player.global_position.distance_to(start)

	player.global_position = start
	player.facing = Vector2.RIGHT
	await tree.physics_frame
	Input.action_press("dash")
	await tree.physics_frame
	Input.action_release("dash")
	for i in 7:
		await tree.physics_frame
	var dashed: float = player.global_position.distance_to(start)

	t.assert_true(walked > 0.0, "테스트 전제: 걸어서 움직여야 한다 (%.1f)" % walked)
	t.assert_true(dashed > walked,
		"대시가 걷기보다 멀어야 한다 (걷기 %.1f, 대시 %.1f)" % [walked, dashed])


## `FLR-028` — 던지기 입력이 실제로 투사체를 만든다.
func _test_throw_creates_projectile(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var before: int = main._projectiles.size()
	Input.action_press("throw_item")
	await tree.physics_frame
	Input.action_release("throw_item")
	await tree.physics_frame

	t.assert_true(main._projectiles.size() > before,
		"던지기 입력이 투사체를 만들어야 한다 (FLR-028 — 돌로 함정 터뜨리기)")

	# 날아가다 결국 사라져야 한다 — 영원히 남으면 누수다
	for i in 120:
		await tree.physics_frame
		if main._projectiles.is_empty():
			break
	t.assert_eq(main._projectiles.size(), 0,
		"투사체는 사거리 끝에서 사라져야 한다 (남은 %d)" % main._projectiles.size())


## 적도 공격한다 — 일방적으로 맞기만 하면 전투가 아니다.
func _test_enemy_attacks_player(tree: SceneTree, t: TestCase, main: Node2D) -> void:
	var enemy: Enemy = _living_enemy(main)
	if enemy == null:
		return
	var player: CharacterBody2D = main._player
	var before: float = player.combatant.vitality

	enemy.target = player
	var w: WeaponData = enemy.combatant.weapon()
	enemy.global_position = player.global_position + Vector2((w.reach if w else 20.0) * 0.4, 0)

	for i in 120:
		await tree.physics_frame
		if player.combatant.vitality < before:
			break

	t.assert_true(player.combatant.vitality < before,
		"적이 플레이어를 공격해야 한다 (남은 %.1f / 시작 %.1f)"
		% [player.combatant.vitality, before])
	enemy.target = null


## `4-1` — 세이브/로드 후 전투 상태가 무결하다.
func _test_combat_survives_save_load(t: TestCase, main: Node2D) -> void:
	var run: RunState = main._run
	var world: WorldState = main._world
	var defs := {main._floor_def.floor_id: main._floor_def}

	# 지금 상태 — 플레이어는 다쳤고 적 하나는 죽었다
	var player_vitality: float = (run.ensure_combatant(main.EXILE_ID) as Combatant).vitality
	var dead_id: StringName = &""
	for e in main._enemies:
		if e.combatant != null and not e.combatant.alive:
			dead_id = e.combatant.id
			break
	t.assert_true(dead_id != &"", "테스트 전제: 죽은 적이 있어야 한다")

	var r := RunSave.from_text(RunSave.to_text(run), defs)
	t.assert_eq(int(r["status"]), int(FloorSave.LoadStatus.OK), "로드가 정상이어야 한다")
	var loaded: RunState = r["run"]
	t.assert_true(loaded != null, "복원돼야 한다")
	if loaded == null:
		return

	t.assert_almost_eq((loaded.ensure_combatant(main.EXILE_ID) as Combatant).vitality, player_vitality,
		"플레이어 체력이 보존돼야 한다", 0.0001)

	var lw: WorldState = loaded.world(world.world_id)
	t.assert_true(lw != null, "월드가 복원돼야 한다")
	if lw == null:
		return
	t.assert_true(lw.combatants.has(dead_id), "적 전투 상태가 복원돼야 한다")
	t.assert_true(not (lw.combatants[dead_id] as Combatant).alive,
		"죽은 적이 되살아나면 안 된다 (4-1)")


func _living_enemy(main: Node2D) -> Enemy:
	for e in main._enemies:
		if e != null and is_instance_valid(e) and e.combatant != null and e.combatant.alive:
			return e
	return null
