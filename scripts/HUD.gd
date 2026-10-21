extends CanvasLayer
## Marcador superior con rodillos mecánicos de puntuación + rótulos en pantalla.

const P := preload("res://scripts/Palette.gd")

const PANEL := Rect2(20, 14, 1040, 300)
const DIGITS := 7
const DRUM_SIZE := Vector2(78, 116)
const DRUM_GAP := 8.0
const DRUM_Y := 74.0
const DRUM_SPEED := 14.0  # dígitos por segundo

var _panel: Control
var _drums: Array[Control] = []
var _drum_pos: Array[float] = []     # posición actual de cada rodillo (0..10)
var _drum_target: Array[int] = []
var _pot: Label
var _message: Label
var _ball_save: Label
var _announce: Label
var _balls := 0
var _announce_tween: Tween
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # el marcador sigue vivo con la mesa en pausa
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.draw.connect(_draw_panel)

	var logo := _make_label(Rect2(52, 30, 330, 60), 40, P.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	logo.text = "Pinball Ultra"
	_pot = _make_label(Rect2(52, 196, 640, 56), 40, P.BRASS_LIGHT, HORIZONTAL_ALIGNMENT_LEFT)
	_message = _make_label(Rect2(52, 254, 976, 46), 28, P.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_message.visible = false
	_ball_save = _make_label(Rect2(700, 196, 306, 56), 32, P.BULB_ON, HORIZONTAL_ALIGNMENT_RIGHT)
	_ball_save.visible = false

	# Rodillos de puntuación, alineados a la derecha.
	var x0 := PANEL.end.x - 34.0 - DIGITS * (DRUM_SIZE.x + DRUM_GAP)
	for i in DIGITS:
		var drum := Control.new()
		drum.position = Vector2(x0 + i * (DRUM_SIZE.x + DRUM_GAP), DRUM_Y)
		drum.size = DRUM_SIZE
		drum.clip_contents = true
		drum.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(drum)
		drum.draw.connect(_draw_drum.bind(i))
		_drums.append(drum)
		_drum_pos.append(0.0)
		_drum_target.append(0)

	_announce = _make_label(Rect2(0, 860, 1080, 220), 104, P.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_announce.add_theme_constant_override("outline_size", 26)
	_announce.scale = Vector2.ZERO


func _process(delta: float) -> void:
	_time += delta
	# Cada rodillo gira hacia delante hasta su dígito, como un contador mecánico.
	for i in DIGITS:
		var diff := fposmod(_drum_target[i] - _drum_pos[i], 10.0)
		if diff > 0.001:
			_drum_pos[i] = fposmod(_drum_pos[i] + minf(diff, DRUM_SPEED * delta), 10.0)
			_drums[i].queue_redraw()


func _make_label(rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.pivot_offset = rect.size / 2.0
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", P.font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", P.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label


func _draw_panel() -> void:
	# Marco de madera con filete de latón y fondo pintado.
	_panel.draw_rect(PANEL.grow(8.0), P.BRASS_DARK)
	_panel.draw_rect(PANEL, P.WOOD)
	for i in 9:
		var y := PANEL.position.y + 20.0 + i * 33.0
		_panel.draw_line(Vector2(PANEL.position.x, y), Vector2(PANEL.end.x, y + 6.0), Color(P.WOOD_DARK, 0.3), 3.0)
	var inner := PANEL.grow(-16.0)
	_panel.draw_rect(inner, P.RED_DARK)
	_panel.draw_rect(inner, P.BRASS, false, 4.0)
	_panel.draw_rect(inner.grow(-8.0), P.BRASS_DARK, false, 2.0)
	# Bisel de la ventana de los rodillos.
	var first := _drums[0].position
	var window := Rect2(first, Vector2(DIGITS * (DRUM_SIZE.x + DRUM_GAP) - DRUM_GAP, DRUM_SIZE.y)).grow(10.0)
	_panel.draw_rect(window, P.BLACK)
	_panel.draw_rect(window, P.BRASS, false, 5.0)
	# Bolas restantes (si hay bola extra puede haber más de 3 a la vez).
	for i in maxi(_balls, 3):
		var p := Vector2(996.0 - i * 54.0, 226.0)
		if i < _balls:
			_panel.draw_circle(p + Vector2(3, 4), 17.0, P.SHADOW)
			_panel.draw_circle(p, 17.0, Color(0.42, 0.43, 0.47))
			_panel.draw_circle(p + Vector2(-2, -2), 14.0, Color(0.88, 0.88, 0.86))
			_panel.draw_circle(p + Vector2(-5, -6), 4.0, Color.WHITE)
		else:
			_panel.draw_arc(p, 16.0, 0.0, TAU, 24, P.BRASS_DARK, 3.0, true)


## Un rodillo: tambor marfil con cifras negras que sube al cambiar.
func _draw_drum(i: int) -> void:
	var drum := _drums[i]
	var font := P.font()
	drum.draw_rect(Rect2(Vector2.ZERO, DRUM_SIZE), P.CREAM)
	var base := floorf(_drum_pos[i])
	var frac := _drum_pos[i] - base
	for k in 2:
		var digit := posmod(int(base) + k, 10)
		var y := DRUM_SIZE.y * (0.5 + k - frac) + 32.0
		drum.draw_string(font, Vector2(0, y), str(digit), HORIZONTAL_ALIGNMENT_CENTER, DRUM_SIZE.x, 88, P.BLACK)
	# Sombras arriba y abajo: curvatura del tambor.
	for j in 3:
		var h := 34.0 - j * 10.0
		drum.draw_rect(Rect2(0, 0, DRUM_SIZE.x, h), Color(0, 0, 0, 0.16))
		drum.draw_rect(Rect2(0, DRUM_SIZE.y - h, DRUM_SIZE.x, h), Color(0, 0, 0, 0.16))


func set_score(value: int) -> void:
	var text := str(clampi(value, 0, 9999999)).pad_zeros(DIGITS)
	for i in DIGITS:
		_drum_target[i] = int(text[i])


func set_balls(value: int) -> void:
	_balls = value
	_panel.queue_redraw()


func set_pot(value: int) -> void:
	_pot.text = Lang.t("POT", [format_number(value)])


## Indicador de bola a salvo: cuenta atrás visible, parpadea en el último tramo.
func set_ball_save(remaining: float) -> void:
	if remaining <= 0.0:
		_ball_save.visible = false
		return
	_ball_save.visible = not (remaining < 3.0 and fmod(_time * 6.0, 1.0) < 0.5)
	_ball_save.text = Lang.t("BALL_SAVE", [int(ceil(remaining))])


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true


func hide_message() -> void:
	_message.visible = false


## Rótulo grande que cae en mitad de la pantalla y se va solo.
func announce(text: String, color: Color) -> void:
	if _announce_tween != null:
		_announce_tween.kill()
	_announce.text = text
	_announce.add_theme_color_override("font_outline_color", color)
	_announce.modulate.a = 1.0
	_announce.scale = Vector2(1.6, 1.6)
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announce, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_interval(0.7)
	_announce_tween.tween_property(_announce, "modulate:a", 0.0, 0.3)


## 1234567 -> "1.234.567"
static func format_number(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if value < 0 else "") + s + out
