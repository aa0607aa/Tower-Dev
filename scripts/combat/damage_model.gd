class_name DamageModel
extends RefCounted
## 4단계 피해 계산. (`CBT-003` `CBT-004` `CBT-010` `CBT-011` `CBT-013`)
##
## ## 설정서 §12.2의 식을 그대로 옮긴다
## ```text
## RawAttack       = WeaponBase × StatScaling × Motion × Skill × Condition
## StatScaling     ≈ √(관련 스탯의 최종 효율)
## Penetration     = WeaponPenetration × StatBonus × SkillBonus × AmbushBonus
## EffectiveArmor  = max(0, Armor − Penetration)
## ArmorMultiplier = 100 / (100 + EffectiveArmor)
## FinalDamage     = RawAttack × ArmorMultiplier ÷ BodyResilience
## ```
##
## ## 왜 √인가 (`CBT-010` CANON)
## 성장곡선 효율을 그대로 곱하면 **효율 380배가 공격력 380배**가 된다.
## 스탯 수천 구간까지 확장하려면 압축이 필요하고, 그 압축이 `√`다.
## 이 항을 빼거나 선형으로 바꾸면 canon 위반이다.
##
## ## 크리티컬은 확률이 아니다 (`CBT-004` CANON)
## `randf() < crit_chance` 같은 구현은 **canon 위반**이다. 크리티컬은 **실제 사건**이
## 만든다 — 급소 적중, 완벽한 기습, 특정 스킬, 무기 수명이 끝나는 최후의 일격.
## 그래서 이 클래스는 **난수를 쓰지 않는다.** 호출자가 "무슨 일이 일어났는지"를 넘기고
## 여기서는 그 사건들을 계산에 반영할 뿐이다.
##
## ## `BodyResilience`는 비노출 (`CBT-011` CANON)
## 힘 계열의 내부 파생값이며 **상태창에 표시하지 않는다.** 여기서는 계산에만 쓰고
## 결과 사전에도 담지 않는다 — 담으면 UI가 그대로 찍어버린다.
##
## ## ⚠ TBD를 임의로 채우지 않는다 (`CBT-006`)
## 명중/회피율, 부위별 급소 배율, 마법 저항은 **TBD**다.
##   - 명중/회피는 **확률 롤을 만들지 않고** 공간 판정으로 대체한다 (`CBT-008` —
##     리치·방향·충돌 박스는 실제 데이터다). 그래서 이 식에 명중률 항이 없다.
##   - 급소 배율은 `critical_multiplier` 인자로 받고 **기본값이 1.0**이다.
##     여기서 숫자를 정하면 TBD를 몰래 확정하는 것이 된다.

## `CHR-003` — 인간 평균 스탯. 성장곡선의 기준점(효율 1.0)이다.
const HUMAN_BASELINE_STAT := 10.0
## 설정서 §12.2의 방어 상수. 식에 그대로 있는 값이다.
const ARMOR_CONSTANT := 100.0


## 무기 스탯 비중과 실제 스탯으로 `StatScaling`을 구한다.
##
## `CBT-010`: 효율을 그대로 곱하지 않고 **압축**한다.
## 비중은 무기 데이터가 정한다 (`CBT-012` — 코드에 무기별 분기 금지).
##
## PHASE 4는 `CHR-007` 최종 효율 중 **성장곡선 항만** 쓴다.
## 재능 계수(초기 스탯/10)·종족 계수·상태 보정은 `PHASE 6`이다.
static func stat_scaling(weapon: WeaponData, stats: Dictionary) -> float:
	if weapon == null:
		return 1.0
	var weighted := 0.0
	var total_weight := 0.0
	# 순회 순서를 고정한다 — 부동소수 합이 순서에 따라 흔들리면 결정성이 깨진다 (`SYS-003`).
	var keys: Array = weapon.stat_weights.keys()
	keys.sort()
	for key in keys:
		var w := float(weapon.stat_weights[key])
		if w <= 0.0:
			continue
		var stat := float(stats.get(key, HUMAN_BASELINE_STAT))
		weighted += StatCurve.efficiency(stat) * w
		total_weight += w
	if total_weight <= 0.0:
		return 1.0
	# 가중 평균 효율을 압축한다.
	return sqrt(weighted / total_weight)


## 한 번의 타격 결과.
##
## 반환: `{ damage, raw_attack, effective_armor, critical, critical_reasons }`
##
## `body_resilience`는 **반환하지 않는다** (`CBT-011` 비노출).
##
## `events`는 "무슨 일이 실제로 일어났는가"다 — 확률이 아니라 사건이다 (`CBT-004`):
##   `{ vital_hit: bool, ambush: bool, weapon_breaking: bool,
##      motion: float, skill: float, condition: float,
##      critical_multiplier: float, penetration_bonus: float }`
static func resolve(weapon: WeaponData, stats: Dictionary, armor: float,
		body_resilience: float, events: Dictionary = {}) -> Dictionary:
	if weapon == null:
		return {"damage": 0.0, "raw_attack": 0.0, "effective_armor": armor,
			"critical": false, "critical_reasons": []}

	var motion := float(events.get("motion", 1.0))
	var skill := float(events.get("skill", 1.0))
	var condition := float(events.get("condition", 1.0))

	var raw_attack := weapon.base_attack * stat_scaling(weapon, stats) * motion * skill * condition

	# ## 관통 — 기습이 여기에 작용한다 (`CBT-007` CANON 방향)
	# "기습·암습은 단순 피해량보다 **관통·절삭 보정**에 특히 큰 영향을 준다."
	# 배율 자체는 TBD이므로 호출자가 넘긴 값을 쓰고 기본은 보정 없음이다.
	var penetration := weapon.penetration * float(events.get("penetration_bonus", 1.0))
	if bool(events.get("ambush", false)):
		penetration *= ambush_penetration_bonus(weapon)

	var effective_armor := maxf(0.0, armor - penetration)
	var armor_multiplier := ARMOR_CONSTANT / (ARMOR_CONSTANT + effective_armor)

	# ## 크리티컬 — 사건에서만 나온다 (`CBT-004`)
	var reasons: Array[String] = []
	if bool(events.get("vital_hit", false)):
		reasons.append("급소")          # `CBT-013` — 별도 판정으로 들어온다
	if bool(events.get("ambush", false)):
		reasons.append("기습")
	if bool(events.get("weapon_breaking", false)):
		reasons.append("무기 수명 종료") # `ITM-003` — 최후의 일격
	var critical := not reasons.is_empty()

	# 배율은 **TBD**다 (`CBT-006`). 기본 1.0 — 여기서 숫자를 정하지 않는다.
	var critical_multiplier := float(events.get("critical_multiplier", 1.0))

	var resilience := maxf(0.0001, body_resilience)
	var damage := raw_attack * armor_multiplier * critical_multiplier / resilience

	return {
		"damage": damage,
		"raw_attack": raw_attack,
		"effective_armor": effective_armor,
		"critical": critical,
		"critical_reasons": reasons,
	}


## 기습 관통 보정. **리치가 짧을수록 크다** (`CBT-007` CANON 방향 · `FLR-007`).
##
## 정확한 배율은 `CBT-006`과 함께 **TBD**다. 여기서는 방향만 구현한다 —
## 리치가 길수록 1.0에 수렴하고, 짧을수록 커진다.
## 숫자를 바꾸더라도 **단조 감소**라는 성질은 유지해야 한다.
const AMBUSH_REFERENCE_REACH := 40.0  ## DESIGN. 이 리치에서 보정이 2배가 된다.


static func ambush_penetration_bonus(weapon: WeaponData) -> float:
	if weapon == null or weapon.reach <= 0.0:
		return 1.0
	# 리치 0 → 큰 값, 리치 ∞ → 1.0 로 단조 감소.
	return 1.0 + AMBUSH_REFERENCE_REACH / weapon.reach
