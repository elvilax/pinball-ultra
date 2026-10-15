extends Node2D
## Rampa elevada (pasadizo): si la bola entra por la boca subiendo con fuerza,
## recorre el tubo por encima de la mesa y sale por el otro extremo.

signal completed(at: Vector2)

const SPEED := 1700.0
const MIN_ENTRY_SPEED := 450.0  # velocidad hacia arriba necesaria para subir
const EXIT_SPEED := 500.0
const WIDTH := 62.0
const COLOR := Color(0.72, 0.58, 0.3)  # raíles de latón

## Puntos de control del recorrido (boca -> salida), en coordenadas de la mesa.
var control_points := PackedVector2Array()

var _points := PackedVector2Array()
var _lengths := PackedFloat32Array()
var _left := PackedVector2Array()
var _right := PackedVector2Array()
var _ball: RigidBody2D = null
var _dist := 0.0
var _cooldown := 0.0
var _time := 0.0
var _flash := 0.0


func _ready() -> void:
	z_index = 10
	_bake()
	var area := Area2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	var shape := CollisionShape2D.new()
	shape.shape = circle
	area.position = _points[0]
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_mouth_entered)


## Suaviza los puntos de control con Catmull-Rom y precalcula raíles y longitudes.
func _bake() -> void:
	var n := control_points.size()
	for i in n - 1:
		var p0 := control_points[maxi(i - 1, 0)]
		var p1 := control_points[i]
		var p2 := control_points[i + 1]
		var p3 := control_points[mini(i + 2, n - 1)]
		for s in 12:
			var t := s / 12.0
			_points.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	_points.append(control_points[n - 1])
	var total := 0.0
	for i in _points.size():
		if i > 0:
			total += _points[i].distance_to(_points[i - 1])
		_lengths.append(total)
		var normal := _tangent(i).orthogonal() * WIDTH / 2.0
		_left.append(_points[i] + normal)
		_right.append(_points[i] - normal)


func _tangent(i: int) -> Vector2:
	var last := _points.size() - 1
	return (_points[mini(i + 1, last)] - _points[maxi(i - 1, 0)]).normalized()


func _on_mouth_entered(body: Node) -> void:
	if _ball != null or _cooldown > 0.0 or not body.is_in_group("ball") or body.captured:
		return
	if body.linear_velocity.y > -MIN_ENTRY_SPEED:
		return
	_ball = body
	_dist = 0.0
	Sfx.play("ramp_enter")
	_ball.capture(_points[0], false)
	_ball.visual_scale = 1.2
	_ball.z_index = _ball.Z_RAMP


func _process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_flash = maxf(0.0, _flash - delta * 1.5)
	if _ball != null:
		_dist += SPEED * delta
		var total := _lengths[_lengths.size() - 1]
		if _dist >= total:
			var last := _points.size() - 1
			_ball.hold_at(_points[last])
			_ball.release(_tangent(last) * EXIT_SPEED)
			_ball = null
			_cooldown = 0.5
			_flash = 1.0
			Sfx.play("ramp")
			completed.emit(_points[last])
		else:
			_ball.hold_at(_sample(_dist))
	queue_redraw()


func _sample(dist: float) -> Vector2:
	var i := _lengths.bsearch(dist)
	if i <= 0:
		return _points[0]
	var seg := _lengths[i] - _lengths[i - 1]
	return _points[i - 1].lerp(_points[i], (dist - _lengths[i - 1]) / maxf(seg, 0.001))


func _draw() -> void:
	var lit := COLOR.lerp(Color.WHITE, _flash * 0.7)
	# Sombra proyectada sobre la mesa (lejos: la rampa está en alto).
	var shadow := PackedVector2Array()
	for p in _points:
		shadow.append(p + Vector2(16, 26))
	draw_polyline(shadow, Color(0, 0, 0, 0.22), WIDTH, true)
	# Cristal del tubo.
	draw_polyline(_points, Color(0.85, 0.95, 1.0, 0.13 + _flash * 0.25), WIDTH, true)
	# Traviesas de alambre.
	for i in range(0, _points.size(), 3):
		var on := _flash > 0.5
		draw_line(_left[i], _right[i], Color(lit, 0.9 if on else 0.22), 5.0 if on else 3.0)
	# Raíles.
	for rail in [_left, _right]:
		draw_polyline(rail, COLOR.darkened(0.55), 10.0, true)
		draw_polyline(rail, lit, 5.0, true)
		draw_polyline(rail, Color(0.9, 0.82, 0.58), 1.5, true)
	# Flechas pintadas en el tapete que señalan la boca.
	var dir := _tangent(0)
	var side := dir.orthogonal()
	var arrow_color := Color(0.9, 0.84, 0.7, 0.75).lerp(Color(1.0, 0.9, 0.5, 1.0), _flash)
	for j in 3:
		var tip := _points[0] - dir * (90.0 - j * 34.0)
		draw_colored_polygon(PackedVector2Array([tip + dir * 26.0, tip + side * 22.0, tip - side * 22.0]),
				arrow_color)
