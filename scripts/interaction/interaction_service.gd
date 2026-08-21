class_name InteractionService
extends RefCounted
## 상호작용 대상 조회 — `P3-T1`.
##
## 앞으로 붙을 상호작용(줍기·함정 조사·계단)이 **각자 입력을 훔치지 않도록** 공통 경로를 둔다.
## 노드가 없는 순수 함수라 headless 테스트로 전부 검증된다 (`D-015`).
##
## ## 여기서 하지 않는 것
## **상태를 바꾸지 않는다.** 조회 전용이다. 실제 줍기/버리기는 `P3-T3`, 함정 발동은 `P3-T5`다.
## 지금 이걸 섞으면 "무엇을 상호작용할 수 있는가"와 "상호작용하면 무슨 일이 일어나는가"가
## 한 함수에 엉겨 테스트가 어려워진다.
##
## ## 함정은 후보가 아니다 (`SYS-005`)
## 함정을 상호작용 후보로 만들면 **프롬프트 자체가 함정의 존재를 알려준다.**
## "여기 뭔가 있다"는 표시가 곧 미발견 정보 누출이다. 함정을 알아채는 경로는
## `clues[]`를 환경에서 관찰하는 것이며 그건 `P3-T6`이 맡는다.
## 발견 상태(`discovered`)라는 개념 자체가 아직 없고, 여기서 임의로 만들지 않는다.
##
## ## 라벨에 내용물을 넣지 않는다
## 바닥에 놓인 물건의 **이름·효과를 여기서 노출하지 않는다.** 열매처럼 외형만으로
## 효과를 확정할 수 없는 물건이 있고(`ITM-002` `D-026`), 표시 규칙은 `P3-T3`이 정한다.
## 지금은 행동만 말한다 — "줍기".

## 상호작용 사거리(셀). **DESIGN이며 canon 아님.** 오너 PLAYTEST로 조정한다.
## 1이면 자기 칸 + 상하좌우 대각까지 닿는다.
const REACH_CELLS := 1

## 후보 종류의 **고정 우선순위**. 거리가 같을 때 순서를 결정적으로 만든다 (`SYS-003`).
## 나중에 종류가 늘면 여기에 추가한다 — 배열 순서가 곧 우선순위다.
const KIND_PRIORITY: Array[StringName] = [&"item"]


## 지금 상호작용할 수 있는 것들. **가까운 순 → 종류 순 → id 순**으로 정렬된다.
##
## 반환 항목: `{ kind, id, cell, distance, label }`
static func candidates(def: FloorDefinition, world: WorldState,
		envelope: AccessEnvelope, actor_cell: Vector2i, layer: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null or world == null:
		return out

	# 파밍 **지점**이 아니라 바닥에 **실제로 있는 물건**을 본다 (`P3-T3`).
	# 지점을 보면 유배자가 다른 곳에 버린 물건을 주울 수 없다.
	#
	# 조회는 `cell`이 아니라 **`WorldAnchor` 전체**로 한다 (`P3-REV-003`) —
	# 좌표만 보면 다른 region/layer의 같은 좌표 물건까지 손에 잡힌다.
	for r in range(-REACH_CELLS, REACH_CELLS + 1):
		for c in range(-REACH_CELLS, REACH_CELLS + 1):
			var cell := actor_cell + Vector2i(c, r)
			var at := WorldAnchor.new(def.world_id, def.world_region_ref, cell, layer)
			# 행동 반경 밖에는 손이 닿지 않는다 (`D-017` 4항 · `FLR-024`).
			if envelope != null and not envelope.contains(at):
				continue
			for instance_id in world.ground_items_here(at):
				out.append({
					"kind": &"item",
					"id": instance_id,
					"cell": cell,
					"distance": _reach_distance(actor_cell, cell),
					# 내용물을 말하지 않는다 — 행동만 말한다.
					"label": "줍기",
				})

	out.sort_custom(_compare)
	return out


## 지금 `interact` 키를 누르면 실행될 **단 하나**의 대상. 없으면 빈 사전.
static func best(def: FloorDefinition, world: WorldState,
		envelope: AccessEnvelope, actor_cell: Vector2i, layer: int = 0) -> Dictionary:
	var list := candidates(def, world, envelope, actor_cell, layer)
	return list[0] if not list.is_empty() else {}


## 체비쇼프 거리 — 대각도 한 칸으로 센다. 8방향 연속 이동이므로 대각만 안 닿으면 이상하다.
static func _reach_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## 결정적 정렬. **동점을 남기면 안 된다** — 같은 상황에서 다른 대상이 잡히면
## 세이브·재현이 흔들린다 (`SYS-003`).
static func _compare(a: Dictionary, b: Dictionary) -> bool:
	if a["distance"] != b["distance"]:
		return int(a["distance"]) < int(b["distance"])
	var pa := KIND_PRIORITY.find(a["kind"])
	var pb := KIND_PRIORITY.find(b["kind"])
	if pa != pb:
		return pa < pb
	return String(a["id"]) < String(b["id"])
