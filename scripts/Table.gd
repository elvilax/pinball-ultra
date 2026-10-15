extends Node2D
## Mesa: paredes con volumen, carriles inferiores, drenaje y decoración animada.
## Coordenadas 1080x1920. La zona de juego va de x=40 a x=960; a la derecha, el carril de lanzamiento.

signal drained(body: Node)

const P := preload("res://scripts/Palette.gd")

const WALL_HEIGHT := 16.0  # altura visual (falso 3D)
const LEFT_PIVOT := Vector2(302, 1636)
const RIGHT_PIVOT := Vector2(698, 1636)
const BALL_START := Vector2(1000, 1790)
const LAUNCHER_POS := Vector2(1000, 1820)
const CENTER_X := 500.0
const CENTER_ART := Vector2(500, 1090)

var _walls: Array[PackedVector2Array] = []
var _floor := PackedVector2Array()
var _bulbs := PackedVector2Array()
var _diamonds := PackedVector2Array()
var _time := 0.0
var _flash := 0.0
## Se activa durante la tragaperras/ruleta: persecución más rápida y densa.
var _excited := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # las luces siguen con la mesa en pausa
	var arc_left := _arc(Vector2(340, 340), 300.0, PI, PI * 1.5)
	var arc_right := _arc(Vector2(740, 340), 300.0, PI * 1.5, TAU)

	# Contorno: pared izquierda, techo curvo, pared derecha y suelo del carril.
	var outline := PackedVector2Array([Vector2(40, 1920)])
	outline.append_array(arc_left)
	outline.append_array(arc_right)
	outline.append_array([Vector2(1040, 1820), Vector2(960, 1820)])
	_walls.append(outline)
	# Separador del carril de lanzamiento.
	_walls.append(PackedVector2Array([Vector2(960, 420), Vector2(960, 1920)]))
	# Guías inferiores: nacen en la propia pared, así que no hay carriles de
	# salida. Todo lo que baja por los lados acaba en un flipper; la única
	# forma de perder la bola es el hueco central.
	_walls.append(PackedVector2Array([Vector2(40, 1400), Vector2(290, 1620), Vector2(290, 1920)]))
	_walls.append(PackedVector2Array([Vector2(960, 1400), Vector2(710, 1620), Vector2(710, 1920)]))

	_floor.append(Vector2(40, 1920))
	_floor.append_array(arc_left)
	_floor.append_array(arc_right)
	_floor.append(Vector2(1040, 1920))

	var body := StaticBody2D.new()
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.25
	mat.friction = 0.1
	body.physics_material_override = mat
	add_child(body)
	for wall in _walls:
		for i in wall.size() - 1:
			var seg := SegmentShape2D.new()
			seg.a = wall[i]
			seg.b = wall[i + 1]
			var shape := CollisionShape2D.new()
			shape.shape = seg
			body.add_child(shape)

	var drain := Area2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(420, 80)
	var drain_shape := CollisionShape2D.new()
	drain_shape.shape = rect
	drain.position = Vector2(500, 1920)
	drain.add_child(drain_shape)
	add_child(drain)
	drain.body_entered.connect(func(b: Node) -> void: drained.emit(b))

	_place_bulbs(outline, 64.0)
	# Rombos del tapete: solo los que caen dentro de la zona de juego.
	for row in 22:
		for col in 12:
			var p := Vector2(70.0 + col * 84.0 + (42.0 if row % 2 == 1 else 0.0), 90.0 + row * 84.0)
			if p.x < 940.0 and Geometry2D.is_point_in_polygon(p, _floor) \
					and p.distance_to(CENTER_ART) > 280.0 and p.y < 1380.0:
				_diamonds.append(p)


## Enciende todas las bombillas un instante.
func flash(strength := 1.0) -> void:
	_flash = maxf(_flash, strength)


## Mientras esté activo, las bombillas del borde persiguen más rápido y
## densas, para los momentos de tragaperras y ruleta girando.
func set_excited(active: bool) -> void:
	_excited = active


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	queue_redraw()


func _arc(center: Vector2, r: float, from: float, to: float, steps := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


## Reparte bombillas a lo largo de una pared, cada `spacing` píxeles.
func _place_bulbs(wall: PackedVector2Array, spacing: float) -> void:
	var carry := 0.0
	for i in wall.size() - 1:
		var a := wall[i]
		var b := wall[i + 1]
		var length := a.distance_to(b)
		var d := spacing - carry
		while d <= length:
			_bulbs.append(a.lerp(b, d / length))
			d += spacing
		carry = fmod(carry + length, spacing)


func _draw() -> void:
	_draw_floor()
	# Drenaje.
	draw_line(Vector2(300, 1895), Vector2(700, 1895), P.RED_DARK, 14.0)
	draw_line(Vector2(300, 1895), Vector2(700, 1895), P.RED, 5.0)
	_draw_walls()
	_draw_bulbs()


## Tapete verde con rombos, carril de lanzamiento de madera y un filete de latón.
func _draw_floor() -> void:
	draw_colored_polygon(_floor, P.FELT)
	draw_rect(Rect2(960, 420, 80, 1500), P.WOOD)
	for i in 6:
		draw_line(Vector2(972 + i * 12.0, 430), Vector2(972 + i * 12.0, 1815), Color(P.WOOD_DARK, 0.35), 2.0)
	for p in _diamonds:
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -15), p + Vector2(11, 0), p + Vector2(0, 15), p + Vector2(-11, 0)]), P.FELT_DARK)
		draw_circle(p, 2.5, Color(P.BRASS, 0.5))
	# Faldón de madera bajo las guías: la zona muerta queda tapada.
	for apron in [
			PackedVector2Array([Vector2(40, 1400), Vector2(290, 1620), Vector2(290, 1920), Vector2(40, 1920)]),
			PackedVector2Array([Vector2(960, 1400), Vector2(710, 1620), Vector2(710, 1920), Vector2(960, 1920)])]:
		draw_colored_polygon(apron, P.WOOD)
	for i in 7:
		draw_line(Vector2(60 + i * 34.0, 1440 + i * 30.0), Vector2(60 + i * 34.0, 1915), Color(P.WOOD_DARK, 0.3), 3.0)
		draw_line(Vector2(940 - i * 34.0, 1440 + i * 30.0), Vector2(940 - i * 34.0, 1915), Color(P.WOOD_DARK, 0.3), 3.0)


func _draw_walls() -> void:
	var up := Vector2(0, -WALL_HEIGHT)
	for wall in _walls:
		# Sombra y cara lateral de cada tramo.
		var shadow := PackedVector2Array()
		for p in wall:
			shadow.append(p + Vector2(7, 9))
		draw_polyline(shadow, P.SHADOW, 12.0)
		for i in wall.size() - 1:
			var a := wall[i]
			var b := wall[i + 1]
			if absf(a.x - b.x) > 1.0:
				draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), P.BRASS_DARK)
			else:
				draw_line(a, b, P.BRASS_DARK, 12.0)
		var top := PackedVector2Array()
		for p in wall:
			top.append(p + up)
		draw_polyline(top, P.BRASS_DARK, 14.0, true)
		draw_polyline(top, P.BRASS, 9.0, true)
		draw_polyline(top, Color(P.BRASS_LIGHT, 0.9), 2.5, true)


## Bombillas incandescentes sobre el raíl exterior, a paso tranquilo.
func _draw_bulbs() -> void:
	var up := Vector2(0, -WALL_HEIGHT)
	var step := int(_time * (9.0 if _excited else 3.0))
	var period := 2 if _excited else 4
	for i in _bulbs.size():
		var on := posmod(i - step, period) == 0 or _flash > 0.3
		var p := _bulbs[i] + up
		draw_circle(p, 9.0, P.BRASS_DARK)
		if on:
			draw_circle(p, 13.0 * (1.3 if _excited else 1.0), Color(P.BULB_ON, 0.14))
			draw_circle(p, 7.0, P.BULB_ON)
		else:
			draw_circle(p, 6.0, P.BULB_OFF)
