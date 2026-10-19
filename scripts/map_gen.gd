extends RefCounted
## Zufallskarte: Seen, Strände, Wälder (auch als natürliche Grenzen),
## Startbereiche mit Beeren, Gold, Stein und Holz.

const GRASS := 0
const WATER := 1
const SAND := 2
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(w: int, h: int, seed_val: int, n_players := 2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var terrain := PackedByteArray()
	terrain.resize(w * h)
	terrain.fill(GRASS)
	var res := {}
	var starts := _pick_starts(w, h, rng, n_players)

	var nw := FastNoiseLite.new()
	nw.seed = seed_val
	nw.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nw.frequency = 0.03
	var nf := FastNoiseLite.new()
	nf.seed = seed_val + 101
	nf.frequency = 0.06
	var water_level := rng.randf_range(0.25, 0.42)
	var forest_level := rng.randf_range(0.12, 0.3)

	for y in h:
		for x in w:
			var ds := _dist_to_starts(Vector2i(x, y), starts)
			var v := nw.get_noise_2d(x, y)
			if ds > 16.0 and v > water_level:
				terrain[y * w + x] = WATER
			elif ds > 13.0 and v > water_level - 0.07:
				terrain[y * w + x] = SAND

	# Land zwischen den Spielern muss verbunden sein
	var land_blocked := func(c: Vector2i) -> bool: return terrain[c.y * w + c.x] == WATER
	for i in range(1, starts.size()):
		if _bfs_path(w, h, starts[0], starts[i], land_blocked).is_empty():
			for c in _line(starts[0], starts[i]):
				for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)]:
					var n: Vector2i = c + d
					if _in(n, w, h) and terrain[n.y * w + n.x] == WATER:
						terrain[n.y * w + n.x] = SAND

	# Wälder
	for y in h:
		for x in w:
			if terrain[y * w + x] == WATER:
				continue
			var c := Vector2i(x, y)
			var ds := _dist_to_starts(c, starts)
			var edge := x < 2 or y < 2 or x >= w - 2 or y >= h - 2
			var f := nf.get_noise_2d(x, y)
			if edge or (ds > 10.0 and f > forest_level) or (ds > 10.0 and rng.randf() < 0.008):
				res[c] = _make("tree", rng)

	# Ein Weg ohne Bäume muss existieren, damit sich die Völker begegnen
	var tree_blocked := func(c: Vector2i) -> bool: return terrain[c.y * w + c.x] == WATER or res.has(c)
	for i in range(1, starts.size()):
		if _bfs_path(w, h, starts[0], starts[i], tree_blocked).is_empty():
			for c in _bfs_path(w, h, starts[0], starts[i], land_blocked):
				for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
					res.erase(c + d)

	for s in starts:
		_clear(res, s, 7)
		var dir := rng.randf() * TAU
		_cluster(res, terrain, w, h, starts, s + _off(dir, 6), 6, "berry", rng)
		_cluster(res, terrain, w, h, starts, s + _off(dir + 2.1, 8), 7, "gold", rng)
		_cluster(res, terrain, w, h, starts, s + _off(dir + 4.0, 9), 5, "stone", rng)
		_forest_blob(res, terrain, w, h, starts, s + _off(dir + 1.0 + rng.randf(), 11), rng)

	var kinds := ["gold", "stone", "berry", "gold"]
	var placed := 0
	var tries := 0
	var extra := 8 * w * h / (96 * 96)
	while placed < extra and tries < 400:
		tries += 1
		var c := Vector2i(rng.randi_range(6, w - 7), rng.randi_range(6, h - 7))
		if _dist_to_starts(c, starts) < 22.0 or terrain[c.y * w + c.x] == WATER:
			continue
		_cluster(res, terrain, w, h, starts, c, 6, kinds[placed % kinds.size()], rng)
		placed += 1

	return {"terrain": terrain, "res": res, "starts": starts}


static func _pick_starts(w: int, h: int, rng: RandomNumberGenerator, n: int) -> Array:
	# Spieler gleichmäßig auf einem Ring um die Kartenmitte verteilen
	var s := []
	var center := Vector2(w, h) / 2.0
	var radius := minf(w, h) / 2.0 - 16.0
	var base := rng.randf() * TAU
	for i in n:
		var ang := base + TAU * i / n + rng.randf_range(-0.25, 0.25)
		var p := center + Vector2(cos(ang), sin(ang)) * radius
		s.append(Vector2i(clampi(roundi(p.x), 14, w - 15), clampi(roundi(p.y), 14, h - 15)))
	return s


static func _make(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	match kind:
		"tree":
			return {"kind": "tree", "type": "wood", "amount": 100.0, "v": rng.randi() % 2}
		"gold":
			return {"kind": "gold", "type": "gold", "amount": 800.0, "v": 0}
		"stone":
			return {"kind": "stone", "type": "stone", "amount": 350.0, "v": 0}
	return {"kind": "berry", "type": "food", "amount": 125.0, "v": 0}


static func _in(c: Vector2i, w: int, h: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


static func _dist_to_starts(c: Vector2i, starts: Array) -> float:
	var best := 1e9
	for s in starts:
		best = minf(best, Vector2(c - s).length())
	return best


static func _off(angle: float, dist: float) -> Vector2i:
	return Vector2i(roundi(cos(angle) * dist), roundi(sin(angle) * dist))


static func _clear(res: Dictionary, center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				res.erase(center + Vector2i(dx, dy))


static func _cluster(res: Dictionary, terrain: PackedByteArray, w: int, h: int, starts: Array, center: Vector2i, count: int, kind: String, rng: RandomNumberGenerator) -> void:
	var cands := []
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := center + Vector2i(dx, dy)
			if c.x < 2 or c.y < 2 or c.x >= w - 2 or c.y >= h - 2:
				continue
			if terrain[c.y * w + c.x] == WATER or _dist_to_starts(c, starts) < 5.0:
				continue
			if res.has(c) and res[c]["kind"] != "tree":
				continue
			cands.append([Vector2(dx, dy).length() + rng.randf() * 1.2, c])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(count, cands.size()):
		res[cands[i][1]] = _make(kind, rng)


static func _forest_blob(res: Dictionary, terrain: PackedByteArray, w: int, h: int, starts: Array, center: Vector2i, rng: RandomNumberGenerator) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var c := center + Vector2i(dx, dy)
			if not _in(c, w, h) or terrain[c.y * w + c.x] == WATER or res.has(c):
				continue
			if _dist_to_starts(c, starts) < 8.0:
				continue
			if Vector2(dx, dy).length() + rng.randf() * 1.5 < 4.0:
				res[c] = _make("tree", rng)


static func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(1.0, n)
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out


static func _bfs_path(w: int, h: int, a: Vector2i, b: Vector2i, blocked: Callable) -> Array:
	var prev := {a: a}
	var q := [a]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		if c == b:
			var path := []
			while c != a:
				path.append(c)
				c = prev[c]
			path.append(a)
			path.reverse()
			return path
		for d in DIRS4:
			var n: Vector2i = c + d
			if not _in(n, w, h) or prev.has(n) or blocked.call(n):
				continue
			prev[n] = c
			q.append(n)
	return []
