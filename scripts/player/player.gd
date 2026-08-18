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


func _physics_process(_delta: float) -> void:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = Movement.desired_velocity(raw, BASE_SPEED)

	# move_and_slide()는 velocity를 픽셀/초로 해석하고 delta를 내부에서 곱한다.
	# 그래서 여기서 delta를 다시 곱하면 안 된다 — 곱하면 프레임률에 따라 속도가 흔들린다.
	move_and_slide()

	if _debug_label:
		_debug_label.text = "%d,%d" % [roundi(global_position.x), roundi(global_position.y)]
