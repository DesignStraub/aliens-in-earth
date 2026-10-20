extends Node2D
## Bäume, Minen und Sträucher, in Blöcken gezeichnet (nur geänderte Blöcke werden neu gemalt).
## Bäume wackeln beim Hacken, fallen um, wenn sie leer sind, und hinterlassen einen Stumpf.

const CHUNK := 8

var world
var chunks := {}


class ResChunk extends Node2D:
	var layer
	var origin := Vector2i.ZERO

	func _draw() -> void:
		layer.draw_chunk(self, origin)


## Kurzes Wackeln eines getroffenen Baums/Strauchs
class ShakeFx extends Node2D:
	var layer
	var cell := Vector2i.ZERO
	var tex: Texture2D
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t >= 0.22:
			layer.end_shake(cell)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var off := sin(t * 70.0) * 2.0 * (1.0 - t / 0.22)
		draw_texture(tex, Vector2(off, 0))


## Umfallender Baum
class FallFx extends Node2D:
	var tex: Texture2D
	var dir := 1.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t >= 1.1:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / 0.6, 0.0, 1.0)
		var ang := dir * (PI / 2.0) * k * k
		var alpha := 1.0 if t < 0.7 else 1.0 - (t - 0.7) / 0.4
		draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
		draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()), Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func build() -> void:
	for c in get_children():
		c.queue_free()
	chunks.clear()
	for cy in ceili(float(world.H) / CHUNK):
		for cx in ceili(float(world.W) / CHUNK):
			var ch := ResChunk.new()
			ch.layer = self
			ch.origin = Vector2i(cx, cy) * CHUNK
			add_child(ch)
			chunks[Vector2i(cx, cy)] = ch


func mark(c: Vector2i) -> void:
	var k := Vector2i(c.x / CHUNK, c.y / CHUNK)
	if chunks.has(k):
		chunks[k].queue_redraw()


func mark_all() -> void:
	for k in chunks:
		chunks[k].queue_redraw()


func _cell_pos(c: Vector2i, tex: Texture2D) -> Vector2:
	var t: int = Data.TILE
	return Vector2(c) * t + Vector2(0, t - tex.get_height())


func draw_chunk(ch: Node2D, o: Vector2i) -> void:
	for y in range(o.y, mini(o.y + CHUNK, world.H)):
		for x in range(o.x, mini(o.x + CHUNK, world.W)):
			var c := Vector2i(x, y)
			var r = world.resources.get(c)
			if r != null:
				if r.has("shake"):
					continue
				var tex: Texture2D = Art.resource_tex(r["kind"], int(r["v"]), Art.res_stage(r))
				ch.draw_texture(tex, _cell_pos(c, tex))
			elif world.stumps.has(c):
				var st: Texture2D = Art.resource_tex("stump", 0)
				ch.draw_texture(st, _cell_pos(c, st))


func shake(c: Vector2i) -> void:
	var r = world.resources.get(c)
	if r == null or r.has("shake"):
		return
	r["shake"] = true
	mark(c)
	var fx := ShakeFx.new()
	fx.layer = self
	fx.cell = c
	fx.tex = Art.resource_tex(r["kind"], int(r["v"]), Art.res_stage(r))
	fx.position = _cell_pos(c, fx.tex)
	add_child(fx)


func end_shake(c: Vector2i) -> void:
	var r = world.resources.get(c)
	if r != null:
		r.erase("shake")
	mark(c)


func fall(c: Vector2i, r: Dictionary, dir: float) -> void:
	var fx := FallFx.new()
	fx.tex = Art.resource_tex("tree", int(r["v"]), 2)
	fx.dir = dir
	fx.position = Vector2(c) * Data.TILE + Vector2(Data.TILE * 0.5, Data.TILE)
	add_child(fx)
