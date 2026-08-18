extends SceneTree
## 통합 테스트 harness — 실제 물리 프레임이 필요한 검증용 (D-015).
##
## 실행:
##   godot --headless --path . --script res://tests/integration_runner.gd
##
## `runner.gd`(단위)와 나눈 이유: 단위 테스트는 노드 없이 한 프레임에 끝나지만
## 물리 검증은 프레임을 실제로 여러 번 돌려야 한다.
##
## **이 파일에는 테스트 로직을 넣지 않는다.** 발견 / 실행 / 집계 / 종료 코드만 담당한다.
## (D-015 원칙 1) 케이스는 `tests/integration/test_*.gd`에 둔다.
##
## 케이스 파일 규약:
##   - `tests/integration/test_*.gd`
##   - `extends RefCounted`
##   - `func run(tree: SceneTree, t: TestCase) -> void`
##     프레임을 넘기려면 `await tree.physics_frame`을 쓴다.
##     노드를 root에 붙였으면 스스로 정리한다.

const CASES_DIR := "res://tests/integration"


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	var paths := _discover(CASES_DIR)
	paths.sort()  # 실행 순서를 결정적으로 고정한다

	if paths.is_empty():
		printerr("통합 테스트 케이스를 찾지 못했다: %s/test_*.gd" % CASES_DIR)
		quit(1)
		return

	var total_assertions := 0
	var all_failures: Array[String] = []

	print("=== 통합 테스트 시작 (%d 파일) ===" % paths.size())

	for path in paths:
		# 파스 에러 시 load()가 인스턴스화 불가능한 스크립트를 돌려준다. 러너가 죽지 않게 막는다.
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			all_failures.append("%s — 스크립트를 불러오지 못했다 (파스 에러 확인)" % path)
			continue

		var instance: Object = script.new()
		if not instance.has_method("run"):
			all_failures.append("%s — run(tree, t) 메서드가 없다" % path)
			continue

		var t := TestCase.new()
		await instance.call("run", self, t)

		total_assertions += t.assertions
		var file_name := path.get_file()
		if t.failures.is_empty():
			print("  PASS  %-32s (%d 단언)" % [file_name, t.assertions])
		else:
			print("  FAIL  %-32s (%d 단언, %d 실패)" % [file_name, t.assertions, t.failures.size()])
			for f in t.failures:
				all_failures.append("%s: %s" % [file_name, f])

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


func _discover(dir_path: String) -> Array[String]:
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
