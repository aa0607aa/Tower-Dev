class_name TestCase
extends RefCounted
## 최소 단언 헬퍼.
##
## D-015 원칙 2에 따라 테스트 본문이 러너에 결합되지 않도록, 러너가 아니라 이 객체에만
## 의존하게 한다. 나중에 GUT으로 옮기더라도 이 파일의 메서드 시그니처만 맞추면 된다.

var failures: Array[String] = []
var assertions: int = 0

const EPSILON := 0.00001


func _fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		_fail("%s — 참이어야 하는데 거짓" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		_fail("%s — 기대 %s, 실제 %s" % [message, expected, actual])


func assert_almost_eq(actual: float, expected: float, message: String, tolerance: float = EPSILON) -> void:
	assertions += 1
	if absf(actual - expected) > tolerance:
		_fail("%s — 기대 %f, 실제 %f (허용오차 %f)" % [message, expected, actual, tolerance])


func assert_vec_almost_eq(actual: Vector2, expected: Vector2, message: String, tolerance: float = EPSILON) -> void:
	assertions += 1
	if absf(actual.x - expected.x) > tolerance or absf(actual.y - expected.y) > tolerance:
		_fail("%s — 기대 %v, 실제 %v (허용오차 %f)" % [message, expected, actual, tolerance])
