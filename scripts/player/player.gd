extends CharacterBody2D
## 플레이어 — PHASE 4까지 반영.
##
## 이동·충돌에 더해 공격(`AttackState`)·대시·전투 상태(`Combatant`)를 들고 있다.
## 스탯·부상·장비 본체는 여전히 `PHASE 6`이다.
## 스프라이트는 임시 색 박스이며 PHASE 8에서 도트로 교체한다.
##
## canon 근거:
## - CHR-001: 플레이어는 랜덤 생성 유배자. 지금은 생성 규칙(CHR-010)이 TBD라 익명 박스다
## - CBT-001 / SYS-012: 반실시간 연속 이동. 칸 단위로 끊기지 않는다
## - CBT-009: 속도 보정(민첩·상태이상·장비 무게·[신속])은 PHASE 6에서 붙인다
##
## 이동 계산은 전부 `Movement`(순수 함수)에 있다. 여기서는 입력을 읽고 결과를 실을 뿐이라
## 로직이 headless 테스트로 검증된다. (D-015)

## 기본 이동 속도 (픽셀/초). 32px 타일 기준 초당 5타일.
##
## DESIGN — canon 아님. 확정되면 `data/` 쪽으로 뺀다.
##
## **이 값은 "민첩 10인 유배자"의 기준선이다.** (CHR-003: 인간 평균 각 10)
## 올릴 때 반드시 같이 생각할 것 — `CBT-009`상 이동 속도는 민첩·[신속] 계열로 **빨라진다.**
## 기준선을 넉넉하게 잡으면 성장 여지가 사라지고, 나중에 스킬 효과를 억지로 깎아야 한다.
## 2026-08-18 오너 PLAYTEST 판단: "조금 느린 것 같지만 이후 민첩·스킬로 빨라지는 걸
## 고려하면 오히려 조금 더 느려도 괜찮을 수도 있다" — 그래서 올리지 않고 유지한다.
##
## 민첩 → 이동 속도의 실제 매핑은 `CHR-009`(파생 능력식) TBD다. 임의로 만들지 않는다.
const BASE_SPEED := 160.0

@onready var _debug_label: Label = $DebugLabel

## 충돌 상자의 반크기. 경계 판정은 중심점이 아니라 **몸 전체**를 봐야 한다 (`P2-REV-006`).
## 중심이 마지막 허용 셀에 있어도 옆면이 경계를 넘으면 밖의 물체에 닿는다.
var _half_extent := Vector2.ZERO

## 대시 (`PHASE 4`). **DESIGN 수치** — 손맛은 `4-2` PLAYTEST로 결정된다.
const DASH_SPEED := 420.0
const DASH_DURATION := 0.14
const DASH_COOLDOWN := 0.55

## 전투 상태. `Main`이 넣어준다 — 플레이어 노드가 스스로 만들면
## 세이브/로드 때 `RunState`의 것과 두 벌이 된다.
var combatant: Combatant = null
var attack_state := AttackState.new()

## 마지막으로 바라본 방향. 멈춰 있어도 그쪽으로 휘두른다.
##
## ## 조준은 마우스와 키보드 **둘 다** 받는다 (오너 결정 2026-08-21)
## 이동 방향으로만 조준하면 **멈춰서 치면 빗나가고 함정도 조준할 수 없다.**
## 실제로 그랬다 — 플레이 로그에 돌 128번을 던졌는데 함정 발동 0, 근접 타격 0이었다.
## 공격이 좌클릭에 걸려 있는데 조준이 커서를 따라가지 않는 것이 어긋난 지점이었다.
##
## **마지막 입력이 이긴다.** 마우스를 움직이면 커서 쪽, 방향키를 누르면 그쪽.
## 손이 오가면 조준이 튈 수 있지만, 둘 중 하나만 쓰는 플레이어에게는 항상 자연스럽다.
var facing := Vector2.RIGHT

## 마우스가 실제로 움직였는지 판단할 최소 거리(px). **DESIGN.**
## 이 값이 없으면 미세한 떨림만으로 키보드 조준을 덮어쓴다.
const MOUSE_AIM_THRESHOLD := 3.0

## **화면** 좌표 기준이다. 월드 좌표로 재면 카메라가 플레이어를 따라가는 것만으로도
## "마우스가 움직였다"가 되어 **걷기만 해도 조준이 커서 쪽으로 끌려간다.**
## 실제로 그래서 E2E가 깨졌다.
var _last_mouse_screen := Vector2.INF

## 월드 시간 배속 (`CBT-001`). `Main`이 넣어준다.
##
## 정지 중에는 **물리 이동 자체를 하지 않는다.** 좌표만 되돌리는 것으로는 부족하다 —
## `move_and_slide()`가 돌면 그 프레임에 몸이 실제로 움직이고 함정·물체를 건드린다.
## `P2-REV-006`에서 행동 반경으로 겪은 문제와 같은 계열이다.
var time_scale: TimeScale = null

var _dash_left := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.ZERO

## 이 유배자의 행동 반경 (`FLR-017` `FLR-024`). 없으면 경계 없이 움직인다.
##
## 지형 충돌과 **별개**다 — 지형은 물리 벽이고 이것은 탑의 인과 제약이다.
## 경계 밖에도 실제 세계가 있고 NPC는 자유롭게 오간다 (`FLR-023`).
var access_envelope: AccessEnvelope = null


func _ready() -> void:
	var shape_node := get_node_or_null("Collision") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		_half_extent = (shape_node.shape as RectangleShape2D).size * 0.5


func get_combatant() -> Combatant:
	return combatant


## 공격 중이거나 후딜 중인가 — `Main`이 상호작용을 막는 데 쓴다.
func is_attacking() -> bool:
	return attack_state.is_busy()


## 공격을 시작한다. 성공하면 `true`.
##
## 연타로 선딜을 건너뛸 수 없다 (`CBT-008` — `AttackState`가 막는다).
func try_attack() -> bool:
	if combatant == null or not combatant.alive:
		return false
	var w := combatant.weapon()
	if w == null:
		return false
	return attack_state.start(w, facing)


## 대시를 시작한다. 쿨다운 중이면 `false`.
func try_dash() -> bool:
	if _dash_cooldown > 0.0 or _dash_left > 0.0:
		return false
	if combatant != null and not combatant.alive:
		return false
	# 후딜 중에는 대시로 빠져나갈 수 없다 — 그러면 후딜이 무의미해진다.
	if attack_state.phase == AttackState.Phase.RECOVERY:
		return false
	_dash_direction = facing
	_dash_left = DASH_DURATION
	return true


func is_dashing() -> bool:
	return _dash_left > 0.0


## 월드 시간으로 전투 상태를 진행한다. 새로 유효 구간에 들어갔으면 `true`.
##
## `_physics_process`의 delta를 그대로 쓰지 않는다 — 전술 정지 중에
## 공격만 진행되면 정지가 의미가 없다 (`CBT-001` `CBT-002`).
func advance_combat(world_delta: float) -> bool:
	if world_delta <= 0.0:
		return false
	_dash_left = maxf(0.0, _dash_left - world_delta)
	if _dash_left <= 0.0 and _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - world_delta)
	if is_zero_approx(_dash_left) and _dash_direction != Vector2.ZERO:
		_dash_direction = Vector2.ZERO
		_dash_cooldown = DASH_COOLDOWN
	return attack_state.advance(world_delta)


## 조준 방향을 갱신한다. **마지막 입력이 이긴다.**
##
## 마우스가 움직였으면 커서 쪽, 아니면 이동 입력 쪽.
## 둘 다 없으면 직전 방향을 유지한다 — 멈춰 있다고 정면으로 리셋되면 안 된다.
func _update_facing(move_input: Vector2) -> void:
	# 움직였는지는 **화면** 좌표로, 조준 방향은 **월드** 좌표로 잰다.
	var screen := get_viewport().get_mouse_position()
	var mouse_moved := _last_mouse_screen != Vector2.INF 		and screen.distance_to(_last_mouse_screen) > MOUSE_AIM_THRESHOLD
	_last_mouse_screen = screen

	facing = resolve_facing(mouse_moved, get_global_mouse_position() - global_position,
		move_input, facing)


## 조준 결정 — **순수 함수다.**
##
## ## 왜 밖으로 뺐는가
## 헤드리스 테스트는 마우스를 움직일 수 없다. 결정이 `_update_facing()` 안에만 있으면
## **마우스 분기를 통째로 죽여도 테스트가 통과한다** — 실제로 변이가 안 잡혔다.
## `ClueView.shows_trace_for()`와 같은 처방이다: 판단을 함수로 빼고 테스트가 그걸 부른다.
##
## **마지막 입력이 이긴다.** 둘 다 없으면 직전 방향을 유지한다 —
## 멈췄다고 정면으로 리셋되면 조준이 튄다.
static func resolve_facing(mouse_moved: bool, to_cursor: Vector2,
		move_input: Vector2, current: Vector2) -> Vector2:
	if mouse_moved and to_cursor.length() > 0.0:
		return to_cursor.normalized()
	if move_input.length() > 0.0:
		return move_input.normalized()
	return current


## 월드가 멈춰 있는가. `Main`과 테스트가 함께 쓴다.
func is_world_paused() -> bool:
	return time_scale != null and time_scale.is_paused()


func _physics_process(delta: float) -> void:
	# ★ 완전 정지 (`CBT-001` · `P4-REV-001`)
	# **아무것도 하지 않는다.** 이동도, 대시 진행도, 물리 질의도.
	# 여기서 `move_and_slide()`를 돌리면 정지 중에 함정을 밟을 수 있다.
	if is_world_paused():
		velocity = Vector2.ZERO
		return

	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_facing(raw)

	if combatant != null and not combatant.alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _dash_left > 0.0:
		# 대시 중에는 입력 방향이 아니라 **시작할 때 정한 방향**으로 간다.
		# 도중에 꺾이면 회피 거리가 예측 불가능해진다.
		velocity = _dash_direction * DASH_SPEED
	elif attack_state.phase == AttackState.Phase.RECOVERY:
		# 후딜 중에는 움직이지 못한다 (`CBT-008` — 후딜에 무게가 있어야 한다).
		velocity = Vector2.ZERO
	else:
		velocity = Movement.desired_velocity(raw, BASE_SPEED)

	var before := global_position

	# ★ 행동 반경은 **물리 이동 전에** 건다 (`P2-REV-006`).
	#
	# 전에는 `move_and_slide()`를 먼저 돌리고 결과 좌표만 경계 안으로 되감았다.
	# 좌표는 돌아왔지만 그 프레임에 몸체가 경계 밖에서 실제로 움직였고 충돌을 만들었다.
	# PHASE 3에서 함정·물체·Area가 붙으면 **경계 밖 대상을 건드리고 나서 좌표만 되돌리는**
	# 상태가 된다. `D-017`/`FLR-024`상 유배자가 원인인 직접 영향은 경계 밖에 닿을 수 없다.
	if access_envelope != null:
		velocity = AccessService.limit_motion(
			access_envelope, before, velocity, delta, _half_extent)

	# move_and_slide()는 velocity를 픽셀/초로 해석하고 delta를 내부에서 곱한다.
	# 그래서 여기서 delta를 다시 곱하면 안 된다 — 곱하면 프레임률에 따라 속도가 흔들린다.
	move_and_slide()

	# 안전망. 위에서 이미 막았지만 지형 충돌의 미끄러짐이 예상 밖 좌표를 만들 수 있다.
	# 경계는 한 겹으로 두지 않는다.
	if access_envelope != null:
		global_position = AccessService.clamp_move(access_envelope, before, global_position)

	if _debug_label:
		_debug_label.text = "%d,%d" % [roundi(global_position.x), roundi(global_position.y)]
