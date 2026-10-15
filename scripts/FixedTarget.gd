extends StaticBody2D
## Diana fija: no se tumba, rebota flojo y suma puntos. Rellena huecos vacíos
## del tapete sin cortar los caminos a la rampa, la tragaperras o la ruleta.

signal scored(points: int, at: Vector2)

const P := preload("res://scripts/Palette.gd")
const RADIUS := 30.0

var points := 150
var color := Color(0.72, 0.58, 0.3)

var pulse := 0.0:
	set(value):
		pulse = value
		queue_redraw()


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.35
	mat.friction = 0.2
	physics_material_override = mat


func on_ball_hit(_ball: RigidBody2D) -> void:
	Sfx.play("target")
	scored.emit(points, global_position)
	pulse = 1.0
	create_tween().tween_property(self, "pulse", 0.0, 0.3)


func _draw() -> void:
	draw_circle(Vector2(5, 7), RADIUS, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, RADIUS, color.darkened(0.35).lerp(Color.WHITE, pulse * 0.5))
	draw_arc(Vector2.ZERO, RADIUS - 3.0, 0.0, TAU, 28, P.BRASS, 4.0, true)
	draw_circle(Vector2.ZERO, RADIUS * 0.4, P.CREAM.lerp(P.BULB_ON, pulse))
	draw_string(P.font(), Vector2(-RADIUS, 10), str(points), HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 20, P.BLACK)
