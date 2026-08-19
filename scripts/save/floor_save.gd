class_name FloorSave
extends RefCounted
## `FloorState` 저장/복원. (`P2-T6` · `SYS-003` `SYS-011`)
##
## ## 결과를 저장한다. 시드로 재생성하지 않는다
## `SYS-003`의 핵심은 "플레이어가 보지 않았다고 해서 다시 생성되지 않는다"이다.
## 시드만 저장하고 로드 때 다시 굴리면 **배치 로직을 한 줄 고치는 순간 과거 세이브의 세계가
## 조용히 달라진다.** 위반했다는 사실조차 드러나지 않는 것이 가장 나쁘다.
## 그래서 실체화 결과가 진실이고 시드는 재현·디버그용으로만 함께 남긴다.
##
## ## 정의 해시로 조용한 불일치를 막는다
## 1층 저작이 패치되면 옛 세이브의 좌표가 새 지형의 엉뚱한 곳을 가리킬 수 있다.
## 로드할 때 `definition_hash`를 비교해 **다르면 조용히 진행하지 않고 알린다.**
##
## ## 지형 변경은 여기 없다
## `TerrainMutationState`는 `WorldState` 소유다 (`FLR-024`). 층 세이브에 넣으면
## 유배자별 복제본이 생겨 "실제 월드의 일부"(`FLR-023`)가 깨진다.

const SAVE_VERSION := 1


## 로드 결과. 정의가 바뀌었을 때 호출자가 판단할 수 있게 상태를 함께 준다.
enum LoadStatus {
	OK,
	DEFINITION_CHANGED,  ## 저장 당시와 층 정의가 다르다 — 좌표가 어긋날 수 있다
	VERSION_MISMATCH,    ## 세이브 포맷 자체가 다르다
	CORRUPT,
}


static func to_dict(state: FloorState) -> Dictionary:
	var d := state.to_save_dict()
	d["save_version"] = SAVE_VERSION
	return d


static func write(state: FloorState, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("세이브를 쓸 수 없다: %s" % path)
		return false
	# 정렬된 사전을 쓰므로 같은 상태면 같은 바이트가 나온다 (`SYS-003` 검증에 쓴다)
	f.store_string(JSON.stringify(to_dict(state), "  ", true))
	f.close()
	return true


static func read(path: String, def: FloorDefinition) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"status": LoadStatus.CORRUPT, "state": null, "message": "파일을 열 수 없다"}
	var text := f.get_as_text()
	f.close()
	return from_text(text, def)


static func from_text(text: String, def: FloorDefinition) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"status": LoadStatus.CORRUPT, "state": null, "message": "JSON 파싱 실패"}
	var d := parsed as Dictionary

	if int(d.get("save_version", -1)) != SAVE_VERSION:
		return {
			"status": LoadStatus.VERSION_MISMATCH, "state": null,
			"message": "세이브 버전 %s (기대 %d)" % [d.get("save_version", "?"), SAVE_VERSION],
		}

	var state := _rebuild(d)

	# 정의가 바뀌었으면 **조용히 진행하지 않는다.**
	if def != null and state.definition_hash != def.definition_hash:
		return {
			"status": LoadStatus.DEFINITION_CHANGED, "state": state,
			"message": "층 정의가 바뀌었다 (세이브 %s / 현재 %s) — 좌표가 어긋날 수 있다"
				% [state.definition_hash.substr(0, 8), def.definition_hash.substr(0, 8)],
		}

	return {"status": LoadStatus.OK, "state": state, "message": ""}


static func _rebuild(d: Dictionary) -> FloorState:
	var state := FloorState.new()
	state.floor_id = StringName(d.get("floor_id", ""))
	state.generation_seed = int(d.get("generation_seed", 0))
	state.definition_hash = String(d.get("definition_hash", ""))
	state.layout_version = int(d.get("layout_version", 0))
	state.elapsed_seconds = float(d.get("elapsed_seconds", 0.0))

	for k in (d.get("trap_states", {}) as Dictionary):
		state.trap_states[StringName(k)] = (d["trap_states"] as Dictionary)[k]
	for k in (d.get("loot", {}) as Dictionary):
		state.loot[StringName(k)] = (d["loot"] as Dictionary)[k]
	for k in (d.get("spawns", {}) as Dictionary):
		state.spawns[StringName(k)] = (d["spawns"] as Dictionary)[k]
	for k in (d.get("event_flags", {}) as Dictionary):
		state.event_flags[StringName(k)] = (d["event_flags"] as Dictionary)[k]

	for c in (d.get("discovered_cells", []) as Array):
		state.discovered_cells[Vector2i(int(c[0]), int(c[1]))] = true

	for s in (d.get("party_stairs", []) as Array):
		var a: Dictionary = s["anchor"]
		state.party_stairs.append({
			"party_id": StringName(s["party_id"]),
			"anchor": WorldAnchor.new(
				StringName(a["world_id"]), StringName(a["region_id"]),
				Vector2i(int(a["cell"][0]), int(a["cell"][1])), int(a["layer"])),
			"discovered_by": s.get("discovered_by", []),
		})

	return state
