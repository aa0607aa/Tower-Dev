class_name TrapSensor
extends RefCounted
## 물리 사건 → 함정 자극 **어댑터**. (`P3-REV-008` · `FLR-028`)
##
## ## 왜 필요한가
## `TrapRuntime`은 자극을 받아 판정만 한다. 그런데 **누가 그 자극을 만드는가**가
## 지금까지 `main.gd` 안에 흩어져 있었고, 그래서 실제 게임에는 **플레이어 몸이 걸어 들어가는
## 경로 하나뿐**이었다. 돌·투척물·NPC가 함정을 건드리는 production 경로가 아예 없었다.
##
## `FLR-028`은 "돌을 던져 벽 화살 함정을 먼저 터뜨리는 공략이 가능해야 한다"고 정한다.
## 그 경로가 테스트에만 있고 게임에 없으면 canon을 지킨 것이 아니다.
##
## 이 클래스는 **월드 좌표계의 물리 사실**(어디에 있었고 어디로 갔는가, 얼마나 무거운가,
## 누구 인과인가)을 받아 자극으로 바꾼다. 함정 종류를 알 필요도, actor class를 볼 필요도 없다.
##
## ## 한 곳으로 모은다
## 플레이어도 던진 돌도 NPC도 **같은 어댑터**를 쓴다. 경로가 갈라지면
## `P3-REV-005`처럼 "한쪽 경로만 잘못된 자극을 보내는" 버그가 다시 난다.
##
## ## ⚠ 자극 매핑은 DESIGN이다
## "몸이 들어가면 누르고 스친다", "빠르게 움직이던 물체가 멈추면 때린다" 는
## 구현에 필요한 물리 표현이며 **canon이 아니다.** `FLR-028`이 정한 것은
## "실제 메커니즘을 정상적으로 구현하라"는 원칙뿐이다.
##
## ## 여기서 하지 않는 것
## 던지기 입력·투사체 비행·전투는 `PHASE 4`다. 이 어댑터는 **이미 일어난 물리 사건을
## 받기만** 한다 — 무엇이 그 사건을 일으켰는지는 상관하지 않는다.

const CELL := 32

var definition: FloorDefinition = null
var state: FloorState = null
## 유배자 인과 자극에 적용되는 경계. 독립 시뮬레이션은 `can_cross()`가 통과시킨다.
var envelope: AccessEnvelope = null

## 개체별 마지막으로 판정한 칸. 같은 칸에서 매 프레임 다시 터지는 것을 막는다.
var _last_cell: Dictionary = {}


func _init(p_definition: FloorDefinition = null, p_state: FloorState = null,
		p_envelope: AccessEnvelope = null) -> void:
	definition = p_definition
	state = p_state
	envelope = p_envelope


static func cell_of(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / CELL), floori(world_position.y / CELL))


## **몸이 걸어 다니는** 개체가 지금 이 위치에 있다.
##
## 칸이 바뀐 순간에만 자극을 만든다 — 서 있는 동안 계속 터지면 안 된다.
## 몸이 칸에 들어가면 바닥을 누르고(`PRESSURE`) 동시에 그 공간의 것들을 스친다(`TOUCH`).
##
## `presence_id`는 개체를 구분하는 키다. 여러 개체가 각자의 마지막 칸을 가져야
## 한 개체의 이동이 다른 개체의 판정을 지운다.
func sense_body(presence_id: StringName, world_position: Vector2, mass: float,
		source: CausalSource) -> Array[StringName]:
	var cell := cell_of(world_position)
	if _last_cell.get(presence_id, Vector2i(-99999, -99999)) == cell:
		return []
	_last_cell[presence_id] = cell
	return _apply(TrapStimulus.from_body_entering_with(cell, mass, source))


## **날아가던 물체가 멈췄다** — 부딪힘.
##
## 지나온 칸들을 전부 훑지 않고 **멈춘 칸**만 본다. 관통 판정은 투사체 시스템(`PHASE 4`)의
## 일이고, 여기서 임의로 만들면 그 시스템이 붙을 때 두 벌이 된다.
##
## 부딪힌 물체는 때리고(`IMPACT`) 동시에 닿는다(`TOUCH`) — 던진 돌이 실선을 건드릴 수 있다.
func sense_impact(world_position: Vector2, mass: float,
		source: CausalSource) -> Array[StringName]:
	var cell := cell_of(world_position)
	var stimuli: Array[TrapStimulus] = [
		TrapStimulus.new(TrapStimulus.Kind.IMPACT, mass, cell, source),
		TrapStimulus.new(TrapStimulus.Kind.TOUCH, mass, cell, source),
	]
	return _apply(stimuli)


## 이 개체의 위치 기억을 지운다. 층을 옮기거나 개체가 사라질 때 쓴다.
func forget(presence_id: StringName) -> void:
	_last_cell.erase(presence_id)


func _apply(stimuli: Array[TrapStimulus]) -> Array[StringName]:
	if definition == null or state == null:
		return []
	return TrapRuntime.apply_all(definition, state, stimuli, envelope)
