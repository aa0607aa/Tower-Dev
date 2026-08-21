class_name TerrainMutationState
extends RefCounted
## 지형 변경 델타 — **`WorldState`가 소유하며 모든 유배자가 공유한다.** (`FLR-024` `FLR-027`)
##
## ⚠ **이 객체를 `FloorState`나 유배자별 구조에 복제하지 마라.**
## `FLR-024`: 허용 영역이 겹쳐 같은 월드 좌표를 가리키면 지형 mutation·NPC 생존/위치·
## 실제 물체 등 물리 상태는 **공유**한다. 같은 좌표에 유배자마다 다른 벽을 두면
## "층은 실제 월드의 일부"(`FLR-023`)라는 canon이 깨지고 플레이어별 평행 복제본이 된다.
##
## 이 클래스가 `world/`에 있고 `floor/`에 없는 것 자체가 그 경계의 표현이다.
## 소유권 위반은 `tests/test_world_space.gd`가 검사한다.
##
## `FLR-027`: 지형은 절대 벽이 아니라 물질이다. 초기 정의는 고정이고(`FLR-001`)
## 플레이어가 파괴한 결과는 여기 델타로 쌓인다. 전체 복셀을 저장하지 않는다 —
## **변경된 좌표만** 기록한다.
##
## PHASE 2 범위: 델타를 담는 그릇과 소유권 경계까지. 실제 굴착/붕괴 물리는 하지 않는다
## (구현 인계 §2 "PHASE 2에서 하지 않는 것"). 재료 저항·작업량 수치는 TBD.

## 지형이 어떻게 바뀌었는가. 수치가 아니라 종류만 — 물성치는 TBD다.
enum Change {
	EXCAVATED,  ## 굴착되어 통행 가능해짐
	COLLAPSED,  ## 붕괴로 막힘
	BREACHED,   ## 벽·구조물이 뚫림
}

## anchor.key() → { anchor, change, caused_by, at_tick }
var _mutations: Dictionary = {}


func mutation_count() -> int:
	return _mutations.size()


## 지형 변경을 기록한다.
##
## `caused_by`를 함께 남기는 이유: `FLR-024`상 유배자 인과와 독립 월드 사건을 구분해야 하고,
## 나중에 `NPC-003`(정보 전파)·인과 그래프가 "누가 무엇을 부쉈나"를 필요로 한다.
func record(anchor: WorldAnchor, change: Change, caused_by: CausalSource, at_tick: int) -> void:
	_mutations[anchor.key()] = {
		"anchor": anchor,
		"change": change,
		"caused_by": caused_by,
		"at_tick": at_tick,
	}


func has_mutation(anchor: WorldAnchor) -> bool:
	return _mutations.has(anchor.key())


func get_mutation(anchor: WorldAnchor) -> Dictionary:
	return _mutations.get(anchor.key(), {})


## 저장/비교용. 결정성(`SYS-003`)상 순서가 흔들리면 안 되므로 **키로 정렬**한다.
## Dictionary 순회 순서에 의존하면 같은 상태가 다른 세이브를 만든다.
func to_sorted_records() -> Array:
	var keys := _mutations.keys()
	keys.sort()
	var out: Array = []
	for k in keys:
		out.append(_mutations[k])
	return out


## 저장 형식 — **JSON으로 변환 가능한 값만** 담는다 (`P3-REV-002`).
##
## `to_sorted_records()`는 `WorldAnchor`·`CausalSource` **객체**를 그대로 들고 있어
## `JSON.stringify()`를 거치면 객체가 사라진다. 저장은 됐는데 복원이 안 되는 상태였다.
## 실제로 `RunSave`가 이 값을 저장만 하고 **복원 코드가 아예 없었다.**
##
## `enum`은 정수라 값 순서가 바뀌면 옛 세이브가 다른 변경 종류로 읽힌다 — 이름으로 저장한다.
func to_save_dict() -> Dictionary:
	var out: Array = []
	for r in to_sorted_records():
		out.append({
			"anchor": (r["anchor"] as WorldAnchor).to_save_dict(),
			"change": change_to_string(r["change"]),
			"caused_by": (r["caused_by"] as CausalSource).to_save_dict(),
			"at_tick": int(r["at_tick"]),
		})
	return {"mutations": out}


static func from_save_dict(d: Dictionary) -> TerrainMutationState:
	var out := TerrainMutationState.new()
	for r in d.get("mutations", []):
		out.record(
			WorldAnchor.from_save_dict(r["anchor"]),
			change_from_string(String(r["change"])),
			CausalSource.from_save_dict(r["caused_by"]),
			int(r.get("at_tick", 0)))
	return out


static func change_to_string(c: Change) -> String:
	match c:
		Change.EXCAVATED: return "excavated"
		Change.COLLAPSED: return "collapsed"
		Change.BREACHED: return "breached"
	return "excavated"


static func change_from_string(name: String) -> Change:
	match name:
		"excavated": return Change.EXCAVATED
		"collapsed": return Change.COLLAPSED
		"breached": return Change.BREACHED
	push_error("알 수 없는 TerrainMutationState.Change: %s" % name)
	return Change.EXCAVATED
