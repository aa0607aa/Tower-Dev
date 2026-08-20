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
	_test_envelope_blocks_route(t, def)
	_test_fallback_stays_inside_envelope(t, def)
	_test_ai_trust_boundary(t, def, env)


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

	# `P2-REV-002` — 여기 있던 `p1.key() != p2.key() or true`는 **어떤 구현에서도 통과**했다.
	# `or true`가 붙어 회귀 방지 효과가 전혀 없었다.
	#
	# 검사하려던 성질은 "party_id가 RNG key에 실제로 참여하는가"다.
	# 단, 서로 다른 파티가 **우연히 같은 좌표를 받을 수 있다**는 게 canon이므로
	# 한 시드에서 다르길 요구하면 안 된다. 여러 시드 표본에서 통계적으로 본다.
	var differ := 0
	for s in SEED_COUNT:
		var a: WorldAnchor = _resolve(def, env, s * 13 + 1, &"party_1")["anchor"]
		var b: WorldAnchor = _resolve(def, env, s * 13 + 1, &"party_2")["anchor"]
		if a.key() != b.key():
			differ += 1
	t.assert_true(differ > 0,
		"party_id가 계단 RNG key에 참여해야 한다 (시드 %d개 중 다른 결과 %d건)"
		% [SEED_COUNT, differ])

	# 파티를 바꿔도 **같은 파티 + 같은 시드**는 여전히 결정적이어야 한다.
	for party in [&"party_1", &"party_2"]:
		var x: WorldAnchor = _resolve(def, env, 777, party)["anchor"]
		var y: WorldAnchor = _resolve(def, env, 777, party)["anchor"]
		t.assert_true(x.equals(y), "%s 는 같은 시드에서 항상 같아야 한다" % party)


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

	func rank(projection: Array) -> Dictionary:
		var out := {}
		for p in projection:
			# `P2-REV-005` 이후 AI는 원시값 사본만 받는다 — `anchor` 객체는 오지 않는다.
			out[(p as Dictionary)["candidate_id"]] = 1000.0 / maxf(1.0, float((p as Dictionary)["cost"]))
		return out


## `P2-REV-001` — 경로 계산이 허용 영역을 존중해야 한다.
##
## 허용 영역 한가운데를 세로로 막아 **지형상으로는 이어져 있지만 허용 영역 안에서는 끊긴**
## 상황을 만든다. envelope을 무시하고 BFS를 돌리면 막힌 띠를 지나 반대편까지
## 도달 가능하다고 오판하고, 그쪽에 계단을 놓아 층을 나갈 수 없게 만든다.
##
## 1층 `envelope_from_floor()`는 통행 가능 칸 전체를 허용하므로 기존 테스트로는
## 이 증상이 드러나지 않는다. 그래서 여기서 인위적으로 구멍을 낸다.
func _test_envelope_blocks_route(t: TestCase, def: FloorDefinition) -> void:
	var env := AccessService.envelope_from_floor(&"player", def)
	var bounds := def.bounds

	# 맵을 동/서로 가르는 차단 띠. 대각 이동이 없으므로 폭 1이면 충분하지만
	# 넉넉히 3칸을 막아 우회로가 없게 한다.
	var band_x := bounds.position.x + bounds.size.x / 2
	for x in range(band_x - 1, band_x + 2):
		for y in range(bounds.position.y, bounds.position.y + bounds.size.y + 1):
			env.deny_cell(Vector2i(x, y))

	# 띠 서쪽에 있는 시작점만 쓴다.
	var start := Vector2i(-1, -1)
	for sp in def.start_points:
		if sp.x < band_x - 1 and def.is_walkable(sp):
			start = sp
			break
	t.assert_true(start.x >= 0, "차단 띠 서쪽에 시작점 후보가 있어야 한다 (테스트 전제)")
	if start.x < 0:
		return

	# 허용 영역을 존중한 경로 — 띠 동쪽에는 닿을 수 없어야 한다.
	var route := StairResolver._route_costs_from(def, start, env)
	var east_in_route := 0
	for cell in route.keys():
		if (cell as Vector2i).x > band_x + 1:
			east_in_route += 1
	t.assert_eq(east_in_route, 0,
		"차단 띠 너머는 경로에 들어오면 안 된다 (들어온 칸 %d개)" % east_in_route)

	# 지형만 보면 여전히 이어져 있어야 한다 — 그래야 이 테스트가 의미가 있다.
	var terrain_route := StairResolver._route_costs_from(def, start)
	var east_in_terrain := 0
	for cell in terrain_route.keys():
		if (cell as Vector2i).x > band_x + 1:
			east_in_terrain += 1
	t.assert_true(east_in_terrain > 0,
		"지형 그래프로는 띠 너머가 이어져 있어야 한다 (테스트 전제, 이어진 칸 %d개)" % east_in_terrain)

	# 계단은 허용 영역 안이면서 **그 안에서 실제로 도달 가능한** 곳이어야 한다.
	for s in 20:
		var anchor: WorldAnchor = StairResolver.new().resolve_from(
			def, env, &"party_1", s * 31 + 7, start)["anchor"]
		t.assert_true(env.contains(anchor),
			"계단이 허용 영역 안이어야 한다 (%v)" % anchor.cell)
		t.assert_true(route.has(anchor.cell),
			"계단이 허용 영역 안에서 도달 가능해야 한다 (%v)" % anchor.cell)


## `P2-REV-001` — Hard Constraint를 만족하는 후보가 0개일 때의 fallback도
## 허용 영역 밖으로 나가면 안 된다.
##
## 허용 영역을 시작점 주변 작은 상자로 좁히면 이름 있는 공간 대부분이 밖으로 나가
## 후보가 0개가 되고 fallback 경로를 타게 된다.
func _test_fallback_stays_inside_envelope(t: TestCase, def: FloorDefinition) -> void:
	var start := def.start_points[0]
	var env := AccessEnvelope.new(&"player", def.world_id, def.world_region_ref)
	env.allow_rect(Rect2i(start - Vector2i(6, 6), Vector2i(13, 13)))

	var route := StairResolver._route_costs_from(def, start, env)
	t.assert_true(route.size() > 1, "좁은 허용 영역 안에서도 경로가 있어야 한다 (테스트 전제)")

	for s in 10:
		var stair := StairResolver.new().resolve_from(def, env, &"party_1", s * 17 + 3, start)
		var anchor: WorldAnchor = stair["anchor"]
		t.assert_true(env.contains(anchor),
			"fallback 계단도 허용 영역 안이어야 한다 (%v)" % anchor.cell)
		t.assert_true(route.has(anchor.cell),
			"fallback 계단도 도달 가능해야 한다 (%v)" % anchor.cell)


## `P2-REV-005` — AI 어댑터는 **신뢰 경계 밖**이다.
##
## 검사하는 것은 "지금 AI가 없다"가 아니라 **PHASE 2가 만든 계약이 나중에 붙을 AI에게
## 수정 가능한 신뢰 상태를 넘기지 않는가**다.
func _test_ai_trust_boundary(t: TestCase, def: FloorDefinition, env: AccessEnvelope) -> void:
	var baseline: WorldAnchor = _resolve(def, env, 4242)["anchor"]
	var route := StairResolver._route_costs(def)
	var max_cost := 0
	for c in route.values():
		max_cost = maxi(max_cost, int(c))

	# ① 후보를 직접 고치려는 랭커 — 사본만 받으므로 원본에 닿을 수 없어야 한다.
	var vandal := _VandalRanker.new()
	var r1 := StairResolver.new()
	r1.ai_ranker = vandal
	var a1: WorldAnchor = r1.resolve(def, env, &"party_1", 4242)["anchor"]
	t.assert_true(vandal.saw_anchor_object == false,
		"AI에게 WorldAnchor 객체를 넘기면 안 된다 (P2-REV-005)")
	t.assert_true(vandal.mutation_attempts > 0, "테스트 전제: 랭커가 실제로 수정을 시도했어야 한다")
	t.assert_true(route.has(a1.cell) and env.contains(a1),
		"후보 수정 시도 뒤에도 계단은 유효해야 한다 (%v)" % a1.cell)
	t.assert_true(float(route[a1.cell]) / float(max_cost) >= StairResolver.MIN_ROUTE_RATIO,
		"후보 수정 시도가 안티 스킵을 뚫으면 안 된다")

	# ② 모르는 ID·비정상 점수를 쏟아붓는 랭커
	for ranker in [_UnknownIdRanker.new(), _NaNRanker.new(), _HugeScoreRanker.new(), _GarbageRanker.new()]:
		var r := StairResolver.new()
		r.ai_ranker = ranker
		var a: WorldAnchor = r.resolve(def, env, &"party_1", 4242)["anchor"]
		t.assert_true(route.has(a.cell), "%s 이후에도 계단이 도달 가능해야 한다" % ranker.label)
		t.assert_true(env.contains(a), "%s 이후에도 계단이 허용 영역 안이어야 한다" % ranker.label)
		t.assert_true(float(route[a.cell]) / float(max_cost) >= StairResolver.MIN_ROUTE_RATIO,
			"%s 이후에도 안티 스킵이 지켜져야 한다" % ranker.label)

	# ③ 모르는 ID만 주는 랭커는 **아무 영향이 없어야** 한다 — 결과가 AI 없을 때와 같다.
	var r_unknown := StairResolver.new()
	r_unknown.ai_ranker = _UnknownIdRanker.new()
	var a_unknown: WorldAnchor = r_unknown.resolve(def, env, &"party_1", 4242)["anchor"]
	t.assert_true(a_unknown.equals(baseline),
		"모르는 ID만 반환하면 엔진 단독 결과와 같아야 한다")

	# ④ 랭커가 예외를 던져도 계단은 나와야 한다 (`SYS-007`).
	var r_throw := StairResolver.new()
	r_throw.ai_ranker = _NotARankerAtAll.new()
	var a_throw: WorldAnchor = r_throw.resolve(def, env, &"party_1", 4242)["anchor"]
	t.assert_true(a_throw.equals(baseline),
		"rank() 없는 객체는 AI 없음과 같이 처리돼야 한다")


## 넘겨받은 후보를 직접 고치려 든다. 사본만 받으므로 원본에 닿을 수 없어야 한다.
class _VandalRanker:
	extends RefCounted
	var label := "후보 훼손 랭커"
	var saw_anchor_object := false
	var mutation_attempts := 0

	func rank(projection: Array) -> Dictionary:
		for p in projection:
			for k in (p as Dictionary):
				if typeof((p as Dictionary)[k]) == TYPE_OBJECT:
					saw_anchor_object = true
			# 사본을 마음껏 망가뜨려본다 — 원본에 반영되면 안 된다
			(p as Dictionary)["cost"] = 0
			(p as Dictionary)["engine_score"] = 9999.0
			(p as Dictionary)["cell_x"] = -99999
			mutation_attempts += 1
		return {}


class _UnknownIdRanker:
	extends RefCounted
	var label := "모르는 ID 랭커"
	func rank(_projection: Array) -> Dictionary:
		return {"없는키/없음/0,0@0": 1000.0, "another/bogus/1,1@0": -1000.0}


class _NaNRanker:
	extends RefCounted
	var label := "NaN/INF 랭커"
	func rank(projection: Array) -> Dictionary:
		var out := {}
		for p in projection:
			out[(p as Dictionary)["candidate_id"]] = NAN if out.size() % 2 == 0 else INF
		return out


class _HugeScoreRanker:
	extends RefCounted
	var label := "거대 점수 랭커"
	func rank(projection: Array) -> Dictionary:
		var out := {}
		for p in projection:
			# 시작점에 가까울수록 극단적으로 밀어준다
			out[(p as Dictionary)["candidate_id"]] = 1.0e12 / maxf(1.0, float((p as Dictionary)["cost"]))
		return out


class _GarbageRanker:
	extends RefCounted
	var label := "쓰레기 반환 랭커"
	func rank(_projection: Array) -> Variant:
		return "나는 사전이 아니다"


class _NotARankerAtAll:
	extends RefCounted
	var label := "rank() 없음"

