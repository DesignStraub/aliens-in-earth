extends Node
## Einfache Computer-KI: Wirtschaft, Bauen, Aufsteigen, Konter-Einheiten, Angriffswellen.

const UnitScript = preload("res://scripts/unit.gd")
const NONE := Vector2i(-1, -1)

var world
var pid := 1
var think_t := 0.0
var think_interval := 1.0
var drop_t := 5.0
var next_attack := 330.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	think_t = rng.randf()


func _process(delta: float) -> void:
	if world == null or not world.running or world.game_over:
		return
	think_t -= delta
	if think_t > 0.0:
		return
	think_t = think_interval
	_think()


func _think() -> void:
	var p: Dictionary = world.players[pid]
	var tc = _find("town_center")
	var vills: Array = []
	var army: Array = []
	for u in world.units:
		if u.owner_id != pid:
			continue
		if u.kind == "villager":
			vills.append(u)
		else:
			army.append(u)
	if tc != null and tc.built:
		_train_villagers(p, tc, vills)
		_assign_builders(vills)
		_build_stuff(p, tc, vills)
		_assign_gatherers(p, tc, vills)
		_age_up(p, tc, vills)
		_research(p, vills)
		_train_army(p, vills, army)
	_war(p, tc, army)


# ---------------------------------------------------------------- Helfer

func _find(kind: String):
	for b in world.buildings:
		if b.owner_id == pid and b.kind == kind:
			return b
	return null


func _count(kind: String) -> int:
	var n := 0
	for b in world.buildings:
		if b.owner_id == pid and b.kind == kind:
			n += 1
	return n


func _unfinished(kind: String) -> bool:
	for b in world.buildings:
		if b.owner_id == pid and b.kind == kind and not b.built:
			return true
	return false


func _target_vills(p: Dictionary) -> int:
	return mini(20 + int(p["age"]) * 7, 50)


func _reserve(p: Dictionary, vills: Array) -> Dictionary:
	if int(p["age"]) < 4 and not p["aging"] and vills.size() >= _target_vills(p) - 4:
		return Data.AGES[p["age"] + 1]["cost"]
	return {}


func _afford_with_reserve(cost: Dictionary, reserve: Dictionary) -> bool:
	var r: Dictionary = world.players[pid]["res"]
	for k in cost:
		if float(r[k]) - float(cost[k]) < float(reserve.get(k, 0)):
			return false
	return true


func _origin(tc) -> Vector2i:
	return world.to_cell(tc.center())


func _spot_ok(kind: String, c: Vector2i, size: int) -> bool:
	if not world.can_place(kind, c):
		return false
	# Rand freihalten, damit sich die KI nicht selbst einmauert
	for y in range(-1, size + 1):
		for x in range(-1, size + 1):
			var n := c + Vector2i(x, y)
			if not world.in_bounds(n) or world.occ.has(n):
				return false
	return true


func _find_spot(kind: String, near: Vector2i, rmin: float, rmax: float) -> Vector2i:
	var size: int = Data.BUILDINGS[kind]["size"]
	for i in 80:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var c := near + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r)) - Vector2i(size / 2, size / 2)
		if _spot_ok(kind, c, size):
			return c
	return NONE


func _nearest_villager(vills: Array, pos: Vector2):
	var best = null
	var bd := 1e9
	for v in vills:
		if v.state == UnitScript.S.BUILD:
			continue
		var d: float = v.position.distance_to(pos)
		if v.state == UnitScript.S.IDLE:
			d *= 0.5
		if d < bd:
			bd = d
			best = v
	return best


func _try_build(vills: Array, kind: String, near: Vector2i, rmin: float, rmax: float, reserve := {}) -> bool:
	var cost := Data.building_cost(kind, world.players[pid]["faction"])
	if not _afford_with_reserve(cost, reserve):
		return false
	var spot := _find_spot(kind, near, rmin, rmax)
	if spot.x < 0:
		return false
	world.pay(pid, cost)
	var b = world.place_building(kind, spot, pid, false)
	var v = _nearest_villager(vills, b.center())
	if v != null:
		v.cmd_build(b)
	return true


# ---------------------------------------------------------------- Wirtschaft

func _train_villagers(p: Dictionary, tc, vills: Array) -> void:
	if p["aging"] or tc.queue.size() >= 2:
		return
	var queued := 0
	for item in tc.queue:
		if item == "villager":
			queued += 1
	if vills.size() + queued < _target_vills(p):
		world.queue_train(tc, "villager")


func _assign_builders(vills: Array) -> void:
	for b in world.buildings:
		if b.owner_id != pid or b.built:
			continue
		var has_builder := false
		for v in vills:
			if v.state == UnitScript.S.BUILD and v.target == b:
				has_builder = true
				break
		if not has_builder:
			var v = _nearest_villager(vills, b.center())
			if v != null:
				v.cmd_build(b)


func _want(p: Dictionary) -> Dictionary:
	match int(p["age"]):
		0:
			return {"food": 0.55, "wood": 0.4, "gold": 0.05, "stone": 0.0}
		1:
			return {"food": 0.42, "wood": 0.33, "gold": 0.2, "stone": 0.05}
	return {"food": 0.38, "wood": 0.27, "gold": 0.25, "stone": 0.1}


var rebalance_t := 20.0


## Bei großem Überschuss einer Ressource ein paar Sammler freistellen.
func _rebalance(p: Dictionary, vills: Array) -> void:
	rebalance_t -= think_interval
	if rebalance_t > 0.0:
		return
	rebalance_t = 20.0
	var r: Dictionary = p["res"]
	var want := _want(p)
	var low := ""
	for k in want:
		if float(want[k]) > 0.05 and float(r[k]) < 250.0:
			low = k
	if low == "":
		return
	for k in Data.RES:
		if k != low and float(r[k]) > 700.0:
			var freed := 0
			for v in vills:
				if v.task_type == k and v.state == UnitScript.S.GATHER and freed < 3:
					v.state = UnitScript.S.IDLE
					v.task_type = ""
					freed += 1
			return


func _assign_gatherers(p: Dictionary, tc, vills: Array) -> void:
	_rebalance(p, vills)
	var want := _want(p)
	var counts := {"food": 0, "wood": 0, "gold": 0, "stone": 0}
	for v in vills:
		if v.state != UnitScript.S.IDLE and v.task_type != "":
			counts[v.task_type] = int(counts[v.task_type]) + 1
	var n := vills.size()
	for v in vills:
		if v.state != UnitScript.S.IDLE:
			continue
		var order := want.keys()
		order.sort_custom(func(a, b) -> bool: return float(want[a]) * n - counts[a] > float(want[b]) * n - counts[b])
		for type in order:
			if float(want[type]) <= 0.0:
				continue
			if _send_gather(v, type, tc, vills):
				counts[type] = int(counts[type]) + 1
				break


func _send_gather(v, type: String, tc, vills: Array) -> bool:
	var origin := _origin(tc)
	if type == "food":
		var c: Vector2i = world.find_resource_near("berry", origin, 14, NONE, pid)
		if c.x >= 0:
			v.cmd_gather(c)
			return true
		for b in world.buildings:
			if b.owner_id == pid and b.kind == "farm" and b.built and world.farmers(b) == 0:
				v.cmd_farm(b)
				return true
		var cost := Data.building_cost("farm", world.players[pid]["faction"])
		if world.can_afford(pid, cost):
			var spot := _find_spot("farm", origin, 3.0, 9.0)
			if spot.x < 0:
				spot = _find_spot("farm", origin, 6.0, 15.0)
			if spot.x >= 0:
				world.pay(pid, cost)
				var fb = world.place_building("farm", spot, pid, false)
				v.cmd_build(fb)
				return true
		return false
	var c2: Vector2i = world.find_resource_near(Data.RES_KIND[type], origin, 30, NONE, pid)
	if c2.x >= 0:
		v.cmd_gather(c2)
		return true
	return false


func _maybe_dropoffs(p: Dictionary, tc, vills: Array) -> void:
	if _unfinished("camp") or _unfinished("mill"):
		return
	var origin := _origin(tc)
	for type in ["food", "wood", "gold", "stone"]:
		if type == "stone" and int(p["age"]) < 1:
			continue
		var c: Vector2i = world.find_resource_near(Data.RES_KIND[type], origin, 25, NONE, pid)
		if c.x < 0:
			continue
		var drop = world.nearest_dropoff(pid, type, world.cell_center(c))
		if drop != null and world.dist_to_rect(world.cell_center(c), drop.rect()) < 16.0 * 6.0:
			continue
		var kind := "mill" if type == "food" else "camp"
		if _try_build(vills, kind, c, 2.0, 5.0):
			return


func _build_stuff(p: Dictionary, tc, vills: Array) -> void:
	var origin := _origin(tc)
	var age := int(p["age"])
	var n := vills.size()
	var reserve := _reserve(p, vills)
	var cap: int = world.pop_cap(pid)
	if cap < Data.POP_MAX and cap - world.pop(pid) <= 3 + age and not _unfinished("house"):
		_try_build(vills, "house", origin, 4.0, 12.0)
	drop_t -= 1.0
	if drop_t <= 0.0:
		drop_t = 10.0
		_maybe_dropoffs(p, tc, vills)
	if n >= 9 and _count("barracks") == 0:
		_try_build(vills, "barracks", origin, 6.0, 12.0, reserve)
	if age >= 1 and n >= 14 and _count("range") == 0:
		_try_build(vills, "range", origin, 6.0, 13.0, reserve)
	if age >= 1 and _count("tower") == 0:
		_try_build(vills, "tower", origin, 3.0, 6.0, reserve)
	if age >= 2 and _count("stable") == 0:
		_try_build(vills, "stable", origin, 6.0, 13.0, reserve)
	if age >= 2 and n >= 25 and _count("barracks") < 2:
		_try_build(vills, "barracks", origin, 6.0, 14.0, reserve)
	if age >= 3 and _count("workshop") == 0:
		_try_build(vills, "workshop", origin, 6.0, 14.0, reserve)
	if age >= 3 and _count("range") < 2:
		_try_build(vills, "range", origin, 6.0, 14.0, reserve)


func _age_up(p: Dictionary, tc, vills: Array) -> void:
	if p["aging"] or int(p["age"]) >= Data.AGES.size() - 1:
		return
	if vills.size() < _target_vills(p) - 4:
		return
	world.queue_age_up(tc)


const TECH_PRIORITY := ["loom", "double_axe", "horse_collar", "wheelbarrow", "gold_mining", "forging", "fletching", "bow_saw", "masonry", "scale_armor", "barding", "handcart", "tower_arrows", "crop_rotation", "stone_mining", "ballistics", "gunpowder"]


func _research(p: Dictionary, vills: Array) -> void:
	var reserve := {}
	for k in _reserve(p, vills):
		reserve[k] = float(_reserve(p, vills)[k]) * 0.5
	for tid in TECH_PRIORITY:
		if not world.tech_available(pid, tid):
			continue
		if not _afford_with_reserve(Data.TECHS[tid]["cost"], reserve):
			continue
		var at: String = Data.TECHS[tid]["at"]
		for b in world.buildings:
			if b.owner_id == pid and b.kind == at and b.built and b.queue.is_empty():
				world.queue_research(b, tid)
				return


# ---------------------------------------------------------------- Militär

func _train_army(p: Dictionary, vills: Array, army: Array) -> void:
	var reserve := _reserve(p, vills)
	var enemy := {"spear": 0, "archer": 0, "cavalry": 0, "siege": 0}
	var own := {"spear": 0, "archer": 0, "cavalry": 0, "siege": 0}
	for u in world.units:
		if enemy.has(u.kind):
			if u.owner_id == pid:
				own[u.kind] = int(own[u.kind]) + 1
			elif world.is_enemy(pid, u.owner_id):
				enemy[u.kind] = int(enemy[u.kind]) + 1
	# Konter-Gewichte nach Schere-Stein-Papier
	var w := {
		"spear": 1.0 + enemy["cavalry"] * 2.0,
		"archer": 1.0 + enemy["spear"] * 2.0,
		"cavalry": 1.0 + (enemy["archer"] + enemy["siege"]) * 2.0,
		"siege": 0.6,
	}
	var avail := []
	for k in w:
		if int(p["age"]) >= int(Data.UNITS[k]["age"]):
			avail.append(k)
	var total_w := 0.0
	for k in avail:
		total_w += float(w[k])
	var total_own := maxi(1, army.size())
	# In der Funkenzeit nur eine kleine Wache, sonst fehlt Nahrung für den Aufstieg
	if int(p["age"]) == 0 and army.size() >= 5:
		return
	for b in world.buildings:
		if b.owner_id != pid or not b.built or b.kind == "town_center":
			continue
		var trains: Array = b.info.get("trains", [])
		if trains.is_empty() or b.queue.size() >= 2:
			continue
		var k: String = trains[0]
		if not avail.has(k):
			continue
		var share := float(w[k]) / total_w
		if float(own[k]) / total_own > share + 0.12 and army.size() > 3:
			continue
		var cost := Data.unit_cost(k, p["faction"])
		if _afford_with_reserve(cost, reserve) and world.pop(pid) < world.pop_cap(pid):
			world.queue_train(b, k)


func _war(p: Dictionary, tc, army: Array) -> void:
	if army.is_empty():
		return
	var home: Vector2 = tc.center() if tc != null else army[0].position
	# Verteidigung
	var threat = null
	for b in world.buildings:
		if b.owner_id == pid and not b.info.get("wall", false):
			threat = world.nearest_enemy_unit(pid, b.center(), 16.0 * 10.0)
			if threat != null:
				break
	if threat != null:
		for u in army:
			if u.position.distance_to(home) < 16.0 * 30.0 and (u.state == UnitScript.S.IDLE or u.state == UnitScript.S.MOVE):
				u.cmd_attack(threat)
		return
	var age := int(p["age"])
	if (world.game_time >= next_attack and army.size() >= 5 + 3 * age) or army.size() >= 30:
		next_attack = world.game_time + 140.0
		var tgt = world.nearest_enemy_building(pid, home, 1e9, false)
		if tgt != null:
			for u in army:
				u.cmd_attack(tgt)
	# Untätige Truppen im Feindesland greifen weiter an
	for u in army:
		if u.state == UnitScript.S.IDLE and u.position.distance_to(home) > 16.0 * 25.0:
			var t2 = world.nearest_enemy_building(pid, u.position, 16.0 * 80.0, false)
			if t2 == null:
				t2 = world.nearest_enemy_building(pid, u.position, 16.0 * 80.0, true)
			if t2 != null:
				u.cmd_attack(t2)
