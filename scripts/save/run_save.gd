class_name RunSave
extends RefCounted
## `RunState` 저장/복원. (`P3-T3` · `SYS-003` `SYS-011`)
##
## `FloorSave`가 층 하나를 다뤘다면 이것은 **회차 전체**를 다룬다 —
## 월드들, 층들, 지형 변경, 바닥 물건, 유배자 인벤토리.
##
## ## 결과를 저장한다
## `FloorSave`와 같은 원칙이다. 시드로 다시 굴리지 않는다. 특히 물건은
## **`instance_id`가 그대로 살아남아야** 한다 — 저장/로드로 id가 바뀌면
## 같은 물건인지 알 수 없고 복제·소실을 검출할 방법도 사라진다.

const SAVE_VERSION := 1


static func to_dict(run: RunState) -> Dictionary:
	var d := run.to_save_dict()
	d["save_version"] = SAVE_VERSION
	return d


static func to_text(run: RunState) -> String:
	return JSON.stringify(to_dict(run), "\t", true)


## 복원. 층 정의는 `floor_id → FloorDefinition`으로 넘긴다 —
## `FloorState` 복원에 정의가 필요하기 때문이다.
static func from_text(text: String, defs: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"status": FloorSave.LoadStatus.CORRUPT, "run": null}
	var d: Dictionary = parsed

	if int(d.get("save_version", -1)) != SAVE_VERSION:
		return {"status": FloorSave.LoadStatus.VERSION_MISMATCH, "run": null}

	var run := RunState.new(int(d.get("run_seed", 0)))
	var status: int = FloorSave.LoadStatus.OK

	var worlds: Dictionary = d.get("worlds", {})
	var world_ids: Array = worlds.keys()
	world_ids.sort()
	for wid in world_ids:
		var wd: Dictionary = worlds[wid]
		var world := run.ensure_world(StringName(wid))

		var floors: Dictionary = wd.get("floors", {})
		var floor_ids: Array = floors.keys()
		floor_ids.sort()
		for fid in floor_ids:
			var fdef: FloorDefinition = defs.get(StringName(fid), null)
			var r := FloorSave.from_text(JSON.stringify(_with_version(floors[fid])), fdef)
			if r["state"] != null:
				world.put_floor(r["state"])
			# 정의 불일치는 삼키지 않고 위로 올린다
			if int(r["status"]) != FloorSave.LoadStatus.OK:
				status = int(r["status"])

		for entry in wd.get("ground_items", []):
			world.put_ground_item(
				ItemInstance.from_save_dict(entry["instance"]),
				WorldAnchor.from_save_dict(entry["anchor"]))

	var inventories: Dictionary = d.get("inventories", {})
	var exile_ids: Array = inventories.keys()
	exile_ids.sort()
	for eid in exile_ids:
		for item_d in inventories[eid]:
			run.add_to_inventory(StringName(eid), ItemInstance.from_save_dict(item_d))

	return {"status": status, "run": run}


## `FloorSave.from_text()`가 `save_version`을 요구하므로 붙여준다.
## 층 세이브를 회차 세이브 안에 중첩할 때만 쓰는 어댑터다.
static func _with_version(floor_dict: Dictionary) -> Dictionary:
	var d := floor_dict.duplicate(true)
	d["save_version"] = FloorSave.SAVE_VERSION
	return d
