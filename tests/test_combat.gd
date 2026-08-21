extends RefCounted
## `P4-T1`~`P4-T3` — 피해 계산·공격 타이밍·공간 판정.
## (`CBT-003` `CBT-004` `CBT-006` `CBT-007` `CBT-008` `CBT-010` `CBT-011` `CBT-012` `CBT-013`)
##
## ## 이 파일이 지키는 것
## 전투는 canon 밀도가 가장 높은 영역이다. 특히 **하면 안 되는 것**이 명시돼 있다:
##   - `CBT-004`: 크리티컬을 확률 굴림으로 만들면 canon 위반
##   - `CBT-006`: 명중/회피·급소 배율은 **TBD** — 임의 확정 금지
##   - `CBT-010`: 성장곡선 효율을 그대로 곱하면 안 된다 (압축 필수)
##   - `CBT-011`: `BodyResilience`는 비노출
##   - `CBT-012`: 무기별 스탯 비중을 코드에 하드코딩 금지

## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 하한을 못박아 두면 그렇게 사라진 단언이 실패로 드러난다.
const MIN_ASSERTIONS := 62


func run(t: TestCase) -> void:
	_test_weapon_data_loads(t)
	_test_stat_curve(t)
	_test_scaling_is_compressed(t)
	_test_damage_uses_four_stage_formula(t)
	_test_critical_is_not_random(t)
	_test_ambush_favors_short_reach(t)
	_test_resilience_is_not_exposed(t)
	_test_no_hardcoded_weapon_branches(t)
	_test_attack_phases(t)
	_test_attack_is_frame_rate_independent(t)
	_test_spatial_hit_detection(t)
	_test_vital_hit_is_spatial(t)
	_test_strike_applies_damage_once(t)
	_test_combat_state_roundtrip(t)
	_test_time_scale(t)
	t.done()


func _test_weapon_data_loads(t: TestCase) -> void:
	var dagger := WeaponData.get_weapon(&"starting_dagger")
	t.assert_true(dagger != null, "초기 대거가 있어야 한다 (FLR-007)")
	if dagger == null:
		return
	t.assert_true(dagger.reach > 0.0, "리치가 있어야 한다")
	t.assert_true(dagger.base_attack > 0.0, "기본 공격력이 있어야 한다")
	t.assert_true(not dagger.stat_weights.is_empty(),
		"무기가 스탯 비중을 가져야 한다 (CBT-012)")

	# `CBT-012` — 단검은 힘과 민첩을 함께 쓴다
	t.assert_true(float(dagger.stat_weights.get("STR", 0)) > 0.0, "단검은 힘을 쓴다")
	t.assert_true(float(dagger.stat_weights.get("AGI", 0)) > 0.0, "단검은 민첩도 쓴다")

	# `FLR-007` — 대거의 약점은 짧은 리치
	var sword := WeaponData.get_weapon(&"rusty_shortsword")
	t.assert_true(sword != null, "비교용 무기가 있어야 한다")
	if sword != null:
		t.assert_true(dagger.reach < sword.reach,
			"대거의 리치가 더 짧아야 한다 (FLR-007 — 약점은 짧은 리치)")

	t.assert_true(dagger.total_duration() > 0.0, "공격 구간 합이 0이면 안 된다")


## `CHR-008` — 성장곡선은 데이터에서 온다. 스탯 10에서 효율 1.0.
func _test_stat_curve(t: TestCase) -> void:
	t.assert_almost_eq(StatCurve.efficiency(10.0), 1.0, "스탯 10의 효율은 1.0 (CHR-003 기준점)", 0.001)
	t.assert_almost_eq(StatCurve.efficiency(100.0), 8.0, "표의 기준점이 그대로 나와야 한다", 0.001)
	t.assert_almost_eq(StatCurve.efficiency(2000.0), 220.0, "표의 기준점이 그대로 나와야 한다", 0.001)

	# 단조 증가여야 한다 — 스탯을 올렸는데 약해지면 안 된다
	var prev := 0.0
	for s in [10, 50, 200, 1000, 2000, 3000, 5000]:
		var e := StatCurve.efficiency(float(s))
		t.assert_true(e >= prev, "성장곡선은 단조 증가여야 한다 (스탯 %d)" % s)
		prev = e

	# 표 사이는 보간, 표 밖은 양 끝 유지
	var mid := StatCurve.efficiency(40.0)
	t.assert_true(mid > 2.5 and mid < 4.0, "표 사이는 보간돼야 한다 (실제 %.2f)" % mid)
	t.assert_almost_eq(StatCurve.efficiency(99999.0), 380.0, "표 밖은 끝값을 유지한다", 0.001)
	t.assert_almost_eq(StatCurve.efficiency(1.0), 1.0, "표 아래도 끝값을 유지한다", 0.001)

	# `CHR-008` — 하드코딩 금지
	var src := FileAccess.get_file_as_string("res://scripts/combat/stat_curve.gd")
	t.assert_true(src.contains("data/curves/"),
		"성장곡선은 Curve 데이터로 관리해야 한다 (CHR-008)")


## ★ `CBT-010` CANON — 효율을 그대로 곱하지 않는다. 압축해야 한다.
func _test_scaling_is_compressed(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return

	var low := DamageModel.stat_scaling(w, {"STR": 10, "AGI": 10, "INT": 10})
	var high := DamageModel.stat_scaling(w, {"STR": 5000, "AGI": 5000, "INT": 10})

	t.assert_almost_eq(low, 1.0, "인간 평균에서 스케일링이 1.0이어야 한다", 0.01)
	t.assert_true(high > low, "스탯이 오르면 스케일링도 올라야 한다")

	# ★ 핵심: 효율 380배가 공격력 380배가 되면 안 된다
	var efficiency_ratio := StatCurve.efficiency(5000.0) / StatCurve.efficiency(10.0)
	var scaling_ratio := high / low
	t.assert_true(scaling_ratio < efficiency_ratio,
		"압축되지 않았다 — 효율 %.0f배가 스케일링 %.0f배가 되면 안 된다 (CBT-010)"
		% [efficiency_ratio, scaling_ratio])
	t.assert_almost_eq(scaling_ratio, sqrt(efficiency_ratio),
		"압축은 √이어야 한다 (CBT-003 StatScaling ≈ √효율)", 0.5)


## `CBT-003` — 4단계 식이 실제로 그 형태여야 한다.
func _test_damage_uses_four_stage_formula(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var stats := {"STR": 10, "AGI": 10, "INT": 10}

	# 방어가 오르면 피해가 줄어든다
	var no_armor := DamageModel.resolve(w, stats, 0.0, 1.0)
	var heavy := DamageModel.resolve(w, stats, 200.0, 1.0)
	t.assert_true(float(heavy["damage"]) < float(no_armor["damage"]),
		"방어가 높으면 피해가 줄어야 한다")

	# 관통이 방어를 깎는다
	t.assert_almost_eq(float(no_armor["effective_armor"]), 0.0,
		"방어 0이면 유효 방어도 0", 0.001)
	var partial := DamageModel.resolve(w, stats, 10.0, 1.0)
	t.assert_true(float(partial["effective_armor"]) < 10.0,
		"관통이 방어를 깎아야 한다 (실제 %.1f)" % float(partial["effective_armor"]))
	t.assert_true(float(partial["effective_armor"]) >= 0.0,
		"유효 방어는 음수가 되면 안 된다 (max(0, ...))")

	# BodyResilience로 나눈다
	var tough := DamageModel.resolve(w, stats, 0.0, 2.0)
	t.assert_almost_eq(float(tough["damage"]), float(no_armor["damage"]) / 2.0,
		"BodyResilience로 나눠야 한다", 0.01)

	# Motion/Skill/Condition이 곱해진다
	var boosted := DamageModel.resolve(w, stats, 0.0, 1.0, {"motion": 2.0})
	t.assert_almost_eq(float(boosted["raw_attack"]), float(no_armor["raw_attack"]) * 2.0,
		"Motion이 RawAttack에 곱해져야 한다", 0.01)

	# 결정적이어야 한다 — 같은 입력이면 같은 결과 (SYS-003)
	for i in 5:
		var again := DamageModel.resolve(w, stats, 10.0, 1.0)
		t.assert_almost_eq(float(again["damage"]), float(partial["damage"]),
			"같은 입력은 항상 같은 피해여야 한다", 0.0001)


## ★★ `CBT-004` CANON — 크리티컬은 확률이 아니다.
func _test_critical_is_not_random(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var stats := {"STR": 10, "AGI": 10, "INT": 10}

	# 아무 사건도 없으면 크리티컬이 아니다 — 100번 돌려도
	for i in 100:
		var r := DamageModel.resolve(w, stats, 0.0, 1.0)
		if bool(r["critical"]):
			t.assert_true(false, "사건 없이 크리티컬이 났다 — 확률 굴림이 있다 (CBT-004 위반)")
			break
	t.assert_true(true, "사건 없이는 크리티컬이 나지 않는다 (100회 확인)")

	# 사건이 있으면 크리티컬이고, 이유가 남는다
	var vital := DamageModel.resolve(w, stats, 0.0, 1.0, {"vital_hit": true})
	t.assert_true(bool(vital["critical"]), "급소 적중은 크리티컬이다 (CBT-013)")
	t.assert_true((vital["critical_reasons"] as Array).has("급소"), "이유가 기록돼야 한다")

	var breaking := DamageModel.resolve(w, stats, 0.0, 1.0, {"weapon_breaking": true})
	t.assert_true(bool(breaking["critical"]),
		"무기 수명이 끝나는 최후의 일격은 크리티컬이다 (ITM-003)")

	var ambush := DamageModel.resolve(w, stats, 0.0, 1.0, {"ambush": true})
	t.assert_true(bool(ambush["critical"]), "완벽한 기습은 크리티컬이다")

	# ★ 소스 가드 — 피해 계산에 난수가 있으면 안 된다
	var r := "rand"
	# 주석은 "이렇게 하면 canon 위반"이라고 설명하느라 금지어를 쓸 수밖에 없다 — 코드만 본다.
	var src := _code_only(FileAccess.get_file_as_string("res://scripts/combat/damage_model.gd"))
	for forbidden in [r + "i(", r + "f(", r + "f_range", r + "i_range", "RandomNumberGenerator"]:
		t.assert_true(not src.contains(forbidden),
			"크리티컬/피해에 난수를 쓰면 canon 위반이다 (CBT-004 — `%s`)" % forbidden)

	# 급소 **배율**은 TBD다 — 기본값이 1.0이어야 한다 (CBT-006)
	var no_mult := DamageModel.resolve(w, stats, 0.0, 1.0, {"vital_hit": true})
	var plain := DamageModel.resolve(w, stats, 0.0, 1.0)
	t.assert_almost_eq(float(no_mult["damage"]), float(plain["damage"]),
		"급소 배율은 TBD이므로 기본값이 피해를 바꾸면 안 된다 (CBT-006)", 0.0001)


## `CBT-007` CANON(방향) — 기습은 관통에 작용하고, 리치가 짧을수록 크다.
func _test_ambush_favors_short_reach(t: TestCase) -> void:
	var dagger := WeaponData.get_weapon(&"starting_dagger")
	var sword := WeaponData.get_weapon(&"rusty_shortsword")
	if dagger == null or sword == null:
		return

	var dagger_bonus := DamageModel.ambush_penetration_bonus(dagger)
	var sword_bonus := DamageModel.ambush_penetration_bonus(sword)
	t.assert_true(dagger_bonus > sword_bonus,
		"리치가 짧을수록 암습 보정이 커야 한다 (CBT-007 — 대거 %.2f, 숏소드 %.2f)"
		% [dagger_bonus, sword_bonus])
	t.assert_true(sword_bonus > 1.0, "보정은 1.0보다 커야 한다 (보정이 없으면 의미가 없다)")

	# 기습이 실제로 관통을 늘려 유효 방어를 깎는가
	var stats := {"STR": 10, "AGI": 10, "INT": 10}
	var normal := DamageModel.resolve(dagger, stats, 30.0, 1.0)
	var ambushed := DamageModel.resolve(dagger, stats, 30.0, 1.0, {"ambush": true})
	t.assert_true(float(ambushed["effective_armor"]) < float(normal["effective_armor"]),
		"기습은 관통을 늘려 유효 방어를 깎아야 한다 (CBT-007)")
	t.assert_true(float(ambushed["damage"]) > float(normal["damage"]),
		"그 결과 피해가 커져야 한다")


## ★ `CBT-011` CANON — `BodyResilience`는 비노출이다.
func _test_resilience_is_not_exposed(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var r := DamageModel.resolve(w, {"STR": 10, "AGI": 10, "INT": 10}, 0.0, 1.7)
	t.assert_true(not r.has("body_resilience"),
		"피해 결과에 BodyResilience를 담으면 UI가 그대로 찍는다 (CBT-011)")
	t.assert_true(not r.has("resilience"), "다른 이름으로도 노출하면 안 된다")

	# 계산에는 실제로 쓰여야 한다 — 담지 않는 것과 안 쓰는 것은 다르다
	var soft := DamageModel.resolve(w, {"STR": 10, "AGI": 10, "INT": 10}, 0.0, 1.0)
	t.assert_true(float(r["damage"]) < float(soft["damage"]),
		"BodyResilience가 높으면 피해가 줄어야 한다 (계산에는 쓰인다)")


## ★ `CBT-012` CANON — 무기별 분기를 코드에 하드코딩하면 안 된다.
func _test_no_hardcoded_weapon_branches(t: TestCase) -> void:
	for path in ["res://scripts/combat/damage_model.gd",
			"res://scripts/combat/combat_service.gd",
			"res://scripts/combat/attack_state.gd"]:
		var code := _code_only(FileAccess.get_file_as_string(path))
		for forbidden in ["dagger", "shortsword", "sword", "\"STR\"", "\"AGI\"", "\"INT\""]:
			t.assert_true(not code.contains(forbidden),
				"%s 에 무기/스탯이 하드코딩됐다 (CBT-012 — `%s`)" % [path, forbidden])


## `CBT-008` — wind-up → active → recovery 순서로 진행한다.
func _test_attack_phases(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var a := AttackState.new()

	t.assert_true(not a.is_busy(), "처음에는 공격 중이 아니다")
	t.assert_true(a.start(w, Vector2.RIGHT), "공격을 시작할 수 있어야 한다")
	t.assert_eq(int(a.phase), int(AttackState.Phase.WIND_UP), "선딜부터 시작한다")

	# 연타로 선딜을 건너뛸 수 없다
	t.assert_true(not a.start(w, Vector2.LEFT), "공격 중에는 다시 시작할 수 없다")
	t.assert_eq(a.direction, Vector2.RIGHT, "휘두르는 중에 방향이 바뀌면 안 된다")

	# 선딜 중에는 아직 유효 구간이 아니다
	a.advance(w.wind_up * 0.5)
	t.assert_eq(int(a.phase), int(AttackState.Phase.WIND_UP), "선딜 중이어야 한다")

	a.advance(w.wind_up)
	t.assert_eq(int(a.phase), int(AttackState.Phase.ACTIVE), "선딜이 끝나면 유효 구간")

	a.advance(w.active)
	t.assert_eq(int(a.phase), int(AttackState.Phase.RECOVERY), "유효가 끝나면 후딜")

	a.advance(w.recovery)
	t.assert_eq(int(a.phase), int(AttackState.Phase.IDLE), "후딜이 끝나면 대기")
	t.assert_true(a.start(w, Vector2.UP), "끝났으면 다시 공격할 수 있다")


## ★ `CBT-001` — 반실시간. 프레임률이 달라도 같은 시간에 같은 진행이어야 한다.
func _test_attack_is_frame_rate_independent(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var total := w.total_duration()

	# 큰 delta 한 번과 작은 delta 여러 번이 같은 결과를 내야 한다
	var coarse := AttackState.new()
	coarse.start(w, Vector2.RIGHT)
	coarse.advance(total * 0.999)

	var fine := AttackState.new()
	fine.start(w, Vector2.RIGHT)
	for i in 200:
		fine.advance(total * 0.999 / 200.0)

	t.assert_eq(int(coarse.phase), int(fine.phase),
		"프레임률이 달라도 같은 구간이어야 한다 (거친 %d, 촘촘 %d)"
		% [int(coarse.phase), int(fine.phase)])

	# 한 번의 delta가 여러 구간을 넘길 수 있어야 한다 — 낮은 프레임률에서 실제로 일어난다
	var jump := AttackState.new()
	jump.start(w, Vector2.RIGHT)
	jump.advance(total * 2.0)
	t.assert_eq(int(jump.phase), int(AttackState.Phase.IDLE),
		"큰 delta 하나가 공격 전체를 넘길 수 있어야 한다")


## ★ `CBT-006` 회피 — 명중은 굴림이 아니라 **공간**이 결정한다 (`CBT-008`).
func _test_spatial_hit_detection(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var a := AttackState.new()
	a.start(w, Vector2.RIGHT)
	a.advance(w.wind_up + 0.001)
	t.assert_eq(int(a.phase), int(AttackState.Phase.ACTIVE), "테스트 전제: 유효 구간")

	var origin := Vector2.ZERO
	var targets := {
		&"in_front": {"position": Vector2(w.reach * 0.5, 0), "combatant": Combatant.new(&"in_front")},
		&"behind": {"position": Vector2(-w.reach * 0.5, 0), "combatant": Combatant.new(&"behind")},
		&"too_far": {"position": Vector2(w.reach * 3.0, 0), "combatant": Combatant.new(&"too_far")},
	}

	var hit := CombatService.targets_in_arc(origin, a, w, targets)
	t.assert_true(hit.has(&"in_front"), "정면 리치 안은 맞아야 한다")
	t.assert_true(not hit.has(&"behind"), "등 뒤는 맞지 않아야 한다 (방향이 실제 데이터다)")
	t.assert_true(not hit.has(&"too_far"), "리치 밖은 맞지 않아야 한다")

	# 굴림이 아니므로 100번 해도 같은 결과여야 한다
	for i in 20:
		var again := CombatService.targets_in_arc(origin, a, w, targets)
		t.assert_eq(again, hit, "명중 판정은 결정적이어야 한다 (굴림이 아니다)")

	# 선딜 중에는 아무도 맞지 않는다
	var b := AttackState.new()
	b.start(w, Vector2.RIGHT)
	t.assert_eq(CombatService.targets_in_arc(origin, b, w, targets).size(), 0,
		"선딜 중에는 타격 판정이 없어야 한다 (CBT-008)")

	# 죽은 대상은 맞지 않는다
	var dead := Combatant.new(&"dead")
	dead.alive = false
	var dead_targets := {&"dead": {"position": Vector2(5, 0), "combatant": dead}}
	t.assert_eq(CombatService.targets_in_arc(origin, a, w, dead_targets).size(), 0,
		"죽은 대상은 다시 맞지 않는다")

	# ★ 소스 가드 — 명중 판정에 난수가 없어야 한다
	var r := "rand"
	var src := _code_only(FileAccess.get_file_as_string("res://scripts/combat/combat_service.gd"))
	for forbidden in [r + "i(", r + "f(", "RandomNumberGenerator"]:
		t.assert_true(not src.contains(forbidden),
			"명중을 굴림으로 만들면 CBT-006의 TBD를 몰래 확정하는 것이다 (`%s`)" % forbidden)


## `CBT-013` — 급소는 별도 판정이되 확률이 아니다.
func _test_vital_hit_is_spatial(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var a := AttackState.new()
	a.start(w, Vector2.RIGHT)
	a.advance(w.wind_up + 0.001)

	var origin := Vector2.ZERO
	# 궤적선 위 — 급소
	t.assert_true(CombatService.is_vital_hit(origin, a, w, Vector2(w.reach * 0.6, 0.0)),
		"궤적선 위 중심은 급소여야 한다")
	# 궤적선에서 벗어남 — 급소 아님
	t.assert_true(not CombatService.is_vital_hit(origin, a, w, Vector2(w.reach * 0.6, 20.0)),
		"궤적에서 벗어나면 급소가 아니다")
	# 등 뒤 — 급소 아님
	t.assert_true(not CombatService.is_vital_hit(origin, a, w, Vector2(-10.0, 0.0)),
		"등 뒤는 급소가 아니다")

	# 결정적이어야 한다
	for i in 10:
		t.assert_true(CombatService.is_vital_hit(origin, a, w, Vector2(w.reach * 0.6, 0.0)),
			"급소 판정은 결정적이어야 한다 (CBT-004 — 굴림이 아니다)")


func _test_strike_applies_damage_once(t: TestCase) -> void:
	var w := WeaponData.get_weapon(&"starting_dagger")
	if w == null:
		return
	var attacker := Combatant.new(&"attacker")
	var target := Combatant.new(&"target")
	var a := AttackState.new()
	a.start(w, Vector2.RIGHT)
	a.advance(w.wind_up + 0.001)

	var before := target.vitality
	var r1 := CombatService.strike(attacker, Vector2.ZERO, a, &"target", target, Vector2(10, 0))
	t.assert_true(float(r1["damage"]) > 0.0, "실제로 피해가 들어가야 한다")
	t.assert_true(target.vitality < before, "체력이 줄어야 한다")

	# 한 번의 active에서 같은 대상을 두 번 때리지 않는다
	var targets := {&"target": {"position": Vector2(10, 0), "combatant": target}}
	t.assert_eq(CombatService.targets_in_arc(Vector2.ZERO, a, w, targets).size(), 0,
		"이미 맞은 대상은 같은 공격에서 다시 잡히지 않아야 한다")

	# 죽으면 killed가 뜨고, 시체는 더 안 맞는다
	target.vitality = 0.1
	var b := AttackState.new()
	b.start(w, Vector2.RIGHT)
	b.advance(w.wind_up + 0.001)
	var r2 := CombatService.strike(attacker, Vector2.ZERO, b, &"target", target, Vector2(10, 0))
	t.assert_true(bool(r2["killed"]), "체력이 0이면 죽어야 한다")
	t.assert_true(not target.alive, "생존 플래그가 꺼져야 한다")

	var c := AttackState.new()
	c.start(w, Vector2.RIGHT)
	c.advance(w.wind_up + 0.001)
	var r3 := CombatService.strike(attacker, Vector2.ZERO, c, &"target", target, Vector2(10, 0))
	t.assert_almost_eq(float(r3["damage"]), 0.0, "시체는 더 이상 피해를 받지 않는다", 0.0001)


## `4-1` — 세이브/로드 후 전투 상태가 무결하다.
func _test_combat_state_roundtrip(t: TestCase) -> void:
	var c := Combatant.new(&"enemy_1", {"STR": 14, "AGI": 9, "INT": 7})
	c.vitality = 63.5
	c.armor = 12.0
	c.body_resilience = 1.4
	c.equipped_weapon = &"rusty_shortsword"

	var restored := Combatant.from_save_dict(
		JSON.parse_string(JSON.stringify(c.to_save_dict())))
	t.assert_eq(restored.id, c.id, "id 보존")
	t.assert_almost_eq(restored.vitality, c.vitality, "체력 보존", 0.0001)
	t.assert_almost_eq(restored.armor, c.armor, "방어 보존", 0.0001)
	t.assert_almost_eq(restored.body_resilience, c.body_resilience, "저항 보존", 0.0001)
	t.assert_eq(restored.equipped_weapon, c.equipped_weapon, "장비 보존")
	t.assert_eq(int(restored.stats.get(&"STR", 0)), 14, "스탯 보존")
	t.assert_true(restored.alive, "생존 상태 보존")

	# 공격 중이던 상태도 복원돼야 한다 — 로드하면 선딜이 사라지면 안 된다
	var w := WeaponData.get_weapon(&"starting_dagger")
	var a := AttackState.new()
	a.start(w, Vector2(0, -1))
	a.advance(w.wind_up * 0.5)
	a.hit_ids.append(&"someone")

	var ra := AttackState.from_save_dict(
		JSON.parse_string(JSON.stringify(a.to_save_dict())))
	t.assert_eq(int(ra.phase), int(a.phase), "공격 구간 보존")
	t.assert_almost_eq(ra.elapsed, a.elapsed, "구간 경과 보존", 0.0001)
	t.assert_eq(ra.weapon_id, a.weapon_id, "무기 보존")
	t.assert_vec_almost_eq(ra.direction, a.direction, "방향 보존", 0.001)
	t.assert_true(ra.hit_ids.has(&"someone"), "이미 맞은 대상 목록 보존")


## `CBT-001` — 마인드맵을 열면 완전 정지한다 (설정서가 결과로 확정한 항목).
func _test_time_scale(t: TestCase) -> void:
	var ts := TimeScale.new()
	t.assert_almost_eq(ts.world_delta(0.016), 0.016, "기본은 등속", 0.0001)
	t.assert_true(not ts.is_paused(), "기본은 정지가 아니다")

	ts.pause()
	t.assert_almost_eq(ts.world_delta(0.016), 0.0, "정지하면 월드 시간이 흐르지 않는다 (CBT-001)", 0.0001)
	t.assert_true(ts.is_paused(), "정지 상태여야 한다")

	ts.tactical()
	t.assert_true(ts.world_delta(0.016) > 0.0 and ts.world_delta(0.016) < 0.016,
		"전술 슬로모션은 느리되 멈추지는 않는다")

	ts.resume()
	t.assert_almost_eq(ts.world_delta(0.016), 0.016, "복귀하면 등속", 0.0001)

	# ★ 정지 상태로 저장했어도 로드하면 풀려야 한다 — 조작 불가로 시작하면 안 된다
	ts.pause()
	var restored := TimeScale.from_save_dict(ts.to_save_dict())
	t.assert_true(not restored.is_paused(),
		"정지 상태로 저장해도 로드하면 정상 속도여야 한다 (조작 불가 방지)")

	# `Engine.time_scale`을 건드리면 UI까지 느려진다
	var src := FileAccess.get_file_as_string("res://scripts/world/time_scale.gd")
	t.assert_true(not _code_only(src).contains("Engine.time_scale"),
		"엔진 배속을 건드리면 물리·입력·UI가 함께 느려진다")


func _code_only(src: String) -> String:
	var out := ""
	for line in src.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		out += stripped + "\n"
	return out
