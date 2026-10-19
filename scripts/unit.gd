extends Node2D
## Eine Einheit: Bewegen, Sammeln, Abliefern, Bauen/Reparieren, Kämpfen – mit Animationen.

enum S { IDLE, MOVE, GATHER, RETURN, BUILD, ATTACK }

const NONE := Vector2i(-1, -1)
const HAND := Vector2(4, -7)
const TOOL_FOR := {"tree": "axe", "gold": "pick", "stone": "pick", "berry": "basket", "farm": "hoe"}
const WORK_FX := {
	"axe": ["chop", "chips", Color("b08050")],
	"pick": ["mine", "sparks", Color("fff0a0")],
	"hoe": ["farm", "dust", Color("8a6a40")],
	"basket": ["gather", "leaves", Color("d03060")],
	"hammer": ["build", "dust", Color("c8b890")],
}

var is_building := false
var world
var kind := ""
var faction := ""
var owner_id := 0
var stats: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var dead := false
var state: int = S.IDLE
var path: Array = []
var move_goal := Vector2.ZERO
var target = null
var saved_target = null
var gather_cell := NONE
var gather_kind := ""
var farm = null
var task_type := ""
var carry_type := ""
var carry := 0.0
var attack_t := 0.0
var repath_t := 0.0
var scan_t := 0.0
var fails := 0
var selected := false
var frames: Array = []
var tex: Texture2D
var flip := false
var anim_t := 0.0
var hit_flash := 0.0
var working := false
var work_phase := 0.0
var lunge := Vector2.ZERO


func setup(w, k: String, pid: int, pos: Vector2) -> void:
	world = w
	kind = k
	owner_id = pid
	position = pos
	faction = w.players[pid]["faction"]
	frames = Art.unit_frames(faction, kind, pid)
	tex = frames[0]
	refresh_stats(true)
	scan_t = randf() * 0.5
	anim_t = randf() * 3.0
	work_phase = randf()


func refresh_stats(full := false) -> void:
	var ratio := 1.0 if full else hp / max_hp
	var p: Dictionary = world.players[owner_id]
	stats = Data.unit_stats(kind, faction, p["age"], p["techs"])
	max_hp = stats["hp"]
	hp = max_hp * ratio


func display_name() -> String:
	return Data.unit_name(kind, faction, world.players[owner_id]["age"])


func cell() -> Vector2i:
	return world.to_cell(position)


func aim_point() -> Vector2:
	return position + Vector2(0, -5)


func is_military() -> bool:
	return kind != "villager"


func reach() -> float:
	var r: float = stats["range"]
	return r * 16.0 if r > 0.0 else 11.0


func carry_cap() -> float:
	return Data.carry_cap(world.players[owner_id]["techs"])


func _rate(res_kind: String) -> float:
	var p: Dictionary = world.players[owner_id]
	return Data.gather_rate(faction, res_kind, p["techs"]) * float(p["gather_mult"])


# ---------------------------------------------------------------- Befehle

func _reset() -> void:
	path = []
	target = null
	saved_target = null
	farm = null
	fails = 0


func cmd_move(pos: Vector2) -> void:
	_reset()
	state = S.MOVE
	move_goal = pos
	var c: Vector2i = world.to_cell(pos)
	path = world.find_path(owner_id, cell(), c, true)
	if not path.is_empty() and world.to_cell(path.back()) == c:
		path[-1] = pos


func cmd_attack(t) -> void:
	if not world.valid(t) or not world.is_enemy(owner_id, t.owner_id):
		return
	_reset()
	target = t
	state = S.ATTACK
	repath_t = 0.0


func cmd_gather(c: Vector2i) -> void:
	if kind != "villager" or not world.resources.has(c):
		return
	_reset()
	var r: Dictionary = world.resources[c]
	gather_cell = c
	gather_kind = r["kind"]
	task_type = r["type"]
	state = S.GATHER


func cmd_farm(b) -> void:
	if kind != "villager":
		return
	_reset()
	farm = b
	gather_kind = "farm"
	task_type = "food"
	state = S.GATHER


func cmd_build(b) -> void:
	if kind != "villager":
		return
	_reset()
	target = b
	state = S.BUILD


func cmd_return(b = null) -> void:
	path = []
	target = b
	state = S.RETURN


# ---------------------------------------------------------------- Ablauf

func _process(delta: float) -> void:
	if dead or not world.running or world.game_over:
		return
	attack_t = maxf(0.0, attack_t - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	lunge = lunge.move_toward(Vector2.ZERO, 20.0 * delta)
	anim_t += delta
	working = false
	match state:
		S.IDLE:
			_idle(delta)
		S.MOVE:
			if _follow(delta):
				state = S.IDLE
		S.GATHER:
			_gather(delta)
		S.RETURN:
			_return(delta)
		S.BUILD:
			_build(delta)
		S.ATTACK:
			_attack(delta)
	if working:
		_animate_work(delta)
	if visible:
		queue_redraw()


func _follow(delta: float) -> bool:
	if path.is_empty():
		return true
	var tgt: Vector2 = path[0]
	var tc: Vector2i = world.to_cell(tgt)
	if tc != cell() and world.is_solid_for(owner_id, tc):
		# Weg wurde verbaut -> neu planen
		path = []
		if state == S.MOVE:
			path = world.find_path(owner_id, cell(), world.to_cell(move_goal), true)
		return path.is_empty() and state == S.MOVE
	var d := tgt - position
	var step: float = float(stats["speed"]) * 16.0 * delta
	if d.length() <= step:
		position = tgt
		path.pop_front()
	else:
		position += d / d.length() * step
		if absf(d.x) > 0.3:
			flip = d.x < 0.0
	return path.is_empty()


func _near_rect(r: Rect2i) -> bool:
	return world.dist_to_rect(position, r) <= 13.0


func _idle(delta: float) -> void:
	if not is_military():
		return
	scan_t -= delta
	if scan_t > 0.0:
		return
	scan_t = 0.5
	var sight: float = float(stats["sight"]) * 16.0
	var e = world.nearest_enemy_unit(owner_id, position, sight)
	if e == null:
		e = world.nearest_enemy_building(owner_id, position, sight, kind == "siege")
	if e != null:
		cmd_attack(e)


func _gather(delta: float) -> void:
	var cap := carry_cap()
	if gather_kind == "farm":
		if not world.valid(farm):
			farm = null
			if carry > 0.0:
				_go_return()
			else:
				state = S.IDLE
			return
		if not path.is_empty():
			_follow(delta)
			return
		var fc: Vector2 = farm.center()
		if position.distance_to(fc) > 12.0:
			path = world.find_path(owner_id, cell(), world.to_cell(fc), false)
			if path.is_empty():
				state = S.IDLE
			else:
				path[-1] = fc + Vector2(randf_range(-6, 6), randf_range(-6, 6))
			return
		if carry_type != "food":
			carry = 0.0
			carry_type = "food"
		var amt := minf(_rate("farm") * delta, cap - carry)
		carry += farm.take_food(amt)
		working = true
	else:
		if not world.resources.has(gather_cell):
			_resource_gone()
			return
		if not path.is_empty():
			_follow(delta)
			return
		var r1 := Rect2i(gather_cell, Vector2i.ONE)
		if not _near_rect(r1):
			path = world.find_path_adjacent(owner_id, cell(), r1)
			if path.is_empty():
				_resource_gone(true)
			return
		var r: Dictionary = world.resources[gather_cell]
		if carry_type != r["type"]:
			carry = 0.0
			carry_type = r["type"]
		var amt := minf(_rate(gather_kind) * delta, cap - carry)
		carry += world.take_resource(gather_cell, amt)
		flip = world.cell_center(gather_cell).x < position.x
		working = true
	if carry >= cap - 0.01:
		_go_return()


func _resource_gone(unreachable := false) -> void:
	fails += 1 if unreachable else 0
	var exclude: Vector2i = gather_cell if unreachable else NONE
	var nc: Vector2i = world.find_resource_near(gather_kind, gather_cell, 8, exclude, owner_id)
	if nc.x >= 0 and fails < 4:
		gather_cell = nc
		path = []
	elif carry > 0.0:
		_go_return()
	else:
		state = S.IDLE


func _go_return() -> void:
	state = S.RETURN
	target = null
	path = []


func _return(delta: float) -> void:
	if not world.valid(target) or not target.accepts(carry_type):
		target = world.nearest_dropoff(owner_id, carry_type, position)
		path = []
		if target == null:
			state = S.IDLE
			return
		path = world.find_path_adjacent(owner_id, cell(), target.rect())
		if path.is_empty():
			state = S.IDLE
			return
	if not path.is_empty():
		_follow(delta)
		return
	if _near_rect(target.rect()):
		world.players[owner_id]["res"][carry_type] += carry
		carry = 0.0
		target = null
		if gather_kind == "farm" and world.valid(farm):
			state = S.GATHER
		elif gather_kind != "" and gather_kind != "farm":
			state = S.GATHER
		else:
			state = S.IDLE
	else:
		path = world.find_path_adjacent(owner_id, cell(), target.rect())
		if path.is_empty():
			state = S.IDLE


func _build(delta: float) -> void:
	if not world.valid(target):
		target = null
		state = S.IDLE
		return
	if target.built and target.hp >= target.max_hp:
		_after_build()
		return
	if not path.is_empty():
		_follow(delta)
		return
	if not _near_rect(target.rect()):
		path = world.find_path_adjacent(owner_id, cell(), target.rect())
		if path.is_empty():
			state = S.IDLE
		return
	target.work(delta)
	flip = target.center().x < position.x
	working = true


func _after_build() -> void:
	var b = target
	target = null
	if b.kind == "farm" and world.farmers(b) == 0:
		cmd_farm(b)
		return
	if b.info.has("drop") and b.kind != "town_center":
		for t in b.info["drop"]:
			var c: Vector2i = world.find_resource_near(Data.RES_KIND[t], b.cell + Vector2i(1, 1), 8)
			if c.x >= 0:
				cmd_gather(c)
				return
	var nb = world.nearest_unfinished(owner_id, position, 160.0)
	if nb != null:
		cmd_build(nb)
		return
	state = S.IDLE


func _attack(delta: float) -> void:
	if not world.valid(target):
		target = null
		if world.valid(saved_target):
			target = saved_target
			saved_target = null
			path = []
			repath_t = 0.0
		else:
			saved_target = null
			state = S.IDLE
			scan_t = 0.0
			return
	if _in_range(target):
		path = []
		flip = target.aim_point().x < position.x
		if attack_t <= 0.0:
			attack_t = stats["cd"]
			_strike(target)
		return
	repath_t -= delta
	if repath_t <= 0.0 or path.is_empty():
		repath_t = 0.6 + randf() * 0.4
		_path_to_target()
		if path.is_empty():
			fails += 1
			if fails > 6:
				state = S.IDLE
				target = null
				return
		else:
			fails = 0
	_follow(delta)


func _in_range(t) -> bool:
	if t.is_building:
		return world.dist_to_rect(position, t.rect()) <= reach() + 2.0
	return position.distance_to(t.position) <= reach() + 4.0


func _path_to_target() -> void:
	var goal: Rect2i
	if target.is_building:
		goal = target.rect()
		path = world.find_path_adjacent(owner_id, cell(), goal)
	else:
		goal = Rect2i(target.cell(), Vector2i.ONE)
		path = world.find_path(owner_id, cell(), target.cell(), true)
		if not path.is_empty() and world.to_cell(path.back()) == target.cell():
			path[-1] = target.position
	var reaches: bool = not path.is_empty() and world.rect_dist_cells(world.to_cell(path.back()), goal) <= 1
	if not reaches and saved_target == null and is_military():
		# Mauern/Gebäude im Weg? Dann wird das Hindernis angegriffen.
		var blocker = world.find_blocking_building(owner_id, cell(), goal.position)
		if blocker != null and blocker != target:
			saved_target = target
			target = blocker
			path = world.find_path_adjacent(owner_id, cell(), blocker.rect())


func _strike(t) -> void:
	var dmg: float = world.calc_damage(kind, stats["atk"], t)
	var dir: Vector2 = (t.aim_point() - aim_point()).normalized()
	if float(stats["range"]) > 0.0:
		world.spawn_projectile(self, t, dmg, kind == "siege")
		lunge = -dir * 1.5
		var snd: String = "siege" if kind == "siege" else {"mammals": "arrow", "aliens": "beam", "plants": "spore"}[faction]
		world.play_sound(snd, position)
	else:
		world.apply_damage(t, dmg, self)
		lunge = dir * 3.0
		world.play_sound("melee", position)


func take_damage(amount: float, attacker) -> void:
	hp -= amount
	hit_flash = 0.12
	if hp <= 0.0:
		world.kill_unit(self)
		return
	if attacker == null or attacker.is_building or not world.is_enemy(owner_id, attacker.owner_id):
		return
	world.notify_attacked(self)
	if is_military():
		var busy_with_building: bool = state == S.ATTACK and world.valid(target) and target.is_building
		if state == S.IDLE or busy_with_building:
			cmd_attack(attacker)
	world.call_for_help(self, attacker)


# ---------------------------------------------------------------- Animation

func current_tool() -> String:
	if kind != "villager":
		return ""
	match state:
		S.GATHER:
			return TOOL_FOR.get(gather_kind, "")
		S.BUILD:
			return "hammer"
		S.ATTACK:
			return "sword"
	return ""


func _animate_work(delta: float) -> void:
	var before := work_phase
	work_phase = fmod(work_phase + delta / 0.9, 1.0)
	# Schlag trifft bei Phase ~0.95
	if before < 0.95 and (work_phase >= 0.95 or work_phase < before):
		var tool := current_tool()
		if WORK_FX.has(tool):
			var fx: Array = WORK_FX[tool]
			var hit := position + Vector2(-7 if flip else 7, -4)
			world.spawn_fx(fx[1], hit, fx[2], true)
			world.play_sound(fx[0], position, -6.0)


func _tool_angle() -> float:
	if not working:
		return 0.5
	# langsam ausholen, schnell zuschlagen
	if work_phase < 0.7:
		return lerpf(0.9, -1.6, work_phase / 0.7)
	return lerpf(-1.6, 0.9, (work_phase - 0.7) / 0.3)


func _draw_bundle() -> void:
	var fill := clampf(carry / carry_cap(), 0.3, 1.0)
	var h := 2.0 + 3.0 * fill
	var r := Rect2(-7, -8 - h, 5, h)
	match carry_type:
		"wood":
			draw_rect(r, Color("8a5a30"))
			draw_rect(Rect2(r.position + Vector2(0, 1), Vector2(5, 1)), Color("5a3a1a"))
			draw_rect(Rect2(r.position + Vector2(-1, h - 2), Vector2(7, 1)), Color("b08050"))
		"gold":
			draw_rect(r, Color("c89a30"))
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(2, 1)), Color("fff0a0"))
		"stone":
			draw_rect(r, Color("9a9aa2"))
			draw_rect(Rect2(r.position + Vector2(2, 1), Vector2(2, 1)), Color("dcdce4"))
		_:
			draw_rect(r, Color("a07040"))
			draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(3, 2)), Color("d03060"))


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 4.5, Color(0, 0, 0, 0.28))
	if selected:
		draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.0)
	var moving := not path.is_empty()
	var frame := 0
	var bob := 0.0
	if moving and frames.size() >= 3:
		var step := int(anim_t * 2.2 * float(stats["speed"])) % 4
		frame = [1, 0, 2, 0][step]
		bob = 1.0 if step % 2 == 0 else 0.0
	elif state == S.IDLE:
		bob = 1.0 if fmod(anim_t, 2.4) < 0.25 else 0.0
	var tool := current_tool()
	if tool == "basket" and working:
		bob = 1.0 if work_phase > 0.5 else 0.0
	var base := Transform2D(0.0, Vector2(-1.0 if flip else 1.0, 1.0), 0.0, Vector2(lunge.x, lunge.y - bob))
	draw_set_transform_matrix(base)
	if carry > 0.0 and not working:
		_draw_bundle()
	var mod := Color(1, 0.55, 0.55) if hit_flash > 0.0 else Color.WHITE
	draw_texture(frames[frame], Vector2(-8, -15), mod)
	if tool != "":
		var ttex: Texture2D = Art.tool_tex(tool, faction)
		if tool == "basket":
			draw_texture(ttex, HAND + Vector2(-2, -1))
		else:
			draw_set_transform_matrix(base * Transform2D(_tool_angle(), HAND))
			draw_texture(ttex, Vector2(-3, -ttex.get_height() + 1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tier: int = stats["tier"]
	for i in tier:
		draw_rect(Rect2(-4 + i * 2, -19, 1, 1), Color("ffd040"))
	if selected or hp < max_hp:
		draw_rect(Rect2(-6, -17, 12, 1.5), Color(0.2, 0, 0))
		draw_rect(Rect2(-6, -17, 12.0 * hp / max_hp, 1.5), Color(0.2, 0.9, 0.2) if owner_id == 0 else Color(0.95, 0.3, 0.2))
