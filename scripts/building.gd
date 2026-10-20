extends Node2D
## Gebäude: Bauplatz, Produktion, Zeitalter-Aufstieg, Türme schießen, Farmen liefern Nahrung.

var is_building := true
var world
var kind := ""
var faction := ""
var info: Dictionary = {}
var owner_id := 0
var cell := Vector2i.ZERO
var size := 1
var hp := 1.0
var max_hp := 1.0
var built := false
var progress := 0.0
var dead := false
var queue: Array = []
var queue_t := 0.0
var has_rally := false
var rally := Vector2.ZERO
var food_left := 0.0
var attack_t := 0.0
var selected := false
var tex: Texture2D
var fire_t := 0.0


func setup(w, k: String, pid: int, c: Vector2i, complete: bool) -> void:
	world = w
	kind = k
	owner_id = pid
	cell = c
	info = Data.BUILDINGS[k]
	size = info["size"]
	faction = w.players[pid]["faction"]
	max_hp = Data.building_hp(kind, w.players[pid]["techs"])
	tex = Art.building_tex(faction, kind, pid)
	# Ursprung unten links, damit die Y-Sortierung mit Einheiten passt
	position = Vector2(c.x * Data.TILE, (c.y + size) * Data.TILE)
	if info.get("walkable", false):
		z_index = -1
	if kind == "farm":
		food_left = Data.farm_food(w.players[pid]["techs"])
	if complete:
		built = true
		progress = 1.0
		hp = max_hp
	else:
		hp = maxf(1.0, max_hp * 0.05)


func rect() -> Rect2i:
	return Rect2i(cell, Vector2i(size, size))


func center() -> Vector2:
	return Vector2(cell) * Data.TILE + Vector2(size, size) * Data.TILE * 0.5


func aim_point() -> Vector2:
	return center()


func accepts(t: String) -> bool:
	return built and info.get("drop", []).has(t)


func display_name() -> String:
	return Data.building_name(kind, faction)


func work(delta: float) -> void:
	if not built:
		var inc: float = delta / float(info["time"])
		progress = minf(1.0, progress + inc)
		hp = minf(max_hp, hp + max_hp * inc)
		if progress >= 1.0:
			built = true
			world.on_building_complete(self)
	else:
		hp = minf(max_hp, hp + max_hp * delta / (float(info["time"]) * 3.0))
	queue_redraw()


func take_food(amt: float) -> float:
	var g := minf(amt, food_left)
	food_left -= g
	if food_left <= 0.0:
		world.destroy_building(self)
	return g


func take_damage(amount: float, attacker) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		world.destroy_building(self)
		return
	if attacker != null and world.is_enemy(owner_id, attacker.owner_id):
		world.notify_attacked(self)
	world.call_for_help(self, attacker)


func current_time() -> float:
	var item: String = queue[0]
	if item == "age_up":
		return Data.AGES[world.players[owner_id]["age"] + 1]["time"]
	if item.begins_with("tech:"):
		return Data.TECHS[item.substr(5)]["time"]
	return Data.UNITS[item]["time"]


func _process(delta: float) -> void:
	if dead or not world.running or world.game_over or not built:
		return
	if faction == "plants" and hp < max_hp:
		hp = minf(max_hp, hp + 2.0 * delta)
	if not queue.is_empty():
		_do_queue(delta)
	if info.has("attack"):
		_do_attack(delta)
	if hp < max_hp * 0.5:
		fire_t += delta
		queue_redraw()


func _do_queue(delta: float) -> void:
	var item: String = queue[0]
	var need := current_time()
	queue_t += delta
	if queue_t < need:
		return
	var is_unit := item != "age_up" and not item.begins_with("tech:")
	if is_unit and world.unit_count(owner_id) >= world.pop_cap(owner_id):
		queue_t = need  # wartet auf Häuser
		return
	queue_t = 0.0
	queue.pop_front()
	if item == "age_up":
		world.complete_age_up(owner_id)
	elif item.begins_with("tech:"):
		world.complete_research(owner_id, item.substr(5))
	else:
		var u = world.spawn_unit(item, owner_id, world.spawn_point(self))
		if has_rally:
			world.command_units([u], rally)
		if owner_id == world.human:
			world.play_sound("train", center())


func _do_attack(delta: float) -> void:
	attack_t -= delta
	if attack_t > 0.0:
		return
	var a: Dictionary = info["attack"]
	var e = world.nearest_enemy_unit(owner_id, center(), float(a["range"]) * Data.TILE)
	if e == null:
		attack_t = 0.3
		return
	attack_t = a["cd"]
	var atk: float = float(a["atk"]) + world.players[owner_id]["age"]
	if world.players[owner_id]["techs"].has("tower_arrows"):
		atk += 3.0
	world.spawn_projectile(self, e, world.calc_damage("tower", atk, e), false)


func _draw() -> void:
	var s := size * Data.TILE
	var top := Vector2(0, -s)
	var tex_top := Vector2(0, -tex.get_height())
	if not info.get("walkable", false) and not info.get("wall", false):
		draw_set_transform(Vector2(s * 0.55, -s * 0.12), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, s * 0.55, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if built:
		draw_texture(tex, tex_top)
	else:
		draw_texture(tex, tex_top, Color(1, 1, 1, 0.45))
		# Baugerüst
		for i in range(0, s + 1, 12):
			draw_line(top + Vector2(i, 0), top + Vector2(i, s), Color(0.55, 0.4, 0.2, 0.8), 2.0)
		draw_rect(Rect2(tex_top + Vector2(2, -6), Vector2(s - 4, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(tex_top + Vector2(2, -6), Vector2((s - 4) * progress, 3)), Color("f0d040"))
	if built and hp < max_hp * 0.5:
		var seed_i := get_instance_id()
		for i in 3:
			var fx := float((seed_i / (i + 1)) % maxi(1, s - 6)) + 3.0
			var fy := -s * 0.5 + float((seed_i / (i + 7)) % maxi(1, s / 2))
			var flick := 1.0 + sin(fire_t * 12.0 + i) * 0.8
			draw_rect(Rect2(Vector2(fx, fy - flick * 2), Vector2(4, 4 + flick * 2)), Color("ff8020"))
			draw_rect(Rect2(Vector2(fx + 1, fy - flick * 2 - 2), Vector2(2, 2)), Color("ffe060"))
	if selected:
		draw_rect(Rect2(top, Vector2(s, s)), Color(1, 1, 1, 0.85), false, 2.0)
	if selected or (hp < max_hp and built):
		draw_rect(Rect2(tex_top + Vector2(2, -11), Vector2(s - 4, 3)), Color(0.2, 0, 0))
		draw_rect(Rect2(tex_top + Vector2(2, -11), Vector2((s - 4) * hp / max_hp, 3)), Color(0.2, 0.9, 0.2) if owner_id == world.human else Color(0.95, 0.3, 0.2))
