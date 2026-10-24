class_name CityLayout
## The city block shared by THE FALLEN CITY (World 1) and THE HOLLOW FUTURE (World 3).
## World 3 is the same street thousands of years later, reflected left-to-right: the reversal
## you caused. Every position is mirrored, every sprite flipped, every prop swapped for its
## rotted "grim_" version, and the people's things are replaced by graves.
##
## Layout (world px, 2592 x 1440; the ground art in ground/city.png matches it):
##   y    0..144   city wall              y  576..624   north sidewalk (lamps)
##   y  186..330   north street front     y  624..816   the road, plaza in the middle
##   y  340..570   north pavement         y  816..864   south sidewalk (lamps)
##   y  880..1290  crash zone + refugee camp, ruined south row, city wall from 1344

const W := 2592.0
const PLAZA := Vector2(1296, 720)

## North street front, west -> east: intact homes first, then ruins toward the crash site.
const NORTH := [
	["town_house_a", 150], ["town_shop", 345], ["town_house_c", 540], ["town_red", 735], ["town_house_b", 930],
	["ruin_c", 1110], ["ruin_b", 1485], ["town_house_a", 1675], ["ruin_a", 1880], ["town_house_c", 2085],
	["ruin_c", 2270], ["town_house_b", 2450],
]
## South row: what the crash left standing.
const SOUTH := [
	["ruin_wall", 140], ["ruin_b", 320], ["moss_trees", 520], ["ruin_wall", 720], ["ruin_c", 900],
	["ruin_a", 1110], ["ruin_rubble", 1310], ["moss_trees", 1500], ["ruin_wall", 1690], ["ruin_rubble", 1880],
	["ruin_b", 2060], ["ruin_wall", 2250], ["ruin_c", 2440],
]
const LAMPS_N := [200, 530, 860, 1730, 2060, 2390]
const LAMPS_S := [365, 695, 1895, 2225]
const TREES_N := [250, 640, 1580, 2180]
const CARS := [["car_blue", Vector2(470, 688), false], ["car_taxi", Vector2(905, 772), true],
	["car_red", Vector2(1760, 686), true], ["car_blue", Vector2(2140, 770), false]]
const PODS := [Vector2(699, 712), Vector2(2280, 684), Vector2(1660, 1000), Vector2(2152, 1016)]
const SAUCER := Vector2(1900, 1096)


static func build(lv: Level, grim: bool) -> void:
	var m := func(p: Vector2) -> Vector2: return Vector2(W - p.x, p.y) if grim else p
	var n := func(name: String) -> String:
		if not grim:
			return name
		var g := "grim_" + name
		return g if ResourceLoader.exists("res://assets/ninja/props/%s.png" % g) else name
	var base := {"flip": grim}
	# The wall bands in the ground art are solid.
	lv.block(Rect2(0, 0, W, 150))
	lv.block(Rect2(0, 1338, W, 120))
	# Street fronts
	for h in NORTH:
		lv.prop(n.call(h[0]), m.call(Vector2(h[1], 330)), base)
	for h in SOUTH:
		var nm: String = h[0]
		if grim and nm == "moss_trees":
			nm = "grim_tree_dead"
		lv.prop(n.call(nm), m.call(Vector2(h[1], 1300)), base)
	# The town hall north of the plaza, and its lion
	lv.prop(n.call("ruin_house_big"), m.call(Vector2(1296, 318)), base)
	lv.prop(n.call("statue_lion"), m.call(PLAZA + Vector2(0, -262)), base)
	# Street lamps along both sidewalks (dead and cold in the future)
	for x in LAMPS_N:
		_lamp(lv, n.call("lamp_post"), m.call(Vector2(x, 600)), grim)
	for x in LAMPS_S:
		_lamp(lv, n.call("lamp_post"), m.call(Vector2(x, 862)), grim)
	# Four lamps frame the plaza where the mirror will open
	for off in [Vector2(-236, -170), Vector2(236, -170), Vector2(-236, 170), Vector2(236, 170)]:
		_lamp(lv, n.call("lamp_post"), m.call(PLAZA + off + Vector2(0, 30)), grim)
	# Planted trees on the north pavement
	for x in TREES_N:
		lv.prop("grim_tree_dead" if grim else "moss_tree", m.call(Vector2(x, 548)), base.merged({"sway": not grim}))
	# Abandoned cars on the road
	for c in CARS:
		lv.prop(n.call(c[0]), m.call(c[1]), {"flip": c[2] != grim})
	# The city sealed the road off at both gates
	for x in [112.0, 2480.0]:
		for y in [662.0, 778.0]:
			lv.prop(n.call("road_barrier"), m.call(Vector2(x, y)), base)
	# Where they came down: the saucer and its escape pods, still glowing in the present
	lv.prop("grim_saucer_wreck" if grim else "saucer_wreck", m.call(SAUCER), base.merged(
		{} if grim else {"light": Color(0.4, 1.0, 0.6), "energy": 1.2, "light_scale": 3.0}))
	for i in PODS.size():
		var pos: Vector2 = m.call(PODS[i])
		if grim:
			lv.prop("grim_pod_broken", pos, base)
		else:
			lv.prop("alien_pod", pos, {"light": Color(0.4, 1.0, 0.5), "energy": 1.3, "light_scale": 2.2, "flip": i % 2 == 1})
	# Debris thrown out by the crash
	for d in [["pillar_broken", Vector2(1720, 1180)], ["rock_grey_small", Vector2(1610, 1110)], ["ruin_rubble", Vector2(2300, 1150)],
			["rock_grey_small", Vector2(2050, 960)], ["pillar_broken", Vector2(1450, 940)]]:
		lv.prop(("grim_pillar_broken" if d[0] == "pillar_broken" else n.call(d[0])) if grim else d[0], m.call(d[1]), base)
	# Weeds where the paving meets the walls
	var weeds := ["bush_a", "bush_b", "fern"]
	var k := 0
	for h in NORTH:
		for side in [-78, 78]:
			k += 1
			if grim:
				if k % 3 == 0:
					lv.prop("grim_grave", m.call(Vector2(h[1] + side, 352)), {"collide": false, "flip": grim})
			else:
				lv.prop(weeds[k % 3], m.call(Vector2(h[1] + side, 346)), {"collide": false})
	# Keep the plaza and the gates clear
	lv.keepout(m.call(PLAZA), 300.0)


static func _lamp(lv: Level, name: String, pos: Vector2, grim: bool) -> void:
	if grim:
		lv.prop(name, pos, {"flip": true})
	else:
		lv.prop(name, pos, {"light": Color(1.0, 0.75, 0.45), "energy": 1.3, "light_scale": 2.4})
