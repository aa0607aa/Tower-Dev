class_name TimeScale
extends RefCounted
## 월드 시간 배속. (`CBT-001` CANON · `CBT-002` DESIGN)
##
## ## canon이 정한 것과 아닌 것
## `CBT-001`이 확정한 것은 **"마인드맵을 열면 완전 일시정지된다"** 는 **결과**다.
## 그걸 별도 클럭으로 구현할지 `Engine.time_scale`로 할지는 정해지지 않았고,
## 전술 메뉴 배속(0.1~0.2×)도 `CBT-002`의 DESIGN이다.
##
## ## 왜 `Engine.time_scale`을 쓰지 않는가
## 엔진 배속을 건드리면 **물리·입력·UI가 함께 느려진다.** 전술 메뉴에서 UI까지
## 슬로모션이 되면 조작이 불가능하다. 그래서 월드 시간만 별도로 곱한다.
##
## ## `PHASE 5`와의 경계
## `CBT-002`의 완전한 Simulation Clock(3600초 서든데스 진행)은 `PHASE 5`다.
## 여기 있는 것은 **배속 값 하나**이며, PHASE 5가 이 값을 받아 클럭을 돌리게 된다.
## 여기에 경과 시간 누적을 두지 않는다 — 두면 PHASE 5가 두 벌이 된다.

## 배속 프리셋. **DESIGN이며 canon 아님** (`CBT-002`가 "0.1~0.2×"를 예시로만 준다).
const NORMAL := 1.0
const PAUSED := 0.0
const TACTICAL := 0.15

var scale: float = NORMAL


## 이번 프레임의 **월드 시간**. 전투·함정·NPC가 전부 이 값을 받는다.
func world_delta(engine_delta: float) -> float:
	return engine_delta * scale


func is_paused() -> bool:
	return is_zero_approx(scale)


## 마인드맵 등 완전 정지 (`CBT-001` — 설정서가 결과로 확정한 유일한 항목).
func pause() -> void:
	scale = PAUSED


## 전술 메뉴 슬로모션.
func tactical() -> void:
	scale = TACTICAL


func resume() -> void:
	scale = NORMAL


func to_save_dict() -> Dictionary:
	return {"scale": scale}


static func from_save_dict(d: Dictionary) -> TimeScale:
	var t := TimeScale.new()
	# 저장 당시 일시정지 중이었어도 **로드하면 정상 속도로 돌아온다.**
	# 멈춘 채로 복원하면 플레이어가 조작할 수 없는 상태로 시작한다.
	var s := float(d.get("scale", NORMAL))
	t.scale = s if s > 0.0 else NORMAL
	return t
