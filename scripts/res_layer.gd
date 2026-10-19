extends Node2D
## Zeichnet alle Bäume, Minen und Beerensträucher in einem Durchgang.

var world


func _draw() -> void:
	if world == null:
		return
	for c in world.resources:
		var r: Dictionary = world.resources[c]
		draw_texture(Art.resource_tex(r["kind"], int(r["v"])), Vector2(c) * 16.0)
