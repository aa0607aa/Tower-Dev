class_name CombatService
extends RefCounted
## 공간 타격 판정. (`CBT-008` `CBT-013` `CBT-004` · `CBT-006` TBD 회피)
##
## ## 명중률 굴림이 없다
## `CBT-006`이 명중/회피 수치를 **TBD**로 못박았다. 그래서 `randf() < hit_chance` 같은
## 것을 만들면 TBD를 몰래 확정하는 것이 된다.
##
## 대신 `CBT-008`이 준 것을 쓴다 — **"무기 리치·방향·충돌 박스는 전부 실제 데이터로
## 존재하며 텍스트 판정이 아니다."** 맞았는지는 **공간이 결정한다.**
## 리치 안에 있고 휘두른 각도 안에 있으면 맞는다. 굴림이 없으므로 결정적이다.
##
## ## 급소도 굴림이 아니다 (`CBT-013` `CBT-004`)
## 급소는 **별도 판정**이되 확률이 아니다. 여기서는 **타격 위치가 대상의 급소 영역에
## 들어왔는지**를 본다 — 공간 사건이다. `CBT-013`이 "부위 히트박스만이 유일한 구현은
## 아니고, 플레이 사건에서 재현 가능한 공간/조건 판정이면 된다"고 허용한다.
##
## ## 여기서 하지 않는 것
## 부위별 급소 **배율**은 TBD다. 급소가 났다는 **사실**만 `DamageModel`에 넘기고
## 배율은 기본 1.0으로 둔다.

## 급소로 치는 상대 위치 반경(px). **DESIGN** — 실제 부위 히트박스는 `PHASE 6`/`PHASE 8`.
## 대상 중심에 가까울수록 급소라는 단순화다. 배율이 아니라 **판정 영역**이라 TBD가 아니다.
const VITAL_RADIUS := 7.0


## 공격이 닿는 대상을 고른다.
##
## `targets`: `{ id -> { position: Vector2, combatant: Combatant } }`
## 반환: 맞은 대상 id 배열. **id 순으로 결정적**이다 (`SYS-003`).
static func targets_in_arc(attacker_position: Vector2, state: AttackState,
		weapon: WeaponData, targets: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if weapon == null or state == null or state.phase != AttackState.Phase.ACTIVE:
		return out

	var half_arc := deg_to_rad(weapon.arc_degrees) * 0.5
	var ids: Array = targets.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))

	for id in ids:
		if state.hit_ids.has(id):
			continue  # 한 번의 active에서 같은 대상을 두 번 때리지 않는다
		var entry: Dictionary = targets[id]
		var c: Combatant = entry["combatant"]
		if c == null or not c.alive:
			continue
		var to_target: Vector2 = (entry["position"] as Vector2) - attacker_position
		var distance := to_target.length()
		if distance > weapon.reach:
			continue
		# 리치 안이어도 등 뒤는 맞지 않는다 — 방향이 실제 데이터다.
		if distance > 0.0 and absf(state.direction.angle_to(to_target)) > half_arc:
			continue
		out.append(id)
	return out


## 급소에 맞았는가 — **공간 판정**이다 (`CBT-013`).
##
## 타격점이 대상 중심에 얼마나 가까운지를 본다. 굴림이 아니므로 같은 상황이면 같은 결과다.
static func is_vital_hit(attacker_position: Vector2, state: AttackState,
		weapon: WeaponData, target_position: Vector2) -> bool:
	if weapon == null or state == null:
		return false
	# 휘두른 궤적선에 대상 중심이 얼마나 가까운가.
	var to_target := target_position - attacker_position
	var along := to_target.dot(state.direction)
	if along <= 0.0:
		return false
	var closest := attacker_position + state.direction * minf(along, weapon.reach)
	return closest.distance_to(target_position) <= VITAL_RADIUS


## 한 번의 타격을 해결한다. 대상에 실제로 피해를 입힌다.
##
## `events`로 기습·무기 파손 같은 **사건**을 넘긴다 (`CBT-004`).
## 반환: `{ target_id, damage, critical, critical_reasons, killed }`
static func strike(attacker: Combatant, attacker_position: Vector2, state: AttackState,
		target_id: StringName, target: Combatant, target_position: Vector2,
		events: Dictionary = {}) -> Dictionary:
	var weapon := attacker.weapon() if attacker != null else null
	if weapon == null or target == null or not target.alive:
		return {"target_id": target_id, "damage": 0.0, "critical": false,
			"critical_reasons": [], "killed": false}

	var merged := events.duplicate()
	# 급소는 **별도 판정**이며 호출자가 강제로 켤 수도 있다 (테스트·스킬).
	if not merged.has("vital_hit"):
		merged["vital_hit"] = is_vital_hit(attacker_position, state, weapon, target_position)

	var result := DamageModel.resolve(
		weapon, attacker.stats, target.armor, target.body_resilience, merged)
	var dealt := target.apply_damage(float(result["damage"]))
	state.hit_ids.append(target_id)

	return {
		"target_id": target_id,
		"damage": dealt,
		"critical": result["critical"],
		"critical_reasons": result["critical_reasons"],
		"killed": not target.alive,
	}
