extends Node2D
## Monta la mesa y lleva las reglas: bolas, puntuación, bote y BIG WIN.
##
## La mesa vive en un SubViewport plano (1080x1920) y se muestra en pantalla
## deformada en perspectiva con un shader: de ahí el efecto 3D sin ser 3D.

const Table := preload("res://scripts/Table.gd")
const Ball := preload("res://scripts/Ball.gd")
const Flipper := preload("res://scripts/Flipper.gd")
const Bumper := preload("res://scripts/Bumper.gd")
const Tunnel := preload("res://scripts/Tunnel.gd")
const Roulette := preload("res://scripts/Roulette.gd")
const RouletteUI := preload("res://scripts/RouletteUI.gd")
const P := preload("res://scripts/Palette.gd")
const Slingshot := preload("res://scripts/Slingshot.gd")
const Lanes := preload("res://scripts/Lanes.gd")
const Ramp := preload("res://scripts/Ramp.gd")
const Launcher := preload("res://scripts/Launcher.gd")
const HUD := preload("res://scripts/HUD.gd")
const FloatingText := preload("res://scripts/FloatingText.gd")
const DropTargets := preload("res://scripts/DropTargets.gd")
const Spinner := preload("res://scripts/Spinner.gd")
const FixedTarget := preload("res://scripts/FixedTarget.gd")
const BigWinScene := preload("res://scenes/BigWin.tscn")
const SlotMachineScene := preload("res://scenes/SlotMachine.tscn")
const HighScores := preload("res://scripts/HighScores.gd")
const HighScoreUI := preload("res://scripts/HighScoreUI.gd")
const Controls := preload("res://scripts/Controls.gd")
const SettingsUI := preload("res://scripts/SettingsUI.gd")

const WORLD_SIZE := Vector2i(1080, 1920)
const BALLS_PER_GAME := 3
const POT_BASE := 5000
const POT_PER_BUMPER := 500
const POT_PER_RAMP := 2000
const RAMP_POINTS := 1000
const LANE_POINTS := 250
const LANES_BONUS := 2500
## Premios de la tragaperras del túnel (se multiplican por el xN del túnel).
const SLOT_PAIR_PRIZE := 2000
const SLOT_NOTHING_PRIZE := 250
## Premios de la ruleta (fácil de cambiar).
const ROULETTE_GREEN_MULTIPLIER := 10
const ROULETTE_MISS_PRIZE := 250
## Tiro maestro: entrar por la letra encendida durante el lanzamiento.
const SKILL_SHOT_POINTS := 5000
## Puntuación a la que se regala una bola extra (una sola vez por partida).
const EXTRA_BALL_SCORE := 50000
## Segundos de bola-save tras lanzar: si se drena en ese tiempo, no cuenta como bola perdida.
const BALL_SAVE_TIME := 10.0
## Empujón de mesa: cuánto sube el medidor por cada nudge y a qué velocidad baja solo.
const TILT_PER_NUDGE := 1.0
const TILT_DECAY := 0.4
const TILT_WARN := 3.0
const TILT_LIMIT := 5.0
const NUDGE_IMPULSE := 420.0
## Completar W-I-N estas veces suelta la multibola.
const WIN_FOR_MULTIBALL := 3
const MULTIBALL_EXTRA_BALLS := 2
const MULTIBALL_SCORE_MULT := 2

## Bonus al final de cada bola: puntos por cada vez que se consiguió algo (fácil de cambiar).
const BONUS_PER_RAMP := 500
const BONUS_PER_BUMPER := 100
const BONUS_PER_TARGET := 300
const BONUS_PER_SLOT_WIN := 800
const BONUS_PER_ROULETTE_WIN := 1200

## Cuánto se estrecha la mesa al fondo. 0 = plana.
const PERSPECTIVE := 0.22
## Rectángulo de pantalla que ocupa la mesa (debajo del marcador).
const TABLE_TOP := 330.0
## Acabado analógico sobre toda la pantalla: menos saturación, tono cálido, viñeta y grano.
const ANALOG_SHADER := "
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float gray = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(gray), 0.28);
	c *= vec3(1.05, 1.0, 0.88);
	vec2 d = UV - 0.5;
	c *= 1.0 - dot(d, d) * 1.1;
	vec2 cell = floor(UV * vec2(540.0, 960.0)) + floor(TIME * 10.0) * 7.0;
	float grain = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	c += (grain - 0.5) * 0.045;
	COLOR = vec4(c, 1.0);
}
"
const PERSPECTIVE_SHADER := "
shader_type canvas_item;
uniform float depth = 0.22;
void fragment() {
	// Proyección de un plano inclinado: el fondo (arriba) queda más lejos.
	float q = 1.0 - UV.y;
	float s = q / (1.0 + depth - depth * q);
	float z = 1.0 + depth * s;
	vec2 uv = vec2((UV.x - 0.5) * z + 0.5, 1.0 - s);
	if (uv.x < 0.0 || uv.x > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv);
		// Un poco más oscuro al fondo, para dar profundidad.
		COLOR.rgb *= mix(1.0, 0.78, s * s);
	}
}
"

var score := 0
var balls_left := 0
var pot := POT_BASE
var game_over := false
## Multiplicador que se muestra en la ruleta (1 = apagado). De momento nada lo enciende;
## queda listo por si se quiere premiar algo con él más adelante.
var multiplier := 1
var _extra_ball_awarded := false

var _viewport: SubViewport
var _world: Node2D
var _table: Node2D
var _balls: Array = []
var _launcher: Node2D
var _hud: CanvasLayer
var _big_win: CanvasLayer
var _slot_machine: CanvasLayer
var _roulette: Node2D
var _roulette_ui: CanvasLayer
var _roulette_choice := Roulette.RED
var _lanes: Node2D
var _drop_targets: Node2D
var _busy := false
var _camera: Camera2D
var _flippers: Array = []

## Fase 5: bola-save, nudge/tilt y multibola.
var _ball_save_timer := 0.0
var _tilt_meter := 0.0
var _tilt_warned := false
var _tilted := false
var _win_completions := 0
var _multiball := false

## Fase 6: bonus de bola, récords y modo atracción.
var _highscore_ui: CanvasLayer
var _settings_ui: SettingsUI
var _attract := true
var _ball_ramps := 0
var _ball_bumpers := 0
var _ball_targets := 0
var _ball_slot_wins := 0
var _ball_roulette_wins := 0


func _ready() -> void:
	_setup_input()
	# Muchos pasos de física por segundo: la bola es rápida y los flippers también.
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 16
	RenderingServer.set_default_clear_color(Color(0.09, 0.045, 0.025))

	_build_screen()
	_camera = Camera2D.new()
	_camera.position = Vector2(WORLD_SIZE) / 2.0
	_world.add_child(_camera)

	_table = Table.new()
	_world.add_child(_table)
	_table.drained.connect(_on_drained)

	# Túnel de la tragaperras: entrada, premio x3 y boca por la que reaparece la bola.
	# Sale apuntando a un flipper, no al hueco central.
	var top := _add_tunnel(Vector2(500, 150), 3, Vector2(750, 1010), Vector2(-100, 300))
	top.label_offset = Vector2(170, 12)

	# Ruleta real en el agujero central.
	_roulette = Roulette.new()
	_roulette.position = Table.CENTER_ART
	_roulette.camera = _camera
	_roulette.multiplier = multiplier
	_world.add_child(_roulette)
	_roulette.ball_captured.connect(_on_roulette_captured)

	_roulette_ui = RouletteUI.new()
	add_child(_roulette_ui)

	_lanes = Lanes.new()
	_world.add_child(_lanes)
	_lanes.lane_lit.connect(_on_lane_lit)
	_lanes.completed.connect(_on_lanes_completed)
	_lanes.skill_shot.connect(_on_skill_shot)

	_add_slingshot(Vector2(190, 1290), Vector2(190, 1440), Vector2(280, 1505))
	_add_slingshot(Vector2(810, 1290), Vector2(810, 1440), Vector2(720, 1505))

	_add_flipper(Table.LEFT_PIVOT, 1.0, "flipper_left")
	_add_flipper(Table.RIGHT_PIVOT, -1.0, "flipper_right")

	_add_bumper(Vector2(330, 640), P.RED)
	_add_bumper(Vector2(670, 640), Color(0.14, 0.12, 0.12))
	_add_bumper(Vector2(500, 790), Color(0.12, 0.2, 0.5))

	# Dianas abatibles en el hueco libre de la izquierda (entre la rampa y la pared).
	_drop_targets = DropTargets.new()
	_world.add_child(_drop_targets)
	_drop_targets.target_hit.connect(_on_drop_target_hit)
	_drop_targets.all_down.connect(_on_drop_targets_all_down)

	# Spinner a la entrada de esa misma órbita izquierda.
	_add_spinner(Vector2(225, 1010))

	# Dianas fijas y postes de goma rellenando huecos, sin cortar caminos.
	_add_fixed_target(Vector2(500, 460), 150)
	_add_post(Vector2(390, 480), P.BRASS)
	_add_post(Vector2(610, 480), P.BRASS)
	_add_post(Vector2(770, 700), Color(0.2, 0.45, 0.28))
	_add_post(Vector2(770, 900), Color(0.45, 0.28, 0.5))

	_launcher = Launcher.new()
	_launcher.position = Table.LAUNCHER_POS
	_world.add_child(_launcher)
	_launcher.launched.connect(_on_launched)

	# La bola inicial la crea _new_game(), al final de _ready().

	# Rampa: boca abajo a la derecha, cruza por encima y devuelve la bola al flipper izquierdo.
	var ramp := Ramp.new()
	ramp.control_points = PackedVector2Array([
		Vector2(830, 1170), Vector2(885, 1000), Vector2(905, 720), Vector2(860, 500),
		Vector2(700, 405), Vector2(500, 395), Vector2(300, 405), Vector2(150, 480),
		Vector2(100, 650), Vector2(95, 1000), Vector2(120, 1200), Vector2(150, 1300)])
	_world.add_child(ramp)
	ramp.completed.connect(_on_ramp_completed)

	_hud = HUD.new()
	add_child(_hud)

	_slot_machine = SlotMachineScene.instantiate()
	add_child(_slot_machine)

	_big_win = BigWinScene.instantiate()
	_big_win.shake_target = _camera
	add_child(_big_win)

	_highscore_ui = HighScoreUI.new()
	add_child(_highscore_ui)

	_settings_ui = SettingsUI.new()
	add_child(_settings_ui)

	_add_analog_finish()

	_enter_attract()


## Crea el SubViewport de la mesa y el rectángulo que lo proyecta en perspectiva.
func _build_screen() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.size_2d_override = WORLD_SIZE
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node2D.new()
	_viewport.add_child(_world)

	var shader := Shader.new()
	shader.code = PERSPECTIVE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("depth", PERSPECTIVE)

	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.material = mat
	# Alto = alto de la mesa / (1 + perspectiva): así la parte cercana no se deforma.
	view.position = Vector2(0, TABLE_TOP)
	view.size = Vector2(WORLD_SIZE.x, WORLD_SIZE.y / (1.0 + PERSPECTIVE))
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)

	get_window().size_changed.connect(_fit_viewport)
	_fit_viewport()


## Ajusta la resolución interna de la mesa a la de la ventana (evita dientes de sierra).
func _fit_viewport() -> void:
	var k := clampf(get_window().size.y / float(WORLD_SIZE.y) * 1.25, 0.4, 1.0)
	_viewport.size = Vector2i(Vector2(WORLD_SIZE) * k)


## Capa por encima de todo con el filtro de aspecto envejecido.
func _add_analog_finish() -> void:
	var shader := Shader.new()
	shader.code = ANALOG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var rect := ColorRect.new()
	rect.size = Vector2(1080, 1920)
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_layer := CanvasLayer.new()
	top_layer.layer = 50
	top_layer.add_child(rect)
	add_child(top_layer)


func _setup_input() -> void:
	var keys := Controls.load_keys()
	for action in keys.keys():
		_add_action(action, [keys[action]], Controls.JOYPAD_DEFAULTS.get(action, -1))


func _add_action(action: String, keys: Array, joy_button: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if joy_button >= 0:
		var jb_event := InputEventJoypadButton.new()
		jb_event.button_index = joy_button
		InputMap.action_add_event(action, jb_event)


func _add_flipper(pos: Vector2, side: float, action: String) -> void:
	var flipper := Flipper.new()
	flipper.position = pos
	flipper.side = side
	flipper.action = action
	_world.add_child(flipper)
	_flippers.append(flipper)


func _add_bumper(pos: Vector2, color: Color) -> void:
	var bumper := Bumper.new()
	bumper.position = pos
	bumper.color = color
	_world.add_child(bumper)
	bumper.scored.connect(_on_bumper_scored.bind(color))


## Poste de goma: un bumper más pequeño y flojo para rellenar huecos.
func _add_post(pos: Vector2, color: Color) -> void:
	var post := Bumper.new()
	post.position = pos
	post.radius = 32.0
	post.points = 50
	post.color = color
	_world.add_child(post)
	post.scored.connect(_on_bumper_scored.bind(color))


func _add_fixed_target(pos: Vector2, points: int) -> void:
	var target := FixedTarget.new()
	target.position = pos
	target.points = points
	_world.add_child(target)
	target.scored.connect(_on_fixed_target_scored)


func _add_spinner(pos: Vector2) -> void:
	var spinner := Spinner.new()
	spinner.position = pos
	_world.add_child(spinner)
	spinner.spun.connect(_on_spinner_spun)


func _add_slingshot(a: Vector2, b: Vector2, c: Vector2) -> void:
	var sling := Slingshot.new()
	sling.a = a
	sling.b = b
	sling.c = c
	_world.add_child(sling)
	sling.scored.connect(func(points: int, _at: Vector2) -> void: _add_score(points))


func _add_tunnel(pos: Vector2, multiplier: int, exit_pos: Vector2, exit_velocity: Vector2) -> Area2D:
	var tunnel := Tunnel.new()
	tunnel.position = pos
	tunnel.multiplier = multiplier
	tunnel.exit_pos = exit_pos
	tunnel.exit_velocity = exit_velocity
	_world.add_child(tunnel)
	tunnel.ball_captured.connect(_on_tunnel_entered)
	return tunnel


func _new_game() -> void:
	score = 0
	balls_left = BALLS_PER_GAME
	pot = POT_BASE
	game_over = false
	_attract = false
	_extra_ball_awarded = false
	_win_completions = 0
	_multiball = false
	_tilted = false
	_tilt_meter = 0.0
	_tilt_warned = false
	_ball_save_timer = 0.0
	_reset_ball_bonus()
	for f in _flippers:
		f.enabled = true
	for ball in _balls.duplicate():
		_balls.erase(ball)
		ball.queue_free()
	_lanes.stop_skill_shot()
	_launcher.enabled = true
	_spawn_ball(Table.BALL_START)
	_hud.set_score(score)
	_hud.set_balls(balls_left)
	_hud.set_pot(pot)
	_hud.set_ball_save(0.0)
	_hud.show_message(Lang.t("HOLD_LAUNCH"))


## Modo atracción: sin bola en juego, luces y animaciones de la mesa solas,
## tabla de récords en bucle, esperando a que alguien pulse lanzar.
func _enter_attract() -> void:
	_attract = true
	game_over = false
	_launcher.enabled = false
	for ball in _balls.duplicate():
		_balls.erase(ball)
		ball.queue_free()
	_hud.set_score(0)
	_hud.set_balls(0)
	_hud.set_pot(POT_BASE)
	_hud.show_message(Lang.t("ATTRACT_PROMPT"))
	_highscore_ui.show_table(HighScores.load_scores())


func _unhandled_input(event: InputEvent) -> void:
	if _attract and event.is_action_pressed("launch"):
		_highscore_ui.hide_table()
		_new_game()
	elif event.is_action_pressed("nudge"):
		_nudge()


func _process(delta: float) -> void:
	_tilt_meter = maxf(0.0, _tilt_meter - delta * TILT_DECAY)
	if _tilt_meter < TILT_WARN:
		_tilt_warned = false
	if _ball_save_timer > 0.0:
		_ball_save_timer = maxf(0.0, _ball_save_timer - delta)
	_hud.set_ball_save(_ball_save_timer)


func _physics_process(_delta: float) -> void:
	# Red de seguridad por si alguna bola se escapa de la mesa.
	for ball in _balls.duplicate():
		var p: Vector2 = ball.global_position
		if not ball.teleporting and (p.y > 2100.0 or p.y < -200.0 or p.x < -200.0 or p.x > 1300.0):
			_remove_ball(ball, true)


## Empujón de mesa: mueve un poco las bolas en juego y sube el medidor de tilt.
func _nudge() -> void:
	if _tilted or game_over or _busy:
		return
	for ball in _balls:
		if not ball.captured and not ball.teleporting:
			var dir := Vector2(randf_range(-1.0, 1.0), -1.0).normalized()
			ball.apply_central_impulse(dir * NUDGE_IMPULSE * ball.mass)
	_shake_camera()
	_tilt_meter += TILT_PER_NUDGE
	if _tilt_meter >= TILT_LIMIT:
		_trigger_tilt()
	elif _tilt_meter >= TILT_WARN and not _tilt_warned:
		_tilt_warned = true
		_hud.announce(Lang.t("WARNING"), P.RED_DARK)


func _shake_camera() -> void:
	if _camera == null:
		return
	var shake := create_tween()
	for i in 4:
		shake.tween_property(_camera, "offset", Vector2(randf_range(-9, 9), randf_range(-6, 6)), 0.03)
	shake.tween_property(_camera, "offset", Vector2.ZERO, 0.05)


## Demasiados empujones: se pierde la bola en juego sin red de bola-save.
func _trigger_tilt() -> void:
	if _tilted:
		return
	_tilted = true
	_tilt_warned = true
	_ball_save_timer = 0.0
	Sfx.play("tilt")
	for f in _flippers:
		f.enabled = false
	_table.flash(1.0)
	_hud.announce(Lang.t("TILT"), P.RED_DARK)
	for ball in _balls.duplicate():
		_remove_ball(ball, false)


## Suma puntos (al doble durante la multibola) y devuelve lo realmente
## aplicado, para que el texto flotante muestre la cifra correcta.
func _add_score(points: int) -> int:
	var applied := points * MULTIBALL_SCORE_MULT if _multiball else points
	score += applied
	_hud.set_score(score)
	if not _extra_ball_awarded and score >= EXTRA_BALL_SCORE:
		_award_extra_ball()
	return applied


func _add_pot(amount: int) -> void:
	pot += amount
	_hud.set_pot(pot)


func _award_extra_ball() -> void:
	Sfx.play("extra_ball")
	_extra_ball_awarded = true
	balls_left += 1
	_hud.set_balls(balls_left)
	_table.flash(1.5)
	_hud.announce(Lang.t("EXTRA_BALL"), P.BRASS_DARK)


func _on_launched(_power: float) -> void:
	_hud.hide_message()
	_table.flash(0.6)
	_lanes.start_skill_shot()
	_ball_save_timer = BALL_SAVE_TIME
	_reset_ball_bonus()


## Contadores del bonus de fin de bola: rampas, bumpers, dianas, tragaperras y
## ruletas ganadas DURANTE la bola en curso. Se reinician al lanzar cada bola.
func _reset_ball_bonus() -> void:
	_ball_ramps = 0
	_ball_bumpers = 0
	_ball_targets = 0
	_ball_slot_wins = 0
	_ball_roulette_wins = 0


func _on_bumper_scored(points: int, at: Vector2, color: Color) -> void:
	var applied := _add_score(points)
	_add_pot(POT_PER_BUMPER)
	_table.flash(0.5)
	_ball_bumpers += 1
	FloatingText.spawn(_world, at + Vector2(0, -70), "+%d" % applied, color.darkened(0.4))


func _on_lane_lit(_index: int, at: Vector2) -> void:
	var applied := _add_score(LANE_POINTS)
	FloatingText.spawn(_world, at, "+%d" % applied, P.RED_DARK)


func _on_lanes_completed() -> void:
	_add_score(LANES_BONUS)
	_add_pot(pot)
	_table.flash(1.5)
	_hud.announce(Lang.t("POT_X2"), P.BRASS_DARK)
	_win_completions += 1
	if not _multiball and _win_completions % WIN_FOR_MULTIBALL == 0:
		_start_multiball()


## Tiro maestro: la bola entró por la letra que estaba encendida al lanzar.
func _on_skill_shot(at: Vector2) -> void:
	_busy = true
	_table.flash(1.2)
	FloatingText.spawn(_world, at + Vector2(0, -70), "+%d" % SKILL_SHOT_POINTS, P.BRASS_DARK)
	_hud.announce(Lang.t("SKILL_SHOT"), P.BRASS_DARK)
	_big_win.play(SKILL_SHOT_POINTS * (MULTIBALL_SCORE_MULT if _multiball else 1), 0, true)
	await _big_win.finished
	_add_score(SKILL_SHOT_POINTS)
	_busy = false


func _on_drop_target_hit(points: int, at: Vector2) -> void:
	var applied := _add_score(points)
	_table.flash(0.4)
	_ball_targets += 1
	FloatingText.spawn(_world, at + Vector2(0, -50), "+%d" % applied, P.RED_DARK)


func _on_drop_targets_all_down() -> void:
	_add_pot(pot)
	_table.flash(1.5)
	_hud.announce(Lang.t("TARGETS_POT_X2"), P.BRASS_DARK)


func _on_fixed_target_scored(points: int, at: Vector2) -> void:
	var applied := _add_score(points)
	_table.flash(0.3)
	FloatingText.spawn(_world, at + Vector2(0, -50), "+%d" % applied, P.BRASS_DARK)


func _on_spinner_spun(points: int, at: Vector2) -> void:
	var applied := _add_score(points)
	FloatingText.spawn(_world, at + Vector2(50, 0), "+%d" % applied, P.BRASS_DARK)


func _on_ramp_completed(at: Vector2) -> void:
	var applied := _add_score(RAMP_POINTS)
	_add_pot(POT_PER_RAMP)
	_table.flash(1.2)
	_hud.announce(Lang.t("RAMP_HIT"), P.BRASS_DARK)
	_ball_ramps += 1
	FloatingText.spawn(_world, at + Vector2(60, -60), "+%d" % applied, P.BRASS_DARK)


## La bola entra en un túnel: tirada automática de tragaperras y premio según la suerte.
func _on_tunnel_entered(tunnel: Area2D, _captured_ball: RigidBody2D) -> void:
	_busy = true
	_table.flash(1.5)
	_table.set_excited(true)
	_slot_machine.spin()
	var result: Array = await _slot_machine.finished
	_table.set_excited(false)
	var matches: int = result[0]
	tunnel.celebrate(matches)
	if matches >= 2:
		_ball_slot_wins += 1
	if matches == 3:
		# Tres iguales: se lleva el bote entero con la animación gorda.
		var amount: int = pot * tunnel.multiplier
		pot = POT_BASE
		_hud.set_pot(pot)
		_table.flash(2.0)
		_big_win.play(amount * (MULTIBALL_SCORE_MULT if _multiball else 1))
		await _big_win.finished
		_add_score(amount)
	elif matches == 2:
		var prize: int = SLOT_PAIR_PRIZE * tunnel.multiplier
		var applied := _add_score(prize)
		_hud.announce("+%s" % HUD.format_number(applied), P.RED_DARK)
	else:
		_add_score(SLOT_NOTHING_PRIZE * tunnel.multiplier)
	tunnel.eject()
	_busy = false


## La bola cae en el agujero de la ruleta: se para la mesa, el jugador elige
## color con cuenta atrás y la ruleta gira de verdad hasta un número real.
func _on_roulette_captured(_ball: RigidBody2D) -> void:
	_busy = true
	_table.flash(0.6)
	get_tree().paused = true
	_roulette.zoom_in()
	_roulette_ui.choose(_roulette_choice)
	var choice: int = await _roulette_ui.chosen
	_roulette_choice = choice
	_roulette_ui.show_bet(choice)

	_table.set_excited(true)
	_roulette.spin(choice)
	var result: Array = await _roulette.spin_finished
	_table.set_excited(false)
	var number: int = result[0]
	var color: int = result[1]
	_roulette.zoom_out()

	var won := color == choice
	if won:
		_ball_roulette_wins += 1
	var prize: int
	if won:
		prize = pot * (ROULETTE_GREEN_MULTIPLIER if color == Roulette.GREEN else 1)
	else:
		prize = ROULETTE_MISS_PRIZE

	_roulette_ui.show_result(number, color, won, prize)
	await _roulette_ui.result_done
	_roulette_ui.close()

	if won:
		pot = POT_BASE
		_hud.set_pot(pot)
		_table.flash(2.0)
		_big_win.play(prize * (MULTIBALL_SCORE_MULT if _multiball else 1), 2 if color == Roulette.GREEN else 0)
		await _big_win.finished
	else:
		var applied := prize * (MULTIBALL_SCORE_MULT if _multiball else 1)
		FloatingText.spawn(_world, _roulette.global_position + Vector2(0, -160), "+%d" % applied, P.RED_DARK)
	_add_score(prize)

	get_tree().paused = false
	_roulette.eject()
	_busy = false


func _on_drained(body: Node) -> void:
	if _busy or not _balls.has(body):
		return
	var ball := body as RigidBody2D
	if not ball.teleporting:
		_remove_ball(ball, true)


## Quita una bola de juego. `allow_save` decide si el bola-save puede salvar
## el turno (nunca aplica al TILT). Con multibola, perder una bola de más no
## cuesta turno: solo cuando se queda la mesa sin ninguna.
func _remove_ball(ball: RigidBody2D, allow_save: bool) -> void:
	if not _balls.has(ball):
		return
	_balls.erase(ball)
	ball.queue_free()
	if _balls.size() > 0:
		if _multiball and _balls.size() == 1:
			_end_multiball()
		return
	if allow_save and _ball_save_timer > 0.0:
		_spawn_ball(Table.BALL_START)
		return
	_end_turn()


func _end_turn() -> void:
	if game_over:
		return
	_lanes.stop_skill_shot()
	_ball_save_timer = 0.0
	_tilt_meter = 0.0
	_tilt_warned = false
	balls_left -= 1
	_hud.set_balls(balls_left)
	await _play_bonus()
	if balls_left <= 0:
		game_over = true
		Sfx.play("game_over")
		_launcher.enabled = false
		_hud.announce(Lang.t("GAME_OVER"), P.RED_DARK)
		if HighScores.qualifies(score):
			var initials: String = await _highscore_ui.enter_initials(score)
			HighScores.insert(initials, score)
		_enter_attract()
	else:
		Sfx.play("drain")
		_tilted = false
		for f in _flippers:
			f.enabled = true
		_spawn_ball(Table.BALL_START)
		_hud.announce(Lang.t("BALL_LOST"), P.RED_DARK)
		_hud.show_message(Lang.t("HOLD_LAUNCH"))


## Recuento de bonus de la bola que se acaba de perder: rampas, bumpers,
## dianas, tragaperras y ruletas ganadas, cada una sumando a la puntuación con
## la misma animación de contador del marcador (set_score hace rodar los dígitos).
func _play_bonus() -> void:
	var items := []
	if _ball_ramps > 0:
		items.append([Lang.t("BONUS_RAMPS"), _ball_ramps, BONUS_PER_RAMP])
	if _ball_bumpers > 0:
		items.append([Lang.t("BONUS_BUMPERS"), _ball_bumpers, BONUS_PER_BUMPER])
	if _ball_targets > 0:
		items.append([Lang.t("BONUS_TARGETS"), _ball_targets, BONUS_PER_TARGET])
	if _ball_slot_wins > 0:
		items.append([Lang.t("BONUS_SLOT"), _ball_slot_wins, BONUS_PER_SLOT_WIN])
	if _ball_roulette_wins > 0:
		items.append([Lang.t("BONUS_ROULETTE"), _ball_roulette_wins, BONUS_PER_ROULETTE_WIN])
	if items.is_empty():
		return
	_hud.announce(Lang.t("BONUS"), P.BRASS_DARK)
	await get_tree().create_timer(0.7).timeout
	for item in items:
		var label: String = item[0]
		var count: int = item[1]
		var per: int = item[2]
		var subtotal: int = _add_score(count * per)
		_hud.announce("%s x%d = %s" % [label, count, HUD.format_number(subtotal)], P.BRASS_DARK)
		await get_tree().create_timer(0.6).timeout


func _spawn_ball(pos: Vector2, velocity := Vector2.ZERO) -> RigidBody2D:
	# Puede llamarse desde dentro del callback de colisión del drenaje (bola-save,
	# TILT, fin de turno): igual que en DropTarget, crear el cuerpo físico ahí
	# mismo revienta ("flushing queries"), así que el add_child se difiere.
	var ball := Ball.new()
	ball.teleport(pos, velocity)
	_balls.append(ball)
	_world.call_deferred("add_child", ball)
	return ball


## Completar W-I-N las veces que toque suelta 2 bolas más; mientras dure, los premios valen el doble.
func _start_multiball() -> void:
	_multiball = true
	Sfx.play("multiball")
	_table.flash(2.0)
	_hud.announce(Lang.t("MULTIBALL_START"), P.BRASS_DARK)
	for i in MULTIBALL_EXTRA_BALLS:
		var pos := Table.CENTER_ART + Vector2(randf_range(-80.0, 80.0), -260.0)
		_spawn_ball(pos, Vector2(randf_range(-60.0, 60.0), 520.0))


func _end_multiball() -> void:
	if not _multiball:
		return
	_multiball = false
	_hud.announce(Lang.t("MULTIBALL_END"), P.BRASS_DARK)
