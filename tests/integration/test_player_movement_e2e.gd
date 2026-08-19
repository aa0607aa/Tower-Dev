extends RefCounted
## 실제 Player 경로 E2E 이동 회귀 — TEST_CHECKLIST 1-2, 1-3. (P1-TEST-001)
##
## **이 파일이 존재하는 이유** — `tests/test_movement.gd`(단위)는 `Movement.step()`을 검사하는데
## 실제 `player.gd`는 그 함수를 **호출하지 않는다.** `move_and_slide()`를 쓴다.
## 그래서 `player.gd`에 delta를 한 번 더 곱하는 버그가 생겨도 단위 테스트는 계속 통과한다.
##
## 실제로 확인했다 — `velocity *= delta`를 주입하고 돌렸더니 단위 17단언 + 통합 10단언이
## **전부 통과**했다. 플레이어가 초당 2.7픽셀로 기어가는 상태인데도.
##
## 그래서 이 테스트는 우회로 없이 **진짜 경로**를 통과한다:
##   `Input.action_press()` → `Player._physics_process()` → `move_and_slide()` → 실제 이동 거리
##
## 벽에 막히면 프레임률 비교가 무의미해지므로 **빈 공간에서** 측정한다.

const PLAYER_SCENE := "res://scenes/player/Player.tscn"

## 측정할 논리 시간(초). 짧으면 오차가, 길면 테스트가 느려진다.
const DURATION := 0.5
## 프레임률이 달라도 같은 거리를 이동해야 한다. 물리 tick 오차를 감안한 허용치(px).
const DISTANCE_TOLERANCE := 1.0
## 틱레이트 변경이 실제로 반영되기를 기다리는 프레임 수.
const SETTLE_FRAMES := 3


func run(tree: SceneTree, t: TestCase) -> void:
	var original_tps := Engine.physics_ticks_per_second

	var d30 := await _measure(tree, "move_right", 30)
	var d60 := await _measure(tree, "move_right", 60)
	var d120 := await _measure(tree, "move_right", 120)

	Engine.physics_ticks_per_second = original_tps

	var expected := 160.0 * DURATION  # BASE_SPEED × 시간

	# 1-2. 프레임률이 달라도 같은 시간에 같은 거리 — 실제 Player 경로로.
	t.assert_almost_eq(d30, expected, "30 tick/s 실제 이동 거리", DISTANCE_TOLERANCE)
	t.assert_almost_eq(d60, expected, "60 tick/s 실제 이동 거리", DISTANCE_TOLERANCE)
	t.assert_almost_eq(d120, expected, "120 tick/s 실제 이동 거리", DISTANCE_TOLERANCE)
	t.assert_almost_eq(d30, d60, "30 tick/s와 60 tick/s가 같아야 한다", DISTANCE_TOLERANCE)
	t.assert_almost_eq(d60, d120, "60 tick/s와 120 tick/s가 같아야 한다", DISTANCE_TOLERANCE)

	# 1-3. 대각이 직선보다 빠르지 않다 — 실제 입력 조합으로.
	Engine.physics_ticks_per_second = 60
	var straight := await _measure(tree, "move_right", 60)
	var diagonal := await _measure_diagonal(tree, 60)
	Engine.physics_ticks_per_second = original_tps

	t.assert_almost_eq(diagonal, straight,
		"대각 이동 거리가 직선과 같아야 한다 (정규화)", DISTANCE_TOLERANCE)
	t.assert_true(diagonal <= straight + DISTANCE_TOLERANCE,
		"대각이 직선보다 빠르면 안 된다 (직선 %.2f, 대각 %.2f)" % [straight, diagonal])


## 한 방향 입력을 실제로 눌러 이동 거리를 잰다.
func _measure(tree: SceneTree, action: String, ticks_per_second: int) -> float:
	Engine.physics_ticks_per_second = ticks_per_second
	var player: CharacterBody2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	tree.root.add_child(player)
	# 벽이 없는 빈 공간. 충돌은 test_player_collision.gd가 따로 본다.
	player.global_position = Vector2.ZERO
	# `physics_ticks_per_second` 변경은 **한 프레임 늦게 적용**된다.
	# 바로 측정하면 첫 프레임이 이전 틱레이트의 delta로 돌아 거리가 어긋난다
	# (30 tick 측정에서 정확히 `160/60 = 2.67px`만큼 모자랐다).
	for _i in SETTLE_FRAMES:
		await tree.physics_frame

	var start := player.global_position
	Input.action_press(action)
	var frames := int(round(DURATION * ticks_per_second))
	for i in frames:
		await tree.physics_frame
	Input.action_release(action)

	var distance := player.global_position.distance_to(start)
	player.queue_free()
	await tree.physics_frame
	return distance


func _measure_diagonal(tree: SceneTree, ticks_per_second: int) -> float:
	Engine.physics_ticks_per_second = ticks_per_second
	var player: CharacterBody2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	tree.root.add_child(player)
	player.global_position = Vector2.ZERO
	for _i in SETTLE_FRAMES:
		await tree.physics_frame

	var start := player.global_position
	Input.action_press("move_right")
	Input.action_press("move_down")
	var frames := int(round(DURATION * ticks_per_second))
	for i in frames:
		await tree.physics_frame
	Input.action_release("move_right")
	Input.action_release("move_down")

	var distance := player.global_position.distance_to(start)
	player.queue_free()
	await tree.physics_frame
	return distance
