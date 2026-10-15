extends CanvasLayer
## Tragaperras del túnel de arriba. Main llama a spin() al capturar la bola;
## "gira" los 3 rodillos y al final emite finished(matches, symbols). Todo
## dibujado por código (sin imágenes): marco con bombillas en persecución,
## palanca lateral y tambores con el mismo lenguaje visual que el HUD.
##
## MECANISMO (distinto del original): nada de posición continua ni de Tween
## para el giro. Cada rodillo tiene un cronómetro propio por fotograma
## (_elapsed[i] contra DURATION[i]): mientras dura, va cambiando de símbolo
## al azar a saltos cada vez más espaciados (como si frenase), y en el
## instante exacto en que se cumple su tiempo se fija de golpe en el símbolo
## de resultado y no se vuelve a tocar. No hay ninguna variable que arrastre
## nada de una tirada a otra: spin() reinicia los tres cronómetros a cero.

signal finished(matches: int, symbols: Array)

const P := preload("res://scripts/Palette.gd")

enum { BAR, BELL, DIAMOND, STAR, SEVEN }
const SYMBOL_COUNT := 5
const REELS := 3
const REEL_SIZE := Vector2(210, 210)
const REEL_GAP := 16.0
const PANEL := Rect2(70, 374, 860, 312)
const LEVER_X := PANEL.position.x + PANEL.size.x + 46.0
const BULB_SPACING := 46.0
## Cuánto dura cada rodillo "girando" antes de fijarse (el último, más: efecto de suspense).
const DURATION: Array[float] = [1.0, 1.6, 2.4]
## Cada cuánto cambia de símbolo al principio y al final del giro (se interpola entre
## los dos según el tiempo transcurrido: empieza rápido y acaba casi parado).
const SWAP_FAST := 0.045
const SWAP_SLOW := 0.26

# --- Azar (fácil de cambiar): reparto de resultados de la tirada ---
const CHANCE_JACKPOT := 0.10   ## 3 iguales
const CHANCE_PAIR := 0.40      ## 2 iguales (el resto, 0.50, no empareja nada)

var _stage: Control
var _panel: Control
var _reels: Array[Control] = []

## Estado de cada rodillo, reiniciado entero en cada spin().
var _symbol: Array[int] = [0, 0, 0]      ## símbolo que se ve ahora mismo
var _result: Array[int] = [0, 0, 0]      ## símbolo al que debe llegar
var _elapsed: Array[float] = [0.0, 0.0, 0.0]
var _next_swap: Array[float] = [0.0, 0.0, 0.0]
var _done: Array[bool] = [true, true, true]

var _window_rect := Rect2()
var _bulb_points := PackedVector2Array()
var _time := 0.0
var _jackpot_flash := 0.0
var _lever_pull := 0.0


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_stage = Control.new()
	_stage.size = Vector2(1080, 1920)
	_stage.pivot_offset = PANEL.get_center()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_panel)
	_panel.draw.connect(_draw_panel)

	var total_w := REELS * REEL_SIZE.x + (REELS - 1) * REEL_GAP
	var x0 := PANEL.get_center().x - total_w / 2.0
	var y0 := PANEL.get_center().y - REEL_SIZE.y / 2.0
	_window_rect = Rect2(Vector2(x0, y0), Vector2(total_w, REEL_SIZE.y)).grow(16.0)

	for i in REELS:
		var reel := Control.new()
		reel.position = Vector2(x0 + i * (REEL_SIZE.x + REEL_GAP), y0)
		reel.size = REEL_SIZE
		reel.clip_contents = true
		reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(reel)
		reel.draw.connect(_draw_reel.bind(i))
		_reels.append(reel)

	_place_bulbs()


## Bombillas repartidas por todo el perímetro del marco, como en la mesa.
func _place_bulbs() -> void:
	var r := PANEL.grow(10.0)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var steps := maxi(2, int(round(a.distance_to(b) / BULB_SPACING)))
		for s in steps:
			_bulb_points.append(a.lerp(b, float(s) / steps))


func _process(delta: float) -> void:
	_time += delta
	if not visible:
		return
	_jackpot_flash = maxf(0.0, _jackpot_flash - delta * 1.2)
	_advance_reels(delta)
	_panel.queue_redraw()
	for reel in _reels:
		reel.queue_redraw()


## El corazón del "giro": a cada rodillo que no haya terminado se le suma el
## tiempo; si con eso ya cumple su duración, se para en seco en el símbolo de
## resultado (una vez, para siempre: _done[i] ya no vuelve a tocarse hasta el
## próximo spin()). Si no, puede que le toque cambiar de símbolo al azar.
func _advance_reels(delta: float) -> void:
	for i in REELS:
		if _done[i]:
			continue
		_elapsed[i] += delta
		if _elapsed[i] >= DURATION[i]:
			_done[i] = true
			_symbol[i] = _result[i]
			Sfx.play("slot_stop")
			continue
		_next_swap[i] -= delta
		if _next_swap[i] <= 0.0:
			_symbol[i] = randi() % SYMBOL_COUNT
			Sfx.play("slot_tick", -8.0)
			var progress := _elapsed[i] / DURATION[i]
			_next_swap[i] = lerpf(SWAP_FAST, SWAP_SLOW, progress)


## Tirada automática: decide el resultado, arranca los 3 cronómetros y
## espera a que los tres terminen.
func spin() -> void:
	visible = true
	_jackpot_flash = 0.0
	Sfx.play_music("slot_loop")
	Sfx.play("slot_lever")

	var matches: int
	var result_symbols: Array = [0, 0, 0]
	var outcome := randf()
	if outcome < CHANCE_JACKPOT:
		matches = 3
		var sym := randi() % SYMBOL_COUNT
		result_symbols = [sym, sym, sym]
	elif outcome < CHANCE_JACKPOT + CHANCE_PAIR:
		matches = 2
		var sym := randi() % SYMBOL_COUNT
		var other := (sym + 1 + randi() % (SYMBOL_COUNT - 1)) % SYMBOL_COUNT
		result_symbols = [sym, sym, other]
		result_symbols.shuffle()
	else:
		matches = 0
		var picks := range(SYMBOL_COUNT)
		picks.shuffle()
		result_symbols = [picks[0], picks[1], picks[2]]

	for i in REELS:
		_result[i] = result_symbols[i]
		_elapsed[i] = 0.0
		_next_swap[i] = 0.0
		_done[i] = false

	# Solo rebote de escala, sin fundido: con alpha de por medio se ve un
	# instante la mesa transparentándose a través del panel.
	_stage.scale = Vector2(0.65, 0.65)
	_stage.modulate.a = 1.0
	var intro := create_tween()
	intro.tween_property(_stage, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Tirón de la palanca al empezar, como en una tragaperras de verdad.
	var lever := create_tween()
	lever.tween_property(self, "_lever_pull", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	lever.tween_property(self, "_lever_pull", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Espera activa a que los tres rodillos hayan terminado de verdad
	# (_advance_reels los va cerrando uno a uno en _process). No depende de
	# ningún Tween: si el bucle de delta no corre, tampoco corre esta espera.
	while not (_done[0] and _done[1] and _done[2]):
		await get_tree().process_frame

	Sfx.stop_music(0.15)
	if matches == 3:
		_jackpot_flash = 1.0
		await get_tree().create_timer(1.0).timeout
	elif matches == 2:
		Sfx.play("slot_pair")
	else:
		Sfx.play("slot_lose")

	# Igual que en la entrada: se encoge hasta desaparecer sin fundido, para
	# no dejar ver la mesa de fondo a través del panel.
	var outro := create_tween()
	outro.tween_property(_stage, "scale", Vector2(0.01, 0.01), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await outro.finished

	visible = false
	finished.emit(matches, result_symbols)


func _draw_panel() -> void:
	_panel.draw_rect(PANEL.grow(10.0), P.BRASS_DARK)
	_panel.draw_rect(PANEL, P.WOOD)
	_panel.draw_rect(PANEL.grow(-14.0), P.RED_DARK)
	_panel.draw_rect(PANEL.grow(-14.0), P.BRASS, false, 4.0)
	_panel.draw_rect(_window_rect, P.BLACK)
	_panel.draw_rect(_window_rect, P.BRASS, false, 5.0)
	if _jackpot_flash > 0.0:
		var a := (sin(_time * 30.0) * 0.5 + 0.5) * _jackpot_flash
		_panel.draw_rect(_window_rect.grow(6.0), Color(P.BULB_ON, a), false, 10.0)

	# Remaches de latón en las esquinas.
	var g := PANEL.grow(10.0)
	for corner in [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]:
		_panel.draw_circle(corner, 7.0, P.BRASS)
		_panel.draw_circle(corner, 4.0, P.BRASS_DARK)

	_draw_bulbs()
	_draw_lever()


## Bombillas persiguiéndose alrededor del marco; se encienden todas con el premio gordo.
func _draw_bulbs() -> void:
	var step := int(_time * 10.0)
	for i in _bulb_points.size():
		var on := posmod(i - step, 3) == 0 or _jackpot_flash > 0.4
		var p: Vector2 = _bulb_points[i]
		if on:
			_panel.draw_circle(p, 12.0, Color(P.BULB_ON, 0.22))
			_panel.draw_circle(p, 6.5, P.BULB_ON)
		else:
			_panel.draw_circle(p, 6.5, P.BULB_OFF)
		_panel.draw_arc(p, 6.5, 0.0, TAU, 10, P.BRASS_DARK, 1.5, true)


## Palanca decorativa: se tira de ella al arrancar la tirada.
func _draw_lever() -> void:
	var top := Vector2(LEVER_X, PANEL.position.y + 20.0)
	var bottom := Vector2(LEVER_X, PANEL.end.y - 20.0)
	_panel.draw_line(top, bottom, P.BRASS_DARK, 10.0)
	_panel.draw_circle(top, 10.0, P.BRASS_DARK)
	_panel.draw_circle(bottom, 10.0, P.BRASS_DARK)
	var handle := top.lerp(bottom, 0.12 + _lever_pull * 0.68)
	_panel.draw_line(top, handle, P.BRASS, 7.0)
	_panel.draw_circle(handle, 20.0, Color(0.6, 0.16, 0.13))
	_panel.draw_circle(handle, 20.0, P.BRASS_DARK)
	_panel.draw_arc(handle, 20.0, 0.0, TAU, 20, P.BRASS, 3.0, true)
	_panel.draw_circle(handle + Vector2(-6, -6), 6.0, Color(1, 1, 1, 0.35))


## Un rodillo: un único símbolo centrado en la ventana (nada de recortar dos
## filas ni de desplazar nada que se pueda desalinear). Mientras sigue
## girando, un vaivén vertical puramente visual dice "esto se está moviendo"
## incluso en los huecos entre un cambio de símbolo y el siguiente; en cuanto
## el rodillo termina (_done[i]) se para en seco, sin tocar el cronómetro.
func _draw_reel(i: int) -> void:
	var reel := _reels[i]
	var wobble := sin(_time * 42.0 + i * 7.0) * 9.0 if not _done[i] else 0.0
	reel.draw_rect(Rect2(Vector2.ZERO, REEL_SIZE), Color(0.05, 0.04, 0.03))
	_draw_symbol(reel, _symbol[i], REEL_SIZE / 2.0 + Vector2(0, wobble), REEL_SIZE.x * 0.72)
	for j in 3:
		var h := 40.0 - j * 12.0
		reel.draw_rect(Rect2(0, 0, REEL_SIZE.x, h), Color(0, 0, 0, 0.22))
		reel.draw_rect(Rect2(0, REEL_SIZE.y - h, REEL_SIZE.x, h), Color(0, 0, 0, 0.22))


## Icono de símbolo dibujado a mano (sin imágenes), centrado en `center`, con
## una pizca de sombra/brillo para que no se vean planos.
func _draw_symbol(c: Control, id: int, center: Vector2, size: float) -> void:
	var font := P.font()
	match id:
		BAR:
			var r := Rect2(center - Vector2(size * 0.42, size * 0.26), Vector2(size * 0.84, size * 0.52))
			c.draw_rect(r.grow(4.0).grow_side(SIDE_BOTTOM, 6.0), Color(0, 0, 0, 0.3))
			c.draw_rect(r, Color(0.1, 0.08, 0.06))
			c.draw_rect(r.grow(-6.0), P.BRASS)
			c.draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12.0, r.size.y * 0.3)), Color(P.BRASS_LIGHT, 0.5))
			c.draw_string(font, center + Vector2(-size * 0.32, 12), "BAR",
					HORIZONTAL_ALIGNMENT_CENTER, size * 0.64, 34, Color(0.1, 0.08, 0.06))
		BELL:
			var dome := PackedVector2Array()
			for a in range(0, 181, 20):
				var r := deg_to_rad(float(a))
				dome.append(center + Vector2(-cos(r), -sin(r)) * size * 0.32 + Vector2(0, -size * 0.08))
			c.draw_colored_polygon(dome, P.BULB_ON.darkened(0.1))
			c.draw_circle(center + Vector2(-size * 0.07, -size * 0.14), size * 0.1, Color(1, 0.96, 0.8))
			c.draw_circle(center + Vector2(0, -size * 0.08), size * 0.08, P.BULB_ON)
			c.draw_rect(Rect2(center + Vector2(-size * 0.22, size * 0.24), Vector2(size * 0.44, size * 0.1)), P.BRASS_DARK)
			c.draw_circle(center + Vector2(0, size * 0.38), size * 0.06, P.BRASS_DARK)
		DIAMOND:
			var pts := PackedVector2Array([
				center + Vector2(0, -size * 0.38), center + Vector2(size * 0.3, 0),
				center + Vector2(0, size * 0.38), center + Vector2(-size * 0.3, 0)])
			c.draw_colored_polygon(pts, P.RED)
			var hi := PackedVector2Array([
				center + Vector2(0, -size * 0.38), center + Vector2(size * 0.14, -size * 0.1),
				center, center + Vector2(-size * 0.14, -size * 0.1)])
			c.draw_colored_polygon(hi, Color(1, 1, 1, 0.22))
			pts.append(pts[0])
			c.draw_polyline(pts, P.CREAM, 3.0, true)
		STAR:
			var pts := PackedVector2Array()
			for i2 in 10:
				var a := -PI / 2.0 + i2 * PI / 5.0
				var rad := size * (0.38 if i2 % 2 == 0 else 0.16)
				pts.append(center + Vector2(cos(a), sin(a)) * rad)
			c.draw_colored_polygon(pts, P.BULB_ON)
			c.draw_circle(center + Vector2(-size * 0.08, -size * 0.14), size * 0.07, Color(1, 1, 0.9, 0.6))
		SEVEN:
			# draw_string posiciona por línea base, no centrado como el resto
			# de símbolos (círculos/polígonos alrededor de `center`): hay que
			# bajarlo para que el carácter quede centrado de verdad, no pegado
			# arriba de la celda.
			var pos := center + Vector2(-size * 0.22, size * 0.15)
			c.draw_string_outline(font, pos + Vector2(4, 4), "7", HORIZONTAL_ALIGNMENT_CENTER, size * 0.6, int(size * 0.7), 4, Color(0, 0, 0, 0.35))
			c.draw_string_outline(font, pos, "7", HORIZONTAL_ALIGNMENT_CENTER, size * 0.6, int(size * 0.7), 8, P.BLACK)
			c.draw_string(font, pos, "7", HORIZONTAL_ALIGNMENT_CENTER, size * 0.6, int(size * 0.7), P.RED.lightened(0.1))
