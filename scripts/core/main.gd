extends Node2D
## Main — PHASE 3까지 반영.
##
## 1층 고정 정의를 로드해 지형을 세우고 플레이어를 시작점에 놓는다.
## PHASE 1의 `TestRoom.tscn`은 폐기했다 — canon 지형이 아니었다 (`FLR-001`).
##
## PHASE 4까지 실제로 쓰고 있다 — population · 행동 반경 · 계단 · 상호작용(줍기/버리기) ·
## 함정 발동 · 단서 표현 · 전투(공격/대시/던지기/전술 정지).
##
## 아직 없는 것: 계단 타기(층 이동, `PHASE 5`) · 인벤토리 UI와 던지기 자원(`PHASE 6`).
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

## 월드 시간 배속 (`CBT-001` `CBT-002`). 전투·함정·NPC가 전부 이 값을 거친다.
var _time := TimeScale.new()
## 살아 있는 적들. `PHASE 7`의 NPC 본체가 오면 그쪽으로 옮긴다.
var _enemies: Array[Enemy] = []
## 날아가는 중인 물체들.
var _projectiles: Array[ThrownObject] = []
## 전투 알림 (피격·처치). 발동 사실은 숨기지 않는다 — 이미 겪은 일이다.
var _combat_notice := ""
var _combat_notice_until := 0


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

	# 함정 감지 어댑터. 플레이어도 던진 물체도 적도 이걸 통해서만 자극을 만든다.
	_trap_sensor = TrapSensor.new(_floor_def, _floor_state, _player.access_envelope)

	# 유배자의 전투 상태. `RunState`가 소유한다 — 층을 넘어 따라가야 하므로
	# `FloorState`에 두면 계단을 오를 때 사라진다 (`WLD-003`).
	_player.combatant = _run.ensure_combatant(EXILE_ID)
	# 정지 중에는 플레이어가 물리적으로 움직이지 않아야 한다 (`P4-REV-001`).
	_player.time_scale = _time
	# 휘두르던 공격이 있으면 이어받는다 (`P4-REV-002`).
	if _run.attack_states.has(EXILE_ID):
		_player.attack_state = AttackState.from_save_dict(_run.attack_states[EXILE_ID])

	_spawn_enemies()

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

	_status_label.text = "「탑」 1층 (greybox) — 공간 %d · 긴 축 %d타일 · 함정 %d · 파밍 %d\nWASD: 이동  E: 줍기  Q: 버리기  좌클릭/J: 공격  Shift: 대시  F: 던지기  Tab: 정지  F1: 개발용  ESC: 종료" % [
		_floor_def.spaces.size(), _floor_def.long_axis(),
		_floor_def.traps.size(), _floor_def.loot_points.size(),
	]


## `FloorDefinition.spawn_points`에 적을 세운다.
##
## `FLR-002` — 스폰 **지점**은 고정이고 무엇이 서는지는 시드가 정한다.
## `CHR-010`(랜덤 유배자 생성 규칙)이 TBD이므로 지금은 **동일한 최소 개체**만 세운다.
## 여기서 출신·성격·스탯 분포를 만들면 TBD를 몰래 확정하는 것이 된다.
func _spawn_enemies() -> void:
	for point in _floor_def.spawn_points:
		var spawn_id: StringName = point["id"]
		var entry: Dictionary = _floor_state.spawns.get(spawn_id, {})
		if not bool(entry.get("alive", true)):
			continue

		var e := Enemy.new()
		e.name = "Enemy_%s" % spawn_id
		e.combatant = _world.ensure_combatant(StringName(entry.get("npc_id", spawn_id)))
		e.trap_sensor = _trap_sensor
		e.target = _player
		add_child(e)
		var cell: Vector2i = point["cell"]
		e.global_position = Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0)
		# 저장된 런타임 상태가 있으면 **그것이 정본**이다 (`P4-REV-002`).
		# 없으면 지금 정한 스폰 위치가 시작값이 된다.
		e.apply_runtime_dict(_world.actor_states.get(e.combatant.id, {}))
		_enemies.append(e)
	GameLog.info("Main", "적 %d체 배치" % _enemies.size())


## 지금 살아 있는 전투 대상들. 공격 판정과 투사체가 함께 쓴다.
func _enemy_targets() -> Dictionary:
	var out := {}
	for e in _enemies:
		if e == null or not is_instance_valid(e) or e.combatant == null:
			continue
		if not e.combatant.alive:
			continue
		out[e.combatant.id] = {"position": e.global_position, "combatant": e.combatant}
	return out


func _process(delta: float) -> void:
	_poll_combat_input()
	_refresh_interaction_prompt()
	_check_trap_underfoot()
	_advance_combat(delta)


## 전투 입력은 **폴링한다.** 이동(`Input.get_vector`)과 같은 방식이다.
##
## `_unhandled_input`은 실제 `InputEvent`가 전파돼야 도는데, 자동 테스트가 쓰는
## `Input.action_press()`는 **상태만 바꾸고 이벤트를 만들지 않는다.**
## 그래서 이벤트 기반으로 두면 실제 게임에서만 동작하고 E2E로는 검증할 수 없다 —
## `P3-REV-005`("게임 경로에만 있는 버그")와 정확히 같은 함정이다.
##
## 액션 게임에서 폴링은 관용적이기도 하다. ESC·F1 같은 UI성 입력만 이벤트로 남긴다.
func _poll_combat_input() -> void:
	if _player == null:
		return

	# `CBT-001` — 전술 정지. 설정서가 **결과로** 확정한 항목이다.
	# 정지 중에도 이 입력만은 받아야 풀 수 있다.
	if Input.is_action_just_pressed("tactical_pause"):
		if _time.is_paused():
			_time.resume()
		else:
			_time.pause()
		GameLog.info("Main", "월드 시간 %s" % ("정지" if _time.is_paused() else "재개"))
		return

	# 정지 중에는 다른 행동이 나가지 않는다 — 나가면 정지가 무적 시간이 된다.
	if _time.is_paused():
		return

	if Input.is_action_just_pressed("attack"):
		_player.try_attack()
	if Input.is_action_just_pressed("dash"):
		_player.try_dash()
	if Input.is_action_just_pressed("throw_item"):
		_on_throw()


## 전투 한 틱. **모든 시간이 `TimeScale`을 거친다** (`CBT-001` `CBT-002`).
func _advance_combat(engine_delta: float) -> void:
	var world_delta := _time.world_delta(engine_delta)
	if world_delta <= 0.0:
		return

	# 플레이어 공격 진행 — 유효 구간에 들어가면 그 자리에서 판정한다.
	if _player.advance_combat(world_delta):
		_resolve_player_hits()

	for e in _enemies:
		if e == null or not is_instance_valid(e):
			continue
		var r := e.tick(world_delta)
		e.move(world_delta)
		var hit: Dictionary = r.get("hit", {})
		if not hit.is_empty() and float(hit.get("damage", 0.0)) > 0.0:
			_on_player_hurt(hit)

	_sync_runtime_state()

	for p in _projectiles.duplicate():
		if p == null or not is_instance_valid(p):
			_projectiles.erase(p)
			continue
		if p.tick(world_delta):
			_projectiles.erase(p)


## 노드의 런타임 상태를 **세이브의 정본**에 밀어 넣는다 (`P4-REV-002`).
##
## 씬 노드가 정본이면 저장할 때 그 노드를 뒤져야 하고, 노드가 사라진 순간 상태도 사라진다.
## 그래서 매 틱 데이터 쪽으로 옮겨둔다 — 저장은 언제든 데이터만 보면 된다.
func _sync_runtime_state() -> void:
	for e in _enemies:
		if e == null or not is_instance_valid(e) or e.combatant == null:
			continue
		_world.actor_states[e.combatant.id] = e.to_runtime_dict()
	_run.attack_states[EXILE_ID] = _player.attack_state.to_save_dict()


## 플레이어의 유효 구간 타격. 판정은 전부 `CombatService`가 한다.
func _resolve_player_hits() -> void:
	var c: Combatant = _player.combatant
	if c == null or not c.alive:
		return
	var w := c.weapon()
	if w == null:
		return
	var targets := _enemy_targets()
	for id in CombatService.targets_in_arc(
			_player.global_position, _player.attack_state, w, targets):
		var entry: Dictionary = targets[id]
		var r := CombatService.strike(c, _player.global_position, _player.attack_state,
			id, entry["combatant"], entry["position"])
		if float(r["damage"]) <= 0.0:
			continue
		var suffix := ""
		if bool(r["critical"]):
			suffix = " [%s]" % ", ".join(r["critical_reasons"])
		GameLog.info("Main", "타격 — %s %.1f%s%s" % [
			id, float(r["damage"]), suffix, " (처치)" if bool(r["killed"]) else ""])
		_notice("처치" if bool(r["killed"]) else "명중%s" % suffix)


func _on_player_hurt(hit: Dictionary) -> void:
	var c: Combatant = _player.combatant
	GameLog.info("Main", "피격 — %.1f (남은 %.0f)" % [
		float(hit.get("damage", 0.0)), c.vitality if c != null else 0.0])
	if c != null and not c.alive:
		_notice("쓰러졌다")
	else:
		_notice("피격")


func _notice(text: String) -> void:
	_combat_notice = text
	_combat_notice_until = Time.get_ticks_msec() + 1500


## 유배자가 밟은 칸의 함정을 판정한다.
##
## **`body is Player` 같은 조건을 쓰지 않는다** (`FLR-028`). 밟았다는 사실을
## `TrapStimulus`(압력 + 체중)로 바꿔 넘길 뿐이고, 판정은 `TrapRuntime`이 데이터로 한다.
## 던진 돌·NPC도 같은 경로를 쓴다 — 그래야 원작의 "돌로 먼저 터뜨리기"가 성립한다.
func _check_trap_underfoot() -> void:
	if _floor_def == null or _floor_state == null:
		return
	# 정지 중에는 월드가 바뀌지 않는다 (`P4-REV-001`). 플레이어도 안 움직이지만
	# 판정 자체를 막아 "정지 중에 함정이 터졌다"가 구조적으로 불가능하게 한다.
	if _time.is_paused():
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
	if not _combat_notice.is_empty() and Time.get_ticks_msec() >= _combat_notice_until:
		_combat_notice = ""
	var text := ""
	if not _fired_notice.is_empty():
		if Time.get_ticks_msec() < _fired_notice_until:
			text = _fired_notice
		else:
			_fired_notice = ""
	if text.is_empty() and not _combat_notice.is_empty():
		text = _combat_notice
	if text.is_empty() and not target.is_empty():
		text = "[E] %s" % target["label"]
	if _time.is_paused():
		text = "— 정지 —   " + text
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
	if _floor_def == null or _world == null or _time.is_paused():
		return
	var target := InteractionService.best(
		_floor_def, _world, _player.access_envelope, _player_cell())
	if target.is_empty():
		return
	if ItemService.pick_up(_run, _world, _floor_state, EXILE_ID, target["id"]):
		GameLog.info("Main", "주움 — `%s`" % target["id"])
		_ground_view.refresh()


## 던지기. `FLR-028`의 "돌로 함정 먼저 터뜨리기" 공략이 여기서 성립한다.
##
## 투사체는 **자기 자극을 만들지 않는다** — 착지 위치를 `TrapSensor`에 넘길 뿐이다.
func _on_throw() -> void:
	if _time.is_paused():
		return
	if _player.combatant == null or not _player.combatant.alive:
		return
	var p := ThrownObject.new()
	p.direction = _player.facing
	p.thrower_id = EXILE_ID
	p.thrower = _player.combatant
	p.trap_sensor = _trap_sensor
	p.envelope = _player.access_envelope
	p.target_provider = _enemy_targets
	add_child(p)
	p.global_position = _player.global_position + _player.facing * 14.0
	_projectiles.append(p)
	GameLog.info("Main", "던짐 — %v 방향" % _player.facing)


## 버리기. **선 것 자리에 놓인다** — 원래 파밍 지점으로 돌아가지 않는다 (`P3-T3`).
##
## 지금은 마지막에 주운 것을 버린다. 무엇을 버릴지 고르는 UI는 인벤토리 화면의 일이고,
## 그건 `PHASE 6`(무게·장비)과 함께 다뤄야 형태가 정해진다.
func _on_drop() -> void:
	if _run == null or _world == null or _time.is_paused():
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
