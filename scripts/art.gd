extends Node
## Erzeugt sämtliche Pixelgrafik zur Laufzeit: Einheiten aus ASCII-Vorlagen,
## Gebäude prozedural je Volk, Gelände und Ressourcen.
## Eigene PNGs können später einfach statt dieser Texturen geladen werden.

const TEAM := [Color("3a78f0"), Color("e04040"), Color("40c060"), Color("e0c040")]

# Zeichen in den Vorlagen: o Umriss, s Haut/Fell, S Schatten, b Kleidung, h Holz/Griff,
# w Waffe, e Auge, a Akzent, m/M Reittier, t/T Teamfarbe.
const PAL := {
	"mammals": {"o": Color("2a1a10"), "s": Color("b07a48"), "S": Color("8a5a30"), "b": Color("6a4a2a"), "h": Color("7a5430"), "w": Color("d0d0d8"), "e": Color("101010"), "a": Color("e8d8b0"), "m": Color("8a8a90"), "M": Color("5a5a60")},
	"aliens": {"o": Color("101828"), "s": Color("80d870"), "S": Color("5aa850"), "b": Color("4a3070"), "h": Color("505868"), "w": Color("90f0ff"), "e": Color("ff2a2a"), "a": Color("ff70ff"), "m": Color("7a7aa0"), "M": Color("30d0ff")},
	"plants": {"o": Color("142810"), "s": Color("58a840"), "S": Color("3a7a2a"), "b": Color("7b5a2e"), "h": Color("5a3e1e"), "w": Color("e0d040"), "e": Color("f8f040"), "a": Color("ff80b0"), "m": Color("8a6a20"), "M": Color("4a3a10")},
}

# Kopfschmuck je Volk: Ohren, Antennen, Blätter
const OVERLAY := {
	"mammals": ["o....o", "so..os"],
	"aliens": ["a....a", ".o..o."],
	"plants": [".aa.s.", "..ss.."],
}
const HEAD := {"villager": Vector2i(5, 1), "spear": Vector2i(5, 1), "archer": Vector2i(5, 1), "cavalry": Vector2i(5, 0)}

const UNIT_T := {
	"villager": [
		"................",
		"................",
		"................",
		"......oooo......",
		".....osssso.....",
		".....oesseo.....",
		".....osssso.....",
		"......oSSo......",
		".....otttto.....",
		"....osttttso....",
		"....os.tt.so....",
		"......tTTt......",
		"......bbbb......",
		"......b..b......",
		".....oo..oo.....",
		"................",
	],
	"spear": [
		".............w..",
		"............www.",
		".............h..",
		"......oooo...h..",
		".....osssso..h..",
		".....oesseo..h..",
		".....osssso..h..",
		"......oSSo...h..",
		"..aaa.otttto.h..",
		"..aTa.ottttssh..",
		"..aTa..tttt..h..",
		"..aTa..tTTt..h..",
		"...a...bbbb..h..",
		".......b..b..h..",
		"......oo..oo....",
		"................",
	],
	"archer": [
		"................",
		"................",
		"..............h.",
		"......oooo....h.",
		".....osssso....h",
		".....oesseo....h",
		".....osssso....h",
		"......oSSo.....h",
		".....otttto..w.h",
		"....osttttsssswh",
		"....os.tt.....wh",
		"......tTTt.....h",
		"......bbbb.....h",
		"......b..b....h.",
		".....oo..oo...h.",
		"................",
	],
	"cavalry": [
		"................",
		"................",
		"......oooo......",
		".....osssso...w.",
		".....oesseo..w..",
		".....osssso.w...",
		"......oSSo.h....",
		".....ottttsh....",
		".....otTTto.....",
		"..M..mmmmmmmmm..",
		".MmmmmmmmmmmmmMo",
		"..mmmmmmmmmmmmeo",
		"..mmmmmmmmmmmmo.",
		"..MM.......MM...",
		"..oo.......oo...",
		"................",
	],
	"siege": [
		"................",
		"...........ww...",
		"..........whw...",
		".........h......",
		"........h..t....",
		".......h...tt...",
		"......h....t....",
		".....h..........",
		"..oooooooooooo..",
		"..ohhhhhhhhhho..",
		"..ohhaaaaaahho..",
		"..oooooooooooo..",
		"...ooo....ooo...",
		"...obo....obo...",
		"...ooo....ooo...",
		"................",
	],
}

# Laufanimation: ersetzt einzelne Zeilen der Grundvorlage (Zeile -> Inhalt)
const WALK := {
	"villager": [
		{12: "......bbbb......", 13: ".....b....b.....", 14: "....oo....oo...."},
		{12: "......bbbb......", 13: ".......bb.......", 14: "......oooo......"},
	],
	"spear": [
		{12: "...a...bbbb..h..", 13: "......b....b.h..", 14: ".....oo....oo..."},
		{12: "...a...bbbb..h..", 13: "........bb...h..", 14: ".......oooo....."},
	],
	"archer": [
		{12: "......bbbb.....h", 13: ".....b....b...h.", 14: "....oo....oo..h."},
		{12: "......bbbb.....h", 13: ".......bb.....h.", 14: "......oooo....h."},
	],
	"cavalry": [
		{13: ".M..M.....M..M..", 14: ".o..o.....o..o.."},
		{13: "...MM.....MM....", 14: "...oo.....oo...."},
	],
	"siege": [
		{12: "...obo....obo...", 13: "...ooo....ooo...", 14: "...obo....obo..."},
		{12: "...ooo....ooo...", 13: "...bob....bob...", 14: "...ooo....ooo..."},
	],
}

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

const TREE_PINE := [
	".......o........",
	"......oGo.......",
	".....oGgGo......",
	".....ogggo......",
	"....oGgggGo.....",
	"....oggGggo.....",
	"...oGgggggGo....",
	"...ogggGgggo....",
	"..oGggggggggo...",
	"..ogggGgggGgo...",
	".oGggggggggggo..",
	".ooooooooooooo..",
	"......obbo......",
	"......obbo......",
	".....obbbbo.....",
	"................",
]
const TREE_OAK := [
	"................",
	".....oooooo.....",
	"...ooggGgggoo...",
	"..oggGgggggGgo..",
	"..ogggggGggggo..",
	".oggGgggggggGgo.",
	".ogggggGggggggo.",
	".oGgggggggGgggo.",
	"..oggGgggggggo..",
	"...ooggggGgoo...",
	".....oobbooo....",
	"......obbo......",
	"......obbo......",
	".....obbbbo.....",
	"................",
	"................",
]
const ROCK := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"......oooo......",
	"....ooyyYyoo....",
	"...oyYyyyyyyo...",
	"..oyyyyYyyyyyo..",
	"..oyYyyyyyYyyo..",
	".oyyyyyoyyyyyyo.",
	".oyyYyyyyyyYyyo.",
	".oyyyyyyyyyyyyo.",
	"..oooooooooooo..",
	"................",
	"................",
]
const BUSH := [
	"................",
	"................",
	"................",
	"................",
	".....oooooo.....",
	"...oogrgggroo...",
	"..oggggrgggggo..",
	"..ogrggggrgrgo..",
	".oggggrggggggro.",
	".ogrgggggrggggo.",
	".oggggrgggggrgo.",
	"..oogggggggoo...",
	"....ooooooo.....",
	"................",
	"................",
	"................",
]
const TREE_PAL := {"o": Color("1e3a14"), "g": Color("3e8a2e"), "G": Color("5aaa40"), "b": Color("6a4424")}
const GOLD_PAL := {"o": Color("5a4418"), "y": Color("c89a30"), "Y": Color("fff0a0")}
const STONE_PAL := {"o": Color("3a3a40"), "y": Color("9a9aa2"), "Y": Color("dcdce4")}
const BUSH_PAL := {"o": Color("1a3a12"), "g": Color("3a7a2a"), "r": Color("c83060")}

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


func unit_tex(faction: String, kind: String, team: int) -> Texture2D:
	return unit_frames(faction, kind, team)[0]


## [Stehen, Schritt 1, Schritt 2]
func unit_frames(faction: String, kind: String, team: int) -> Array:
	var key := "uf_%s_%s_%d" % [faction, kind, team]
	if _cache.has(key):
		return _cache[key]
	var pal: Dictionary = PAL[faction].duplicate()
	pal["t"] = TEAM[team]
	pal["T"] = TEAM[team].darkened(0.35)
	var frames := []
	var variants: Array = [{}]
	variants.append_array(WALK.get(kind, []))
	for v in variants:
		var rows: Array = UNIT_T[kind].duplicate()
		for r in v:
			rows[r] = v[r]
		var img := _img_from(rows, pal, 16, 16)
		if HEAD.has(kind):
			var hp: Vector2i = HEAD[kind]
			_img_from(OVERLAY[faction], pal, 16, 16, hp.x, hp.y, img)
		frames.append(ImageTexture.create_from_image(img))
	_cache[key] = frames
	return frames


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


func resource_tex(kind: String, variant: int) -> Texture2D:
	var key := "r_%s_%d" % [kind, variant if kind == "tree" else 0]
	if _cache.has(key):
		return _cache[key]
	var img: Image
	match kind:
		"tree":
			img = _img_from(TREE_PINE if variant == 0 else TREE_OAK, TREE_PAL, 16, 16)
		"gold":
			img = _img_from(ROCK, GOLD_PAL, 16, 16)
		"stone":
			img = _img_from(ROCK, STONE_PAL, 16, 16)
		_:
			img = _img_from(BUSH, BUSH_PAL, 16, 16)
	var tex := ImageTexture.create_from_image(img)
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
	var s := size * 16
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var tc: Color = TEAM[team]
	match kind:
		"palisade", "wall":
			_draw_wall(img, faction, kind, tc)
		"gate":
			_draw_wall(img, faction, "wall", tc)
			_draw_gate(img, faction, tc)
		"tower":
			_draw_tower(img, faction, tc)
		"farm":
			_draw_farm(img, faction, tc)
		_:
			_draw_house(img, faction, kind, tc, s)
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


func _draw_house(img: Image, f: String, kind: String, team: Color, s: int) -> void:
	var p: Dictionary = BPAL[f]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(f + kind)
	var wall_top := int(s * 0.5)
	var x0 := 2
	var x1 := s - 3
	var y1 := s - 1
	_rect(img, x0, wall_top, x1 - x0 + 1, y1 - wall_top + 1, p.wall)
	match f:
		"mammals":
			for x in range(x0 + 2, x1, 3):
				for y in range(wall_top, y1 + 1):
					_px(img, x, y, p.wall_d)
		"aliens":
			for y in range(wall_top + 3, y1, 4):
				_hline(img, x0, x1, y, p.wall_d)
			for x in range(x0 + 3, x1, 6):
				_px(img, x, wall_top + 1, p.win)
		"plants":
			for i in s * 2:
				var x := rng.randi_range(x0, x1)
				var y := rng.randi_range(wall_top, y1 - 1)
				_px(img, x, y, p.wall_d)
				_px(img, x, y + 1, p.wall_d)
	_outline(img, x0 - 1, wall_top, x1 - x0 + 3, y1 - wall_top + 1, p.out)

	var cxi := s / 2
	match f:
		"mammals":
			# Strohdach
			var top := 3
			for y in range(top, wall_top + 2):
				var t := float(y - top) / float(wall_top + 2 - top)
				var half := int(lerpf(2.0, s / 2.0, t))
				_hline(img, cxi - half, cxi + half - 1, y, p.roof)
				for x in range(cxi - half, cxi + half):
					if (x + y * 2) % 4 == 0:
						_px(img, x, y, p.roof_d)
				_px(img, cxi - half - 1, y, p.out)
				_px(img, cxi + half, y, p.out)
			_hline(img, cxi - 3, cxi + 2, top - 1, p.out)
			_hline(img, 0, s - 1, wall_top + 2, p.roof_d)
		"aliens":
			# Kuppel
			var r := s / 2 - 2
			var cy := wall_top + 1
			for y in range(cy - r, cy + 1):
				var dy := cy - y
				var half := int(sqrt(float(r * r - dy * dy)))
				_hline(img, cxi - half, cxi + half - 1, y, p.roof)
				for x in range(cxi + half / 3, cxi + half):
					_px(img, x, y, p.roof_d)
				_px(img, cxi - half - 1, y, p.out)
				_px(img, cxi + half, y, p.out)
			_hline(img, cxi - 2, cxi + 1, cy - r - 1, p.out)
			var wy := cy - r / 2
			for x in range(cxi - r + 3, cxi + r - 3):
				if x % 3 != 0:
					_px(img, x, wy, p.win)
		"plants":
			# Blätterkrone
			var cx := s / 2.0
			var cy := wall_top * 0.6
			var rx := s / 2.0 - 0.5
			var ry := wall_top * 0.6
			for y in range(0, wall_top + 4):
				for x in range(0, s):
					var dx := (x + 0.5 - cx) / rx
					var dy := (y + 0.5 - cy) / ry
					var d := dx * dx + dy * dy
					if d <= 1.0:
						var c: Color = p.roof
						if d > 0.8:
							c = p.out
						elif rng.randf() < 0.18:
							c = p.roof_d
						elif rng.randf() < 0.05:
							c = Color("ff80b0")
						_px(img, x, y, c)

	var dw := maxi(4, s / 6)
	var dh := maxi(6, s / 4)
	_rect(img, cxi - dw / 2, y1 - dh + 1, dw, dh, p.door)
	if f == "aliens":
		_hline(img, cxi - dw / 2, cxi - dw / 2 + dw - 1, y1 - dh + 1, p.win)
	if s >= 48:
		_rect(img, x0 + 3, wall_top + 5, 4, 4, p.win)
		_rect(img, x1 - 6, wall_top + 5, 4, 4, p.win)
	# Teamfahne
	var fx := x0 + 1
	for y in range(0, 9):
		_px(img, fx, y, p.out)
	_rect(img, fx + 1, 0, 5, 3, team)
	_hline(img, fx + 1, fx + 5, 3, team.darkened(0.35))
	if kind == "town_center":
		for y in range(0, 9):
			_px(img, s - 4, y, p.out)
		_rect(img, s - 9, 0, 5, 3, team)
	# Symbol
	if GLYPH.has(kind):
		var g: Array = GLYPH[kind]
		var gx := cxi - dw / 2 - 7
		var gy := wall_top + 4
		if s >= 48:
			gx = cxi - 2
			gy = wall_top + 4
		for yy in g.size():
			var row: String = g[yy]
			for xx in row.length():
				if row[xx] == "x":
					_px(img, gx + xx, gy + yy, Color("f4e8c8"))


func _draw_wall(img: Image, f: String, kind: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	if kind == "palisade":
		match f:
			"mammals":
				for x in range(0, 16, 4):
					_rect(img, x + 1, 3, 3, 13, p.wall)
					_px(img, x + 2, 2, p.wall)
					_px(img, x + 2, 1, p.out)
					for y in range(3, 16):
						_px(img, x, y, p.out)
					_px(img, x + 3, 8, p.wall_d)
			"aliens":
				_rect(img, 1, 2, 3, 14, p.stone)
				_rect(img, 12, 2, 3, 14, p.stone)
				for y in [5, 8, 11, 14]:
					_hline(img, 4, 11, y, p.win)
			"plants":
				var rng := RandomNumberGenerator.new()
				rng.seed = 7
				for i in 90:
					var x := rng.randi_range(0, 15)
					var y := rng.randi_range(4, 15)
					_px(img, x, y, p.wall if i % 3 else p.roof_d)
				for i in 10:
					_px(img, rng.randi_range(0, 15), rng.randi_range(4, 15), Color("e0d040"))
	else:
		_rect(img, 0, 3, 16, 13, p.stone)
		for x in range(0, 16, 4):
			_rect(img, x, 1, 2, 2, p.stone)
		for y in [3, 7, 11, 15]:
			_hline(img, 0, 15, y, p.stone_d)
		for y in range(4, 15):
			var row := (y - 3) / 4
			var off := 0 if row % 2 == 0 else 3
			if (y - 3) % 4 != 0:
				_px(img, (off + 1) % 16, y, p.stone_d)
				_px(img, (off + 8) % 16, y, p.stone_d)
		if f == "aliens":
			_hline(img, 1, 14, 9, p.win)
		elif f == "plants":
			for i in [Vector2i(2, 5), Vector2i(9, 6), Vector2i(5, 10), Vector2i(12, 12), Vector2i(3, 13)]:
				_px(img, i.x, i.y, Color("e0d040"))
	_hline(img, 0, 15, 15, team)


func _draw_gate(img: Image, f: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	_rect(img, 4, 6, 8, 10, p.door)
	_hline(img, 5, 10, 5, p.door)
	_rect(img, 6, 1, 4, 3, team)
	if f == "aliens":
		_hline(img, 4, 11, 6, p.win)


func _draw_tower(img: Image, f: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	_rect(img, 3, 3, 10, 13, p.stone if f != "plants" else p.wall)
	for x in [3, 6, 9, 12]:
		_rect(img, x, 1, 2, 2, p.stone if f != "plants" else p.roof)
	_outline(img, 3, 3, 10, 13, p.out)
	_rect(img, 7, 6, 2, 4, p.out)
	if f == "aliens":
		_rect(img, 7, 6, 2, 4, p.win)
	elif f == "plants":
		_rect(img, 2, 0, 12, 4, p.roof)
		_px(img, 5, 1, Color("ff80b0"))
		_px(img, 10, 2, Color("ff80b0"))
	_rect(img, 5, 11, 6, 2, team)


func _draw_farm(img: Image, f: String, team: Color) -> void:
	var p: Dictionary = BPAL[f]
	_rect(img, 1, 1, 30, 30, Color("6a4a2a"))
	for y in range(4, 30, 4):
		_hline(img, 2, 29, y, Color("4e3420"))
		for x in range(3, 29, 3):
			_px(img, x, y - 1, p.crop)
			_px(img, x, y - 2, p.crop.darkened(0.25))
	_outline(img, 0, 0, 32, 32, Color("8a6a40"))
	_rect(img, 1, 1, 3, 2, team)


# ---------------------------------------------------------------- Gelände

func build_terrain_image(terrain: PackedByteArray, w: int, h: int, seed_val: int) -> Image:
	var img := Image.create_empty(w * 16, h * 16, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var tint := FastNoiseLite.new()
	tint.seed = seed_val + 5
	tint.frequency = 0.08
	var grass := [Color("4e8e32"), Color("66a644"), Color("447e2c"), Color("72b04c")]
	for cy in h:
		for cx in w:
			var t := terrain[cy * w + cx]
			var base: Color
			var dots: Array
			match t:
				1:
					base = Color("2a5aa0")
					dots = [Color("3a70c0"), Color("24508e")]
				2:
					base = Color("d6c48c")
					dots = [Color("c8b47a"), Color("e2d4a0")]
				_:
					base = Color("5a9a3a").lerp(Color("6aa040"), tint.get_noise_2d(cx, cy) * 0.5 + 0.5)
					dots = grass
			img.fill_rect(Rect2i(cx * 16, cy * 16, 16, 16), base)
			if t == 1:
				for i in 2:
					var x := rng.randi_range(0, 12)
					var y := rng.randi_range(1, 14)
					for k in 3:
						img.set_pixel(cx * 16 + x + k, cy * 16 + y, dots[0])
			else:
				for i in 12:
					img.set_pixel(cx * 16 + rng.randi_range(0, 15), cy * 16 + rng.randi_range(0, 15), dots[rng.randi() % dots.size()])
				if t == 0 and rng.randf() < 0.06:
					# kleine Blume
					var fx := cx * 16 + rng.randi_range(2, 13)
					var fy := cy * 16 + rng.randi_range(2, 13)
					img.set_pixel(fx, fy, [Color("f0e060"), Color("f0f0f0"), Color("e070a0")][rng.randi() % 3])
	return img


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
