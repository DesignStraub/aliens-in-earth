extends Node
## Einstellungen (UI-Skalierung, Vollbild, Lautstärke, Kamera) – gespeichert in user://settings.cfg

const PATH := "user://settings.cfg"

var ui_scale := 1.0
var fullscreen := false
var volume := 0.5
var edge_scroll := true
var cam_speed := 1.0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		ui_scale = cfg.get_value("display", "ui_scale", ui_scale)
		fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
		volume = cfg.get_value("audio", "volume", volume)
		edge_scroll = cfg.get_value("controls", "edge_scroll", edge_scroll)
		cam_speed = cfg.get_value("controls", "cam_speed", cam_speed)
	apply()


func apply() -> void:
	# Die Oberfläche skaliert über den Stretch-Modus automatisch mit der Fenstergröße
	# (wichtig für 4K/Retina); ui_scale vergrößert zusätzlich.
	get_window().content_scale_factor = ui_scale
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("controls", "edge_scroll", edge_scroll)
	cfg.set_value("controls", "cam_speed", cam_speed)
	cfg.save(PATH)
