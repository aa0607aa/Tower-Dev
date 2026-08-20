class_name ClueView
extends Node2D
## 함정 단서의 greybox 표현. (`P3-T6` · `FLR-011` `SYS-005`)
##
## ## 단서는 정답 표시가 아니다
## `FLR-011`이 요구하는 것은 "발동 전에 **알아챌 수 있는** 유효 단서"다.
## 함정 칸에 경고 아이콘을 띄우면 그건 단서가 아니라 답이다 — 관찰도 추론도 사라진다.
##
## 그래서 여기서 그리는 것은 **함정 칸이 아니라 그 주변의 흔적**이다:
##   - 바닥 얼룩·마모·이음매 어긋남 같은 미세한 자국
##   - 함정 칸 자체가 아니라 **주변 칸에 흩어져** 있다
##   - 종류를 구분하지 않는다. "여기 뭔가 이상하다"까지만 말한다
##
## 유배자는 이걸 보고 **의심**할 수 있어야 하고, 무시하고 지나갈 수도 있어야 한다.
##
## ## `DebugOverlay`와의 차이
## `DebugOverlay`는 함정 위치를 정확히 찍어준다 — 개발 도구이고 `SYS-005` 위반이다.
## 이것은 배포 가능한 표현이다. 단서가 있는 함정만, 주변에만, 흐리게 그린다.
##
## ## 왜 `clues[]` 텍스트를 화면에 쓰지 않는가
## "벽면 높이의 좁은 사출구" 같은 문장을 띄우면 그 순간 정답이 된다.
## 텍스트는 조사(`PHASE 3` 후반 이후)나 관찰 결과로 나와야 할 서술이지
## 상시 표시가 아니다. 지금은 **시각적 흔적**만 낸다.
##
## `PHASE 8`에서 실제 도트가 들어오면 이 표현은 교체되고 가독성을 다시 검증한다.

const CELL := 32

## 단서 흔적의 크기(px). greybox 값이며 canon 아님.
const MARK_RADIUS := 3.0
## 잿빛 돌 바닥(`FLR-013`)에서 **자세히 보면 보이는** 정도. 눈에 확 띄면 정답이 된다.
const MARK_COLOR := Color(0.32, 0.26, 0.20, 0.55)

## 흔적이 흩어지는 범위(칸). 함정 칸을 정확히 가리키지 않게 한다.
const SCATTER_CELLS := 1

var definition: FloorDefinition = null
var state: FloorState = null


func _ready() -> void:
	z_index = -1  # 바닥 흔적이므로 플레이어·아이템 아래


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if definition == null:
		return

	for trap in definition.traps:
		# 단서가 없는 함정은 흔적도 없다. `FLR-011`은 **치명** 함정에 단서를 요구하며,
		# 그 검사는 테스트가 한다. 여기서 없는 단서를 만들어내지 않는다.
		var clues: Array = trap["clues"]
		if clues.is_empty():
			continue
		# 이미 터진 함정의 흔적은 남기지 않는다 — 위험이 사라졌으므로.
		if state != null and state.trap_has_fired(trap["id"]):
			continue

		_draw_traces(trap)


## 함정 하나 주변에 흔적을 뿌린다.
##
## 위치는 **함정 id에서 결정적으로** 만든다 (`SYS-003`). 난수를 쓰면 같은 세이브를
## 다시 열 때 흔적이 다른 곳에 생겨 "어제 본 그 자국"이 사라진다.
## 지형 암기가 영구 성장인 게임에서(`FLR-015`) 그건 치명적이다.
func _draw_traces(trap: Dictionary) -> void:
	var cell: Vector2i = trap["cell"]
	var clues: Array = trap["clues"]
	var h := hash(String(trap["id"]))

	# 단서가 많을수록 흔적도 많다 — 더 알아채기 쉬운 함정이 된다.
	var count := mini(clues.size() + 1, 4)
	for i in count:
		var seed_i := hash(h + i * 7919)
		var dx := (seed_i % (SCATTER_CELLS * 2 + 1)) - SCATTER_CELLS
		var dy := ((seed_i / 13) % (SCATTER_CELLS * 2 + 1)) - SCATTER_CELLS
		var trace_cell := cell + Vector2i(dx, dy)
		if not definition.is_walkable(trace_cell):
			continue

		# 칸 안에서의 위치도 고정한다
		var ox := float((seed_i / 101) % CELL)
		var oy := float((seed_i / 307) % CELL)
		var p := Vector2(trace_cell.x * CELL + ox, trace_cell.y * CELL + oy)
		draw_circle(p, MARK_RADIUS, MARK_COLOR)
