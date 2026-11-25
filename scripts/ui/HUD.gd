extends CanvasLayer
## Bengali HUD: objectives, economy, minimap, trade panel, BCS gate and results.

const BCS = preload("res://scripts/world/BCSQuestions.gd")

var mission = null
var state: String = ""
var notice: String = ""
var notice_time: float = 0.0
var shop_index: int = 0
var gate_q: Array = []
var map_big: bool = false
var root: Control
var lbl_title: Label
var lbl_obj: Label
var lbl_status: Label
var lbl_health: Label
var lbl_notice: Label
var lbl_panel: Label
var panel: Panel
var mini = null


func _ready() -> void:
	root = Control.new()
	add_child(root)
	lbl_title = _label("title", Vector2(24, 18), Vector2(620, 36), 25, Color(0.93, 0.78, 0.42))
	lbl_obj = _label("objective", Vector2(24, 58), Vector2(620, 58), 19, Color(0.92, 0.94, 0.90))
	lbl_status = _label("status", Vector2(24, 650), Vector2(700, 40), 18, Color(0.55, 0.86, 0.79))
	lbl_health = _label("health", Vector2(24, 610), Vector2(700, 34), 18, Color(0.96, 0.72, 0.55))
	lbl_notice = _label("notice", Vector2(330, 500), Vector2(620, 46), 22, Color(0.98, 0.83, 0.45))
	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340
	panel.offset_top = -230
	panel.offset_right = 340
	panel.offset_bottom = 230
	panel.visible = false
	root.add_child(panel)
	lbl_panel = Label.new()
	lbl_panel.position = Vector2(24, 20)
	lbl_panel.size = Vector2(632, 420)
	lbl_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(lbl_panel)
	mini = MiniMap.new()
	mini.hud = self
	add_child(mini)


func _label(n: String, pos: Vector2, size: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.name = n
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	root.add_child(l)
	return l


func refresh() -> void:
	if mission == null:
		return
	var d: Dictionary = mission.data
	var o: Dictionary = mission.current_objective()
	var done: int = int(mission.progress.get(str(mission.obj_index), 0))
	var count: int = int(o.get("count", 1))
	lbl_title.text = "%d/15  %s  —  %s" % [int(d.get("index", 1)), str(d.get("title", "")), str(d.get("title_en", ""))]
	lbl_obj.text = "লক্ষ্য %d/%d: %s  (%d/%d)" % [
		mission.obj_index + 1, mission.objectives.size(), str(o.get("text", "")), done, count]
	lbl_health.text = "স্বাস্থ্য %d/%d   •   ওষুধ %d   •   অস্ত্র %s   •   স্কোর %d" % [
		mission.hero.hp, mission.hero.max_hp, Game.medkits,
		"স্নাইপার" if mission.scope else "BD-08", mission.score]
	var alarm_s: String = "নীরব" if mission.alarms == 0 else ("অ্যালার্ম ×%d" % mission.alarms)
	lbl_status.text = "৳ %d   •   %s   •   %s   •   %s   •   পদমর্যাদা: %s" % [
		Game.wallet, alarm_s, _time(mission.elapsed), "থার্মাল" if mission.thermal else "সাধারণ", Game.rank()]
	lbl_notice.text = notice if notice_time > 0.0 else ""
	mini.queue_redraw()


func tick(delta: float) -> void:
	notice_time = maxf(0.0, notice_time - delta)


func close_panel() -> void:
	if state in ["shop", "gate"]:
		state = ""
		panel.visible = false


func _time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [int(s / 60), s % 60]


func notify(text: String) -> void:
	notice = text
	notice_time = 4.5


func blocking() -> bool:
	return state != ""


func handle_block_input() -> void:
	pass


func open_shop(idx: int) -> void:
	shop_index = idx
	state = "shop"
	_refresh_panel()


func open_gate() -> void:
	var questions: Array = BCS.QUESTIONS
	gate_q = questions[randi() % questions.size()]
	state = "gate"
	_refresh_panel()


func _refresh_panel() -> void:
	panel.visible = state != ""
	if state == "shop":
		var s: Dictionary = mission.city.shops[shop_index]
		lbl_panel.text = "দোকান: %s (%s)\n\nওয়ালেট: ৳ %d\n\n" % [
			str(s["name"]), str(s["kind"]), Game.wallet]
		lbl_panel.text += "1  গুলি — ৳ 20\n2  মেডকিট — ৳ 60\n3  ব্যান্ডেজ — ৳ 30\n"
		lbl_panel.text += "4  স্থায়ী +25 HP — ৳ 250\n5  লুট বেচুন — ৳ 40\n\n[E/ESC] বন্ধ করুন"
	elif state == "gate":
		var opts: Array = gate_q[1]
		lbl_panel.text = "BCS গেট — বাংলা প্রশ্ন\n\n%s\n\n" % str(gate_q[0])
		for i in opts.size():
			lbl_panel.text += "%d  %s\n" % [i + 1, str(opts[i])]
		lbl_panel.text += "\n[1-4] উত্তর   [ESC] বন্ধ"
	elif state == "result":
		lbl_panel.text = lbl_panel.text


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var k: int = event.keycode
	if state == "shop":
		if k == KEY_1: buy("ammo", 20)
		elif k == KEY_2: buy("medkit", 60)
		elif k == KEY_3: buy("bandage", 30)
		elif k == KEY_4: buy("health", 250)
		elif k == KEY_5:
			Game.earn(40)
			notify("লুট বেচে ৳ 40 পেলেন")
		if k in [KEY_E, KEY_ESCAPE]:
			state = ""
			_refresh_panel()
	elif state == "gate":
		if k >= KEY_1 and k <= KEY_4:
			var ans := k - KEY_1
			if ans == int(gate_q[2]):
				state = ""
				_refresh_panel()
				mission.on_objective_action("gate_%d" % mission.obj_index)
				notify("সঠিক উত্তর — গেট খুলে গেল")
			else:
				var questions: Array = BCS.QUESTIONS
				gate_q = questions[randi() % questions.size()]
				_refresh_panel()
				notify("ভুল উত্তর — অন্য প্রশ্ন")
		elif k == KEY_ESCAPE:
			state = ""
			_refresh_panel()
	elif state == "result":
		if k == KEY_R:
			Game.start_mission(Game.current_mission)
		elif k == KEY_M or k == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func buy(kind: String, cost: int) -> bool:
	if not Game.spend(cost):
		notify("পর্যাপ্ত টাকা নেই")
		return false
	if kind == "health":
		Game.add_health_bonus(25)
		mission.hero.max_hp += 25
		mission.hero.hp += 25
		notify("স্বাস্থ্য সীমা +25 বৃদ্ধি পেল")
	elif kind == "medkit":
		Game.medkits += 1
		mission.hero.hp = mini(mission.hero.max_hp, mission.hero.hp + 45)
		notify("মেডকিট ব্যবহার করা হলো")
	elif kind == "bandage":
		mission.hero.hp = mini(mission.hero.max_hp, mission.hero.hp + 20)
		notify("ব্যান্ডেজ লাগানো হলো")
	elif kind == "ammo":
		notify("গুলি কেনা হলো")
	Sfx.play("pickup")
	if state == "shop":
		_refresh_panel()
	return true


func toggle_map() -> void:
	map_big = not map_big
	mini.scale = Vector2(1.35, 1.35) if map_big else Vector2.ONE


func show_result(success: bool, reason: String, score: int, seconds: float, alarms: int) -> void:
	state = "result"
	panel.visible = true
	lbl_panel.text = ("অভিযান সফল" if success else "অভিযান ব্যর্থ") + "\n\n"
	lbl_panel.text += reason + "\n\n"
	lbl_panel.text += "স্কোর: %d\nসময়: %s\nঅ্যালার্ম: %d\nমেডাল: %s\nমোট পদমর্যাদা: %s\n\n" % [
		score, _time(seconds), alarms,
		Game.medal_for(Game.current_mission), Game.rank()]
	lbl_panel.text += "[R] আবার চেষ্টা    [M] মেনুতে ফিরুন"


class MiniMap extends Node2D:
	var hud

	func _draw() -> void:
		if hud == null or hud.mission == null:
			return
		var m = hud.mission
		var c = m.city
		var center: Vector2 = m.hero.position
		var sc := 0.055
		var size := 210.0
		draw_rect(Rect2(1040, 18, size, size), Color(0.04, 0.09, 0.09, 0.85))
		draw_rect(Rect2(1040, 18, size, size), Color(0.83, 0.68, 0.38), false, 2.0)
		for rd in c.roads:
			var pts := PackedVector2Array()
			for p in rd["pts"]:
				pts.append(Vector2(1040, 18) + (p - center) * sc + Vector2(size / 2.0, size / 2.0))
			draw_polyline(pts, Color(0.35, 0.38, 0.37, 0.8), maxf(1.0, float(rd["w"]) * sc))
		for b in c.buildings:
			var r: Rect2 = b["rect"]
			var rp := Rect2(Vector2(1040, 18) + (r.position - center) * sc + Vector2(size / 2.0, size / 2.0), r.size * sc)
			if rp.intersects(Rect2(1040, 18, size, size)):
				draw_rect(rp, Color(0.48, 0.43, 0.36, 0.9))
		var t: Vector2 = m.call("objective_target")
		draw_circle(Vector2(1040, 18) + (t - center) * sc + Vector2(size / 2.0, size / 2.0), 5.0, Color(0.95, 0.72, 0.3))
		draw_circle(Vector2(1040 + size / 2.0, 18 + size / 2.0), 4.0, Color(0.3, 0.9, 0.8))
