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

## 기본 이동 속도 (픽셀/초).
##
## DESIGN — canon 아님. 32px 타일 기준 초당 5타일이며 조작감은 PLAYTESTED로만 정할 수 있다.
## (CBT-009 · TEST_CHECKLIST 1-4) 확정되면 `data/` 쪽으로 뺀다.
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
