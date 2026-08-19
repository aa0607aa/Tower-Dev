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
##
## ## 거리가 아니라 속도를 본다 (2026-08-19)
## 처음에는 "`await physics_frame` N번 = 물리 스텝 N번"으로 보고 `거리 == 속도 × N/tps`를
## 단언했다. 30 tick 측정에서 **정확히 `160/60 = 2.67px`가 모자랐다.**
##
## 추측하지 않고 관측했다:
##   1. 빈 SceneTree에서 같은 순서를 재현하니 15스텝 모두 `dx=5.3333`, 합계 정확히 80.0.
##      → `player.gd`도 `Movement`도 멀쩡하다.
##   2. 틱레이트 변경 직후 delta를 찍어보니 첫 프레임부터 `1/30`을 보고했다.
##      → "보고 값이 늦게 바뀐다"는 가설도 틀렸다.
##   3. 스텝 수를 세지 않고 보고된 delta를 누적해봤더니 누적 시간은 **15스텝(0.5초)**,
##      이동 거리는 **14.5스텝분**이었다.
##
## 결론: 틱레이트를 바꾼 직후의 스텝이 **이전 delta로 적분하면서 새 delta를 보고한다.**
## 런타임에 틱레이트를 바꾸는 건 이 테스트뿐이고 실제 게임에는 없는 상황이다.
##
## 그래서 두 가지를 고쳤다 — 허용치를 늘려 덮은 것이 아니라 **측정 대상을 바로잡았다**:
##   - 스텝 수를 가정하지 않고 보고된 delta를 누적해 논리 시간을 만든다
##   - 전환 스텝을 흘려보낸 뒤 **정상 상태 속도**를 잰다
## `velocity *= delta` 버그는 속도를 2.7px/s로 만들므로 이 방식으로도 그대로 잡힌다.
## (변이 주입으로 실제 확인함 — 아래 주석 참조)
##
const PLAYER_SCENE := "res://scenes/player/Player.tscn"

## 측정할 논리 시간(초). 짧으면 오차가, 길면 테스트가 느려진다.
const DURATION := 0.5
## 속도 허용치(픽셀/초). 물리 스텝 경계 오차만 흡수할 만큼만 준다.
## `velocity *= delta` 버그는 속도를 2.7px/s로 만들므로 이 폭으로도 확실히 잡힌다.
const SPEED_TOLERANCE := 2.0
## 틱레이트 전환 스텝을 흘려보내는 수. 측정 전에만 쓴다.
const FLUSH_STEPS := 4
## `Player.BASE_SPEED`. 여기 하드코딩하면 상수가 바뀔 때 조용히 어긋나므로 씬에서 읽는다.
var _base_speed := 160.0


func run(tree: SceneTree, t: TestCase) -> void:
	var original_tps := Engine.physics_ticks_per_second
	_base_speed = (load("res://scripts/player/player.gd") as GDScript).get_script_constant_map()["BASE_SPEED"]

	var v30 := await _measure(tree, ["move_right"], 30)
	var v60 := await _measure(tree, ["move_right"], 60)
	var v120 := await _measure(tree, ["move_right"], 120)

	Engine.physics_ticks_per_second = original_tps

	# 1-2. 프레임률이 달라도 같은 속도 — 실제 Player 경로로.
	t.assert_almost_eq(v30, _base_speed, "30 tick/s 실제 이동 속도(px/s)", SPEED_TOLERANCE)
	t.assert_almost_eq(v60, _base_speed, "60 tick/s 실제 이동 속도(px/s)", SPEED_TOLERANCE)
	t.assert_almost_eq(v120, _base_speed, "120 tick/s 실제 이동 속도(px/s)", SPEED_TOLERANCE)
	t.assert_almost_eq(v30, v60, "30 tick/s와 60 tick/s 속도가 같아야 한다", SPEED_TOLERANCE)
	t.assert_almost_eq(v60, v120, "60 tick/s와 120 tick/s 속도가 같아야 한다", SPEED_TOLERANCE)

	# 1-3. 대각이 직선보다 빠르지 않다 — 실제 입력 조합으로.
	var straight := await _measure(tree, ["move_right"], 60)
	var diagonal := await _measure(tree, ["move_right", "move_down"], 60)
	Engine.physics_ticks_per_second = original_tps

	t.assert_almost_eq(diagonal, straight,
		"대각 이동 속도가 직선과 같아야 한다 (정규화)", SPEED_TOLERANCE)
	t.assert_true(diagonal <= straight + SPEED_TOLERANCE,
		"대각이 직선보다 빠르면 안 된다 (직선 %.2f, 대각 %.2f px/s)" % [straight, diagonal])


## 입력을 실제로 눌러 **속도(픽셀/초)** 를 잰다.
##
## 물리 스텝 수를 가정하지 않는다 — 엔진이 보고한 delta를 누적해 논리 시간을 직접 만든다.
func _measure(tree: SceneTree, actions: Array, ticks_per_second: int) -> float:
	Engine.physics_ticks_per_second = ticks_per_second
	var player: CharacterBody2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	tree.root.add_child(player)
	# 벽이 없는 빈 공간. 충돌은 test_player_collision.gd가 따로 본다.
	player.global_position = Vector2.ZERO
	for a in actions:
		Input.action_press(a)

	# 틱레이트를 바꾼 직후 몇 스텝은 **이전 delta로 적분하면서 새 delta를 보고한다.**
	# 30 tick 측정에서 누적 시간은 15스텝인데 이동은 14.5스텝분이 나오는 게 이것 때문이다.
	# 런타임에 틱레이트를 바꾸는 건 이 테스트뿐이고 실제 게임에는 없는 상황이므로,
	# 전환이 끝난 뒤의 **정상 상태 속도**를 잰다. 입력을 미리 눌러두고 몇 스텝 흘린다.
	for _i in FLUSH_STEPS:
		await tree.physics_frame

	var start := player.global_position
	var elapsed := 0.0
	for i in int(round(DURATION * ticks_per_second)):
		await tree.physics_frame
		elapsed += tree.root.get_physics_process_delta_time()
	for a in actions:
		Input.action_release(a)
	var distance := player.global_position.distance_to(start)
	player.queue_free()
	await tree.physics_frame

	if elapsed <= 0.0:
		return 0.0
	return distance / elapsed
