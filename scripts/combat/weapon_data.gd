class_name WeaponData
extends RefCounted
## 무기 정의. (`CBT-012` `CBT-008` · `FLR-007`)
##
## `CBT-012`가 **"정확한 비율은 무기 데이터에서 개별 정의하며 코드에 하드코딩하지 않는다"** 고
## 구현 방식까지 지정했다. 그래서 무기 타입별 분기가 코드에 있으면 canon 위반이다.
## `if weapon_type == "dagger"` 같은 것을 넣지 마라.
##
## ## ⚠ 수치는 DESIGN이다
## `CBT-006`이 무기별 스탯 가중치를 TBD로 명시한다. `data/items/weapons.json`의 값은
## PHASE 4 전투가 돌아가기 위한 기준선이며 PLAYTEST/`PHASE 6`에서 조정된다.

const WEAPONS_PATH := "res://data/items/weapons.json"

var id: StringName
var name: String
## 유효 사거리(px). `FLR-007` — 대거의 약점은 짧은 리치다.
var reach: float = 0.0
## 휘두르는 각도(도). 정면 기준 좌우로 절반씩.
var arc_degrees: float = 90.0
var base_attack: float = 0.0
var penetration: float = 0.0
## `STR`/`AGI`/`INT` 기여 비중. 합이 1일 필요는 없다 — 무기가 정한다.
var stat_weights: Dictionary = {}
## `CBT-008` 3구간 (초). **프레임이 아니다** — 프레임에 묶으면 `CBT-001`이 깨진다.
var wind_up: float = 0.1
var active: float = 0.1
var recovery: float = 0.2

static var _cache: Dictionary = {}


static func get_weapon(weapon_id: StringName) -> WeaponData:
	_ensure_loaded()
	return _cache.get(weapon_id, null)


static func all_ids() -> Array[StringName]:
	_ensure_loaded()
	var out: Array[StringName] = []
	for k in _cache:
		out.append(k)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## 총 공격 시간(초). 저장/복원과 테스트에서 쓴다.
func total_duration() -> float:
	return wind_up + active + recovery


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var f := FileAccess.open(WEAPONS_PATH, FileAccess.READ)
	if f == null:
		push_error("무기 데이터를 열 수 없다: %s" % WEAPONS_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("무기 데이터가 사전이 아니다")
		return
	for entry in (parsed as Dictionary).get("weapons", []):
		var w := WeaponData.new()
		w.id = StringName(entry["id"])
		w.name = String(entry.get("name", ""))
		w.reach = float(entry.get("reach", 0.0))
		w.arc_degrees = float(entry.get("arc_degrees", 90.0))
		w.base_attack = float(entry.get("base_attack", 0.0))
		w.penetration = float(entry.get("penetration", 0.0))
		w.stat_weights = entry.get("stat_weights", {})
		w.wind_up = float(entry.get("wind_up", 0.1))
		w.active = float(entry.get("active", 0.1))
		w.recovery = float(entry.get("recovery", 0.2))
		_cache[w.id] = w
