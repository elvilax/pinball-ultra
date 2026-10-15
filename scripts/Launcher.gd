extends Node2D
## Lanzador. Se coloca en el suelo del carril; mantener "launch" carga la fuerza.

signal launched(power: float)

const MIN_SPEED := 1300.0
const MAX_SPEED := 2900.0
const CHARGE_TIME := 1.2
const COLOR := Color(0.72, 0.58, 0.3)

var enabled := true
var charge := 0.0


## Devuelve la bola que está quieta en el carril, lista para lanzar (o null).
func ball_ready() -> RigidBody2D:
	for ball in get_tree().get_nodes_in_group("ball"):
		var d: Vector2 = ball.global_position - global_position
		if not ball.captured and not ball.teleporting and absf(d.x) < 40.0 and d.y > -120.0 and d.y < 0.0 \
				and ball.linear_velocity.length() < 80.0:
			return ball
	return null


func _physics_process(delta: float) -> void:
	var ball := ball_ready()
	if enabled and Input.is_action_pressed("launch") and ball != null:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
	elif charge > 0.0:
		if ball != null:
			ball.linear_velocity = Vector2(0, -lerpf(MIN_SPEED, MAX_SPEED, charge))
			Sfx.play("launch", 0.0, lerpf(0.85, 1.3, charge))
			launched.emit(charge)
		charge = 0.0
	queue_redraw()


func _draw() -> void:
	# Émbolo: baja al cargar.
	var top := 4.0 + charge * 50.0
	draw_rect(Rect2(-30, top, 60, 14), COLOR)
	draw_rect(Rect2(-8, top + 14, 16, 90), Color(COLOR, 0.6))
	# Medidor de fuerza a la derecha del carril.
	var segments := 12
	for i in segments:
		var on := charge > float(i) / segments
		var c := Color(0.6, 0.16, 0.13) if i >= 9 else Color(0.9, 0.84, 0.7)
		draw_rect(Rect2(50, -30 - i * 30, 18, 22), c if on else Color(c, 0.22))
