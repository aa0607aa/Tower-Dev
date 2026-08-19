class_name FloorState
extends RefCounted
## 한 층의 **동적 상태**. (`D-016` · `SYS-011`)
##
## `FloorDefinition`이 초기 정의(불변)라면 이쪽은 플레이하며 바뀌는 것 전부다.
##
## ## 진실은 실체화된 결과이지 시드가 아니다 (`SYS-003`)
## `generation_seed`는 **재현·디버그용**으로 함께 저장하지만, 세이브를 읽을 때 시드로
## 다시 굴리지 않는다. 배치 로직을 한 줄만 고쳐도 과거 세이브의 세계가 조용히 달라지기 때문이다.
## 위반했다는 사실조차 드러나지 않는 것이 가장 나쁘다.
##
## ## 지형 변경은 여기 없다
## 지형 mutation은 `WorldState`가 소유한다 (`FLR-024`). 유배자/층별로 복제하면
## 같은 좌표에 서로 다른 벽이 생겨 "실제 월드의 일부"(`FLR-023`)가 깨진다.
## 가드 테스트가 이 소유권을 감시한다.

var floor_id: StringName
## 재현·디버그용. 로드 시 이것으로 재생성하지 않는다.
var generation_seed: int = 0
## 정의가 패치됐을 때 옛 세이브가 조용히 다른 좌표에 올라가는 것을 막는다 (`P2-T6`).
var definition_hash: String = ""
var layout_version: int = 0

## 함정 런타임 상태. `trap_id → { armed, fired }`
## **타입·단서는 여기 없다.** 그건 `FloorDefinition`의 고정 정의다.
var trap_states: Dictionary = {}

## 파밍 실체화 결과. `point_id → { item_id, kind, durability, looted }`
var loot: Dictionary = {}

## 유배자 스폰 결과. `spawn_id → { npc_id, alive }`
var spawns: Dictionary = {}

## 파티별 계단 (`FAC-002`). 단일 `stair_id`가 아니라 배열이다.
## [{ party_id, anchor: WorldAnchor, discovered_by: [] }]
var party_stairs: Array[Dictionary] = []

## 발견한 셀 (`FAC-003` — 계단은 직접 발견해야 한다).
var discovered_cells: Dictionary = {}

## 이번 회차에 실제로 뽑힌 시작 위치 (`D-022`).
## 후보 목록은 `FloorDefinition`(고정)에 있고 **선택 결과가 여기 저장**된다.
## 로드할 때 다시 뽑지 않는다 (`SYS-003`).
var start_cell: Vector2i = Vector2i.ZERO

var elapsed_seconds: float = 0.0
var event_flags: Dictionary = {}


func trap_is_armed(trap_id: StringName) -> bool:
	var st: Dictionary = trap_states.get(trap_id, {})
	return bool(st.get("armed", false))


func trap_has_fired(trap_id: StringName) -> bool:
	var st: Dictionary = trap_states.get(trap_id, {})
	return bool(st.get("fired", false))


## 함정 발동. `FLR-012` — 발사형은 한 번 소모되면 재충전되지 않는다.
func fire_trap(trap_id: StringName, one_shot: bool) -> void:
	var st: Dictionary = trap_states.get(trap_id, {"armed": true, "fired": false})
	st["fired"] = true
	if one_shot:
		st["armed"] = false
	trap_states[trap_id] = st


func is_looted(point_id: StringName) -> bool:
	var e: Dictionary = loot.get(point_id, {})
	return bool(e.get("looted", false))


func take_loot(point_id: StringName) -> void:
	if loot.has(point_id):
		loot[point_id]["looted"] = true


## 저장/비교용. Dictionary 순회 순서에 의존하면 같은 상태가 다른 세이브를 만든다 (`SYS-003`).
func to_save_dict() -> Dictionary:
	return {
		"floor_id": String(floor_id),
		"generation_seed": generation_seed,
		"definition_hash": definition_hash,
		"layout_version": layout_version,
		"trap_states": _sorted_dict(trap_states),
		"loot": _sorted_dict(loot),
		"spawns": _sorted_dict(spawns),
		"party_stairs": _stairs_to_save(),
		"start_cell": [start_cell.x, start_cell.y],
		"discovered_cells": _sorted_cells(discovered_cells),
		"elapsed_seconds": elapsed_seconds,
		"event_flags": _sorted_dict(event_flags),
	}


func _sorted_dict(d: Dictionary) -> Dictionary:
	var keys := d.keys()
	keys.sort_custom(func(a, b) -> bool: return String(a) < String(b))
	var out := {}
	for k in keys:
		out[String(k)] = _json_native(d[k])
	return out


## JSON에 없는 타입을 JSON 네이티브로 바꾼다.
##
## `StringName`은 JSON을 거치면 `String`이 되므로, 정규화하지 않으면
## **저장→로드 왕복에서 같은 상태가 다르게 보인다.** 실제로 2-3 테스트가 그걸 잡았다.
## 세이브 포맷은 JSON이므로 **직렬화 시점에** JSON이 표현할 수 있는 것만 남긴다.
func _json_native(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING_NAME:
			return String(v)
		TYPE_DICTIONARY:
			var out := {}
			var keys := (v as Dictionary).keys()
			keys.sort_custom(func(a, b) -> bool: return String(a) < String(b))
			for k in keys:
				out[String(k)] = _json_native((v as Dictionary)[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for item in (v as Array):
				arr.append(_json_native(item))
			return arr
		_:
			return v


func _sorted_cells(d: Dictionary) -> Array:
	var out: Array = []
	for c in d:
		out.append([c.x, c.y])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1] < b[1] if a[1] != b[1] else a[0] < b[0])
	return out


func _stairs_to_save() -> Array:
	var out: Array = []
	for s in party_stairs:
		var anchor: WorldAnchor = s["anchor"]
		out.append({
			"party_id": String(s["party_id"]),
			"anchor": {
				"world_id": String(anchor.world_id),
				"region_id": String(anchor.region_id),
				"cell": [anchor.cell.x, anchor.cell.y],
				"layer": anchor.layer,
			},
			"discovered_by": s.get("discovered_by", []),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["party_id"]) < String(b["party_id"]))
	return out
