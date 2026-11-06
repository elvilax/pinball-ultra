extends CanvasLayer
## Selector de idioma de primer arranque: se muestra una sola vez, antes del
## modo atracción, si no existe aún user://lang.json (ver Lang.is_first_run).
## Mismo lenguaje visual y mismos controles (flippers + lanzar) que
## RouletteUI.choose() / HighScoreUI.enter_initials().

signal chosen

const P := preload("res://scripts/Palette.gd")

const PANEL := Rect2(60, 680, 960, 560)
const PROMPTS := ["Select your language", "Elige tu idioma", "Tria el teu idioma"]

var _stage: Control
var _time := 0.0
var _index := 0


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = Control.new()
	_stage.size = Vector2(1080, 1920)
	_stage.pivot_offset = PANEL.get_center()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.draw.connect(_draw_stage)
	_index = Lang.LANGS.find(Lang.lang)
	_stage.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_stage, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	_stage.queue_redraw()
	# Pequeña espera para que una tecla que ya venía pulsada no elija sola.
	if _time < 0.25:
		return
	if Input.is_action_just_pressed("flipper_left"):
		_index = posmod(_index - 1, Lang.LANGS.size())
	elif Input.is_action_just_pressed("flipper_right"):
		_index = posmod(_index + 1, Lang.LANGS.size())
	elif Input.is_action_just_pressed("launch"):
		Lang.set_lang(Lang.LANGS[_index])
		chosen.emit()


func _draw_stage() -> void:
	var s := _stage
	var font := P.font()
	s.draw_rect(PANEL.grow(12.0), P.BRASS_DARK)
	s.draw_rect(PANEL, P.WOOD)
	s.draw_rect(PANEL.grow(-14.0), P.RED_DARK)
	s.draw_rect(PANEL.grow(-14.0), P.BRASS, false, 4.0)
	var cx := PANEL.get_center().x
	for i in PROMPTS.size():
		_text(font, Vector2(cx, PANEL.position.y + 70 + i * 50), PROMPTS[i], 32, P.BRASS_LIGHT)
	for i in Lang.LANGS.size():
		var c := Vector2(cx, PANEL.position.y + 260 + i * 80)
		var selected := i == _index
		if selected:
			s.draw_rect(Rect2(c - Vector2(300, 32), Vector2(600, 64)), P.BLACK)
			s.draw_rect(Rect2(c - Vector2(300, 32), Vector2(600, 64)), P.BRASS, false, 3.0)
		_text(font, c + Vector2(0, 12), Lang.LANG_NAMES[Lang.LANGS[i]], 40, P.BULB_ON if selected else P.CREAM)
	_text(font, Vector2(cx, PANEL.position.y + 500), "Z / ←      M / →      SPACE", 26, P.BRASS_LIGHT)


func _text(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var pos := center - Vector2(480, 0)
	_stage.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, 8, P.BLACK)
	_stage.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, color)
