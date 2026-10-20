extends Control
## Minimap: Klick/Ziehen bewegt die Kamera, Rechtsklick schickt die Auswahl dorthin.

var world
var tex: ImageTexture
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	if world == null or not world.running:
		return
	t -= delta
	if t <= 0.0 and (world.minimap_dirty or world.fog_enabled or tex == null):
		t = 1.0
		world.minimap_dirty = false
		var img: Image = Art.minimap_image(world)
		if tex == null:
			tex = ImageTexture.create_from_image(img)
		else:
			tex.update(img)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if world == null or not world.running or tex == null:
		return
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	var s := size / Vector2(world.W, world.H)
	for b in world.buildings:
		if not b.visible:
			continue
		draw_rect(Rect2(Vector2(b.cell) * s, Vector2(b.size, b.size) * s), Art.TEAM[b.owner_id])
	for u in world.units:
		if not u.visible:
			continue
		draw_rect(Rect2(u.position / Data.TILE * s - Vector2(1, 1), Vector2(2.5, 2.5)), Art.TEAM[u.owner_id].lightened(0.35))
	var cam: Camera2D = world.camera
	var vs: Vector2 = get_viewport_rect().size / cam.zoom
	draw_rect(Rect2((cam.position - vs / 2.0) / Data.TILE * s, vs / Data.TILE * s), Color.WHITE, false, 1.0)
	if world.game_time - world.alarm_t < 4.0 and fmod(world.game_time, 0.5) < 0.3:
		draw_arc(world.alarm_pos / Data.TILE * s, 7.0, 0.0, TAU, 20, Color("ff3030"), 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("c8a060"), false, 1.0)


func _to_world(p: Vector2) -> Vector2:
	return p / size * Vector2(world.W, world.H) * Data.TILE


func _gui_input(event: InputEvent) -> void:
	if world == null or not world.running:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			world.center_on(_to_world(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			world.command_units(world.own_selected_units(), _to_world(event.position), Input.is_key_pressed(KEY_SHIFT))
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		world.center_on(_to_world(event.position))
