extends Node
## Erzeugt sämtliche Pixelgrafik zur Laufzeit in 32-px-Auflösung: Figuren aus Körperteilen
## (Blickrichtung, Werkzeug in der Hand, Schattierung, Umriss), Gebäude, Gelände und Ressourcen.
## Eigene PNGs können später einfach statt dieser Texturen geladen werden.

const TEAM := [Color("3a78f0"), Color("e04040"), Color("40c060"), Color("e0c040")]

# Werkzeuge der Dorfbewohner, Griff unten (Drehpunkt = PIVOT)
const TOOLS := {
	"axe": ["..ww...", ".www...", ".wwh...", "...h...", "...h...", "...h...", "...h..."],
	"pick": [".wwwww.", "w..h..w", "...h...", "...h...", "...h...", "...h...", "...h..."],
	"hammer": [".www...", ".www...", "..h....", "..h....", "..h....", "..h...."],
	"hoe": ["www....", "..h....", "..h....", "..h....", "..h....", "..h...."],
	"sword": ["..w..", "..w..", "..w..", "..w..", ".hhh.", "..h.."],
	"basket": [".oooo.", "orrrro", "obbbbo", ".oooo."],
}
const TOOL_PAL := {"w": Color("d8d8e0"), "h": Color("7a5430"), "o": Color("4a3018"), "r": Color("d03060"), "b": Color("a07040")}

const BPAL := {
	"mammals": {"wall": Color("9a6a3a"), "wall_d": Color("6a4424"), "roof": Color("d8b048"), "roof_d": Color("a8842c"), "door": Color("3a2210"), "win": Color("f0d890"), "out": Color("24160c"), "stone": Color("8a8a8a"), "stone_d": Color("5e5e5e"), "crop": Color("e0c048")},
	"aliens": {"wall": Color("8a8aa8"), "wall_d": Color("5a5a78"), "roof": Color("b0b0d8"), "roof_d": Color("7070a0"), "door": Color("202038"), "win": Color("70f0ff"), "out": Color("141428"), "stone": Color("6a6a88"), "stone_d": Color("3a3a58"), "crop": Color("c060ff")},
	"plants": {"wall": Color("7a5a2e"), "wall_d": Color("523a1a"), "roof": Color("4ea83c"), "roof_d": Color("2e7a26"), "door": Color("2a1a0a"), "win": Color("f8f070"), "out": Color("142810"), "stone": Color("3a6a2a"), "stone_d": Color("24481a"), "crop": Color("90e050")},
}

const GLYPH := {
	"town_center": ["x.x.x", "xxxxx", "xxxxx"],
	"mill": ["x.x.x", ".xxx.", "..x..", "..x.."],
	"camp": ["xxx..", "xxxx.", "..x..", "...x.", "....x"],
	"barracks": ["....x", "...x.", "x.x..", ".x...", "x.x.."],
	"range": [".xx..", "x..x.", "xxxxx", "x..x.", ".xx.."],
	"stable": ["x...x", "x...x", "x...x", ".xxx."],
	"workshop": [".x.x.", "xxxxx", ".x.x.", "xxxxx", ".x.x."],
}

var _cache := {}


func _img_from(rows: Array, pal: Dictionary, w: int, h: int, ox := 0, oy := 0, img: Image = null) -> Image:
	if img == null:
		img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or not pal.has(ch):
				continue
			_px(img, ox + x, oy + y, pal[ch])
	return img


const SCROLL := [
	".oooooooooo.",
	"oaaaaaaaaaao",
	".owwwwwwwwo.",
	".owhhhhhhwo.",
	".owwwwwwwwo.",
	".owhhhhhwwo.",
	".owwwwwwwwo.",
	".owhhhhhhwo.",
	".owwwwwwwwo.",
	"oaaaaaaaaaao",
	".oooooooooo.",
]


func tech_icon() -> Texture2D:
	if _cache.has("tech_icon"):
		return _cache["tech_icon"]
	var img := _img_from(SCROLL, {"o": Color("4a3018"), "a": Color("a07040"), "w": Color("f0e0b0"), "h": Color("7a6040")}, 12, 11)
	img.resize(24, 22, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache["tech_icon"] = tex
	return tex


# ---------------------------------------------------------------- Mauszeiger

const CURSOR_ARROW := [
	"o...........",
	"oo..........",
	"owo.........",
	"owwo........",
	"owwwo.......",
	"owwwwo......",
	"owwwwwo.....",
	"owwwwwwo....",
	"owwwwwwwo...",
	"owwwwwoooo..",
	"owwowwo.....",
	"owo.owwo....",
	"oo..owwo....",
	"o....owwo...",
	".....owwo...",
	"......oo....",
]
# Schwert, Spitze oben links (Hotspot 0,0)
const CURSOR_SWORD := [
	"oo..............",
	"owo.............",
	".owo............",
	"..owo...........",
	"...owo..........",
	"....owo.........",
	".....owo.....o..",
	"......owo...oo..",
	".......owo.oo...",
	"........orro....",
	"........oorro...",
	".......oo.oro...",
	"...........oro..",
	"............oro.",
	".............oro",
	"..............oo",
]
const CURSOR_PAL := {"o": Color("1a1008"), "w": Color("f4ecd8"), "r": Color("c83a2a")}


## Mauszeiger als Bild; size_px = Zielgröße (pixelig hochskaliert).
func cursor_image(mode: String, faction: String, scale: int) -> Image:
	var key := "c_%s_%s_%d" % [mode, faction, scale]
	if _cache.has(key):
		return _cache[key]
	var img: Image
	match mode:
		"arrow":
			img = _img_from(CURSOR_ARROW, CURSOR_PAL, 16, 16)
		"attack":
			var pal := CURSOR_PAL.duplicate()
			pal["w"] = Color("e0e0e8")
			img = _img_from(CURSOR_SWORD, pal, 16, 16)
		_:
			# Werkzeug (Axt, Hacke, Korb, Hammer) mit Umriss, Griff unten rechts
			img = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			var t: Image = tool_tex(mode, faction).get_image()
			t.resize(t.get_width() * 2, t.get_height() * 2, Image.INTERPOLATE_NEAREST)
			var big := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
			big.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(1, 1))
			var outline := Color("1a1008")
			for y in 16:
				for x in 16:
					if big.get_pixel(x, y).a > 0.5:
						img.set_pixel(x, y, big.get_pixel(x, y))
					else:
						for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							var n: Vector2i = Vector2i(x, y) + d
							if n.x >= 0 and n.y >= 0 and n.x < 16 and n.y < 16 and big.get_pixel(n.x, n.y).a > 0.5:
								img.set_pixel(x, y, outline)
								break
	img.resize(16 * scale, 16 * scale, Image.INTERPOLATE_NEAREST)
	_cache[key] = img
	return img


func tool_tex(tool: String, faction: String) -> Texture2D:
	var key := "t_%s_%s" % [tool, faction]
	if _cache.has(key):
		return _cache[key]
	var pal: Dictionary = TOOL_PAL.duplicate()
	if faction == "aliens":
		pal["w"] = Color("90f0ff")
		pal["h"] = Color("505868")
	elif faction == "plants":
		pal["w"] = Color("e0d040")
		pal["h"] = Color("5a3e1e")
	var rows: Array = TOOLS[tool]
	var tex := ImageTexture.create_from_image(_img_from(rows, pal, 7, rows.size()))
	_cache[key] = tex
	return tex


## Vergrößert kleine Texturen für Buttons (Nearest-Neighbour, bleibt pixelig).
func icon(tex: Texture2D) -> Texture2D:
	if tex == null or tex.get_width() > 16:
		return tex
	var key := "i_%d" % tex.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var img := tex.get_image()
	img.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


# ---------------------------------------------------------------- Gebäude

func building_tex(faction: String, kind: String, team: int) -> Texture2D:
	var key := "b_%s_%s_%d" % [faction, kind, team]
	if _cache.has(key):
		return _cache[key]
	var size: int = Data.BUILDINGS[kind]["size"]
	var s := size * Data.TILE
	var h := s
	match kind:
		"tower":
			h = s + 24
		"palisade", "wall", "gate", "farm":
			h = s
		_:
			h = s + s / 4
	var img := Image.create_empty(s, h, false, Image.FORMAT_RGBA8)
	var tc: Color = TEAM[team]
	match kind:
		"palisade", "wall":
			_draw_wall(img, faction, kind, tc)
		"gate":
			_draw_wall(img, faction, "wall", tc)
			_draw_gate(img, faction, tc)
		"tower":
			_draw_tower(img, faction, tc)
			_outline_img(img, BPAL[faction].out)
		"farm":
			_draw_farm(img, faction, tc)
		_:
			_draw_house(img, faction, kind, tc, s, h)
			_outline_img(img, BPAL[faction].out)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _hline(img: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(img, x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		_hline(img, x, x + w - 1, yy, c)


func _outline(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_hline(img, x, x + w - 1, y, c)
	_hline(img, x, x + w - 1, y + h - 1, c)
	for yy in range(y, y + h):
		_px(img, x, yy, c)
		_px(img, x + w - 1, yy, c)


func _banner(img: Image, x: int, team: Color, out: Color) -> void:
	for y in range(0, 15):
		_px(img, x, y, out)
	_rect(img, x + 1, 1, 9, 6, team)
	_hline(img, x + 1, x + 9, 1, team.lightened(0.25))
	_hline(img, x + 1, x + 9, 6, team.darkened(0.35))
	_px(img, x + 9, 4, Color(0, 0, 0, 0))


func _draw_house(img: Image, f: String, kind: String, team: Color, s: int, h: int) -> void:
	var p: Dictionary = BPAL[f]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(f + kind)
	var wall_top := int(h * 0.56)
	var x0 := 3
	var x1 := s - 4
	var y1 := h - 1
	var depth := maxi(5, s / 8)
	var side_x := x1 - depth + 1
	# Wände: Vorderseite + dunklere Seitenwand (Tiefe)
	_rect(img, x0, wall_top, x1 - x0 + 1, y1 - wall_top + 1, p.wall)
	_rect(img, side_x, wall_top, depth, y1 - wall_top + 1, p.wall.darkened(0.22))
	match f:
		"mammals":
			for x in range(x0 + 3, side_x, 4):
				for y in range(wall_top, y1 + 1):
					_px(img, x, y, p.wall_d)
					_px(img, x + 1, y, p.wall.lightened(0.08))
			_rect(img, x0, wall_top + 2, x1 - x0 + 1, 2, p.wall_d.darkened(0.2))
			# Steinfundament
			for x in range(x0, x1 + 1, 5):
				_rect(img, x, y1 - 3, 4, 3, Color("8a8a8a"))
				_hline(img, x, x + 3, y1 - 3, Color("a8a8a8"))
		"aliens":
			for y in range(wall_top + 5, y1, 6):
				_hline(img, x0, x1, y, p.wall_d)
				_hline(img, x0, x1, y + 1, p.wall.lightened(0.12))
			for x in range(x0 + 4, side_x, 8):
				for y in range(wall_top + 3, y1, 6):
					_px(img, x, y, p.wall.lightened(0.3))
			_hline(img, x0, x1, wall_top + 2, p.win)
		"plants":
			for i in s * 3:
				var x := rng.randi_range(x0, x1)
				var y := rng.randi_range(wall_top, y1 - 2)
				_px(img, x, y, p.wall_d)
				_px(img, x, y + 1, p.wall_d)
				_px(img, x, y + 2, p.wall_d.darkened(0.1))
			for i in s / 3:
				_px(img, rng.randi_range(x0, x1), rng.randi_range(wall_top, y1), Color("4e8a34"))
			for x in range(x0, x1, 7):
				_px(img, x, y1, p.wall_d.darkened(0.3))
				_px(img, x + 1, y1, p.wall_d.darkened(0.3))

	var cxi := s / 2
	match f:
		"mammals":
			# Strohdach mit Überstand
			var top := 6
			for y in range(top, wall_top + 4):
				var t := float(y - top) / float(wall_top + 4 - top)
				var half := int(lerpf(4.0, s / 2.0 + 1, t))
				for x in range(cxi - half, cxi + half):
					var c: Color = p.roof
					if (y - top) % 3 == 0:
						c = p.roof_d
					elif x > cxi + half / 3:
						c = p.roof.darkened(0.12)
					elif x < cxi - half / 2:
						c = p.roof.lightened(0.1)
					if rng.randf() < 0.08:
						c = p.roof_d.darkened(0.15)
					_px(img, x, y, c)
			_rect(img, cxi - 4, top - 2, 8, 2, p.roof_d.darkened(0.2))
			# Schornstein
			_rect(img, cxi + s / 5, top + 2, 4, 6, Color("8a7a6a"))
			_hline(img, cxi + s / 5, cxi + s / 5 + 3, top + 2, Color("a89888"))
		"aliens":
			var rx := s / 2.0 - 3.0
			var ry := float(wall_top) - 6.0
			var cy := float(wall_top) + 2.0
			for y in range(int(cy - ry), int(cy) + 1):
				for x in range(0, s):
					var nx := (x + 0.5 - cxi) / rx
					var ny := (y + 0.5 - cy) / ry
					if nx * nx + ny * ny > 1.0:
						continue
					var l := -(nx * 0.6 + ny * 0.8)
					var c: Color = p.roof
					if l > 0.55:
						c = p.roof.lightened(0.25)
					elif l < -0.1:
						c = p.roof_d
					_px(img, x, y, c)
			var wy := int(cy - ry * 0.45)
			for x in range(int(cxi - rx * 0.8), int(cxi + rx * 0.8)):
				if x % 4 != 0:
					_px(img, x, wy, p.win)
					_px(img, x, wy + 1, p.win.darkened(0.3))
			# Antenne
			_rect(img, cxi, int(cy - ry) - 6, 1, 6, p.wall_d)
			_rect(img, cxi - 1, int(cy - ry) - 8, 3, 3, Color("ff70ff"))
		"plants":
			var ccx := s / 2.0
			var ccy := wall_top * 0.55
			var crx := s / 2.0 - 1.0
			var cry := wall_top * 0.6
			for y in range(0, wall_top + 6):
				for x in range(0, s):
					var nx := (x + 0.5 - ccx) / crx
					var ny := (y + 0.5 - ccy) / cry
					var d := nx * nx + ny * ny
					if d > 1.0:
						continue
					var l := -(nx * 0.55 + ny * 0.85)
					var c: Color = p.roof
					if l > 0.5:
						c = p.roof.lightened(0.2)
					elif l < -0.4:
						c = p.roof_d
					if rng.randf() < 0.12:
						c = p.roof_d.darkened(0.1)
					elif rng.randf() < 0.04:
						c = Color("ff86b8")
					_px(img, x, y, c)
			# hängende Ranken
			for i in 4:
				var vx := rng.randi_range(x0 + 4, x1 - 4)
				for y in range(int(ccy + cry) - 2, int(ccy + cry) + rng.randi_range(4, 10)):
					_px(img, vx, y, Color("3a7a2a"))

	# Tür
	var dw := maxi(8, s / 5)
	var dh := maxi(12, int((y1 - wall_top) * 0.55))
	var dx0 := cxi - dw / 2 - depth / 2
	match f:
		"plants":
			for y in range(y1 - dh + 1, y1 + 1):
				for x in range(dx0, dx0 + dw):
					var nx := (x + 0.5 - (dx0 + dw / 2.0)) / (dw / 2.0)
					var ny := (y + 0.5 - (y1 - dh / 2.0)) / (dh / 2.0)
					if ny > 0.0 or nx * nx + ny * ny <= 1.0:
						_px(img, x, y, p.door)
		_:
			_rect(img, dx0 - 1, y1 - dh, dw + 2, dh + 1, p.wall_d.darkened(0.15))
			_rect(img, dx0, y1 - dh + 1, dw, dh, p.door)
			if f == "mammals":
				for x in range(dx0 + 2, dx0 + dw, 3):
					for y in range(y1 - dh + 1, y1 + 1):
						_px(img, x, y, p.door.lightened(0.12))
				_px(img, dx0 + dw - 2, y1 - dh / 2, Color("d0b060"))
			else:
				_hline(img, dx0, dx0 + dw - 1, y1 - dh + 1, p.win)
				for y in range(y1 - dh + 1, y1 + 1):
					_px(img, dx0 + dw / 2, y, p.win.darkened(0.4))
	# Fenster
	if s >= 64:
		for wx in [x0 + 5, side_x - 13]:
			_rect(img, wx - 1, wall_top + 7, 9, 9, p.wall_d.darkened(0.2))
			_rect(img, wx, wall_top + 8, 7, 7, p.win)
			_rect(img, wx, wall_top + 8, 3, 3, p.win.lightened(0.35))
			_hline(img, wx, wx + 6, wall_top + 11, p.wall_d)
			for y in range(wall_top + 8, wall_top + 15):
				_px(img, wx + 3, y, p.wall_d)
	# Teamfahnen
	_banner(img, x0 + 1, team, p.out)
	if kind == "town_center":
		_banner(img, s - 14, team, p.out)
	# Symbol (doppelt groß)
	if GLYPH.has(kind):
		var g: Array = GLYPH[kind]
		var gx := dx0 - 14
		var gy := wall_top + 8
		if s >= 96:
			gx = cxi - 5 - depth / 2
			gy = wall_top + 6
		for yy in g.size():
			var row: String = g[yy]
			for xx in row.length():
				if row[xx] == "x":
					_rect(img, gx + xx * 2, gy + yy * 2, 2, 2, Color("f4e8c8"))
	# Bodenschatten an der Hauswand
	_hline(img, x0, x1, y1, p.wall_d.darkened(0.35))


func _draw_wall(img: Image, f: String, kind: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	var s := img.get_width()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(f + kind)
	if kind == "palisade":
		match f:
			"mammals":
				for x in range(0, s, 6):
					_rect(img, x, 7, 6, s - 7, p.wall)
					for y in range(7, s):
						_px(img, x, y, p.wall.lightened(0.15))
						_px(img, x + 4, y, p.wall_d)
						_px(img, x + 5, y, p.wall_d.darkened(0.2))
					for k in 3:
						_hline(img, x + k, x + 5 - k, 6 - k, p.wall if k < 2 else p.wall.lightened(0.15))
					_hline(img, x, x + 5, 16, Color("c8a870"))
			"aliens":
				_rect(img, 1, 3, 5, s - 3, p.stone)
				_rect(img, s - 6, 3, 5, s - 3, p.stone)
				_rect(img, 1, 3, 1, s - 3, p.stone.lightened(0.2))
				_rect(img, s - 6, 3, 1, s - 3, p.stone.lightened(0.2))
				for y in [9, 15, 21, 27]:
					_hline(img, 6, s - 7, y, p.win)
					_hline(img, 6, s - 7, y + 1, p.win.darkened(0.4))
			"plants":
				for i in 260:
					var x := rng.randi_range(0, s - 1)
					var y := rng.randi_range(8, s - 1)
					_px(img, x, y, [p.wall, p.wall_d, p.roof_d][i % 3])
				for i in 18:
					_px(img, rng.randi_range(0, s - 1), rng.randi_range(8, s - 1), Color("e0d040"))
	else:
		var base: Color = p.stone
		# Zinnen
		for x in range(0, s, 8):
			_rect(img, x, 2, 5, 6, base)
			_hline(img, x, x + 4, 2, base.lightened(0.2))
			_px(img, x + 4, 4, base.darkened(0.25))
		# Steinblöcke mit Licht oben links
		var row := 0
		for y in range(8, s, 6):
			var off := 0 if row % 2 == 0 else 4
			for x in range(-off, s, 8):
				_rect(img, x, y, 8, 6, base)
				_hline(img, x, x + 7, y, base.lightened(0.18))
				_hline(img, x, x + 7, y + 5, base.darkened(0.3))
				for yy in range(y, y + 6):
					_px(img, x + 7, yy, base.darkened(0.3))
			row += 1
		if f == "aliens":
			_hline(img, 0, s - 1, 19, p.win)
		elif f == "plants":
			for i in 30:
				_px(img, rng.randi_range(0, s - 1), rng.randi_range(8, s - 1), Color("4e8a34"))
			for i in 8:
				_px(img, rng.randi_range(0, s - 1), rng.randi_range(8, s - 1), Color("e0d040"))
	_hline(img, 0, s - 1, s - 1, team)
	_hline(img, 0, s - 1, s - 2, team.darkened(0.3))


func _draw_gate(img: Image, f: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	var s := img.get_width()
	var dx := 7
	var dw := s - 14
	for y in range(11, s - 2):
		for x in range(dx, dx + dw):
			var top := 11 + int(4.0 * (1.0 - pow((x - s / 2.0) / (dw / 2.0), 2)))
			if y >= 15 - (top - 11):
				_px(img, x, y, p.door)
	if f == "mammals":
		for x in range(dx + 2, dx + dw, 4):
			for y in range(14, s - 2):
				_px(img, x, y, p.door.lightened(0.15))
	else:
		_hline(img, dx, dx + dw - 1, 14, p.win)
	_rect(img, s / 2 - 5, 3, 10, 7, team)
	_hline(img, s / 2 - 5, s / 2 + 4, 3, team.lightened(0.25))


func _draw_tower(img: Image, f: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	var w := img.get_width()
	var h := img.get_height()
	var body: Color = p.stone if f != "plants" else p.wall
	_rect(img, 6, 14, w - 12, h - 14, body)
	_rect(img, w - 11, 14, 5, h - 14, body.darkened(0.22))
	_rect(img, 6, 14, 1, h - 14, body.lightened(0.18))
	for y in range(18, h, 7):
		_hline(img, 6, w - 7, y, body.darkened(0.15))
	# Zinnen / Spitze
	match f:
		"aliens":
			for y in range(0, 14):
				var half := int(y * 0.6) + 2
				_hline(img, w / 2 - half, w / 2 + half, y, p.stone.lightened(0.1) if y % 3 else p.win)
			_rect(img, w / 2 - 2, 0, 4, 4, Color("ff70ff"))
		"plants":
			for y in range(0, 16):
				for x in range(2, w - 2):
					var nx := (x + 0.5 - w / 2.0) / (w / 2.0 - 2.0)
					var ny := (y + 0.5 - 8.0) / 8.0
					if nx * nx + ny * ny <= 1.0:
						_px(img, x, y, p.roof if nx + ny < 0.3 else p.roof_d)
			_px(img, 10, 5, Color("ff86b8"))
			_px(img, 21, 8, Color("ff86b8"))
		_:
			_rect(img, 4, 9, w - 8, 6, body.lightened(0.05))
			for x in range(4, w - 4, 6):
				_rect(img, x, 4, 4, 5, body)
				_hline(img, x, x + 3, 4, body.lightened(0.2))
	# Schießscharte und Team
	_rect(img, w / 2 - 1, 22, 3, 8, p.out if f != "aliens" else p.win)
	_rect(img, 8, h - 18, w - 16, 4, team)
	_hline(img, 8, w - 9, h - 18, team.lightened(0.25))


func _draw_farm(img: Image, f: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	var s := img.get_width()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(f + "farm")
	_rect(img, 2, 2, s - 4, s - 4, Color("6a4a2a"))
	for y in range(6, s - 4, 6):
		_hline(img, 3, s - 4, y, Color("4e3420"))
		_hline(img, 3, s - 4, y + 1, Color("7a5a36"))
		for x in range(5, s - 5, 4):
			var c: Color = p.crop
			_px(img, x, y - 1, c)
			_px(img, x, y - 2, c.darkened(0.15))
			_px(img, x + 1, y - 3, c.lightened(0.2))
			if rng.randf() < 0.5:
				_px(img, x - 1, y - 3, c)
	# Zaun
	for x in range(0, s, 2):
		_px(img, x, 0, Color("a07a48"))
		_px(img, x, s - 1, Color("7a5a36"))
	for y in range(0, s, 2):
		_px(img, 0, y, Color("a07a48"))
		_px(img, s - 1, y, Color("7a5a36"))
	for c in [Vector2i(0, 0), Vector2i(s - 2, 0), Vector2i(0, s - 2), Vector2i(s - 2, s - 2)]:
		_rect(img, c.x, c.y, 2, 2, Color("5a3a1a"))
	_rect(img, 3, 3, 6, 4, team)


func minimap_image(world) -> Image:
	var w: int = world.W
	var h: int = world.H
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var t: int = world.terrain[y * w + x]
			var c := Color("4e8e32")
			if t == 1:
				c = Color("2a5aa0")
			elif t == 2:
				c = Color("d0c088")
			img.set_pixel(x, y, c)
	var cols := {"tree": Color("1e5a1a"), "gold": Color("f0d040"), "stone": Color("b0b0b8"), "berry": Color("d04070")}
	for cell in world.resources:
		img.set_pixel(cell.x, cell.y, cols[world.resources[cell]["kind"]])
	if world.fog_enabled:
		for y in h:
			for x in w:
				var i := y * w + x
				if world.explored[i] == 0:
					img.set_pixel(x, y, Color("06060c"))
				elif world.vis[i] == 0:
					img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.55))
	return img


# ---------------------------------------------------------------- Mal-Werkzeuge (32 px)

const S := 32

# Figuren-Paletten je Volk
const CHAR := {
	"mammals": {"skin": Color("b07a48"), "skin2": Color("ead0a8"), "cloth2": Color("5e4228"), "metal": Color("c8ccd6"), "wood": Color("8a5a30"), "accent": Color("e8d8b0"), "eye": Color("141010"), "out": Color("22140a"), "mount": Color("8a8a94"), "mount2": Color("d8d8de")},
	"aliens": {"skin": Color("7ed46a"), "skin2": Color("c0f4a8"), "cloth2": Color("4a3072"), "metal": Color("8ef0ff"), "wood": Color("586078"), "accent": Color("ff70ff"), "eye": Color("0c0c16"), "out": Color("0e1424"), "mount": Color("7a7aa8"), "mount2": Color("30d8ff")},
	"plants": {"skin": Color("5aa842"), "skin2": Color("b0e278"), "cloth2": Color("7b5a2e"), "metal": Color("e2d24a"), "wood": Color("6a4a24"), "accent": Color("ff86b8"), "eye": Color("f8f040"), "out": Color("12240e"), "mount": Color("8a6a22"), "mount2": Color("d0aa48")},
}

# Arm-Winkel (Grad, 0 = rechts, 90 = unten) je Werkzeug, Richtung und Frame 0..3
# Frame 1 = ausgeholt, Frame 3 = Treffer. Der Schlag geht immer in Blickrichtung.
const SWING := {
	"axe": {"e": [0.0, -135.0, -50.0, 35.0], "s": [20.0, -100.0, -10.0, 75.0], "n": [60.0, 120.0, 10.0, -80.0]},
	"pick": {"e": [0.0, -135.0, -50.0, 40.0], "s": [20.0, -100.0, -10.0, 80.0], "n": [60.0, 120.0, 10.0, -80.0]},
	"hammer": {"e": [-10.0, -110.0, -45.0, 25.0], "s": [20.0, -80.0, -10.0, 65.0], "n": [50.0, 110.0, 10.0, -70.0]},
	"hoe": {"e": [10.0, -80.0, -20.0, 55.0], "s": [30.0, -60.0, 0.0, 80.0], "n": [50.0, 100.0, 20.0, -50.0]},
	"sword": {"e": [0.0, -120.0, -40.0, 30.0], "s": [20.0, -90.0, -10.0, 70.0], "n": [60.0, 110.0, 10.0, -70.0]},
	"basket": {"e": [15.0, -5.0, 25.0, 5.0], "s": [70.0, 45.0, 80.0, 55.0], "n": [-70.0, -45.0, -80.0, -55.0]},
}
const TOOL_LEN := {"axe": 9.0, "pick": 9.0, "hammer": 8.0, "hoe": 10.0, "sword": 9.0}


func _new(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _p(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _box(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var col := c
			if xx == x + w - 1 or yy == y + h - 1:
				col = c.darkened(0.28)
			elif xx == x or yy == y:
				col = c.lightened(0.16)
			_p(img, xx, yy, col)


func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, shade := true) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var col := c
			if shade:
				var l := -(nx * 0.55 + ny * 0.85)
				if l > 0.5:
					col = c.lightened(0.22)
				elif l < -0.45:
					col = c.darkened(0.28)
			_p(img, x, y, col)


func _line(img: Image, a: Vector2, b: Vector2, c: Color, w := 1) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	var off := (w - 1) * 0.5
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for oy in w:
			for ox in w:
				_p(img, int(round(p.x - off)) + ox, int(round(p.y - off)) + oy, c)


## Dunkler Umriss um alle sichtbaren Pixel
func _outline_img(img: Image, c: Color) -> void:
	var src: Image = img.duplicate()
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and src.get_pixel(n.x, n.y).a > 0.1:
					img.set_pixel(x, y, c)
					break


func _dir_vec(deg: float) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(deg))


# ---------------------------------------------------------------- Figuren

## Ein Animations-Frame einer Einheit.
## dir: "s" (zum Betrachter), "n" (weg), "e" (rechts; links = gespiegelt)
## pose: idle, walk, work, attack, carry_idle, carry_walk
func unit_frame(f: String, kind: String, team: int, dir: String, pose: String, frame: int, tool := "", carry := "") -> Texture2D:
	var key := "uf|%s|%s|%d|%s|%s|%d|%s|%s" % [f, kind, team, dir, pose, frame, tool, carry]
	if _cache.has(key):
		return _cache[key]
	var img := _new(S, S)
	match kind:
		"cavalry":
			_draw_cavalry(img, f, team, dir, pose, frame)
		"siege":
			_draw_siege(img, f, team, pose, frame)
		_:
			_draw_humanoid(img, f, kind, team, dir, pose, frame, tool, carry)
	_outline_img(img, CHAR[f]["out"])
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


func unit_tex(faction: String, kind: String, team: int) -> Texture2D:
	return unit_frame(faction, kind, team, "s", "idle", 0)


## Seitenansicht [Stehen, Schritt 1, Schritt 2] – für Titel-Parade und Cover
func unit_frames(faction: String, kind: String, team: int) -> Array:
	return [unit_frame(faction, kind, team, "e", "idle", 0), unit_frame(faction, kind, team, "e", "walk", 0), unit_frame(faction, kind, team, "e", "walk", 2)]


func _legs(img: Image, P: Dictionary, side: bool, lp: int) -> void:
	var pants: Color = P["cloth2"]
	var boot: Color = pants.darkened(0.45)
	if side:
		var front := Vector2(15, 30)
		var back := Vector2(15, 30)
		if lp == 0:
			front = Vector2(19, 30)
			back = Vector2(11, 30)
		elif lp == 2:
			front = Vector2(11, 30)
			back = Vector2(19, 30)
		_line(img, Vector2(15, 23), back, pants.darkened(0.25), 3)
		_line(img, back + Vector2(0, -1), back + Vector2(2, 0), boot, 2)
		_line(img, Vector2(15, 23), front, pants, 3)
		_line(img, front + Vector2(0, -1), front + Vector2(2, 0), boot, 2)
	else:
		var lh := 6 if lp == 0 else 7
		var rh := 6 if lp == 2 else 7
		_box(img, 12, 24, 3, lh, pants)
		_box(img, 17, 24, 3, rh, pants)
		_box(img, 12, 23 + lh - 1, 3, 2, boot)
		_box(img, 17, 23 + rh - 1, 3, 2, boot)


func _torso(img: Image, P: Dictionary, tc: Color, kind: String, f: String, dir: String) -> void:
	var side := dir == "e"
	var x0 := 12 if side else 11
	var w := 8 if side else 10
	_box(img, x0, 14, w, 10, tc)
	for x in range(x0, x0 + w):
		_p(img, x, 21, P["cloth2"])
	match kind:
		"spear":
			_box(img, x0 + 1, 15, w - 2, 5, P["metal"])
			if f == "plants":
				for x in range(x0 + 1, x0 + w - 1, 2):
					_p(img, x, 14, P["metal"].lightened(0.3))
		"archer":
			if dir == "s":
				_line(img, Vector2(x0, 14), Vector2(x0 + w - 1, 21), P["cloth2"], 1)
		"villager":
			if f == "mammals" and dir != "n":
				_line(img, Vector2(x0 + 1, 14), Vector2(x0 + w - 2, 14), P["skin2"], 1)
	if f == "plants":
		# Moos- und Blattmuster
		_p(img, x0 + 2, 17, P["skin2"])
		_p(img, x0 + w - 3, 19, P["skin2"])


func _head(img: Image, f: String, P: Dictionary, dir: String, c: Vector2, s: float, kind: String) -> void:
	var skin: Color = P["skin"]
	var side := dir == "e"
	match f:
		"mammals":
			# Ohren
			if side:
				_ell(img, c.x - 2 * s, c.y - 5 * s, 1.6 * s, 2.4 * s, skin)
			else:
				_ell(img, c.x - 4 * s, c.y - 5 * s, 1.6 * s, 2.4 * s, skin)
				_ell(img, c.x + 4 * s, c.y - 5 * s, 1.6 * s, 2.4 * s, skin)
				if dir == "s":
					_p(img, int(c.x - 4 * s), int(c.y - 5 * s), Color("e0a0a0"))
					_p(img, int(c.x + 4 * s), int(c.y - 5 * s), Color("e0a0a0"))
			_ell(img, c.x, c.y, 5.2 * s, 5.0 * s, skin)
			if dir == "s":
				_ell(img, c.x, c.y + 2.2 * s, 2.6 * s, 1.8 * s, P["skin2"], false)
				_p(img, int(c.x), int(c.y + 1 * s), P["eye"])
				_p(img, int(c.x - 2.5 * s), int(c.y - 1 * s), P["eye"])
				_p(img, int(c.x + 2.5 * s), int(c.y - 1 * s), P["eye"])
			elif side:
				_ell(img, c.x + 5 * s, c.y + 1.2 * s, 2.2 * s, 1.6 * s, P["skin2"], false)
				_p(img, int(c.x + 7 * s), int(c.y + 0.5 * s), P["eye"])
				_p(img, int(c.x + 2.5 * s), int(c.y - 1 * s), P["eye"])
		"aliens":
			if side:
				_line(img, c + Vector2(0, -5) * s, c + Vector2(2, -9) * s, skin.darkened(0.2), 1)
				_box(img, int(c.x + 2 * s), int(c.y - 10 * s), 2, 2, P["accent"])
			else:
				_line(img, c + Vector2(-3, -5) * s, c + Vector2(-5, -9) * s, skin.darkened(0.2), 1)
				_line(img, c + Vector2(3, -5) * s, c + Vector2(5, -9) * s, skin.darkened(0.2), 1)
				_box(img, int(c.x - 6 * s), int(c.y - 10 * s), 2, 2, P["accent"])
				_box(img, int(c.x + 5 * s), int(c.y - 10 * s), 2, 2, P["accent"])
			_ell(img, c.x, c.y - 0.5 * s, 5.6 * s, 6.2 * s, skin)
			if dir == "s":
				_ell(img, c.x - 2.4 * s, c.y + 0.5 * s, 1.5 * s, 2.2 * s, P["eye"], false)
				_ell(img, c.x + 2.4 * s, c.y + 0.5 * s, 1.5 * s, 2.2 * s, P["eye"], false)
				_p(img, int(c.x - 2.8 * s), int(c.y - 0.5 * s), Color("ff4040"))
				_p(img, int(c.x + 2.0 * s), int(c.y - 0.5 * s), Color("ff4040"))
			elif side:
				_ell(img, c.x + 3 * s, c.y + 0.5 * s, 1.5 * s, 2.2 * s, P["eye"], false)
				_p(img, int(c.x + 3 * s), int(c.y - 0.5 * s), Color("ff4040"))
		"plants":
			_ell(img, c.x, c.y, 5.0 * s, 5.0 * s, skin)
			# Blätterkrone und Blüte
			var leaf: Color = skin.darkened(0.15)
			if side:
				_ell(img, c.x - 3 * s, c.y - 4.5 * s, 3.2 * s, 1.6 * s, leaf)
				_ell(img, c.x + 1 * s, c.y - 5.5 * s, 2.6 * s, 1.4 * s, leaf.lightened(0.1))
			else:
				_ell(img, c.x - 3.5 * s, c.y - 4.5 * s, 3.2 * s, 1.6 * s, leaf)
				_ell(img, c.x + 3.5 * s, c.y - 4.5 * s, 3.2 * s, 1.6 * s, leaf)
			_ell(img, c.x + (1 if side else 0) * s, c.y - 6 * s, 1.8 * s, 1.8 * s, P["accent"])
			_p(img, int(c.x + (1 if side else 0) * s), int(c.y - 6 * s), Color("ffe060"))
			if dir == "s":
				_p(img, int(c.x - 2 * s), int(c.y), P["eye"])
				_p(img, int(c.x + 2 * s), int(c.y), P["eye"])
				_p(img, int(c.x), int(c.y + 2 * s), skin.darkened(0.4))
			elif side:
				_p(img, int(c.x + 3 * s), int(c.y), P["eye"])
	# Helm der Speerträger
	if kind == "spear":
		var m: Color = P["metal"]
		match f:
			"mammals":
				for x in range(int(c.x - 5 * s), int(c.x + 5 * s) + 1):
					for y in range(int(c.y - 5 * s), int(c.y - 1 * s)):
						if Vector2((x - c.x) / (5.2 * s), (y - c.y) / (5.0 * s)).length() <= 1.0:
							_p(img, x, y, m if x < c.x + 2 * s else m.darkened(0.25))
			"aliens":
				if dir != "n":
					_line(img, Vector2(c.x - 5 * s, c.y), Vector2(c.x + 5 * s, c.y), m, 1)
			"plants":
				for i in 4:
					_p(img, int(c.x - 4 * s + i * 2.6 * s), int(c.y - 5 * s), m)


func _arm(img: Image, P: Dictionary, tc: Color, shoulder: Vector2, deg: float, dark := false) -> Vector2:
	var d := _dir_vec(deg)
	var sleeve: Color = tc.darkened(0.25) if dark else tc
	var skin: Color = P["skin"].darkened(0.25) if dark else P["skin"]
	var elbow := shoulder + d * 3.0
	var hand := shoulder + d * 7.0
	_line(img, shoulder, elbow, sleeve, 3)
	_line(img, elbow, hand, skin, 2)
	return hand


func _tool(img: Image, P: Dictionary, tool: String, hand: Vector2, deg: float) -> void:
	var d := _dir_vec(deg)
	var n := d.rotated(PI / 2.0)
	var wood: Color = P["wood"]
	var metal: Color = P["metal"]
	var L: float = TOOL_LEN.get(tool, 9.0)
	var tip := hand + d * L
	match tool:
		"sword":
			_line(img, hand + n * -2 + d, hand + n * 2 + d, wood, 1)
			_line(img, hand + d * 2, tip, metal, 2)
			_p(img, int(tip.x), int(tip.y), metal.lightened(0.4))
		"basket":
			_ell(img, hand.x, hand.y + 1, 3.5, 2.5, wood)
			_p(img, int(hand.x - 1), int(hand.y - 1), Color("d03060"))
			_p(img, int(hand.x + 1), int(hand.y - 1), Color("e04070"))
		_:
			_line(img, hand - d, tip, wood, 1)
			match tool:
				"axe":
					for i in 4:
						_line(img, tip - d * i, tip - d * i + n * 3.5, metal if i > 0 else metal.lightened(0.3), 1)
				"pick":
					_line(img, tip - n * 4 - d, tip + n * 4 - d, metal, 1)
					_p(img, int((tip + n * 4 - d * 2).x), int((tip + n * 4 - d * 2).y), metal.lightened(0.3))
				"hammer":
					for i in 3:
						_line(img, tip - d * i - n * 2, tip - d * i + n * 2, metal.darkened(0.1 * i), 1)
				"hoe":
					_line(img, tip, tip + n * 4 - d, metal, 1)
					_line(img, tip - d, tip + n * 4 - d * 2, metal.darkened(0.2), 1)


func _carry_load(img: Image, P: Dictionary, carry: String, c: Vector2) -> void:
	match carry:
		"wood":
			_box(img, int(c.x - 7), int(c.y - 1), 14, 3, Color("8a5a30"))
			_box(img, int(c.x - 6), int(c.y - 3), 12, 3, Color("9a6a3a"))
			_p(img, int(c.x - 7), int(c.y), Color("d0a070"))
			_p(img, int(c.x - 6), int(c.y - 2), Color("d0a070"))
		"gold":
			_ell(img, c.x, c.y - 1, 4.5, 3.2, Color("b08a3a"))
			for o in [Vector2(-2, -3), Vector2(1, -3), Vector2(3, -2), Vector2(-1, -2)]:
				_p(img, int(c.x + o.x), int(c.y + o.y), Color("ffe050"))
		"stone":
			_box(img, int(c.x - 4), int(c.y - 4), 8, 5, Color("a8a8b2"))
			_line(img, Vector2(c.x - 2, c.y - 3), Vector2(c.x + 1, c.y - 1), Color("6a6a74"), 1)
		_:
			_ell(img, c.x, c.y, 5.0, 2.6, Color("a07040"))
			for i in 5:
				_p(img, int(c.x - 3 + i * 1.5), int(c.y - 2 - (i % 2)), Color("d03060"))


func _draw_humanoid(img: Image, f: String, kind: String, team: int, dir: String, pose: String, frame: int, tool: String, carry: String) -> void:
	var P: Dictionary = CHAR[f]
	var tc: Color = TEAM[team]
	var side := dir == "e"
	var walking := pose == "walk" or pose == "carry_walk"
	var carrying := pose == "carry_walk" or pose == "carry_idle"
	var lp := frame % 4 if walking else -1
	var swing := sin(frame * PI / 2.0) * 22.0 if walking else 0.0
	_legs(img, P, side, lp)

	# Winkel für vorderen (Werkzeug-)Arm und hinteren Arm
	var near := 95.0 if side else 80.0
	var far := 85.0 if side else 100.0
	var weapon := ""
	var weapon_deg := -90.0
	if walking:
		near += swing
		far -= swing
	if carrying:
		near = -80.0 if side else -60.0
		far = -100.0 if side else -120.0
	elif pose == "work" and SWING.has(tool):
		near = SWING[tool][dir][frame % 4]
	elif pose == "attack" and kind == "villager":
		tool = "sword"
		near = SWING["sword"][dir][[1, 2, 3][frame % 3]]
	if kind == "spear":
		weapon = "spear"
		near = 70.0 if side else 85.0
		if pose == "attack":
			near = [60.0, 0.0, 15.0][frame % 3] if side else ([60.0, 90.0, 80.0][frame % 3] if dir == "s" else [-60.0, -90.0, -80.0][frame % 3])
	elif kind == "archer":
		weapon = "bow"
		near = 20.0 if side else 75.0
		if pose == "attack":
			near = 0.0 if side else (85.0 if dir == "s" else -85.0)

	var shoulder_near := Vector2(15, 16) if side else Vector2(21, 16)
	var shoulder_far := Vector2(17, 16) if side else Vector2(10, 16)

	# Hinter dem Körper: Köcher, ferner Arm (Seitenansicht)
	if kind == "archer" and dir != "s":
		var qx := 11 if side else 18
		_box(img, qx, 12, 3, 9, P["wood"])
		_p(img, qx, 11, Color("e0e0e0"))
		_p(img, qx + 2, 10, Color("e0e0e0"))
	if side:
		_arm(img, P, tc, shoulder_far, far, true)

	_torso(img, P, tc, kind, f, dir)
	if kind == "spear" and side:
		# Schild vor dem Körper
		_box(img, 17, 15, 5, 8, P["accent"].darkened(0.1))
		_box(img, 18, 16, 3, 6, tc.darkened(0.15))
	var head_c := Vector2(17, 9) if side else Vector2(16, 9)
	if f == "aliens":
		head_c.y = 8
	_head(img, f, P, dir, head_c, 1.0, kind)

	if not side:
		var fh := _arm(img, P, tc, shoulder_far, far, dir == "n")
		if kind == "spear":
			_box(img, int(fh.x) - 3, 15, 5, 8, P["accent"].darkened(0.1))
			_box(img, int(fh.x) - 2, 16, 3, 6, tc.darkened(0.15))
		if carrying:
			pass
	var hand := _arm(img, P, tc, shoulder_near, near, false)

	if weapon == "spear":
		var d := Vector2(0, -1)
		var length := 22.0
		if pose == "attack":
			d = Vector2(1, 0) if side else (Vector2(0, 1) if dir == "s" else Vector2(0, -1))
			length = 18.0 if side else 13.0
		var a := hand - d * length * 0.3
		var b := hand + d * length * 0.7
		_line(img, a, b, P["wood"], 1)
		_line(img, b - d * 3, b, P["metal"], 2)
	elif weapon == "bow":
		var fwd := Vector2(1, 0)
		if pose == "attack" and not side:
			fwd = Vector2(0, 1) if dir == "s" else Vector2(0, -1)
		var up := fwd.rotated(-PI / 2.0)
		var top := hand + up * 6 - fwd
		var bot := hand - up * 6 - fwd
		var mid := hand + fwd * 2
		_line(img, top, mid, P["wood"], 1)
		_line(img, mid, bot, P["wood"], 1)
		var pull := 0.0
		if pose == "attack":
			pull = [3.0, 6.0, 0.0][frame % 3]
		var string_mid := hand - fwd * (1.0 + pull)
		_line(img, top, string_mid, Color("e8e0d0"), 1)
		_line(img, string_mid, bot, Color("e8e0d0"), 1)
		if pull > 0.0:
			_line(img, string_mid, string_mid + fwd * 9, Color("d8c8a0"), 1)
			_p(img, int((string_mid + fwd * 9).x), int((string_mid + fwd * 9).y), P["metal"])
	elif tool != "" and not carrying:
		_tool(img, P, tool, hand, near)

	if carrying and carry != "":
		_carry_load(img, P, carry, Vector2(head_c.x, 3))


func _draw_cavalry(img: Image, f: String, team: int, dir: String, pose: String, frame: int) -> void:
	var P: Dictionary = CHAR[f]
	var tc: Color = TEAM[team]
	var m: Color = P["mount"]
	var m2: Color = P["mount2"]
	var lp := frame % 4 if pose == "walk" else 1
	var g: float = [2.0, 0.0, -2.0, 0.0][lp]
	if dir == "e":
		match f:
			"mammals":
				for lx: float in [8.0, 11.0, 19.0, 22.0]:
					var o := g if int(lx) % 2 == 0 else -g
					_line(img, Vector2(lx, 23), Vector2(lx + o, 30), m.darkened(0.2), 2)
				_line(img, Vector2(6, 19), Vector2(1, 15), m, 2)
				_ell(img, 15, 21, 10, 4.5, m)
				_ell(img, 15, 23, 7, 2, m2, false)
				_ell(img, 24, 16, 4, 3.2, m)
				_box(img, 26, 16, 5, 3, m2)
				_ell(img, 23, 12, 1.4, 2.2, m)
				_p(img, 25, 15, P["eye"])
				_p(img, 30, 16, P["eye"])
			"aliens":
				_ell(img, 16, 25, 12, 3.2, m)
				_ell(img, 16, 24, 7, 1.5, m.lightened(0.3), false)
				for x in range(6, 27):
					if (x + frame) % 3 != 0:
						_p(img, x, 29, m2)
			"plants":
				for i in 3:
					var o := g if i % 2 == 0 else -g
					_line(img, Vector2(9 + i * 6, 23), Vector2(7 + i * 6 + o, 30), m.darkened(0.35), 1)
				_ell(img, 15, 21, 10, 5.5, m)
				_line(img, Vector2(15, 16), Vector2(15, 26), m.darkened(0.3), 1)
				_ell(img, 25, 22, 3.2, 2.6, m.darkened(0.2))
				_line(img, Vector2(26, 20), Vector2(30, 14), m2, 1)
				_p(img, 27, 21, P["eye"])
		# Reiter
		_line(img, Vector2(14, 15), Vector2(14, 20), P["cloth2"], 2)
		_box(img, 12, 8, 7, 8, tc)
		_head(img, f, P, "e", Vector2(16, 5), 0.72, "cavalry")
		var hand := Vector2(19, 13)
		_line(img, Vector2(16, 10), hand, P["skin"], 2)
		var d := Vector2(1, -0.55).normalized() if pose != "attack" else Vector2(1, 0.15).normalized()
		_line(img, hand - d * 5, hand + d * 13, P["wood"], 1)
		_line(img, hand + d * 10, hand + d * 13, P["metal"], 2)
	else:
		var front := dir == "s"
		match f:
			"aliens":
				_ell(img, 16, 26, 11, 3.2, m)
				for x in range(7, 26):
					if (x + frame) % 3 != 0:
						_p(img, x, 29, m2)
			_:
				for i in 4:
					var lx: float = [11.0, 13.0, 19.0, 21.0][i]
					var h := 30.0 - (absf(g) if i % 2 == lp % 2 else 0.0)
					_line(img, Vector2(lx, 24), Vector2(lx, h), m.darkened(0.25), 2)
				_ell(img, 16, 22, 6.5 if f == "mammals" else 8.0, 6.5, m)
				if front:
					_ell(img, 16, 26, 3.6, 3, m)
					_box(img, 14, 27, 5, 3, m2)
					_p(img, 14, 25, P["eye"])
					_p(img, 18, 25, P["eye"])
				elif f == "mammals":
					_line(img, Vector2(16, 26), Vector2(16, 30), m, 2)
		_box(img, 12, 9, 8, 8, tc)
		_head(img, f, P, dir, Vector2(16, 5), 0.72, "cavalry")
		_line(img, Vector2(22, 1), Vector2(22, 18), P["wood"], 1)
		_line(img, Vector2(22, 0), Vector2(22, 3), P["metal"], 2)


func _draw_siege(img: Image, f: String, team: int, pose: String, frame: int) -> void:
	var P: Dictionary = CHAR[f]
	var tc: Color = TEAM[team]
	var push := 3.0 if pose == "attack" and frame % 3 == 1 else 0.0
	match f:
		"mammals":
			_box(img, 3, 20, 26, 4, P["wood"])
			for y in range(8, 20):
				var half := int((y - 8) * 1.15)
				for x in range(16 - half, 16 + half + 1):
					var stripe := (x / 3) % 2 == 0
					_p(img, x, y, tc if stripe else tc.darkened(0.2))
			_box(img, 2 + int(push), 15, 24, 4, P["wood"].darkened(0.1))
			_box(img, 26 + int(push), 14, 5, 6, P["metal"])
			for wx: float in [9.0, 23.0]:
				_ell(img, wx, 27, 4, 4, P["wood"].darkened(0.2))
				var a := frame * PI / 4.0
				_line(img, Vector2(wx, 27) + Vector2(cos(a), sin(a)) * 3, Vector2(wx, 27) - Vector2(cos(a), sin(a)) * 3, P["wood"].lightened(0.2), 1)
				_p(img, int(wx), 27, P["metal"])
		"aliens":
			var lp := frame % 4
			var feet := [Vector2(5, 31), Vector2(16, 31), Vector2(27, 31)]
			for i in 3:
				var o: float = float([2.0, 0.0, -2.0, 0.0][lp]) * (1 if i != 1 else -1)
				var foot: Vector2 = feet[i] + Vector2(o, 0)
				var knee := Vector2(lerpf(16, foot.x, 0.6), 20)
				_line(img, Vector2(16, 12), knee, Color("6a6a88"), 2)
				_line(img, knee, foot, Color("6a6a88"), 2)
			_ell(img, 16, 11, 13, 4.5, Color("8a8aa8"))
			_ell(img, 16, 7, 5.5, 3.5, P["metal"])
			for x in range(5, 28):
				_p(img, x, 12, tc)
			_p(img, 8, 10, P["accent"])
			_p(img, 24, 10, P["accent"])
			if push > 0.0:
				_ell(img, 29, 11, 2.5, 2.5, Color.WHITE, false)
		"plants":
			var lp2 := frame % 4
			for i in 5:
				var x0 := 6.0 + i * 5.0
				var o: float = float([2.0, 0.0, -2.0, 0.0][lp2]) * (1 if i % 2 == 0 else -1)
				_line(img, Vector2(x0, 23), Vector2(x0 + o, 31), P["wood"].darkened(0.35), 2)
			_box(img, 3 + int(push), 13, 26, 10, P["wood"])
			for x in range(5, 28, 4):
				_line(img, Vector2(x + push, 14), Vector2(x + push, 21), P["wood"].darkened(0.3), 1)
			_ell(img, 28 + push, 18, 3.5, 4.5, P["wood"].darkened(0.15))
			_ell(img, 10, 11, 5, 3, P["skin"])
			_ell(img, 20, 10, 6, 3.2, P["skin"])
			_p(img, 12, 9, P["accent"])
			_p(img, 22, 8, P["accent"])
			for x in range(3, 29):
				_p(img, x + int(push), 17, tc)
				_p(img, x + int(push), 18, tc.darkened(0.2))


# ---------------------------------------------------------------- Ressourcen (Bäume schrumpfen beim Fällen)

const RES_MAX := {"tree": 100.0, "gold": 800.0, "stone": 350.0, "berry": 125.0}


func res_stage(r: Dictionary) -> int:
	var frac: float = float(r["amount"]) / float(RES_MAX.get(r["kind"], 100.0))
	if frac > 0.66:
		return 0
	if frac > 0.33:
		return 1
	return 2


## Bäume: 32×48 (ragen über ihre Kachel), alles andere 32×32
func resource_tex(kind: String, variant: int, stage := 0) -> Texture2D:
	var key := "r|%s|%d|%d" % [kind, variant, stage]
	if _cache.has(key):
		return _cache[key]
	var img: Image
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match kind:
		"tree":
			img = _tree_img(variant, stage, rng)
		"stump":
			img = _new(S, 48)
			var w := Color("6a4424")
			_box(img, 12, 40, 8, 7, w)
			_ell(img, 16, 40, 4, 1.6, w.lightened(0.35), false)
			_p(img, 16, 40, w.darkened(0.2))
			_p(img, 10, 46, w.darkened(0.2))
			_p(img, 21, 46, w.darkened(0.2))
			_outline_img(img, Color("2a1a0c"))
		"gold", "stone":
			img = _rocks_img(kind, stage, rng)
		_:
			img = _bush_img(stage, rng)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


func _tree_img(variant: int, stage: int, rng: RandomNumberGenerator) -> Image:
	var img := _new(S, 48)
	var leaf: Color = [Color("3e8a2e"), Color("4a9632"), Color("367a2c"), Color("5a9a38")][variant % 4]
	var trunk := Color("6a4424")
	var full: float = [1.0, 0.78, 0.5][stage]
	var holes: float = [0.0, 0.12, 0.28][stage]
	var pine := variant % 2 == 0
	if pine:
		_box(img, 14, 37, 4, 10, trunk)
		var tiers := 4 if stage < 2 else 2
		for i in tiers:
			var base_y := 39 - i * 8
			var half := (12.0 - i * 2.4) * full
			var apex := base_y - 11
			for y in range(apex, base_y + 1):
				var w := half * float(y - apex) / float(base_y - apex)
				for x in range(int(16 - w), int(16 + w) + 1):
					if rng.randf() < holes:
						continue
					var col := leaf
					if x < 16 - w * 0.35:
						col = leaf.lightened(0.18)
					elif x > 16 + w * 0.3 or y == base_y:
						col = leaf.darkened(0.25)
					_p(img, x, y, col)
	else:
		_box(img, 13, 30, 6, 17, trunk)
		_p(img, 12, 46, trunk.darkened(0.2))
		_p(img, 19, 46, trunk.darkened(0.2))
		_line(img, Vector2(16, 34), Vector2(21, 28), trunk, 2)
		var blobs := [Vector4(16, 20, 11, 9), Vector4(8, 25, 7, 6), Vector4(24, 25, 7, 6), Vector4(11, 13, 7, 6), Vector4(21, 13, 7, 6)]
		var count: int = [5, 3, 1][stage]
		for i in count:
			var b: Vector4 = blobs[i]
			_ell(img, b.x, b.y + (1.0 - full) * 8.0, b.z * full, b.w * full, leaf)
		if holes > 0.0:
			for i in int(holes * 120):
				var x := rng.randi_range(4, 28)
				var y := rng.randi_range(6, 30)
				if img.get_pixel(x, y).a > 0.1 and img.get_pixel(x, y).g > img.get_pixel(x, y).r:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		for i in 10 * count:
			var x := rng.randi_range(5, 26)
			var y := rng.randi_range(6, 28)
			if img.get_pixel(x, y).a > 0.1 and img.get_pixel(x, y).g > img.get_pixel(x, y).r:
				img.set_pixel(x, y, leaf.lightened(0.28))
	_outline_img(img, Color("15300e"))
	return img


func _rocks_img(kind: String, stage: int, rng: RandomNumberGenerator) -> Image:
	var img := _new(S, S)
	var rock := Color("8a8070") if kind == "gold" else Color("b4b4bc")
	var all := [Vector4(9, 22, 6.5, 5), Vector4(21, 21, 7, 6), Vector4(15, 14, 6, 5), Vector4(24, 27, 5, 3.5), Vector4(8, 27, 5, 3.5)]
	var count: int = [5, 3, 1][stage]
	for i in count:
		var b: Vector4 = all[i] if stage < 2 else Vector4(16, 22, 7, 5.5)
		_ell(img, b.x, b.y, b.z, b.w, rock)
		for k in 6:
			var x := int(b.x + rng.randf_range(-b.z * 0.6, b.z * 0.6))
			var y := int(b.y + rng.randf_range(-b.w * 0.6, b.w * 0.5))
			if kind == "gold":
				_p(img, x, y, Color("ffe050"))
				_p(img, x + 1, y, Color("fff4b0"))
			elif k < 2:
				_line(img, Vector2(x, y), Vector2(x + 2, y + 1), rock.darkened(0.35), 1)
	_outline_img(img, Color("2a2622"))
	return img


func _bush_img(stage: int, rng: RandomNumberGenerator) -> Image:
	var img := _new(S, S)
	var leaf := Color("3a7a2a")
	_ell(img, 16, 20, 11, 8, leaf)
	_ell(img, 9, 23, 6, 5, leaf.darkened(0.08))
	_ell(img, 23, 23, 6, 5, leaf.darkened(0.08))
	var berries: int = [11, 5, 1][stage]
	for i in berries:
		var x := rng.randi_range(7, 24)
		var y := rng.randi_range(15, 26)
		_p(img, x, y, Color("c82858"))
		_p(img, x + 1, y, Color("e04070"))
		_p(img, x, y + 1, Color("9a1a40"))
	_outline_img(img, Color("16300e"))
	return img


# ---------------------------------------------------------------- Gelände (Kachelsatz)

## Atlas mit 8 Varianten je Geländetyp (Zeilen: Gras, Wasser, Sand), je 32×32
func terrain_atlas(seed_val: int) -> Image:
	var img := Image.create_empty(S * 8, S * 3, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for row in 3:
		for v in 8:
			var ox := v * S
			var oy := row * S
			match row:
				0:
					var base := Color("5c9c3c")
					img.fill_rect(Rect2i(ox, oy, S, S), base)
					for i in 40:
						img.set_pixel(ox + rng.randi_range(0, S - 1), oy + rng.randi_range(0, S - 1), [Color("4e8e32"), Color("6eac4a"), Color("528a34")][rng.randi() % 3])
					for i in rng.randi_range(2, 5):
						var x := ox + rng.randi_range(2, S - 3)
						var y := oy + rng.randi_range(4, S - 2)
						var tuft := Color("3e7a28")
						img.set_pixel(x, y, tuft)
						img.set_pixel(x - 1, y - 1, tuft)
						img.set_pixel(x + 1, y - 2, Color("78b850"))
						img.set_pixel(x, y - 2, tuft.lightened(0.2))
					if v >= 6:
						var fx := ox + rng.randi_range(4, S - 5)
						var fy := oy + rng.randi_range(4, S - 5)
						var fc: Color = [Color("f0e060"), Color("f4f4f4"), Color("e070a0")][v % 3]
						img.set_pixel(fx, fy, fc)
						img.set_pixel(fx + 1, fy, fc.darkened(0.2))
						img.set_pixel(fx, fy + 1, fc.darkened(0.2))
				1:
					img.fill_rect(Rect2i(ox, oy, S, S), Color("2a5aa0"))
					for i in 3:
						var x := ox + rng.randi_range(0, S - 8)
						var y := oy + rng.randi_range(2, S - 3)
						for k in rng.randi_range(4, 7):
							img.set_pixel(x + k, y, Color("4a80cc"))
						img.set_pixel(x + 2, y + 1, Color("3a6ab4"))
					for i in 12:
						img.set_pixel(ox + rng.randi_range(0, S - 1), oy + rng.randi_range(0, S - 1), Color("24508e"))
				2:
					img.fill_rect(Rect2i(ox, oy, S, S), Color("d6c48c"))
					for i in 50:
						img.set_pixel(ox + rng.randi_range(0, S - 1), oy + rng.randi_range(0, S - 1), [Color("c8b47a"), Color("e2d4a0"), Color("bca870")][rng.randi() % 3])
					if v % 3 == 0:
						var px := ox + rng.randi_range(3, S - 4)
						var py := oy + rng.randi_range(3, S - 4)
						img.set_pixel(px, py, Color("9a9488"))
						img.set_pixel(px + 1, py, Color("c0bab0"))
	return img


## Bild der Karte aus dem Kachelsatz (für das Cover)
func build_terrain_image(terrain: PackedByteArray, w: int, h: int, seed_val: int) -> Image:
	var atlas := terrain_atlas(seed_val)
	var img := Image.create_empty(w * S, h * S, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := terrain[y * w + x]
			var row := 0 if t == 0 else (1 if t == 1 else 2)
			var v := absi(hash(Vector2i(x, y) + Vector2i(seed_val, 0))) % 8
			img.blit_rect(atlas, Rect2i(v * S, row * S, S, S), Vector2i(x * S, y * S))
	return img
