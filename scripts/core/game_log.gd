extends Node
## GameLog — 개발 로그 (autoload)
##
## PHASE 0 범위: 콘솔 출력만 한다. 파일 로그·로그 레벨 필터·크래시 리포트는
## PHASE 11(안정화)에서 다룬다. 여기서 게임 상태를 보관하지 않는다.
##
## SSOT 원칙: 이 노드는 로그만 남기며 GameState를 읽거나 쓰지 않는다.

enum Level { DEBUG, INFO, WARN, ERROR }

var min_level: Level = Level.DEBUG


func debug(tag: String, message: String) -> void:
	_write(Level.DEBUG, tag, message)


func info(tag: String, message: String) -> void:
	_write(Level.INFO, tag, message)


func warn(tag: String, message: String) -> void:
	_write(Level.WARN, tag, message)


func error(tag: String, message: String) -> void:
	_write(Level.ERROR, tag, message)


func _write(level: Level, tag: String, message: String) -> void:
	if level < min_level:
		return
	var line := "[%s][%s] %s" % [Level.keys()[level], tag, message]
	if level >= Level.WARN:
		printerr(line)
	else:
		print(line)
