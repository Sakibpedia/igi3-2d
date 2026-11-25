extends Node
## Renders real gameplay frames and saves them as PNGs for the README.
## Usage: SHOT_MODE=menu|mission|shop|gate|result godot --path . res://tools/test/ScreenshotTest.tscn
var mode := "menu"
var scene_node = null

func _ready() -> void:
	mode = OS.get_environment("SHOT_MODE")
	if mode == "":
		mode = "menu"
	call_deferred("_setup")
	await get_tree().create_timer(3.0).timeout
	_act()
	await get_tree().create_timer(1.0).timeout
	_capture()

func _setup() -> void:
	if mode == "menu":
		scene_node = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	else:
		Game.current_mission = 1
		scene_node = (load("res://scenes/Mission.tscn") as PackedScene).instantiate()
	add_child(scene_node)

func _act() -> void:
	if scene_node == null or mode == "menu":
		return
	var mission = scene_node
	var city = mission.city
	match mode:
		"shop":
			mission.hero.position = city.shops[0]["pos"]
			mission.interact()
		"gate":
			mission.hud.open_gate()
		"result":
			mission.finish(true, "অভিযান সফল — সব লক্ষ্য পূর্ণ")
		_:
			pass

func _capture() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path := "res://docs/images/gameplay-%s.png" % mode
	img.save_png(path)
	print("[SHOT] saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	get_tree().quit()
