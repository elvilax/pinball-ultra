extends Node2D
## Ruleta europea pintada en la mesa: 37 casillas en el orden real del cilindro.
## En el centro hay un agujero protegido por un anillo con entradas estrechas;
## si la bola cae dentro, Main lanza la apuesta y llama a spin().

signal ball_captured(ball: RigidBody2D)
signal spin_finished(number: int, color: int)

const P := preload("res://scripts/Palette.gd")

enum { RED, BLACK, GREEN }

const ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
		5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const REDS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const POCKETS := 37

# --- Azar (fácil de cambiar) ---
## Probabilidad de que salga el 0. El resto se reparte a medias entre rojo y negro.
const CHANCE_GREEN := 1.0 / 37.0
## Si fallas, probabilidad de que la bolita se pare un instante en tu color antes de caer al lado.
const NEAR_MISS_CHANCE := 0.6
const SPIN_TIME := 6.0

# --- Dificultad del agujero (fácil de cambiar) ---
const HOLE_RADIUS := 44.0
## La bola cae si su centro pasa a menos de esto del centro del agujero...
## (va casi hasta el anillo: una vez dentro, prácticamente siempre cae).
const CAPTURE_DIST := 70.0
## ...y no va más rápida que esto (si va muy fuerte, salta por encima).
const MAX_CAPTURE_SPEED := 2200.0
const RING_RADIUS := 94.0
const GAP_WIDTH := 76.0  # la bola mide 44
## Entradas del anillo, en grados (0 = derecha, 90 = abajo). Dos arriba en diagonal y una abajo.
const RING_GAPS := [90.0, 240.0, 300.0]
const EJECT_SPEED := 1000.0

const R_OUT := 250.0
const R_NUM := 196.0
const R_IN := 150.0
const R_TRACK := 236.0
const R_REST := 173.0
const WALL_HEIGHT := 14.0
const POCKET_GREEN := Color(0.12, 0.42, 0.2)

## Multiplicador encendido por el túnel de arriba (1 = apagado). Solo se muestra aquí.
var multiplier := 1
var camera: Camera2D = null
## Para pruebas: fuerza el número que sale. -1 = al azar.
var forced_number := -1
var spinning := false

var _angle := 0.0
var _speed := 0.12
var _rel := 0.0          # ángulo de la bolita respecto al cilindro
var _ball_r := R_REST
var _hop := 0.0
var _rattle := 0.0
var _held: RigidBody2D = null
var _cooldown := 0.0
var _time := 0.0
var _arcs: Array[PackedVector2Array] = []
var _camera_home := Vector2.ZERO
## Agujero de salida por el que acaba de escupir la bola (se ilumina un instante).
var _exit_angle := 0.0
var _exit_pulse := 0.0


static func color_of(number: int) -> int:
	if number == 0:
		return GREEN
	return RED if REDS.has(number) else BLACK


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Anillo protector: tres tramos de pared con huecos en RING_GAPS.
	var half := rad_to_deg(asin(GAP_WIDTH / 2.0 / RING_RADIUS))
	var body := StaticBody2D.new()
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.35
	body.physics_material_override = mat
	add_child(body)
	for i in RING_GAPS.size():
		var from: float = RING_GAPS[i] + half
		var to: float = RING_GAPS[(i + 1) % RING_GAPS.size()] - half
		if to < from:
			to += 360.0
		var pts := PackedVector2Array()
		var steps := maxi(2, int((to - from) / 12.0))
		for s in steps + 1:
			pts.append(Vector2.from_angle(deg_to_rad(lerpf(from, to, float(s) / steps))) * RING_RADIUS)
		_arcs.append(pts)
		for s in pts.size() - 1:
			var seg := SegmentShape2D.new()
			seg.a = pts[s]
			seg.b = pts[s + 1]
			var shape := CollisionShape2D.new()
			shape.shape = seg
			body.add_child(shape)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _held != null or _cooldown > 0.0 or get_tree().paused:
		return
	for ball in get_tree().get_nodes_in_group("ball"):
		if not ball.captured and not ball.teleporting \
				and ball.global_position.distance_to(global_position) < CAPTURE_DIST \
				and ball.linear_velocity.length() < MAX_CAPTURE_SPEED:
			_held = ball
			ball.capture(global_position)
			Sfx.play("roulette_drop")
			ball_captured.emit(ball)
			return


func _process(delta: float) -> void:
	_time += delta
	# El cilindro siempre gira un poco y pierde impulso despacio.
	_speed = lerpf(_speed, 0.12, delta * 0.45)
	_angle += _speed * delta
	_exit_pulse = maxf(0.0, _exit_pulse - delta * 2.0)
	queue_redraw()


## Empujón al cilindro (por ejemplo al golpear un bumper).
func nudge(strength: float) -> void:
	_speed = maxf(_speed, strength)


## Gira la ruleta y deja la bolita en un número. `choice` solo afecta a la
## animación (efecto de casi premio); el número se decide sin mirarlo.
func spin(choice: int) -> void:
	spinning = true
	var index := _pick_pocket()
	var number: int = ORDER[index]
	var color := color_of(number)
	var step := TAU / POCKETS
	# La bolita va en sentido contrario al cilindro (su ángulo relativo baja),
	# así que la última casilla por la que pasa es la siguiente en el orden.
	var before := ORDER[(index + 1) % POCKETS] as int
	var near := color != choice and color_of(before) == choice and randf() < NEAR_MISS_CHANCE

	_speed = 2.4
	_rel = fposmod(_rel, TAU)
	var target := index * step
	while target > _rel - TAU * 4.0:
		target -= TAU
	var first_stop := target + step if near else target

	var roll := create_tween().set_parallel(true)
	roll.tween_property(self, "_rel", first_stop, SPIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_ball_r = R_TRACK
	roll.tween_property(self, "_ball_r", R_REST, 1.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT) \
			.set_delay(SPIN_TIME * 0.45)
	_rattle = 0.0
	roll.tween_property(self, "_rattle", 9.0, 0.3).set_delay(SPIN_TIME * 0.45 + 1.0)
	roll.tween_property(self, "_rattle", 0.0, 1.5).set_delay(SPIN_TIME - 1.6)
	await roll.finished

	if near:
		# Casi premio: duda un momento en tu color y salta a la casilla de al lado.
		await get_tree().create_timer(0.5).timeout
		var hop := create_tween().set_parallel(true)
		hop.tween_property(self, "_rel", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		hop.tween_property(self, "_hop", 1.0, 0.45)
		await hop.finished
		_hop = 0.0
	_rel = target
	await get_tree().create_timer(0.35).timeout
	spinning = false
	if color != choice:
		Sfx.play("roulette_lose")
	spin_finished.emit(number, color)


func _pick_pocket() -> int:
	if forced_number >= 0:
		return ORDER.find(forced_number)
	if randf() < CHANCE_GREEN:
		return 0
	var color := RED if randf() < 0.5 else BLACK
	var options: Array[int] = []
	for i in range(1, POCKETS):
		if color_of(ORDER[i]) == color:
			options.append(i)
	return options.pick_random()


## Acerca la cámara a la ruleta mientras gira.
func zoom_in() -> void:
	if camera == null:
		return
	_camera_home = camera.position
	var t := create_tween().set_parallel(true)
	t.tween_property(camera, "position", global_position + Vector2(40, -30), 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(camera, "zoom", Vector2(1.45, 1.45), 0.6).set_trans(Tween.TRANS_SINE)


func zoom_out() -> void:
	if camera == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(camera, "position", _camera_home, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(camera, "zoom", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	await t.finished


## La bola no sale disparada desde el centro: reaparece en uno de los dos
## agujeros del anillo (igual que el túnel tiene su propia boca de salida)
## y desde ahí sale disparada hacia arriba.
func eject() -> void:
	if _held == null:
		return
	var gap: float = [RING_GAPS[1], RING_GAPS[2]].pick_random()
	var dir := Vector2.from_angle(deg_to_rad(gap))
	_exit_angle = gap
	_exit_pulse = 1.0
	_held.teleport(global_position + dir * RING_RADIUS, dir * EJECT_SPEED)
	_held = null
	_cooldown = 1.2


func _draw() -> void:
	_draw_wheel()
	_draw_center()
	_draw_ring()
	_draw_exit_holes()
	_draw_roulette_ball()


## Los dos agujeros del anillo por los que puede reaparecer la bola.
func _draw_exit_holes() -> void:
	for gap in [RING_GAPS[1], RING_GAPS[2]]:
		var p := Vector2.from_angle(deg_to_rad(gap)) * RING_RADIUS
		var lit := _exit_pulse if is_equal_approx(gap, _exit_angle) else 0.0
		draw_circle(p, 17.0, P.BRASS_DARK)
		draw_circle(p, 12.0, Color.BLACK.lerp(P.BULB_ON, lit))
		draw_arc(p, 14.0, 0.0, TAU, 16, P.BRASS, 3.0, true)
		if lit > 0.1:
			draw_circle(p, 26.0, Color(P.BULB_ON, lit * 0.25))


func _draw_wheel() -> void:
	var font := P.font()
	var step := TAU / POCKETS
	draw_circle(Vector2(8, 12), R_OUT + 16.0, P.SHADOW)
	draw_circle(Vector2.ZERO, R_OUT + 16.0, P.WOOD_DARK)
	for i in POCKETS:
		var a0 := _angle + (i - 0.5) * step
		var pts := PackedVector2Array()
		for s in 4:
			pts.append(Vector2.from_angle(a0 + step * s / 3.0) * R_OUT)
		for s in 4:
			pts.append(Vector2.from_angle(a0 + step * (3 - s) / 3.0) * R_IN)
		var number: int = ORDER[i]
		var c := [P.RED, P.BLACK, POCKET_GREEN][color_of(number)] as Color
		draw_colored_polygon(pts, c)
		draw_line(pts[0], pts[7], P.BRASS, 2.5)
		# Número: de pie mirando hacia fuera.
		var mid := _angle + i * step
		draw_set_transform(Vector2.from_angle(mid) * 224.0, mid + PI / 2.0)
		draw_string(font, Vector2(-24, 9), str(number), HORIZONTAL_ALIGNMENT_CENTER, 48.0, 25, P.CREAM)
		draw_set_transform(Vector2.ZERO)
	draw_arc(Vector2.ZERO, R_OUT, 0.0, TAU, 72, P.BRASS, 7.0, true)
	draw_arc(Vector2.ZERO, R_NUM, 0.0, TAU, 72, P.BRASS, 3.0, true)
	draw_arc(Vector2.ZERO, R_IN, 0.0, TAU, 72, P.BRASS, 6.0, true)
	draw_arc(Vector2.ZERO, R_OUT + 14.0, 0.0, TAU, 72, P.BRASS_DARK, 4.0, true)


## Disco central fijo: tapete, agujero y lámparas del multiplicador.
func _draw_center() -> void:
	var font := P.font()
	draw_circle(Vector2.ZERO, R_IN - 3.0, P.FELT_DARK)
	for a in [200.0, 340.0]:
		var p := Vector2.from_angle(deg_to_rad(a)) * 118.0
		var lit := multiplier > 1 and fmod(_time * 3.0, 1.0) < 0.6
		draw_circle(p, 25.0, P.BRASS_DARK)
		draw_circle(p, 21.0, P.BULB_ON if lit else P.RED_DARK)
		if lit:
			draw_circle(p, 34.0, Color(P.BULB_ON, 0.18))
		draw_string(font, p + Vector2(-25, 9), "x%d" % maxi(multiplier, 3), HORIZONTAL_ALIGNMENT_CENTER, 50.0, 24,
				P.BLACK if lit else Color(P.CREAM, 0.5))
	# Agujero: halo que respira despacio mientras está libre (inserto "activo").
	if not spinning and _held == null:
		var breathe := 0.5 + 0.5 * sin(_time * 2.0)
		draw_circle(Vector2.ZERO, HOLE_RADIUS + 26.0, Color(P.BULB_ON, 0.08 + breathe * 0.07))
	draw_circle(Vector2.ZERO, HOLE_RADIUS + 7.0, P.BRASS_DARK)
	draw_circle(Vector2.ZERO, HOLE_RADIUS, P.WOOD_DARK)
	draw_circle(Vector2(0, 7), HOLE_RADIUS - 6.0, Color.BLACK)
	draw_arc(Vector2.ZERO, HOLE_RADIUS, 0.0, TAU, 40, P.BRASS, 5.0, true)


func _draw_ring() -> void:
	var up := Vector2(0, -WALL_HEIGHT)
	for arc in _arcs:
		var top := PackedVector2Array()
		for i in arc.size():
			top.append(arc[i] + up)
			if i > 0:
				draw_colored_polygon(PackedVector2Array([arc[i - 1], arc[i], arc[i] + up, arc[i - 1] + up]), P.BRASS_DARK)
		draw_polyline(top, P.BRASS_DARK, 13.0, true)
		draw_polyline(top, P.BRASS, 8.0, true)
		draw_polyline(top, P.BRASS_LIGHT, 2.0, true)
		for end in [top[0], top[top.size() - 1]]:
			draw_circle(end, 10.0, P.BRASS_DARK)
			draw_circle(end, 7.0, P.RED)


## La bolita de marfil que corre por el cilindro.
func _draw_roulette_ball() -> void:
	var bounce := absf(sin(_rel * POCKETS * 0.5)) * _rattle + sin(_hop * PI) * 16.0
	var p := Vector2.from_angle(_angle + _rel) * (_ball_r + bounce)
	draw_circle(p + Vector2(4, 6), 11.0, Color(0, 0, 0, 0.4))
	draw_circle(p, 11.0, Color(0.6, 0.57, 0.5))
	draw_circle(p + Vector2(-1, -2), 9.5, P.CREAM)
	draw_circle(p + Vector2(-3, -4), 3.0, Color.WHITE)
