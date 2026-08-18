extends RefCounted
## 이동 로직 테스트 — TEST_CHECKLIST 1-2, 1-3.
##
## PHASE 1 완료 조건 중 "프레임 변화에 속도 안 흔들림"과 "대각 이동이 직선보다 빠르지 않음"을
## 노드 없이 순수 함수로 검증한다.

const SPEED := 160.0


func run(t: TestCase) -> void:
	_test_diagonal_not_faster(t)
	_test_analog_strength_preserved(t)
	_test_zero_input(t)
	_test_frame_independence(t)
	_test_frame_independence_diagonal(t)


## 1-3. 8방향 대각 이동이 직선 이동보다 빠르면 안 된다.
func _test_diagonal_not_faster(t: TestCase) -> void:
	var straight := Movement.desired_velocity(Vector2(1, 0), SPEED)
	var diagonal := Movement.desired_velocity(Vector2(1, 1), SPEED)

	t.assert_almost_eq(straight.length(), SPEED, "직선 속도는 SPEED와 같아야 한다")
	t.assert_almost_eq(diagonal.length(), SPEED, "대각 속도도 SPEED와 같아야 한다")

	# 정규화를 빼먹으면 여기서 1.414배가 나온다
	t.assert_true(
		diagonal.length() <= straight.length() + TestCase.EPSILON,
		"대각 이동이 직선보다 빠르면 안 된다"
	)

	# 네 대각 방향 전부 확인
	for dir in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		t.assert_almost_eq(
			Movement.desired_velocity(dir, SPEED).length(), SPEED,
			"대각 %v 속도" % dir
		)


## 아날로그 입력(길이 < 1)은 세기를 보존해야 한다. 무조건 normalized()를 부르면 깨진다.
func _test_analog_strength_preserved(t: TestCase) -> void:
	var half := Movement.desired_velocity(Vector2(0.5, 0), SPEED)
	t.assert_almost_eq(half.length(), SPEED * 0.5, "절반 세기 입력은 절반 속도여야 한다")

	var unit := Movement.desired_velocity(Vector2(1, 0), SPEED)
	t.assert_almost_eq(unit.length(), SPEED, "최대 세기 입력은 SPEED여야 한다")


func _test_zero_input(t: TestCase) -> void:
	t.assert_vec_almost_eq(
		Movement.desired_velocity(Vector2.ZERO, SPEED), Vector2.ZERO,
		"입력이 없으면 속도는 0"
	)


## 1-2. 프레임률이 달라도 같은 시간 동안 같은 거리를 이동해야 한다.
func _test_frame_independence(t: TestCase) -> void:
	var velocity := Movement.desired_velocity(Vector2(1, 0), SPEED)
	var duration := 1.0

	var at_30 := _simulate(velocity, 1.0 / 30.0, 30)
	var at_60 := _simulate(velocity, 1.0 / 60.0, 60)
	var at_120 := _simulate(velocity, 1.0 / 120.0, 120)

	var expected := Vector2(SPEED * duration, 0)
	t.assert_vec_almost_eq(at_30, expected, "30 FPS 1초 이동 거리", 0.001)
	t.assert_vec_almost_eq(at_60, expected, "60 FPS 1초 이동 거리", 0.001)
	t.assert_vec_almost_eq(at_120, expected, "120 FPS 1초 이동 거리", 0.001)

	t.assert_vec_almost_eq(at_30, at_60, "30 FPS와 60 FPS 결과가 같아야 한다", 0.001)
	t.assert_vec_almost_eq(at_60, at_120, "60 FPS와 120 FPS 결과가 같아야 한다", 0.001)


## 불규칙한 delta(프레임 끊김)에서도 같아야 한다. 고정 delta만 테스트하면 놓친다.
func _test_frame_independence_diagonal(t: TestCase) -> void:
	var velocity := Movement.desired_velocity(Vector2(1, 1), SPEED)

	var steady := _simulate(velocity, 1.0 / 60.0, 60)

	# 합이 1.0초인 들쭉날쭉한 delta 열
	var jittery := Vector2.ZERO
	var deltas := [0.008, 0.033, 0.016, 0.004, 0.05, 0.016, 0.016, 0.1, 0.007, 0.75]
	var sum := 0.0
	for d in deltas:
		jittery = Movement.step(jittery, velocity, d)
		sum += d
	t.assert_almost_eq(sum, 1.0, "테스트용 delta 합이 1초여야 한다", 0.0001)

	t.assert_vec_almost_eq(jittery, steady, "불규칙 delta에서도 이동 거리가 같아야 한다", 0.001)


func _simulate(velocity: Vector2, delta: float, steps: int) -> Vector2:
	var position := Vector2.ZERO
	for i in steps:
		position = Movement.step(position, velocity, delta)
	return position
