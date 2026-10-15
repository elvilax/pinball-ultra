extends StaticBody2D
## Slingshot: triángulo sobre el flipper. La cara a-c patea la bola hacia el centro.

signal scored(points: int, at: Vector2)

const KICK := 650.0
const HEIGHT := 16.0  # altura visual (falso 3D)

var a := Vector2.ZERO
var b := Vector2.ZERO
var c := Vector2.ZERO
var points := 10
var color := Color(0.6, 0.16, 0.13)

var pulse := 0.0:
	set(value):
		pulse = value
		queue_redraw()


func _ready() -> void:
	var poly := ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([a, b, c])
	var shape := CollisionShape2D.new()
	shape.shape = poly
	add_child(shape)

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.4
	physics_material_override = mat


func on_ball_hit(ball: RigidBody2D) -> void:
	var p := ball.global_position
	var closest := Geometry2D.get_closest_point_to_segment(p, a, c)
	if p.distance_to(closest) > 34.0:
		return
	var normal := (c - a).orthogonal().normalized()
	if normal.dot(b - a) > 0.0:
		normal = -normal
	ball.apply_central_impulse(normal * KICK * ball.mass)
	Sfx.play("slingshot")
	scored.emit(points, closest)
	pulse = 1.0
	create_tween().tween_property(self, "pulse", 0.0, 0.25)


func _draw() -> void:
	var up := Vector2(0, -HEIGHT)
	var base := PackedVector2Array([a, b, c])
	var top := PackedVector2Array([a + up, b + up, c + up])
	var shadow := PackedVector2Array([a + Vector2(9, 14), b + Vector2(9, 14), c + Vector2(9, 14)])
	var dark := color.darkened(0.7)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(base, dark)
	draw_colored_polygon(PackedVector2Array([b, c, c + up, b + up]), dark)
	draw_colored_polygon(top, color.darkened(0.5).lerp(Color.WHITE, pulse * 0.6))
	top.append(top[0])
	draw_polyline(top, Color(0.36, 0.27, 0.12), 11.0, true)
	draw_polyline(top, Color(0.72, 0.58, 0.3), 6.0, true)
	# Banda elástica de la cara que patea.
	var bulge := (c - a).orthogonal().normalized() * pulse * 14.0
	if bulge.dot(b - a) > 0.0:
		bulge = -bulge
	var mid := (a + c) / 2.0 + up + bulge
	draw_polyline(PackedVector2Array([a + up, mid, c + up]), Color(0.9, 0.84, 0.7), 6.0, true)
