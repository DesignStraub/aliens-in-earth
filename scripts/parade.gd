extends Control
## Deko für den Titelbildschirm: Einheiten aller Völker marschieren übers Bild.

var t := 0.0
var marchers: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kinds := ["villager", "spear", "archer", "cavalry", "siege"]
	var facs := Data.FACTIONS.keys()
	for i in 14:
		marchers.append({"f": facs[i % 3], "k": kinds[(i * 2 + i / 3) % kinds.size()], "x": i / 14.0, "team": i % 4})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x + 100.0
	var sc := 4.0
	for m in marchers:
		var x := fmod(float(m["x"]) * w + t * 28.0, w) - 50.0
		var frames: Array = Art.unit_frames(m["f"], m["k"], m["team"])
		var step := int(t * 6.0 + float(m["x"]) * 10.0) % 4
		var tex: Texture2D = frames[[1, 0, 2, 0][step]] if frames.size() >= 3 else frames[0]
		draw_texture_rect(tex, Rect2(Vector2(x, size.y - 16 * sc - 8 - (step % 2) * sc), Vector2(16, 16) * sc), false)
