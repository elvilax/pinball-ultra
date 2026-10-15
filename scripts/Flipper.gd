extends AnimatableBody2D
## Flipper. side = 1 para el izquierdo (apunta a la derecha), -1 para el derecho.

const LENGTH := 180.0
const THICK := 18.0
const HEIGHT := 12.0  # altura visual (falso 3D)
const REST_ANGLE := 0.45
const ACTIVE_ANGLE := -0.55
const SPEED := 16.0  # rad/s

var side := 1.0
var action := "flipper_left"
var color := Color(0.6, 0.16, 0.13)
## Se apaga durante el TILT: deja de responder y cae a su posición de reposo.
var enabled := true

var _angle := REST_ANGLE
var _was_active := false


func _ready() -> void:
	sync_to_physics = false

	var capsule := CapsuleShape2D.new()
	capsule.radius = THICK
	capsule.height = LENGTH + THICK
	var shape := CollisionShape2D.new()
	shape.shape = capsule
	shape.rotation = PI / 2.0
	shape.position = Vector2((LENGTH - THICK) / 2.0 * side, 0)
	add_child(shape)

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.1
	mat.friction = 0.5
	physics_material_override = mat

	rotation = _angle * side


func _physics_process(delta: float) -> void:
	var active := enabled and Input.is_action_pressed(action)
	if active and not _was_active:
		Sfx.play("flipper")
	_was_active = active
	var target := ACTIVE_ANGLE if active else REST_ANGLE
	if _angle != target:
		_angle = move_toward(_angle, target, SPEED * delta)
		rotation = _angle * side
		queue_redraw()


func _draw() -> void:
	# Los desplazamientos van en coordenadas de pantalla, no del flipper girado.
	var up := Vector2(0, -HEIGHT).rotated(-rotation)
	var shadow := Vector2(8, 14).rotated(-rotation)
	var a := Vector2.ZERO
	var b := Vector2((LENGTH - THICK) * side, 0)
	var dark := color.darkened(0.6)
	_draw_bar(a + shadow, b + shadow, THICK, Color(0, 0, 0, 0.35))
	_draw_bar(a, b, THICK, dark)
	_draw_bar(a + up * 0.5, b + up * 0.5, THICK, dark)
	_draw_bar(a + up, b + up, THICK + 4.0, Color(0.36, 0.27, 0.12))
	_draw_bar(a + up, b + up, THICK, color)
	_draw_bar(a + up, b + up, THICK * 0.4, Color(0.9, 0.84, 0.7))
	draw_circle(a + up, 6.0, Color(0.05, 0.05, 0.1))


func _draw_bar(a: Vector2, b: Vector2, r: float, c: Color) -> void:
	draw_line(a, b, c, r * 2.0)
	draw_circle(a, r, c)
	draw_circle(b, r, c)
