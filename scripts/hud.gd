extends CanvasLayer
## Oberfläche: Ressourcenleiste, Auswahl-Info, Befehlsknöpfe, Minimap, Menü, Spielende.

const MinimapScript = preload("res://scripts/minimap.gd")

const C_BG := Color("2b1d14")
const C_BORDER := Color("c8a060")
const C_TEXT := Color("f0e6d0")

var world
var root: Control
var top_bar: Control
var bottom_bar: Control
var res_labels := {}
var pop_label: Label
var age_label: Label
var time_label: Label
var info_icon: TextureRect
var info_title: Label
var info_body: Label
var prog: ProgressBar
var queue_box: HBoxContainer
var cmd_grid: GridContainer
var msg_label: Label
var msg_t := 0.0
var minimap
var menu: Control
var dirty := true
var sig := ""
var tick := 0.0


func _ready() -> void:
	layer = 10
	_build()


func _box(bg: Color, border: Color, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(6)
	return s


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 14
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.45))
	th.set_font_size("font_size", "Button", 12)
	th.set_stylebox("normal", "Button", _box(Color("4a3222"), Color("8a6a40")))
	th.set_stylebox("hover", "Button", _box(Color("5e4230"), C_BORDER))
	th.set_stylebox("pressed", "Button", _box(Color("2e2016"), C_BORDER))
	th.set_stylebox("disabled", "Button", _box(Color("2a2420"), Color("4a4038")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("panel", "PanelContainer", _box(C_BG, C_BORDER))
	th.set_stylebox("background", "ProgressBar", _box(Color("1a120c"), Color("8a6a40"), 1))
	th.set_stylebox("fill", "ProgressBar", _box(Color("d8b040"), Color("d8b040"), 0))
	root.theme = th
	add_child(root)

	# Obere Leiste
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 34
	root.add_child(top_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	top_bar.add_child(hb)
	for k in Data.RES:
		var box := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = Data.RES_COLORS[k]
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var l := Label.new()
		l.tooltip_text = Data.RES_NAMES[k]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(sw)
		box.add_child(l)
		hb.add_child(box)
		res_labels[k] = l
	pop_label = Label.new()
	hb.add_child(pop_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	age_label = Label.new()
	age_label.add_theme_color_override("font_color", C_BORDER)
	hb.add_child(age_label)
	time_label = Label.new()
	hb.add_child(time_label)

	# Untere Leiste
	bottom_bar = PanelContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -196
	root.add_child(bottom_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bottom_bar.add_child(row)
	minimap = MinimapScript.new()
	minimap.world = world
	minimap.custom_minimum_size = Vector2(176, 176)
	minimap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(minimap)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(340, 0)
	row.add_child(info)
	var title_row := HBoxContainer.new()
	info.add_child(title_row)
	info_icon = TextureRect.new()
	info_icon.custom_minimum_size = Vector2(40, 40)
	info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_row.add_child(info_icon)
	info_title = Label.new()
	info_title.add_theme_font_size_override("font_size", 17)
	info_title.add_theme_color_override("font_color", C_BORDER)
	info_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(info_title)
	info_body = Label.new()
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size = Vector2(330, 0)
	info_body.add_theme_font_size_override("font_size", 13)
	info.add_child(info_body)
	prog = ProgressBar.new()
	prog.custom_minimum_size = Vector2(320, 12)
	prog.show_percentage = false
	prog.visible = false
	info.add_child(prog)
	queue_box = HBoxContainer.new()
	info.add_child(queue_box)

	cmd_grid = GridContainer.new()
	cmd_grid.columns = 6
	cmd_grid.add_theme_constant_override("h_separation", 4)
	cmd_grid.add_theme_constant_override("v_separation", 4)
	row.add_child(cmd_grid)

	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	msg_label.offset_top = 46
	msg_label.offset_bottom = 72
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 5)
	root.add_child(msg_label)

	top_bar.visible = false
	bottom_bar.visible = false


func message(text: String) -> void:
	if text == "":
		return
	msg_label.text = text
	msg_t = 3.0


# ---------------------------------------------------------------- Menü

func show_menu() -> void:
	menu = ColorRect.new()
	menu.color = Color("140c08")
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)

	var title := Label.new()
	title.text = "KOMETEN & KRONEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_BORDER)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Mittelalter trifft Außerirdische. Sammle Rohstoffe, steige von der Dunklen Zeit bis zur Moderne auf\nund besiege deinen Gegner mit klugen Konter-Einheiten."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var opp_row := HBoxContainer.new()
	opp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ol := Label.new()
	ol.text = "Gegner:"
	opp_row.add_child(ol)
	var opp := OptionButton.new()
	opp.add_item("Zufällig")
	for f in Data.FACTIONS:
		opp.add_item(Data.FACTIONS[f]["name"])
	opp_row.add_child(opp)
	vb.add_child(opp_row)

	var pick := Label.new()
	pick.text = "Wähle dein Volk:"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick.add_theme_font_size_override("font_size", 20)
	vb.add_child(pick)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(cards)
	for f in Data.FACTIONS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(320, 250)
		cards.add_child(btn)
		btn.pressed.connect(func(): _start(f, opp.selected))
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 12
		inner.offset_top = 12
		inner.offset_right = -12
		inner.offset_bottom = -12
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 10)
		btn.add_child(inner)
		var icons := HBoxContainer.new()
		icons.alignment = BoxContainer.ALIGNMENT_CENTER
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icons)
		var tcr := TextureRect.new()
		tcr.texture = Art.building_tex(f, "town_center", 0)
		tcr.custom_minimum_size = Vector2(72, 72)
		tcr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tcr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(tcr)
		for k in ["villager", "spear", "archer", "cavalry", "siege"]:
			var ur := TextureRect.new()
			ur.texture = Art.unit_tex(f, k, 0)
			ur.custom_minimum_size = Vector2(40, 40)
			ur.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ur.size_flags_vertical = Control.SIZE_SHRINK_END
			ur.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_child(ur)
		var nl := Label.new()
		nl.text = Data.FACTIONS[f]["name"]
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 22)
		nl.add_theme_color_override("font_color", C_BORDER)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(nl)
		var dl := Label.new()
		dl.text = Data.FACTIONS[f]["desc"]
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 13)
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(dl)

	var help := Label.new()
	help.text = "Speer schlägt Reiter  •  Reiter schlagen Schützen  •  Schützen schlagen Speer  •  Belagerung zerstört Mauern"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color("b0a080"))
	vb.add_child(help)


func _start(f: String, opp_idx: int) -> void:
	var keys := Data.FACTIONS.keys()
	var enemy: String
	if opp_idx <= 0:
		var others := keys.filter(func(k) -> bool: return k != f)
		enemy = others[randi() % others.size()]
	else:
		enemy = keys[opp_idx - 1]
	menu.queue_free()
	menu = null
	world.start_game(f, enemy)


func on_game_started() -> void:
	top_bar.visible = true
	bottom_bar.visible = true
	dirty = true
	var p: Dictionary = world.players[1]
	message("Dein Gegner: %s. Viel Glück!" % Data.FACTIONS[p["faction"]]["name"])


func show_game_over(win: bool) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 200)
	panel.offset_left = -210
	panel.offset_top = -100
	panel.offset_right = 210
	panel.offset_bottom = 100
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	panel.add_child(vb)
	var l := Label.new()
	l.text = "SIEG!" if win else "NIEDERLAGE"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", C_BORDER if win else Color("e05050"))
	vb.add_child(l)
	var b := Button.new()
	b.text = "Neues Spiel"
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	vb.add_child(b)


# ---------------------------------------------------------------- Laufende Anzeige

func _process(delta: float) -> void:
	if msg_t > 0.0:
		msg_t -= delta / maxf(0.01, Engine.time_scale)
		if msg_t <= 0.0:
			msg_label.text = ""
	if world == null or not world.running:
		return
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.15
	_update_top()
	var s := _selection_sig()
	if s != sig or dirty:
		sig = s
		dirty = false
		_rebuild_commands()
	_update_info()


func _update_top() -> void:
	var p: Dictionary = world.players[0]
	for k in Data.RES:
		res_labels[k].text = "%s %d" % [Data.RES_NAMES[k], int(p["res"][k])]
	pop_label.text = "Bevölkerung %d/%d" % [world.pop(0), world.pop_cap(0)]
	var age_txt: String = Data.AGES[p["age"]]["name"]
	if p["aging"]:
		age_txt += "  →  Aufstieg läuft…"
	age_label.text = age_txt
	var t := int(world.game_time)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]


func _selection_sig() -> String:
	var p: Dictionary = world.players[0]
	var parts := PackedStringArray([str(p["age"]), str(p["aging"])])
	for e in world.selected:
		if world.valid(e):
			parts.append(str(e.get_instance_id()))
			if e.is_building:
				parts.append("%s%d" % [e.built, e.queue.size()])
	return ",".join(parts)


func _cmd_button(tex: Texture2D, title: String, cost: String, disabled: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 52)
	btn.icon = Art.icon(tex)
	btn.text = title + ("\n" + cost if cost != "" else "")
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.disabled = disabled
	btn.add_theme_constant_override("icon_max_width", 40)
	cmd_grid.add_child(btn)
	return btn


func _unit_tooltip(k: String, f: String, age: int) -> String:
	var s := Data.unit_stats(k, f, age)
	var t := "%s\nLP %d  Angriff %d  Rüstung %d" % [Data.unit_name(k, f, age), int(s["hp"]), int(s["atk"]), int(s["armor"])]
	if float(s["range"]) > 0.0:
		t += "  Reichweite %.1f" % s["range"]
	return t + "\n" + Data.COUNTER_TEXT[k]


func _rebuild_commands() -> void:
	for c in cmd_grid.get_children():
		c.queue_free()
	for c in queue_box.get_children():
		c.queue_free()
	var sel: Array = world.selected
	if sel.is_empty() or not world.valid(sel[0]) or sel[0].owner_id != 0:
		return
	var p: Dictionary = world.players[0]
	var f: String = p["faction"]
	var age := int(p["age"])
	var has_vill := false
	for e in sel:
		if world.valid(e) and not e.is_building and e.kind == "villager":
			has_vill = true
	if has_vill:
		for k in Data.BUILD_ORDER:
			var bi: Dictionary = Data.BUILDINGS[k]
			var locked := age < int(bi["age"])
			var btn := _cmd_button(Art.building_tex(f, k, 0), Data.building_name(k, f), Data.cost_text(Data.building_cost(k, f)), locked)
			btn.tooltip_text = "Erst ab %s" % Data.AGES[bi["age"]]["name"] if locked else Data.building_name(k, f)
			btn.pressed.connect(func(): world.start_placement(k))
		return
	var b = sel[0]
	if not b.is_building or not b.built or sel.size() != 1:
		return
	for k in b.info.get("trains", []):
		var locked := age < int(Data.UNITS[k]["age"])
		var btn := _cmd_button(Art.unit_tex(f, k, 0), Data.unit_name(k, f, age), Data.cost_text(Data.unit_cost(k, f)), locked)
		btn.tooltip_text = ("Erst ab %s\n" % Data.AGES[Data.UNITS[k]["age"]]["name"] if locked else "") + _unit_tooltip(k, f, age)
		btn.pressed.connect(func(): world.queue_train(b, k))
	if b.kind == "town_center" and age < Data.AGES.size() - 1:
		var na: Dictionary = Data.AGES[age + 1]
		var btn := _cmd_button(null, "Aufstieg:\n" + na["name"], Data.cost_text(na["cost"]), p["aging"])
		btn.tooltip_text = "Steige in die %s auf. Neue Gebäude und Einheiten, alle Einheiten werden stärker." % na["name"]
		btn.pressed.connect(func(): world.queue_age_up(b))
	for i in b.queue.size():
		var item: String = b.queue[i]
		var qb := Button.new()
		qb.custom_minimum_size = Vector2(34, 34)
		if item == "age_up":
			qb.text = "Zeit"
		else:
			qb.icon = Art.icon(Art.unit_tex(f, item, 0))
			qb.expand_icon = true
		qb.tooltip_text = "Klicken zum Abbrechen"
		var idx: int = i
		qb.pressed.connect(func(): world.cancel_queue(b, idx))
		queue_box.add_child(qb)


func _update_info() -> void:
	var sel: Array = world.selected.filter(func(e) -> bool: return world.valid(e))
	prog.visible = false
	var f: String = world.players[0]["faction"]
	if sel.is_empty():
		info_icon.texture = null
		info_title.text = Data.FACTIONS[f]["name"]
		info_body.text = "Linksklick / Ziehen: auswählen\nRechtsklick: bewegen, sammeln, bauen, angreifen\nWASD, Pfeile oder Bildschirmrand: Kamera  •  Mausrad: Zoom\nH: Dorfzentrum  •  Punkt: untätiger Arbeiter  •  Entf: löschen\nShift beim Bauen: mehrere platzieren"
		return
	if sel.size() == 1:
		var e = sel[0]
		info_icon.texture = e.tex
		var enemy_tag := "" if e.owner_id == 0 else "  (Gegner)"
		if e.is_building:
			info_title.text = e.display_name() + enemy_tag
			var t := "Lebenspunkte %d / %d" % [int(e.hp), int(e.max_hp)]
			if not e.built:
				t += "\nIm Bau: %d%%" % int(e.progress * 100.0)
				prog.visible = true
				prog.value = e.progress * 100.0
			elif e.kind == "farm":
				t += "\nNahrung übrig: %d" % int(e.food_left)
			elif not e.queue.is_empty():
				var item: String = e.queue[0]
				var nm: String = "Aufstieg in die " + Data.AGES[world.players[e.owner_id]["age"] + 1]["name"] if item == "age_up" else Data.unit_name(item, e.faction, world.players[e.owner_id]["age"])
				t += "\nIn Arbeit: " + nm
				prog.visible = true
				prog.value = e.queue_t / e.current_time() * 100.0
			if e.info.has("pop"):
				t += "\nBietet Platz für %d" % int(e.info["pop"])
			if e.info.has("drop"):
				var names := PackedStringArray()
				for r in e.info["drop"]:
					names.append(Data.RES_NAMES[r])
				t += "\nAbgabe von: " + ", ".join(names)
			if e.info.has("trains") and e.owner_id == 0 and e.built:
				t += "\nRechtsklick setzt den Sammelpunkt"
			info_body.text = t
		else:
			info_title.text = e.display_name() + enemy_tag
			var s: Dictionary = e.stats
			var t := "LP %d / %d   Angriff %d   Rüstung %d" % [int(e.hp), int(e.max_hp), int(s["atk"]), int(s["armor"])]
			if float(s["range"]) > 0.0:
				t += "   Reichweite %.1f" % s["range"]
			if e.carry > 0.0:
				t += "\nTrägt %d %s" % [int(e.carry), Data.RES_NAMES[e.carry_type]]
			t += "\n" + Data.COUNTER_TEXT[e.kind]
			info_body.text = t
		return
	var counts := {}
	for e in sel:
		var n: String = e.display_name()
		counts[n] = int(counts.get(n, 0)) + 1
	info_icon.texture = sel[0].tex
	info_title.text = "%d ausgewählt" % sel.size()
	var lines := PackedStringArray()
	for n in counts:
		lines.append("%d× %s" % [counts[n], n])
	info_body.text = "\n".join(lines)
