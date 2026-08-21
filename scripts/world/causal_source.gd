class_name CausalSource
extends RefCounted
## 어떤 효과의 **인과 주체**가 누구인가.
##
## `FLR-024` / `D-017`의 Hard Rule을 판정하는 데 쓴다:
## **유배자가 원인이 된 직접 영향은 행동 반경(AccessEnvelope) 밖 월드에 효과를 낼 수 없다.**
## 반면 일반 NPC·야생동물이 자기 행동으로 움직이는 것은 경계와 무관하다.
##
## 경계를 못 넘는 것 (유배자 인과):
##   본체 · 소환물/펫 · 투사체 · 기술/마법의 직접 효과 · 던진 물체 ·
##   유배자의 공격/밀치기로 **강제 이동 중인** NPC·물체
##
## 자유롭게 통과하는 것:
##   일반 NPC·야생동물의 자발적 이동 · 유배자 인과에서 벗어난 월드 시뮬레이션
##
## 그래서 판정 기준은 "무엇인가"가 아니라 **"누가 원인인가"** 다.
## 같은 NPC라도 스스로 걸어가면 통과하고, 유배자가 밀치는 중이면 못 넘는다.

## 인과 주체가 없는 독립 월드 시뮬레이션을 뜻하는 값.
const NO_OWNER := &""

## 무엇이 움직이는가. 판정 자체엔 쓰지 않지만 로그·연출·디버깅에 필요하다.
enum Kind {
	BODY,        ## 유배자 본체
	SUMMON,      ## 소환물·직접 통제 펫
	PROJECTILE,  ## 발사한 투사체
	EFFECT,      ## 기술·마법의 직접 효과
	THROWN,      ## 던진/발사한 물체
	FORCED,      ## 유배자 힘으로 강제 이동 중인 NPC·물체
	INDEPENDENT, ## 유배자 인과 밖 — NPC 자발 이동, 야생동물, 월드 시뮬레이션
}

## 이 효과를 일으킨 유배자 ID. 독립 시뮬레이션이면 `NO_OWNER`.
var exile_owner_id: StringName
var kind: Kind


func _init(p_exile_owner_id: StringName = NO_OWNER, p_kind: Kind = Kind.INDEPENDENT) -> void:
	exile_owner_id = p_exile_owner_id
	kind = p_kind


## 유배자 인과에 속하는가.
##
## `INDEPENDENT`인데 소유자가 있으면 모순이므로 소유자 유무만 본다 —
## 판정을 `kind`에 맡기면 새 `Kind`가 추가될 때마다 목록을 고쳐야 하고, 빠뜨리면
## 조용히 경계를 통과한다. 소유자 유무는 그런 실수가 구조적으로 불가능하다.
func is_exile_caused() -> bool:
	return exile_owner_id != NO_OWNER


static func independent() -> CausalSource:
	return CausalSource.new(NO_OWNER, Kind.INDEPENDENT)


static func by_exile(exile_id: StringName, p_kind: Kind) -> CausalSource:
	return CausalSource.new(exile_id, p_kind)


func _to_string() -> String:
	if not is_exile_caused():
		return "CausalSource(independent)"
	return "CausalSource(%s, %s)" % [exile_owner_id, Kind.keys()[kind]]


## 저장 형식. `enum`은 정수라 값이 바뀌면 옛 세이브가 조용히 다른 종류가 된다 —
## **이름으로** 저장한다 (`P3-REV-002`).
func to_save_dict() -> Dictionary:
	return {
		"exile_owner_id": String(exile_owner_id),
		"kind": kind_to_string(kind),
	}


static func from_save_dict(d: Dictionary) -> CausalSource:
	return CausalSource.new(
		StringName(d.get("exile_owner_id", String(NO_OWNER))),
		kind_from_string(String(d.get("kind", "independent"))))


static func kind_to_string(k: Kind) -> String:
	match k:
		Kind.BODY: return "body"
		Kind.SUMMON: return "summon"
		Kind.PROJECTILE: return "projectile"
		Kind.EFFECT: return "effect"
		Kind.THROWN: return "thrown"
		Kind.FORCED: return "forced"
		Kind.INDEPENDENT: return "independent"
	return "independent"


static func kind_from_string(name: String) -> Kind:
	match name:
		"body": return Kind.BODY
		"summon": return Kind.SUMMON
		"projectile": return Kind.PROJECTILE
		"effect": return Kind.EFFECT
		"thrown": return Kind.THROWN
		"forced": return Kind.FORCED
		"independent": return Kind.INDEPENDENT
	push_error("알 수 없는 CausalSource.Kind: %s" % name)
	return Kind.INDEPENDENT

