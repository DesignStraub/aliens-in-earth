extends Node2D
## Die Spielwelt: Karte, Wegfindung, Wirtschaft, Nebel des Krieges, Speichern, Auswahl und Eingabe.

const MapGen = preload("res://scripts/map_gen.gd")
const UnitScript = preload("res://scripts/unit.gd")
const BuildingScript = preload("res://scripts/building.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const FxScript = preload("res://scripts/fx.gd")
const ResLayerScript = preload("res://scripts/res_layer.gd")
const OverlayScript = preload("res://scripts/overlay.gd")
const FogScript = preload("res://scripts/fog.gd")
const AIScript = preload("res://scripts/ai.gd")
const HudScript = preload("res://scripts/hud.gd")

const T := 16
const WATER := 1
const NONE := Vector2i(-1, -1)
const DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const SAVE_PATH := "user://spielstand.save"

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
var config: Dictionary = {}
## Index des menschlichen Spielers, -1 = nur Zuschauen (Autotest)
var human := 0

var res_layer
var entities: Node2D
var fx_layer: Node2D
var overlay
var fog
var camera: Camera2D
var hud
var ais: Array = []

var fog_enabled := true
var explored := PackedByteArray()
var vis := PackedByteArray()
var fog_t := 0.0
var alarm_t := -100.0
var alarm_pos := Vector2.ZERO

var selected: Array = []
var place_kind := ""
var ghost_cell := Vector2i.ZERO
var dragging := false
var drag_start := Vector2.ZERO
var wall_start := NONE
var check_t := 0.0
var minimap_dirty := true
var stat_t := 0.0
var _cursor_key := ""


func _ready() -> void:
	randomize()
	if "--cover" in OS.get_cmdline_user_args():
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_window().content_scale_factor = 1.0
		get_window().size = Vector2i(1260, 1000)
		add_child(preload("res://scripts/cover.gd").new())
		return
	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	add_child(camera)
	hud = HudScript.new()
	hud.world = self
	add_child(hud)
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args or "--autotest4" in args:
		autotest = true
		Engine.time_scale = 8.0
		var opp := []
		for i in (3 if "--autotest4" in args else 1):
			opp.append(Data.FACTIONS.keys()[randi() % 3])
		start_game({"faction": "mammals", "opponents": opp, "teams": "ffa", "map_size": 0 if opp.size() == 1 else 1, "fog": false, "difficulty": 1, "spectate": true})
	elif "--uitest" in args:
		start_game({"faction": "plants", "opponents": ["aliens"], "teams": "ffa", "map_size": 0, "fog": true, "difficulty": 1})
		_ui_test()
	elif "--colltest" in args:
		start_game({"faction": "aliens", "opponents": ["plants"], "teams": "ffa", "map_size": 0, "fog": false, "difficulty": 1})
		var tc = buildings[0]
		var spot: Vector2 = tc.center() + Vector2(0, 70)
		var group := []
		for i in 10:
			group.append(spawn_unit(["spear", "archer", "cavalry", "villager"][i % 4], 0, spot))
		camera.position = spot
		camera.zoom = Vector2(6, 6)
		await get_tree().create_timer(2.0).timeout
		var md := 1e9
		for a in group:
			for b in group:
				if a != b:
					md = minf(md, a.position.distance_to(b.position))
		print("Kleinster Abstand nach 2s: %.1f px" % md)
		get_viewport().get_texture().get_image().save_png("res://shot_coll.png")
		var sheet := Image.create_empty(48 * 7, 48, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("4e8e32"))
		var i := 0
		for m in ["arrow", "attack", "axe", "pick", "basket", "hoe", "hammer"]:
			sheet.blend_rect(Art.cursor_image(m, "aliens", 3), Rect2i(0, 0, 48, 48), Vector2i(i * 48, 0))
			i += 1
		sheet.save_png("res://shot_cursors.png")
		get_tree().quit()
	elif "--loadtest" in args:
		_load_save(read_save())
		await get_tree().create_timer(3.0).timeout
		print("Geladen: Einheiten ", units.size(), " Gebäude ", buildings.size(), " Zeit ", int(game_time), " Techs ", players[0]["techs"].keys())
		get_viewport().get_texture().get_image().save_png("res://shot_load.png")
		get_tree().quit()
	elif not Data.pending.is_empty():
		var pend: Dictionary = Data.pending
		Data.pending = {}
		if pend.has("save"):
			_load_save(pend["save"])
		else:
			start_game(pend["config"])
	else:
		hud.show_title()
		if "--menushot" in args:
			for step in ["title", "setup", "settings"]:
				if step == "setup":
					hud.show_setup()
				elif step == "settings":
					hud.show_settings(hud.show_title)
				await get_tree().create_timer(1.5).timeout
				get_viewport().get_texture().get_image().save_png("res://shot_%s.png" % step)
			get_tree().quit()


# ---------------------------------------------------------------- Spielaufbau

## cfg: faction, opponents[], teams ("ffa" | "all_vs_you"), map_size, fog, difficulty
func start_game(cfg: Dictionary) -> void:
	config = cfg
	seed_val = randi()
	var size: int = Data.MAP_SIZES[int(cfg.get("map_size", 0))]["size"]
	var facs: Array = [cfg["faction"]]
	facs.append_array(cfg["opponents"])
	human = -1 if cfg.get("spectate", false) else 0
	var g: Dictionary = MapGen.generate(size, size, seed_val, facs.size())
	var diff: Dictionary = Data.DIFFICULTY[int(cfg.get("difficulty", 1))]
	var pl := []
	for i in facs.size():
		var team := i
		if cfg.get("teams", "ffa") == "all_vs_you":
			team = 0 if i == 0 else 1
		var ai := i != human
		pl.append({"id": i, "faction": facs[i], "res": Data.START_RES.duplicate(), "age": 0, "aging": false, "ai": ai, "team": team, "techs": {}, "researching": {}, "gather_mult": float(diff["gather"]) if ai else 1.0, "alive": true})
	_build_world(size, size, g["terrain"], g["res"], pl, bool(cfg.get("fog", true)) and human >= 0)
	var starts: Array = g["starts"]
	for i in facs.size():
		var s: Vector2i = starts[i]
		place_building("town_center", s - Vector2i(1, 1), i, true)
		for k in 3:
			spawn_unit("villager", i, cell_center(s + Vector2i(-2 + k * 2, 3)))
		spawn_unit("spear", i, cell_center(s + Vector2i(3, -2)))
	_spawn_ais({})
	camera.position = cell_center(starts[maxi(human, 0)])
	_update_fog()
	running = true
	hud.on_game_started()


func _build_world(w: int, h: int, terr: PackedByteArray, res: Dictionary, pl: Array, fog_on: bool) -> void:
	W = w
	H = h
	terrain = terr
	resources = res
	players = pl
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
	fog_enabled = fog_on
	explored.resize(W * H)
	vis.resize(W * H)
	explored.fill(0 if fog_on else 1)
	vis.fill(0 if fog_on else 1)
	if fog_on:
		fog = FogScript.new()
		fog.world = self
		add_child(fog)
		fog.setup()
	overlay = OverlayScript.new()
	overlay.world = self
	overlay.z_index = 11
	add_child(overlay)
	_setup_astar()


func _spawn_ais(saved: Dictionary) -> void:
	var diff: Dictionary = Data.DIFFICULTY[int(config.get("difficulty", 1))]
	for i in players.size():
		if players[i]["ai"] and players[i]["alive"]:
			var ai = AIScript.new()
			ai.world = self
			ai.pid = i
			ai.think_interval = diff["think"]
			ai.next_attack = saved.get(i, float(diff["attack"]) + randf_range(-30, 30))
			add_child(ai)
			ais.append(ai)


func player_name(pid: int) -> String:
	if pid == human:
		return "Du"
	return "%s (Spieler %d)" % [Data.FACTIONS[players[pid]["faction"]]["name"], pid + 1]


func is_enemy(a: int, b: int) -> bool:
	return a != b and players[a]["team"] != players[b]["team"]


func _same_team_as_human(pid: int) -> bool:
	return human >= 0 and players[pid]["team"] == players[human]["team"]


# ---------------------------------------------------------------- Nebel des Krieges

func cell_visible(c: Vector2i) -> bool:
	if not fog_enabled:
		return true
	return in_bounds(c) and vis[c.y * W + c.x] == 1


func cell_explored(c: Vector2i) -> bool:
	if not fog_enabled:
		return true
	return in_bounds(c) and explored[c.y * W + c.x] == 1


func is_pos_visible(pos: Vector2) -> bool:
	return cell_visible(to_cell(pos))


func _reveal(c: Vector2i, r: int) -> void:
	for dy in range(-r, r + 1):
		var y := c.y + dy
		if y < 0 or y >= H:
			continue
		for dx in range(-r, r + 1):
			var x := c.x + dx
			if x >= 0 and x < W and dx * dx + dy * dy <= r * r:
				vis[y * W + x] = 1


func _update_fog() -> void:
	if not fog_enabled:
		return
	vis.fill(0)
	for u in units:
		if _same_team_as_human(u.owner_id):
			_reveal(u.cell(), int(u.stats["sight"]))
	for b in buildings:
		if _same_team_as_human(b.owner_id):
			_reveal(b.cell + Vector2i(b.size / 2, b.size / 2), b.size + (6 if b.built else 1))
	for i in vis.size():
		if vis[i] == 1:
			explored[i] = 1
	for u in units:
		if not _same_team_as_human(u.owner_id):
			u.visible = cell_visible(u.cell())
	for b in buildings:
		if not _same_team_as_human(b.owner_id):
			b.visible = cell_explored(b.cell) or cell_explored(b.cell + Vector2i(b.size - 1, b.size - 1))
	fog.refresh()


func play_sound(sound: String, pos: Vector2, vol_db := 0.0) -> void:
	if is_pos_visible(pos):
		Sfx.play(sound, pos, vol_db)


func notify_attacked(e) -> void:
	if e.owner_id != human or game_time - alarm_t < 12.0:
		return
	alarm_t = game_time
	alarm_pos = e.aim_point()
	hud.message("Ihr werdet angegriffen!")
	Sfx.play("alarm")


# ---------------------------------------------------------------- Forschung

func tech_available(pid: int, tid: String) -> bool:
	var t: Dictionary = Data.TECHS[tid]
	var p: Dictionary = players[pid]
	if p["techs"].has(tid) or p["researching"].has(tid) or int(p["age"]) < int(t["age"]):
		return false
	return not t.has("req") or p["techs"].has(t["req"])


func queue_research(b, tid: String) -> bool:
	var pid: int = b.owner_id
	if not tech_available(pid, tid) or b.queue.size() >= 8:
		return false
	var cost: Dictionary = Data.TECHS[tid]["cost"]
	if not can_afford(pid, cost):
		_msg(pid, missing_text(pid, cost))
		return false
	pay(pid, cost)
	players[pid]["researching"][tid] = true
	b.queue.append("tech:" + tid)
	return true


func complete_research(pid: int, tid: String) -> void:
	var p: Dictionary = players[pid]
	p["researching"].erase(tid)
	p["techs"][tid] = true
	for u in units:
		if u.owner_id == pid:
			u.refresh_stats()
	if tid == "masonry":
		for b in buildings:
			if b.owner_id == pid:
				var ratio: float = b.hp / b.max_hp
				b.max_hp = Data.building_hp(b.kind, p["techs"])
				b.hp = b.max_hp * ratio
	if pid == human:
		hud.message("Erforscht: %s" % Data.TECHS[tid]["name"])
		Sfx.play("research")
	hud.dirty = true


# ---------------------------------------------------------------- Speichern & Laden

func save_game() -> bool:
	var bl := []
	for b in buildings:
		bl.append({"kind": b.kind, "owner": b.owner_id, "cell": b.cell, "hp": b.hp, "max_hp": b.max_hp, "built": b.built, "progress": b.progress, "queue": b.queue.duplicate(), "queue_t": b.queue_t, "food": b.food_left, "has_rally": b.has_rally, "rally": b.rally})
	var ul := []
	for u in units:
		ul.append({"kind": u.kind, "owner": u.owner_id, "pos": u.position, "hp": u.hp, "carry": u.carry, "carry_type": u.carry_type, "gather_cell": u.gather_cell, "gather_kind": u.gather_kind,
			"farm": buildings.find(u.farm) if valid(u.farm) else -1,
			"build": buildings.find(u.target) if u.state == UnitScript.S.BUILD and valid(u.target) else -1})
	var ai_state := {}
	for ai in ais:
		ai_state[ai.pid] = ai.next_attack
	var data := {"version": 1, "config": config, "seed": seed_val, "human": human, "W": W, "H": H, "terrain": terrain, "resources": resources, "players": players,
		"fog": fog_enabled, "explored": explored, "game_time": game_time, "camera": camera.position, "buildings": bl, "units": ul, "ai": ai_state}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(data)
	f.close()
	hud.message("Spiel gespeichert")
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	f.close()
	return d if d is Dictionary else {}


func _load_save(d: Dictionary) -> void:
	config = d["config"]
	seed_val = d["seed"]
	human = d["human"]
	_build_world(d["W"], d["H"], d["terrain"], d["resources"], d["players"], d["fog"])
	explored = d["explored"]
	game_time = d["game_time"]
	var bl := []
	for bd in d["buildings"]:
		var b = place_building(bd["kind"], bd["cell"], bd["owner"], bd["built"])
		b.max_hp = bd["max_hp"]
		b.hp = bd["hp"]
		b.progress = bd["progress"]
		b.queue = bd["queue"]
		b.queue_t = bd["queue_t"]
		b.food_left = bd["food"]
		b.has_rally = bd["has_rally"]
		b.rally = bd["rally"]
		bl.append(b)
	for ud in d["units"]:
		var u = spawn_unit(ud["kind"], ud["owner"], ud["pos"])
		u.hp = ud["hp"]
		if int(ud["farm"]) >= 0:
			u.cmd_farm(bl[ud["farm"]])
		elif int(ud["build"]) >= 0:
			u.cmd_build(bl[ud["build"]])
		elif ud["gather_kind"] != "" and resources.has(ud["gather_cell"]):
			u.cmd_gather(ud["gather_cell"])
		u.carry = ud["carry"]
		u.carry_type = ud["carry_type"]
	_spawn_ais(d["ai"])
	camera.position = d["camera"]
	_update_fog()
	running = true
	hud.on_game_started()
	hud.message("Spielstand geladen")


func request_load() -> void:
	var d := read_save()
	if d.is_empty():
		hud.message("Kein Spielstand vorhanden")
		return
	Data.pending = {"save": d}
	get_tree().paused = false
	get_tree().reload_current_scene()


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
	astars = []
	for i in players.size():
		astars.append(_make_astar())
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
		if b != null and is_enemy(pid, b.owner_id) and _building_blocks(pid, c):
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
		if not u.visible:
			continue
		var d: float = u.aim_point().distance_to(pos)
		if d < bd:
			bd = d
			best = u
	return best


func nearest_enemy_unit(pid: int, pos: Vector2, radius: float):
	var best = null
	var bd := radius
	for u in units:
		if not is_enemy(pid, u.owner_id):
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
		if not is_enemy(pid, b.owner_id) or (not walls and b.info.get("wall", false)):
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
		if is_enemy(pid, b.owner_id) and b.info.has("attack"):
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
	if pid == human:
		hud.message(text)
		Sfx.play("error")


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
	elif item.begins_with("tech:"):
		var tid := item.substr(5)
		refund(b.owner_id, Data.TECHS[tid]["cost"])
		p["researching"].erase(tid)
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
	if pid == human:
		hud.message("Ihr habt die %s erreicht! Eure Einheiten werden stärker." % name)
		Sfx.play("ageup")
	elif human >= 0:
		hud.message("%s hat die %s erreicht." % [player_name(pid), name])
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
	if b.owner_id == human and not b.info.get("wall", false):
		hud.message("%s fertiggestellt" % b.display_name())
		play_sound("complete", b.center())


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
		play_sound("collapse", b.center())
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
	play_sound("death", u.position, -4.0)
	u.queue_free()
	hud.dirty = true


func spawn_fx(kind: String, pos: Vector2, color: Color, only_visible := false) -> void:
	if only_visible and not (Sfx.view_rect.has_point(pos) and is_pos_visible(pos)):
		return
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
	if eu != null and is_enemy(pid, eu.owner_id):
		for u in list:
			u.cmd_attack(eu)
		return
	var b = occ.get(c)
	if b != null:
		if is_enemy(pid, b.owner_id):
			for u in list:
				u.cmd_attack(b)
			return
		if b.owner_id != pid:
			for i in list.size():
				list[i].cmd_move(pos)
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
	if not autotest:
		_update_cursor()
	if not running:
		return
	_camera_move(delta)
	var vs: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	Sfx.view_rect = Rect2(camera.position - vs / 2.0, vs).grow(48.0)
	if game_over:
		return
	game_time += delta
	fog_t -= delta
	if fog_t <= 0.0:
		fog_t = 0.25
		_update_fog()
	_separate_units(delta)
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


# ---------------------------------------------------------------- Kollision

## Weiche Kollision: Einheiten dürfen sich berühren, aber nicht ineinander stehen.
## Wer läuft, drückt Stehende stärker beiseite.
func _separate_units(delta: float) -> void:
	var grid := {}
	for u in units:
		var k := to_cell(u.position)
		if grid.has(k):
			grid[k].append(u)
		else:
			grid[k] = [u]
	var max_step := 45.0 * delta
	for u in units:
		if u.is_anchored():
			continue  # Arbeitende bleiben am Baum/Busch/Bauplatz verankert
		var c := to_cell(u.position)
		var push := Vector2.ZERO
		var u_moving: bool = not u.path.is_empty()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var bucket = grid.get(c + Vector2i(dx, dy))
				if bucket == null:
					continue
				for o in bucket:
					if o == u:
						continue
					var d: Vector2 = u.position - o.position
					var min_d: float = u.radius + o.radius
					var l2 := d.length_squared()
					if l2 >= min_d * min_d:
						continue
					var l := sqrt(l2)
					if l < 0.01:
						# exakt übereinander: deterministisch auseinanderschieben
						d = Vector2(1, 0).rotated(float(u.get_instance_id() % 628) / 100.0)
						l = 1.0
					var o_moving: bool = not o.path.is_empty()
					var share := 0.5
					if o.is_anchored():
						share = 1.0
					elif u_moving and not o_moving:
						share = 0.15
					elif o_moving and not u_moving:
						share = 0.85
					push += d / l * (min_d - l) * share
		if push == Vector2.ZERO:
			continue
		var np: Vector2 = u.position + push.limit_length(max_step)
		var nc := to_cell(np)
		if nc == c or not is_solid_for(u.owner_id, nc):
			u.position = np


# ---------------------------------------------------------------- Mauszeiger

func _cursor_mode() -> String:
	if not running or game_over or human < 0 or place_kind != "" or get_viewport().gui_get_hovered_control() != null:
		return "arrow"
	var own := own_selected_units()
	if own.is_empty():
		return "arrow"
	var pos := get_global_mouse_position()
	var c := to_cell(pos)
	var eu = unit_at(pos)
	if eu != null and is_enemy(human, eu.owner_id):
		return "attack"
	var b = occ.get(c)
	if b != null and b.visible and is_enemy(human, b.owner_id):
		return "attack"
	var has_vill := false
	for u in own:
		if u.kind == "villager":
			has_vill = true
			break
	if not has_vill:
		return "arrow"
	if b != null and b.owner_id == human:
		if b.kind == "farm" and b.built:
			return "hoe"
		if not b.built or b.hp < b.max_hp:
			return "hammer"
	if resources.has(c) and cell_explored(c):
		return {"tree": "axe", "gold": "pick", "stone": "pick", "berry": "basket"}[resources[c]["kind"]]
	return "arrow"


func reset_cursor() -> void:
	_cursor_key = ""
	var scale := clampi(roundi(get_window().size.y / 900.0 * Settings.ui_scale * 1.25), 1, 5)
	Input.set_custom_mouse_cursor(Art.cursor_image("arrow", "mammals", scale), Input.CURSOR_ARROW, Vector2.ZERO)


func _update_cursor() -> void:
	var mode := _cursor_mode()
	var scale := clampi(roundi(get_window().size.y / 900.0 * Settings.ui_scale * 1.25), 1, 5)
	var fac: String = players[human]["faction"] if human >= 0 and not players.is_empty() else "mammals"
	var key := "%s_%d_%s" % [mode, scale, fac]
	if key == _cursor_key:
		return
	_cursor_key = key
	Input.set_custom_mouse_cursor(Art.cursor_image(mode, fac, scale), Input.CURSOR_ARROW, Vector2.ZERO)


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
	if Settings.edge_scroll and not autotest and DisplayServer.window_is_focused() and Rect2(Vector2.ZERO, vs).has_point(m):
		if m.x < 5:
			dir.x -= 1
		elif m.x > vs.x - 5:
			dir.x += 1
		if m.y < 5:
			dir.y -= 1
		elif m.y > vs.y - 5:
			dir.y += 1
	camera.position += dir * 750.0 * Settings.cam_speed * (delta / maxf(0.01, Engine.time_scale)) / camera.zoom.x
	camera.position = camera.position.clamp(Vector2.ZERO, Vector2(W * T, H * T + 60))


func _zoom(f: float) -> void:
	var z := clampf(camera.zoom.x * f, 1.5, 7.0)
	camera.zoom = Vector2(z, z)


func _unhandled_input(event: InputEvent) -> void:
	if not running or game_over or human < 0:
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
				elif not selected.is_empty():
					select_list([])
				else:
					hud.toggle_pause_menu()
			KEY_F10:
				hud.toggle_pause_menu()
			KEY_F5:
				save_game()
			KEY_H:
				for b in buildings:
					if b.owner_id == human and b.kind == "town_center":
						select_list([b])
						camera.position = b.center()
						break
			KEY_PERIOD:
				_select_idle_villager()
			KEY_DELETE, KEY_BACKSPACE:
				for e in selected.duplicate():
					if valid(e) and e.owner_id == human:
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
		if valid(e) and not e.is_building and e.owner_id == human:
			out.append(e)
	return out


func _selected_villagers() -> Array:
	var out := []
	for u in own_selected_units():
		if u.kind == "villager":
			out.append(u)
	return out


func start_placement(kind: String) -> void:
	var p: Dictionary = players[human]
	if int(p["age"]) < int(Data.BUILDINGS[kind]["age"]):
		_msg(human, "Erst ab %s verfügbar" % Data.AGES[Data.BUILDINGS[kind]["age"]]["name"])
		return
	var cost := Data.building_cost(kind, p["faction"])
	if not can_afford(human, cost):
		_msg(human, missing_text(human, cost))
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
	var cost := Data.building_cost(kind, players[human]["faction"])
	if not can_place(kind, c):
		_msg(human, "Hier kann nicht gebaut werden")
		return false
	if not can_afford(human, cost):
		_msg(human, missing_text(human, cost))
		return false
	pay(human, cost)
	var b = place_building(kind, c, human, false)
	for v in _selected_villagers():
		v.cmd_build(b)
	Sfx.play("build")
	return true


func _place_wall_line(kind: String, a: Vector2i, b: Vector2i) -> void:
	var cost := Data.building_cost(kind, players[human]["faction"])
	var placed := []
	for c in line_cells(a, b):
		if not can_place(kind, c):
			continue
		if not can_afford(human, cost):
			_msg(human, missing_text(human, cost))
			break
		pay(human, cost)
		placed.append(place_building(kind, c, human, false))
	if placed.is_empty():
		return
	Sfx.play("build")
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
			if bld != null and bld.visible:
				list = [bld]
	else:
		for u in units:
			if u.owner_id == human and r.has_point(u.aim_point()) and not list.has(u):
				list.append(u)
		# Gebäude nicht mit Einheiten mischen
		list = list.filter(func(e) -> bool: return not e.is_building)
	select_list(list)
	if not list.is_empty() and list[0].owner_id == human:
		Sfx.play("select")


func _right_click(pos: Vector2) -> void:
	var own := own_selected_units()
	if not own.is_empty():
		command_units(own, pos)
		spawn_fx("click", pos, Color(0.4, 1, 0.4))
		Sfx.play("ack_" + players[human]["faction"])
		return
	for e in selected:
		if valid(e) and e.is_building and e.owner_id == human and e.info.has("trains"):
			e.has_rally = true
			e.rally = pos
			spawn_fx("click", pos, Color.WHITE)


func _select_idle_villager() -> void:
	var idle := []
	for u in units:
		if u.owner_id == human and u.kind == "villager" and u.state == UnitScript.S.IDLE:
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


# ---------------------------------------------------------------- Spielende & Tests

func _player_alive(pid: int) -> bool:
	for b in buildings:
		if b.owner_id == pid and not b.info.get("wall", false):
			return true
	for u in units:
		if u.owner_id == pid:
			return true
	return false


func _check_victory() -> void:
	var teams := {}
	for pid in players.size():
		var p: Dictionary = players[pid]
		if p["alive"] and not _player_alive(pid):
			p["alive"] = false
			for b in buildings.duplicate():
				if b.owner_id == pid:
					destroy_building(b)
			if pid != human and human >= 0:
				hud.message("%s wurde besiegt!" % player_name(pid))
			if autotest:
				print("[%4ds] Spieler %d besiegt" % [int(game_time), pid])
		if p["alive"]:
			teams[p["team"]] = true
	if human >= 0:
		if not players[human]["alive"]:
			_end(false)
		elif teams.size() <= 1:
			_end(true)
	elif teams.size() <= 1:
		_end(true)


func _end(win: bool) -> void:
	game_over = true
	hud.show_game_over(win)
	Sfx.play("ageup" if win else "death")
	if autotest:
		print("SPIELENDE nach %ds" % int(game_time))
		_print_stats()
		get_tree().quit()


func _autotest_tick(delta: float) -> void:
	stat_t -= delta
	if stat_t <= 0.0:
		stat_t = 60.0
		_print_stats()
	if game_time > 1800.0:
		print("Zeitlimit erreicht")
		get_tree().quit()


func _print_stats() -> void:
	for pid in players.size():
		var p: Dictionary = players[pid]
		var counts := {}
		for u in units:
			if u.owner_id == pid:
				counts[u.kind] = int(counts.get(u.kind, 0)) + 1
		var st := {}
		for u in units:
			if u.owner_id == pid and u.kind == "villager":
				var key: String = "%s/%s" % [UnitScript.S.keys()[u.state], u.gather_kind]
				st[key] = int(st.get(key, 0)) + 1
		if OS.get_cmdline_user_args().has("--debug"):
			print("      Arbeiter P%d: %s" % [pid, str(st)])
		var r: Dictionary = p["res"]
		print("[%4ds] P%d %s %s | N%d H%d G%d S%d | Pop %d/%d | %s | Tech %d" % [int(game_time), pid, p["faction"], Data.AGES[p["age"]]["name"], int(r["food"]), int(r["wood"]), int(r["gold"]), int(r["stone"]), pop(pid), pop_cap(pid), str(counts), p["techs"].size()])


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
	print("Forschung Zähe Kittel: ", queue_research(tc, "loom"))
	print("Aufstieg: ", queue_age_up(tc))
	# zwei Arbeiter zum Holz, einer zu Gold
	var wood := find_resource_near("tree", tc.cell, 20)
	var gold := find_resource_near("gold", tc.cell, 20)
	await get_tree().create_timer(4.0).timeout
	vills = units.filter(func(u) -> bool: return u.owner_id == 0 and u.kind == "villager")
	if wood.x >= 0:
		vills[0].cmd_gather(wood)
		vills[1].cmd_gather(wood)
	if gold.x >= 0:
		vills[2].cmd_gather(gold)
	camera.position = tc.center()
	await get_tree().create_timer(6.0).timeout
	get_viewport().get_texture().get_image().save_png("res://shot_ui1.png")
	select_list([tc])
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("res://shot_ui2.png")
	print("Speichern: ", save_game())
	Engine.time_scale = 10.0
	await get_tree().create_timer(80.0).timeout
	print("Alter: ", players[0]["age"], " Techs: ", players[0]["techs"].keys(), " Einheiten: ", unit_count(0))
	Engine.time_scale = 1.0
	if wood.x >= 0:
		camera.position = cell_center(wood)
	select_list(units.filter(func(u) -> bool: return u.owner_id == 0))
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("res://shot_ui3.png")
	get_tree().quit()
