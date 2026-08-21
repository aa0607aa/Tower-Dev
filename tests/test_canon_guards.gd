extends RefCounted
## P2-T0 — canon이 금지한 구조가 코드/데이터에 들어오는지 감시한다.
##
## 사람이 조심하는 것에 맡기면 언젠가 깨진다. 특히 아래 항목들은
## **깨져도 게임이 멀쩡히 돌아가서** 리뷰에서만 잡을 수 있고, 리뷰는 언젠가 놓친다.
##
## ## 오탐을 내지 않는 것이 가드의 생명이다
## 거짓 경보가 잦으면 사람이 가드를 끈다. 그래서 세 가지를 지킨다:
##   1. GDScript는 `#` 이후를 잘라 **실행 코드만** 본다.
##      이 저장소는 canon 근거를 주석으로 남기므로, 안 그러면 문서가 자기를 위반으로 신고한다.
##   2. JSON은 문자열을 훑지 않고 **파싱해서 키만** 본다. `_`로 시작하는 주석 키는 건너뛴다.
##      "tier_hint는 두지 않는다"라는 설명문이 위반으로 잡히면 안 된다.
##   3. 전역 RNG는 `rng.randi()` 같은 **인스턴스 호출과 구분**한다.
##      금지 대상은 시드 없는 전역 함수이지 `RandomNumberGenerator`가 아니다.
##
## 실제로 이 세 가지 모두 처음에 오탐을 냈고, 그래서 지금 형태가 됐다.

## 실행 코드에 있으면 안 되는 식별자 → 왜 안 되는지.
const FORBIDDEN_CODE := {
	"is_dummy": "SYS-009 Tier 2 — 더미 판별 플래그를 만들면 한 줄 필터로 전략이 무효화된다",
	"isDummy": "SYS-009 Tier 2 — 표기만 바꿔도 같은 위반이다",
	"dummy_flag": "SYS-009 Tier 2 — 더미 판별 플래그 금지",
	"var stair_id": "FAC-002 — 계단은 party_stairs[] 배열이다. 단일 stair_id로 모델링하지 않는다",
}

## 배포 데이터(JSON)에 있으면 안 되는 **키**.
const FORBIDDEN_DATA_KEYS := {
	"tier_hint": "D-016 — 파밍 지점 등급 힌트는 좋은 곳/나쁜 곳을 마이닝에 노출한다",
	"is_dummy": "SYS-009 Tier 2 — 더미 판별 플래그 금지",
	"dummy": "SYS-009 Tier 2 — 더미 판별 플래그 금지",
	"stair_id": "FAC-002 — 계단은 party_stairs[] 배열이다",
	"trap_type_pool": "FLR-001 — 1층 함정 종류는 고정이다. 시드로 뽑지 않는다",
}

## `SYS-003` — **시드 없는 전역** RNG. `rng.randi()` 같은 인스턴스 호출은 대상이 아니다.
const GLOBAL_RNG_PATTERNS := [
	"randi", "randf", "randi_range", "randf_range", "randfn", "randomize",
]

const SELF_PATH := "res://tests/test_canon_guards.gd"


## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
##
## GDScript의 런타임 스크립트 에러는 **그 함수만** 중단시키고 `run()`은 계속 진행한다.
## 그래서 남은 단언이 조용히 사라져도 러너에는 PASS로 보인다 — 실제로 겪었다.
## 하한을 못박아 두면 그런 유실이 실패로 드러난다.
## 단언을 **추가**할 때는 손댈 필요 없고, 의도적으로 **줄일** 때만 함께 낮춘다.
const MIN_ASSERTIONS := 179


func run(t: TestCase) -> void:
	var scripts := _collect("res://scripts", ".gd")
	var test_scripts := _collect("res://tests", ".gd")
	var data_files := _collect("res://data", ".json")

	t.assert_true(scripts.size() > 0, "검사할 스크립트를 찾아야 한다")
	t.assert_true(data_files.size() > 0, "검사할 데이터 파일을 찾아야 한다")

	_test_forbidden_code_identifiers(t, scripts)
	_test_forbidden_data_keys(t, data_files)
	_test_no_global_rng(t, scripts + test_scripts)
	_test_terrain_ownership_location(t)
	_test_no_floor1_terrain_generator(t)
	t.done()


## 실행 코드의 금지 식별자.
##
## `tests/`는 제외한다 — 테스트는 금지 항목의 **부재를 단언**하느라 그 이름을 정당하게 쓴다.
## 실제로 `test_floor_population.gd`가 `tier_hint`를 언급해 오탐이 났었다.
## 배포되는 것은 `scripts/`와 `data/`이므로 거기만 막으면 충분하다.
func _test_forbidden_code_identifiers(t: TestCase, files: Array[String]) -> void:
	for path in files:
		var code := _strip_gd_comments(_read(path))
		for needle in FORBIDDEN_CODE:
			t.assert_true(not code.contains(needle),
				"%s 에 금지 식별자 `%s` — %s" % [path, needle, FORBIDDEN_CODE[needle]])


## 배포 데이터의 금지 **키**.
##
## 문자열을 훑지 않고 파싱해서 키를 본다. 설명문에 "tier_hint를 두지 않는다"가 있어도
## 그건 키가 아니므로 걸리지 않는다. `_`로 시작하는 주석 키는 건너뛴다.
func _test_forbidden_data_keys(t: TestCase, files: Array[String]) -> void:
	for path in files:
		var parsed: Variant = JSON.parse_string(_read(path))
		t.assert_true(parsed != null, "%s 이 유효한 JSON이어야 한다" % path)
		if parsed == null:
			continue
		var offenders: Array[String] = []
		_walk_keys(parsed, offenders)
		for key in offenders:
			t.assert_true(false, "%s 에 금지 키 `%s` — %s" % [path, key, FORBIDDEN_DATA_KEYS[key]])
		t.assert_true(offenders.is_empty(), "%s 에 금지 키가 없어야 한다" % path)


func _walk_keys(node: Variant, out: Array[String]) -> void:
	match typeof(node):
		TYPE_DICTIONARY:
			for k in (node as Dictionary):
				var key := String(k)
				if key.begins_with("_"):
					continue  # 주석 키
				if FORBIDDEN_DATA_KEYS.has(key):
					out.append(key)
				_walk_keys((node as Dictionary)[k], out)
		TYPE_ARRAY:
			for item in (node as Array):
				_walk_keys(item, out)


## `SYS-003` — 게임 로직에서 시드 없는 전역 RNG를 쓰면 결정성이 조용히 깨진다.
##
## `rng.randi()`처럼 **앞에 `.`이 붙은 인스턴스 호출은 정상**이다.
## 금지 대상은 `randi()`처럼 전역으로 부르는 것뿐이다.
func _test_no_global_rng(t: TestCase, files: Array[String]) -> void:
	var re := RegEx.new()
	# 앞에 단어문자·점이 없는 곳에서 시작하는 호출만 잡는다
	re.compile("(?<![\\w.])(%s)\\s*\\(" % "|".join(GLOBAL_RNG_PATTERNS))

	for path in files:
		if path == SELF_PATH:
			continue
		var code := _strip_gd_comments(_read(path))
		var m := re.search(code)
		t.assert_true(m == null,
			"%s 에 전역 RNG `%s` — SYS-003: 시드를 보관하는 RandomNumberGenerator를 쓸 것"
			% [path, "" if m == null else m.get_string()])


## `FLR-024` — 지형 상태는 월드가 소유한다. 유배자/층 단위로 복제되면 안 된다.
## 파일 위치가 소유권의 표현이다.
func _test_terrain_ownership_location(t: TestCase) -> void:
	t.assert_true(FileAccess.file_exists("res://scripts/world/terrain_mutation_state.gd"),
		"TerrainMutationState는 scripts/world/ 에 있어야 한다 (FLR-024 월드 소유)")
	for suspect in [
		"res://scripts/player/terrain_mutation_state.gd",
		"res://scripts/floor/terrain_mutation_state.gd",
		"res://scripts/world/floor_terrain_mutation_state.gd",
	]:
		t.assert_true(not FileAccess.file_exists(suspect),
			"%s 가 존재하면 지형 상태가 복제된 것이다 (FLR-024 위반)" % suspect)

	# FloorState가 지형 변경을 직접 들고 있으면 같은 위반이다
	var floor_state := _strip_gd_comments(_read("res://scripts/world/floor_state.gd"))
	t.assert_true(not floor_state.contains("TerrainMutationState"),
		"FloorState가 TerrainMutationState를 소유하면 안 된다 (FLR-024)")


## `FLR-003` / `TEST_CHECKLIST` 2-5 — 1층에 프로시저럴 **초기 지형** 생성기를 만들지 않는다.
## `FLR-027`의 플레이 중 지형 파괴는 별개다.
func _test_no_floor1_terrain_generator(t: TestCase) -> void:
	var hits: Array[String] = []
	for path in _collect("res://scripts", ".gd"):
		var name := path.get_file()
		if name.contains("floor1_generator") or name.contains("floor1_terrain_gen"):
			hits.append(path)
	t.assert_eq(hits.size(), 0, "1층 지형 생성기로 보이는 파일이 있다: %s (FLR-003)" % str(hits))

	# 로더가 시드를 받으면 그것이 곧 생성기다
	var loader := _strip_gd_comments(_read("res://scripts/world/floor_definition_loader.gd"))
	t.assert_true(not loader.contains("seed"),
		"FloorDefinitionLoader가 시드를 다루면 안 된다 — 지형은 시드와 무관하다 (FLR-002)")


# ---------------------------------------------------------------- helpers

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## `#` 이후를 잘라 실행 코드만 남긴다.
## 문자열 리터럴 안의 `#`까지 가르려면 파서가 필요하지만 가드 목적에는 과하다.
## 이 근사가 틀리는 방향은 **덜 검사하는 쪽**이라 거짓 경보로 개발을 막지 않는다.
func _strip_gd_comments(text: String) -> String:
	var out := ""
	for line in text.split("\n"):
		var idx := line.find("#")
		out += (line if idx < 0 else line.substr(0, idx)) + "\n"
	return out


func _collect(root: String, ext: String) -> Array[String]:
	var found: Array[String] = []
	_walk_dir(root, ext, found)
	found.sort()
	return found


func _walk_dir(dir_path: String, ext: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_walk_dir(full, ext, out)
		elif entry.ends_with(ext):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
