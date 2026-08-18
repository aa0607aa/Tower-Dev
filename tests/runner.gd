extends SceneTree
## 자체 테스트 러너 (D-015).
##
## 실행:
##   godot --headless --path . --script res://tests/runner.gd
##
## 이 러너가 하는 일은 넷뿐이다 — 발견 / 실행 / 집계 / 종료 코드.
## 테스트 로직은 절대 여기 넣지 않는다. (D-015 원칙 1)
##
## 테스트 파일 규약:
##   - `tests/test_*.gd`  ← 바로 이 폴더에만 둔다
##   - `extends RefCounted`
##   - `func run(t: TestCase) -> void` 를 가진다
##
## 헬퍼는 `tests/lib/`에 둔다. 탐색이 재귀하지 않으므로 헬퍼가 테스트로 오인되지 않는다.
## (실제로 `tests/test_case.gd`가 이 패턴에 걸려 오탐이 났고, 그래서 폴더를 나눴다.)
##
## 실패가 하나라도 있으면 non-zero로 종료해 CI에서 그대로 쓸 수 있게 한다. (원칙 4)

const TESTS_DIR := "res://tests"


func _initialize() -> void:
	var paths := _discover_test_scripts(TESTS_DIR)
	paths.sort()  # 실행 순서를 결정적으로 고정한다

	if paths.is_empty():
		printerr("테스트 파일을 찾지 못했다: %s/test_*.gd" % TESTS_DIR)
		quit(1)
		return

	var total_assertions := 0
	var all_failures: Array[String] = []
	var failed_files := 0

	print("=== 테스트 시작 (%d 파일) ===" % paths.size())

	for path in paths:
		# 파스 에러가 나면 load()가 인스턴스화 불가능한 스크립트를 돌려준다.
		# 그대로 new()를 부르면 러너 자체가 죽어 나머지 테스트가 실행되지 않는다.
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			all_failures.append("%s — 스크립트를 불러오지 못했다 (파스 에러 확인)" % path)
			failed_files += 1
			continue

		var instance: Object = script.new()
		if not instance.has_method("run"):
			all_failures.append("%s — run(t: TestCase) 메서드가 없다" % path)
			failed_files += 1
			continue

		var t := TestCase.new()
		instance.call("run", t)

		total_assertions += t.assertions
		var name := path.get_file()
		if t.failures.is_empty():
			print("  PASS  %-28s (%d 단언)" % [name, t.assertions])
		else:
			failed_files += 1
			print("  FAIL  %-28s (%d 단언, %d 실패)" % [name, t.assertions, t.failures.size()])
			for f in t.failures:
				all_failures.append("%s: %s" % [name, f])

	print("=== 결과 ===")
	print("  파일 %d · 단언 %d · 실패 %d" % [paths.size(), total_assertions, all_failures.size()])

	if all_failures.is_empty():
		print("  전부 통과")
		quit(0)
		return

	printerr("실패 목록:")
	for f in all_failures:
		printerr("  - %s" % f)
	quit(1)


## tests/ 아래에서 test_*.gd 를 재귀 없이 찾는다.
## 하위 폴더가 필요해지면 그때 재귀를 넣는다 — 지금 없는 구조를 미리 만들지 않는다.
func _discover_test_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("디렉터리를 열지 못했다: %s" % dir_path)
		return found

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append("%s/%s" % [dir_path, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	return found
