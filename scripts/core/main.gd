extends Node2D
## Main — PHASE 2 진행 중.
##
## 1층 고정 정의를 로드해 지형을 세우고 플레이어를 시작점에 놓는다.
## PHASE 1의 `TestRoom.tscn`은 폐기했다 — canon 지형이 아니었다 (`FLR-001`).
##
## population(`P2-T3`) · 행동 반경(`P2-T4`) · 계단(`P2-T5`)까지 실제로 쓰고 있다.
## 아직 없는 것: 상호작용(밟기·줍기·계단 타기)은 PHASE 3이다.
## `DebugOverlay`는 그때 삭제한다 — 미발견 정보를 그대로 노출하므로 배포에 남길 수 없다.

const CELL := 32  # Canon.TILE_SIZE

## PHASE 2 임시 고정 시드. 회차 생성(`RunState`)이 붙으면 거기서 온다.
## 지금 고정해두면 실행마다 같은 배치가 나와 greybox PLAYTEST 비교가 쉽다.
const RUN_SEED := 20260819

@onready var _status_label: Label = $UI/StatusLabel
@onready var _player: CharacterBody2D = $Player

var _floor_def: FloorDefinition
var _floor_state: FloorState
var _floor_view: FloorView
var _debug_overlay: DebugOverlay


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

	# 행동 반경 (`FLR-017` `FLR-024`). 1층은 걸을 수 있는 곳 전부가 허용 영역이지만,
	# 2층 이후에는 실제 월드가 더 넓고 그중 일부만 허용된다 (`FLR-023`).
	# 지형과 별개 개념이므로 여기서 명시적으로 만들어 넘긴다.
	_player.access_envelope = AccessService.envelope_from_floor(&"player", _floor_def)

	# 시작 위치는 회차마다 시드가 고른다 (`D-022`). 결과는 FloorState에 저장된다.
	_floor_state = FloorPopulator.populate(_floor_def, RUN_SEED)
	var start := _floor_state.start_cell
	_player.global_position = Vector2(start.x * CELL + CELL / 2.0, start.y * CELL + CELL / 2.0)

	# 층 진입 시 계단을 한 번 실체화한다 (`FAC-012`). 로드 때 다시 굴리지 않는다.
	# **이번 회차의 실제 시작점**을 기준으로 계산해야 안티 스킵이 의미를 갖는다.
	_floor_state.party_stairs.append(StairResolver.new().resolve_from(
		_floor_def, _player.access_envelope, &"party_1", RUN_SEED, start))

	var stair: WorldAnchor = _floor_state.party_stairs[0]["anchor"]

	GameLog.info("Main", "1층 로드 — 공간 %d · 통행 %d칸 · 긴 축 %d타일 · 해시 %s" % [
		_floor_def.spaces.size(), _floor_def.walkable_count(),
		_floor_def.long_axis(), _floor_def.definition_hash.substr(0, 8),
	])
	GameLog.info("Main", "함정 %d · 파밍 %d · 스폰 %d · 시작 %v · 계단 %s" % [
		_floor_def.traps.size(), _floor_def.loot_points.size(),
		_floor_def.spawn_points.size(), start, stair.key(),
	])

	# 개발용 오버레이 — 함정·파밍·계단 마커. 기본 꺼짐, F1로 토글.
	# `SYS-005`(미발견 정보 누출 금지)를 정면으로 어기므로 배포 빌드에서는 켜지지 않는다.
	# PHASE 3에서 실제 오브젝트가 생기면 역할이 끝난다.
	_debug_overlay = DebugOverlay.new()
	_debug_overlay.name = "DebugOverlay"
	_debug_overlay.definition = _floor_def
	_debug_overlay.state = _floor_state
	add_child(_debug_overlay)

	_status_label.text = "「탑」 1층 (greybox) — 공간 %d · 긴 축 %d타일 · 함정 %d · 파밍 %d\nWASD/방향키: 이동   F1: 함정·파밍·계단 표시   ESC: 종료" % [
		_floor_def.spaces.size(), _floor_def.long_axis(),
		_floor_def.traps.size(), _floor_def.loot_points.size(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameLog.info("Main", "ESC 입력 — 정상 종료 요청")
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameLog.info("Main", "창 닫기 요청 — 정상 종료")
