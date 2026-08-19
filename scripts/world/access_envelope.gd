class_name AccessEnvelope
extends RefCounted
## 유배자/파티별 "맵의 끝" — 행동 반경. (`FLR-017` `FLR-024` `FLR-025` `D-017`)
##
## **이것은 월드의 물리적 끝이 아니다.** 유배자에게만 적용되는 탑의 인과 제약이다.
## 경계 밖에도 실제 지리·환경·생태·NPC가 계속 존재한다 (`FLR-023`).
##
## 유배자별로 갈리는 것은 이 경계뿐이고, **지형·NPC·물체의 물리 상태는 월드가 소유해 공유**한다
## (`FLR-024`). 같은 좌표에 유배자마다 다른 벽을 두면 "실제 월드의 일부"라는 canon이 깨진다.
## 허용 영역은 유배자끼리 **겹칠 수 있고**, 겹치면 같은 물리 상태를 함께 본다.
##
## ## 왜 셀 집합이 아니라 형태(rect) 목록인가
##
## 초기 구현은 허용 셀을 전부 `Dictionary`에 넣었다. `FLR-025` **와이드 맵은 정의상 크므로**
## 1000×1000만 되어도 100만 엔트리가 된다. `D-016` §1.5의 "`Rect2i`를 경계 정본으로 삼지 마라"를
## 지키려다 반대 극단으로 간 것이었다.
##
## 지금은 **형태 목록 + 예외**로 저장한다 — 메모리가 셀 수가 아니라 **형태 수**에 비례한다.
##   - `allow_rect()` 여러 개로 넓고 불규칙한 영역을 만든다
##   - `deny_cell()` / `allow_cell()`로 구멍과 돌출을 표현한다
##
## `Rect2i` **하나**를 정본으로 삼지 않는다는 원칙은 그대로다. 여기서 rect는 형태의 조각이지
## 경계 그 자체가 아니며, `bounding_rect()`는 broad-phase 용도로만 쓴다.
##
## PHASE 2 범위: 데이터 모델까지. 실제 Player 이동 연결은 `P2-T4`.

## 이 경계가 적용되는 주체. 유배자 ID 또는 파티 ID.
var owner_id: StringName
var world_id: StringName
var region_id: StringName

## 허용 영역을 이루는 사각형 조각들. 겹쳐도 된다.
var _regions: Array[Rect2i] = []
## 사각형 안이지만 제외되는 셀 (구멍). `_regions`보다 우선한다.
var _excluded: Dictionary = {}
## 사각형 밖이지만 추가로 허용되는 셀 (돌출·숨은 공간).
var _extra: Dictionary = {}

## 허용 레이어 범위. `FAC-012`상 계단이 천장 위 공동·지하에도 놓일 수 있어 필요하다.
var min_layer: int = 0
var max_layer: int = 0


func _init(p_owner_id: StringName, p_world_id: StringName, p_region_id: StringName) -> void:
	owner_id = p_owner_id
	world_id = p_world_id
	region_id = p_region_id


func allow_rect(rect: Rect2i) -> void:
	_regions.append(rect)


## 사각형 밖의 개별 셀을 허용한다. 숨은 공간·돌출부용.
func allow_cell(cell: Vector2i) -> void:
	_extra[cell] = true
	_excluded.erase(cell)


## 사각형 안이지만 접근 불가인 셀. `_regions`보다 우선한다.
func deny_cell(cell: Vector2i) -> void:
	_excluded[cell] = true
	_extra.erase(cell)


func allow_layers(p_min: int, p_max: int) -> void:
	min_layer = p_min
	max_layer = p_max


## 저장된 형태 조각 수. **셀 수가 아니다.**
## 와이드 맵이어도 이 값이 작게 유지되는지가 확장성의 지표다.
func region_count() -> int:
	return _regions.size()


## 명시적으로 다룬 예외 셀 수 (구멍 + 돌출).
func exception_count() -> int:
	return _excluded.size() + _extra.size()


## broad-phase 최적화용 AABB.
##
## ⚠ **이것은 canon 경계가 아니다** (`D-016` §1.5). 충돌 후보를 빠르게 거르는 데만 쓴다.
## 실제 포함 여부는 반드시 `contains()`로 판정한다.
func bounding_rect() -> Rect2i:
	if _regions.is_empty() and _extra.is_empty():
		return Rect2i()
	var has_any := false
	var result := Rect2i()
	for r in _regions:
		result = result.merge(r) if has_any else r
		has_any = true
	for cell in _extra:
		var single := Rect2i(cell, Vector2i.ONE)
		result = result.merge(single) if has_any else single
		has_any = true
	return result


## 이 anchor가 허용 영역 안인가.
func contains(anchor: WorldAnchor) -> bool:
	if anchor == null:
		return false
	if anchor.world_id != world_id or anchor.region_id != region_id:
		return false
	if anchor.layer < min_layer or anchor.layer > max_layer:
		return false

	var cell := anchor.cell
	# 구멍이 사각형보다 우선한다
	if _excluded.has(cell):
		return false
	if _extra.has(cell):
		return true
	for r in _regions:
		if r.has_point(cell):
			return true
	return false


## 이 효과가 경계를 넘어갈 수 있는가.
##
## **Hard Rule** (`D-017` 4항 · 구현 인계 §1.3):
## 유배자가 원인이 된 직접 영향은 경계 밖 월드에 효과를 낼 수 없다.
## 독립 월드 시뮬레이션(NPC 자발 이동, 야생동물)은 자유롭게 통과한다.
##
## 경계 **안**은 누구든 통과 가능하다 — 막는 것은 "밖으로 나가는 것"이다.
func can_cross(source: CausalSource, destination: WorldAnchor) -> bool:
	if source == null:
		return false
	if contains(destination):
		return true
	return not source.is_exile_caused()


## 이 경계의 주인(유배자)이 갈 수 있는가. 본체 이동용 단축 함수.
func can_owner_enter(anchor: WorldAnchor) -> bool:
	return contains(anchor)
