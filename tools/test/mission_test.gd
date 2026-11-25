extends Node
## Headless smoke + objective-chain test for any mission (MISSION=1..15).
var mission: Node
var t := 0.0
var idx := 1
var reported := false
var fails := 0

func _ready() -> void:
	var env := OS.get_environment("MISSION")
	idx = int(env) if env != "" else 1
	Game.current_mission = idx
	mission = (load("res://scenes/Mission.tscn") as PackedScene).instantiate()
	add_child(mission)

func _ck(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("[IGI2D] FAIL M%d %s" % [idx, what])

func _process(delta: float) -> void:
	t += delta
	if t > 120.0:
		print("[IGI2D] FAIL M%d timeout" % idx)
		get_tree().quit(1)
	if reported or t < 2.0 or not bool(mission.get("running")):
		return
	reported = true
	var objs: Array = mission.objectives
	_ck(objs.size() >= 7 and objs.size() <= 10, "objective count %d" % objs.size())
	_ck(mission.actors.size() >= 390, "actors spawned (%d)" % mission.actors.size())
	_ck(mission.city.buildings.size() >= 1400, "city built")
	_ck(mission.hero != null, "hero present")
	for oi in objs.size():
		var o: Dictionary = objs[oi]
		var n := int(o.get("count", 1))
		for k in n:
			mission.call("on_objective_action", "test_%d_%d" % [oi, k])
	if fails == 0:
		print("[IGI2D] PASS M%d - %d objectives, %d actors, %d buildings" % [
			idx, objs.size(), mission.actors.size(), mission.city.buildings.size()])
		get_tree().quit(0)
	else:
		get_tree().quit(1)
