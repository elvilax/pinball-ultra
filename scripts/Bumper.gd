extends StaticBody2D
## Bumper: rebota la bola con fuerza y suma puntos. Se dibuja como un cilindro.

const P := preload("res://scripts/Palette.gd")
signal scored(points: int, at: Vector2)

const KICK := 750.0
const HEIGHT := 24.0  # altura visual (falso 3D)

var radius := 60.0
var points := 100
var color := Color(1.0, 0.2, 0.8)

var pulse := 0.0:
	set(value):
		pulse = value
		queue_redraw()


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.8
	physics_material_override = mat


func _process(_delta: float) -> void:
	# Si la bola está "detrás" (más arriba), el bumper la tapa.
	var ball := get_tree().get_first_node_in_group("ball") as Node2D
	if ball != null and not ball.captured:
		z_index = 6 if ball.position.y < position.y else 0


func on_ball_hit(ball: RigidBody2D) -> void:
	var dir := (ball.global_position - global_position).normalized()
	ball.apply_central_impulse(dir * KICK * ball.mass)
	Sfx.play("bumper")
	scored.emit(points, global_position)
	pulse = 1.0
	create_tween().tween_property(self, "pulse", 0.0, 0.3)


func _draw() -> void:
	var r := radius
	var h := HEIGHT + pulse * 14.0
	var top := Vector2(0, -h)
	var lit := P.BRASS.lerp(P.BRASS_LIGHT, pulse)  # aro de latón
	var dark := color.darkened(0.65)
	# Sombra en el suelo.
	draw_circle(Vector2(10, 16), r, Color(0, 0, 0, 0.35))
	# Cuerpo del cilindro.
	draw_circle(Vector2.ZERO, r, dark)
	draw_rect(Rect2(-r, -h, r * 2.0, h), dark)
	draw_arc(Vector2.ZERO, r - 2.0, 0.0, PI, 24, Color(0.36, 0.27, 0.12), 5.0, true)
	# Tapa.
	draw_circle(top, r, color.darkened(0.35))
	draw_arc(top, r - 4.0, 0.0, TAU, 48, lit, 9.0, true)
	draw_circle(top, r * 0.62, color.darkened(0.1).lerp(P.BULB_ON, pulse * 0.7))
	draw_arc(top, r * 0.62, 0.0, TAU, 32, Color(0.9, 0.84, 0.7), 4.0, true)
	draw_circle(top + Vector2(-r * 0.25, -r * 0.25), r * 0.14, Color(1, 1, 1, 0.7))
	var font := P.font()
	draw_string(font, top + Vector2(-radius, 12), str(points), HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, 32, Color(0.9, 0.84, 0.7))
