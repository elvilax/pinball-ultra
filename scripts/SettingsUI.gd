extends CanvasLayer
## Menú de ajustes: remapear controles. Se abre/cierra con ESC (lo llama
## Main). Mismo lenguaje visual que HighScoreUI/RouletteUI: panel de madera
## y latón, texto dibujado por código. Pausa el árbol mientras está abierto
## (process_mode ALWAYS para seguir recibiendo input igualmente).

const P := preload("res://scripts/Palette.gd")
const HUD := preload("res://scripts/HUD.gd")
const Controls := preload("res://scripts/Controls.gd")

const PANEL := Rect2(60, 420, 960, 1080)

const ACTIONS := ["flipper_left", "flipper_right", "launch", "nudge"]
const LABELS := {
	"flipper_left": "FLIPPER IZQUIERDO",
	"flipper_right": "FLIPPER DERECHO",
	"launch": "LANZAR",
	"nudge": "EMPUJAR MESA",
}
const ROW_MUSIC := 4
const ROW_SFX := 5
const ROW_RESET := 6
const ROW_QUIT := 7
const ROW_CLOSE := 8
const ROW_COUNT := 9
const VOLUME_STEP := 0.1

enum { HIDDEN, MENU, REMAP }

var _mode := HIDDEN
var _stage: Control
var _time := 0.0
var _selected := 0
var _remap_action := ""
var _keys: Dictionary = {}
var _prev_pressed: Dictionary = {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_keys = Controls.load_keys()
	_stage = Control.new()
	_stage.size = Vector2(1080, 1920)
	_stage.pivot_offset = PANEL.get_center()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.draw.connect(_draw_stage)
	visible = false


func is_open() -> bool:
	return _mode != HIDDEN


## Aplica las teclas guardadas (o las por defecto) al InputMap. Lo llama Main al arrancar.
func apply_saved_keys() -> void:
	for action in _keys.keys():
		_apply_action_keymap(action, _keys[action])


func toggle() -> void:
	if is_open():
		_back()
	else:
		_open()


func _open() -> void:
	_mode = MENU
	_selected = 0
	_time = 0.0
	visible = true
	get_tree().paused = true
	_stage.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_stage, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close() -> void:
	_mode = HIDDEN
	visible = false
	get_tree().paused = false


## Botón de atrás (ESC desde Main): cancela el remapeo en curso o cierra el menú.
func _back() -> void:
	if _mode == REMAP:
		_mode = MENU
	elif _mode == MENU:
		_close()


func _process(delta: float) -> void:
	if _mode == HIDDEN:
		return
	_time += delta
	_stage.queue_redraw()
	if _mode == MENU and _time >= 0.15:
		_process_menu()


func _just_pressed(key: Key) -> bool:
	var pressed := Input.is_physical_key_pressed(key)
	var was: bool = _prev_pressed.get(key, false)
	_prev_pressed[key] = pressed
	return pressed and not was


func _process_menu() -> void:
	if _just_pressed(KEY_UP):
		_selected = posmod(_selected - 1, ROW_COUNT)
	elif _just_pressed(KEY_DOWN):
		_selected = posmod(_selected + 1, ROW_COUNT)
	elif _just_pressed(KEY_LEFT):
		_adjust_volume(-VOLUME_STEP)
	elif _just_pressed(KEY_RIGHT):
		_adjust_volume(VOLUME_STEP)
	elif _just_pressed(KEY_ENTER) or _just_pressed(KEY_SPACE) or _just_pressed(KEY_KP_ENTER):
		_activate_selected()


## Las filas de volumen se ajustan con ←/→, no con ENTER (son deslizadores, no botones).
func _adjust_volume(delta: float) -> void:
	if _selected == ROW_MUSIC:
		Sfx.set_music_volume(Sfx.music_volume + delta)
	elif _selected == ROW_SFX:
		Sfx.set_sfx_volume(Sfx.sfx_volume + delta)
		Sfx.play("slot_tick")


func _activate_selected() -> void:
	if _selected < ACTIONS.size():
		_remap_action = ACTIONS[_selected]
		_mode = REMAP
		_time = 0.0
	elif _selected == ROW_RESET:
		_keys = Controls.DEFAULTS.duplicate()
		Controls.save_keys(_keys)
		apply_saved_keys()
		Sfx.set_music_volume(1.0)
		Sfx.set_sfx_volume(1.0)
	elif _selected == ROW_QUIT:
		get_tree().quit()
	elif _selected == ROW_CLOSE:
		_close()


## Siempre activo (process_mode ALWAYS), pausado o no: ESC abre/cierra el
## menú, y mientras se espera una tecla nueva, captura la primera que llegue.
func _input(event: InputEvent) -> void:
	if _mode == REMAP:
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.physical_keycode == KEY_ESCAPE:
				_mode = MENU
			else:
				_keys[_remap_action] = event.physical_keycode
				Controls.save_keys(_keys)
				_apply_action_keymap(_remap_action, event.physical_keycode)
				_mode = MENU
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		toggle()


func _apply_action_keymap(action: String, keycode: int) -> void:
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _draw_stage() -> void:
	var s := _stage
	var font := P.font()
	s.draw_rect(PANEL.grow(12.0), P.BRASS_DARK)
	s.draw_rect(PANEL, P.WOOD)
	s.draw_rect(PANEL.grow(-14.0), P.RED_DARK)
	s.draw_rect(PANEL.grow(-14.0), P.BRASS, false, 4.0)
	var cx := PANEL.get_center().x
	_text(font, Vector2(cx, PANEL.position.y + 90), "CONTROLES", 64, P.BRASS_LIGHT)

	if _mode == MENU:
		for i in ACTIONS.size():
			var action: String = ACTIONS[i]
			var y := _row_y(i)
			var color := P.BULB_ON if i == _selected else P.CREAM
			var line := "%s   [ %s ]" % [LABELS[action], OS.get_keycode_string(_keys[action])]
			_text(font, Vector2(cx, y), line, 34, color)
		_draw_volume_row(font, _row_y(ROW_MUSIC), "VOLUMEN MÚSICA", Sfx.music_volume, _selected == ROW_MUSIC)
		_draw_volume_row(font, _row_y(ROW_SFX), "VOLUMEN EFECTOS", Sfx.sfx_volume, _selected == ROW_SFX)
		_text(font, Vector2(cx, _row_y(ROW_RESET)), "RESTAURAR POR DEFECTO", 34, P.BULB_ON if _selected == ROW_RESET else P.CREAM)
		_text(font, Vector2(cx, _row_y(ROW_QUIT)), "SALIR DEL JUEGO", 34, P.BULB_ON if _selected == ROW_QUIT else P.CREAM)
		_text(font, Vector2(cx, _row_y(ROW_CLOSE)), "CERRAR", 34, P.BULB_ON if _selected == ROW_CLOSE else P.CREAM)
		_text(font, Vector2(cx, PANEL.position.y + PANEL.size.y - 60), "↑/↓ mover · ←/→ volumen · ENTER elegir · ESC cerrar", 24, P.BRASS_LIGHT)
	elif _mode == REMAP:
		_text(font, Vector2(cx, PANEL.position.y + 420), "PULSA UNA TECLA NUEVA PARA", 36, P.CREAM)
		_text(font, Vector2(cx, PANEL.position.y + 480), LABELS[_remap_action], 46, P.BULB_ON)
		var blink: bool = fmod(_time * 2.0, 1.0) < 0.6
		if blink:
			_text(font, Vector2(cx, PANEL.position.y + 580), "...", 46, P.BRASS_LIGHT)
		_text(font, Vector2(cx, PANEL.position.y + PANEL.size.y - 60), "ESC cancela", 26, P.BRASS_LIGHT)


func _row_y(row: int) -> float:
	return PANEL.position.y + 200.0 + row * 94.0


func _draw_volume_row(font: Font, y: float, label: String, value: float, selected: bool) -> void:
	var cx := PANEL.get_center().x
	var color := P.BULB_ON if selected else P.CREAM
	_text(font, Vector2(cx, y), "%s   %d%%" % [label, int(round(value * 100.0))], 34, color)
	var bar_size := Vector2(400.0, 14.0)
	var bar_pos := Vector2(cx - bar_size.x / 2.0, y + 26.0)
	_stage.draw_rect(Rect2(bar_pos, bar_size), P.BRASS_DARK)
	_stage.draw_rect(Rect2(bar_pos, Vector2(bar_size.x * value, bar_size.y)), color)
	_stage.draw_rect(Rect2(bar_pos, bar_size), P.BRASS, false, 2.0)


func _text(font: Font, center: Vector2, text: String, size: int, color: Color) -> void:
	var pos := center - Vector2(480, 0)
	_stage.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, 10, P.BLACK)
	_stage.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 960.0, size, color)
