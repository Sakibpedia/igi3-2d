extends Node2D
## Real-OSM Sontek Kajla, drawn top-down. Buildings are polygons with doors;
## roads and shops are laid out from the same data as the 3D game.

const SCALE := 3.2
const AREA := 520.0
const MAX_BUILDINGS := 1500
const CELL := 220.0

var buildings: Array = []      # {center, pts, rect, floors, door, kind}
var roads: Array = []          # PackedVector2Array in world pixels
var shops: Array = []          # {pos, kind, name, color}
var gates: Array = []          # Vector2 positions
var vehicles: Array = []       # {pos, kind, color}
var road_points: Array = []    # Vector2 spawn/interaction points
var extraction: Vector2 = Vector2.ZERO
var _grid: Dictionary = {}     # cell key -> Array[int]

var _colors := [
	Color(0.42, 0.36, 0.31), Color(0.50, 0.42, 0.34), Color(0.36, 0.39, 0.40),
	Color(0.55, 0.47, 0.36), Color(0.33, 0.35, 0.34), Color(0.47, 0.40, 0.38),
]


func _ready() -> void:
	_build()
	queue_redraw()


func _build() -> void:
	var f := FileAccess.open("res://assets/maps/kajla.json", FileAccess.READ)
	if f == null:
		push_error("kajla.json missing")
		return
	var raw: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("bad map data")
		return

	var candidates: Array = []
	for b in (raw.get("buildings", []) as Array):
		var bd: Dictionary = b
		var pts_in: Array = bd.get("pts", [])
		if pts_in.size() < 4:
			continue
		var c := Vector2.ZERO
		var poly := PackedVector2Array()
		for p in pts_in:
			var pa: Array = p
			var v := Vector2(float(pa[0]), float(pa[1]))
			c += v
			poly.append(v * SCALE)
		c /= float(pts_in.size())
		if c.length() > AREA:
			continue
		var rect := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			rect = rect.expand(v)
		candidates.append({
			"center": c * SCALE, "pts": poly, "rect": rect,
			"floors": clampi(int(float(bd.get("h", 6.0)) / 3.0) + 1, 2, 20),
			"kind": str(bd.get("kind", "yes")),
		})
	candidates.sort_custom(func(a, b): return (a as Dictionary)["center"].length_squared() < (b as Dictionary)["center"].length_squared())
	for i in mini(candidates.size(), MAX_BUILDINGS):
		var b: Dictionary = (candidates[i] as Dictionary).duplicate(true)
		var r: Rect2 = b["rect"]
		b["door"] = Vector2(r.position.x + r.size.x * 0.5, r.end.y + 4.0)
		buildings.append(b)
		_add_to_grid(buildings.size() - 1, r)

	var road_idx := 0
	for rd in (raw.get("roads", []) as Array):
		var pts: Array = (rd as Dictionary).get("pts", [])
		if pts.size() < 2:
			continue
		var line := PackedVector2Array()
		for p in pts:
			var pa: Array = p
			line.append(Vector2(float(pa[0]), float(pa[1])) * SCALE)
		roads.append({"pts": line, "w": clampf(float((rd as Dictionary).get("w", 4.0)), 2.0, 12.0)})
		if road_idx % 3 == 0:
			for k in range(0, line.size(), maxi(1, line.size() / 6)):
				road_points.append(line[k])
		road_idx += 1
	while road_points.size() < 80:
		road_points.append(Vector2(sin(float(road_points.size())) * 400.0, cos(float(road_points.size() * 0.7)) * 400.0))

	var kinds := ["pharmacy", "clinic", "arms", "grocery", "general", "mobile", "tea", "hardware"]
	var names := ["فارميسি", "ক্লিনিক", "অস্ত্র বিক্রেতা", "গ্রোসারি", "জেনারেল স্টোর", "মোবাইল শপ", "চায়ের দোকান", "হার্ডওয়্যার"]
	for i in 30:
		var p: Vector2 = road_points[(i * 7 + 3) % road_points.size()]
		var k := i % kinds.size()
		shops.append({"pos": p, "kind": kinds[k], "name": names[k],
			"color": Color(0.85, 0.68, 0.32) if k == 1 or k == 0 else Color(0.35, 0.72, 0.68)})
	for i in 15:
		gates.append(road_points[(i * 11 + 5) % road_points.size()])
	var kinds_v := ["car", "cng", "rickshaw", "pickup"]
	var colors_v := [Color(0.55, 0.62, 0.66), Color(0.85, 0.62, 0.20),
		Color(0.35, 0.70, 0.55), Color(0.62, 0.45, 0.36)]
	for i in 9:
		vehicles.append({"pos": road_points[(i * 13 + 7) % road_points.size()],
			"kind": kinds_v[i % kinds_v.size()], "color": colors_v[i % colors_v.size()]})
	extraction = road_points[1] + Vector2(24, 24)


func _add_to_grid(idx: int, rect: Rect2) -> void:
	var x0 := int(floor(rect.position.x / CELL))
	var y0 := int(floor(rect.position.y / CELL))
	var x1 := int(floor(rect.end.x / CELL))
	var y1 := int(floor(rect.end.y / CELL))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var key := "%d|%d" % [x, y]
			if not _grid.has(key):
				_grid[key] = []
			(_grid[key] as Array).append(idx)


func candidates_near(p: Vector2) -> Array:
	var key := "%d|%d" % [int(floor(p.x / CELL)), int(floor(p.y / CELL))]
	return _grid.get(key, [])


func is_blocked(p: Vector2, radius: float = 8.0) -> bool:
	for idx in candidates_near(p):
		var r: Rect2 = (buildings[idx as int] as Dictionary)["rect"]
		var nearest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if nearest.distance_squared_to(p) < radius * radius:
			return true
	return false


func clamp_move(from: Vector2, to: Vector2, radius: float = 8.0) -> Vector2:
	if not is_blocked(to, radius):
		return to
	if not is_blocked(Vector2(to.x, from.y), radius):
		return Vector2(to.x, from.y)
	if not is_blocked(Vector2(from.x, to.y), radius):
		return Vector2(from.x, to.y)
	return from


func random_road_point(seed_value: int = 0) -> Vector2:
	if road_points.is_empty():
		return Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return road_points[rng.randi_range(0, road_points.size() - 1)]


func nearest_building(p: Vector2) -> int:
	var best := -1
	var best_d := 1.0e12
	for i in buildings.size():
		var d: float = (buildings[i] as Dictionary)["center"].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


func _draw() -> void:
	# Ground
	draw_rect(Rect2(-2200, -2200, 4400, 4400), Color(0.10, 0.13, 0.13))
	# Roads (wide dark ribbons with a lighter centre line)
	for rd in roads:
		var pts: PackedVector2Array = rd["pts"]
		var w: float = rd["w"] * SCALE
		draw_polyline(pts, Color(0.19, 0.20, 0.21), w + 6.0)
		draw_polyline(pts, Color(0.26, 0.27, 0.27), w)
		draw_polyline(pts, Color(0.32, 0.31, 0.26), 1.5)
	# Buildings: real OSM polygons, coloured by height
	for item in buildings:
		var b: Dictionary = item
		var col: Color = _colors[abs(int((b["center"].x + b["center"].y) / 40.0)) % _colors.size()]
		draw_colored_polygon(b["pts"], col)
		draw_polyline(b["pts"], Color(0.05, 0.06, 0.06), 2.0, true)
		var r: Rect2 = b["rect"]
		if r.size.x > 22.0 and r.size.y > 22.0:
			var steps := mini(int(b["floors"]), 8)
			for f in steps:
				var y := r.position.y + (f + 1) * r.size.y / float(steps + 1)
				draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Color(0.13, 0.16, 0.15), 2.0)
			draw_circle(b["door"], 3.5, Color(0.92, 0.76, 0.38))
	# Shops and gates
	for s in shops:
		var p: Vector2 = s["pos"]
		draw_rect(Rect2(p - Vector2(11, 8), Vector2(22, 16)), s["color"] * 0.55)
		draw_rect(Rect2(p - Vector2(11, 8), Vector2(22, 4)), s["color"])
	for g in gates:
		draw_rect(Rect2(g - Vector2(9, 9), Vector2(18, 18)), Color(0.85, 0.45, 0.18), false, 2.0)
	# Vehicles (sedan / CNG / rickshaw / pickup)
	for v in vehicles:
		var p: Vector2 = v["pos"]
		draw_rect(Rect2(p - Vector2(12, 7), Vector2(24, 14)), v["color"])
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(0.12, 0.18, 0.20))
		draw_circle(p + Vector2(-8, -7), 2.5, Color(0.08, 0.09, 0.10))
		draw_circle(p + Vector2(8, 7), 2.5, Color(0.08, 0.09, 0.10))
	# Extraction zone
	draw_circle(extraction, 30.0, Color(0.15, 0.65, 0.55, 0.18))
	draw_circle(extraction, 30.0, Color(0.25, 0.85, 0.70), false, 3.0)
