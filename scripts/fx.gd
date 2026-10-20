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
		"chips", "sparks", "dust", "leaves":
			n = 5
			life = 0.35
	var spread := 1.0 if kind in ["die", "rubble", "hit"] else 0.5
	for i in n:
		parts.append({"p": Vector2(randf_range(-2, 2), randf_range(-3, 0)), "v": Vector2(randf_range(-70, 70), randf_range(-120, -20)) * spread})


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	for p in parts:
		var v: Vector2 = p["v"]
		v.y += 280.0 * delta
		p["v"] = v
		p["p"] = p["p"] + v * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - t / life
	if kind == "click":
		draw_arc(Vector2.ZERO, 4.0 + t * 28.0, 0.0, TAU, 20, Color(color, a), 2.0)
		return
	for p in parts:
		draw_rect(Rect2(p["p"], Vector2(2, 2)), Color(color, a))
