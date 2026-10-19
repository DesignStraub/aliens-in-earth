extends Node2D
## Pfeil / Strahl / Spore / Felsbrocken, verfolgt das Ziel.

var world
var target
var attacker
var dmg := 0.0
var big := false
var speed := 210.0
var color := Color.WHITE
var dir := Vector2.RIGHT


func _ready() -> void:
	z_index = 4
	if big:
		speed = 140.0


func _process(delta: float) -> void:
	if not world.valid(target):
		queue_free()
		return
	var d: Vector2 = target.aim_point() - position
	var step := speed * delta
	if d.length() <= step:
		world.apply_damage(target, dmg, attacker)
		queue_free()
		return
	dir = d.normalized()
	position += dir * step
	queue_redraw()


func _draw() -> void:
	if big:
		draw_circle(Vector2.ZERO, 2.5, color.darkened(0.3))
		draw_circle(Vector2(-0.5, -0.5), 1.2, color)
	else:
		draw_line(-dir * 4.0, dir * 1.5, color, 1.0)
