extends Area2D
## Túnel: la bola entra por la boca, el juego enciende el multiplicador de la
## ruleta y la bola reaparece disparada por la boca de salida.

signal ball_captured(tunnel: Area2D, ball: RigidBody2D)

const P := preload("res://scripts/Palette.gd")

var radius := 72.0
var multiplier := 1
## Boca de salida y velocidad con la que sale la bola (coordenadas de la mesa).
var exit_pos := Vector2.ZERO
var exit_velocity := Vector2(0, 400)
## Dónde se escribe el rótulo, respecto a la boca de entrada.
var label_offset := Vector2(0, 110)

var _held: RigidBody2D = null
var _cooldown := 0.0
var _time := 0.0
var _exit_pulse := 0.0
var _result_pulse := 0.0
var _result_color := Color.WHITE


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.5
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_exit_pulse = maxf(0.0, _exit_pulse - delta * 2.0)
	_result_pulse = maxf(0.0, _result_pulse - delta * 1.3)
	_time += delta
	queue_redraw()


## Inserto de la boca de entrada: destella según lo que dio la tragaperras
## (gordo = todas las luces a tope en dorado, nada = apenas se nota).
func celebrate(matches: int) -> void:
	_result_pulse = 1.0
	_result_color = P.BULB_ON if matches == 3 else (P.CREAM if matches == 2 else P.BRASS_DARK)


func _on_body_entered(body: Node) -> void:
	if _held != null or _cooldown > 0.0 or not body.has_method("capture") or body.captured:
		return
	_held = body
	body.capture(global_position)
	Sfx.play("tunnel")
	ball_captured.emit(self, body)


## Saca la bola por la boca de salida.
func eject() -> void:
	if _held == null:
		return
	_held.teleport(exit_pos, exit_velocity.rotated(randf_range(-0.2, 0.2)))
	_held = null
	_cooldown = 1.0
	_exit_pulse = 1.0


func _draw() -> void:
	var font := P.font()
	# Boca de entrada: agujero con pared interior y aro de latón.
	draw_circle(Vector2.ZERO, radius + 8.0, P.BRASS_DARK)
	draw_circle(Vector2.ZERO, radius, P.WOOD_DARK)
	draw_circle(Vector2(0, 9), radius - 7.0, Color.BLACK)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, P.BRASS, 7.0, true)
	draw_arc(Vector2.ZERO, radius + 2.0, PI * 1.1, PI * 1.9, 16, P.BRASS_LIGHT, 2.5, true)
	# Luces que giran alrededor; con el resultado de la tragaperras, se encienden todas.
	for i in 8:
		var on := posmod(i - int(_time * 2.0), 4) == 0 or _result_pulse > 0.3
		var color := _result_color if _result_pulse > 0.3 else P.BULB_ON
		draw_circle(Vector2.from_angle(TAU * i / 8.0) * (radius + 22.0 + _result_pulse * 10.0), 6.0, color if on else P.BULB_OFF)
	draw_string(font, label_offset + Vector2(-100, 0), "TÚNEL x%d" % multiplier,
			HORIZONTAL_ALIGNMENT_CENTER, 200.0, 32, P.CREAM)

	# Boca de salida: arco oscuro que se ilumina cuando escupe la bola.
	var e := to_local(exit_pos)
	var arch := PackedVector2Array()
	for i in 13:
		arch.append(e + Vector2.from_angle(PI + PI * i / 12.0) * 40.0)
	arch.append(e + Vector2(40, 26))
	arch.append(e + Vector2(-40, 26))
	draw_colored_polygon(arch, Color.BLACK.lerp(P.BULB_ON, _exit_pulse))
	arch.append(arch[0])
	draw_polyline(arch, P.BRASS_DARK, 10.0, true)
	draw_polyline(arch, P.BRASS, 5.0, true)
