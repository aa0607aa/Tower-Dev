extends Node2D
## Main — PHASE 3까지 반영.
##
## 1층 고정 정의를 로드해 지형을 세우고 플레이어를 시작점에 놓는다.
## PHASE 1의 `TestRoom.tscn`은 폐기했다 — canon 지형이 아니었다 (`FLR-001`).
##
## PHASE 3까지 실제로 쓰고 있다 — population · 행동 반경 · 계단 · 상호작용(줍기/버리기) ·
## 함정 발동 · 단서 표현.
##
## 아직 없는 것: 계단 타기(층 이동)·전투(`PHASE 4`)·인벤토리 UI(`PHASE 6`)·던지기 입력.
##
## `DebugOverlay`는 **삭제하지 않는다.** 단서 흔적 튜닝을 `PHASE 8`(도트 완성 후)로
## 미뤘고 그때 흔적 위치와 실제 함정 위치를 비교할 도구가 필요하다.
## 배포 빌드에서는 게이트로 켜지지 않는다.

const CELL := 32  # Canon.TILE_SIZE

## PHASE 2 임시 고정 시드. 회차 생성(`RunState`)이 붙으면 거기서 온다.
## 지금 고정해두면 실행마다 같은 배치가 나와 greybox PLAYTEST 비교가 쉽다.
const RUN_SEED := 20260819

@onready var _status_label: Label = $UI/StatusLabel
@onready var _prompt_label: Label = $UI/InteractionPrompt
@onready var _player: CharacterBody2D = $Player

var _floor_def: FloorDefinition
var _floor_state: FloorState
var _floor_view: FloorView
var _debug_overlay: DebugOverlay
var _ground_view: GroundItemView
var _clue_view: ClueView
## 마지막으로 표시한 프롬프트. 매 프레임 Label을 건드리지 않으려고 들고 있는다.
var _prompt_text := ""
## 함정 발동 알림. 발동했다는 사실은 숨기지 않는다 — 이미 겪은 일이다 (`SYS-005`).
var _fired_notice := ""
var _fired_notice_until := 0

## 회차/월드 상태 (`WLD-003` 3계층). `FloorState`만 있던 시절과 달리
## 인벤토리·바닥 물건이 살 자리가 생겼다 (`P3-T2a`).
var _run: RunState
var _world: WorldState

## 이 유배자의 id. 랜덤 유배자 생성 규칙(`CHR-010`)은 TBD라 지금은 고정값이다.
const EXILE_ID := &"player"

## 유배자 체중(kg). **DESIGN이며 canon 아님** — 무게/운반 공식은 `PHASE 6` TBD다.
## 함정 압력 판정에 필요한 최소 표현이라 여기 둔다.
const EXILE_MASS := 70.0

## 물리 사건 → 함정 자극 어댑터 (`P3-REV-008`). 마지막 칸 기억도 여기 있다.
var _trap_sensor: TrapSensor


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

	# 회차 → 월드 → 층 (`WLD-003`). 인벤토리는 회차에, 바닥 물건은 월드에 붙는다.
	_run = RunState.new(RUN_SEED)
	_world = _run.ensure_world(_floor_def.world_id)

	# 시작 위치는 회차마다 시드가 고른다 (`D-022`). 결과는 FloorState에 저장된다.
	_floor_state = FloorPopulator.populate(_floor_def, RUN_SEED)
	_world.put_floor(_floor_state)
	var start := _floor_state.start_cell
	_player.global_position = Vector2(start.x * CELL + CELL / 2.0, start.y * CELL + CELL / 2.0)

	# 층 진입 시 계단을 한 번 실체화한다 (`FAC-012`). 로드 때 다시 굴리지 않는다.
	# **이번 회차의 실제 시작점**을 기준으로 계산해야 안티 스킵이 의미를 갖는다.
	_floor_state.party_stairs.append(StairResolver.new().resolve_from(
		_floor_def, _player.access_envelope, &"party_1", RUN_SEED, start))

	# 함정 감지 어댑터. 플레이어도 던진 물체도 이걸 통해서만 자극을 만든다.
	_trap_sensor = TrapSensor.new(_floor_def, _floor_state, _player.access_envelope)

	# 파밍 결과를 바닥에 실체화한다 (`P3-T3`). 멱등하므로 로드 후 다시 불러도 복제되지 않는다.
	var materialized := ItemService.materialize_floor_loot(_world, _floor_def, _floor_state)

	var stair: WorldAnchor = _floor_state.party_stairs[0]["anchor"]

	GameLog.info("Main", "1층 로드 — 공간 %d · 통행 %d칸 · 긴 축 %d타일 · 해시 %s" % [
		_floor_def.spaces.size(), _floor_def.walkable_count(),
		_floor_def.long_axis(), _floor_def.definition_hash.substr(0, 8),
	])
	GameLog.info("Main", "함정 %d · 파밍 %d · 스폰 %d · 시작 %v · 계단 %s" % [
		_floor_def.traps.size(), _floor_def.loot_points.size(),
		_floor_def.spawn_points.size(), start, stair.key(),
	])
	GameLog.info("Main", "바닥 물건 %d개 실체화" % materialized)

	# 함정 단서 흔적 (`P3-T6`). 함정 칸을 찍어주는 것이 아니라 **주변 흔적**만 그린다 —
	# 정확히 찍으면 단서가 아니라 정답이 된다 (`FLR-011` `SYS-005`).
	_clue_view = ClueView.new()
	_clue_view.name = "Clues"
	_clue_view.definition = _floor_def
	_clue_view.state = _floor_state
	add_child(_clue_view)
	_clue_view.refresh()

	# 바닥 물건 표시. **눈에 보이는 것만** 그린다 — 함정은 그리지 않는다 (`SYS-005`).
	_ground_view = GroundItemView.new()
	_ground_view.name = "GroundItems"
	_ground_view.world = _world
	# 지금 보고 있는 구역만 그린다 (`P3-REV-003`).
	_ground_view.region_id = _floor_def.world_region_ref
	add_child(_ground_view)
	_ground_view.refresh()

	# 개발용 오버레이 — 함정·파밍·계단 마커. 기본 꺼짐, F1로 토글.
	# `SYS-005`(미발견 정보 누출 금지)를 정면으로 어기므로 배포 빌드에서는 켜지지 않는다.
	# PHASE 3에서 실제 오브젝트가 생기면 역할이 끝난다.
	_debug_overlay = DebugOverlay.new()
	_debug_overlay.name = "DebugOverlay"
	_debug_overlay.definition = _floor_def
	_debug_overlay.state = _floor_state
	add_child(_debug_overlay)

	_status_label.text = "「탑」 1층 (greybox) — 공간 %d · 긴 축 %d타일 · 함정 %d · 파밍 %d\nWASD/방향키: 이동   E: 줍기   Q: 버리기   F1: 개발용 표시   ESC: 종료" % [
		_floor_def.spaces.size(), _floor_def.long_axis(),
		_floor_def.traps.size(), _floor_def.loot_points.size(),
	]


func _process(_delta: float) -> void:
	_refresh_interaction_prompt()
	_check_trap_underfoot()


## 유배자가 밟은 칸의 함정을 판정한다.
##
## **`body is Player` 같은 조건을 쓰지 않는다** (`FLR-028`). 밟았다는 사실을
## `TrapStimulus`(압력 + 체중)로 바꿔 넘길 뿐이고, 판정은 `TrapRuntime`이 데이터로 한다.
## 던진 돌·NPC도 같은 경로를 쓴다 — 그래야 원작의 "돌로 먼저 터뜨리기"가 성립한다.
func _check_trap_underfoot() -> void:
	if _floor_def == null or _floor_state == null:
		return
	# 자극 생성은 **어댑터 한 곳**에서만 한다 (`P3-REV-008`).
	# 플레이어·던진 물체·NPC가 각자 자극을 만들면 한쪽만 잘못 보내는 버그가 다시 난다 —
	# 실제로 `P3-REV-005`가 그랬다.
	var fired := _trap_sensor.sense_body(
		EXILE_ID, _player.global_position, EXILE_MASS,
		CausalSource.new(EXILE_ID, CausalSource.Kind.BODY))
	var cell := _player_cell()
	for trap_id in fired:
		# 피해·부상은 `PHASE 4`/`PHASE 6`이다. 지금은 발동 사실만 알린다.
		GameLog.info("Main", "함정 발동 — `%s` @%v" % [trap_id, cell])
		_fired_notice = "함정이 작동했다"
		_fired_notice_until = Time.get_ticks_msec() + 2500
		# 흔적을 다시 그린다. **터졌다고 무조건 지우는 것이 아니라**
		# 무장이 풀린 함정만 지운다 — 반복형 함정은 발동 뒤에도 위험이 남는다 (`P3-REV-001`).
		_clue_view.refresh()


## 지금 상호작용할 수 있는 것을 화면에 알린다.
##
## **발견된 정보 범위 안에서만** 말한다 — 함정은 후보에 아예 들어오지 않고,
## 라벨은 아이템 내용물도 말하지 않는다 (`SYS-005` · `InteractionService` 주석 참조).
func _refresh_interaction_prompt() -> void:
	if _floor_def == null or _floor_state == null:
		return
	var target := InteractionService.best(
		_floor_def, _world, _player.access_envelope, _player_cell())
	var carried := _run.inventory(EXILE_ID).size()
	var text := ""
	if not _fired_notice.is_empty():
		if Time.get_ticks_msec() < _fired_notice_until:
			text = _fired_notice
		else:
			_fired_notice = ""
	if text.is_empty() and not target.is_empty():
		text = "[E] %s" % target["label"]
	if carried > 0:
		# 개수만 말한다. 무엇을 들고 있는지 표시하는 것은 인벤토리 UI(PHASE 3 후반)의 일이다.
		text += ("   " if not text.is_empty() else "") + "소지품 %d   [Q] 버리기" % carried
	if text != _prompt_text:
		_prompt_text = text
		_prompt_label.text = text


func _player_cell() -> Vector2i:
	return Vector2i(
		floori(_player.global_position.x / CELL),
		floori(_player.global_position.y / CELL))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameLog.info("Main", "ESC 입력 — 정상 종료 요청")
		get_tree().quit()
		return

	if event.is_action_pressed("interact"):
		_on_interact()
		return

	if event.is_action_pressed("drop_item"):
		_on_drop()


## 줍기. 소유권 이동은 전부 `ItemService`가 하고 여기서는 입력만 잇는다.
func _on_interact() -> void:
	if _floor_def == null or _world == null:
		return
	var target := InteractionService.best(
		_floor_def, _world, _player.access_envelope, _player_cell())
	if target.is_empty():
		return
	if ItemService.pick_up(_run, _world, _floor_state, EXILE_ID, target["id"]):
		GameLog.info("Main", "주움 — `%s`" % target["id"])
		_ground_view.refresh()


## 버리기. **선 것 자리에 놓인다** — 원래 파밍 지점으로 돌아가지 않는다 (`P3-T3`).
##
## 지금은 마지막에 주운 것을 버린다. 무엇을 버릴지 고르는 UI는 인벤토리 화면의 일이고,
## 그건 `PHASE 6`(무게·장비)과 함께 다뤄야 형태가 정해진다.
func _on_drop() -> void:
	if _run == null or _world == null:
		return
	var inv: Array = _run.inventory(EXILE_ID)
	if inv.is_empty():
		return
	var last: ItemInstance = inv[inv.size() - 1]
	var at := WorldAnchor.new(
		_floor_def.world_id, _floor_def.world_region_ref, _player_cell(), 0)
	if ItemService.drop(_run, _world, EXILE_ID, last.instance_id, at,
			_player.access_envelope):
		GameLog.info("Main", "버림 — `%s` @%v" % [last.instance_id, at.cell])
		_ground_view.refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameLog.info("Main", "창 닫기 요청 — 정상 종료")
