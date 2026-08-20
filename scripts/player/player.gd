extends CharacterBody2D
## 플레이어 — PHASE 1 임시 구현.
##
## 지금은 이동과 충돌만 한다. 스탯·부상·장비는 PHASE 6, 전투는 PHASE 4다.
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

## 이 유배자의 행동 반경 (`FLR-017` `FLR-024`). 없으면 경계 없이 움직인다.
##
## 지형 충돌과 **별개**다 — 지형은 물리 벽이고 이것은 탑의 인과 제약이다.
## 경계 밖에도 실제 세계가 있고 NPC는 자유롭게 오간다 (`FLR-023`).
var access_envelope: AccessEnvelope = null


func _ready() -> void:
	var shape_node := get_node_or_null("Collision") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		_half_extent = (shape_node.shape as RectangleShape2D).size * 0.5


func _physics_process(delta: float) -> void:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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
