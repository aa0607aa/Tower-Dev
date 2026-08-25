extends RefCounted
## `P4-REV-002` — **로드한 회차를 실제 씬에 주입해 복원**한다. (`SYS-003` `WLD-003`)
##
## ## 왜 이 파일이 따로 있는가
## 기존 E2E는 `RunSave` JSON 왕복 뒤 **Dictionary 값만** 비교했다.
## 그러면 "저장 형식은 맞는데 게임이 그 값을 안 쓰는" 상태를 못 잡는다 —
## `Enemy.to_save_dict()`가 있는데 세이브에 안 쓰이던 `P4-REV-002`가 정확히 그랬다.
##
## 그래서 여기서는 **새 `Main` 씬을 로드 상태로 띄운다.**
##   저장 → `Main.pending_run`에 주입 → 새 씬 생성 → 노드로 복원됐는가 → **다음 tick도 같은가**
##
## ## 저장/취소 계약 (조용히 사라지는 상태는 없다)
##   - **대시**: 로드 시 취소 (`RunState` 주석에 명시)
##   - **투사체**: 저장하고 재개 — **오너 결정 2026-08-21**
## 둘의 차이는 의도된 것이며 각각 테스트로 지킨다.

const MAIN_SCENE := "res://scenes/world/Main.tscn"
const CELL := 32

## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
const MIN_ASSERTIONS := 32


func run(tree: SceneTree, t: TestCase) -> void:
	# ── 1. 원본 세션을 만들고 상태를 흐트러뜨린다 ──────────────────────
	var origin: Main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(origin)
	await tree.physics_frame
	await tree.physics_frame

	var def: FloorDefinition = origin._floor_def
	t.assert_true(def != null and not origin._enemies.is_empty(),
		"테스트 전제: 층과 적이 있어야 한다")
	if def == null or origin._enemies.is_empty():
		origin.queue_free()
		return

	# 플레이어를 시작점에서 옮기고 조준을 바꾼다
	var player_pos := Vector2(def.start_points[0].x * CELL + CELL / 2.0 + 40.0,
		def.start_points[0].y * CELL + CELL / 2.0)
	origin._player.global_position = player_pos
	origin._player.facing = Vector2(0, -1)

	# 공격을 선딜 중간까지 진행시킨다
	var w: WeaponData = origin._player.combatant.weapon()
	origin._player.attack_state = AttackState.new()
	origin._player.attack_state.start(w, Vector2(0, -1))
	origin._player.attack_state.advance(w.wind_up * 0.4)

	# 적도 스폰 지점에서 옮기고 선딜 중간으로
	var enemy: Enemy = origin._enemies[0]
	var enemy_pos := player_pos + Vector2(180.0, 120.0)
	enemy.global_position = enemy_pos
	enemy.attack_state.start(enemy.combatant.weapon(), Vector2.LEFT)
	enemy.attack_state.advance(enemy.combatant.weapon().wind_up * 0.3)
	enemy.mode = Enemy.Mode.CHASE
	enemy.combatant.vitality = 71.5

	# 돌을 던져 **비행 중**으로 만든다.
	# 벽에 바로 박히지 않도록 **열린 쪽**으로 던진다 — 시작점 근처는 광장이다.
	origin._player.facing = Vector2.RIGHT
	origin._on_throw()
	origin._player.facing = Vector2(0, -1)
	await tree.physics_frame
	t.assert_true(origin._projectiles.size() > 0, "테스트 전제: 투사체가 떠 있어야 한다")

	# 대시도 걸어둔다 — 이건 취소돼야 한다
	origin._player.try_dash()
	await tree.physics_frame
	t.assert_true(origin._player.is_dashing(), "테스트 전제: 대시 중이어야 한다")
	await tree.physics_frame  # `_sync_runtime_state()`가 데이터로 옮긴다

	# 동기화가 실제로 돌았는지 먼저 확인한다 — 안 돌면 뒤가 전부 무의미하다.
	origin.capture_runtime_state()
	t.assert_true(origin._run.exile_states.has(origin.EXILE_ID),
		"캡처하면 유배자 런타임 상태가 있어야 한다 (P4-REV-002)")
	var flying_before: int = origin._world.projectiles.size()
	t.assert_true(flying_before > 0,
		"비행 중인 투사체가 저장 데이터에 있어야 한다 (살아있는 %d개)"
		% origin._projectiles.size())

	# ── 2. 저장 → 로드 → **새 씬에 주입** ─────────────────────────────
	var defs := {def.floor_id: def}
	origin.capture_runtime_state()  # 저장은 "지금 이 순간"을 담는다
	var text := RunSave.to_text(origin._run)
	var enemy_id: StringName = enemy.combatant.id
	var expected_player: Vector2 = origin._player.global_position
	var expected_facing: Vector2 = origin._player.facing
	var expected_attack: float = origin._player.attack_state.elapsed
	var expected_enemy: Vector2 = enemy.global_position
	var expected_vitality: float = enemy.combatant.vitality

	origin.queue_free()
	await tree.physics_frame

	var r := RunSave.from_text(text, defs)
	t.assert_eq(int(r["status"]), int(FloorSave.LoadStatus.OK), "로드가 정상이어야 한다")
	var loaded: RunState = r["run"]
	t.assert_true(loaded != null, "회차가 복원돼야 한다")
	if loaded == null:
		return

	# 어느 단계에서 끊기는지 좁힌다 — 저장 / 복원 / 적용
	t.assert_true(text.contains("exile_states"), "세이브 텍스트에 유배자 상태가 있어야 한다")
	t.assert_true(loaded.exile_states.has(&"player"),
		"로드한 회차에 유배자 상태가 있어야 한다 (키 %s)" % str(loaded.exile_states.keys()))

	# ★ production 주입 지점 — 테스트만의 우회로가 아니다
	Main.pending_run = loaded
	var revived: Main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(revived)
	await tree.physics_frame
	await tree.physics_frame

	t.assert_true(Main.pending_run == null,
		"주입한 회차는 한 번 쓰고 비워야 한다 — 남으면 다음 새 게임이 옛 세이브로 시작한다")
	t.assert_true(revived._run == loaded, "새 씬이 로드한 회차를 써야 한다 (새로 만들면 안 된다)")
	t.assert_true(revived._run.exile_states.has(&"player"),
		"복원된 씬에도 유배자 상태가 있어야 한다 — 내용 %s"
		% str(revived._run.exile_states.get(&"player", {})))

	# ── 3. 노드로 실제 복원됐는가 ─────────────────────────────────────
	t.assert_vec_almost_eq(revived._player.global_position, expected_player,
		"플레이어 위치가 복원돼야 한다 (P4-REV-002)", 0.5)
	t.assert_vec_almost_eq(revived._player.facing, expected_facing,
		"조준 방향이 복원돼야 한다", 0.01)
	t.assert_eq(int(revived._player.attack_state.phase), int(AttackState.Phase.WIND_UP),
		"휘두르던 선딜이 이어져야 한다")
	t.assert_almost_eq(revived._player.attack_state.elapsed, expected_attack,
		"선딜 경과가 이어져야 한다", 0.0001)

	var revived_enemy: Enemy = null
	for e in revived._enemies:
		if e != null and is_instance_valid(e) and e.combatant != null \
				and e.combatant.id == enemy_id:
			revived_enemy = e
			break
	t.assert_true(revived_enemy != null, "같은 적이 복원돼야 한다")
	if revived_enemy != null:
		t.assert_vec_almost_eq(revived_enemy.global_position, expected_enemy,
			"적이 스폰 지점이 아니라 **저장된 자리**에 있어야 한다", 0.5)
		t.assert_almost_eq(revived_enemy.combatant.vitality, expected_vitality,
			"적 체력이 복원돼야 한다", 0.0001)
		t.assert_eq(int(revived_enemy.mode), int(Enemy.Mode.CHASE), "행동 모드가 복원돼야 한다")
		t.assert_eq(int(revived_enemy.attack_state.phase), int(AttackState.Phase.WIND_UP),
			"적이 휘두르던 공격도 이어져야 한다")

	# ★ 투사체는 **노드로** 다시 떠 있어야 한다 (오너 결정 — 저장한다)
	t.assert_eq(revived._projectiles.size(), flying_before,
		"비행 중이던 투사체가 노드로 복원돼야 한다 (오너 결정 2026-08-21)")
	if revived._projectiles.size() > 0:
		var p: ThrownObject = revived._projectiles[0]
		t.assert_true(p.direction.length() > 0.0, "투사체 방향이 복원돼야 한다")
		t.assert_true(p._travelled >= 0.0, "이동 거리가 복원돼야 한다")

	# ★ 대시는 **취소** — 계약대로
	t.assert_true(not revived._player.is_dashing(),
		"대시는 로드 시 취소된다 — 계약이며 조용한 초기화가 아니다")

	# ── 4. **다음 tick도 같은가** ─────────────────────────────────────
	# 복원만 되고 그 다음이 어긋나면 의미가 없다.
	var before_phase := int(revived._player.attack_state.phase)
	var before_travel: float = revived._projectiles[0]._travelled if revived._projectiles.size() > 0 else 0.0
	for i in 3:
		await tree.physics_frame
	t.assert_true(revived._player.attack_state.elapsed > expected_attack
			or int(revived._player.attack_state.phase) != before_phase,
		"복원 후에도 공격이 계속 진행돼야 한다 (멈춰 있으면 안 된다)")
	if revived._projectiles.size() > 0:
		t.assert_true(revived._projectiles[0]._travelled > before_travel,
			"복원된 투사체가 계속 날아가야 한다")

	await _test_sensor_cell_survives_reload(tree, t, revived, defs)

	revived.queue_free()
	await tree.physics_frame
	t.done()


## ★ `TrapSensor`의 마지막 칸이 저장돼야 한다.
##
## 저장하지 않으면 **반복형 함정 위에서 저장·로드했을 때 움직이지 않았는데 재발동한다** —
## 로드 직후 센서가 "처음 보는 칸"으로 판단하기 때문이다.
func _test_sensor_cell_survives_reload(tree: SceneTree, t: TestCase, main: Main,
		defs: Dictionary) -> void:
	var def: FloorDefinition = main._floor_def
	var state: FloorState = main._floor_state

	# 반복형(one_shot 아님) 함정을 찾는다 — 발동 뒤에도 무장이 유지된다
	var trap := {}
	for candidate in def.traps:
		if not bool(candidate["one_shot"]) and def.is_walkable(candidate["cell"]):
			trap = candidate
			break
	t.assert_true(not trap.is_empty(), "테스트 전제: 반복형 함정이 있어야 한다")
	if trap.is_empty():
		return

	var cell: Vector2i = trap["cell"]
	main._player.global_position = Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)
	# 함정 판정은 `_process`에서 돈다. 헤드리스에서는 `physics_frame`과 빈도가 크게 다르므로
	# **`process_frame`을 기다려야** 한다 — physics만 기다리면 아예 안 돌 수 있다.
	for i in 60:
		await tree.process_frame
		if state.trap_has_fired(trap["id"]):
			break
	t.assert_true(state.trap_has_fired(trap["id"]), "테스트 전제: 밟아서 발동했어야 한다")
	t.assert_true(state.trap_is_armed(trap["id"]), "반복형이라 무장은 유지된다")
	await tree.physics_frame  # 동기화

	t.assert_true(main._world.sensor_cells.has(main.EXILE_ID),
		"센서의 마지막 칸이 저장 데이터에 있어야 한다 (P4-REV-002)")

	# 저장 → 로드 → 새 씬. **움직이지 않았으니 다시 터지면 안 된다.**
	main.capture_runtime_state()
	var text := RunSave.to_text(main._run)
	var r := RunSave.from_text(text, defs)
	Main.pending_run = r["run"]
	var revived: Main = (load(MAIN_SCENE) as PackedScene).instantiate()
	tree.root.add_child(revived)
	await tree.physics_frame

	var fired_count := 0
	var revived_state: FloorState = revived._floor_state
	revived_state.trap_states[trap["id"]]["fired"] = false  # 재발동을 관측하려고 초기화
	for i in 6:
		await tree.physics_frame
		if revived_state.trap_has_fired(trap["id"]):
			fired_count += 1
	t.assert_eq(fired_count, 0,
		"로드 직후 제자리에서 함정이 재발동하면 안 된다 (P4-REV-002 — 센서 칸 보존)")

	revived.queue_free()
	await tree.physics_frame
