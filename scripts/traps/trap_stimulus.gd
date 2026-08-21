class_name TrapStimulus
extends RefCounted
## 함정 감지부를 건드린 **물리적 사건**. (`P3-T4` · `FLR-028`)
##
## ## 왜 이 클래스가 필요한가
## `body is Player`로 함정을 만들면 `FLR-028`을 어긴다. 원작에는 **돌을 던져 벽 화살 함정을
## 먼저 발동시켜 제거하는** 공략이 나온다. 플레이어 몸에만 반응하는 함정으로는 그게 불가능하다.
##
## 그래서 함정은 "누가 밟았나"가 아니라 **"어떤 물리적 자극이 왔나"** 를 본다.
## 유배자든 던진 돌이든 NPC든, 같은 자극이면 같은 결과다.
##
## ## `CausalSource`와 무엇이 다른가
## `CausalSource`는 **누구 책임인가**(인과·행동 반경 판정)를, 이것은 **무슨 일이 일어났나**를
## 말한다. 던진 돌은 자극으로는 `IMPACT`지만 인과로는 여전히 유배자다.
## 둘을 합치면 "NPC가 밟은 함정"과 "유배자가 던진 돌"을 구분할 수 없다.
##
## ## ⚠ 자극 종류는 **DESIGN**이다
## 어떤 센서가 존재하는지는 소설 원문에도 설정서에도 없다. `FLR-028`이 정한 것은
## "실제 메커니즘을 정상적으로 구현하라"는 원칙뿐이다.
## 아래 목록은 **구현에 필요한 표현**이며 세계관 사실이 아니다. 늘어나거나 바뀔 수 있다.

## 자극의 종류. **DESIGN — canon 아님.**
enum Kind {
	PRESSURE,  ## 누름·체중이 실림 (압력판·약한 바닥)
	TOUCH,     ## 스침·접촉 (실선)
	IMPACT,    ## 부딪힘·충격 (던진 물체가 때림)
}

var kind: Kind = Kind.PRESSURE
## 자극을 만든 물체의 질량(kg). **DESIGN 수치**다.
## 무게 공식 자체는 `PHASE 6`/TBD이므로 여기 값을 canon으로 굳히지 않는다.
var mass: float = 0.0
## 자극이 발생한 위치.
var cell: Vector2i = Vector2i.ZERO
## **누구 책임인가.** 행동 반경 판정에 쓴다 — 자극 종류와 별개다.
var source: CausalSource = null


func _init(p_kind: Kind = Kind.PRESSURE, p_mass: float = 0.0,
		p_cell: Vector2i = Vector2i.ZERO, p_source: CausalSource = null) -> void:
	kind = p_kind
	mass = p_mass
	cell = p_cell
	source = p_source


## 자극 종류 이름 ↔ enum. 저작 데이터가 문자열이므로 필요하다.
static func kind_from_string(name: String) -> Kind:
	match name:
		"pressure": return Kind.PRESSURE
		"touch": return Kind.TOUCH
		"impact": return Kind.IMPACT
	push_error("알 수 없는 자극 종류: %s" % name)
	return Kind.PRESSURE


static func kind_to_string(k: Kind) -> String:
	match k:
		Kind.PRESSURE: return "pressure"
		Kind.TOUCH: return "touch"
		Kind.IMPACT: return "impact"
	return "pressure"


## 유배자 본체가 밟았다 — **누르는** 자극만.
static func from_body(cell_: Vector2i, mass_: float, exile_id: StringName) -> TrapStimulus:
	return TrapStimulus.new(Kind.PRESSURE, mass_, cell_,
		CausalSource.new(exile_id, CausalSource.Kind.BODY))


## 유배자 본체가 **스쳤다** — 실선·감지선을 건드리는 자극.
static func from_body_contact(cell_: Vector2i, mass_: float, exile_id: StringName) -> TrapStimulus:
	return TrapStimulus.new(Kind.TOUCH, mass_, cell_,
		CausalSource.new(exile_id, CausalSource.Kind.BODY))


## 유배자가 **한 칸에 실제로 들어갔을 때** 생기는 자극 전부. (`P3-REV-005`)
##
## ## 왜 하나가 아니라 여러 개인가
## 몸이 공간을 지나가면 **바닥을 누르고(`PRESSURE`) 동시에 그 공간의 것들을 스친다(`TOUCH`)**.
## 둘 중 하나만 보내면 그 자극만 받는 함정이 실제 플레이에서 절대 안 터진다.
##
## 실제로 그 버그가 있었다 — `floor1`의 `wall_bolt`는 `touch`/`impact`만 받는데
## 플레이 경로는 `from_body()`(=`PRESSURE`)만 보내고 있어서
## **미발동 벽 화살 함정 위를 걸어도 아무 일이 없었다.**
##
## 자극 종류는 여전히 **DESIGN**이다 (`FLR-028`은 "실제 메커니즘을 정상적으로 구현하라"만 정한다).
## 여기서 하는 일은 새 종류를 만드는 것이 아니라 **이미 있는 종류를 빠짐없이 전달**하는 것이다.
static func from_body_entering(cell_: Vector2i, mass_: float,
		exile_id: StringName) -> Array[TrapStimulus]:
	return from_body_entering_with(cell_, mass_,
		CausalSource.new(exile_id, CausalSource.Kind.BODY))


## 같은 진입 자극을 **임의의 인과**로 만든다. (`P3-REV-008`)
##
## NPC·야생동물도 걸어 다니고 함정을 밟는다. 인과가 유배자로 고정돼 있으면
## 그들의 이동을 표현할 수 없고, `AccessEnvelope` 판정도 틀린다 —
## 독립 시뮬레이션은 유배자 경계에 막히지 않아야 한다 (`FLR-023`).
static func from_body_entering_with(cell_: Vector2i, mass_: float,
		source: CausalSource) -> Array[TrapStimulus]:
	return [
		TrapStimulus.new(Kind.PRESSURE, mass_, cell_, source),
		TrapStimulus.new(Kind.TOUCH, mass_, cell_, source),
	]


## 유배자가 **던진 물체**가 때렸다.
##
## 이것이 `FLR-028`의 핵심 사례다 — 돌을 던져 벽 화살 함정을 미리 터뜨리는 공략.
## 인과로는 유배자지만(`THROWN`) 몸이 아니다.
static func from_thrown(cell_: Vector2i, mass_: float, exile_id: StringName) -> TrapStimulus:
	return TrapStimulus.new(Kind.IMPACT, mass_, cell_,
		CausalSource.new(exile_id, CausalSource.Kind.THROWN))


## NPC·야생동물 등 유배자 인과 밖의 존재가 건드렸다.
static func from_independent(k: Kind, cell_: Vector2i, mass_: float) -> TrapStimulus:
	return TrapStimulus.new(k, mass_, cell_,
		CausalSource.new(CausalSource.NO_OWNER, CausalSource.Kind.INDEPENDENT))
