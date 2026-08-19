extends RefCounted
## 월드 공간 데이터 책임 경계 — P2-T1 완료 조건.
##
## 핵심 단언: **같은 좌표의 물리 상태가 유배자 ID에 따라 복제되지 않는다.** (`FLR-024`)
## 이게 깨지면 "층은 실제 월드의 일부"(`FLR-023`)가 플레이어별 평행 복제본으로 전락한다.

const WORLD := &"world_a"
const REGION := &"region_1"
const EXILE_A := &"exile_a"
const EXILE_B := &"exile_b"


func run(t: TestCase) -> void:
	_test_anchor_identity(t)
	_test_anchor_survives_terrain_change(t)
	_test_envelope_is_per_exile(t)
	_test_envelope_scales_to_wide_map(t)
	_test_envelope_irregular_shape(t)
	_test_terrain_is_shared(t)
	_test_causal_boundary(t)
	_test_mutation_order_is_deterministic(t)


func _anchor(x: int, y: int, layer: int = 0) -> WorldAnchor:
	return WorldAnchor.new(WORLD, REGION, Vector2i(x, y), layer)


## anchor는 값 객체다. 같은 주소면 같은 것으로 취급돼야 Dictionary 키로 쓸 수 있다.
func _test_anchor_identity(t: TestCase) -> void:
	t.assert_true(_anchor(3, 4).equals(_anchor(3, 4)), "같은 주소의 anchor는 같아야 한다")
	t.assert_true(not _anchor(3, 4).equals(_anchor(3, 5)), "다른 셀은 달라야 한다")
	# layer를 무시하면 천장 위 공동과 바닥이 같은 곳이 된다 (FAC-012)
	t.assert_true(not _anchor(3, 4, 0).equals(_anchor(3, 4, 1)), "레이어가 다르면 달라야 한다")
	t.assert_eq(_anchor(3, 4).key(), _anchor(3, 4).key(), "키가 안정적이어야 한다")


## FAC-013: 계단이 놓인 자리의 지형이 사라져도 계단의 좌표와 존재는 유지된다.
## anchor가 타일 데이터에 종속되지 않는다는 것을 구조로 확인한다.
func _test_anchor_survives_terrain_change(t: TestCase) -> void:
	var terrain := TerrainMutationState.new()
	var stair_anchor := _anchor(10, 10)

	# 계단 자리를 굴착해 없애버린다
	terrain.record(stair_anchor, TerrainMutationState.Change.EXCAVATED,
		CausalSource.by_exile(EXILE_A, CausalSource.Kind.BODY), 100)

	t.assert_true(terrain.has_mutation(stair_anchor), "굴착이 기록돼야 한다")
	# anchor 자체는 지형과 무관하게 그대로다
	t.assert_true(stair_anchor.equals(_anchor(10, 10)),
		"지형이 파괴돼도 계단 anchor는 유지돼야 한다 (FAC-013)")


## FLR-024: 행동 반경은 유배자별이다. 그리고 겹칠 수 있다.
func _test_envelope_is_per_exile(t: TestCase) -> void:
	var env_a := AccessEnvelope.new(EXILE_A, WORLD, REGION)
	env_a.allow_rect(Rect2i(0, 0, 10, 10))

	var env_b := AccessEnvelope.new(EXILE_B, WORLD, REGION)
	env_b.allow_rect(Rect2i(5, 5, 10, 10))  # A와 겹친다

	t.assert_true(env_a.contains(_anchor(1, 1)), "A는 자기 영역 안을 포함")
	t.assert_true(not env_b.contains(_anchor(1, 1)), "B는 A만의 영역을 포함하지 않는다")

	# 겹치는 구간 — 둘 다 포함해야 한다 (FLR-024: 겹칠 수 있다)
	var overlap := _anchor(7, 7)
	t.assert_true(env_a.contains(overlap) and env_b.contains(overlap),
		"겹치는 좌표는 두 유배자 모두의 영역에 있어야 한다")

	# 경계 밖
	t.assert_true(not env_a.contains(_anchor(20, 20)), "영역 밖은 제외")


## FLR-025 와이드 맵 — 허용 영역이 커도 메모리가 셀 수에 비례하면 안 된다.
##
## 초기 구현은 허용 셀을 전부 Dictionary에 넣어서 1000×1000이면 100만 엔트리였다.
## 이 테스트는 **형태 수**로 저장되는지를 확인한다. 통과 못 하면 와이드 맵에서 메모리가 터진다.
func _test_envelope_scales_to_wide_map(t: TestCase) -> void:
	var env := AccessEnvelope.new(EXILE_A, WORLD, REGION)
	env.allow_rect(Rect2i(0, 0, 2000, 2000))  # 400만 셀

	t.assert_eq(env.region_count(), 1,
		"넓은 영역이 형태 1개로 저장돼야 한다 (셀을 나열하면 안 된다)")
	t.assert_eq(env.exception_count(), 0, "예외 셀이 없어야 한다")

	# 그래도 판정은 정확해야 한다
	t.assert_true(env.contains(_anchor(0, 0)), "좌상단 포함")
	t.assert_true(env.contains(_anchor(1999, 1999)), "우하단 포함")
	t.assert_true(env.contains(_anchor(1234, 567)), "내부 임의 지점 포함")
	t.assert_true(not env.contains(_anchor(2000, 0)), "우측 경계 밖 제외")
	t.assert_true(not env.contains(_anchor(-1, 0)), "좌측 경계 밖 제외")

	# bounding_rect는 broad-phase용이며 canon 경계가 아니다 (D-016 §1.5)
	t.assert_eq(env.bounding_rect(), Rect2i(0, 0, 2000, 2000), "AABB가 형태를 감싸야 한다")


## 불규칙한 형태 — 사각형 여러 개 + 구멍 + 돌출.
## 와이드 맵이 단순 사각형일 리 없으므로 이게 되어야 실전에서 쓸 수 있다.
func _test_envelope_irregular_shape(t: TestCase) -> void:
	var env := AccessEnvelope.new(EXILE_A, WORLD, REGION)
	env.allow_rect(Rect2i(0, 0, 10, 10))
	env.allow_rect(Rect2i(20, 0, 10, 10))   # 떨어진 두 번째 영역
	env.deny_cell(Vector2i(5, 5))            # 첫 영역 안의 구멍
	env.allow_cell(Vector2i(100, 100))       # 어느 사각형에도 없는 숨은 공간

	t.assert_eq(env.region_count(), 2, "사각형 2개")

	t.assert_true(env.contains(_anchor(1, 1)), "첫 영역 포함")
	t.assert_true(env.contains(_anchor(25, 5)), "둘째 영역 포함")
	t.assert_true(not env.contains(_anchor(15, 5)), "두 영역 사이는 제외")

	# 구멍이 사각형보다 우선해야 한다
	t.assert_true(not env.contains(_anchor(5, 5)), "구멍은 제외돼야 한다 (deny가 우선)")
	t.assert_true(env.contains(_anchor(5, 6)), "구멍 옆은 여전히 포함")

	# FAC-012: 계단이 정상 바닥이 아닌 숨은 공간에도 놓일 수 있으므로 돌출이 필요하다
	t.assert_true(env.contains(_anchor(100, 100)), "사각형 밖 개별 허용 셀 포함")

	# 레이어 — 천장 위/지하
	env.allow_layers(-1, 2)
	t.assert_true(env.contains(_anchor(1, 1, 2)), "허용 레이어 안")
	t.assert_true(env.contains(_anchor(1, 1, -1)), "지하 레이어 안")
	t.assert_true(not env.contains(_anchor(1, 1, 3)), "허용 레이어 밖 제외")


## ★ P2-T1 핵심 — 물리 상태는 월드가 소유하고 유배자별로 복제되지 않는다.
func _test_terrain_is_shared(t: TestCase) -> void:
	# 월드가 지형 상태를 하나만 가진다
	var world_terrain := TerrainMutationState.new()

	var env_a := AccessEnvelope.new(EXILE_A, WORLD, REGION)
	env_a.allow_rect(Rect2i(0, 0, 10, 10))
	var env_b := AccessEnvelope.new(EXILE_B, WORLD, REGION)
	env_b.allow_rect(Rect2i(5, 5, 10, 10))

	var shared_cell := _anchor(7, 7)
	t.assert_true(env_a.contains(shared_cell) and env_b.contains(shared_cell),
		"전제: 두 유배자의 영역이 이 좌표에서 겹친다")

	# A가 벽을 부순다
	world_terrain.record(shared_cell, TerrainMutationState.Change.BREACHED,
		CausalSource.by_exile(EXILE_A, CausalSource.Kind.BODY), 42)

	# B도 같은 결과를 본다 — 조회에 유배자 ID가 끼어들 자리가 없다
	t.assert_true(world_terrain.has_mutation(shared_cell),
		"B도 A가 부순 결과를 봐야 한다 (FLR-024 물리 상태 공유)")
	t.assert_eq(world_terrain.mutation_count(), 1,
		"같은 좌표의 변경이 유배자 수만큼 복제되면 안 된다")

	# 구조적 보장: AccessEnvelope에는 지형 상태를 담을 자리가 없다.
	# 있으면 언젠가 거기에 복제본이 생긴다.
	t.assert_true(not (env_a as Object).has_method("record"),
		"AccessEnvelope가 지형 변경을 기록할 수 있으면 안 된다 (소유권 경계)")
	t.assert_true(not (env_a as Object).has_method("has_mutation"),
		"AccessEnvelope가 지형 상태를 보유하면 안 된다")


## D-017 4항 Hard Rule — 유배자 인과는 경계를 못 넘고, 독립 시뮬레이션은 넘는다.
func _test_causal_boundary(t: TestCase) -> void:
	var env := AccessEnvelope.new(EXILE_A, WORLD, REGION)
	env.allow_rect(Rect2i(0, 0, 10, 10))

	var inside := _anchor(5, 5)
	var outside := _anchor(50, 50)

	# 유배자 인과 — 전부 막힌다
	for kind in [CausalSource.Kind.BODY, CausalSource.Kind.SUMMON,
			CausalSource.Kind.PROJECTILE, CausalSource.Kind.EFFECT,
			CausalSource.Kind.THROWN, CausalSource.Kind.FORCED]:
		var src := CausalSource.by_exile(EXILE_A, kind)
		t.assert_true(not env.can_cross(src, outside),
			"유배자 인과(%s)는 경계를 넘을 수 없다" % CausalSource.Kind.keys()[kind])
		t.assert_true(env.can_cross(src, inside),
			"경계 안으로는 통과 가능해야 한다 (%s)" % CausalSource.Kind.keys()[kind])

	# 독립 월드 시뮬레이션 — 자유 통과
	var independent := CausalSource.independent()
	t.assert_true(env.can_cross(independent, outside),
		"NPC·야생동물의 자발적 이동은 경계를 통과한다 (FLR-024)")

	# 같은 NPC라도 유배자가 밀치는 중이면 못 넘는다 — 판정 기준이 "누가 원인인가"임을 확인
	var forced := CausalSource.by_exile(EXILE_A, CausalSource.Kind.FORCED)
	t.assert_true(not env.can_cross(forced, outside),
		"유배자가 강제 이동시키는 NPC는 경계를 넘을 수 없다")


## SYS-003: 저장/비교가 Dictionary 순회 순서에 의존하면 같은 상태가 다른 세이브를 만든다.
func _test_mutation_order_is_deterministic(t: TestCase) -> void:
	var a := TerrainMutationState.new()
	var b := TerrainMutationState.new()
	var src := CausalSource.independent()

	# 같은 변경을 다른 순서로 넣는다
	a.record(_anchor(1, 1), TerrainMutationState.Change.EXCAVATED, src, 1)
	a.record(_anchor(9, 9), TerrainMutationState.Change.COLLAPSED, src, 2)
	a.record(_anchor(5, 5), TerrainMutationState.Change.BREACHED, src, 3)

	b.record(_anchor(5, 5), TerrainMutationState.Change.BREACHED, src, 3)
	b.record(_anchor(1, 1), TerrainMutationState.Change.EXCAVATED, src, 1)
	b.record(_anchor(9, 9), TerrainMutationState.Change.COLLAPSED, src, 2)

	var ra := a.to_sorted_records()
	var rb := b.to_sorted_records()
	t.assert_eq(ra.size(), rb.size(), "기록 수가 같아야 한다")
	for i in ra.size():
		t.assert_eq((ra[i]["anchor"] as WorldAnchor).key(), (rb[i]["anchor"] as WorldAnchor).key(),
			"삽입 순서가 달라도 정렬 결과는 같아야 한다 (%d번째)" % i)
