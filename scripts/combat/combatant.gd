class_name Combatant
extends RefCounted
## 전투 개체의 **상태**. (`CBT-003` `CBT-011` · `WLD-003`)
##
## ## PHASE 4의 범위
## 로드맵상 HP·부상·장비는 `PHASE 6`이다. 그런데 PHASE 4는 "피격·사망"을 요구한다.
## 그래서 여기 있는 것은 **골격**이다 — 체력 한 줄과 생사 여부.
## 부상 부위·출혈·상태이상은 만들지 않는다. 만들면 `PHASE 6`이 두 벌이 된다.
##
## ## `body_resilience`는 비노출이다 (`CBT-011` CANON)
## 힘 계열의 내부 파생값이며 **상태창에 표시하지 않는다.**
## `to_save_dict()`에는 담지만 UI에 넘기는 경로를 만들지 않는다.
##
## ## ⚠ 수치는 DESIGN이다
## 최대 체력·방어·저항의 실제 값은 `CBT-006`/`PHASE 6` TBD다.
## 여기 기본값은 전투가 돌아가기 위한 기준선이다.

## 기준 체력. **DESIGN** — `PHASE 6`에서 스탯 기반으로 대체된다.
const BASELINE_VITALITY := 100.0

var id: StringName
## 남은 체력. `PHASE 6`에서 HP/부상 체계로 대체된다.
var vitality: float = BASELINE_VITALITY
var max_vitality: float = BASELINE_VITALITY
## 방어값. `CBT-003`의 `Armor`.
var armor: float = 0.0
## `CBT-011` — **비노출 파생값.** UI에 넘기지 않는다.
var body_resilience: float = 1.0
var stats: Dictionary = {"STR": 10, "AGI": 10, "INT": 10}
var equipped_weapon: StringName = &"starting_dagger"
## 죽은 개체는 다시 맞지 않는다.
var alive: bool = true


func _init(p_id: StringName = &"", p_stats: Dictionary = {}) -> void:
	id = p_id
	if not p_stats.is_empty():
		stats = p_stats.duplicate()


## 피해를 입는다. 실제로 깎인 양을 돌려준다.
##
## 이미 죽은 개체는 아무 일도 일어나지 않는다 — 시체를 계속 때려 로그가 쌓이면 안 된다.
func apply_damage(amount: float) -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var before := vitality
	vitality = maxf(0.0, vitality - amount)
	if vitality <= 0.0:
		alive = false
	return before - vitality


func weapon() -> WeaponData:
	return WeaponData.get_weapon(equipped_weapon)


func to_save_dict() -> Dictionary:
	var stat_keys: Array = stats.keys()
	stat_keys.sort()
	var stat_out := {}
	for k in stat_keys:
		stat_out[String(k)] = stats[k]
	return {
		"id": String(id),
		"vitality": vitality,
		"max_vitality": max_vitality,
		"armor": armor,
		"body_resilience": body_resilience,
		"stats": stat_out,
		"equipped_weapon": String(equipped_weapon),
		"alive": alive,
	}


static func from_save_dict(d: Dictionary) -> Combatant:
	var c := Combatant.new(StringName(d.get("id", "")))
	c.vitality = float(d.get("vitality", BASELINE_VITALITY))
	c.max_vitality = float(d.get("max_vitality", BASELINE_VITALITY))
	c.armor = float(d.get("armor", 0.0))
	c.body_resilience = float(d.get("body_resilience", 1.0))
	var raw: Dictionary = d.get("stats", {})
	var st := {}
	for k in raw:
		st[StringName(k)] = raw[k]
	if not st.is_empty():
		c.stats = st
	c.equipped_weapon = StringName(d.get("equipped_weapon", "starting_dagger"))
	c.alive = bool(d.get("alive", true))
	return c
