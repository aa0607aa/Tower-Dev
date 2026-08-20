extends Node2D
class_name DebugOverlay
## 개발용 오버레이 — 함정·파밍·스폰·계단을 화면에 표시한다.
##
## ## ⚠ 이것은 배포에 들어가면 안 된다 (`SYS-005`)
## `SYS-005`는 **미발견 함정·계단·비밀이 UI로 누출되면 안 된다**고 규정한다.
## 이 오버레이는 정확히 그것을 다 보여준다. 그래서:
##   - 기본은 **꺼져 있고** F1로만 켜진다
##   - `OS.has_feature("editor")`가 아닌 빌드에서는 **아예 동작하지 않는다**
##   - PHASE 3에서 배포용 표현(`ClueView`·`GroundItemView`)이 생겼지만 **삭제하지 않는다.**
##     단서 흔적 튜닝을 `PHASE 8`(도트 완성 후)로 미뤘고, 그때 **흔적 위치와 실제 함정 위치를
##     비교할 도구**가 필요하다. 아래 게이트로 배포 빌드에서는 켜지지 않으므로 위험은 없다.
##
## ## 왜 만들었나
## PHASE 2 greybox PLAYTEST에서 오너가 "적·함정·파밍·계단이 없어서 판정하기 어렵다"고 했다.
## 맞는 지적이다 — 빈 복도만 걸어서는 **밀도와 동선 가치**를 알 수 없다.
## 실제 오브젝트는 PHASE 3~5지만, 공간 판정은 마커만 있어도 가능하다.

const CELL := 32

var definition: FloorDefinition
var state: FloorState

var _enabled := false


func _ready() -> void:
	z_index = 100
	set_process_unhandled_input(true)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F1:
		# 에디터/디버그 빌드가 아니면 무시한다. 배포 빌드에서 켜질 수 없게 한다.
		if not OS.has_feature("editor") and not OS.is_debug_build():
			return
		_enabled = not _enabled
		GameLog.info("DebugOverlay", "표시 %s" % ["ON" if _enabled else "OFF"])
		queue_redraw()


func _draw() -> void:
	if not _enabled or definition == null:
		return

	# 파밍 지점 — 노란 마름모
	for p in definition.loot_points:
		var c := _center(p["cell"])
		var looted := state != null and state.is_looted(p["id"])
		_diamond(c, 9.0, Color(0.95, 0.82, 0.25, 0.35 if looted else 1.0))

	# 스폰 지점 — 보라 원
	for p in definition.spawn_points:
		draw_circle(_center(p["cell"]), 10.0, Color(0.66, 0.45, 0.9, 0.9))

	# 함정 — 치명은 빨강, 비치명은 주황. 삼각형
	for tr in definition.traps:
		var c := _center(tr["cell"])
		var fired := state != null and state.trap_has_fired(tr["id"])
		var col := Color(0.9, 0.25, 0.25) if bool(tr["lethal"]) else Color(0.95, 0.6, 0.2)
		if fired:
			col.a = 0.3
		_triangle(c, 11.0, col)

	# 계단 — 청록 사각 + 테두리. 가장 크게 그린다
	if state != null:
		for s in state.party_stairs:
			var anchor: WorldAnchor = s["anchor"]
			var c := _center(anchor.cell)
			draw_rect(Rect2(c - Vector2(14, 14), Vector2(28, 28)), Color(0.2, 0.85, 0.85, 0.85))
			draw_rect(Rect2(c - Vector2(14, 14), Vector2(28, 28)), Color(0.05, 0.4, 0.4), false, 3.0)


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
	]), col)


func _triangle(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8),
	]), col)
