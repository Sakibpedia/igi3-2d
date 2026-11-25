extends Node2D
## Top-down mission runtime. Builds the OSM city, spawns actors, drives the
## objective chain, AI, economy, BCS gates and extraction.

var data: Dictionary = {}
var city = null
var hud = null
var hero = null
var actors: Array = []
var objectives: Array = []
var obj_index: int = 0
var progress: Dictionary = {}
var running: bool = false
var ended: bool = false
var alarms: int = 0
var alarm_time: float = 0.0
var score: int = 0
var elapsed: float = 0.0
var tracers: Array = []
var interior: int = -1
var survive_time: float = 0.0
var driving: bool = false
var thermal: bool = false
var scope: bool = false
var game_over: bool = false
var _think: float = 0.0
var _hint: float = 0.0
var _airstrikes: Array = []
var _last_target: Vector2 = Vector2.ZERO
var marker_layer = null
var hero_attacked_flag: bool = false


func _ready() -> void:
	data = Game.mission_data(Game.current_mission)
	objectives = (data.get("objectives", []) as Array).duplicate(true)
	city = load("res://scripts/world/City2D.gd").new()
	add_child(city)
	marker_layer = MarkerLayer.new()
	marker_layer.mission = self
	add_child(marker_layer)

	hero = _spawn("hero", "hero", Vector2.ZERO)
	hero.position = city.extraction if city != null else Vector2.ZERO
	_populate()
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	hero.add_child(cam)
	cam.make_current()
	hud = load("res://scripts/ui/HUD.gd").new()
	hud.mission = self
	add_child(hud)
	running = true
	hud.notify("অপারেশন শুরু — %s" % str(data.get("title", "")))
	Sfx.play("ui")


func _spawn(kind: String, team: String, pos: Vector2) -> Node:
	var a = load("res://scripts/world/Actor2D.gd").new()
	add_child(a)
	a.setup(kind, pos, team, self)
	actors.append(a)
	return a


func _populate() -> void:
	var m: int = int(data.get("index", 1))
	var enemies: int = 8 + m
	for i in enemies:
		var k := "commander" if i < 1 + (m % 2) else "enemy"
		var a = _spawn(k, "enemy", city.random_road_point(1000 + i * 17 + m))
		if k == "commander":
			a.tag = "commander"
	for i in 40:
		_spawn("military", "neutral", city.random_road_point(2000 + i * 31))
	for i in 40:
		_spawn("police", "neutral", city.random_road_point(3000 + i * 29))
	for i in 40:
		_spawn("airforce", "neutral", city.random_road_point(4000 + i * 23))
	for i in 40:
		_spawn("naval", "neutral", city.random_road_point(5000 + i * 19))
	for i in 4:
		_spawn("commando", "neutral", city.random_road_point(6000 + i * 13))
	_spawn("protector", "neutral", city.random_road_point(7000))
	for i in 18:
		_spawn("gang", "gang", city.random_road_point(8000 + i * 37))
	for i in 200:
		_spawn("civilian", "civilian", city.random_road_point(9000 + i * 41))


func current_objective() -> Dictionary:
	if obj_index < 0 or obj_index >= objectives.size():
		return {}
	return objectives[obj_index] as Dictionary


func objective_target() -> Vector2:
	var o := current_objective()
	var t := str(o.get("type", ""))
	match t:
		"extract": return city.extraction
		"bcs_gate": return city.gates[obj_index % city.gates.size()]
		"collect", "wiretap", "photo", "sabotage", "disable_alarm":
			return city.shops[(obj_index * 3) % city.shops.size()]["pos"]
		"reach", "infiltrate", "survive":
			var idx: int = city.nearest_building(city.random_road_point(100 + obj_index))
			return (city.buildings[idx] as Dictionary)["door"]
	return _last_target


func _process(delta: float) -> void:
	if not running or ended:
		return
	elapsed += delta
	alarm_time += delta
	_hint += delta
	_handle_input(delta)
	if game_over:
		return
	_think += delta
	if _think > 0.35:
		_think = 0.0
		_update_ai()
	_update_objectives(delta)
	_update_effects(delta)
	var limit := float(data.get("alarm_limit", 0.0))
	if limit > 0.0 and alarms > 0 and alarm_time > limit:
		finish(false, "সময় শেষ — বের হতে পারেননি")
	if hud != null:
		hud.refresh()


func _handle_input(delta: float) -> void:
	if hud != null and hud.blocking():
		hud.handle_block_input()
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0
	hero.speed = 250.0 if driving else (145.0 if Input.is_key_pressed(KEY_SHIFT) else (70.0 if Input.is_key_pressed(KEY_CTRL) else 105.0))
	hero.move(dir, delta, city)
	hero.face_towards(get_global_mouse_position())
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not driving:
		shoot(hero, get_global_mouse_position())
	if Input.is_key_pressed(KEY_ESCAPE):
		running = false
		finish(false, "অভিযান বাতিল")
	if Input.is_key_pressed(KEY_E) and _hint > 0.25:
		_hint = 0.0
		interact()
	if Input.is_key_pressed(KEY_8):
		scope = not scope
	if Input.is_key_pressed(KEY_T):
		thermal = not thermal
	if Input.is_key_pressed(KEY_M) and hud != null:
		hud.toggle_map()


func shoot(shooter: Node, aim: Vector2) -> void:
	if shooter == null or not shooter.alive:
		return
	var from: Vector2 = shooter.position
	var dir := (aim - from)
	var max_range := 620.0 if scope else 420.0
	if dir.length() > max_range:
		dir = dir.normalized() * max_range
	var to := from + dir
	var hit: Node = null
	var hit_at := to
	for a in actors:
		if not a.alive or a == shooter:
			continue
		var d: float = _point_segment_distance(a.position, from, to)
		if d < 11.0 and (hit == null or from.distance_squared_to(a.position) < from.distance_squared_to(hit.position)):
			if not _segment_blocked(from, a.position):
				hit = a
				hit_at = a.position
	tracers.append({"from": from, "to": hit_at, "life": 0.12})
	Sfx.play("shot", 0.9 + randf() * 0.2)
	if hit != null:
		var dmg := 34 if shooter == hero else 18
		if scope: dmg = 90
		if shooter.team == "neutral": dmg = 20
		hit.take_damage(dmg, shooter)


func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.001: return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _segment_blocked(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 24.0)
	for i in range(1, maxi(steps, 1)):
		var p := a.lerp(b, float(i) / maxi(steps, 1))
		if city.is_blocked(p, 2.0):
			return true
	return false


func interact() -> void:
	if interior >= 0:
		interior = -1
		hud.notify("ছাদের দিক থেকে নেমে এলেন")
		return
	var best_shop := -1
	var best_d := 52.0
	for i in city.shops.size():
		var d: float = (city.shops[i]["pos"] as Vector2).distance_to(hero.position)
		if d < best_d:
			best_d = d
			best_shop = i
	if best_shop >= 0:
		hud.open_shop(best_shop)
		return
	var target := objective_target()
	if hero.position.distance_to(target) < 58.0:
		var t := str(current_objective().get("type", ""))
		if t == "bcs_gate":
			hud.open_gate()
		else:
			on_objective_action("objective_%d" % obj_index)
		return
	var bi: int = city.nearest_building(hero.position)
	var door: Vector2 = (city.buildings[bi] as Dictionary)["door"]
	if hero.position.distance_to(door) < 28.0:
		interior = bi
		hero.position = (city.buildings[bi] as Dictionary)["center"]
		hud.notify("ভেতরে প্রবেশ করেছেন — [E] বের হন")
		return
	# vehicle pickup
	var vp := _nearest_vehicle()
	if vp != Vector2.ZERO and hero.position.distance_to(vp) < 40.0:
		driving = not driving
		hud.notify("যানবাহন চালানো শুরু" if driving else "যানবাহন থেকে নামলেন")


func _nearest_vehicle() -> Vector2:
	if city.road_points.is_empty(): return Vector2.ZERO
	var best: Vector2 = city.road_points[0]
	for p in city.road_points:
		if p.distance_to(hero.position) < best.distance_to(hero.position):
			best = p
	return best


func on_objective_action(_id: String) -> void:
	var o := current_objective()
	if o.is_empty():
		return
	var key := str(obj_index)
	progress[key] = int(progress.get(key, 0)) + 1
	if int(progress[key]) >= int(o.get("count", 1)):
		advance()


func advance() -> void:
	score += 150
	obj_index += 1
	Sfx.play("pickup")
	if obj_index >= objectives.size():
		finish(true, "অভিযান সফল")
	else:
		hud.notify("লক্ষ্য পূর্ণ — %s" % str(current_objective().get("text", "")))


func _update_objectives(_delta: float) -> void:
	var o := current_objective()
	if o.is_empty():
		return
	var t := str(o.get("type", ""))
	var target := objective_target()
	_last_target = target
	if t in ["reach", "extract"] and hero.position.distance_to(target) < 36.0:
		on_objective_action("auto_%d" % obj_index)
	elif t == "infiltrate" and interior >= 0:
		on_objective_action("auto_%d" % obj_index)
	elif t == "survive":
		if hero.position.distance_to(target) < 70.0:
			survive_time += _delta
			if survive_time >= float(o.get("time", 25.0)):
				survive_time = 0.0
				on_objective_action("auto_%d" % obj_index)
	else:
		survive_time = 0.0


func update_objective(dt: float) -> void:
	_update_objectives(dt)


func on_actor_died(victim: Node, killer: Node) -> void:
	if victim == null or ended:
		return
	if victim.team == "civilian":
		score = maxi(0, score - 200)
		raise_alarm()
		if hud != null:
			hud.notify("বেসামরিক নাগরিক ক্ষতিগ্রস্ত — ২০০ পয়েন্ট কাটা গেল")
	if victim.team == "enemy":
		score += 500 if victim.tag == "commander" else 80
		Game.earn(60 if victim.tag == "commander" else 15)
		var o := current_objective()
		if str(o.get("type", "")) == "eliminate" and victim.tag == str(o.get("tag", "commander")):
			on_objective_action("kill_%d" % obj_index)
	if victim.kind == "airforce" and killer != null and killer != hero:
		_call_airstrike(killer.position)
	elif victim.kind == "airforce" and killer == hero:
		_call_airstrike(hero.position)
	if victim.team == "gang" or victim.team == "civilian":
		for a in actors:
			if a != null and a.alive and a.team == "neutral" and a.position.distance_to(victim.position) < 300.0:
				a.alerted = true
	if victim == hero:
		finish(false, "অপারেটিভ নিহত")


func _call_airstrike(pos: Vector2) -> void:
	_airstrikes.append({"pos": pos, "t": 2.0, "done": false})
	if hud != null:
		hud.notify("বিমান বাহিনী হামলা আহ্বান করেছে — ছায়ায় যান!")
	raise_alarm()


func raise_alarm() -> void:
	alarms += 1
	alarm_time = 0.0
	Sfx.play("alarm")
	for a in actors:
		if a != null and a.alive and a.team not in ["civilian", "gang"]:
			if a.position.distance_to(hero.position) < 420.0:
				a.alerted = true


func _update_ai() -> void:
	var hero_pos: Vector2 = hero.position
	for a in actors:
		if a == null or not a.alive or a == hero:
			continue
		a.fire_cd = maxf(0.0, a.fire_cd - 0.35)
		var d: float = a.position.distance_to(hero_pos)
		if a.team == "civilian":
			if a.wander_target == Vector2.ZERO or a.position.distance_to(a.wander_target) < 20.0:
				a.wander_target = city.random_road_point(a.get_instance_id())
			a.move((a.wander_target - a.position).normalized(), 0.35, city)
		elif a.team == "gang":
			var prey: Node = hero if d < 320.0 else _nearest_civilian(a.position, 260.0)
			if prey != null:
				a.move((prey.position - a.position).normalized(), 0.35, city)
				if a.position.distance_to(prey.position) < 22.0 and a.fire_cd <= 0.0:
					a.fire_cd = 1.0
					prey.take_damage(12, a)
		elif a.team == "enemy":
			if a.alerted or d < 360.0:
				a.move((hero_pos - a.position).normalized(), 0.35, city)
				if d < 300.0 and a.fire_cd <= 0.0:
					a.fire_cd = 0.8
					shoot(a, hero_pos)
		elif a.team == "neutral" and a.alerted:
			var target: Node = _nearest_attacker(a.position)
			if target != null:
				var td: float = a.position.distance_to(target.position)
				if td < 400.0:
					a.move((target.position - a.position).normalized(), 0.35, city)
					if td < 280.0 and a.fire_cd <= 0.0:
						a.fire_cd = 0.7
						shoot(a, target.position)


func _nearest_civilian(pos: Vector2, radius: float) -> Node:
	var best: Node = null
	var bd := radius
	for a in actors:
		if a != null and a.alive and a.team == "civilian":
			var d: float = a.position.distance_to(pos)
			if d < bd:
				bd = d
				best = a
	return best


func _nearest_attacker(pos: Vector2) -> Node:
	var best: Node = null
	var bd := 1.0e9
	for a in actors:
		if a == null or not a.alive:
			continue
		if a.team in ["enemy", "gang", "hero"] and a.alerted or a == hero and hero_attacked():
			var d: float = a.position.distance_to(pos)
			if d < bd:
				bd = d
				best = a
	return best if bd < 520.0 else null


func hero_attacked() -> bool: return hero_attacked_flag


func _update_effects(delta: float) -> void:
	for t in tracers:
		t["life"] -= delta
	tracers = tracers.filter(func(t): return float(t["life"]) > 0.0)
	for s in _airstrikes:
		s["t"] -= delta
		if s["t"] <= 0.0 and not bool(s["done"]):
			s["done"] = true
			if interior < 0 and hero.position.distance_to(s["pos"]) < 70.0:
				hero.take_damage(40, null)
			Sfx.play("bomb")
	_airstrikes = _airstrikes.filter(func(s): return not bool(s["done"]) or float(s["t"]) > -0.5)
	marker_layer.queue_redraw()


func finish(success: bool, reason: String) -> void:
	if ended:
		return
	ended = true
	running = false
	game_over = true
	if success:
		Game.complete_mission(Game.current_mission, score, elapsed, alarms, obj_index + 1, objectives.size())
		Sfx.play("medal")
	else:
		Game.fail_mission(Game.current_mission)
	if hud != null:
		hud.show_result(success, reason, score, elapsed, alarms)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and hud != null and not hud.blocking():
		if event.keycode == KEY_R:
			hud.buy("medkit", 60)
		if event.keycode == KEY_F:
			hud.buy("bandage", 30)


class MarkerLayer extends Node2D:
	var mission: Node

	func _draw() -> void:
		if mission == null or not mission.running:
			return
		var target: Vector2 = mission.call("objective_target")
		draw_circle(target, 26.0, Color(0.95, 0.72, 0.30, 0.20))
		draw_circle(target, 26.0, Color(0.95, 0.72, 0.30), false, 3.0)
		draw_line(target + Vector2(-34, 0), target + Vector2(-18, 0), Color(0.95, 0.72, 0.30), 2.0)
		draw_line(target + Vector2(18, 0), target + Vector2(34, 0), Color(0.95, 0.72, 0.30), 2.0)
		if mission.thermal:
			for a in mission.actors:
				if a != null and a.alive and a.team != "civilian":
					draw_circle(a.position, 14.0, Color(1.0, 0.35, 0.25, 0.35))
		for tr in mission.tracers:
			draw_line(tr["from"], tr["to"], Color(1.0, 0.85, 0.35, float(tr["life"]) / 0.12 * 0.8), 2.0)
		for s in mission._airstrikes:
			if not bool(s["done"]):
				draw_circle(s["pos"], 70.0, Color(1.0, 0.2, 0.15, 0.25))
				draw_circle(s["pos"], 70.0, Color(1.0, 0.3, 0.2), false, 2.0)
		for p in mission.city.road_points:
			if (p - mission.hero.position).length() < 40.0:
				draw_circle(p, 12.0, Color(0.35, 0.75, 0.85, 0.7))
