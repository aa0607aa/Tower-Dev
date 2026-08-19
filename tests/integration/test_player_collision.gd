extends RefCounted
## 벽·장애물 충돌 — `TEST_CHECKLIST` 1-1.
##
## PHASE 2에서 `TestRoom.tscn`(canon 아님)을 폐기하고 **실제 1층 고정 정의**로 바꿨다.
##
## ⚠ 케이스를 추가할 때 반드시 두 단언을 **쌍으로** 넣을 것:
##   ① 경계를 넘지 않았는가   ② 목표에 실제로 도달했는가
## ①만 쓰면 엉뚱한 장애물에 막혀도 통과한다. 초기 구현이 실제로 그랬다.
##
## 기대 정지 위치를 **하드코딩하지 않고 `FloorDefinition`에서 계산**한다.
## 하드코딩하면 레이아웃을 조금만 고쳐도 테스트가 거짓 실패하고, 그러면 사람이 테스트를 끈다.

const PLAYER_SCENE := "res://scenes/player/Player.tscn"
const CELL := 32
const HALF_EXTENT := 10.0
const CONTACT_TOLERANCE := 2.0
const PUSH_SPEED := 400.0
## 물리 틱 기준 초당 프레임. 밀어붙일 프레임 수를 **거리에서 계산**하는 데 쓴다.
##
## 고정 프레임 수를 쓰면 안 된다 — PHASE 1의 테스트 방은 30타일이라 220프레임으로 충분했지만
## 1층은 180타일이라 도중에 멈춘다. 그러면 "벽에 닿지 않았다"는 **거짓 실패**가 나고,
## 원인이 충돌인지 시간 부족인지 구분되지 않는다.
const TICKS_PER_SECOND := 60.0
## 감속·밀착에 필요한 여유 프레임.
const FRAME_MARGIN := 40


func run(tree: SceneTree, t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return

	var view := FloorView.new()
	tree.root.add_child(view)
	view.build(def)

	var player: CharacterBody2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	tree.root.add_child(player)
	# 노드를 붙인 직후에는 물리 공간에 들어가지 않아 move_and_slide()가 에러를 낸다.
	await tree.physics_frame

	# 시작점이 속한 방 안에서 네 방향으로 밀어붙인다.
	var origin: Vector2i = def.start_points[0]
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		await _push_case(tree, t, def, player, origin, dir)

	player.queue_free()
	view.queue_free()
	await tree.physics_frame


func _push_case(tree: SceneTree, t: TestCase, def: FloorDefinition,
		player: CharacterBody2D, origin: Vector2i, dir: Vector2i) -> void:
	# 이 방향으로 통행 가능한 마지막 셀을 찾는다 — 기대 정지 위치의 근거다.
	var last := origin
	while def.is_walkable(last + dir):
		last += dir
	t.assert_true(last != origin,
		"%s 방향으로 최소 한 칸은 이동할 수 있어야 한다 (테스트가 무의미해지지 않게)" % _name(dir))

	var expected := _stop_edge(last, dir)
	var axis_is_x := dir.x != 0

	player.global_position = _center(origin)
	player.velocity = Vector2.ZERO
	await tree.physics_frame

	# 실제 이동 거리에서 필요한 프레임 수를 계산한다
	var travel: float = absf(_center(origin).x - expected) if axis_is_x \
		else absf(_center(origin).y - expected)
	var frames := int(ceil(travel / (PUSH_SPEED / TICKS_PER_SECOND))) + FRAME_MARGIN

	for i in frames:
		# Player의 _physics_process가 입력을 읽어 velocity를 덮어쓰므로 직접 실어 민다.
		# 입력 경로 자체는 test_player_movement_e2e.gd가 검증한다.
		player.velocity = Vector2(dir) * PUSH_SPEED
		player.move_and_slide()
		await tree.physics_frame

	var pos := player.global_position
	var actual: float = pos.x if axis_is_x else pos.y
	var moving_positive := (dir.x + dir.y) > 0

	# ① 벽을 넘지 않았는가
	var not_passed: bool = (actual <= expected + CONTACT_TOLERANCE) if moving_positive \
		else (actual >= expected - CONTACT_TOLERANCE)
	t.assert_true(not_passed,
		"%s 벽을 통과하지 못해야 한다 (기대 %.1f, 실제 %.1f)" % [_name(dir), expected, actual])

	# ② 그 벽까지 실제로 도달했는가 — 없으면 엉뚱한 곳에 막혀도 통과한다
	t.assert_almost_eq(actual, expected,
		"%s 벽에 실제로 닿아야 한다" % _name(dir), CONTACT_TOLERANCE)


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)


## 통행 가능한 마지막 셀에서 그 방향 벽에 밀착했을 때의 중심 좌표.
func _stop_edge(last_walkable: Vector2i, dir: Vector2i) -> float:
	if dir == Vector2i.LEFT:
		return last_walkable.x * CELL + HALF_EXTENT
	if dir == Vector2i.RIGHT:
		return (last_walkable.x + 1) * CELL - HALF_EXTENT
	if dir == Vector2i.UP:
		return last_walkable.y * CELL + HALF_EXTENT
	return (last_walkable.y + 1) * CELL - HALF_EXTENT


func _name(dir: Vector2i) -> String:
	if dir == Vector2i.LEFT: return "왼쪽"
	if dir == Vector2i.RIGHT: return "오른쪽"
	if dir == Vector2i.UP: return "위쪽"
	return "아래쪽"
