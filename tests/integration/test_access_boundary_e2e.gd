extends RefCounted
## `P2-REV-006` — 행동 반경은 **물리 이동 전에** 걸려야 한다.
##
## ## 이 파일이 존재하는 이유
## 전에는 `move_and_slide()`로 먼저 움직이고 결과 좌표만 경계 안으로 되감았다.
## 최종 좌표만 보면 멀쩡해서 **좌표 기반 단위 테스트로는 절대 잡히지 않는다.**
##
## 문제는 그 프레임에 몸체가 경계 밖에서 실제로 움직였다는 것이다. PHASE 3에서
## 함정·물체·`Area2D`가 붙으면 경계 밖 대상을 건드리고 나서 좌표만 되돌리는 상태가 된다.
## `D-017`/`FLR-024`상 유배자가 원인인 직접 영향은 경계 밖에 닿을 수 없다.
##
## 그래서 이 테스트는 **경계 밖에 실제 `Area2D`를 놓고 접촉이 한 번이라도 보고되는지**를 본다.
## 좌표가 아니라 물리 엔진의 관측을 근거로 삼는다.

const PLAYER_SCENE := "res://scenes/player/Player.tscn"
const CELL := 32
## 경계를 향해 충분히 오래 밀어붙인다.
const PUSH_FRAMES := 90


func run(tree: SceneTree, t: TestCase) -> void:
	# 허용 영역: (0,0)~(4,4) 셀. 그 오른쪽 바깥에 감시용 Area를 둔다.
	var env := AccessEnvelope.new(&"player", &"w", &"r")
	env.allow_rect(Rect2i(0, 0, 5, 5))

	var player: CharacterBody2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.access_envelope = env
	tree.root.add_child(player)
	player.global_position = Vector2(2 * CELL + CELL / 2.0, 2 * CELL + CELL / 2.0)

	# 경계 바로 바깥(셀 x=5,6)을 덮는 감시 영역
	var watcher := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(CELL * 2, CELL * 5)
	shape.shape = rect
	watcher.add_child(shape)
	watcher.global_position = Vector2(6 * CELL, 2.5 * CELL)
	watcher.monitoring = true
	tree.root.add_child(watcher)

	await tree.physics_frame
	await tree.physics_frame

	var touched := false
	var outside_frames := 0
	var max_x_cell := -1

	Input.action_press("move_right")
	Input.action_press("move_down")
	for i in PUSH_FRAMES:
		await tree.physics_frame
		if watcher.get_overlapping_bodies().has(player):
			touched = true
		var cell_x := floori(player.global_position.x / CELL)
		var cell_y := floori(player.global_position.y / CELL)
		max_x_cell = maxi(max_x_cell, cell_x)
		if cell_x > 4 or cell_y > 4 or cell_x < 0 or cell_y < 0:
			outside_frames += 1
	Input.action_release("move_right")
	Input.action_release("move_down")

	t.assert_true(not touched,
		"경계 밖 Area에 몸체가 닿으면 안 된다 (P2-REV-006 — 물리 이동 전에 막아야 한다)")
	t.assert_eq(outside_frames, 0,
		"어떤 프레임에서도 경계 밖 셀에 있으면 안 된다 (밖에 있던 프레임 %d)" % outside_frames)

	# 테스트가 헛돌지 않았음을 보인다 — 실제로 경계까지 밀어붙였어야 한다.
	t.assert_eq(max_x_cell, 4,
		"경계 마지막 셀(4)까지는 도달했어야 한다 (도달 %d) — 아니면 아무것도 검증하지 못한다" % max_x_cell)

	# 경계 안에서는 정상적으로 움직여야 한다. 막는 게 목적이지 얼려버리는 게 아니다.
	player.global_position = Vector2(CELL / 2.0, 2 * CELL + CELL / 2.0)
	await tree.physics_frame
	var start := player.global_position
	Input.action_press("move_right")
	for i in 10:
		await tree.physics_frame
	Input.action_release("move_right")
	t.assert_true(player.global_position.x > start.x + 5.0,
		"경계 안에서는 정상 이동해야 한다 (이동 %.1fpx)" % (player.global_position.x - start.x))

	# 봉투가 없는 개체(NPC·야생동물)는 제약을 받지 않아야 한다 (`FLR-023`).
	var free_body: CharacterBody2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	free_body.access_envelope = null
	tree.root.add_child(free_body)
	free_body.global_position = Vector2(4 * CELL, 2 * CELL + CELL / 2.0)
	await tree.physics_frame
	Input.action_press("move_right")
	for i in 40:
		await tree.physics_frame
	Input.action_release("move_right")
	t.assert_true(floori(free_body.global_position.x / CELL) > 4,
		"봉투가 없으면 경계를 넘을 수 있어야 한다 (NPC·야생동물, FLR-023)")

	player.queue_free()
	free_body.queue_free()
	watcher.queue_free()
	await tree.physics_frame
