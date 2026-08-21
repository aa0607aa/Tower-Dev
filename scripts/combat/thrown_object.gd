class_name ThrownObject
extends Node2D
## 던진 물체. (`P4-T5` · `FLR-028` `CBT-004`)
##
## ## 왜 이게 PHASE 4에 있는가
## `FLR-028`이 canon으로 정한 것 — **"돌을 던져 벽 화살 함정을 먼저 발동시켜 제거하는
## 공략이 가능해야 한다."** `PHASE 3`에서 `TrapSensor.sense_impact()`까지는 만들었지만
## **던지는 입력이 없어 실제 플레이에서는 불가능**했다.
##
## ## 자기 자극을 만들지 않는다
## 멈춘 위치를 `TrapSensor.sense_impact()`에 넘길 뿐이다.
## 투사체가 자기 자극을 따로 만들면 경로가 다시 갈라진다 — `P3-REV-005`가 그랬다.
## (GPT `P3-REV-008` 인계: "반드시 `TrapSensor.sense_impact()`를 재사용한다.")
##
## ## 유배자 인과다
## 던진 사람이 원인이므로 `CausalSource.THROWN`이다.
## 행동 반경 밖으로는 나가지 못한다 (`D-017` 4항 · `FLR-024`).

## 비행 속도(px/s). **DESIGN.**
const SPEED := 420.0
## 최대 비행 거리(px). 무한히 날면 맵 밖까지 간다. **DESIGN.**
const MAX_RANGE := 260.0
## 돌 하나의 질량(kg). **DESIGN** — 함정 `min_mass` 판정에 쓴다.
const MASS := 0.5

var direction := Vector2.RIGHT
var thrower_id: StringName = &""
var trap_sensor: TrapSensor = null
var envelope: AccessEnvelope = null
## 맞으면 피해를 주는 대상들. `{ id -> { position, combatant } }`를 주는 콜백.
var target_provider: Callable = Callable()
var thrower: Combatant = null

var _travelled := 0.0
var _landed := false
## 마지막으로 자극을 낸 칸. 한 칸에서 매 프레임 자극이 나가면 안 된다.
var _last_cell := Vector2i(-99999, -99999)


func _ready() -> void:
	z_index = 2


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0.72, 0.70, 0.66))


## 월드 시간으로 진행한다. 착지했으면 `true`.
func tick(world_delta: float) -> bool:
	if _landed or world_delta <= 0.0:
		return _landed

	var step := direction * SPEED * world_delta
	var next := global_position + step

	# ## 지나간 칸을 **전부** 훑는다
	# 한 프레임 이동량이 한 칸보다 크면 그 칸을 통째로 뛰어넘는다 — 물리 터널링과 같다.
	# 실제로 그랬다: 420px/s 로 날면서 `21 → 23 → 25` 로 건너뛰어
	# **함정이 있는 24번 칸을 그냥 지나쳤다** (오너 발견, 2026-08-21).
	#
	# 끝점만 보면 프레임률에 따라 결과가 달라진다 — `CBT-001`(반실시간)에 어긋난다.
	# 그래서 시작점과 끝점 사이의 칸을 순서대로 본다.
	for cell in _cells_between(global_position, next):
		var cell_center := Vector2(cell.x * TrapSensor.CELL + TrapSensor.CELL / 2.0,
			cell.y * TrapSensor.CELL + TrapSensor.CELL / 2.0)

		# ## 지형에 막힌다 — **물리적 벽**이다
		# 경계(`AccessEnvelope`)만 보고 날면 안 된다. 경계는 `FLR-024`의 **인과 제약**이지
		# 물리 벽이 아니다. 둘을 같은 것으로 쓰면 한쪽이 어긋날 때 조용히 통과한다.
		if trap_sensor != null and trap_sensor.definition != null 				and not trap_sensor.definition.is_walkable(cell):
			_land(global_position)
			return true

		# 행동 반경 밖으로는 나가지 못한다 — 유배자 인과다 (`D-017` 4항).
		# 지형과 **별개 판정**이다.
		if envelope != null and not AccessService.can_body_enter(envelope, cell_center):
			_land(global_position)
			return true

		if cell == _last_cell:
			continue
		_last_cell = cell
		if trap_sensor == null:
			continue
		# 감지부를 건드렸으면 거기서 멈춘다 — 실선이나 압력판을 치고 계속 날아가지 않는다.
		var fired := trap_sensor.sense_impact(cell_center, MASS,
			CausalSource.new(thrower_id, CausalSource.Kind.THROWN))
		if not fired.is_empty():
			global_position = cell_center
			_land(cell_center)
			return true

	global_position = next
	_travelled += step.length()

	# 대상에 맞았는가 — 공간 판정이다 (`CBT-008`, 굴림 없음).
	if _hit_target():
		return true

	if _travelled >= MAX_RANGE:
		_land(global_position)
		return true
	return false


## 두 점 사이에 **실제로 지나간 칸들**을 순서대로 돌려준다.
##
## 셀 절반 간격으로 샘플링해 건너뛰지 않게 한다. 시작 칸은 포함하지 않는다 —
## 이미 지난 프레임에 처리했다.
func _cells_between(from: Vector2, to: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var distance := from.distance_to(to)
	if distance <= 0.0:
		return out
	var steps := maxi(1, ceili(distance / (TrapSensor.CELL * 0.5)))
	var last := TrapSensor.cell_of(from)
	for i in range(1, steps + 1):
		var c := TrapSensor.cell_of(from.lerp(to, float(i) / float(steps)))
		if c != last:
			out.append(c)
			last = c
	return out


func _hit_target() -> bool:
	if not target_provider.is_valid():
		return false
	var targets: Dictionary = target_provider.call()
	var ids: Array = targets.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var entry: Dictionary = targets[id]
		var c: Combatant = entry["combatant"]
		if c == null or not c.alive:
			continue
		if global_position.distance_to(entry["position"] as Vector2) > 12.0:
			continue
		# 던진 무기로 피해를 준다. 크리티컬은 사건에서만 (`CBT-004`).
		if thrower != null:
			var stone := WeaponData.get_weapon(&"thrown_stone")
			if stone != null:
				var r := DamageModel.resolve(stone, thrower.stats, c.armor,
					c.body_resilience, {})
				c.apply_damage(float(r["damage"]))
		_land(global_position)
		return true
	return false


## 착지 — **여기서만** 함정 자극이 나간다.
func _land(at: Vector2) -> void:
	if _landed:
		return
	_landed = true
	# 비행 중 이미 이 칸에서 자극을 냈으면 다시 내지 않는다 — 한 번의 착지는 한 번이다.
	if trap_sensor != null and TrapSensor.cell_of(at) != _last_cell:
		trap_sensor.sense_impact(at, MASS,
			CausalSource.new(thrower_id, CausalSource.Kind.THROWN))
	queue_free()


func has_landed() -> bool:
	return _landed
