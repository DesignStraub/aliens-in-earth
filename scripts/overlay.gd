extends Node2D
## Auswahlrahmen, Bauvorschau, Sammelpunkt.

var world


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or not world.running:
		return
	if world.dragging:
		var a: Vector2 = world.drag_start
		var r := Rect2(a, get_global_mouse_position() - a).abs()
		draw_rect(r, Color(1, 1, 1, 0.12))
		draw_rect(r, Color(1, 1, 1, 0.85), false, 2.0)
	if world.place_kind != "":
		var k: String = world.place_kind
		var tex: Texture2D = Art.building_tex(world.players[0]["faction"], k, 0)
		var size: int = Data.BUILDINGS[k]["size"]
		var cells: Array = [world.ghost_cell]
		if world.wall_start.x >= 0:
			cells = world.line_cells(world.wall_start, world.ghost_cell)
		for c in cells:
			var ok: bool = world.can_place(k, c)
			var col := Color(0.6, 1.0, 0.6, 0.7) if ok else Color(1.0, 0.35, 0.35, 0.7)
			draw_texture(tex, Vector2(c) * Data.TILE + Vector2(0, size * Data.TILE - tex.get_height()), col)
			draw_rect(Rect2(Vector2(c) * Data.TILE, Vector2(size, size) * Data.TILE), col, false, 2.0)
	for e in world.selected:
		if world.valid(e) and e.is_building and e.has_rally and e.owner_id == 0:
			draw_line(e.center(), e.rally, Color(1, 1, 1, 0.35), 2.0)
			draw_line(e.rally, e.rally + Vector2(0, -18), Color.WHITE, 2.0)
			draw_rect(Rect2(e.rally + Vector2(2, -18), Vector2(10, 6)), Art.TEAM[0])
	# Wegpunkte der mit Shift angehängten Aufgaben
	for e in world.selected:
		if not world.valid(e) or e.is_building or e.owner_id != world.human or e.cmd_queue.is_empty():
			continue
		var prev: Vector2 = e.position
		var n := 1
		for cmd in e.cmd_queue:
			var p: Vector2 = e.cmd_pos(world, cmd)
			if p == Vector2.INF:
				continue
			draw_line(prev, p, Color(1, 1, 0.6, 0.45), 2.0)
			draw_circle(p, 5.0, Color(1, 1, 0.6, 0.8))
			draw_string(ThemeDB.fallback_font, p + Vector2(7, -4), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 0.7))
			prev = p
			n += 1
