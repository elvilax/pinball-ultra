extends SceneTree
var main
var f := 0
func _initialize():
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
func shot(n): root.get_texture().get_image().save_png("res://_shot%d.png" % n)
func _process(_d):
	f += 1   # frames de dibujo (60/s): el árbol se pausa durante la ruleta
	if f == 2: main._highscore_ui.hide_table(); main._new_game()   # sale del modo atracción
	if f < 5 or main._balls.is_empty(): return false
	var b = main._balls[0]
	if f == 30: b.teleport(Vector2(500, 150))            # túnel x3
	if f == 150: shot(1)
	if f == 160:
		main._roulette.forced_number = 14            # rojo
		b.teleport(Vector2(500, 1150), Vector2(0, -300))  # entra por abajo
	if f == 215: shot(2)
	if f == 230: Input.action_press("flipper_left")
	if f == 236: Input.action_release("flipper_left")
	if f == 236 + 300: shot(3)
	if f == 236 + 440: shot(4)
	if f == 236 + 600: shot(5)
	if f % 60 == 0: print("t=%d ball=%s cap=%s paused=%s mult=%d score=%d pot=%d spinning=%s bw=%s" % [f/60, b.global_position.round(), b.captured, paused, main.multiplier, main.score, main.pot, main._roulette.spinning, main._big_win.visible])
	if f == 1500: quit()
	return false
