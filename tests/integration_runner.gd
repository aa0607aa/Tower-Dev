extends SceneTree
## 통합 테스트 러너 — 실제 물리가 필요한 검증용 (D-015).
##
## 실행:
##   godot --headless --path . --script res://tests/integration_runner.gd
##
## `runner.gd`(단위)와 나눈 이유: 단위 테스트는 노드 없이 한 프레임에 끝나지만
## 충돌 검증은 **물리 프레임을 실제로 여러 번 돌려야** 한다. 하나의 러너에 두 성격을 넣으면
## 러너가 비동기/생명주기를 알아야 해서 D-015 원칙 1(러너는 발견·실행·집계·종료만)을 깬다.
##
## 이 러너도 실패 시 non-zero로 종료한다. (원칙 4)
##
## ⚠ 이 테스트를 쓸 때 주의:
## "경계를 넘지 않았다"만 단언하면 **엉뚱한 장애물에 막혀도 통과한다.**
## 초기 구현이 실제로 그랬다 — 오른쪽 벽(x=950) 테스트가 안쪽 블록(x=608)에 막혀 x=598에서
## 멈췄는데 `x <= 950`이 참이라 통과했다. 그래서 각 케이스는
## **목표 벽에 실제로 도달했는지(근접했는지)** 도 함께 단언한다.

const ROOM_SCENE := "res://scenes/world/TestRoom.tscn"
const PLAYER_SCENE := "res://scenes/player/Player.tscn"

## 벽으로 밀어붙일 물리 프레임 수. 60프레임 = 1초. 방을 가로지르기 충분하게 잡는다.
const PUSH_FRAMES := 150
const PUSH_SPEED := 400.0

## 플레이어 충돌 박스 반폭 (Player.tscn의 RectangleShape2D 20x20).
const HALF_EXTENT := 10.0
## 벽에 "닿았다"고 볼 허용 오차.
const CONTACT_TOLERANCE := 2.0

var _t: TestCase
var _player: CharacterBody2D
var _frames := 0
var _phase := 0
var _cases: Array = []


func _initialize() -> void:
	_t = TestCase.new()

	var room: Node2D = (load(ROOM_SCENE) as PackedScene).instantiate()
	root.add_child(room)

	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	root.add_child(_player)

	# 방 내부는 (0,0)~(960,640). 안쪽 장애물:
	#   BlockH   x 224..352, y 176..208
	#   BlockV   x 608..640, y 320..480
	#   BlockSq  x 160..256, y 448..544
	# 각 케이스의 출발점은 목표 벽까지 **장애물이 없는 경로**로 고른다.
	_cases = [
		{
			"name": "왼쪽 벽",
			"start": Vector2(480, 64),   # y=64는 모든 블록 위쪽
			"dir": Vector2.LEFT,
			"axis": "x", "expected": 0.0 + HALF_EXTENT, "limit_is_min": true,
		},
		{
			"name": "오른쪽 벽",
			"start": Vector2(480, 64),
			"dir": Vector2.RIGHT,
			"axis": "x", "expected": 960.0 - HALF_EXTENT, "limit_is_min": false,
		},
		{
			"name": "위쪽 벽",
			"start": Vector2(480, 320),  # x=480은 모든 블록 사이
			"dir": Vector2.UP,
			"axis": "y", "expected": 0.0 + HALF_EXTENT, "limit_is_min": true,
		},
		{
			"name": "아래쪽 벽",
			"start": Vector2(480, 320),
			"dir": Vector2.DOWN,
			"axis": "y", "expected": 640.0 - HALF_EXTENT, "limit_is_min": false,
		},
		{
			# 안쪽 장애물도 막아야 한다. 벽만 테스트하면 블록 충돌이 깨져도 모른다.
			"name": "안쪽 블록",
			"start": Vector2(480, 400),  # BlockV(x 608..640, y 320..480)를 향해 오른쪽으로
			"dir": Vector2.RIGHT,
			"axis": "x", "expected": 608.0 - HALF_EXTENT, "limit_is_min": false,
		},
	]

	print("=== 통합 테스트 시작 (%d 케이스) ===" % _cases.size())
	_begin_phase()


func _begin_phase() -> void:
	_player.global_position = _cases[_phase]["start"]
	_player.velocity = Vector2.ZERO
	_frames = 0


func _physics_process(_delta: float) -> bool:
	# 플레이어의 _physics_process가 입력을 읽어 velocity를 덮어쓰므로,
	# 여기서는 입력 대신 velocity를 직접 실어 move_and_slide를 돌린다.
	_player.velocity = (_cases[_phase]["dir"] as Vector2) * PUSH_SPEED
	_player.move_and_slide()

	_frames += 1
	if _frames < PUSH_FRAMES:
		return false

	_evaluate_phase()

	_phase += 1
	if _phase < _cases.size():
		_begin_phase()
		return false

	_report()
	return true


func _evaluate_phase() -> void:
	var case: Dictionary = _cases[_phase]
	var pos: Vector2 = _player.global_position
	var actual: float = pos.x if case["axis"] == "x" else pos.y
	var expected: float = case["expected"]
	var name: String = case["name"]

	# ① 경계를 넘지 않았는가 (뚫고 지나가지 않았는가)
	var not_passed: bool = actual >= expected - CONTACT_TOLERANCE if case["limit_is_min"] \
		else actual <= expected + CONTACT_TOLERANCE
	_t.assert_true(not_passed, "%s을 통과하지 못해야 한다 (기대 %.1f, 실제 %.1f)" % [name, expected, actual])

	# ② 그 벽까지 실제로 도달했는가 — 이게 없으면 엉뚱한 장애물에 막혀도 통과한다
	_t.assert_almost_eq(actual, expected, "%s에 실제로 닿아야 한다" % name, CONTACT_TOLERANCE)

	if not_passed and absf(actual - expected) <= CONTACT_TOLERANCE:
		print("  PASS  %-10s %s=%.2f (기대 %.1f)" % [name, case["axis"], actual, expected])
	else:
		print("  FAIL  %-10s %s=%.2f (기대 %.1f)" % [name, case["axis"], actual, expected])


func _report() -> void:
	print("=== 결과 ===")
	print("  단언 %d · 실패 %d" % [_t.assertions, _t.failures.size()])
	if _t.failures.is_empty():
		print("  전부 통과")
		quit(0)
		return
	printerr("실패 목록:")
	for f in _t.failures:
		printerr("  - %s" % f)
	quit(1)
