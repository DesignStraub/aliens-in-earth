extends Node2D
## Die Spielwelt: Karte, Wegfindung, Wirtschaft, Auswahl und Eingabe.

const MapGen = preload("res://scripts/map_gen.gd")
const UnitScript = preload("res://scripts/unit.gd")
const BuildingScript = preload("res://scripts/building.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const FxScript = preload("res://scripts/fx.gd")
const ResLayerScript = preload("res://scripts/res_layer.gd")
const OverlayScript = preload("res://scripts/overlay.gd")
const AIScript = preload("res://scripts/ai.gd")
const HudScript = preload("res://scripts/hud.gd")

const T := 16
const WATER := 1
const NONE := Vector2i(-1, -1)
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var W := 0
var H := 0
var terrain := PackedByteArray()
var resources: Dictionary = {}
var occ: Dictionary = {}
var astars: Array = []
var astar_terrain: AStarGrid2D
var players: Array = []
var units: Array = []
var buildings: Array = []
var running := false
var game_over := false
var game_time := 0.0
var seed_val := 0
var autotest := false

var res_layer
var entities: Node2D
var fx_layer: Node2D
var overlay
var camera: Camera2D
var hud
var ais: Array = []

var selected: Array = []
var place_kind := ""
var ghost_cell := Vector2i.ZERO
var dragging := false
var drag_start := Vector2.ZERO
var wall_start := NONE
var check_t := 0.0
var minimap_dirty := true
var stat_t := 0.0


func _ready() -> void:
	randomize()
	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	add_child(camera)
	hud = HudScript.new()
	hud.world = self
	add_child(hud)
	if "--autotest" in OS.get_cmdline_user_args():
		autotest = true
		Engine.time_scale = 8.0
		start_game("mammals", ["aliens", "plants"][randi() % 2])
	elif "--uitest" in OS.get_cmdline_user_args():
		start_game("plants", "aliens")
		_ui_test()
	else:
		hud.show_menu()
		if "--menushot" in OS.get_cmdline_user_args():
			await get_tree().create_timer(1.5).timeout
			get_viewport().get_texture().get_image().save_png("res://shot_menu.png")
			get_tree().quit()


func start_game(fac: String, enemy_fac: String) -> void:
	seed_val = randi()
	W = Data.MAP_W
	H = Data.MAP_H
	var g: Dictionary = MapGen.generate(W, H, seed_val)
	terrain = g["terrain"]
	resources = g["res"]
	var starts: Array = g["starts"]

	var ts := Sprite2D.new()
	ts.centered = false
	ts.texture = ImageTexture.create_from_image(Art.build_terrain_image(terrain, W, H, seed_val))
	ts.z_index = -10
	add_child(ts)
	res_layer = ResLayerScript.new()
	res_layer.world = self
	res_layer.z_index = -5
	add_child(res_layer)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	overlay = OverlayScript.new()
	overlay.world = self
	add_child(overlay)

	players = []
	var facs := [fac, enemy_fac]
	for i in 2:
		players.append({"id": i, "faction": facs[i], "res": Data.START_RES.duplicate(), "age": 0, "aging": false, "ai": i == 1 or autotest})
	_setup_astar()
	for i in 2:
		var s: Vector2i = starts[i]
		place_building("town_center", s - Vector2i(1, 1), i, true)
		for k in 3:
			spawn_unit("villager", i, cell_center(s + Vector2i(-2 + k * 2, 3)))
		spawn_unit("spear", i, cell_center(s + Vector2i(3, -2)))
		if players[i]["ai"]:
			var ai = AIScript.new()
			ai.world = self
			ai.pid = i
			add_child(ai)
			ais.append(ai)
	camera.position = cell_center(starts[0])
	running = true
	hud.on_game_started()


func _make_astar() -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, W, H)
	a.cell_size = Vector2(1, 1)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.update()
	return a


func _setup_astar() -> void:
	astars = [_make_astar(), _make_astar()]
	astar_terrain = _make_astar()
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if terrain[y * W + x] == WATER or resources.has(c):
				astar_terrain.set_point_solid(c, true)
				for a in astars:
					a.set_point_solid(c, true)


# ---------------------------------------------------------------- Raster-Helfer

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * T + Vector2(T, T) * 0.5


func valid(e) -> bool:
	return e != null and is_instance_valid(e) and not e.dead


func is_solid_for(pid: int, c: Vector2i) -> bool:
	if not in_bounds(c):
		return true
	return astars[pid].is_point_solid(c)


func _building_blocks(pid: int, c: Vector2i) -> bool:
	var b = occ.get(c)
	if b == null:
		return false
	if b.info.get("walkable", false):
		return false
	if b.info.get("gate", false) and b.owner_id == pid and b.built:
		return false
	return true


func refresh_cell(c: Vector2i) -> void:
	var base := terrain[c.y * W + c.x] == WATER or resources.has(c)
	astar_terrain.set_point_solid(c, base)
	for pid in astars.size():
		astars[pid].set_point_solid(c, base or _building_blocks(pid, c))


func dist_to_rect(p: Vector2, r: Rect2i) -> float:
	var rr := Rect2(Vector2(r.position) * T, Vector2(r.size) * T)
	var q := Vector2(clampf(p.x, rr.position.x, rr.end.x), clampf(p.y, rr.position.y, rr.end.y))
	return p.distance_to(q)


func rect_dist_cells(c: Vector2i, r: Rect2i) -> int:
	var dx := maxi(0, maxi(r.position.x - c.x, c.x - (r.end.x - 1)))
	var dy := maxi(0, maxi(r.position.y - c.y, c.y - (r.end.y - 1)))
	return maxi(dx, dy)


func ring_cells(r: Rect2i) -> Array:
	var out := []
	for x in range(r.position.x - 1, r.end.x + 1):
		out.append(Vector2i(x, r.position.y - 1))
		out.append(Vector2i(x, r.end.y))
	for y in range(r.position.y, r.end.y):
		out.append(Vector2i(r.position.x - 1, y))
		out.append(Vector2i(r.end.x, y))
	return out


func line_cells(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var c := a
	while out.size() < 200:
		out.append(c)
		if c == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			c.x += sx
		if e2 <= dx:
			err += dx
			c.y += sy
	return out


# ---------------------------------------------------------------- Wegfindung

func nearest_free(pid: int, c: Vector2i) -> Vector2i:
	var a: AStarGrid2D = astars[pid]
	for rad in range(0, 16):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dy)) != rad:
					continue
				var n := c + Vector2i(dx, dy)
				if in_bounds(n) and not a.is_point_solid(n):
					return n
	return c


func find_path(pid: int, from: Vector2i, to: Vector2i, partial := false) -> Array:
	var a: AStarGrid2D = astars[pid]
	to = Vector2i(clampi(to.x, 0, W - 1), clampi(to.y, 0, H - 1))
	var start := from
	if not in_bounds(start) or a.is_point_solid(start):
		start = nearest_free(pid, from)
	var ids: Array[Vector2i] = a.get_id_path(start, to, partial)
	if ids.is_empty():
		return []
	var pts := []
	if ids.size() == 1:
		pts.append(cell_center(ids[0]))
	for i in range(1, ids.size()):
		pts.append(cell_center(ids[i]))
	if start != from:
		pts.push_front(cell_center(start))
	return pts


func find_path_adjacent(pid: int, from: Vector2i, r: Rect2i) -> Array:
	var a: AStarGrid2D = astars[pid]
	var cands := []
	for c in ring_cells(r):
		if in_bounds(c) and not a.is_point_solid(c):
			cands.append(c)
	if cands.is_empty():
		return []
	cands.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return (p - from).length_squared() < (q - from).length_squared())
	for i in mini(cands.size(), 5):
		var p := find_path(pid, from, cands[i], false)
		if not p.is_empty():
			return p
	return []


## Erstes feindliches Gebäude auf dem Weg, wenn man Gebäude ignorieren würde (Mauern brechen).
func find_blocking_building(pid: int, from: Vector2i, to: Vector2i):
	if astar_terrain.is_point_solid(from):
		return null
	var ids: Array[Vector2i] = astar_terrain.get_id_path(from, to, true)
	for c in ids:
		var b = occ.get(c)
		if b != null and b.owner_id != pid and _building_blocks(pid, c):
			return b
	return null


func formation_cells(pid: int, c: Vector2i, n: int) -> Array:
	var a: AStarGrid2D = astars[pid]
	var start := c
	if not in_bounds(start) or a.is_point_solid(start):
		start = nearest_free(pid, c)
	var out := [start]
	var seen := {start: true}
	var q := [start]
	var qi := 0
	while out.size() < n and qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		for d in DIRS8:
			var nb: Vector2i = cur + d
			if seen.has(nb) or not in_bounds(nb) or a.is_point_solid(nb):
				continue
			seen[nb] = true
			q.append(nb)
			out.append(nb)
			if out.size() >= n:
				break
	while out.size() < n:
		out.append(start)
	return out


func spawn_point(b) -> Vector2:
	var cands := []
	for c in ring_cells(b.rect()):
		if in_bounds(c) and not is_solid_for(b.owner_id, c):
			cands.append(c)
	if cands.is_empty():
		return cell_center(nearest_free(b.owner_id, b.cell))
	var goal: Vector2 = b.rally if b.has_rally else b.center() + Vector2(0, 100)
	cands.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return cell_center(p).distance_squared_to(goal) < cell_center(q).distance_squared_to(goal))
	return cell_center(cands[0]) + Vector2(randf_range(-3, 3), randf_range(-3, 3))


# ---------------------------------------------------------------- Abfragen

func unit_at(pos: Vector2):
	var best = null
	var bd := 9.0
	for u in units:
		var d: float = u.aim_point().distance_to(pos)
		if d < bd:
			bd = d
			best = u
	return best


func nearest_enemy_unit(pid: int, pos: Vector2, radius: float):
	var best = null
	var bd := radius
	for u in units:
		if u.owner_id == pid:
			continue
		var d: float = pos.distance_to(u.position)
		if d < bd:
			bd = d
			best = u
	return best


func nearest_enemy_building(pid: int, pos: Vector2, radius: float, walls := false):
	var best = null
	var bd := radius
	for b in buildings:
		if b.owner_id == pid or (not walls and b.info.get("wall", false)):
			continue
		var d := dist_to_rect(pos, b.rect())
		if d < bd:
			bd = d
			best = b
	return best


func nearest_dropoff(pid: int, type: String, pos: Vector2):
	var best = null
	var bd := 1e9
	for b in buildings:
		if b.owner_id == pid and b.accepts(type):
			var d := dist_to_rect(pos, b.rect())
			if d < bd:
				bd = d
				best = b
	return best


func nearest_unfinished(pid: int, pos: Vector2, radius: float):
	var best = null
	var bd := radius
	for b in buildings:
		if b.owner_id == pid and not b.built:
			var d := dist_to_rect(pos, b.rect())
			if d < bd:
				bd = d
				best = b
	return best


func farmers(b) -> int:
	var n := 0
	for u in units:
		if u.farm == b:
			n += 1
	return n


func _has_free_neighbor(c: Vector2i) -> bool:
	for d in DIRS8:
		var n: Vector2i = c + d
		if in_bounds(n) and not astar_terrain.is_point_solid(n) and not occ.has(n):
			return true
	return false


## Gefährliche Orte: Umkreis feindlicher Dorfzentren und Türme.
func _danger_zones(pid: int) -> Array:
	var out := []
	if pid < 0:
		return out
	for b in buildings:
		if b.owner_id != pid and b.info.has("attack"):
			out.append(b.center())
	return out


func find_resource_near(kind: String, c: Vector2i, radius: int, exclude := NONE, avoid_pid := -1) -> Vector2i:
	var best := NONE
	var bd := 1 << 30
	var danger := _danger_zones(avoid_pid)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var n := c + Vector2i(dx, dy)
			if n == exclude:
				continue
			var r = resources.get(n)
			if r == null or r["kind"] != kind:
				continue
			var d := dx * dx + dy * dy
			if d < bd and _has_free_neighbor(n):
				var safe := true
				for z in danger:
					if cell_center(n).distance_to(z) < 16.0 * 10.0:
						safe = false
						break
				if safe:
					bd = d
					best = n
	return best


func take_resource(c: Vector2i, amt: float) -> float:
	var r = resources.get(c)
	if r == null:
		return 0.0
	var got := minf(amt, float(r["amount"]))
	r["amount"] = float(r["amount"]) - got
	if float(r["amount"]) <= 0.001:
		resources.erase(c)
		refresh_cell(c)
		res_layer.queue_redraw()
		minimap_dirty = true
	return got


# ---------------------------------------------------------------- Wirtschaft

func can_afford(pid: int, cost: Dictionary) -> bool:
	var r: Dictionary = players[pid]["res"]
	for k in cost:
		if float(r[k]) < float(cost[k]):
			return false
	return true


func pay(pid: int, cost: Dictionary) -> void:
	var r: Dictionary = players[pid]["res"]
	for k in cost:
		r[k] = float(r[k]) - float(cost[k])


func refund(pid: int, cost: Dictionary) -> void:
	var r: Dictionary = players[pid]["res"]
	for k in cost:
		r[k] = float(r[k]) + float(cost[k])


func missing_text(pid: int, cost: Dictionary) -> String:
	var r: Dictionary = players[pid]["res"]
	for k in cost:
		if float(r[k]) < float(cost[k]):
			return "Nicht genug %s" % Data.RES_NAMES[k]
	return ""


func unit_count(pid: int) -> int:
	var n := 0
	for u in units:
		if u.owner_id == pid:
			n += 1
	return n


func pop(pid: int) -> int:
	var n := unit_count(pid)
	for b in buildings:
		if b.owner_id == pid:
			for item in b.queue:
				if item != "age_up":
					n += 1
	return n


func pop_cap(pid: int) -> int:
	var cap := 0
	for b in buildings:
		if b.owner_id == pid and b.built:
			cap += int(b.info.get("pop", 0))
	return mini(cap, Data.POP_MAX)


func _msg(pid: int, text: String) -> void:
	if pid == 0 and not players[0]["ai"]:
		hud.message(text)


func queue_train(b, kind: String) -> bool:
	var pid: int = b.owner_id
	var p: Dictionary = players[pid]
	if int(p["age"]) < int(Data.UNITS[kind]["age"]):
		_msg(pid, "Erst ab %s verfügbar" % Data.AGES[Data.UNITS[kind]["age"]]["name"])
		return false
	if b.queue.size() >= 8:
		return false
	if pop(pid) >= pop_cap(pid):
		_msg(pid, "Bevölkerungslimit erreicht – baue Häuser")
		return false
	var cost := Data.unit_cost(kind, p["faction"])
	if not can_afford(pid, cost):
		_msg(pid, missing_text(pid, cost))
		return false
	pay(pid, cost)
	b.queue.append(kind)
	return true


func queue_age_up(b) -> bool:
	var pid: int = b.owner_id
	var p: Dictionary = players[pid]
	if p["aging"] or int(p["age"]) >= Data.AGES.size() - 1:
		return false
	var cost: Dictionary = Data.AGES[p["age"] + 1]["cost"]
	if not can_afford(pid, cost):
		_msg(pid, missing_text(pid, cost))
		return false
	pay(pid, cost)
	p["aging"] = true
	b.queue.append("age_up")
	return true


func cancel_queue(b, idx: int) -> void:
	if idx < 0 or idx >= b.queue.size():
		return
	var item: String = b.queue[idx]
	var p: Dictionary = players[b.owner_id]
	if item == "age_up":
		refund(b.owner_id, Data.AGES[p["age"] + 1]["cost"])
		p["aging"] = false
	else:
		refund(b.owner_id, Data.unit_cost(item, p["faction"]))
	b.queue.remove_at(idx)
	if idx == 0:
		b.queue_t = 0.0


func complete_age_up(pid: int) -> void:
	var p: Dictionary = players[pid]
	p["age"] = int(p["age"]) + 1
	p["aging"] = false
	for u in units:
		if u.owner_id == pid:
			u.refresh_stats()
	var name: String = Data.AGES[p["age"]]["name"]
	if pid == 0:
		hud.message("Ihr habt die %s erreicht! Eure Einheiten werden stärker." % name)
	else:
		hud.message("Der Gegner hat die %s erreicht." % name)
	hud.dirty = true
	if autotest:
		print("[%4ds] Spieler %d erreicht %s" % [int(game_time), pid, name])


# ---------------------------------------------------------------- Entitäten

func can_place(kind: String, c: Vector2i) -> bool:
	var size: int = Data.BUILDINGS[kind]["size"]
	for y in size:
		for x in size:
			var n := c + Vector2i(x, y)
			if not in_bounds(n) or terrain[n.y * W + n.x] == WATER:
				return false
			if resources.has(n) or occ.has(n):
				return false
	return true


func place_building(kind: String, c: Vector2i, pid: int, complete: bool):
	var b = BuildingScript.new()
	b.setup(self, kind, pid, c, complete)
	entities.add_child(b)
	buildings.append(b)
	for y in b.size:
		for x in b.size:
			var n := c + Vector2i(x, y)
			occ[n] = b
			refresh_cell(n)
	if not b.info.get("walkable", false):
		for u in units:
			if b.rect().has_point(u.cell()):
				u.position = cell_center(nearest_free(u.owner_id, u.cell()))
				u.path = []
	minimap_dirty = true
	return b


func on_building_complete(b) -> void:
	for y in b.size:
		for x in b.size:
			refresh_cell(b.cell + Vector2i(x, y))
	hud.dirty = true
	if b.owner_id == 0 and not b.info.get("wall", false):
		_msg(0, "%s fertiggestellt" % b.display_name())


func destroy_building(b) -> void:
	if b.dead:
		return
	b.dead = true
	buildings.erase(b)
	selected.erase(b)
	for y in b.size:
		for x in b.size:
			var n: Vector2i = b.cell + Vector2i(x, y)
			if occ.get(n) == b:
				occ.erase(n)
			refresh_cell(n)
	if b.kind != "farm":
		spawn_fx("rubble", b.center(), Color("8a7a60"))
	b.queue_free()
	hud.dirty = true
	minimap_dirty = true


func spawn_unit(kind: String, pid: int, pos: Vector2):
	var u = UnitScript.new()
	u.setup(self, kind, pid, pos)
	entities.add_child(u)
	units.append(u)
	return u


func kill_unit(u) -> void:
	if u.dead:
		return
	u.dead = true
	units.erase(u)
	selected.erase(u)
	spawn_fx("die", u.position, Art.TEAM[u.owner_id])
	u.queue_free()
	hud.dirty = true


func spawn_fx(kind: String, pos: Vector2, color: Color) -> void:
	var f = FxScript.new()
	f.kind = kind
	f.color = color
	f.position = pos
	fx_layer.add_child(f)


func spawn_projectile(src, t, dmg: float, big: bool) -> void:
	var p = ProjectileScript.new()
	p.world = self
	p.target = t
	p.attacker = src
	p.dmg = dmg
	p.big = big
	p.color = Data.FACTIONS[players[src.owner_id]["faction"]]["shot"]
	p.position = src.aim_point()
	fx_layer.add_child(p)


func calc_damage(att_kind: String, atk: float, t) -> float:
	if t.is_building:
		return maxf(1.0, atk * float(Data.VS_BUILDING.get(att_kind, 1.0)))
	var bon: Dictionary = Data.BONUS.get(att_kind, {})
	var mult := float(bon.get(t.kind, bon.get("*", 1.0)))
	return maxf(1.0, atk * mult - float(t.stats["armor"]))


func apply_damage(t, dmg: float, attacker) -> void:
	if not valid(t):
		return
	t.take_damage(dmg, attacker if valid(attacker) else null)


func call_for_help(victim, attacker) -> void:
	if not valid(attacker) or attacker.is_building:
		return
	var pos: Vector2 = victim.aim_point()
	for u in units:
		if u.owner_id == victim.owner_id and u.is_military() and u.state == UnitScript.S.IDLE and u.position.distance_to(pos) < 160.0:
			u.cmd_attack(attacker)


## Rechtsklick-Logik, auch für Sammelpunkte und die KI.
func command_units(list: Array, pos: Vector2) -> void:
	if list.is_empty():
		return
	var pid: int = list[0].owner_id
	var c := to_cell(pos)
	var eu = unit_at(pos)
	if eu != null and eu.owner_id != pid:
		for u in list:
			u.cmd_attack(eu)
		return
	var b = occ.get(c)
	if b != null:
		if b.owner_id != pid:
			for u in list:
				u.cmd_attack(b)
			return
		for u in list:
			if u.kind != "villager":
				u.cmd_move(pos)
			elif not b.built or (b.hp < b.max_hp and b.kind != "farm"):
				u.cmd_build(b)
			elif b.kind == "farm":
				u.cmd_farm(b)
			elif u.carry > 0.0 and b.accepts(u.carry_type):
				u.cmd_return(b)
			else:
				u.cmd_move(pos)
		return
	if resources.has(c):
		for u in list:
			if u.kind == "villager":
				u.cmd_gather(c)
			else:
				u.cmd_move(pos)
		return
	var cells := formation_cells(pid, c, list.size())
	for i in list.size():
		var p := cell_center(cells[i]) if i > 0 or list.size() > 1 else pos
		list[i].cmd_move(p)


# ---------------------------------------------------------------- Eingabe

func _process(delta: float) -> void:
	if not running:
		return
	_camera_move(delta)
	if game_over:
		return
	game_time += delta
	check_t -= delta
	if check_t <= 0.0:
		check_t = 1.0
		_check_victory()
	if autotest:
		_autotest_tick(delta)
	if "--shot" in OS.get_cmdline_user_args() and game_time > 25.0 and stat_t > -100.0:
		stat_t = -1000.0
		get_viewport().get_texture().get_image().save_png("res://shot_game.png")
		get_tree().quit()


func _camera_move(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	var vp := get_viewport()
	var m := vp.get_mouse_position()
	var vs := vp.get_visible_rect().size
	if not autotest and DisplayServer.window_is_focused() and Rect2(Vector2.ZERO, vs).has_point(m):
		if m.x < 5:
			dir.x -= 1
		elif m.x > vs.x - 5:
			dir.x += 1
		if m.y < 5:
			dir.y -= 1
		elif m.y > vs.y - 5:
			dir.y += 1
	camera.position += dir * 750.0 * (delta / maxf(0.01, Engine.time_scale)) / camera.zoom.x
	camera.position = camera.position.clamp(Vector2.ZERO, Vector2(W * T, H * T + 60))


func _zoom(f: float) -> void:
	var z := clampf(camera.zoom.x * f, 1.5, 6.0)
	camera.zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:
	if not running or game_over:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var mpos := get_global_mouse_position()
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if place_kind != "":
					if Data.BUILDINGS[place_kind].get("wall", false):
						wall_start = ghost_cell
					else:
						_try_place_at(place_kind, ghost_cell)
						if not mb.shift_pressed:
							cancel_placement()
				else:
					dragging = true
					drag_start = mpos
			else:
				if place_kind != "" and wall_start.x >= 0:
					_place_wall_line(place_kind, wall_start, ghost_cell)
					wall_start = NONE
					if not mb.shift_pressed:
						cancel_placement()
				elif dragging:
					dragging = false
					_finish_selection(drag_start, mpos, mb.shift_pressed)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if place_kind != "":
				cancel_placement()
			else:
				_right_click(mpos)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			camera.position -= mm.relative / camera.zoom
		_update_ghost()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if place_kind != "":
					cancel_placement()
				else:
					select_list([])
			KEY_H:
				for b in buildings:
					if b.owner_id == 0 and b.kind == "town_center":
						select_list([b])
						camera.position = b.center()
						break
			KEY_PERIOD:
				_select_idle_villager()
			KEY_DELETE, KEY_BACKSPACE:
				for e in selected.duplicate():
					if valid(e) and e.owner_id == 0:
						if e.is_building:
							destroy_building(e)
						else:
							kill_unit(e)


func _update_ghost() -> void:
	if place_kind == "":
		return
	var size: int = Data.BUILDINGS[place_kind]["size"]
	var mp := get_global_mouse_position()
	ghost_cell = to_cell(mp - Vector2(size - 1, size - 1) * T * 0.5)


func own_selected_units() -> Array:
	var out := []
	for e in selected:
		if valid(e) and not e.is_building and e.owner_id == 0:
			out.append(e)
	return out


func _selected_villagers() -> Array:
	var out := []
	for u in own_selected_units():
		if u.kind == "villager":
			out.append(u)
	return out


func start_placement(kind: String) -> void:
	var p: Dictionary = players[0]
	if int(p["age"]) < int(Data.BUILDINGS[kind]["age"]):
		hud.message("Erst ab %s verfügbar" % Data.AGES[Data.BUILDINGS[kind]["age"]]["name"])
		return
	var cost := Data.building_cost(kind, p["faction"])
	if not can_afford(0, cost):
		hud.message(missing_text(0, cost))
		return
	place_kind = kind
	wall_start = NONE
	_update_ghost()
	if Data.BUILDINGS[kind].get("wall", false):
		hud.message("Ziehen, um eine Linie zu bauen. Shift: weiterbauen.")


func cancel_placement() -> void:
	place_kind = ""
	wall_start = NONE


func _try_place_at(kind: String, c: Vector2i) -> bool:
	var cost := Data.building_cost(kind, players[0]["faction"])
	if not can_place(kind, c):
		hud.message("Hier kann nicht gebaut werden")
		return false
	if not can_afford(0, cost):
		hud.message(missing_text(0, cost))
		return false
	pay(0, cost)
	var b = place_building(kind, c, 0, false)
	for v in _selected_villagers():
		v.cmd_build(b)
	return true


func _place_wall_line(kind: String, a: Vector2i, b: Vector2i) -> void:
	var cost := Data.building_cost(kind, players[0]["faction"])
	var placed := []
	for c in line_cells(a, b):
		if not can_place(kind, c):
			continue
		if not can_afford(0, cost):
			hud.message(missing_text(0, cost))
			break
		pay(0, cost)
		placed.append(place_building(kind, c, 0, false))
	if placed.is_empty():
		return
	var vills := _selected_villagers()
	for i in vills.size():
		vills[i].cmd_build(placed[mini(i, placed.size() - 1)])


func select_list(list: Array) -> void:
	for e in selected:
		if valid(e):
			e.selected = false
			e.queue_redraw()
	selected = []
	for e in list:
		if valid(e):
			e.selected = true
			e.queue_redraw()
			selected.append(e)
	hud.dirty = true


func _finish_selection(a: Vector2, b: Vector2, add: bool) -> void:
	var list: Array = selected.duplicate() if add else []
	var r := Rect2(a, b - a).abs()
	if r.size.length() < 5.0:
		var u = unit_at(b)
		if u != null:
			if add and list.has(u):
				list.erase(u)
			else:
				list.append(u)
		else:
			var bld = occ.get(to_cell(b))
			if bld != null:
				list = [bld]
	else:
		for u in units:
			if u.owner_id == 0 and r.has_point(u.aim_point()) and not list.has(u):
				list.append(u)
		# Gebäude nicht mit Einheiten mischen
		list = list.filter(func(e) -> bool: return not e.is_building)
	select_list(list)


func _right_click(pos: Vector2) -> void:
	var own := own_selected_units()
	if not own.is_empty():
		command_units(own, pos)
		spawn_fx("click", pos, Color(0.4, 1, 0.4))
		return
	for e in selected:
		if valid(e) and e.is_building and e.owner_id == 0 and e.info.has("trains"):
			e.has_rally = true
			e.rally = pos
			spawn_fx("click", pos, Color.WHITE)


func _select_idle_villager() -> void:
	var idle := []
	for u in units:
		if u.owner_id == 0 and u.kind == "villager" and u.state == UnitScript.S.IDLE:
			idle.append(u)
	if idle.is_empty():
		hud.message("Keine untätigen Arbeiter")
		return
	var idx: int = 0
	if selected.size() == 1 and idle.has(selected[0]):
		idx = (idle.find(selected[0]) + 1) % idle.size()
	select_list([idle[idx]])
	camera.position = idle[idx].position


func center_on(pos: Vector2) -> void:
	camera.position = pos


# ---------------------------------------------------------------- Spielende & Test

func _check_victory() -> void:
	for pid in players.size():
		var alive := false
		for b in buildings:
			if b.owner_id == pid and not b.info.get("wall", false):
				alive = true
				break
		if not alive:
			for u in units:
				if u.owner_id == pid:
					alive = true
					break
		if not alive:
			game_over = true
			hud.show_game_over(pid != 0)
			if autotest:
				print("SPIELENDE nach %ds: Spieler %d verliert" % [int(game_time), pid])
				_print_stats()
				get_tree().quit()
			return


func _autotest_tick(delta: float) -> void:
	stat_t -= delta
	if stat_t <= 0.0:
		stat_t = 60.0
		_print_stats()
	if game_time > 1500.0:
		print("Zeitlimit erreicht")
		get_tree().quit()


func _print_stats() -> void:
	for pid in players.size():
		var p: Dictionary = players[pid]
		var counts := {}
		for u in units:
			if u.owner_id == pid:
				counts[u.kind] = int(counts.get(u.kind, 0)) + 1
		var bc := {}
		for b in buildings:
			if b.owner_id == pid:
				bc[b.kind] = int(bc.get(b.kind, 0)) + 1
		var r: Dictionary = p["res"]
		print("[%4ds] P%d %s %s | N%d H%d G%d S%d | Pop %d/%d | %s | %s" % [int(game_time), pid, p["faction"], Data.AGES[p["age"]]["name"], int(r["food"]), int(r["wood"]), int(r["gold"]), int(r["stone"]), pop(pid), pop_cap(pid), str(counts), str(bc)])


## Entwickler-Test der Spielerbefehle: godot --path . -- --uitest
func _ui_test() -> void:
	await get_tree().create_timer(0.5).timeout
	players[0]["res"] = {"food": 5000.0, "wood": 5000.0, "gold": 5000.0, "stone": 5000.0}
	var vills := units.filter(func(u) -> bool: return u.owner_id == 0 and u.kind == "villager")
	var tc = buildings.filter(func(b) -> bool: return b.owner_id == 0)[0]
	select_list(vills)
	for kind in ["house", "barracks", "farm"]:
		for i in 200:
			var c: Vector2i = tc.cell + Vector2i(randi_range(-8, 8), randi_range(-8, 8))
			if can_place(kind, c):
				print(kind, " platziert: ", _try_place_at(kind, c))
				break
	_place_wall_line("palisade", tc.cell + Vector2i(-6, -6), tc.cell + Vector2i(6, -9))
	queue_train(tc, "villager")
	queue_train(tc, "villager")
	print("Aufstieg: ", queue_age_up(tc))
	await get_tree().create_timer(2.0).timeout
	camera.position = tc.center()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("res://shot_ui1.png")
	select_list([tc])
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("res://shot_ui2.png")
	Engine.time_scale = 10.0
	await get_tree().create_timer(90.0).timeout
	print("Alter: ", players[0]["age"], " Einheiten: ", unit_count(0), " Gebäude: ", buildings.filter(func(b) -> bool: return b.owner_id == 0 and b.built).size())
	var bar = buildings.filter(func(b) -> bool: return b.owner_id == 0 and b.kind == "barracks")
	if not bar.is_empty():
		for i in 4:
			queue_train(bar[0], "spear")
	Engine.time_scale = 1.0
	select_list(units.filter(func(u) -> bool: return u.owner_id == 0))
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("res://shot_ui3.png")
	get_tree().quit()
