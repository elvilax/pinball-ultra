extends RefCounted
## Texto de puntos que salta y se desvanece ("+100"). Uso: FloatingText.spawn(...)


static func spawn(parent: Node, pos: Vector2, text: String, color: Color, font_size := 46) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 20
	label.size = Vector2(400, 80)
	label.position = pos - Vector2(200, 40)
	label.pivot_offset = Vector2(200, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://scripts/Palette.gd").font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.9, 0.84, 0.7))
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", 12)
	label.scale = Vector2.ZERO
	parent.add_child(label)

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 110.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tween.chain().tween_callback(label.queue_free)
