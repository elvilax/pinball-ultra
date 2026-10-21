extends RefCounted
## Teclas configurables, persistentes en user://controls.json: un físical
## keycode por acción. Lo usa Main (al arrancar) y SettingsUI (al remapear).

const PATH := "user://controls.json"

const DEFAULTS := {
	"flipper_left": KEY_Z,
	"flipper_right": KEY_M,
	"launch": KEY_SPACE,
	"nudge": KEY_SHIFT,
}

## Botón de mando por acción (fijo, no se remapea desde el menú: solo las
## teclas se remapean). Mismo botón en cualquier mando porque se referencia
## por índice estándar (SDL/XInput), no por nombre de modelo.
const JOYPAD_DEFAULTS := {
	"flipper_left": JOY_BUTTON_LEFT_SHOULDER,
	"flipper_right": JOY_BUTTON_RIGHT_SHOULDER,
	"launch": JOY_BUTTON_A,
	"nudge": JOY_BUTTON_B,
}


static func load_keys() -> Dictionary:
	var keys: Dictionary = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var file := FileAccess.open(PATH, FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			for action in keys.keys():
				if data.has(action):
					keys[action] = int(data[action])
	return keys


static func save_keys(keys: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(keys))
