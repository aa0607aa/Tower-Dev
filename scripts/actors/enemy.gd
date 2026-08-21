class_name Enemy
extends CharacterBody2D
## 최소 적 개체 — 감지 · 추적 · 근접 공격. (`PHASE 4` · `CBT-001` `CBT-008`)
##
## ## PHASE 7과의 경계
## `PHASE 7`이 NPC 본체(관계·기억·목표·시설 인식)를 만든다. 여기 있는 것은
## **전투가 성립하는 데 필요한 최소한**이다 — 보이면 쫓고, 닿으면 친다.
## 대화·기억·관계를 여기서 만들면 `PHASE 7`이 두 벌이 된다.
##
## ## 시간은 밖에서 온다 (`CBT-001` `CBT-002`)
## `_physics_process`의 delta를 그대로 쓰지 않고 **월드 시간**을 받는다.
## 전술 정지 중에 적만 움직이면 정지가 의미가 없다.
##
## ## 함정도 밟는다 (`FLR-028`)
## 적은 `TrapSensor`를 통해 자극을 만든다. 플레이어 전용 경로가 아니다.

## 감지 거리(px). **DESIGN** — `CBT-006`/`PHASE 7` TBD.
const SIGHT_RANGE := 220.0
## 감지를 잃는 거리. 감지와 같으면 경계에서 깜빡인다.
const LOSE_RANGE := 320.0
## 이동 속도(px/s). **DESIGN.**
const MOVE_SPEED := 96.0
## 이 거리 안이면 공격한다. 무기 리치보다 살짝 짧게 잡아 헛치지 않게 한다.
const ATTACK_MARGIN := 6.0

enum Mode { IDLE, CHASE, ATTACK }

var combatant: Combatant
var attack_state := AttackState.new()
var mode: Mode = Mode.IDLE
## 추적 대상. 없으면 대기.
var target: Node2D = null
## 함정 자극을 만드는 어댑터. 없으면 함정을 밟지 않는다.
var trap_sensor: TrapSensor = null

var _sprite: ColorRect


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if combatant == null:
		combatant = Combatant.new(name)
	_build_body()


func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)

	_sprite = ColorRect.new()
	_sprite.offset_left = -10
	_sprite.offset_top = -10
	_sprite.offset_right = 10
	_sprite.offset_bottom = 10
	_sprite.color = Color(0.62, 0.28, 0.26)
	add_child(_sprite)


## 월드 시간으로 한 틱 진행한다. `Main`이 배속을 곱해 넘긴다.
func tick(world_delta: float) -> Dictionary:
	var result := {"attacked": false, "hit": {}}
	if combatant == null or not combatant.alive:
		if _sprite != null:
			_sprite.color = Color(0.30, 0.24, 0.24, 0.6)  # 시체
		velocity = Vector2.ZERO
		return result

	# 진행 중인 공격은 시간만 흘린다 — 후딜 중에는 못 움직인다 (`CBT-008`).
	var entered_active := attack_state.advance(world_delta)

	_update_mode()

	if attack_state.phase == AttackState.Phase.IDLE and mode == Mode.CHASE and target != null:
		var to_target := target.global_position - global_position
		if to_target.length() > 0.0:
			velocity = to_target.normalized() * MOVE_SPEED
	else:
		velocity = Vector2.ZERO

	if mode == Mode.ATTACK and not attack_state.is_busy() and target != null:
		var w := combatant.weapon()
		if w != null:
			attack_state.start(w, (target.global_position - global_position).normalized())
			result["attacked"] = true

	if entered_active:
		result["hit"] = _resolve_active_hit()

	return result


## 유효 구간에서 대상을 때린다. 판정은 전부 `CombatService`가 한다.
func _resolve_active_hit() -> Dictionary:
	if target == null or not target.has_method("get_combatant"):
		return {}
	var target_combatant: Combatant = target.call("get_combatant")
	if target_combatant == null or not target_combatant.alive:
		return {}
	var w := combatant.weapon()
	if w == null:
		return {}

	var targets := {
		target_combatant.id: {
			"position": target.global_position,
			"combatant": target_combatant,
		}
	}
	var reachable := CombatService.targets_in_arc(global_position, attack_state, w, targets)
	if reachable.is_empty():
		return {}
	return CombatService.strike(combatant, global_position, attack_state,
		target_combatant.id, target_combatant, target.global_position)


func _update_mode() -> void:
	if target == null:
		mode = Mode.IDLE
		return
	var distance := global_position.distance_to(target.global_position)
	var w := combatant.weapon()
	var reach := (w.reach if w != null else 0.0) - ATTACK_MARGIN

	match mode:
		Mode.IDLE:
			if distance <= SIGHT_RANGE:
				mode = Mode.CHASE
		Mode.CHASE:
			if distance > LOSE_RANGE:
				mode = Mode.IDLE
			elif distance <= reach:
				mode = Mode.ATTACK
		Mode.ATTACK:
			if distance > reach:
				mode = Mode.CHASE


## 물리 이동. 실제 지형 충돌을 통과한다.
func move(world_delta: float) -> void:
	if world_delta <= 0.0 or velocity == Vector2.ZERO:
		return
	var before := global_position
	# `move_and_slide()`는 엔진 delta를 쓰므로 월드 시간과 어긋난다.
	# 배속이 걸린 상태에서도 정확하려면 이동량을 직접 준다.
	var motion := velocity * world_delta
	var collision := move_and_collide(motion)
	if collision != null:
		# 벽에 부딪히면 미끄러진다 — 막다른 곳에서 떨리지 않게.
		move_and_collide(motion.slide(collision.get_normal()))

	# 함정은 플레이어 전용이 아니다 (`FLR-028`).
	if trap_sensor != null and global_position != before:
		trap_sensor.sense_body(combatant.id, global_position, ENEMY_MASS,
			CausalSource.new(CausalSource.NO_OWNER, CausalSource.Kind.INDEPENDENT))


## 적 체중(kg). **DESIGN** — 함정 압력 판정에 필요한 최소 표현.
const ENEMY_MASS := 60.0


func get_combatant() -> Combatant:
	return combatant


func to_save_dict() -> Dictionary:
	return {
		"id": String(combatant.id),
		"position": [global_position.x, global_position.y],
		"combatant": combatant.to_save_dict(),
		"attack": attack_state.to_save_dict(),
		"mode": int(mode),
	}
