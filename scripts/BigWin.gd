extends CanvasLayer
## Animación "BIG WIN" a pantalla completa, estilo tragaperras de casino.
##
## Uso:
##     big_win.shake_target = camara      # opcional: Camera2D (u otro nodo) al que sacudir
##     big_win.play(27000)
##     await big_win.finished
##
## El premio empieza como BIG WIN y, mientras el contador sube, va escalando a
## MEGA WIN y ULTRA WIN cada vez que cruza el mínimo del siguiente nivel.

const P := preload("res://scripts/Palette.gd")
signal finished

## Niveles ordenados de menor a mayor. Añade o retoca aquí para cambiar el espectáculo.
const TIERS := [
	{"min": 0, "title": "BIG WIN", "color": Color(0.62, 0.16, 0.13), "shake": 16.0, "particles": 120},
	{"min": 10000, "title": "MEGA WIN", "color": Color(0.12, 0.33, 0.38), "shake": 28.0, "particles": 220},
	{"min": 25000, "title": "ULTRA WIN", "color": Color(0.78, 0.6, 0.22), "shake": 42.0, "particles": 360},
]
const VIEW := Vector2(1080, 1920)
const CENTER := Vector2(540, 800)
const COUNT_TIME_PER_TIER := 1.9
const TITLE_SIZE := 160
const TITLE_MAX_WIDTH := 850.0
const BULB_SPACING := 62.0

## Nodo que se sacude (por ejemplo una Camera2D) y la propiedad Vector2 que se mueve.
var shake_target: Node = null
var shake_property := "offset"

var shake := 0.0

var _stage: Control
var _dim: ColorRect
var _flash: ColorRect
var _rays: Node2D
var _bulbs: Node2D
var _bulb_points := PackedVector2Array()
var _title: Node2D
var _letters: Array[Label] = []
var _counter: Label
var _coins: CPUParticles2D
var _burst: CPUParticles2D
var _fountains: Array[CPUParticles2D] = []
var _color := Color.WHITE
var _tier_index := 0
var _target_tier := 0
var _start_tier := 0
var _playing := false
var _counting := false
var _time := 0.0
var _firework_timer := 0.0
var _shake_tween: Tween


static func tier_index_for(amount: int) -> int:
	var result := 0
	for i in TIERS.size():
		if amount >= TIERS[i]["min"]:
			result = i
	return result


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue animando con la mesa en pausa
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_dim = _make_rect(Color(0, 0, 0, 0))

	_rays = Node2D.new()
	_rays.position = CENTER
	_stage.add_child(_rays)
	_rays.draw.connect(_draw_rays)

	var coin := _make_coin_texture()
	_coins = _make_particles(Vector2(VIEW.x / 2.0, -40), coin)
	_coins.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_coins.emission_rect_extents = Vector2(VIEW.x / 2.0, 10)
	_coins.direction = Vector2.DOWN
	_coins.spread = 12.0
	_coins.initial_velocity_min = 400.0
	_coins.initial_velocity_max = 1000.0
	_coins.gravity = Vector2(0, 700)
	_coins.amount = 80
	_coins.lifetime = 2.6
	_coins.scale_amount_min = 0.7
	_coins.scale_amount_max = 1.5

	_title = Node2D.new()
	_title.position = Vector2(VIEW.x / 2.0, 640)
	_stage.add_child(_title)

	_counter = Label.new()
	_counter.position = Vector2(0, 800)
	_counter.size = Vector2(VIEW.x, 240)
	_counter.pivot_offset = _counter.size / 2.0
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter.add_theme_font_override("font", P.font())
	_counter.add_theme_font_size_override("font_size", 150)
	_counter.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.0))
	_counter.add_theme_constant_override("outline_size", 30)
	_stage.add_child(_counter)

	# Confeti en explosión desde el centro.
	_burst = _make_particles(CENTER, null)
	_burst.one_shot = true
	_burst.explosiveness = 0.95
	_burst.direction = Vector2.UP
	_burst.spread = 180.0
	_burst.initial_velocity_min = 500.0
	_burst.initial_velocity_max = 1700.0
	_burst.gravity = Vector2(0, 1300)
	_burst.lifetime = 2.2
	_burst.scale_amount_min = 10.0
	_burst.scale_amount_max = 28.0

	# Dos fuentes de monedas desde las esquinas de abajo.
	for side in [-1.0, 1.0]:
		var f := _make_particles(Vector2(VIEW.x / 2.0 + side * 500.0, VIEW.y + 20.0), coin)
		f.direction = Vector2(-side * 0.35, -1.0)
		f.spread = 14.0
		f.initial_velocity_min = 1500.0
		f.initial_velocity_max = 2400.0
		f.gravity = Vector2(0, 1900)
		f.amount = 36
		f.lifetime = 2.4
		f.scale_amount_min = 0.8
		f.scale_amount_max = 1.6
		_fountains.append(f)
		# Detrás del título y del contador, para no taparlos.
		_stage.move_child(f, _coins.get_index())

	_bulbs = Node2D.new()
	_stage.add_child(_bulbs)
	_bulbs.draw.connect(_draw_bulbs)
	_place_bulbs()

	_flash = _make_rect(Color(1, 1, 1, 0))
	visible = false


func _process(delta: float) -> void:
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	offset = off * 0.6
	if shake_target != null:
		shake_target.set(shake_property, off)
	if not _playing:
		return

	_time += delta
	_rays.rotation += delta * 0.25
	_bulbs.queue_redraw()
	# Las letras bailan en ola.
	for i in _letters.size():
		var letter := _letters[i]
		letter.position.y = letter.get_meta("base_y") + sin(_time * 7.0 + i * 0.7) * 16.0
		letter.rotation = sin(_time * 5.0 + i * 0.9) * 0.07
	if _counting:
		_counter.scale = Vector2.ONE * (1.0 + 0.06 * absf(sin(_time * 22.0)))
		_firework_timer -= delta
		if _firework_timer <= 0.0:
			_firework_timer = 0.22
			_spawn_firework()


## Lanza la animación completa para una cantidad de puntos.
## `start_tier` hace que empiece ya en ese nivel (2 = directamente ULTRA WIN).
## `quick` la acorta: sirve para premios pequeños.
func play(amount: int, start_tier := 0, quick := false) -> void:
	if _playing:
		return
	_playing = true
	_time = 0.0
	_target_tier = maxi(tier_index_for(amount), start_tier)
	_tier_index = start_tier
	_start_tier = start_tier

	# 1) La pantalla entera se transforma: fondo, rayos, marco de bombillas, título.
	_stage.modulate.a = 1.0
	_dim.color.a = 0.0
	_rays.scale = Vector2.ZERO
	_bulbs.modulate.a = 0.0
	_counter.scale = Vector2.ZERO
	_show_count(0.0)
	visible = true
	_apply_tier(start_tier)
	var intro := create_tween().set_parallel(true)
	intro.tween_property(_dim, "color:a", 0.8, 0.2)
	intro.tween_property(_rays, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_bulbs, "modulate:a", 1.0, 0.3)
	intro.tween_property(_counter, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.6)
	await intro.finished

	# 2) El contador rueda de 0 al total; llueven monedas y estallan fuegos.
	_coins.emitting = true
	for f in _fountains:
		f.emitting = true
	_counting = true
	var count := create_tween()
	count.tween_method(_roll, 0.0, float(amount),
			0.9 if quick else COUNT_TIME_PER_TIER * (_target_tier - start_tier + 1)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await count.finished
	_counting = false

	# 3) Golpe final al llegar al total.
	_show_count(float(amount))
	_do_flash(P.CREAM, 0.6, 0.45)
	_kick_shake(TIERS[_tier_index]["shake"] * 1.4, 0.7)
	_zoom_punch(1.12)
	_burst.restart()
	_counter.scale = Vector2(2.0, 2.0)
	create_tween().tween_property(_counter, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.9 if quick else 1.8).timeout

	# 4) Salida.
	_coins.emitting = false
	for f in _fountains:
		f.emitting = false
	var outro := create_tween().set_parallel(true)
	outro.tween_property(_stage, "modulate:a", 0.0, 0.45)
	outro.tween_property(_rays, "scale", Vector2(2.5, 2.5), 0.45).set_ease(Tween.EASE_IN)
	outro.tween_property(_title, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await outro.finished

	visible = false
	_playing = false
	shake = 0.0
	finished.emit()


## Avanza el contador y sube de nivel cuando cruza el mínimo del siguiente.
func _roll(value: float) -> void:
	_show_count(value)
	while _tier_index < _target_tier and value >= TIERS[_tier_index + 1]["min"]:
		_tier_index += 1
		_apply_tier(_tier_index)


## Cambia título y colores con un golpe de efecto. Sirve para la entrada y para cada subida.
func _apply_tier(index: int) -> void:
	var tier: Dictionary = TIERS[index]
	Sfx.play("jackpot", 0.0, 1.0 + index * 0.16)
	_color = tier["color"]
	_rays.modulate = _color
	_counter.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	_set_title(tier["title"])
	_title.scale = Vector2(1.8, 1.8) if index > _start_tier else Vector2.ONE
	create_tween().tween_property(_title, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var ramp := Gradient.new()
	ramp.set_color(0, _color)
	ramp.set_color(1, P.CREAM)
	ramp.add_point(0.5, P.BRASS)
	_burst.color_initial_ramp = ramp
	_burst.amount = tier["particles"]
	_burst.restart()

	_do_flash(P.CREAM, 0.55, 0.4)
	_kick_shake(tier["shake"], 0.8)
	_zoom_punch(1.06 + index * 0.03)


## Crea una etiqueta por letra para poder animarlas una a una.
func _set_title(text: String) -> void:
	for letter in _letters:
		letter.queue_free()
	_letters.clear()

	var font := P.font()
	# Si el título no cabe a tamaño completo, se reduce la letra lo justo.
	var full := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var font_size := int(TITLE_SIZE * minf(1.0, TITLE_MAX_WIDTH / full))
	var height := font.get_height(font_size)
	var widths: Array[float] = []
	var total := 0.0
	for i in text.length():
		var w := font_size * 0.32
		if text[i] != " ":
			w = font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0
		widths.append(w)
		total += w

	var x := -total / 2.0
	for i in text.length():
		if text[i] != " ":
			var letter := Label.new()
			letter.text = text[i]
			letter.size = Vector2(widths[i], height)
			letter.position = Vector2(x, -height / 2.0)
			letter.pivot_offset = letter.size / 2.0
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.add_theme_font_override("font", font)
			letter.add_theme_font_size_override("font_size", font_size)
			letter.add_theme_color_override("font_color", P.CREAM)
			letter.add_theme_color_override("font_outline_color", _color.darkened(0.45))
			letter.add_theme_constant_override("outline_size", 34)
			letter.set_meta("base_y", letter.position.y)
			letter.scale = Vector2(5, 5)
			letter.modulate.a = 0.0
			_title.add_child(letter)
			# Cada letra cae desde "delante de la pantalla" y rebota al aterrizar.
			var drop := letter.create_tween().set_parallel(true)
			var delay := _letters.size() * 0.06
			drop.tween_property(letter, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(delay)
			drop.tween_property(letter, "modulate:a", 1.0, 0.12).set_delay(delay)
			_letters.append(letter)
		x += widths[i]


func _show_count(value: float) -> void:
	var s := str(int(round(value)))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	_counter.text = s + out


func _do_flash(color: Color, alpha: float, time: float) -> void:
	_flash.color = Color(color, alpha)
	create_tween().tween_property(_flash, "color:a", 0.0, time)


func _kick_shake(strength: float, time: float) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	shake = strength
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "shake", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Golpe de zoom sobre la mesa (solo si shake_target es una cámara).
func _zoom_punch(amount: float) -> void:
	var camera := shake_target as Camera2D
	if camera == null:
		return
	camera.zoom = Vector2(amount, amount)
	create_tween().tween_property(camera, "zoom", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _spawn_firework() -> void:
	var fw := CPUParticles2D.new()
	fw.position = Vector2(randf_range(120, VIEW.x - 120), randf_range(250, 1500))
	fw.one_shot = true
	fw.explosiveness = 1.0
	fw.amount = 40
	fw.lifetime = 0.9
	fw.spread = 180.0
	fw.initial_velocity_min = 250.0
	fw.initial_velocity_max = 650.0
	fw.gravity = Vector2(0, 500)
	fw.damping_min = 200.0
	fw.damping_max = 300.0
	fw.scale_amount_min = 6.0
	fw.scale_amount_max = 14.0
	fw.color = [P.BULB_ON, P.CREAM, P.BRASS, P.RED].pick_random()
	_stage.add_child(fw)
	_stage.move_child(fw, _title.get_index())
	fw.emitting = true
	get_tree().create_timer(1.2).timeout.connect(fw.queue_free)


func _draw_rays() -> void:
	var count := 18
	for i in count:
		var a0 := TAU * i / count
		var a1 := a0 + TAU / count * 0.5
		_rays.draw_colored_polygon(PackedVector2Array([
			Vector2.ZERO, Vector2.from_angle(a0) * 1800.0, Vector2.from_angle(a1) * 1800.0]),
			Color(1, 1, 1, 0.3))
	for r in [560.0, 400.0, 250.0]:
		_rays.draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.07))


func _place_bulbs() -> void:
	var m := 34.0
	var corners := [Vector2(m, m), Vector2(VIEW.x - m, m), Vector2(VIEW.x - m, VIEW.y - m), Vector2(m, VIEW.y - m)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var steps := int(round(a.distance_to(b) / BULB_SPACING))
		for s in steps:
			_bulb_points.append(a.lerp(b, float(s) / steps))


## Marco de bombillas alrededor de toda la pantalla, con luces persiguiéndose.
func _draw_bulbs() -> void:
	var w := 68.0
	var frame := Color(0.22, 0.03, 0.05, 0.95)
	_bulbs.draw_rect(Rect2(0, 0, VIEW.x, w), frame)
	_bulbs.draw_rect(Rect2(0, VIEW.y - w, VIEW.x, w), frame)
	_bulbs.draw_rect(Rect2(0, w, w, VIEW.y - w * 2.0), frame)
	_bulbs.draw_rect(Rect2(VIEW.x - w, w, w, VIEW.y - w * 2.0), frame)
	_bulbs.draw_rect(Rect2(w, w, VIEW.x - w * 2.0, VIEW.y - w * 2.0), _color, false, 5.0)
	var step := int(_time * 12.0)
	for i in _bulb_points.size():
		var p := _bulb_points[i]
		if posmod(i - step, 3) == 0:
			_bulbs.draw_circle(p, 26.0, Color(1.0, 0.9, 0.4, 0.3))
			_bulbs.draw_circle(p, 14.0, Color(1.0, 0.97, 0.75))
		else:
			_bulbs.draw_circle(p, 11.0, _color.darkened(0.5))


## Moneda dorada generada por código (sin imágenes externas).
func _make_coin_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 0.7, 0.88, 0.94])
	grad.colors = PackedColorArray([
		Color(1.0, 0.97, 0.6), Color(1.0, 0.8, 0.15), Color(0.85, 0.55, 0.0),
		Color(1.0, 0.85, 0.3), Color(1.0, 0.8, 0.2, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 48
	tex.height = 48
	return tex


func _make_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	# Más grande que la pantalla para que la sacudida no deje ver los bordes.
	rect.position = -VIEW * 0.25
	rect.size = VIEW * 1.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(rect)
	return rect


func _make_particles(pos: Vector2, texture: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.texture = texture
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	_stage.add_child(p)
	return p
