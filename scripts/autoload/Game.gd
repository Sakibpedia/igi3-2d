extends Node
## Global campaign state for IGI 3 2D: mission data, wallet, upgrades, medals and saves.

signal state_changed

const MISSION_COUNT := 15
const SAVE_PATH := "user://igi3_2d.cfg"

const TITLES_EN := [
	"Kajla Recon", "Document Run", "Park Stakeout", "R110 Sabotage", "Final Sweep",
	"Rooftop War", "Diplomatic Compound", "Motijheel Nightfall", "Hatirjheel Bridge",
	"Lalbagh Fort", "Karwan Bazar", "Airport Dawn", "Buriganga Night",
	"Parliament Zone", "Final Operation",
]
const TITLES_BN := [
	"কাজলা reconnaissance", "নথি উদ্ধার", "পার্কে নজরদারি", "R110 সাবোতাজ", "চূড়ান্ত অভিযান",
	"ছাদের যুদ্ধ", "কূটনৈতিক চৌহদ্দি", "মোতিজয়েল নিশাচল", "হাতিরঝিল সেতু", "লালবাগের দুর্গ",
	"করওয়ান বাজার", "বিমানবন্দরের ভোর", "বুড়িগঙ্গার রাত", "সংসদ এলাকা", "শেষ অভিযান",
]
const ZONES := ["north", "south", "park", "highway", "full", "rooftops", "full", "full",
	"full", "full", "full", "full", "full", "full", "full"]

var current_mission: int = 1
var unlocked: int = 1
var wallet: int = 600
var health_bonus: int = 0
var medkits: int = 2
var records: Dictionary = {}
var settings: Dictionary = {"sfx": true, "show_hints": true}
var last_result: Dictionary = {}


func _ready() -> void:
	load_game()


func mission_data(idx: int) -> Dictionary:
	var i: int = clampi(idx, 1, MISSION_COUNT) - 1
	var objs: Array = []
	var push := func(t: String, n: int = 1, extra: Dictionary = {}) -> void:
		var o := {"type": t, "count": n, "progress": 0}
		for k in extra.keys():
			o[k] = extra[k]
		objs.append(o)
	push.call("reach", 1, {"text": "কাজলা এলাকায় প্রবেশ করুন"})
	push.call("photo", 2 if i % 2 == 1 else 3, {"text": "লক্ষ্যগুলোর ছবি তুলুন"})
	push.call("collect", 1 + (i % 2), {"text": "গোপন নথি সংগ্রহ করুন"})
	push.call("wiretap", 1, {"text": "ফোনে ওয়্যারট্যাপ লাগান"})
	push.call("sabotage", 1 + (i % 3), {"text": "লক্ষ্যে চার্জ লাগান"})
	if i < 6:
		push.call("infiltrate", 1, {"text": "ভেতরের ঘরে প্রবেশ করুন"})
		push.call("survive", 1, {"text": "অবস্থান ধরে ২৫ সেকেন্ড টিকে থাকুন", "time": 25.0})
	else:
		push.call("eliminate", 1 + (i % 2), {"text": "চিহ্নিত কমান্ডারকে বাদ দিন"})
		push.call("disable_alarm", 1, {"text": "অ্যালার্ম সিস্টেম অক্ষম করুন"})
	push.call("bcs_gate", 1, {"text": "BCS প্রশ্নের উত্তর দিয়ে গেট খুলুন"})
	push.call("extract", 1, {"text": "এক্সট্রাকশন পয়েন্টে ফিরে আসুন"})
	return {
		"index": i + 1,
		"title": TITLES_BN[i],
		"title_en": TITLES_EN[i],
		"zone": ZONES[i],
		"reward": 350 + i * 70,
		"alarm_limit": 0.0 if i < 3 else (120.0 + i * 4.0),
		"parachute": i == 5 or i == 11,
		"objectives": objs,
	}


func start_mission(idx: int) -> void:
	current_mission = clampi(idx, 1, MISSION_COUNT)
	get_tree().change_scene_to_file("res://scenes/Mission.tscn")


func complete_mission(idx: int, score: int, seconds: float, alarms: int,
		obj_done: int, obj_total: int) -> void:
	var m := mission_data(idx)
	var medal := "Bronze"
	if alarms == 0 and obj_done == obj_total:
		medal = "Gold"
	elif alarms <= 2:
		medal = "Silver"
	records[idx] = {
		"score": score, "time": snappedf(seconds, 0.1), "medal": medal,
		"alarms": alarms, "objectives": "%d/%d" % [obj_done, obj_total],
	}
	if idx >= unlocked and idx < MISSION_COUNT:
		unlocked = idx + 1
	wallet += int(m.get("reward", 0)) + score / 10
	last_result = records[idx].duplicate()
	last_result["idx"] = idx
	save_game()
	state_changed.emit()


func fail_mission(_idx: int) -> void:
	last_result = {"failed": true}
	state_changed.emit()


func total_score() -> int:
	var total := 0
	for r in records.values():
		total += int((r as Dictionary).get("score", 0))
	return total


func rank() -> String:
	var s := total_score()
	if s >= 14000: return "Master Agent"
	if s >= 9000: return "Senior Agent"
	if s >= 5000: return "Field Agent"
	if s >= 2000: return "Operative"
	return "Recruit"


func medal_for(idx: int) -> String:
	if not records.has(idx): return ""
	return str((records[idx] as Dictionary).get("medal", ""))


func spend(cost: int) -> bool:
	if wallet < cost:
		return false
	wallet -= cost
	save_game()
	state_changed.emit()
	return true


func earn(amount: int) -> void:
	wallet += amount
	save_game()
	state_changed.emit()


func add_health_bonus(amount: int) -> void:
	health_bonus = mini(health_bonus + amount, 75)
	save_game()
	state_changed.emit()


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("campaign", "unlocked", unlocked)
	cf.set_value("campaign", "records", records)
	cf.set_value("economy", "wallet", wallet)
	cf.set_value("economy", "health_bonus", health_bonus)
	cf.set_value("economy", "medkits", medkits)
	cf.set_value("settings", "values", settings)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	unlocked = clampi(int(cf.get_value("campaign", "unlocked", 1)), 1, MISSION_COUNT)
	records = cf.get_value("campaign", "records", {})
	wallet = int(cf.get_value("economy", "wallet", 600))
	health_bonus = int(cf.get_value("economy", "health_bonus", 0))
	medkits = int(cf.get_value("economy", "medkits", 2))
	settings = cf.get_value("settings", "values", settings)
