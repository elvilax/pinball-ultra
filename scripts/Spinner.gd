extends Node2D
## Spinner en la entrada de la órbita izquierda: la bola lo atraviesa sin
## chocar, lo hace girar y suma puntos por cada pasada.

signal spun(points: int, at: Vector2)

const P := preload("res://scripts/Palette.gd")
const POINTS := 150
const LENGTH := 76.0
const COOLDOWN := 0.15

var _spin_angle := 0.0
var _spin_speed := 0.0
var _cooldown := 0.0


func _ready() -> void:
	var area := Area2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, LENGTH)
	var shape := CollisionShape2D.new()
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _cooldown > 0.0 or not body.is_in_group("ball"):
		return
	_cooldown = COOLDOWN
	_spin_speed = 26.0
	Sfx.play("spinner")
	spun.emit(POINTS, global_position)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_spin_angle += _spin_speed * delta
	_spin_speed = maxf(0.0, _spin_speed - delta * 34.0)
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(0, -LENGTH / 2.0 - 12.0), Vector2(0, LENGTH / 2.0 + 12.0), P.BRASS_DARK, 7.0)
	draw_circle(Vector2(0, -LENGTH / 2.0 - 12.0), 7.0, P.BRASS)
	draw_circle(Vector2(0, LENGTH / 2.0 + 12.0), 7.0, P.BRASS)
	# La paleta vista de canto: más ancha cuando está de perfil hacia la cámara.
	var w := absf(cos(_spin_angle)) * 11.0 + 1.5
	var lit := _spin_speed > 1.0
	var c := P.BULB_ON if lit else P.BRASS
	draw_rect(Rect2(-w / 2.0, -LENGTH / 2.0, w, LENGTH), c)
	if lit:
		draw_rect(Rect2(-w / 2.0 - 2.0, -LENGTH / 2.0, w + 4.0, LENGTH), Color(P.BULB_ON, 0.25))
