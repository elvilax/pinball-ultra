extends Node
## Audio del juego, generado entero por código (igual que el resto: sin
## ficheros de sonido). Cada efecto es una onda sintetizada una vez y
## cacheada; Sfx.play(nombre) la dispara desde cualquier script del juego.
## La música de la tragaperras es una pista corta en bucle, también sintetizada.

const RATE := 44100
const POOL := 12
const VOLUME_PATH := "user://audio.json"

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music: AudioStreamPlayer
var _music_name := ""

## Volumen lineal 0..1, ajustable desde el menú de ajustes y persistente.
var sfx_volume := 1.0
var music_volume := 1.0
var _sfx_bus := 0
var _music_bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_bus = _ensure_bus("Sfx")
	_music_bus = _ensure_bus("Music")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	_music.bus = "Music"
	add_child(_music)
	_load_volumes()


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus(-1)
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


## Volumen de efectos (bumpers, flippers, tragaperras, etc.), 0..1.
func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(_sfx_bus, linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_mute(_sfx_bus, sfx_volume <= 0.0)
	_save_volumes()


## Volumen de la música de fondo (tragaperras), 0..1.
func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_mute(_music_bus, music_volume <= 0.0)
	_save_volumes()


func _load_volumes() -> void:
	var s := 1.0
	var m := 1.0
	if FileAccess.file_exists(VOLUME_PATH):
		var file := FileAccess.open(VOLUME_PATH, FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			s = clampf(float(data.get("sfx", 1.0)), 0.0, 1.0)
			m = clampf(float(data.get("music", 1.0)), 0.0, 1.0)
	set_sfx_volume(s)
	set_music_volume(m)


func _save_volumes() -> void:
	var file := FileAccess.open(VOLUME_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"sfx": sfx_volume, "music": music_volume}))


## Dispara un efecto de un solo golpe. pitch > 0 lo transporta (1.0 = normal).
func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := _players[_pool_i]
	_pool_i = (_pool_i + 1) % POOL
	p.stream = _get_stream(name)
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()


## Arranca (o deja seguir) una pista en bucle.
func play_music(name: String) -> void:
	if _music_name == name and _music.playing:
		return
	_music_name = name
	_music.volume_db = -9.0
	_music.stream = _get_stream(name)
	_music.play()


func stop_music(fade := 0.2) -> void:
	_music_name = ""
	if not _music.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


func _get_stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = _build(name)
	return _cache[name]


func _build(name: String) -> AudioStreamWAV:
	match name:
		"bumper": return _tone(190.0, 70.0, 0.1, "square", 16.0, 0.25)
		"slingshot": return _tone(560.0, 160.0, 0.08, "square", 20.0, 0.15)
		"target": return _tone(950.0, 720.0, 0.05, "sine", 26.0)
		"drop_target": return _thud(0.14, 12.0)
		"spinner": return _tone(1500.0, 1150.0, 0.035, "sine", 40.0)
		"flipper": return _click(0.025, 55.0)
		"launch": return _tone(260.0, 1000.0, 0.22, "square", 5.0, 0.08)
		"ramp_enter": return _tone(320.0, 680.0, 0.14, "sine", 8.0)
		"ramp": return _chime([660.0, 880.0, 1320.0], 0.09)
		"lane": return _chime([990.0], 0.08)
		"double_pot": return _chime([784.0, 988.0, 1318.0], 0.1)
		"extra_ball": return _chime([660.0, 880.0, 1100.0, 1320.0], 0.11)
		"tilt": return _buzz()
		"drain": return _tone(480.0, 110.0, 0.35, "sine", 4.0)
		"game_over": return _tone(440.0, 70.0, 0.9, "sine", 2.0)
		"multiball": return _chord([440.0, 554.0, 660.0, 880.0], 0.55)
		"tunnel": return _tone(300.0, 760.0, 0.2, "sine", 7.0)
		"slot_tick": return _click(0.02, 70.0)
		"slot_stop": return _thud(0.07, 24.0)
		"slot_lever": return _thud(0.28, 4.0)
		"slot_pair": return _chime([660.0, 880.0], 0.1)
		"slot_lose": return _tone(220.0, 130.0, 0.14, "square", 12.0, 0.35)
		"roulette_drop": return _tone(300.0, 170.0, 0.12, "sine", 18.0)
		"roulette_lose": return _tone(220.0, 100.0, 0.2, "square", 10.0, 0.3)
		"jackpot": return _chord([523.25, 659.25, 784.0, 1046.5], 0.4)
		"slot_loop": return _slot_music()
	return _tone(440.0, 440.0, 0.05, "sine", 30.0)


# --- Generadores -----------------------------------------------------------

func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _put(data: PackedByteArray, i: int, s: float) -> void:
	data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))


func _osc(kind: String, phase: float) -> float:
	var ph := fposmod(phase, 1.0)
	match kind:
		"square": return 1.0 if ph < 0.5 else -1.0
		"triangle": return 1.0 - 4.0 * absf(ph - 0.5)
		"saw": return 2.0 * ph - 1.0
	return sin(ph * TAU)  # "sine" por defecto


## Tono con barrido de frecuencia (freq0 -> freq1) y caída exponencial;
## noise_mix > 0 le mezcla ruido blanco encima (para que suene a golpe, no a pito).
func _tone(freq0: float, freq1: float, duration: float, kind: String, decay: float, noise_mix := 0.0) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := lerpf(freq0, freq1, t / duration)
		phase += freq / RATE
		var wave := _osc(kind, phase)
		if noise_mix > 0.0:
			wave = lerpf(wave, randf_range(-1.0, 1.0), noise_mix)
		var env := minf(1.0, t / 0.004) * exp(-decay * t)
		_put(data, i, wave * env * 0.9)
	return _wrap(data)


## Golpe sordo: ruido filtrado (paso bajo simple) con caída rápida. Para
## dianas que caen, remates de rodillo, tirón de la palanca.
func _thud(duration: float, decay: float) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		prev = lerpf(prev, randf_range(-1.0, 1.0), 0.14)
		var env := exp(-decay * t)
		_put(data, i, prev * env)
	return _wrap(data)


## Clic seco: ruido blanco sin filtrar, caída muy rápida. Flippers, rodillos.
func _click(duration: float, decay: float) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-decay * t)
		_put(data, i, randf_range(-1.0, 1.0) * env * 0.8)
	return _wrap(data)


## Zumbido disonante y sostenido: dos cuadradas casi a la misma frecuencia. Tilt.
func _buzz() -> AudioStreamWAV:
	var duration := 0.45
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t := float(i) / RATE
		p1 += 90.0 / RATE
		p2 += 97.0 / RATE
		var wave := (_osc("square", p1) + _osc("square", p2)) * 0.5
		var env := minf(1.0, t / 0.02) * clampf((duration - t) / 0.1, 0.0, 1.0)
		_put(data, i, wave * env * 0.85)
	return _wrap(data)


## Arpegio: cada frecuencia de la lista suena una tras otra, tipo campanilla.
func _chime(freqs: Array, note_dur: float) -> AudioStreamWAV:
	var note_n := int(RATE * note_dur)
	var n := note_n * freqs.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	var idx := 0
	for f in freqs:
		var phase := 0.0
		for i in note_n:
			var t := float(i) / RATE
			phase += float(f) / RATE
			var env := exp(-7.0 * t)
			_put(data, idx, sin(phase * TAU) * env * 0.85)
			idx += 1
	return _wrap(data)


## Acorde: todas las frecuencias a la vez, para un golpe dramático (jackpot, multibola).
func _chord(freqs: Array, duration: float) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phases := []
	for f in freqs:
		phases.append(0.0)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.01) * exp(-2.4 * t)
		var mix := 0.0
		for fi in freqs.size():
			phases[fi] += float(freqs[fi]) / RATE
			mix += sin(phases[fi] * TAU)
		mix /= freqs.size()
		_put(data, i, mix * env * 0.9)
	return _wrap(data)


## Pista corta en bucle, estilo tragaperras de bar: arpegio de campanas que se
## repite mientras giran los rodillos.
func _slot_music() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 784.0, 1046.5, 784.0, 659.25]  # C5 E5 G5 C6 G5 E5
	var note_dur := 0.13
	var note_n := int(RATE * note_dur)
	var n := note_n * notes.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	var idx := 0
	for f in notes:
		var phase := 0.0
		for i in note_n:
			var t := float(i) / RATE
			phase += f / RATE
			var env := minf(1.0, t / 0.008) * (1.0 - t / note_dur * 0.25)
			_put(data, idx, _osc("triangle", phase) * env * 0.8)
			idx += 1
	var wav := _wrap(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
