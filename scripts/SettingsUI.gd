extends CanvasLayer
## Menú de ajustes: remapear controles. Se abre/cierra con ESC (lo llama
## Main). Mismo lenguaje visual que HighScoreUI/RouletteUI: panel de madera
## y latón, texto dibujado por código. Pausa el árbol mientras está abierto
## (process_mode ALWAYS para seguir recibiendo input igualmente).

const P := preload("res://scripts/Palette.gd")
const HUD := preload("res://scripts/HUD.gd")
const Controls := preload("res://scripts/Controls.gd")

const PANEL := Rect2(60, 300, 960, 1380)

const ACTIONS := ["flipper_left", "flipper_right", "launch", "nudge"]
const LABEL_KEYS := {
	"flipper_left": "LABEL_FLIPPER_LEFT",
	"flipper_right": "LABEL_FLIPPER_RIGHT",
	"launch": "LABEL_LAUNCH",
	"nudge": "LABEL_NUDGE",
}
const ROW_MUSIC := 4
const ROW_SFX := 5
const ROW_LANG := 6
const ROW_CREDITS := 7
const ROW_RESET := 8
const ROW_QUIT := 9
const ROW_CLOSE := 10
const ROW_COUNT := 11
const VOLUME_STEP := 0.1

## Botón de mando (índice 0) equivalente a cada tecla de navegación del menú.
const JOY_UP := JOY_BUTTON_DPAD_UP
const JOY_DOWN := JOY_BUTTON_DPAD_DOWN
const JOY_LEFT := JOY_BUTTON_DPAD_LEFT
const JOY_RIGHT := JOY_BUTTON_DPAD_RIGHT
const JOY_ACCEPT := JOY_BUTTON_A
const JOY_BACK := JOY_BUTTON_START

enum { HIDDEN, MENU, REMAP, CREDITS }

var _mode := HIDDEN
var _stage: Control
var _time := 0.0
var _selected := 0
var _remap_action := ""
var _keys: Dictionary = {}
var _prev_pressed: Dictionary = {}
var _prev_joy_pressed: Dictionary = {}


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


## Botón de atrás (ESC desde Main): cancela el remapeo/créditos en curso o cierra el menú.
func _back() -> void:
	if _mode == REMAP or _mode == CREDITS:
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


func _just_joy_pressed(button: JoyButton) -> bool:
	var pressed := Input.is_joy_button_pressed(0, button)
	var was: bool = _prev_joy_pressed.get(button, false)
	_prev_joy_pressed[button] = pressed
	return pressed and not was


func _process_menu() -> void:
	if _just_pressed(KEY_UP) or _just_joy_pressed(JOY_UP):
		_selected = posmod(_selected - 1, ROW_COUNT)
	elif _just_pressed(KEY_DOWN) or _just_joy_pressed(JOY_DOWN):
		_selected = posmod(_selected + 1, ROW_COUNT)
	elif _just_pressed(KEY_LEFT) or _just_joy_pressed(JOY_LEFT):
		_adjust_row(-1)
	elif _just_pressed(KEY_RIGHT) or _just_joy_pressed(JOY_RIGHT):
		_adjust_row(1)
	elif _just_pressed(KEY_ENTER) or _just_pressed(KEY_SPACE) or _just_pressed(KEY_KP_ENTER) or _just_joy_pressed(JOY_ACCEPT):
		_activate_selected()


## Las filas de volumen e idioma se ajustan con ←/→ (deslizador/ciclo), no con ENTER.
func _adjust_row(dir: int) -> void:
	if _selected == ROW_MUSIC:
		Sfx.set_music_volume(Sfx.music_volume + dir * VOLUME_STEP)
	elif _selected == ROW_SFX:
		Sfx.set_sfx_volume(Sfx.sfx_volume + dir * VOLUME_STEP)
		Sfx.play("slot_tick")
	elif _selected == ROW_LANG:
		Lang.cycle_lang(dir)
		Sfx.play("slot_tick")


func _activate_selected() -> void:
	if _selected < ACTIONS.size():
		_remap_action = ACTIONS[_selected]
		_mode = REMAP
		_time = 0.0
	elif _selected == ROW_LANG:
		Lang.cycle_lang(1)
	elif _selected == ROW_CREDITS:
		_mode = CREDITS
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


## Siempre activo (process_mode ALWAYS), pausado o no: ESC/Start abre/cierra
## el menú, y mientras se espera una tecla nueva, captura la primera que llegue.
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
	if _mode == CREDITS:
		if (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventJoypadButton and event.pressed):
			get_viewport().set_input_as_handled()
			_mode = MENU
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		toggle()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BACK:
		get_viewport().set_input_as_handled()
		toggle()


## Sustituye solo el evento de teclado de la acción (no el de mando, que es
## fijo): así remapear una tecla nunca desliga el botón del gamepad.
func _apply_action_keymap(action: String, keycode: int) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = keycode
	InputMap.action_add_event(action, new_ev)


func _draw_stage() -> void:
	var s := _stage
	var font := P.font()
	s.draw_rect(PANEL.grow(12.0), P.BRASS_DARK)
	s.draw_rect(PANEL, P.WOOD)
	s.draw_rect(PANEL.grow(-14.0), P.RED_DARK)
	s.draw_rect(PANEL.grow(-14.0), P.BRASS, false, 4.0)
	var cx := PANEL.get_center().x
	_text(font, Vector2(cx, PANEL.position.y + 90), Lang.t("SETTINGS_TITLE"), 64, P.BRASS_LIGHT)

	if _mode == MENU:
		for i in ACTIONS.size():
			var action: String = ACTIONS[i]
			var y := _row_y(i)
			var color := P.BULB_ON if i == _selected else P.CREAM
			var line := "%s   [ %s ]" % [Lang.t(LABEL_KEYS[action]), OS.get_keycode_string(_keys[action])]
			_text(font, Vector2(cx, y), line, 34, color)
		_draw_volume_row(font, _row_y(ROW_MUSIC), Lang.t("MUSIC_VOLUME"), Sfx.music_volume, _selected == ROW_MUSIC)
		_draw_volume_row(font, _row_y(ROW_SFX), Lang.t("SFX_VOLUME"), Sfx.sfx_volume, _selected == ROW_SFX)
		_text(font, Vector2(cx, _row_y(ROW_LANG)), "%s   [ %s ]" % [Lang.t("LANGUAGE_ROW"), Lang.LANG_NAMES[Lang.lang]], 34, P.BULB_ON if _selected == ROW_LANG else P.CREAM)
		_text(font, Vector2(cx, _row_y(ROW_CREDITS)), Lang.t("CREDITS_ROW"), 34, P.BULB_ON if _selected == ROW_CREDITS else P.CREAM)
		_text(font, Vector2(cx, _row_y(ROW_RESET)), Lang.t("RESET_DEFAULTS"), 34, P.BULB_ON if _selected == ROW_RESET else P.CREAM)
		_text(font, Vector2(cx, _row_y(ROW_QUIT)), Lang.t("QUIT_GAME"), 34, P.BULB_ON if _selected == ROW_QUIT else P.CREAM)
		_text(font, Vector2(cx, _row_y(ROW_CLOSE)), Lang.t("CLOSE"), 34, P.BULB_ON if _selected == ROW_CLOSE else P.CREAM)
		_text(font, Vector2(cx, PANEL.position.y + PANEL.size.y - 60), Lang.t("SETTINGS_HINT"), 24, P.BRASS_LIGHT)
	elif _mode == REMAP:
		_text(font, Vector2(cx, PANEL.position.y + 420), Lang.t("PRESS_NEW_KEY"), 36, P.CREAM)
		_text(font, Vector2(cx, PANEL.position.y + 480), Lang.t(LABEL_KEYS[_remap_action]), 46, P.BULB_ON)
		var blink: bool = fmod(_time * 2.0, 1.0) < 0.6
		if blink:
			_text(font, Vector2(cx, PANEL.position.y + 580), "...", 46, P.BRASS_LIGHT)
		_text(font, Vector2(cx, PANEL.position.y + PANEL.size.y - 60), Lang.t("ESC_CANCEL"), 26, P.BRASS_LIGHT)
	elif _mode == CREDITS:
		_text(font, Vector2(cx, PANEL.position.y + 300), "Pinball Ultra", 70, P.BULB_ON)
		_text(font, Vector2(cx, PANEL.position.y + 420), Lang.t("CREDITS_MADE_BY"), 38, P.CREAM)
		_text(font, Vector2(cx, PANEL.position.y + 490), Lang.t("CREDITS_ENGINE"), 34, P.BRASS_LIGHT)
		_text(font, Vector2(cx, PANEL.position.y + 560), Lang.t("CREDITS_ART_AUDIO"), 34, P.BRASS_LIGHT)
		_text(font, Vector2(cx, PANEL.position.y + PANEL.size.y - 60), Lang.t("ESC_BACK"), 26, P.BRASS_LIGHT)


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
