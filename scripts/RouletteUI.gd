extends CanvasLayer
## Rótulos de la ruleta: selector de color con cuenta atrás, apuesta en curso y resultado.

signal chosen(choice: int)
signal result_done

const P := preload("res://scripts/Palette.gd")
const Roulette := preload("res://scripts/Roulette.gd")

const CHOOSE_TIME := 5.0
const RESULT_TIME := 1.9
const PANEL := Rect2(60, 350, 960, 400)
const ACTIONS := ["flipper_left", "flipper_right", "launch"]


func _names() -> Array:
	return [Lang.t("ROULETTE_RED"), Lang.t("ROULETTE_BLACK"), Lang.t("ROULETTE_GREEN")]


func _keys_hint() -> Array:
	return ["Z  /  ←", "M  /  →", Lang.t("KEY_SPACE_LABEL")]

enum { HIDDEN, CHOOSE, BET, RESULT }

var _mode := HIDDEN
var _stage: Control
var _choice := 0
var _time_left := 0.0
var _time := 0.0
var _number := 0
var _color := 0
var _won := false
var _prize := 0


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = Control.new()
	_stage.size = Vector2(1080, 1920)
	_stage.pivot_offset = PANEL.get_center()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.draw.connect(_draw_stage)
	visible = false


func _colors() -> Array:
	return [P.RED, P.BLACK, Roulette.POCKET_GREEN]


## Abre el selector. Emite `chosen` al pulsar o al acabar la cuenta atrás (con `default_choice`).
func choose(default_choice: int) -> void:
	_choice = default_choice
	_time_left = CHOOSE_TIME
	_show(CHOOSE)


func show_bet(choice: int) -> void:
	_choice = choice
	_show(BET)


func show_result(number: int, color: int, won: bool, prize: int) -> void:
	_number = number
	_color = color
	_won = won
	_prize = prize
	_time_left = RESULT_TIME
	_show(RESULT)


func close() -> void:
	_mode = HIDDEN
	visible = false


func _show(mode: int) -> void:
	_mode = mode
	_time = 0.0
	visible = true
	_stage.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_stage, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _mode == HIDDEN:
		return
	_time += delta
	_stage.queue_redraw()
	if _mode == CHOOSE:
		_time_left -= delta
		var picked := -1
		# Pequeña espera para que una tecla que ya venía pulsada no elija sola.
		if _time > 0.25:
			for i in 3:
				if Input.is_action_just_pressed(ACTIONS[i]):
					picked = i
		if picked >= 0 or _time_left <= 0.0:
			if picked >= 0:
				_choice = picked
			_mode = BET
			chosen.emit(_choice)
	elif _mode == RESULT:
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = INF
			result_done.emit()


func _draw_stage() -> void:
	var s := _stage
	var font := P.font()
	s.draw_rect(PANEL.grow(12.0), P.BRASS_DARK)
	s.draw_rect(PANEL, P.WOOD)
	s.draw_rect(PANEL.grow(-14.0), P.RED_DARK)
	s.draw_rect(PANEL.grow(-14.0), P.BRASS, false, 4.0)
	var cx := PANEL.get_center().x
	var names := _names()
	match _mode:
		CHOOSE:
			_text(font, Vector2(cx, 440), Lang.t("BET_PROMPT"), 58, P.BRASS_LIGHT)
			var keys := _keys_hint()
			for i in 3:
				var c := Vector2(240.0 + i * 300.0, 570.0)
				var selected := i == _choice
				if selected and fmod(_time * 3.0, 1.0) < 0.6:
					s.draw_circle(c, 92.0, P.BULB_ON)
				_chip(c, 78.0, _colors()[i])
				_text(font, c + Vector2(0, 12), names[i], 30, P.CREAM)
				_text(font, c + Vector2(0, 128), keys[i], 26, P.CREAM)
			# Cuenta atrás: número y barra.
			var k := clampf(_time_left / CHOOSE_TIME, 0.0, 1.0)
			_text(font, Vector2(PANEL.end.x - 90.0, 445), str(int(ceil(_time_left))), 64, P.BULB_ON)
			s.draw_rect(Rect2(PANEL.position.x + 40.0, 722, (PANEL.size.x - 80.0) * k, 8), P.BULB_ON)
		BET:
			_text(font, Vector2(cx, 450), Lang.t("BET_ON"), 50, P.CREAM)
			_chip(Vector2(cx, 590), 84.0, _colors()[_choice])
			_text(font, Vector2(cx, 603), names[_choice], 32, P.CREAM)
			_text(font, Vector2(cx, 722), Lang.t("NO_MORE_BETS"), 30, P.BRASS_LIGHT)
		RESULT:
			var c := Vector2(280, 550)
			_chip(c, 132.0, _colors()[_color])
			_text(font, c + Vector2(0, 52), str(_number), 150, P.CREAM)
			_text(font, Vector2(690, 470), names[_color], 76, P.CREAM)
			if _won:
				var blink := fmod(_time * 5.0, 1.0) < 0.6
				_text(font, Vector2(690, 580), Lang.t("YOU_WIN"), 80, P.BULB_ON if blink else P.BRASS)
			else:
				_text(font, Vector2(690, 575), Lang.t("YOU_LOSE"), 56, P.BRASS_LIGHT)
			_text(font, Vector2(690, 680), "+%s" % _format(_prize), 60, P.CREAM)


func _chip(c: Vector2, r: float, color: Color) -> void:
	_stage.draw_circle(c + Vector2(5, 7), r, P.SHADOW)
	_stage.draw_circle(c, r, P.BRASS_DARK)
	_stage.draw_circle(c, r - 6.0, P.CREAM)
	_stage.draw_circle(c, r - 14.0, color)
	_stage.draw_arc(c, r - 22.0, 0.0, TAU, 40, Color(P.CREAM, 0.6), 2.0, true)


func _text(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var pos := center - Vector2(480, 0)
	_stage.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, 10, P.BLACK)
	_stage.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, color)


func _format(value: int) -> String:
	var s := str(value)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
