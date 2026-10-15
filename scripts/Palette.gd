extends RefCounted
## Paleta "máquina electromecánica antigua": tapete gastado, madera, latón mate,
## rojo ladrillo y marfil envejecido. Cambia aquí colores y tipografía de todo el juego.

const FELT := Color(0.15, 0.29, 0.2)
const FELT_DARK := Color(0.11, 0.22, 0.15)
const FELT_LIGHT := Color(0.2, 0.36, 0.25)
const WOOD := Color(0.38, 0.24, 0.13)
const WOOD_DARK := Color(0.17, 0.1, 0.055)
const BRASS := Color(0.72, 0.58, 0.3)
const BRASS_DARK := Color(0.36, 0.27, 0.12)
const BRASS_LIGHT := Color(0.9, 0.82, 0.58)
const RED := Color(0.6, 0.16, 0.13)
const RED_DARK := Color(0.32, 0.08, 0.07)
const CREAM := Color(0.9, 0.84, 0.7)
const BLACK := Color(0.1, 0.085, 0.075)
const BULB_ON := Color(1.0, 0.86, 0.55)
const BULB_OFF := Color(0.4, 0.3, 0.16)
const SHADOW := Color(0, 0, 0, 0.35)

static var _font: Font


## Tipografía con serifa del sistema (si no hay ninguna, Godot usa la suya).
static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["DejaVu Serif Condensed", "DejaVu Serif", "Liberation Serif", "Noto Serif"])
		f.font_weight = 700
		_font = f
	return _font
