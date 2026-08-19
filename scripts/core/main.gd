extends Node2D
## Main — PHASE 2 진행 중.
##
## 1층 고정 정의를 로드해 지형을 세우고 플레이어를 시작점에 놓는다.
## PHASE 1의 `TestRoom.tscn`은 폐기했다 — canon 지형이 아니었다 (`FLR-001`).
##
## 아직 없는 것: 함정·파밍(`P2-T3`) · 행동 반경 적용(`P2-T4`) · 계단(`P2-T5`) · 세이브(`P2-T6`).

const CELL := 32  # Canon.TILE_SIZE

@onready var _status_label: Label = $UI/StatusLabel
@onready var _player: CharacterBody2D = $Player

var _floor_def: FloorDefinition
var _floor_view: FloorView


func _ready() -> void:
	_floor_def = FloorDefinitionLoader.load_from_file()
	if _floor_def == null:
		GameLog.error("Main", "1층 정의 로드 실패")
		_status_label.text = "1층 정의 로드 실패"
		return

	_floor_view = FloorView.new()
	_floor_view.name = "Floor"
	add_child(_floor_view)
	move_child(_floor_view, 0)
	_floor_view.build(_floor_def)

	if not _floor_def.start_points.is_empty():
		var start: Vector2i = _floor_def.start_points[0]
		_player.global_position = Vector2(start.x * CELL + CELL / 2.0, start.y * CELL + CELL / 2.0)

	GameLog.info("Main", "1층 로드 — 공간 %d · 통행 %d칸 · 긴 축 %d타일 · 해시 %s" % [
		_floor_def.spaces.size(), _floor_def.walkable_count(),
		_floor_def.long_axis(), _floor_def.definition_hash.substr(0, 8),
	])

	_status_label.text = "「탑」 1층 (greybox) — 공간 %d · 긴 축 %d타일\nWASD/방향키: 이동   ESC: 종료" % [
		_floor_def.spaces.size(), _floor_def.long_axis(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameLog.info("Main", "ESC 입력 — 정상 종료 요청")
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameLog.info("Main", "창 닫기 요청 — 정상 종료")
