extends RefCounted
## 벽·장애물 충돌 — TEST_CHECKLIST 1-1.
##
## ⚠ 케이스를 추가할 때 반드시 두 단언을 **쌍으로** 넣을 것:
##   ① 경계를 넘지 않았는가
##   ② 목표에 실제로 도달했는가
##
## ①만 쓰면 **엉뚱한 장애물에 막혀도 통과한다.** 초기 구현이 실제로 그랬다 —
## 오른쪽 벽(x=950) 케이스가 안쪽 블록(x=608)에 막혀 x=598에서 멈췄는데
## `x <= 950`이 참이라 그냥 통과했다.

const ROOM_SCENE := "res://scenes/world/TestRoom.tscn"
const PLAYER_SCENE := "res://scenes/player/Player.tscn"

const PUSH_FRAMES := 150
const PUSH_SPEED := 400.0
## Player.tscn의 RectangleShape2D 20x20 → 반폭 10.
const HALF_EXTENT := 10.0
const CONTACT_TOLERANCE := 2.0


func run(tree: SceneTree, t: TestCase) -> void:
	var room: Node2D = (load(ROOM_SCENE) as PackedScene).instantiate()
	tree.root.add_child(room)
	var player: CharacterBody2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	tree.root.add_child(player)
	# 노드를 붙인 직후에는 아직 물리 공간에 들어가지 않아 move_and_slide()가
	# "body->get_space() is null" 에러를 낸다. 한 프레임 넘기고 시작한다.
	await tree.physics_frame

	# 방 내부 (0,0)~(960,640). 안쪽 장애물:
	#   BlockH  x 224..352, y 176..208
	#   BlockV  x 608..640, y 320..480
	#   BlockSq x 160..256, y 448..544
	# 출발점은 목표까지 **장애물이 없는 경로**로 고른다.
	var cases := [
		{"name": "왼쪽 벽", "start": Vector2(480, 64), "dir": Vector2.LEFT,
			"axis": "x", "expected": HALF_EXTENT, "is_min": true},
		{"name": "오른쪽 벽", "start": Vector2(480, 64), "dir": Vector2.RIGHT,
			"axis": "x", "expected": 960.0 - HALF_EXTENT, "is_min": false},
		{"name": "위쪽 벽", "start": Vector2(480, 320), "dir": Vector2.UP,
			"axis": "y", "expected": HALF_EXTENT, "is_min": true},
		{"name": "아래쪽 벽", "start": Vector2(480, 320), "dir": Vector2.DOWN,
			"axis": "y", "expected": 640.0 - HALF_EXTENT, "is_min": false},
		# 안쪽 장애물도 막아야 한다. 외벽만 보면 블록 충돌이 깨져도 모른다.
		{"name": "안쪽 블록", "start": Vector2(480, 400), "dir": Vector2.RIGHT,
			"axis": "x", "expected": 608.0 - HALF_EXTENT, "is_min": false},
	]

	for case in cases:
		player.global_position = case["start"]
		player.velocity = Vector2.ZERO

		for i in PUSH_FRAMES:
			# Player의 _physics_process가 입력을 읽어 velocity를 덮어쓰므로,
			# 충돌만 보는 이 케이스에서는 매 프레임 직접 실어 밀어붙인다.
			# (입력 경로 자체는 test_player_movement_e2e.gd가 검증한다)
			player.velocity = (case["dir"] as Vector2) * PUSH_SPEED
			player.move_and_slide()
			await tree.physics_frame

		var pos: Vector2 = player.global_position
		var actual: float = pos.x if case["axis"] == "x" else pos.y
		var expected: float = case["expected"]

		# ① 경계를 넘지 않았는가
		var not_passed: bool = (actual >= expected - CONTACT_TOLERANCE) if case["is_min"] \
			else (actual <= expected + CONTACT_TOLERANCE)
		t.assert_true(not_passed,
			"%s을 통과하지 못해야 한다 (기대 %.1f, 실제 %.1f)" % [case["name"], expected, actual])

		# ② 목표에 실제로 도달했는가 — 없으면 엉뚱한 장애물에 막혀도 통과한다
		t.assert_almost_eq(actual, expected,
			"%s에 실제로 닿아야 한다" % case["name"], CONTACT_TOLERANCE)

	player.queue_free()
	room.queue_free()
	await tree.physics_frame
