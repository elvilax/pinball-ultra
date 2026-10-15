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
