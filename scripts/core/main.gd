extends Node2D
## Main — PHASE 1 테스트 화면.
##
## 테스트 방과 플레이어를 올려 이동·충돌·카메라를 확인한다.
## 1층 고정 지형 로드(FLR-001)는 PHASE 2다. 여기 지형은 canon이 아니다.

@onready var _status_label: Label = $UI/StatusLabel


func _ready() -> void:
	GameLog.info("Main", "PHASE 1 테스트 방 준비 완료")
	_status_label.text = "「탑」 PHASE 1 — 이동/카메라 테스트\nWASD 또는 방향키: 이동   ESC: 종료"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameLog.info("Main", "ESC 입력 — 정상 종료 요청")
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameLog.info("Main", "창 닫기 요청 — 정상 종료")
