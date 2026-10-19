extends Sprite2D
## Nebel des Krieges: eine Zelle pro Pixel, weich hochskaliert.
## Schwarz = unerforscht, halbdunkel = erforscht, klar = in Sichtweite.

var world
var img: Image
var data := PackedByteArray()


func setup() -> void:
	centered = false
	scale = Vector2(16, 16)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 10
	data.resize(world.W * world.H * 4)
	img = Image.create_empty(world.W, world.H, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(img)
	refresh()


func refresh() -> void:
	var n: int = world.W * world.H
	for i in n:
		var a := 0
		if world.vis[i] == 0:
			a = 140 if world.explored[i] == 1 else 255
		var o := i * 4
		data[o] = 6
		data[o + 1] = 6
		data[o + 2] = 12
		data[o + 3] = a
	img.set_data(world.W, world.H, false, Image.FORMAT_RGBA8, data)
	texture.update(img)
