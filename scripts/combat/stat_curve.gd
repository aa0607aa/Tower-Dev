class_name StatCurve
extends RefCounted
## 성장곡선 → 효율. (`CHR-007` `CHR-008` · `CBT-010`)
##
## `CHR-008`이 **"하드코딩하지 않고 Curve 데이터로 관리한다"** 고 명시했다.
## 그래서 표는 `data/curves/stat_efficiency.json`에 있고 여기서는 읽어서 보간만 한다.
##
## ## PHASE 4가 쓰는 범위
## `CHR-007`의 최종 효율은 `성장곡선 × (초기 스탯/10) × 종족 계수 × 상태 보정`이다.
## PHASE 4는 **성장곡선 항만** 쓴다. 나머지 항(재능 계수·종족·상태)은 `PHASE 6`이고
## 여기서 임의로 만들지 않는다 — 만들면 `CHR-015`·`RAC-001`을 건드리게 된다.

const CURVE_PATH := "res://data/curves/stat_efficiency.json"

static var _points: Array = []


## 스탯값의 성장곡선 효율. 표 사이는 선형 보간, 표 밖은 양 끝을 유지한다.
##
## 스탯 10에서 1.0이다 — `CHR-003`의 인간 평균이 기준점이라는 뜻이다.
static func efficiency(stat: float) -> float:
	_ensure_loaded()
	if _points.is_empty():
		return 1.0

	var first: Dictionary = _points[0]
	if stat <= float(first["stat"]):
		return float(first["efficiency"])
	var last: Dictionary = _points[_points.size() - 1]
	if stat >= float(last["stat"]):
		return float(last["efficiency"])

	for i in range(_points.size() - 1):
		var a: Dictionary = _points[i]
		var b: Dictionary = _points[i + 1]
		var sa := float(a["stat"])
		var sb := float(b["stat"])
		if stat >= sa and stat <= sb:
			var t := (stat - sa) / (sb - sa)
			return lerpf(float(a["efficiency"]), float(b["efficiency"]), t)
	return float(last["efficiency"])


static func _ensure_loaded() -> void:
	if not _points.is_empty():
		return
	var f := FileAccess.open(CURVE_PATH, FileAccess.READ)
	if f == null:
		push_error("성장곡선 데이터를 열 수 없다: %s" % CURVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("성장곡선 데이터가 사전이 아니다")
		return
	var pts: Array = (parsed as Dictionary).get("points", [])
	# 스탯 오름차순을 보장한다. 저작 순서가 흔들려도 보간이 깨지면 안 된다.
	pts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["stat"]) < float(b["stat"]))
	_points = pts
