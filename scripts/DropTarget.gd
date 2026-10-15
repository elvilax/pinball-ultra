extends StaticBody2D
## Una diana abatible: se tumba al recibir un golpe y queda caída hasta que
## el banco (DropTargets.gd) la vuelve a levantar.

signal hit

const P := preload("res://scripts/Palette.gd")

const WIDTH := 86.0
const HEIGHT := 22.0
const POINTS := 300

var down := false

var _shape: CollisionShape2D
var _lean := 0.0  # 0 = de pie, 1 = tumbada
var _hit_flash := 0.0
var _time := 0.0


func _ready() -> void:
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, HEIGHT)
	_shape = CollisionShape2D.new()
	_shape.shape = rect
	add_child(_shape)

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.15
	mat.friction = 0.3
	physics_material_override = mat


func on_ball_hit(_ball: RigidBody2D) -> void:
	if down:
		return
	knock_down()
	hit.emit()


func knock_down() -> void:
	down = true
	Sfx.play("drop_target")
	# Esto se llama desde dentro del callback de colisión de la propia bola:
	# tocar la física ahí mismo revienta ("flushing queries"), hay que diferirlo.
	_shape.set_deferred("disabled", true)
	create_tween().tween_property(self, "_lean", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_flash = 1.0
	create_tween().tween_property(self, "_hit_flash", 0.0, 0.5)


func raise_up() -> void:
	down = false
	_shape.set_deferred("disabled", false)
	create_tween().tween_property(self, "_lean", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var w := WIDTH / 2.0
	var h := HEIGHT / 2.0
	var sink := 16.0 * _lean  # se hunde en el tapete al caer
	var color := Color(0.6, 0.16, 0.13).darkened(_lean * 0.5)
	_draw_insert()
	draw_rect(Rect2(-w, -h + sink, WIDTH, HEIGHT), Color(0, 0, 0, 0.25 * (1.0 - _lean)))
	draw_rect(Rect2(-w, -h + sink + 6.0, WIDTH, HEIGHT), color)
	draw_rect(Rect2(-w, -h + sink + 6.0, WIDTH, HEIGHT), P.BRASS, false, 3.0)
	draw_circle(Vector2(0, sink), 4.0, P.BRASS_LIGHT)


## Inserto redondo en el tapete, justo delante: encendido fijo mientras la
## diana está de pie, destello fuerte al golpearla, apagado mientras está caída.
func _draw_insert() -> void:
	var p := Vector2(0, HEIGHT * 0.5 + 22.0)
	var on := not down or _hit_flash > 0.0
	var glow := (0.5 if down else 0.85) + _hit_flash * 0.5
	if on:
		draw_circle(p, 18.0 + _hit_flash * 10.0, Color(P.BULB_ON, 0.16 + _hit_flash * 0.2))
		draw_circle(p, 9.0, P.BULB_ON.lerp(Color.WHITE, _hit_flash * 0.6) * Color(1, 1, 1, glow))
	else:
		draw_circle(p, 9.0, P.BULB_OFF)
	draw_arc(p, 9.0, 0.0, TAU, 14, P.BRASS_DARK, 1.5, true)
