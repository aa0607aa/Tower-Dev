extends RefCounted
## `P4-RISK-001` — 적이 벽을 따라 미끄러질 때 **프레임률에 따라 더 가면 안 된다.**
##
## ## 왜 위험한가
## `move_and_collide()`가 프레임 중간에 벽에 닿으면 **남은 이동량**만 미끄러져야 한다.
## 원래 `motion` 전체를 다시 미끄러뜨리면 그 프레임에 **예산보다 더 간다.**
##
## 낮은 프레임률일수록 한 프레임의 `motion`이 크므로 초과분도 커진다 —
## 30fps에서 적이 60fps보다 빨리 벽을 타고 도는 상황이 된다. `CBT-001`(반실시간) 위반이다.
##
## ## 재현을 먼저 확인했다
## GPT 지시대로 "재현되면 고친다"를 따랐다. 수정 전 실측:
##
## | fps | 이동 거리 |
## |---|---|
## | 15 | 38.46 |
## | 30 | 36.54 |
## | 60 | 36.05 |
## | 120 | 37.40 |
##
## **낮은 프레임률에서 더 갔다** — 버그가 예측한 방향이다. 폭이 작아 처음엔 허용치(4px)에
## 묻혔다. `get_remainder()`로 고친 뒤 30/60/120이 **33.96으로 완전히 수렴**했고
## 허용치를 0.5px로 조여도 통과한다. 그래서 이 테스트는 이제 회귀를 실제로 잡는다.

const CELL := 32
## 벽을 비스듬히 밀어붙이는 총 시간(초).
const TOTAL_TIME := 0.5
## 프레임률이 달라도 이만큼 안에서 같아야 한다(px). 물리 스텝 경계 오차만 흡수한다.
const POSITION_TOLERANCE := 0.5

## 이 파일이 최소한 실행해야 하는 단언 수. (`P3-REV-008` 후속)
const MIN_ASSERTIONS := 9


func run(tree: SceneTree, t: TestCase) -> void:
	# 30 / 60 / 120 fps에 해당하는 delta로 같은 총시간을 밀어붙인다.
	var results: Array[Vector2] = []
	var distances: Array[float] = []
	for fps in [30, 60, 120]:
		var r := await _slide_along_wall(tree, 1.0 / float(fps))
		results.append(r["position"])
		distances.append(r["distance"])

	t.assert_true(distances[0] > 1.0,
		"테스트 전제: 실제로 움직였어야 한다 (30fps 이동 %.1f)" % distances[0])

	# ★ 같은 총시간이면 프레임률이 달라도 같은 자리에 있어야 한다
	t.assert_vec_almost_eq(results[0], results[1],
		"30fps와 60fps가 같은 자리여야 한다 (P4-RISK-001)", POSITION_TOLERANCE)
	t.assert_vec_almost_eq(results[1], results[2],
		"60fps와 120fps가 같은 자리여야 한다", POSITION_TOLERANCE)

	t.assert_almost_eq(distances[0], distances[1],
		"30fps와 60fps 이동 거리가 같아야 한다 (%.1f vs %.1f)" % [distances[0], distances[1]],
		POSITION_TOLERANCE)
	t.assert_almost_eq(distances[1], distances[2],
		"60fps와 120fps 이동 거리가 같아야 한다 (%.1f vs %.1f)" % [distances[1], distances[2]],
		POSITION_TOLERANCE)

	# ★ 어떤 프레임률에서도 **예산보다 더 갈 수 없다.**
	# 벽을 타면 오히려 덜 가야 한다 — 더 갔다면 미끄러짐이 이동량을 되쓴 것이다.
	var budget := Enemy.MOVE_SPEED * TOTAL_TIME
	for i in distances.size():
		t.assert_true(distances[i] <= budget + POSITION_TOLERANCE,
			"이동 예산 %.1fpx를 넘으면 안 된다 (실제 %.1f) — 미끄러짐이 이동량을 되쓴다"
			% [budget, distances[i]])

	# 소스 가드 — 충돌 후에는 **남은 이동량**을 써야 한다
	var code := ""
	for line in FileAccess.get_file_as_string("res://scripts/actors/enemy.gd").split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		code += stripped + "\n"
	t.assert_true(code.contains("get_remainder"),
		"충돌 후 미끄러짐은 남은 이동량(get_remainder)을 써야 한다 (P4-RISK-001)")

	t.done()


## 벽을 향해 비스듬히 밀어붙이고 최종 위치·이동 거리를 돌려준다.
func _slide_along_wall(tree: SceneTree, delta: float) -> Dictionary:
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(CELL * 10, CELL)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	tree.root.add_child(wall)
	wall.global_position = Vector2(0, 0)

	var enemy := Enemy.new()
	enemy.combatant = Combatant.new(&"probe")
	tree.root.add_child(enemy)
	await tree.physics_frame
	# 벽 아래쪽에 두고 **오른쪽 위 대각**으로 민다 — 벽을 따라 미끄러지게 된다.
	enemy.global_position = Vector2(-CELL * 2, CELL)
	enemy.velocity = Vector2(1, -1).normalized() * Enemy.MOVE_SPEED
	await tree.physics_frame

	var start := enemy.global_position
	var steps := int(round(TOTAL_TIME / delta))
	for i in steps:
		# 속도는 매 스텝 같게 유지한다 — AI가 방향을 바꾸면 비교가 무의미해진다.
		enemy.velocity = Vector2(1, -1).normalized() * Enemy.MOVE_SPEED
		enemy.move(delta)
		await tree.physics_frame

	var result := {
		"position": enemy.global_position,
		"distance": start.distance_to(enemy.global_position),
	}
	enemy.queue_free()
	wall.queue_free()
	await tree.physics_frame
	return result
