extends Control
## Mission-select menu for the 15-mission top-down campaign.

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/menu_bg.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.06, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var title := Label.new()
	title.text = "IGI 3  —  SONTEK KAJLA"
	title.position = Vector2(70, 44)
	title.size = Vector2(800, 70)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.97, 0.85, 0.55))
	add_child(title)
	var sub := Label.new()
	sub.text = "সনটেক কাজলা • ১৫টি গোপন অভিযান • টপ-ডাউন স্টেলথ"
	sub.position = Vector2(72, 112)
	sub.size = Vector2(900, 40)
	sub.add_theme_font_size_override("font_size", 23)
	sub.add_theme_color_override("font_color", Color(0.55, 0.88, 0.82))
	add_child(sub)

	var info := Label.new()
	info.text = "ওয়ালেট ৳ %d   |   পদমর্যাদা: %s   |   অতিরিক্ত HP +%d   |   মেডকিট %d" % [
		Game.wallet, Game.rank(), Game.health_bonus, Game.medkits]
	info.position = Vector2(72, 158)
	info.size = Vector2(1000, 34)
	info.add_theme_font_size_override("font_size", 19)
	info.add_theme_color_override("font_color", Color(0.92, 0.93, 0.88))
	add_child(info)

	for i in Game.MISSION_COUNT:
		var idx := i + 1
		var b := Button.new()
		b.position = Vector2(72 + (i % 5) * 226, 230 + (i / 5) * 116)
		b.size = Vector2(210, 94)
		var locked: bool = idx > Game.unlocked
		var medal := Game.medal_for(idx)
		var mark: String = "[LOCKED]" if locked else ("[GOLD]" if medal == "Gold" else ("[" + medal.to_upper() + "]" if medal != "" else "[NEW]"))
		b.text = "%02d  %s\n%s  %s" % [idx, Game.TITLES_EN[i], Game.TITLES_BN[i], mark]
		b.disabled = locked
		b.add_theme_font_size_override("font_size", 17)
		if not locked:
			b.pressed.connect(_start.bind(idx))
		add_child(b)

	var help := Label.new()
	help.text = "WASD চলুন • Shift দৌড় • Ctrl নিচু • LMB গুলি • E ইন্টারঅ্যাক্ট • 8 স্কোপ • T থার্মাল • BCS গেটে 1-4"
	help.position = Vector2(72, 640)
	help.size = Vector2(1100, 40)
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_color", Color(0.80, 0.86, 0.84))
	add_child(help)

	var credit := Label.new()
	credit.text = "Made by S M Nazmuz Sakib   •   Map data © OpenStreetMap contributors (ODbL 1.0)"
	credit.position = Vector2(72, 682)
	credit.size = Vector2(1140, 26)
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(0.62, 0.70, 0.68))
	add_child(credit)


func _start(idx: int) -> void:
	Sfx.play("ui")
	Game.start_mission(idx)
