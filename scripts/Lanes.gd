extends Node2D
## Carriles superiores W-I-N: pasar la bola por un carril enciende su letra.

const P := preload("res://scripts/Palette.gd")
signal lane_lit(index: int, at: Vector2)
signal completed
signal skill_shot(at: Vector2)

const POSTS_X := [320.0, 440.0, 560.0, 680.0]
const Y_TOP := 240.0
const Y_BOTTOM := 330.0
const LETTERS := ["W", "I", "N"]
const HEIGHT := 16.0
const COLOR := Color(0.72, 0.58, 0.3)  # latón

## Skill shot: al lanzar, una luz recorre las 3 letras; si la bola entra por
## la que está encendida en ese momento, premio grande (y se acaba la racha).
const SWEEP_INTERVAL := 0.28
const SWEEP_TIMEOUT := 3.0

var lit := [false, false, false]

var _time := 0.0
var _celebrate := 0.0
var _sweep_active := false
var _sweep_index := 0
var _sweep_timer := 0.0
var _sweep_elapsed := 0.0


func _ready() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for x in POSTS_X:
		var seg := SegmentShape2D.new()
		seg.a = Vector2(x, Y_TOP)
		seg.b = Vector2(x, Y_BOTTOM)
		var shape := CollisionShape2D.new()
		shape.shape = seg
		body.add_child(shape)

	for i in 3:
		var area := Area2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(50, 30)
		var shape := CollisionShape2D.new()
		shape.shape = rect
		area.position = _lane_center(i)
		area.add_child(shape)
		add_child(area)
		area.body_entered.connect(_on_lane_entered.bind(i))


func _lane_center(i: int) -> Vector2:
	return Vector2((POSTS_X[i] + POSTS_X[i + 1]) / 2.0, (Y_TOP + Y_BOTTOM) / 2.0)


func _on_lane_entered(body: Node, i: int) -> void:
	if not body.is_in_group("ball") or lit[i] or _celebrate > 0.0:
		return
	lit[i] = true
	Sfx.play("lane")
	lane_lit.emit(i, _lane_center(i))
	if _sweep_active:
		if i == _sweep_index:
			skill_shot.emit(_lane_center(i))
		_sweep_active = false
	if not lit.has(false):
		_celebrate = 1.5
		Sfx.play("double_pot")
		completed.emit()


## Arranca la luz viajera por W-I-N justo al lanzar la bola.
func start_skill_shot() -> void:
	_sweep_active = true
	_sweep_index = 0
	_sweep_timer = 0.0
	_sweep_elapsed = 0.0


func stop_skill_shot() -> void:
	_sweep_active = false


func _process(delta: float) -> void:
	_time += delta
	if _celebrate > 0.0:
		_celebrate -= delta
		if _celebrate <= 0.0:
			lit = [false, false, false]
	if _sweep_active:
		_sweep_elapsed += delta
		if _sweep_elapsed >= SWEEP_TIMEOUT:
			_sweep_active = false
		else:
			_sweep_timer += delta
			if _sweep_timer >= SWEEP_INTERVAL:
				_sweep_timer -= SWEEP_INTERVAL
				_sweep_index = (_sweep_index + 1) % 3
	queue_redraw()


func _draw() -> void:
	var font := P.font()
	var blink := _celebrate > 0.0 and fmod(_time * 10.0, 1.0) < 0.5
	for i in 3:
		var p := _lane_center(i)
		var on: bool = lit[i] and not blink
		var c := COLOR if on else Color(COLOR, 0.2)
		if on:
			draw_circle(p, 40.0, Color(1.0, 0.86, 0.55, 0.25))
		draw_circle(p, 26.0, Color(0.6, 0.16, 0.13) if on else Color(0.32, 0.08, 0.07))
		draw_arc(p, 26.0, 0.0, TAU, 32, c, 4.0, true)
		draw_string(font, p + Vector2(-30, 13), LETTERS[i], HORIZONTAL_ALIGNMENT_CENTER, 60.0, 36,
				P.CREAM if on else Color(COLOR, 0.45))
	if _sweep_active:
		var p := _lane_center(_sweep_index)
		var glow := 0.6 + 0.4 * sin(_time * 14.0)
		draw_circle(p, 44.0, Color(P.BULB_ON, 0.3 * glow))
		draw_arc(p, 34.0, 0.0, TAU, 28, P.BULB_ON, 4.0, true)
		# Flecha señalando la letra activa del tiro maestro.
		var tip := p + Vector2(0, -56)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(0, -18), tip + Vector2(16, 10), tip + Vector2(-16, 10)]), P.BULB_ON)
	# Postes con volumen.
	var up := Vector2(0, -HEIGHT)
	for x in POSTS_X:
		var a := Vector2(x, Y_TOP)
		var b := Vector2(x, Y_BOTTOM)
		draw_line(a + Vector2(8, 12), b + Vector2(8, 12), Color(0, 0, 0, 0.3), 10.0)
		draw_line(b, b + up, COLOR.darkened(0.6), 12.0)
		draw_line(a + up, b + up, COLOR.darkened(0.5), 15.0)
		draw_line(a + up, b + up, COLOR, 10.0)
		draw_line(a + up, b + up, P.BRASS_LIGHT, 3.0)
		draw_circle(a + up, 8.0, COLOR)
		draw_circle(b + up, 8.0, COLOR)
