extends RefCounted
## `P3-T6` `P3-T7` — 정보 비대칭. (`SYS-005` `FLR-011` `ITM-002` `D-026`)
##
## ## 검사하는 것
## 배포되는 표현 계층이 **미발견 정보를 새지 않는가.**
## 개발 도구(`DebugOverlay`)는 대놓고 다 보여주므로 예외지만, **배포 경로에서 켜지면 안 된다.**
##
## ## 왜 소스를 읽어서 검사하는가
## 화면 픽셀을 검사할 수는 없다. 대신 **표현 계층이 무엇을 참조하는지**를 본다 —
## 함정 종류나 단서 텍스트를 상시 표시하는 코드가 있으면 그건 정답 표시다.


func run(t: TestCase) -> void:
	var def := FloorDefinitionLoader.load_from_file()
	t.assert_true(def != null, "1층 정의를 불러와야 한다")
	if def == null:
		return

	_test_clue_view_does_not_pinpoint(t, def)
	_test_clue_hidden_only_when_disarmed(t, def)
	_test_repeating_trap_keeps_clue(t, def)
	_test_clue_traces_are_deterministic(t, def)
	_test_views_do_not_render_clue_text(t)
	_test_ground_view_does_not_distinguish_items(t)
	_test_debug_overlay_is_gated(t)
	_test_lethal_traps_are_observable(t, def)


## ★ 단서 흔적이 함정 칸을 **정확히** 가리키면 안 된다 — 그건 정답이다.
func _test_clue_view_does_not_pinpoint(t: TestCase, def: FloorDefinition) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/world/clue_view.gd")
	t.assert_true(src.contains("SCATTER_CELLS"),
		"단서 흔적은 함정 칸 주변으로 흩어져야 한다 (정확히 찍으면 정답)")
	t.assert_true(ClueView.SCATTER_CELLS >= 1,
		"흩어짐 범위가 0이면 함정 칸을 정확히 가리키게 된다")

	# 흔적이 함정 칸에만 몰리지 않는지 실제로 확인한다.
	var view := ClueView.new()
	view.definition = def
	var off_center := 0
	var total := 0
	for trap in def.traps:
		if (trap["clues"] as Array).is_empty():
			continue
		for cell in _trace_cells(view, trap):
			total += 1
			if cell != trap["cell"]:
				off_center += 1
	t.assert_true(total > 0, "테스트 전제: 흔적이 생성돼야 한다")
	t.assert_true(off_center > 0,
		"흔적이 전부 함정 칸 위에만 있으면 정답 표시다 (총 %d / 바깥 %d)" % [total, off_center])
	view.free()


## 흔적을 지우는 기준은 **"위험이 남아 있는가"** 다 (`P3-REV-001`).
##
## 전에는 `trap_has_fired`만 봤다. 그런데 `FloorState.fire_trap()`은 `one_shot`이 아닌
## 함정의 `armed`를 true로 유지한다 — **반복해서 걸리는 치명 함정은 발동 이력이 있어도
## 여전히 위험한데 단서만 사라졌다.** `FLR-011` 위반이었다.
func _test_clue_hidden_only_when_disarmed(t: TestCase, def: FloorDefinition) -> void:
	var code := _code_only(FileAccess.get_file_as_string("res://scripts/world/clue_view.gd"))
	t.assert_true(code.contains("trap_is_armed"),
		"흔적 표시 기준은 armed(위험 잔존)여야 한다")
	t.assert_true(not code.contains("trap_has_fired"),
		"발동 이력(fired)만으로 흔적을 지우면 반복형 함정의 위험이 숨겨진다")


## ★ `P3-REV-001` — 반복형 치명 함정은 발동 뒤에도 단서가 남고, 다시 밟으면 또 걸린다.
func _test_repeating_trap_keeps_clue(t: TestCase, def: FloorDefinition) -> void:
	var repeating := {}
	var one_shot := {}
	for trap in def.traps:
		if not bool(trap["lethal"]) or (trap["clues"] as Array).is_empty():
			continue
		if bool(trap["one_shot"]):
			if one_shot.is_empty():
				one_shot = trap
		elif repeating.is_empty():
			repeating = trap
	t.assert_true(not repeating.is_empty(),
		"테스트 전제: one_shot이 아닌 치명 함정이 있어야 한다 (반복형)")
	t.assert_true(not one_shot.is_empty(), "테스트 전제: one_shot 치명 함정이 있어야 한다")
	if repeating.is_empty() or one_shot.is_empty():
		return

	var state := FloorPopulator.populate(def, 4242)
	var view := ClueView.new()
	view.definition = def
	view.state = state

	# 반복형: 발동 → 여전히 armed → 흔적 유지 → 다시 밟으면 또 걸린다
	var s1 := TrapStimulus.from_body(repeating["cell"], 70.0, &"player")
	t.assert_true(TrapRuntime.trigger(repeating, state, s1), "반복형 함정이 발동해야 한다")
	t.assert_true(state.trap_has_fired(repeating["id"]), "발동 이력이 남아야 한다")
	t.assert_true(state.trap_is_armed(repeating["id"]),
		"반복형 함정은 발동 뒤에도 무장 상태여야 한다 (FloorState.fire_trap)")
	t.assert_true(_is_visible(view, repeating),
		"위험이 남아 있으면 단서도 남아야 한다 (P3-REV-001 — FLR-011)")
	t.assert_true(TrapRuntime.trigger(repeating, state, s1),
		"재진입하면 다시 발동해야 한다 — 위험이 실재한다")

	# 발사형: 발동 → 무장 해제 → 흔적 사라짐
	var s2 := TrapStimulus.from_thrown(one_shot["cell"], 0.5, &"player")
	t.assert_true(TrapRuntime.trigger(one_shot, state, s2), "발사형 함정이 발동해야 한다")
	t.assert_true(not state.trap_is_armed(one_shot["id"]), "발사형은 무장이 풀려야 한다")
	t.assert_true(not _is_visible(view, one_shot),
		"위험이 사라진 함정의 흔적은 지워야 한다")
	view.free()


## `ClueView`가 이 함정의 흔적을 그리는가 — `_draw()`와 같은 조건을 재현한다.
func _is_visible(view: ClueView, trap: Dictionary) -> bool:
	if (trap["clues"] as Array).is_empty():
		return false
	if view.state != null and not view.state.trap_is_armed(trap["id"]):
		return false
	return not _trace_cells(view, trap).is_empty()


## 흔적 위치가 **결정적**이어야 한다.
##
## 지형 암기가 영구 성장인 게임에서(`FLR-015`) "어제 본 그 자국"이 다른 곳에 있으면
## 학습이 무의미해진다. 난수를 쓰면 안 된다 (`SYS-003`).
func _test_clue_traces_are_deterministic(t: TestCase, def: FloorDefinition) -> void:
	var a := ClueView.new()
	a.definition = def
	var b := ClueView.new()
	b.definition = def

	for trap in def.traps:
		if (trap["clues"] as Array).is_empty():
			continue
		t.assert_eq(_trace_cells(a, trap), _trace_cells(b, trap),
			"함정 `%s`의 단서 흔적 위치가 매번 같아야 한다" % trap["id"])
	a.free()
	b.free()

	var src := FileAccess.get_file_as_string("res://scripts/world/clue_view.gd")
	# 금지어를 **런타임에 조립**한다. 리터럴로 적으면 `test_canon_guards.gd`의
	# 전역 RNG 가드가 이 파일 자체를 위반으로 잡는다 — 실제로 한 번 잡혔다.
	# 가드를 느슨하게 만드는 대신 이쪽을 피한다.
	var r := "rand"
	for forbidden in [r + "i(", r + "f(", r + "i_range", "RandomNumberGenerator"]:
		t.assert_true(not src.contains(forbidden),
			"단서 흔적에 난수를 쓰면 안 된다 (`%s`)" % forbidden)


## ★ 단서 **텍스트**를 상시 표시하면 그 순간 정답이 된다.
func _test_views_do_not_render_clue_text(t: TestCase) -> void:
	for path in ["res://scripts/world/clue_view.gd",
			"res://scripts/world/ground_item_view.gd",
			"res://scripts/interaction/interaction_service.gd"]:
		var code := _code_only(FileAccess.get_file_as_string(path))
		t.assert_true(not code.contains('["clues"]') or path.ends_with("clue_view.gd"),
			"%s 가 단서 텍스트를 다루면 안 된다" % path)
		t.assert_true(not code.contains("draw_string"),
			"%s 가 단서/아이템 텍스트를 화면에 그리면 안 된다" % path)

	# ClueView는 clues를 개수 판단에만 쓰고 **문자열을 그리지 않아야** 한다.
	var clue_code := _code_only(FileAccess.get_file_as_string("res://scripts/world/clue_view.gd"))
	t.assert_true(not clue_code.contains("draw_string"),
		"단서 문장을 화면에 띄우면 정답 표시가 된다")


## 바닥 물건 표현이 **종류를 구분하면** 주워보기 전에 무엇인지 알게 된다.
## 열매는 외형만으로 효과를 확정할 수 없다 (`ITM-002` `D-026`).
func _test_ground_view_does_not_distinguish_items(t: TestCase) -> void:
	var code := _code_only(FileAccess.get_file_as_string("res://scripts/world/ground_item_view.gd"))
	for forbidden in ["item_id", "kind", "durability"]:
		t.assert_true(not code.contains(forbidden),
			"바닥 물건 표현이 `%s`로 종류를 구분하면 안 된다" % forbidden)


## `DebugOverlay`는 개발 도구다. 배포 경로에서 자동으로 켜지면 안 된다.
func _test_debug_overlay_is_gated(t: TestCase) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/world/debug_overlay.gd")
	t.assert_true(src.contains("SYS-005"),
		"DebugOverlay는 SYS-005 위반임을 스스로 밝혀야 한다")
	t.assert_true(src.contains("OS.is_debug_build") or src.contains("EngineDebugger")
			or src.contains("is_debug"),
		"DebugOverlay가 디버그 빌드에서만 켜지도록 게이트돼야 한다")


## `FLR-011` — 치명 함정은 **알아챌 수 있어야** 한다. 단서가 데이터로만 있으면 안 된다.
func _test_lethal_traps_are_observable(t: TestCase, def: FloorDefinition) -> void:
	var view := ClueView.new()
	view.definition = def

	var lethal := 0
	var observable := 0
	for trap in def.traps:
		if not bool(trap["lethal"]):
			continue
		lethal += 1
		if not _trace_cells(view, trap).is_empty():
			observable += 1

	t.assert_true(lethal > 0, "테스트 전제: 치명 함정이 있어야 한다")
	t.assert_eq(observable, lethal,
		"치명 함정 %d개 전부 화면에서 관찰 가능해야 한다 (관찰 가능 %d) — FLR-011"
		% [lethal, observable])
	view.free()


## `ClueView`가 실제로 흔적을 그릴 칸들. 그리기 로직과 같은 계산을 재현한다.
func _trace_cells(view: ClueView, trap: Dictionary) -> Array:
	var out: Array = []
	var cell: Vector2i = trap["cell"]
	var clues: Array = trap["clues"]
	var h := hash(String(trap["id"]))
	var count := mini(clues.size() + 1, 4)
	for i in count:
		var seed_i := hash(h + i * 7919)
		var dx := (seed_i % (ClueView.SCATTER_CELLS * 2 + 1)) - ClueView.SCATTER_CELLS
		var dy := ((seed_i / 13) % (ClueView.SCATTER_CELLS * 2 + 1)) - ClueView.SCATTER_CELLS
		var c := cell + Vector2i(dx, dy)
		if view.definition.is_walkable(c):
			out.append(c)
	return out


## 주석을 뺀 실제 코드만. 주석은 규칙을 설명하느라 금지어를 쓸 수밖에 없다.
func _code_only(src: String) -> String:
	var out := ""
	for line in src.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		out += stripped + "\n"
	return out
