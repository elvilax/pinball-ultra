extends CanvasLayer
## Aviso "logro desbloqueado": panel compacto que entra desde arriba, se
## mantiene unos segundos y se va otra vez. Si llegan varios logros a la vez
## (p.ej. al cargar progreso antiguo), se encolan y se muestran uno a uno.
## Mismo lenguaje visual que el resto (madera/latón, texto dibujado por código).

const P := preload("res://scripts/Palette.gd")

const PANEL := Rect2(140, -180, 800, 160)
const SHOWN_Y := 60.0
const HOLD_TIME := 2.2

var _stage: Control
var _queue: Array[String] = []
var _showing := false
var _title := ""


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = Control.new()
	_stage.size = PANEL.size
	_stage.position = Vector2(PANEL.position.x, PANEL.position.y)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.draw.connect(_draw_stage)
	Achievements.unlocked.connect(_on_unlocked)


func _on_unlocked(id: String) -> void:
	_queue.append(id)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var id: String = _queue.pop_front()
	_title = Lang.t(Achievements.DEFS[id]["title"])
	Sfx.play("achievement")
	_stage.position = Vector2(PANEL.position.x, PANEL.position.y)
	_stage.queue_redraw()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_stage, "position:y", SHOWN_Y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_stage, "position:y", PANEL.position.y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_show_next)


func _draw_stage() -> void:
	var s := _stage
	var font := P.font()
	var rect := Rect2(Vector2.ZERO, PANEL.size)
	s.draw_rect(rect.grow(6.0), P.BRASS_DARK)
	s.draw_rect(rect, P.WOOD)
	s.draw_rect(rect.grow(-8.0), P.RED_DARK)
	s.draw_rect(rect.grow(-8.0), P.BRASS, false, 3.0)
	_draw_medal(s, Vector2(78, 80))
	_text(font, Vector2(150, 44), Lang.t("ACH_TOAST"), 24, P.BULB_ON, 610)
	_text(font, Vector2(150, 90), _title, 32, P.CREAM, 610)


## Medallita sencilla con dos cintas: mismo espíritu "todo dibujado" que el resto.
func _draw_medal(s: Control, center: Vector2) -> void:
	s.draw_rect(Rect2(center + Vector2(-9, 26), Vector2(8, 28)), P.RED_DARK)
	s.draw_rect(Rect2(center + Vector2(2, 26), Vector2(8, 28)), P.RED_DARK)
	s.draw_circle(center, 36.0, P.BRASS_DARK)
	s.draw_circle(center, 30.0, P.BRASS)
	s.draw_circle(center, 19.0, P.BULB_ON)


func _text(font: Font, pos: Vector2, text: String, size: int, color: Color, width: float) -> void:
	_stage.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, 8, P.BLACK)
	_stage.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)
