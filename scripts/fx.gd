extends Node2D
## Kurze Effekte: Klickmarker, Treffer, Tod, Trümmer.

var kind := "hit"
var color := Color.WHITE
var t := 0.0
var life := 0.4
var parts: Array = []


func _ready() -> void:
	z_index = 5
	var n := 4
	match kind:
		"die":
			n = 10
			life = 0.7
		"rubble":
			n = 24
			life = 0.9
		"click":
			n = 0
			life = 0.35
	for i in n:
		parts.append({"p": Vector2(randf_range(-4, 4), randf_range(-6, 0)), "v": Vector2(randf_range(-35, 35), randf_range(-60, -10))})


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	for p in parts:
		var v: Vector2 = p["v"]
		v.y += 140.0 * delta
		p["v"] = v
		p["p"] = p["p"] + v * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - t / life
	if kind == "click":
		draw_arc(Vector2.ZERO, 2.0 + t * 14.0, 0.0, TAU, 16, Color(color, a), 1.0)
		return
	for p in parts:
		draw_rect(Rect2(p["p"], Vector2(1, 1)), Color(color, a))
