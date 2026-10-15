extends SceneTree
## Genera el icono del snap/escritorio por código, con el mismo lenguaje
## visual que un bumper de la mesa. Dibuja en un SubViewport propio de
## 512x512 (no depende del tamaño real de la ventana, que varía según el
## display). Uso: xvfb-run godot-4 --path . -s _icon_gen.gd --rendering-driver opengl3

const P := preload("res://scripts/Palette.gd")
const SIZE := 512

var _vp: SubViewport
var _canvas: Node2D
var _f := 0


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	_canvas = Node2D.new()
	_vp.add_child(_canvas)
	_canvas.draw.connect(_draw.bind(_canvas))


func _process(_delta: float) -> bool:
	_f += 1
	_canvas.queue_redraw()
	if _f == 6:
		_vp.get_texture().get_image().save_png("res://icon.png")
	if _f >= 8:
		quit()
	return false


func _draw(c: Node2D) -> void:
	var center := Vector2(SIZE, SIZE) / 2.0
	var side := float(SIZE)

	c.draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), P.WOOD_DARK)
	c.draw_circle(center, side * 0.485, P.BRASS_DARK)
	c.draw_circle(center, side * 0.457, P.FELT_DARK)
	c.draw_arc(center, side * 0.457, 0.0, TAU, 72, P.BRASS, side * 0.02, true)
	c.draw_arc(center, side * 0.457, 0.0, TAU, 72, P.BRASS_LIGHT, side * 0.005, true)

	# Bumper grande, mismo lenguaje que Bumper._draw() en la mesa.
	var r := side * 0.29
	var h := side * 0.1
	var top := center + Vector2(0, -h)
	c.draw_circle(center + Vector2(side * 0.027, side * 0.039), r, Color(0, 0, 0, 0.35))
	c.draw_circle(center, r, P.RED.darkened(0.55))
	c.draw_rect(Rect2(center.x - r, center.y - h, r * 2.0, h), P.RED.darkened(0.55))
	c.draw_arc(center, r - 3.0, 0.0, PI, 40, P.BRASS_DARK, side * 0.0176, true)
	c.draw_circle(top, r, P.RED.darkened(0.25))
	c.draw_arc(top, r - 6.0, 0.0, TAU, 72, P.BRASS_LIGHT, side * 0.0293, true)
	c.draw_circle(top, r * 0.62, P.BULB_ON)
	c.draw_arc(top, r * 0.62, 0.0, TAU, 56, P.CREAM, side * 0.0117, true)
	c.draw_circle(top + Vector2(-r * 0.22, -r * 0.22), r * 0.16, Color(1, 1, 1, 0.75))
