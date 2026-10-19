extends Node
## Sound-Effekte, beim Start prozedural synthetisiert (keine Audiodateien nötig).
## Später einfach durch eigene .wav/.ogg ersetzen: streams["name"] = load("res://...").

const RATE := 22050

var streams := {}
var players: Array = []
var last := {}
## Sichtbarer Weltausschnitt; Geräusche außerhalb werden nicht abgespielt.
var view_rect := Rect2(-1e9, -1e9, 2e9, 2e9)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	_generate()


func play(sound: String, pos = null, vol_db := 0.0) -> void:
	if not streams.has(sound):
		return
	if pos != null and not view_rect.has_point(pos):
		return
	var now := Time.get_ticks_msec()
	if now - int(last.get(sound, -1000)) < 70:
		return
	last[sound] = now
	for p in players:
		if not p.playing:
			p.stream = streams[sound]
			p.volume_db = vol_db
			p.pitch_scale = randf_range(0.93, 1.07)
			p.play()
			return


# ---------------------------------------------------------------- Synthese

func _tone(dur: float, f0: float, f1: float, wave: String, attack: float, decay: float, noise := 0.0, lp := 1.0, vol := 0.5) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lpf := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(f0, f1, t / dur) / RATE
		var ph := fmod(phase, 1.0)
		var s := 0.0
		match wave:
			"sine":
				s = sin(ph * TAU)
			"square":
				s = 1.0 if ph < 0.5 else -1.0
			"saw":
				s = ph * 2.0 - 1.0
			_:
				s = absf(ph * 4.0 - 2.0) - 1.0
		s = s * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		lpf += (s - lpf) * lp
		var env := minf(1.0, t / maxf(attack, 0.0001)) * exp(-t * decay)
		out[i] = lpf * env * vol
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _generate() -> void:
	var s := {}
	s["chop"] = _mix(_tone(0.12, 160, 90, "sine", 0.002, 30, 0.0, 1.0, 0.5), _tone(0.08, 0, 0, "sine", 0.001, 45, 1.0, 0.35, 0.45))
	s["mine"] = _mix(_tone(0.25, 1900, 1850, "sine", 0.001, 18, 0.0, 1.0, 0.3), _tone(0.05, 0, 0, "sine", 0.001, 60, 1.0, 0.8, 0.4))
	s["build"] = _mix(_tone(0.15, 110, 70, "sine", 0.002, 25, 0.0, 1.0, 0.55), _tone(0.06, 0, 0, "sine", 0.001, 50, 1.0, 0.25, 0.35))
	s["gather"] = _tone(0.12, 0, 0, "sine", 0.02, 25, 1.0, 0.12, 0.35)
	s["farm"] = _tone(0.1, 0, 0, "sine", 0.01, 30, 1.0, 0.2, 0.3)
	s["melee"] = _mix(_tone(0.12, 620, 540, "square", 0.001, 35, 0.3, 0.6, 0.22), _tone(0.05, 0, 0, "sine", 0.001, 70, 1.0, 0.9, 0.3))
	s["arrow"] = _tone(0.18, 0, 0, "sine", 0.06, 14, 1.0, 0.18, 0.4)
	s["beam"] = _tone(0.16, 1400, 380, "sine", 0.002, 12, 0.05, 1.0, 0.3)
	s["spore"] = _mix(_tone(0.12, 320, 180, "sine", 0.002, 28, 0.0, 1.0, 0.4), _tone(0.06, 0, 0, "sine", 0.001, 50, 1.0, 0.15, 0.3))
	s["siege"] = _mix(_tone(0.35, 70, 40, "sine", 0.002, 9, 0.0, 1.0, 0.7), _tone(0.2, 0, 0, "sine", 0.001, 18, 1.0, 0.1, 0.5))
	s["death"] = _tone(0.32, 420, 90, "square", 0.002, 8, 0.0, 0.3, 0.2)
	s["collapse"] = _tone(0.7, 0, 0, "sine", 0.01, 5, 1.0, 0.06, 0.8)
	s["select"] = _tone(0.05, 900, 950, "tri", 0.002, 50, 0.0, 1.0, 0.3)
	s["ack_mammals"] = _cat([_tone(0.06, 900, 1400, "tri", 0.002, 20, 0.0, 1.0, 0.25), _tone(0.07, 1000, 1500, "tri", 0.002, 20, 0.0, 1.0, 0.25)])
	s["ack_aliens"] = _cat([_tone(0.05, 1000, 1000, "square", 0.001, 15, 0.0, 0.5, 0.15), _tone(0.07, 1500, 1500, "square", 0.001, 15, 0.0, 0.5, 0.15)])
	s["ack_plants"] = _mix(_tone(0.14, 220, 160, "tri", 0.01, 12, 0.0, 1.0, 0.35), _tone(0.12, 0, 0, "sine", 0.01, 20, 1.0, 0.1, 0.25))
	s["train"] = _tone(0.09, 660, 990, "tri", 0.002, 18, 0.0, 1.0, 0.3)
	s["complete"] = _cat([_tone(0.1, 523, 523, "tri", 0.003, 10, 0.0, 1.0, 0.3), _tone(0.1, 659, 659, "tri", 0.003, 10, 0.0, 1.0, 0.3), _tone(0.22, 784, 784, "tri", 0.003, 7, 0.0, 1.0, 0.3)])
	s["research"] = _cat([_tone(0.08, 784, 784, "sine", 0.003, 10, 0.0, 1.0, 0.3), _tone(0.2, 1047, 1047, "sine", 0.003, 7, 0.0, 1.0, 0.3)])
	s["ageup"] = _cat([_tone(0.16, 392, 392, "square", 0.004, 4, 0.0, 0.25, 0.18), _tone(0.16, 523, 523, "square", 0.004, 4, 0.0, 0.25, 0.18), _tone(0.16, 659, 659, "square", 0.004, 4, 0.0, 0.25, 0.18), _tone(0.5, 784, 784, "square", 0.004, 2.5, 0.0, 0.25, 0.2)])
	s["error"] = _tone(0.16, 120, 110, "square", 0.002, 10, 0.0, 0.4, 0.2)
	s["alarm"] = _cat([_tone(0.25, 330, 330, "saw", 0.02, 2, 0.0, 0.2, 0.28), _tone(0.35, 440, 440, "saw", 0.02, 2, 0.0, 0.2, 0.28)])
	for k in s:
		streams[k] = _wav(s[k])
