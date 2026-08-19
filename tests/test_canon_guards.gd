extends RefCounted
## P2-T0 — canon이 금지한 구조가 코드에 들어오는지 감시한다.
##
## 사람이 조심하는 것에 맡기면 언젠가 깨진다. 특히 아래 항목들은
## **깨져도 게임이 멀쩡히 돌아가서** 리뷰에서만 잡을 수 있고, 리뷰는 언젠가 놓친다.
##
## 지금은 해당 코드가 대부분 아직 없다. **그래서 지금 세우는 게 싸다** —
## 포맷이 굳은 뒤에 가드를 세우면 이미 위반한 코드를 되돌려야 한다.
##
## ## 주석은 검사하지 않는다
## 이 저장소는 canon 근거를 주석으로 남기는 규칙이라 "단일 stair_id로 모델링하지 않는다" 같은
## 문장이 도처에 있다. 순진하게 grep하면 **문서가 자기 자신을 위반으로 신고한다.**
## 그래서 `#` 이후를 잘라내고 **실행되는 코드만** 검사한다.

const SCAN_DIRS := ["res://scripts", "res://tests", "res://data"]

## 코드에 있으면 안 되는 식별자 → 왜 안 되는지.
const FORBIDDEN := {
	"is_dummy": "SYS-009 Tier 2 — 더미 판별 플래그를 만들면 한 줄 필터로 전략이 무효화된다",
	"isDummy": "SYS-009 Tier 2 — 표기만 바꿔도 같은 위반이다",
	"dummy_flag": "SYS-009 Tier 2 — 더미 판별 플래그 금지",
	"tier_hint": "D-016 — 파밍 지점 등급 힌트를 고정 데이터에 두지 않기로 확정했다",
	"var stair_id": "FAC-002 — 계단은 party_stairs[] 배열이다. 단일 stair_id로 모델링하지 않는다",
}

## `SYS-003` — 전역 RNG는 시드를 남기지 않아 재로드 시 결과가 달라진다.
## `RandomNumberGenerator`를 시드와 함께 상태에 보관해야 한다.
const FORBIDDEN_GLOBAL_RNG := [
	"randi()", "randf()", "randi_range(", "randf_range(",
	"randfn(", ".pick_random(", ".shuffle(",
]

## 이 파일들은 가드 자체이므로 금지어를 문자열로 들고 있어도 된다.
const SELF_EXEMPT := ["res://tests/test_canon_guards.gd"]


func run(t: TestCase) -> void:
	var files := _collect_gd_files()
	t.assert_true(files.size() > 0, "검사할 스크립트를 찾아야 한다")

	_test_forbidden_identifiers(t, files)
	_test_no_global_rng(t, files)
	_test_terrain_ownership_location(t)
	_test_no_floor1_terrain_generator(t)


## 금지 식별자가 실행 코드에 있는가.
func _test_forbidden_identifiers(t: TestCase, files: Array[String]) -> void:
	for path in files:
		if path in SELF_EXEMPT:
			continue
		var code := _strip_comments(_read(path))
		for needle in FORBIDDEN:
			t.assert_true(not code.contains(needle),
				"%s 에 금지 식별자 `%s` — %s" % [path, needle, FORBIDDEN[needle]])


## SYS-003 — 게임 로직에서 전역 RNG를 쓰면 결정성이 조용히 깨진다.
func _test_no_global_rng(t: TestCase, files: Array[String]) -> void:
	for path in files:
		if path in SELF_EXEMPT:
			continue
		var code := _strip_comments(_read(path))
		for needle in FORBIDDEN_GLOBAL_RNG:
			t.assert_true(not code.contains(needle),
				"%s 에 전역 RNG `%s` — SYS-003: 시드를 보관하는 RandomNumberGenerator를 쓸 것" % [path, needle])


## FLR-024 — 지형 상태는 월드가 소유한다. 유배자/층 단위로 복제되면 안 된다.
##
## 파일 위치가 소유권의 표현이다. `scripts/floor/`나 유배자별 폴더로 옮겨지면
## 그 자체가 설계 의도를 잃었다는 신호다.
func _test_terrain_ownership_location(t: TestCase) -> void:
	t.assert_true(FileAccess.file_exists("res://scripts/world/terrain_mutation_state.gd"),
		"TerrainMutationState는 scripts/world/ 에 있어야 한다 (FLR-024 월드 소유)")

	# 유배자/층 단위 복제본이 생겼는지
	for suspect in [
		"res://scripts/player/terrain_mutation_state.gd",
		"res://scripts/floor/terrain_mutation_state.gd",
		"res://scripts/world/floor_terrain_mutation_state.gd",
	]:
		t.assert_true(not FileAccess.file_exists(suspect),
			"%s 가 존재하면 지형 상태가 복제된 것이다 (FLR-024 위반)" % suspect)


## FLR-003 / TEST_CHECKLIST 2-5 — 1층에 프로시저럴 **지형** 생성기를 만들지 않는다.
##
## `FLR-027`의 플레이 중 지형 파괴는 별개다. 금지하는 것은 **초기 지형 생성**이다.
func _test_no_floor1_terrain_generator(t: TestCase) -> void:
	var suspects := _find_files_matching("res://scripts", ["floor1_generator", "floor1_terrain_gen"])
	t.assert_eq(suspects.size(), 0,
		"1층 프로시저럴 지형 생성기로 보이는 파일이 있다: %s (FLR-003)" % str(suspects))


# ---------------------------------------------------------------- helpers

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## `#` 이후를 잘라 실행 코드만 남긴다.
##
## 문자열 리터럴 안의 `#`까지 정확히 가르려면 파서가 필요하지만, 가드 목적에는 과하다.
## 이 근사가 틀리는 방향은 **덜 검사하는 쪽**(코드를 주석으로 오인)이라
## 거짓 경보로 개발을 막지 않는다. 놓친 위반은 리뷰가 잡는다.
func _strip_comments(text: String) -> String:
	var out := ""
	for line in text.split("\n"):
		var idx := line.find("#")
		out += (line if idx < 0 else line.substr(0, idx)) + "\n"
	return out


func _collect_gd_files() -> Array[String]:
	var found: Array[String] = []
	for root in SCAN_DIRS:
		_walk(root, found)
	found.sort()
	return found


func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_walk(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _find_files_matching(dir_path: String, needles: Array) -> Array[String]:
	var all: Array[String] = []
	_walk(dir_path, all)
	var hits: Array[String] = []
	for path in all:
		var name := path.get_file()
		for n in needles:
			if name.contains(n):
				hits.append(path)
				break
	return hits
