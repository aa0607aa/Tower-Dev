extends Node2D
## Main — PHASE 0의 최소 실행 화면.
##
## 완료 조건이 "빈 화면까지 정상 실행 · 정상 종료"이므로 게임 로직은 없다.
## 플레이어·타일맵·시뮬레이션 클럭은 PHASE 1 이후에 붙인다.

@onready var _status_label: Label = $UI/StatusLabel


func _ready() -> void:
	GameLog.info("Main", "Main 씬 준비 완료 (PHASE 0 — 게임 로직 없음)")
	_status_label.text = "「탑」 PHASE 0 — 빈 화면\nGodot %s\nESC: 종료" % \
		Engine.get_version_info().get("string", "unknown")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameLog.info("Main", "ESC 입력 — 정상 종료 요청")
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameLog.info("Main", "창 닫기 요청 — 정상 종료")
