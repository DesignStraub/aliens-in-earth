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
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	var mb := Button.new()
	mb.text = "Menü (F10)"
	mb.focus_mode = Control.FOCUS_NONE
	mb.pressed.connect(func(): toggle_pause_menu())
	hb.add_child(mb)

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
	info_title.custom_minimum_size = Vector2(150, 0)
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
	queue_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(queue_box)

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
	show_title()


# ---------------------------------------------------------------- Menüs

const ParadeScript = preload("res://scripts/parade.gd")

var setup := {"faction": "mammals", "opponents": ["random", "", ""], "teams": "ffa", "map_size": 0, "fog": true, "difficulty": 1}


func _clear_menu() -> void:
	if menu != null:
		menu.queue_free()
		menu = null


func _menu_box(title_text: String, dim := false) -> VBoxContainer:
	_clear_menu()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65) if dim else Color("140c08")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	menu = bg
	if not dim:
		var parade := ParadeScript.new()
		parade.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.add_child(parade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	if title_text != "":
		var title := Label.new()
		title.text = title_text
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 52 if not dim else 38)
		title.add_theme_color_override("font_color", C_BORDER)
		vb.add_child(title)
	return vb


func _big_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _label(text: String, size := 15, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func show_title() -> void:
	top_bar.visible = false
	bottom_bar.visible = false
	var vb := _menu_box("KOMETEN & KRONEN")
	var sub := _label("Säugetiere, Aliens und lebende Pflanzen kämpfen von der Funkenzeit bis zur Sternenzeit.", 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	var wrap := CenterContainer.new()
	wrap.add_child(col)
	vb.add_child(wrap)
	col.add_child(_big_button("Neues Spiel", show_setup))
	var lb := _big_button("Spiel laden", func(): world.request_load())
	lb.disabled = not world.has_save()
	col.add_child(lb)
	col.add_child(_big_button("Einstellungen", func(): show_settings(show_title)))
	col.add_child(_big_button("Beenden", func(): get_tree().quit()))
	var v := _label("Open Source (MIT)  •  github.com/DesignStraub/aliens-in-earth", 12, Color("8a7a60"))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(v)


func _option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = selected
	o.custom_minimum_size = Vector2(220, 34)
	o.item_selected.connect(cb)
	return o


func show_setup() -> void:
	var vb := _menu_box("Neues Spiel")
	vb.add_child(_label("Dein Volk", 18, C_BORDER))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 14)
	vb.add_child(cards)
	var group := ButtonGroup.new()
	for f in Data.FACTIONS:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = setup["faction"] == f
		btn.custom_minimum_size = Vector2(300, 190)
		btn.pressed.connect(func(): setup["faction"] = f)
		cards.add_child(btn)
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 10
		inner.offset_top = 10
		inner.offset_right = -10
		inner.offset_bottom = -10
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(inner)
		var icons := HBoxContainer.new()
		icons.alignment = BoxContainer.ALIGNMENT_CENTER
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icons)
		var tcr := TextureRect.new()
		tcr.texture = Art.building_tex(f, "town_center", 0)
		tcr.custom_minimum_size = Vector2(60, 60)
		tcr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tcr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(tcr)
		for k in ["villager", "spear", "archer", "cavalry", "siege"]:
			var ur := TextureRect.new()
			ur.texture = Art.unit_tex(f, k, 0)
			ur.custom_minimum_size = Vector2(36, 36)
			ur.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ur.size_flags_vertical = Control.SIZE_SHRINK_END
			ur.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_child(ur)
		var nl := _label(Data.FACTIONS[f]["name"], 20, C_BORDER)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(nl)
		var dl := _label(Data.FACTIONS[f]["desc"], 12)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(dl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	var gwrap := CenterContainer.new()
	gwrap.add_child(grid)
	vb.add_child(gwrap)
	var fac_names := ["Zufällig"]
	var fac_keys := ["random"]
	for f in Data.FACTIONS:
		fac_names.append(Data.FACTIONS[f]["name"])
		fac_keys.append(f)
	for i in 3:
		var label := "Gegner %d" % (i + 1)
		grid.add_child(_label(label))
		var items := fac_names.duplicate() if i == 0 else ["– keiner –"] + fac_names
		var keys := fac_keys.duplicate() if i == 0 else [""] + fac_keys
		var idx := i
		grid.add_child(_option(items, maxi(0, keys.find(setup["opponents"][i])), func(sel: int): setup["opponents"][idx] = keys[sel]))
	grid.add_child(_label("Modus"))
	grid.add_child(_option(["Jeder gegen jeden", "Alle gegen dich"], 0 if setup["teams"] == "ffa" else 1, func(sel: int): setup["teams"] = "ffa" if sel == 0 else "all_vs_you"))
	grid.add_child(_label("Kartengröße"))
	var sizes := []
	for m in Data.MAP_SIZES:
		sizes.append("%s (%d×%d)" % [m["name"], m["size"], m["size"]])
	grid.add_child(_option(sizes, setup["map_size"], func(sel: int): setup["map_size"] = sel))
	grid.add_child(_label("Schwierigkeit"))
	var diffs := []
	for d in Data.DIFFICULTY:
		diffs.append(d["name"])
	grid.add_child(_option(diffs, setup["difficulty"], func(sel: int): setup["difficulty"] = sel))
	grid.add_child(_label("Nebel des Krieges"))
	var fog := CheckBox.new()
	fog.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fog.button_pressed = setup["fog"]
	fog.toggled.connect(func(on: bool): setup["fog"] = on)
	grid.add_child(fog)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var back := _big_button("Zurück", show_title)
	back.custom_minimum_size = Vector2(200, 48)
	row.add_child(back)
	var go := _big_button("Spiel starten", _start_setup)
	go.custom_minimum_size = Vector2(260, 48)
	row.add_child(go)
	vb.add_child(row)


func _start_setup() -> void:
	var keys := Data.FACTIONS.keys()
	var opp := []
	for o in setup["opponents"]:
		if o == "":
			continue
		opp.append(keys[randi() % keys.size()] if o == "random" else o)
	var size := int(setup["map_size"])
	if opp.size() >= 3:
		size = maxi(size, 1)
	var cfg := {"faction": setup["faction"], "opponents": opp, "teams": setup["teams"], "map_size": size, "fog": setup["fog"], "difficulty": setup["difficulty"]}
	_clear_menu()
	world.start_game(cfg)


func _slider(minv: float, maxv: float, step: float, value: float, fmt: String, on_change: Callable, on_done := Callable()) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var sl := HSlider.new()
	sl.min_value = minv
	sl.max_value = maxv
	sl.step = step
	sl.value = value
	sl.custom_minimum_size = Vector2(260, 24)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vl := _label(fmt % value)
	vl.custom_minimum_size = Vector2(60, 0)
	sl.value_changed.connect(func(v: float):
		vl.text = fmt % v
		on_change.call(v))
	if on_done.is_valid():
		sl.drag_ended.connect(func(_changed: bool): on_done.call())
	hb.add_child(sl)
	hb.add_child(vl)
	return hb


func show_settings(back: Callable) -> void:
	var vb := _menu_box("Einstellungen", world.running)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	var gwrap := CenterContainer.new()
	gwrap.add_child(grid)
	vb.add_child(gwrap)
	grid.add_child(_label("Oberflächen-Skalierung"))
	grid.add_child(_slider(0.75, 2.5, 0.05, Settings.ui_scale, "%.2f×", func(v: float): Settings.ui_scale = v, func(): Settings.apply()))
	grid.add_child(_label("Vollbild"))
	var fs := CheckBox.new()
	fs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool):
		Settings.fullscreen = on
		Settings.apply())
	grid.add_child(fs)
	grid.add_child(_label("Lautstärke"))
	grid.add_child(_slider(0.0, 100.0, 5.0, Settings.volume * 100.0, "%.0f%%", func(v: float):
		Settings.volume = v / 100.0
		Settings.apply(), func(): Sfx.play("select")))
	grid.add_child(_label("Bildschirmrand-Scrollen"))
	var es := CheckBox.new()
	es.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	es.button_pressed = Settings.edge_scroll
	es.toggled.connect(func(on: bool): Settings.edge_scroll = on)
	grid.add_child(es)
	grid.add_child(_label("Kamera-Tempo"))
	grid.add_child(_slider(0.4, 2.5, 0.1, Settings.cam_speed, "%.1f×", func(v: float): Settings.cam_speed = v))
	var hint := _label("Die Oberfläche passt sich automatisch der Fenstergröße an (auch 4K).\nDie Skalierung vergrößert sie zusätzlich.", 12, Color("a09070"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var done := _big_button("Fertig", func():
		Settings.save()
		back.call())
	var dwrap := CenterContainer.new()
	dwrap.add_child(done)
	vb.add_child(dwrap)


func toggle_pause_menu() -> void:
	if not world.running or world.game_over:
		return
	if menu != null:
		_close_pause()
	else:
		_open_pause()


func _open_pause() -> void:
	get_tree().paused = true
	world.reset_cursor()
	var vb := _menu_box("Pause", true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var wrap := CenterContainer.new()
	wrap.add_child(col)
	vb.add_child(wrap)
	col.add_child(_big_button("Weiterspielen", _close_pause))
	col.add_child(_big_button("Speichern (F5)", func():
		world.save_game()
		_close_pause()))
	var lb := _big_button("Laden", func(): world.request_load())
	lb.disabled = not world.has_save()
	col.add_child(lb)
	col.add_child(_big_button("Einstellungen", func(): show_settings(_open_pause)))
	col.add_child(_big_button("Hauptmenü", func():
		get_tree().paused = false
		get_tree().reload_current_scene()))


func _close_pause() -> void:
	_clear_menu()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if menu != null and world.running and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_F10]:
		_close_pause()
		get_viewport().set_input_as_handled()


func on_game_started() -> void:
	top_bar.visible = true
	bottom_bar.visible = true
	dirty = true
	if world.human >= 0 and world.game_time < 1.0:
		var names := PackedStringArray()
		for i in range(1, world.players.size()):
			names.append(Data.FACTIONS[world.players[i]["faction"]]["name"])
		message("Gegner: %s. Viel Glück!" % ", ".join(names))


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
	b.text = "Hauptmenü"
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


func _me() -> int:
	return maxi(world.human, 0)


func _update_top() -> void:
	var p: Dictionary = world.players[_me()]
	for k in Data.RES:
		res_labels[k].text = "%s %d" % [Data.RES_NAMES[k], int(p["res"][k])]
	pop_label.text = "Bevölkerung %d/%d" % [world.pop(_me()), world.pop_cap(_me())]
	var age_txt: String = Data.AGES[p["age"]]["name"]
	if p["aging"]:
		age_txt += "  →  Aufstieg läuft…"
	age_label.text = age_txt
	var t := int(world.game_time)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]


func _selection_sig() -> String:
	var p: Dictionary = world.players[_me()]
	var parts := PackedStringArray([str(p["age"]), str(p["aging"]), str(p["techs"].size()), str(p["researching"].size())])
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
	if sel.is_empty() or not world.valid(sel[0]) or sel[0].owner_id != world.human:
		return
	var p: Dictionary = world.players[world.human]
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
	for tid in Data.TECHS:
		var td: Dictionary = Data.TECHS[tid]
		if td["at"] != b.kind or p["techs"].has(tid) or p["researching"].has(tid):
			continue
		var locked: bool = age < int(td["age"]) or (td.has("req") and not p["techs"].has(td["req"]))
		var tb := _cmd_button(Art.tech_icon(), td["name"], Data.cost_text(td["cost"]), locked)
		var why := ""
		if age < int(td["age"]):
			why = "Erst ab %s\n" % Data.AGES[td["age"]]["name"]
		elif td.has("req") and not p["techs"].has(td["req"]):
			why = "Benötigt: %s\n" % Data.TECHS[td["req"]]["name"]
		tb.tooltip_text = why + "Forschung: %s\n%s" % [td["name"], td["desc"]]
		tb.pressed.connect(func(): world.queue_research(b, tid))
	for i in b.queue.size():
		var item: String = b.queue[i]
		var qb := Button.new()
		qb.custom_minimum_size = Vector2(30, 30)
		if item == "age_up":
			qb.text = "Zeit"
		elif item.begins_with("tech:"):
			qb.icon = Art.tech_icon()
			qb.expand_icon = true
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
	var f: String = world.players[_me()]["faction"]
	if sel.is_empty():
		info_icon.texture = null
		info_title.text = Data.FACTIONS[f]["name"]
		info_body.text = "Linksklick/Ziehen: auswählen  •  Rechtsklick: Befehl\nWASD/Rand: Kamera  •  Mausrad: Zoom\nH: Hauptsitz  •  Punkt: untätiger Arbeiter\nF5: speichern  •  Esc/F10: Menü"
		return
	if sel.size() == 1:
		var e = sel[0]
		info_icon.texture = e.tex
		var enemy_tag := "" if e.owner_id == world.human else ("  (Verbündet)" if not world.is_enemy(_me(), e.owner_id) else "  (Gegner)")
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
				var nm: String
				if item == "age_up":
					nm = "Aufstieg in die " + Data.AGES[world.players[e.owner_id]["age"] + 1]["name"]
				elif item.begins_with("tech:"):
					nm = "Forschung: " + Data.TECHS[item.substr(5)]["name"]
				else:
					nm = Data.unit_name(item, e.faction, world.players[e.owner_id]["age"])
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
			if e.info.has("trains") and e.owner_id == world.human and e.built:
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
