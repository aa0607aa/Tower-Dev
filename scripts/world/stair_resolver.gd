class_name StairResolver
extends RefCounted
## 계단 배치 — "공정한 악의". (`FAC-012` `FAC-013` · `D-016` §1.4)
##
## 층 진입 시 **한 번** 계산한다. 고정 후보표에서 고르지 않는다.
##
## ## 파이프라인
## ```
## 엔진 후보 생성 → Hard Constraint → 엔진 점수 → (선택) AI ranking
##   → Validator 재검증 → 상위 밴드 seed 선택 → WorldAnchor 실체화
## ```
##
## ## AI는 권한자가 아니라 보조자다 (`SYS-002` `SYS-007`)
## AI는 **엔진이 만든 합법 후보의 순위만** 매긴다. 좌표를 새로 만들거나 GameState에 쓰지 않는다.
## AI가 없거나 실패하면 엔진 점수만으로 끝까지 진행한다 — 계단이 안 생기면 게임이 멈추므로
## AI를 필수 의존성으로 만들 수 없다. PHASE 2는 no-op 어댑터를 쓰고 PHASE 9에서 붙인다.
##
## ## 1등을 항상 고르지 않는다
## 점수 최고점 하나를 고정하면 **공식 역산이 가능**해지고 매 회차 같은 유형이 반복된다.
## Hard Constraint를 통과한 상위 밴드에서 시드 기반으로 뽑는다.
##
## ## 아직 없는 것
## 스토리 그래프·POI·지형 굴착 비용은 PHASE 2 범위 밖이다(`B-007`, PHASE 9).
## 지금 점수는 **경로 거리·발견 난이도·안티 스킵**만 본다. 가중치는 DESIGN이며 튜닝 대상이다.

## Hard Constraint — 시작점에서 최소 이 비율만큼 떨어져야 한다.
## 층을 즉시 스킵하는 위치를 막는다 (`D-016` §1.4 Hard Constraint 3).
const MIN_ROUTE_RATIO := 0.55
## 상위 몇 %를 밴드로 볼 것인가. DESIGN.
const TOP_BAND_RATIO := 0.20
## 밴드 최소 크기 — 너무 작으면 사실상 argmax가 된다.
const MIN_BAND := 3


## 후보 순위를 매기는 선택적 보조자. PHASE 9에서 AI 어댑터가 이 자리에 들어온다.
## `rank(candidates) -> Dictionary[anchor_key -> float]`를 가지면 된다.
var ai_ranker: Object = null


## 층 진입 시 계단을 실체화한다.
##
## `party_id`별로 하나씩 만든다 — 단일 `stair_id`가 아니다 (`FAC-002`).
func resolve(def: FloorDefinition, envelope: AccessEnvelope,
		party_id: StringName, generation_seed: int) -> Dictionary:
	var start := def.start_points[0] if not def.start_points.is_empty() else Vector2i.ZERO
	return resolve_from(def, envelope, party_id, generation_seed, start)


## 시작점을 명시해 계단을 계산한다.
##
## `D-022`로 시작점이 회차마다 달라지므로, 계단의 안티 스킵 판정도
## **그 회차의 실제 시작점**을 기준으로 해야 한다.
## 고정 시작점을 쓰면 어떤 회차에서는 코앞에 계단이 놓인다.
func resolve_from(def: FloorDefinition, envelope: AccessEnvelope,
		party_id: StringName, generation_seed: int, start: Vector2i) -> Dictionary:
	# 경로는 **허용 영역 안에서만** 계산한다 (`P2-REV-001`).
	var route := _route_costs_from(def, start, envelope)
	var candidates := _generate_candidates(def, envelope, route)
	candidates = _apply_hard_constraints(def, envelope, candidates, route)

	if candidates.is_empty():
		# 소프트락 방지: 제약을 만족하는 후보가 없으면 가장 먼 도달 가능 지점으로 떨어진다.
		# 계단이 없으면 층을 나갈 수 없으므로 실패해서는 안 된다.
		push_warning("계단 Hard Constraint를 만족하는 후보가 없다 — 최장거리 지점으로 대체")
		candidates = _fallback_candidates(def, route, envelope)

	for c in candidates:
		c["score"] = _engine_score(c, route)

	# 선택적 AI ranking. 실패하거나 없으면 건너뛴다 (`SYS-007`).
	if ai_ranker != null and ai_ranker.has_method("rank"):
		var ranks: Variant = ai_ranker.call("rank", candidates)
		if typeof(ranks) == TYPE_DICTIONARY:
			for c in candidates:
				var key: String = (c["anchor"] as WorldAnchor).key()
				if (ranks as Dictionary).has(key):
					# AI 점수는 가산일 뿐 Hard Constraint를 뒤집지 못한다.
					c["score"] = float(c["score"]) + float((ranks as Dictionary)[key])

	# 점수 내림차순. 동점은 anchor 키로 갈라 **순서를 결정적으로** 만든다 (`SYS-003`).
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a["score"], b["score"]):
			return a["score"] > b["score"]
		return (a["anchor"] as WorldAnchor).key() < (b["anchor"] as WorldAnchor).key())

	var band_size := maxi(MIN_BAND, int(ceil(candidates.size() * TOP_BAND_RATIO)))
	band_size = mini(band_size, candidates.size())

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d/stair/%s/%s" % [generation_seed, def.floor_id, party_id])
	var picked: Dictionary = candidates[rng.randi_range(0, band_size - 1)]

	return {
		"party_id": party_id,
		"anchor": picked["anchor"],
		"discovered_by": [],
	}


## 시작점에서 각 셀까지의 경로 비용 (BFS). 유클리드 거리가 아니라 **실제 경로**를 본다 —
## 벽 하나 너머는 가까워 보여도 돌아가야 한다.
static func _route_costs(def: FloorDefinition) -> Dictionary:
	if def.start_points.is_empty():
		return {}
	return _route_costs_from(def, def.start_points[0])


## 주어진 시작점에서 각 셀까지의 경로 비용 (BFS).
##
## `envelope`을 주면 **허용 영역 안의 칸만 통과**한다 (`P2-REV-001`).
## 주지 않으면 지형만 본다 — 지형 그래프 자체를 볼 때 쓴다.
##
## 왜 중요한가: envelope을 무시하면 **경계 밖으로 나갔다 돌아와야만 닿는 곳**을
## 도달 가능하다고 오판한다. 1층은 허용 영역이 통행 가능 칸 전체라 증상이 가려져 있지만,
## 2층부터는 월드의 일부만 허용되므로(`FLR-023`) 계단이 실제로 못 가는 곳에 생길 수 있다.
static func _route_costs_from(def: FloorDefinition, start: Vector2i,
		envelope: AccessEnvelope = null) -> Dictionary:
	var costs := {}
	if not _passable(def, envelope, start):
		return costs
	costs[start] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var nxt: Vector2i = cur + d
			if costs.has(nxt) or not _passable(def, envelope, nxt):
				continue
			costs[nxt] = int(costs[cur]) + 1
			queue.append(nxt)
	return costs


## 경로가 지날 수 있는 칸인가 — 지형과 **허용 영역을 모두** 본다.
static func _passable(def: FloorDefinition, envelope: AccessEnvelope, cell: Vector2i) -> bool:
	if not def.is_walkable(cell):
		return false
	if envelope == null:
		return true
	return envelope.contains(WorldAnchor.new(def.world_id, def.world_region_ref, cell, 0))


## 희소 후보 — 모든 셀을 후보로 삼지 않는다.
## 지금은 각 이름 있는 공간의 중심과 막다른 길 끝을 쓴다.
## 스토리 POI·숨은 공간은 그 시스템이 생길 때 여기에 더한다.
func _generate_candidates(def: FloorDefinition, envelope: AccessEnvelope,
		route: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for space in def.spaces:
		# 기하학적 중심이 아니라 **통행 가능한 대표 칸**을 쓴다.
		# `inner_complex`·`divisions` 구역은 중심이 구조물 안이라 공간째로 빠져버린다.
		var cell := def.space_anchor_cell(space)
		if not def.is_walkable(cell) or not route.has(cell):
			continue
		var anchor := WorldAnchor.new(def.world_id, def.world_region_ref, cell, 0)
		if not envelope.contains(anchor):
			continue
		out.append({
			"anchor": anchor,
			"space_id": space["id"],
			"kind": space["kind"],
			"cost": int(route[cell]),
			"score": 0.0,
		})
	return out


## Hard Constraint — 통과 못 하면 후보가 아니다. AI도 이걸 뒤집을 수 없다.
func _apply_hard_constraints(def: FloorDefinition, envelope: AccessEnvelope,
		candidates: Array[Dictionary], route: Dictionary) -> Array[Dictionary]:
	var max_cost := 0
	for c in route.values():
		max_cost = maxi(max_cost, int(c))
	if max_cost == 0:
		return []

	var out: Array[Dictionary] = []
	for c in candidates:
		# ① 최종 도달 가능해야 한다 — route에 있다는 것 자체가 증명이다
		if not route.has((c["anchor"] as WorldAnchor).cell):
			continue
		# ② 층을 즉시 스킵하게 만드는 위치 금지
		if float(c["cost"]) / float(max_cost) < MIN_ROUTE_RATIO:
			continue
		# ③ 허용 영역과 정합
		if not envelope.contains(c["anchor"]):
			continue
		out.append(c)
	return out


## 제약을 만족하는 후보가 하나도 없을 때. **계단이 없으면 층을 나갈 수 없으므로 실패 금지.**
## **허용 영역 밖으로는 절대 나가지 않는다** — 못 가는 곳에 계단을 놓느니
## 가까운 곳에 놓는 편이 낫다 (`P2-REV-001`).
static func _fallback_candidates(def: FloorDefinition, route: Dictionary,
		envelope: AccessEnvelope = null) -> Array[Dictionary]:
	var best_cell := Vector2i.ZERO
	var best := -1
	var cells := def.sorted_walkable_cells()
	for cell in cells:
		if not route.has(cell):
			continue
		if not _passable(def, envelope, cell):
			continue
		if int(route[cell]) > best:
			best = int(route[cell])
			best_cell = cell
	if best < 0:
		return []
	return [{
		"anchor": WorldAnchor.new(def.world_id, def.world_region_ref, best_cell, 0),
		"space_id": &"fallback",
		"kind": "fallback",
		"cost": best,
		"score": 0.0,
	}]


## 엔진 점수. 가중치는 DESIGN이며 PLAYTEST로 조정한다.
static func _engine_score(candidate: Dictionary, route: Dictionary) -> float:
	var max_cost := 1
	for c in route.values():
		max_cost = maxi(max_cost, int(c))

	# 경로 거리 백분위 — 유클리드가 아니라 실제 걸어야 하는 거리
	var distance := float(candidate["cost"]) / float(max_cost)
	# 막다른 포켓은 우연히 지나가다 발견하기 어렵다 → 발견 난이도 가산
	var discovery := 0.25 if candidate["kind"] == "pocket" else 0.0
	return distance + discovery
