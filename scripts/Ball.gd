extends RigidBody2D
## Bola de acero. Física real, con límite de velocidad para evitar túneles.

const RADIUS := 22.0
const MAX_SPEED := 3000.0
const Z_TABLE := 5
const Z_RAMP := 15

var captured := false
var teleporting := false
## >1 cuando va por una rampa elevada: se dibuja más grande y con la sombra lejos.
var visual_scale := 1.0

var _hold_pos := Vector2.ZERO
var _teleport_pos := Vector2.ZERO
var _teleport_velocity := Vector2.ZERO
var _ccd_wait := 0
var _teleport_wait := 0
var _capture_tween: Tween = null


func _ready() -> void:
	add_to_group("ball")
	z_index = Z_TABLE

	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.3
	mat.friction = 0.2
	physics_material_override = mat

	# Detección continua de colisiones (por rayo: el modo por forma da saltos
	# raros junto a paredes finas): la bola no atraviesa nada por rápida que vaya.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	queue_redraw()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if teleporting and _teleport_wait > 0:
		# Un paso de espera con el CCD ya apagado antes de mover la bola.
		_teleport_wait -= 1
		state.linear_velocity = Vector2.ZERO
	elif teleporting:
		state.transform = Transform2D(0.0, _teleport_pos)
		state.linear_velocity = _teleport_velocity
		state.angular_velocity = 0.0
		teleporting = false
		_ccd_wait = 3
	elif captured:
		state.transform = Transform2D(0.0, _hold_pos)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
	else:
		if state.linear_velocity.length() > MAX_SPEED:
			state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)
		if _ccd_wait > 0:
			_ccd_wait -= 1
			if _ccd_wait == 0:
				_set_ccd(true)


## Mueve la bola a una posición (y le da una velocidad) de forma segura para la física.
func teleport(pos: Vector2, velocity := Vector2.ZERO) -> void:
	_reset_state()
	_teleport_pos = pos
	_teleport_velocity = velocity
	teleporting = true
	_teleport_wait = 1
	_set_ccd(false)


## La bola queda retenida en un punto (túnel, ruleta o rampa). hold_at() la va
## moviendo. Con dim=true (túnel/ruleta) se desliza y se encoge hasta
## desaparecer, como si cayera por el agujero; con dim=false (rampa) se
## coloca al instante, porque quien la mueve fotograma a fotograma es la
## propia rampa con hold_at().
func capture(pos: Vector2, dim := true) -> void:
	if _capture_tween != null:
		_capture_tween.kill()
		_capture_tween = null
	# Si había un teletransporte pendiente sin resolver (p.ej. recién creada),
	# la captura lo cancela: si no, el aviso de "teleporting" se queda
	# colgado y, si la mesa se pausa justo después (la ruleta), la bola
	# puede quedarse congelada en el origen del mundo durante toda la espera.
	teleporting = false
	captured = true
	_set_ccd(false)
	if dim:
		var start := global_position
		_hold_pos = start
		_capture_tween = create_tween()
		# La ruleta pausa el árbol justo después de capturar: sin esto, la
		# animación se queda congelada a mitad de camino en vez de completarse.
		_capture_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_capture_tween.tween_method(_slide_hold.bind(), start, pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_capture_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
		_capture_tween.parallel().tween_property(self, "visual_scale", 0.1, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		_hold_pos = pos


## Igual que hold_at(), pero además mueve la posición real del nodo al momento:
## _integrate_forces() (quien aplica _hold_pos normalmente) es física, y la
## física no corre con el árbol en pausa, así que sin esto la bola no se
## movería visualmente mientras desliza hacia el agujero de la ruleta.
func _slide_hold(pos: Vector2) -> void:
	_hold_pos = pos
	global_position = pos


func hold_at(pos: Vector2) -> void:
	_hold_pos = pos


func release(velocity: Vector2) -> void:
	_reset_state()
	linear_velocity = velocity
	_ccd_wait = 3


## El CCD se apaga mientras la bola se recoloca "a mano" (teletransporte o
## retenida): con él activo, el motor interpreta el salto como un movimiento y
## la deja donde no toca. Se vuelve a encender unos pasos después.
func _set_ccd(on: bool) -> void:
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY if on else RigidBody2D.CCD_MODE_DISABLED


func _reset_state() -> void:
	# Si la bola se capturó con la mesa a punto de pausarse (la ruleta), el
	# tween que la apaga puede quedar a medias y, al despausar, revivir y
	# volver a apagarla por encima de este reset. Hay que matarlo aquí.
	if _capture_tween != null:
		_capture_tween.kill()
		_capture_tween = null
	captured = false
	z_index = Z_TABLE
	if modulate.a < 0.999 or visual_scale < 0.999:
		# Volvía encogida/invisible de un agujero (túnel o ruleta): que
		# aparezca creciendo en el sitio de salida, no de golpe.
		_capture_tween = create_tween().set_parallel(true)
		_capture_tween.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_capture_tween.tween_property(self, "visual_scale", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		modulate.a = 1.0
		visual_scale = 1.0


func _on_body_entered(body: Node) -> void:
	if body.has_method("on_ball_hit"):
		body.on_ball_hit(self)


func _draw() -> void:
	# Se deshace el giro de la bola para que sombra y brillo no den vueltas.
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	var lift := visual_scale - 1.0
	draw_circle(Vector2(7, 12) + Vector2(60, 100) * lift, RADIUS * 0.95, Color(0, 0, 0, 0.4))
	var r := RADIUS * visual_scale
	# Acero: borde oscuro, cuerpo gris, reflejo y brillo pequeño.
	draw_circle(Vector2.ZERO, r, Color(0.25, 0.25, 0.27))
	draw_circle(Vector2(-1, -2) * visual_scale, r * 0.9, Color(0.6, 0.6, 0.61))
	draw_circle(Vector2(-4, -5) * visual_scale, r * 0.62, Color(0.82, 0.82, 0.8))
	draw_circle(Vector2(-8, -9) * visual_scale, r * 0.2, Color(1, 1, 0.97))
