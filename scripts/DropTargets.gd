extends Node2D
## Banco de 3 dianas abatibles en el hueco libre de la izquierda, entre la
## rampa y la pared. Tumbarlas todas duplica el bote; se levantan solas
## un momento después.

signal target_hit(points: int, at: Vector2)
signal all_down

const DropTarget := preload("res://scripts/DropTarget.gd")

## Columna vertical en el hueco izquierdo: deja libres la rampa (su tubo pasa
## más a la izquierda, x~95-150) y la ruleta (su anillo empieza en x~250).
const POSITIONS := [Vector2(230, 620), Vector2(230, 760), Vector2(230, 900)]
const RESET_DELAY := 1.3

var _targets: Array = []
var _celebrate := 0.0


func _ready() -> void:
	for pos in POSITIONS:
		var t := DropTarget.new()
		t.position = pos
		add_child(t)
		t.hit.connect(_on_target_hit.bind(t))
		_targets.append(t)


func _on_target_hit(target: DropTarget) -> void:
	target_hit.emit(DropTarget.POINTS, target.global_position)
	if _all_down():
		Sfx.play("double_pot")
		all_down.emit()
		_celebrate = RESET_DELAY


func _all_down() -> bool:
	for t in _targets:
		if not t.down:
			return false
	return true


func _process(delta: float) -> void:
	if _celebrate > 0.0:
		_celebrate -= delta
		if _celebrate <= 0.0:
			for t in _targets:
				t.raise_up()
