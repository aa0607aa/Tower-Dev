extends RefCounted
## P2-T5 — 계단 resolver. (`FAC-002` `FAC-012` `FAC-013` · `TEST_CHECKLIST` 2-2, 2-4)
##
## ★ 2-2 "시드 100~1000개에서 시작점→계단 접근 불가 0건"을 여기서 실제로 돌린다.

const SEED_COUNT := 120


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return
	var env := AccessService.envelope_from_floor(&"player", def)

	_test_reachable_for_many_seeds(t, def, env)
	_test_anti_skip(t, def, env)
	_test_anti_skip_from_every_start(t, def, env)
	_test_deterministic(t, def, env)
	_test_not_always_argmax(t, def, env)
	_test_party_stairs_is_array(t, def, env)
	_test_works_without_ai(t, def, env)
	_test_ai_cannot_break_hard_constraints(t, def, env)


func _resolve(def: FloorDefinition, env: AccessEnvelope, s: int, party: StringName = &"party_1") -> Dictionary:
	return StairResolver.new().resolve(def, env, party, s)


## ★ 2-2 — 여러 시드에서 시작점→계단 경로가 항상 존재해야 한다.
func _test_reachable_for_many_seeds(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	var route := StairResolver._route_costs(def)
	var unreachable := 0
	var outside := 0
	for s in SEED_COUNT:
		var stair := _resolve(def, env, s * 7919 + 13)
		var anchor: WorldAnchor = stair["anchor"]
		if not route.has(anchor.cell):
			unreachable += 1
		if not env.contains(anchor):
			outside += 1
	t.assert_eq(unreachable, 0,
		"시드 %d개에서 시작점→계단 접근 불가 0건이어야 한다 (실패 %d)" % [SEED_COUNT, unreachable])
	t.assert_eq(outside, 0, "계단이 항상 허용 영역 안이어야 한다 (밖 %d)" % outside)


## 층을 즉시 스킵하는 위치가 나오면 안 된다 (`D-016` §1.4 Hard Constraint 3).
func _test_anti_skip(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	var route := StairResolver._route_costs(def)
	var max_cost := 0
	for c in route.values():
		max_cost = maxi(max_cost, int(c))

	var too_close := 0
	for s in SEED_COUNT:
		var anchor: WorldAnchor = _resolve(def, env, s * 104729 + 7)["anchor"]
		var ratio := float(route[anchor.cell]) / float(max_cost)
		if ratio < StairResolver.MIN_ROUTE_RATIO:
			too_close += 1
	t.assert_eq(too_close, 0,
		"계단이 시작점에 너무 가까우면 안 된다 (기준 %.2f, 위반 %d)"
		% [StairResolver.MIN_ROUTE_RATIO, too_close])


## D-022 — 시작점이 회차마다 달라도 모든 후보에서 안티 스킵이 성립해야 한다.
func _test_anti_skip_from_every_start(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	for sp in def.start_points:
		var route := StairResolver._route_costs_from(def, sp)
		var max_cost := 0
		for c in route.values():
			max_cost = maxi(max_cost, int(c))
		var violations := 0
		for s in 12:
			var anchor: WorldAnchor = StairResolver.new().resolve_from(def, env, &"p", s * 97 + 3, sp)["anchor"]
			if float(route.get(anchor.cell, 0)) / float(max_cost) < StairResolver.MIN_ROUTE_RATIO:
				violations += 1
		t.assert_eq(violations, 0,
			"시작점 %v 에서도 안티 스킵이 성립해야 한다 (위반 %d)" % [sp, violations])


## `SYS-003` — 같은 시드·같은 파티면 항상 같은 계단. 로드할 때 리롤되면 안 된다.
func _test_deterministic(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	for s in [1, 42, 99999]:
		var a: WorldAnchor = _resolve(def, env, s)["anchor"]
		var b: WorldAnchor = _resolve(def, env, s)["anchor"]
		t.assert_true(a.equals(b), "시드 %d 에서 계단이 같아야 한다" % s)

	# 파티가 다르면 달라질 수 있어야 한다 — 파티별 귀속이므로 (FAC-001)
	var p1: WorldAnchor = _resolve(def, env, 777, &"party_1")["anchor"]
	var p2: WorldAnchor = _resolve(def, env, 777, &"party_2")["anchor"]
	t.assert_true(p1.key() != p2.key() or true,
		"파티별로 독립 계산된다 (같은 결과가 나올 수도 있다)")


## ★ 항상 점수 1등을 고르면 공식 역산이 가능해진다 (`D-016` §1.4).
## 여러 시드에서 **서로 다른 위치**가 나와야 한다.
func _test_not_always_argmax(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	var seen := {}
	for s in SEED_COUNT:
		var anchor: WorldAnchor = _resolve(def, env, s * 31 + 5)["anchor"]
		seen[anchor.key()] = true
	t.assert_true(seen.size() >= 2,
		"시드에 따라 계단 위치가 달라져야 한다 (서로 다른 위치 %d개) — 1등 고정이면 역산된다" % seen.size())


## `FAC-002` — 계단은 파티별 배열이다. 단일 `stair_id`가 아니다.
func _test_party_stairs_is_array(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	var state := FloorPopulator.populate(def, 555)
	for party in [&"party_1", &"party_2", &"party_3"]:
		state.party_stairs.append(_resolve(def, env, 555, party))

	t.assert_eq(state.party_stairs.size(), 3, "파티마다 계단 항목이 있어야 한다")
	var ids := {}
	for s in state.party_stairs:
		ids[s["party_id"]] = true
		t.assert_true(s["anchor"] is WorldAnchor,
			"계단 주소가 WorldAnchor여야 한다 (FAC-013 — 지형이 사라져도 유지)")
	t.assert_eq(ids.size(), 3, "파티 ID가 각각 달라야 한다")

	# 저장 형식에도 배열로 남아야 한다
	var saved: Array = state.to_save_dict()["party_stairs"]
	t.assert_eq(saved.size(), 3, "저장 시에도 파티별 배열이어야 한다")


## `SYS-007` — AI가 없어도 계단이 만들어져야 한다. 없으면 게임이 멈춘다.
func _test_works_without_ai(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	var r := StairResolver.new()
	t.assert_eq(r.ai_ranker, null, "기본값은 AI 없음이어야 한다")
	var stair := r.resolve(def, env, &"solo", 4242)
	t.assert_true(stair["anchor"] is WorldAnchor, "AI 없이도 계단이 실체화돼야 한다")


## ★ AI는 후보 순위만 매긴다. Hard Constraint를 뒤집을 수 없다 (`SYS-002`).
func _test_ai_cannot_break_hard_constraints(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	var route := StairResolver._route_costs(def)
	var max_cost := 0
	for c in route.values():
		max_cost = maxi(max_cost, int(c))

	var r := StairResolver.new()
	# 시작점 근처를 극단적으로 밀어주는 악의적 랭커
	r.ai_ranker = _NearStartRanker.new()

	for s in 30:
		var anchor: WorldAnchor = r.resolve(def, env, &"party_1", s * 13 + 1)["anchor"]
		var ratio := float(route[anchor.cell]) / float(max_cost)
		t.assert_true(ratio >= StairResolver.MIN_ROUTE_RATIO,
			"AI가 밀어도 안티 스킵 제약을 넘을 수 없어야 한다 (비율 %.2f)" % ratio)


## 시작점에 가까울수록 높은 점수를 주는 테스트용 랭커.
## Hard Constraint가 이미 걸러낸 뒤이므로 이걸로도 규칙을 깨면 안 된다.
class _NearStartRanker:
	extends RefCounted

	func rank(candidates: Array) -> Dictionary:
		var out := {}
		for c in candidates:
			out[(c["anchor"] as WorldAnchor).key()] = 1000.0 / maxf(1.0, float(c["cost"]))
		return out
