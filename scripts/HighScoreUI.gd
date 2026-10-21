extends CanvasLayer
## Tabla de récords (se muestra en el modo atracción) y pantalla de iniciales
## cuando la puntuación de la partida entra en la tabla. Mismo lenguaje visual
## que RouletteUI: panel de madera y latón, texto dibujado directamente.

signal entered(initials: String)

const P := preload("res://scripts/Palette.gd")
const HUD := preload("res://scripts/HUD.gd")

const PANEL := Rect2(60, 420, 960, 1080)
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

enum { HIDDEN, TABLE, ENTRY }

var _mode := HIDDEN
var _stage: Control
var _time := 0.0
var _scores: Array = []

## Entrada de iniciales: letra por rodillo, con los flippers; lanzar confirma y avanza.
var _entry_score := 0
var _letters := [0, 0, 0]
var _slot := 0


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


## Modo atracción: tabla de récords en bucle, sin más interacción que lanzar para jugar.
func show_table(scores: Array) -> void:
	_scores = scores
	_show(TABLE)


func hide_table() -> void:
	if _mode == TABLE:
		_mode = HIDDEN
		visible = false


## Pide las 3 iniciales con los flippers (letra) y lanzar (confirmar letra y
## pasar a la siguiente). Devuelve las iniciales cuando se confirma la 3ª.
func enter_initials(score: int) -> String:
	_entry_score = score
	_letters = [0, 0, 0]
	_slot = 0
	_show(ENTRY)
	var initials: String = await entered
	_mode = HIDDEN
	visible = false
	return initials


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
	if _mode != ENTRY or _time < 0.2:
		return
	# Pequeña espera para que una tecla que ya venía pulsada no elija sola.
	if Input.is_action_just_pressed("flipper_left"):
		_letters[_slot] = posmod(_letters[_slot] - 1, LETTERS.length())
	elif Input.is_action_just_pressed("flipper_right"):
		_letters[_slot] = posmod(_letters[_slot] + 1, LETTERS.length())
	elif Input.is_action_just_pressed("launch"):
		_slot += 1
		if _slot >= 3:
			var initials := ""
			for i in 3:
				initials += LETTERS[_letters[i]]
			entered.emit(initials)


func _draw_stage() -> void:
	var s := _stage
	var font := P.font()
	s.draw_rect(PANEL.grow(12.0), P.BRASS_DARK)
	s.draw_rect(PANEL, P.WOOD)
	s.draw_rect(PANEL.grow(-14.0), P.RED_DARK)
	s.draw_rect(PANEL.grow(-14.0), P.BRASS, false, 4.0)
	var cx := PANEL.get_center().x
	if _mode == TABLE:
		_text(font, Vector2(cx, PANEL.position.y + 90), Lang.t("RECORDS_TITLE"), 64, P.BRASS_LIGHT)
		for i in _scores.size():
			var e = _scores[i]
			var y := PANEL.position.y + 210 + i * 90
			var line := "%d.   %s   %s" % [i + 1, String(e["initials"]), HUD.format_number(int(e["score"]))]
			_text(font, Vector2(cx, y), line, 42, P.CREAM)
	elif _mode == ENTRY:
		_text(font, Vector2(cx, PANEL.position.y + 90), Lang.t("NEW_RECORD"), 54, P.BULB_ON)
		_text(font, Vector2(cx, PANEL.position.y + 170), HUD.format_number(_entry_score), 50, P.CREAM)
		for i in 3:
			var c := Vector2(cx - 180.0 + i * 180.0, PANEL.position.y + 380)
			s.draw_rect(Rect2(c - Vector2(60, 70), Vector2(120, 140)), P.BLACK)
			s.draw_rect(Rect2(c - Vector2(60, 70), Vector2(120, 140)), P.BRASS, false, 4.0)
			var show_letter: bool = i < _slot or (i == _slot and fmod(_time * 3.0, 1.0) < 0.65)
			if show_letter:
				var letter: String = LETTERS[_letters[i]] if i <= _slot else "."
				_text(font, c + Vector2(0, 20), letter, 80, P.BULB_ON if i == _slot else P.CREAM)
		_text(font, Vector2(cx, PANEL.position.y + 520), Lang.t("INITIALS_HINT"), 28, P.BRASS_LIGHT)


func _text(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var pos := center - Vector2(480, 0)
	_stage.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, 10, P.BLACK)
	_stage.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, color)
