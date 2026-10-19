extends Node2D
## Rendert das Cover-Bild (itch.io, 1260×1000 = 2× 630×500) aus den Spielgrafiken.
## Aufruf: godot --path . -- --cover   ->  speichert cover.png im Projektordner

const W := 1260.0
const H := 1000.0
const GROUND := 600.0


var ground_tex: Texture2D


func _ready() -> void:
	var terr := PackedByteArray()
	terr.resize(20 * 7)
	terr.fill(0)
	ground_tex = ImageTexture.create_from_image(Art.build_terrain_image(terr, 20, 7, 3))
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://cover.png")
	get_tree().quit()


func _px_rect(p: Vector2, size: float, c: Color) -> void:
	var q := (p / 4.0).floor() * 4.0
	draw_rect(Rect2(q, Vector2(size, size)), c)


func _unit(f: String, k: String, team: int, pos: Vector2, scale: float, face_left := false, frame := 0) -> void:
	var tex: Texture2D = Art.unit_frames(f, k, team)[frame]
	var sz := Vector2(16, 16) * scale
	draw_set_transform(Vector2(pos.x, 0), 0.0, Vector2(-1 if face_left else 1, 1))
	draw_texture_rect(tex, Rect2(Vector2(-sz.x / 2.0, pos.y - sz.y), sz), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Schatten
	draw_rect(Rect2(pos + Vector2(-sz.x * 0.25, -scale * 0.6), Vector2(sz.x * 0.5, scale)), Color(0, 0, 0, 0.25))


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Himmel
	var bands := 40
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, GROUND * t, W, GROUND / bands + 1), Color("0a0a22").lerp(Color("5a2e5e"), t * t))
	for i in 110:
		var c := Color(1, 1, 1, rng.randf_range(0.25, 0.9))
		_px_rect(Vector2(rng.randf() * W, rng.randf() * GROUND * 0.8), 4.0 if rng.randf() < 0.85 else 8.0, c)
	# Komet mit Schweif
	var head := Vector2(1010, 120)
	var dir := Vector2(-1.0, -0.42).normalized()
	for i in range(60, 0, -1):
		var p := head + dir * i * 9.0
		var s := maxf(4.0, 28.0 - i * 0.42)
		var a := 1.0 - float(i) / 60.0
		_px_rect(p - Vector2(s, s) / 2.0, s, Color(0.45, 0.95, 1.0, a * 0.55))
		if i % 3 == 0:
			_px_rect(p + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)), 4.0, Color(1, 1, 1, a * 0.7))
	draw_circle(head, 26, Color(0.5, 0.95, 1.0, 0.35))
	draw_circle(head, 16, Color("bff8ff"))
	draw_circle(head, 9, Color.WHITE)
	# Hügel am Horizont
	for x in range(0, int(W), 4):
		var h1 := 60.0 + sin(x * 0.006) * 30.0 + sin(x * 0.017) * 14.0
		draw_rect(Rect2(x, GROUND - h1, 4, h1), Color("2a1e3a"))
		var h2 := 30.0 + sin(x * 0.011 + 2.0) * 18.0
		draw_rect(Rect2(x, GROUND - h2, 4, h2), Color("1e2a2a"))
	# Boden aus echtem Gelände-Tileset
	if ground_tex != null:
		draw_texture_rect(ground_tex, Rect2(0, GROUND, 1280, 448), false)
	draw_rect(Rect2(0, GROUND, W, 8), Color(0, 0, 0, 0.25))
	# Waldrand
	for i in 18:
		var x := i * 72.0 - 20.0 + rng.randf_range(-10, 10)
		if x > 300 and x < 960:
			continue
		var tex := Art.resource_tex("tree", i % 2)
		draw_texture_rect(tex, Rect2(x, GROUND - 40 + rng.randf_range(0, 20), 64, 64), false)
	# Hauptgebäude der drei Völker
	draw_texture_rect(Art.building_tex("mammals", "town_center", 0), Rect2(70, GROUND - 160 + 30, 192, 192), false)
	draw_texture_rect(Art.building_tex("plants", "town_center", 2), Rect2(510, GROUND - 200 + 30, 240, 240), false)
	draw_texture_rect(Art.building_tex("aliens", "town_center", 1), Rect2(1000, GROUND - 160 + 30, 192, 192), false)
	# Armeen
	var sc := 6.0
	_unit("mammals", "cavalry", 0, Vector2(150, 900), sc, false, 1)
	_unit("mammals", "spear", 0, Vector2(270, 860), sc)
	_unit("mammals", "archer", 0, Vector2(90, 800), sc, false, 2)
	_unit("mammals", "villager", 0, Vector2(330, 760), 5.0)
	_unit("aliens", "cavalry", 1, Vector2(1110, 900), sc, true, 2)
	_unit("aliens", "spear", 1, Vector2(990, 860), sc, true)
	_unit("aliens", "siege", 1, Vector2(1180, 790), sc, true, 1)
	_unit("aliens", "villager", 1, Vector2(930, 760), 5.0, true)
	_unit("plants", "spear", 2, Vector2(560, 940), sc)
	_unit("plants", "archer", 2, Vector2(700, 940), sc, true)
	_unit("plants", "villager", 2, Vector2(630, 860), 5.0)
	# Titel
	var font := ThemeDB.fallback_font
	var title := "KOMETEN & KRONEN"
	var ty := 290.0
	draw_string_outline(font, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, W, 104, 22, Color("1a0e06"))
	draw_string(font, Vector2(0, ty + 5), title, HORIZONTAL_ALIGNMENT_CENTER, W, 104, Color("6a3a10"))
	draw_string(font, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, W, 104, Color("f4c860"))
	var sub := "Säugetiere  •  Aliens  •  Lebende Pflanzen"
	draw_string_outline(font, Vector2(0, ty + 62), sub, HORIZONTAL_ALIGNMENT_CENTER, W, 36, 10, Color("1a0e06"))
	draw_string(font, Vector2(0, ty + 62), sub, HORIZONTAL_ALIGNMENT_CENTER, W, 36, Color("f0e6d0"))
