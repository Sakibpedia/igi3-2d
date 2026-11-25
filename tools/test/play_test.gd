extends Node
## Deeper playthrough-style verification: uses the real interaction/shoot hooks
## instead of only incrementing objective counters.
var mission
var t := 0.0
var idx := 1
var reported := false
var fails := 0
var wallet_before := 0

func _ready() -> void:
	var env := OS.get_environment("MISSION")
	idx = int(env) if env != "" else 1
	Game.current_mission = idx
	wallet_before = Game.wallet
	mission = (load("res://scenes/Mission.tscn") as PackedScene).instantiate()
	add_child(mission)

func _ck(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("[PLAY2D] FAIL M%d %s" % [idx, what])

func _process(delta: float) -> void:
	t += delta
	if t > 120.0:
		print("[PLAY2D] FAIL M%d timeout" % idx)
		get_tree().quit(1)
	if reported or t < 2.0 or not bool(mission.get("running")):
		return
	reported = true
	_play()
	Game.wallet = wallet_before
	Game.save_game()
	if fails == 0:
		print("[PLAY2D] PASS M%d - %d objectives, %d actors, %d vehicles" % [
			idx, mission.objectives.size(), mission.actors.size(), mission.city.vehicles.size()])
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _first(kind: String):
	for a in mission.actors:
		if a != null and a.alive and str(a.kind) == kind:
			return a
	return null

func _play() -> void:
	var city = mission.city
	_ck(city.buildings.size() >= 1400, "city built")
	_ck(city.vehicles.size() == 9, "vehicles present")
	_ck(not city.is_blocked(mission.hero.position, 8.0), "hero spawn is walkable")
	_ck(mission.objectives.size() >= 7, "objective chain length")

	# Shooting reports aggression so neutral forces can retaliate.
	var guard = _first("enemy")
	if guard != null:
		for off in [Vector2(80, 0), Vector2(-80, 0), Vector2(0, 80), Vector2(0, -80)]:
			var p: Vector2 = mission.hero.position + off
			if not city.is_blocked(p, 6.0):
				guard.position = p
				break
		mission.shoot(mission.hero, guard.position)
		_ck(mission.hero_attacked_flag, "hero aggression registered")
	else:
		_ck(false, "guard spawned")

	# Killing air force calls the airstrike.
	var airman = _first("airforce")
	if airman != null:
		mission.on_actor_died(airman, mission.hero)
		_ck(mission._airstrikes.size() > 0, "airstrike called")
	else:
		_ck(false, "airman spawned")

	# Shop trade spends money and heals.
	Game.wallet = 500
	mission.hero.hp = 40
	mission.hud.buy("bandage", 30)
	_ck(Game.wallet == 470, "shop purchase charged")
	_ck(mission.hero.hp > 40, "bandage healed hero")

	# Walk the entire objective chain through real gameplay hooks.
	for oi in mission.objectives.size():
		var o: Dictionary = mission.objectives[oi]
		var typ := str(o.get("type", ""))
		var count := int(o.get("count", 1))
		var before := int(mission.obj_index)
		for k in count:
			mission.hero.position = mission.objective_target()
			match typ:
				"bcs_gate":
					mission.on_objective_action("gate_play")
				"infiltrate":
					mission.interior = city.nearest_building(mission.hero.position)
					mission.update_objective(0.1)
				"reach", "extract":
					mission.update_objective(0.1)
				"survive":
					mission.update_objective(float(o.get("time", 25.0)) + 1.0)
				"eliminate":
					var cmd = null
					for a in mission.actors:
						if a != null and a.alive and str(a.kind) == "commander":
							cmd = a
							break
					if cmd != null:
						cmd.take_damage(999, mission.hero)
					else:
						mission.on_objective_action("kill_play")
				_:
					mission.interact()
			if int(mission.obj_index) > before:
				break
		_ck(int(mission.obj_index) > before, "objective %d (%s) completed" % [oi + 1, typ])
		if bool(mission.ended):
			break
	_ck(bool(mission.ended), "mission reached extraction")
