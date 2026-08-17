extends Node
## Boot — 최초 진입점.
##
## PHASE 0 범위: 엔진 기동을 확인하고 Main 씬으로 넘긴다.
## 세이브 로드·RunState 생성·0층 진입 선택은 이후 PHASE에서 붙인다.

const MAIN_SCENE_PATH := "res://scenes/world/Main.tscn"


func _ready() -> void:
	GameLog.info("Boot", "「탑」 부팅 — Godot %s" % Engine.get_version_info().get("string", "unknown"))

	# _ready() 중에는 트리가 자식 추가/제거로 바쁜 상태라 change_scene_to_file()이
	# remove_child() 에러를 낸다. 한 프레임 넘기고 전환한다.
	await get_tree().process_frame

	GameLog.info("Boot", "Main 씬으로 전환: %s" % MAIN_SCENE_PATH)
	var err := get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	if err != OK:
		GameLog.error("Boot", "Main 씬 전환 실패 (err=%d)" % err)
