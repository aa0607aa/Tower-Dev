class_name AttackState
extends RefCounted
## 공격의 wind-up → active → recovery 진행. (`CBT-008` DESIGN · `CBT-001`)
##
## ## 왜 프레임이 아니라 초인가
## `CBT-001`이 전투를 **반실시간**으로 정한다. 구간 길이를 프레임 수로 세면
## 프레임률에 따라 손맛이 달라진다 — `P1-TEST-001`에서 이동으로 이미 겪은 문제다.
##
## ## 왜 노드가 아닌가
## 진행 로직을 노드에 두면 headless 테스트가 어려워진다 (`D-015`).
## 여기서는 시간만 흘리고, 실제 타격 판정은 `CombatService`가 공간에서 한다.
##
## ## 시간은 밖에서 온다
## `advance(delta)`의 `delta`는 **월드 시간**이다. 전술 정지·슬로모션은
## `TimeScale`이 이 값을 줄여서 넣는다 — 여기에 배속 로직을 두지 않는다.

enum Phase {
	IDLE,      ## 공격 중이 아니다
	WIND_UP,   ## 선딜 — 아직 맞지 않는다
	ACTIVE,    ## 유효 — 이 구간에만 타격 판정이 일어난다
	RECOVERY,  ## 후딜 — 이미 지나갔고 움직이지 못한다
}

var phase: Phase = Phase.IDLE
## 현재 구간에서 흐른 시간(초).
var elapsed: float = 0.0
var weapon_id: StringName = &""
## 공격을 시작한 방향. 도중에 바뀌지 않는다 — 휘두르는 중에 방향을 꺾으면
## 선딜의 의미가 사라진다.
var direction: Vector2 = Vector2.RIGHT
## 이번 공격에서 이미 맞은 대상. `active` 한 번에 한 대상은 한 번만 맞는다.
var hit_ids: Array[StringName] = []


func is_busy() -> bool:
	return phase != Phase.IDLE


## 공격을 시작한다. 이미 공격 중이면 무시된다 — 입력 연타로 선딜을 건너뛸 수 없다.
func start(weapon: WeaponData, dir: Vector2) -> bool:
	if weapon == null or is_busy():
		return false
	phase = Phase.WIND_UP
	elapsed = 0.0
	weapon_id = weapon.id
	direction = dir.normalized() if dir.length() > 0.0 else Vector2.RIGHT
	hit_ids.clear()
	return true


## 월드 시간을 흘린다. 이번 호출에서 **새로 `ACTIVE`에 들어갔는지**를 돌려준다.
func advance(delta: float) -> bool:
	if phase == Phase.IDLE or delta <= 0.0:
		return false
	var weapon := WeaponData.get_weapon(weapon_id)
	if weapon == null:
		phase = Phase.IDLE
		return false

	elapsed += delta
	var entered_active := false

	# 한 번의 delta가 구간을 여러 개 넘길 수 있다 — 낮은 프레임률에서 실제로 일어난다.
	while phase != Phase.IDLE:
		var limit := _phase_duration(weapon)
		if elapsed < limit:
			break
		elapsed -= limit
		match phase:
			Phase.WIND_UP:
				phase = Phase.ACTIVE
				entered_active = true
			Phase.ACTIVE:
				phase = Phase.RECOVERY
			Phase.RECOVERY:
				phase = Phase.IDLE
				elapsed = 0.0
				weapon_id = &""
				hit_ids.clear()
	if phase == Phase.ACTIVE and not entered_active:
		entered_active = true  # active 구간에 머무는 동안 계속 판정한다
	return entered_active


func _phase_duration(weapon: WeaponData) -> float:
	match phase:
		Phase.WIND_UP: return weapon.wind_up
		Phase.ACTIVE: return weapon.active
		Phase.RECOVERY: return weapon.recovery
	return 0.0


func to_save_dict() -> Dictionary:
	var ids: Array = []
	for h in hit_ids:
		ids.append(String(h))
	return {
		"phase": int(phase),
		"elapsed": elapsed,
		"weapon_id": String(weapon_id),
		"direction": [direction.x, direction.y],
		"hit_ids": ids,
	}


static func from_save_dict(d: Dictionary) -> AttackState:
	var a := AttackState.new()
	a.phase = int(d.get("phase", Phase.IDLE)) as Phase
	a.elapsed = float(d.get("elapsed", 0.0))
	a.weapon_id = StringName(d.get("weapon_id", ""))
	var dir: Array = d.get("direction", [1.0, 0.0])
	a.direction = Vector2(float(dir[0]), float(dir[1]))
	var ids: Array[StringName] = []
	for h in d.get("hit_ids", []):
		ids.append(StringName(h))
	a.hit_ids = ids
	return a
