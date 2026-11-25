extends Node
## Verifies all 15 mission definitions, economy, save/reload and unlocks.
func _ready() -> void:
	var fails := 0
	for i in range(1, 16):
		var d: Dictionary = Game.mission_data(i)
		if int(d.get("index", 0)) != i: fails += 1
		if (d.get("objectives", []) as Array).size() < 7: fails += 1
		if str(d.get("title_en", "")) == "": fails += 1
	var before := Game.wallet
	if not Game.spend(50): fails += 1
	if Game.wallet != before - 50: fails += 1
	Game.earn(20)
	var u := Game.unlocked
	Game.complete_mission(1, 1000, 90.0, 0, 10, 10)
	Game.save_game()
	var wallet_before := Game.wallet
	Game.wallet = 0
	Game.load_game()
	if Game.wallet != wallet_before: fails += 1
	if Game.unlocked < maxi(u, 2): fails += 1
	if Game.medal_for(1) != "Gold": fails += 1
	if Game.rank() == "": fails += 1
	if fails > 0:
		print("[SAVE2D] FAIL %d checks" % fails)
		get_tree().quit(1)
	print("[SAVE2D] PASS - 15 missions, wallet, medal, unlock, save/reload, rank")
	get_tree().quit(0)
