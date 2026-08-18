class_name AccessEnvelope
extends RefCounted
## 유배자/파티별 "맵의 끝" — 행동 반경. (`FLR-017` `FLR-024` `D-017`)
##
## **이것은 월드의 물리적 끝이 아니다.** 유배자에게만 적용되는 탑의 인과 제약이다.
## 경계 밖에도 실제 지리·환경·생태·NPC가 계속 존재한다 (`FLR-023`).
##
## 유배자별로 갈리는 것은 이 경계뿐이고, **지형·NPC·물체의 물리 상태는 월드가 소유해 공유**한다
## (`FLR-024`). 같은 좌표에 유배자마다 다른 벽을 두면 "실제 월드의 일부"라는 canon이 깨진다.
##
## 허용 영역은 유배자끼리 **겹칠 수 있다.** 겹치면 같은 물리 상태를 함께 본다.
##
## PHASE 2 범위: 최소 모델(지역 + 셀 집합)로 시작한다. 실제 형태(폴리곤·높이 밴드 등)는
## 지형 시스템이 붙는 단계에서 확장한다. **`Rect2i`를 정본으로 삼지 않는다** —
## broad-phase 최적화에는 쓸 수 있어도 canon 경계의 진실은 아니다 (D-016 §1.5).

## 이 경계가 적용되는 주체. 유배자 ID 또는 파티 ID.
var owner_id: StringName
var world_id: StringName
var region_id: StringName

## 허용 셀 집합. key() → true. 순회 순서 의존을 막기 위해 조회에만 쓴다.
var _allowed_cells: Dictionary = {}
## 허용 레이어 범위. `FAC-012`상 계단이 천장 위·지하에도 놓일 수 있어 필요하다.
var min_layer: int = 0
var max_layer: int = 0


func _init(p_owner_id: StringName, p_world_id: StringName, p_region_id: StringName) -> void:
	owner_id = p_owner_id
	world_id = p_world_id
	region_id = p_region_id


func allow_cell(cell: Vector2i) -> void:
	_allowed_cells[cell] = true


func allow_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_allowed_cells[Vector2i(x, y)] = true


func allow_layers(p_min: int, p_max: int) -> void:
	min_layer = p_min
	max_layer = p_max


func cell_count() -> int:
	return _allowed_cells.size()


## 이 anchor가 허용 영역 안인가.
func contains(anchor: WorldAnchor) -> bool:
	if anchor == null:
		return false
	if anchor.world_id != world_id or anchor.region_id != region_id:
		return false
	if anchor.layer < min_layer or anchor.layer > max_layer:
		return false
	return _allowed_cells.has(anchor.cell)


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
	# 목적지가 이 경계 안이면 애초에 넘는 게 아니다.
	if contains(destination):
		return true
	# 밖으로 나가는 경우 — 유배자 인과면 막는다.
	return not source.is_exile_caused()


## 이 경계의 주인(유배자)이 갈 수 있는가. 본체 이동용 단축 함수.
func can_owner_enter(anchor: WorldAnchor) -> bool:
	return contains(anchor)
