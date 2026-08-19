class_name FloorDefinition
extends RefCounted
## 한 층의 **불변 초기 정의**. (`FLR-001` · `D-016`)
##
## 1층은 저작된 고정 지형에서, 2층 이후는 생성기에서 오지만 **둘 다 이 계약을 출력한다.**
## 게임 로직은 저작 포맷(`.json`/`.tscn`)을 직접 보지 않고 이것만 본다.
##
## ## 불변이다
## 로드 후 바뀌지 않는다. 플레이 중 생기는 변화 — 지형 파괴(`FLR-027`), 함정 소모,
## 루팅, 계단 실체화 — 는 전부 `FloorState`(층별) 또는 `TerrainMutationState`(월드 공유)로 간다.
## 이 경계가 무너지면 "초기 정의 고정"(`FLR-001`)을 검증할 방법이 사라진다.
##
## ## 시드를 받지 않는다
## 지형은 시드와 무관하게 항상 동일하다 (`FLR-002`: 시드는 전리품·유배자·상태 전용).
## 이 클래스에 시드 인자가 생기면 `TEST_CHECKLIST` 2-1이 깨진 것이다.

var floor_id: StringName
var theme_id: StringName

## 실제 월드 공간 참조 (`FLR-023`). 층은 독립 포켓맵이 아니다.
var world_id: StringName
var world_region_ref: StringName
## 자연 지형이면 지질 프로필 참조. 1층은 인공 구조물이라 비어 있다 (`D-017` 9항).
var geology_region_ref: StringName = &""

## `FLR-026` — 홀수층 개인 목표 / 짝수층 공동 목표.
enum ObjectiveScope { INDIVIDUAL, SHARED }
var objective_scope: ObjectiveScope = ObjectiveScope.INDIVIDUAL

## 저작 파일의 버전. 정의가 바뀌면 옛 세이브가 조용히 다른 좌표에 올라가는 것을 막는다 (`P2-T6`).
var layout_version: int = 0

## 이름 있는 공간. 연결성 검사·서든데스 붕괴 순서·POI 참조에 쓴다.
## { id: StringName, rect: Rect2i, tags: Array[StringName], kind: "room"/"pocket" }
var spaces: Array[Dictionary] = []

## 통행 가능한 셀. `cell → true`.
## 저작 기하를 결정적으로 전개한 결과이며 이 자체가 지형의 진실이다.
var _walkable: Dictionary = {}

var bounds: Rect2i = Rect2i()
var start_points: Array[Vector2i] = []

## 저작 기하의 구조 해시. 포맷·주석·들여쓰기가 아니라 **기하만** 반영한다.
var definition_hash: String = ""


func is_walkable(cell: Vector2i) -> bool:
	return _walkable.has(cell)


func walkable_count() -> int:
	return _walkable.size()


## 결정적 순회용. Dictionary 순서에 의존하면 해시가 흔들린다 (`SYS-003`).
func sorted_walkable_cells() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for c in _walkable:
		keys.append(c)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return keys


func space_count(kind: String = "") -> int:
	if kind.is_empty():
		return spaces.size()
	var n := 0
	for s in spaces:
		if s["kind"] == kind:
			n += 1
	return n


func long_axis() -> int:
	return maxi(bounds.size.x, bounds.size.y)


## 로더 전용. 외부에서 지형을 고치면 "불변"이 무의미해지므로 `_`를 붙였다.
func _add_walkable(cell: Vector2i) -> void:
	_walkable[cell] = true


func _finalize(p_bounds: Rect2i, p_hash: String) -> void:
	bounds = p_bounds
	definition_hash = p_hash
