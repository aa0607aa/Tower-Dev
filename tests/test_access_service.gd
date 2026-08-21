extends RefCounted
## P2-T4 — 행동 반경을 실제 이동에 적용한다. (`FLR-017` `FLR-024` `D-017` 4항)

const WORLD := &"w"
const REGION := &"r"
const EXILE := &"exile_a"
const CELL := 32


## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 그래서 남은 단언이 조용히 사라져도 러너에는 PASS로 보인다 — 실제로 겪었다.
## 하한을 못박아 두면 그런 유실이 실패로 드러난다.
## 단언을 **추가**할 때는 손댈 필요 없고, 의도적으로 **줄일** 때만 함께 낮춘다.
const MIN_ASSERTIONS := 29


func run(t: TestCase) -> void:
	_test_pixel_to_anchor(t)
	_test_body_blocked_outside(t)
	_test_clamp_slides_along_boundary(t)
	_test_effects_follow_causal_rule(t)
	_test_envelope_from_floor_covers_all_walkable(t)
	_test_envelope_is_not_terrain(t)
	t.done()


func _envelope() -> AccessEnvelope:
	var env := AccessEnvelope.new(EXILE, WORLD, REGION)
	env.allow_rect(Rect2i(10, 10, 10, 10))  # 셀 10..19
	return env


func _px(cell_x: float, cell_y: float) -> Vector2:
	return Vector2(cell_x * CELL + CELL / 2.0, cell_y * CELL + CELL / 2.0)


func _test_pixel_to_anchor(t: TestCase) -> void:
	var env := _envelope()
	var a := AccessService.anchor_at(env, _px(12, 15))
	t.assert_eq(a.cell, Vector2i(12, 15), "픽셀 좌표가 셀로 변환돼야 한다")
	t.assert_eq(a.world_id, WORLD, "월드 ID가 봉투에서 와야 한다")

	# 음수 좌표에서 floor가 아니라 truncate를 쓰면 -0.5가 0이 되어 경계가 한 칸 새는 버그가 난다
	var neg := AccessService.anchor_at(env, Vector2(-16, -16))
	t.assert_eq(neg.cell, Vector2i(-1, -1), "음수 좌표도 올바른 셀이어야 한다")


func _test_body_blocked_outside(t: TestCase) -> void:
	var env := _envelope()
	t.assert_true(AccessService.can_body_enter(env, _px(15, 15)), "영역 안은 진입 가능")
	t.assert_true(not AccessService.can_body_enter(env, _px(25, 15)), "영역 밖은 차단")
	t.assert_true(not AccessService.can_body_enter(env, _px(15, 25)), "영역 밖은 차단 (세로)")


## 막힌 축만 되돌린다 — 벡터 전체를 버리면 경계에 붙었을 때 이동이 통째로 멈춘 것처럼 느껴진다.
func _test_clamp_slides_along_boundary(t: TestCase) -> void:
	var env := _envelope()
	var from := _px(19, 15)          # 오른쪽 경계 칸
	var to := _px(20, 16)            # 오른쪽으로 나가면서 아래로

	var result := AccessService.clamp_move(env, from, to)
	t.assert_true(AccessService.can_body_enter(env, result), "결과는 항상 영역 안이어야 한다")

	# x는 막히고 y는 살아야 한다 → 경계를 따라 미끄러진다
	t.assert_almost_eq(result.x, from.x, "막힌 축(x)은 되돌려야 한다", 0.01)
	t.assert_almost_eq(result.y, to.y, "열린 축(y)은 살아야 한다", 0.01)

	# 완전히 막히면 제자리
	var corner_from := _px(19, 19)
	var corner_to := _px(20, 20)
	t.assert_eq(AccessService.clamp_move(env, corner_from, corner_to), corner_from,
		"두 축 모두 막히면 제자리")

	# 안쪽 이동은 그대로 통과
	t.assert_eq(AccessService.clamp_move(env, _px(12, 12), _px(13, 13)), _px(13, 13),
		"영역 안 이동은 손대지 않는다")


## ★ `D-017` 4항 — 판정 기준은 "무엇이냐"가 아니라 "누가 원인이냐"다.
func _test_effects_follow_causal_rule(t: TestCase) -> void:
	var env := _envelope()
	var outside := _px(30, 30)
	var inside := _px(15, 15)

	for kind in [CausalSource.Kind.BODY, CausalSource.Kind.SUMMON,
			CausalSource.Kind.PROJECTILE, CausalSource.Kind.EFFECT,
			CausalSource.Kind.THROWN, CausalSource.Kind.FORCED]:
		var src := CausalSource.by_exile(EXILE, kind)
		t.assert_true(not AccessService.can_effect_reach(env, src, outside),
			"유배자 인과(%s)는 경계 밖에 도달할 수 없다" % CausalSource.Kind.keys()[kind])
		t.assert_true(AccessService.can_effect_reach(env, src, inside),
			"경계 안에는 도달 가능 (%s)" % CausalSource.Kind.keys()[kind])

	# NPC·야생동물의 자발적 이동은 통과 (FLR-024)
	t.assert_true(AccessService.can_effect_reach(env, CausalSource.independent(), outside),
		"독립 월드 시뮬레이션은 경계를 통과한다")


func _test_envelope_from_floor_covers_all_walkable(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	if def == null:
		t.assert_true(false, "층 정의를 불러와야 한다")
		return

	var env := AccessService.envelope_from_floor(EXILE, def)
	var missing := 0
	for cell in def.sorted_walkable_cells():
		if not env.contains(WorldAnchor.new(def.world_id, def.world_region_ref, cell, 0)):
			missing += 1
	t.assert_eq(missing, 0, "1층의 모든 통행 셀이 행동 반경 안이어야 한다 (미포함 %d칸)" % missing)

	# 형태 수가 셀 수보다 훨씬 작아야 한다 — 아니면 와이드 맵에서 메모리가 터진다 (FLR-025)
	t.assert_true(env.region_count() + env.exception_count() < def.walkable_count(),
		"봉투가 셀을 통째로 나열하면 안 된다 (형태 %d + 예외 %d vs 셀 %d)"
		% [env.region_count(), env.exception_count(), def.walkable_count()])


## `FLR-024` — 행동 반경은 지형이 아니다. 둘을 같은 것으로 굳히면
## "경계 밖에도 실제 세계가 있다"(`FLR-023`)를 표현할 수 없게 된다.
func _test_envelope_is_not_terrain(t: TestCase) -> void:
	var env := AccessEnvelope.new(EXILE, WORLD, REGION)
	t.assert_true(not (env as Object).has_method("is_walkable"),
		"AccessEnvelope가 지형 통행 여부를 판정하면 안 된다")
	t.assert_true(not (env as Object).has_method("record"),
		"AccessEnvelope가 지형 변경을 기록하면 안 된다")

	# 봉투는 지형보다 넓을 수도 좁을 수도 있어야 한다 — 2층 이후에는 실제로 그렇다
	env.allow_rect(Rect2i(0, 0, 5, 5))
	t.assert_true(env.contains(WorldAnchor.new(WORLD, REGION, Vector2i(2, 2), 0)),
		"지형과 무관하게 봉투 자체로 판정된다")
