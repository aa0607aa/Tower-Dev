class_name TrapRuntime
extends RefCounted
## 함정 발동 판정. (`P3-T4` `P3-T5` · `FLR-011` `FLR-012` `FLR-028`)
##
## ## 규칙은 데이터에 있고 여기엔 없다
## `can_trigger()`는 **함정 정의가 선언한 메커니즘**과 들어온 자극을 대조할 뿐이다.
## `if trap_type == "wall_bolt"` 같은 분기를 여기 두면 데이터가 거짓말이 된다.
##
## ## actor class로 판정하지 않는다 (`FLR-028`)
## `body is Player` 같은 조건이 여기 있으면 안 된다. 유배자든 던진 돌이든 NPC든
## **같은 자극이면 같은 결과**다. 원작의 "돌을 던져 벽 화살 함정을 먼저 터뜨리기"가
## 그래야 성립한다.
##
## ## 모든 함정이 모든 것에 반응하지는 않는다
## `FLR-028`의 판단 항목 그대로다. 각 함정은 `accepts`(받는 자극 종류)와
## `min_mass`(최소 질량)를 선언하고 **그 정의를 따른다.**

## 정의에 `accepts`가 없을 때 쓸 기본값. **DESIGN.**
## 비워두면 아무 자극에도 반응하지 않아 함정이 조용히 죽으므로, 눈에 띄게 압력만 받는다.
const DEFAULT_ACCEPTS: Array[String] = ["pressure"]


## 이 자극이 이 함정을 발동시키는가.
##
## 상태를 보지 않는다 — **메커니즘 판정만** 한다. 이미 터졌는지는 `should_fire()`가 본다.
static func can_trigger(trap: Dictionary, stimulus: TrapStimulus) -> bool:
	if trap.is_empty() or stimulus == null:
		return false
	# 위치가 다르면 감지부를 건드린 것이 아니다.
	if trap["cell"] != stimulus.cell:
		return false

	var accepts: Array = trap.get("accepts", DEFAULT_ACCEPTS)
	if not accepts.has(TrapStimulus.kind_to_string(stimulus.kind)):
		return false

	# 너무 가벼우면 감지부가 반응하지 않는다.
	# 이 문턱이 있어야 "돌은 압력판을 못 누르지만 충격 감지는 건드린다" 같은 구분이 생긴다.
	if stimulus.mass < float(trap.get("min_mass", 0.0)):
		return false

	return true


## 지금 실제로 발동해야 하는가 — 메커니즘 + **상태**까지 본다.
##
## `FLR-012`: 발사형(`one_shot`)은 한 번 터지면 재충전되지 않는다.
## 이미 터진 함정은 메커니즘이 맞아도 발동하지 않는다.
## `state`가 `null`이면 **판정할 수 없다** — 상태를 모르는 채로 발동시키면
## 이미 터진 함정이 다시 터진다. 메커니즘만 보고 싶으면 `can_trigger()`를 쓴다.
## (`P3-REV` 추가 정리 — 전에는 `null`이면 `true`를 돌려주어 `trigger()`가
##  `state.fire_trap()`에서 터지기 직전까지 갔다.)
static func should_fire(trap: Dictionary, state: FloorState, stimulus: TrapStimulus) -> bool:
	if state == null:
		return false
	if not can_trigger(trap, stimulus):
		return false
	var trap_id: StringName = trap["id"]
	if state.trap_has_fired(trap_id) and bool(trap.get("one_shot", false)):
		return false
	return state.trap_is_armed(trap_id)


## 발동시킨다. 발동했으면 `true`.
##
## 상태 변경은 `FloorState.fire_trap()` 한 곳에만 있다 — 여기서 직접 필드를 건드리지 않는다.
static func trigger(trap: Dictionary, state: FloorState, stimulus: TrapStimulus) -> bool:
	if not should_fire(trap, state, stimulus):
		return false
	state.fire_trap(trap["id"], bool(trap.get("one_shot", false)))
	return true


## 이 자극이 닿는 위치에 있는 함정들을 정의에서 찾는다.
## 순서는 정의 순서 그대로 — 저작 순서가 곧 결정적 순서다 (`SYS-003`).
static func traps_at(def: FloorDefinition, cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for trap in def.traps:
		if trap["cell"] == cell:
			out.append(trap)
	return out


## 한 자극을 층 전체에 적용한다. 발동한 함정 id들을 돌려준다.
##
## 유배자가 원인인 자극은 **행동 반경 밖에 닿을 수 없다** (`D-017` 4항 · `FLR-024`).
## 던진 돌도 유배자 인과이므로 경계를 넘지 못한다. 독립 시뮬레이션(NPC·야생동물)은 통과한다.
static func apply(def: FloorDefinition, state: FloorState, stimulus: TrapStimulus,
		envelope: AccessEnvelope = null) -> Array[StringName]:
	var fired: Array[StringName] = []
	if def == null or stimulus == null:
		return fired

	# `source`가 없으면 **누구 인과인지 모른다.** 경계 판정을 할 수 없으므로
	# 봉투가 걸려 있으면 통과시키지 않는다 — 모르는 것을 허용으로 처리하지 않는다.
	if envelope != null:
		if stimulus.source == null:
			push_warning("자극에 CausalSource가 없다 — 경계 판정 불가로 차단")
			return fired
		var anchor := WorldAnchor.new(def.world_id, def.world_region_ref, stimulus.cell, 0)
		if not envelope.can_cross(stimulus.source, anchor):
			return fired

	for trap in traps_at(def, stimulus.cell):
		if trigger(trap, state, stimulus):
			fired.append(trap["id"])
	return fired
