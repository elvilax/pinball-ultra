extends Node
## Logros persistentes en user://achievements.json: contadores de toda la
## vida (no solo de la partida) más qué logros ya se han desbloqueado.
## Autoload "Achievements": otros scripts solo llaman a `add(stat, cantidad)`
## o `set_stat_max(stat, valor)` cuando ocurre el evento correspondiente;
## aquí se decide si eso desbloquea algo y se emite `unlocked` para que
## AchievementToast lo anuncie.

signal unlocked(id: String)

const PATH := "user://achievements.json"

## Orden de aparición en la pantalla de logros del menú de ajustes.
const ORDER := [
	"first_ramp", "ramp_veteran", "bumper_master", "skill_shot", "all_targets",
	"extra_ball", "multiball", "jackpot", "roulette_green", "high_roller",
	"no_tilt_game", "hall_of_fame", "dedicated",
]

## stat: el contador de toda la vida que hay que alcanzar (goal) para desbloquear.
const DEFS := {
	"first_ramp": {"title": "ACH_FIRST_RAMP_T", "desc": "ACH_FIRST_RAMP_D", "stat": "ramps", "goal": 1},
	"ramp_veteran": {"title": "ACH_RAMP_VETERAN_T", "desc": "ACH_RAMP_VETERAN_D", "stat": "ramps", "goal": 50},
	"bumper_master": {"title": "ACH_BUMPER_MASTER_T", "desc": "ACH_BUMPER_MASTER_D", "stat": "bumpers", "goal": 200},
	"skill_shot": {"title": "ACH_SKILL_SHOT_T", "desc": "ACH_SKILL_SHOT_D", "stat": "skill_shots", "goal": 1},
	"all_targets": {"title": "ACH_ALL_TARGETS_T", "desc": "ACH_ALL_TARGETS_D", "stat": "targets_cleared", "goal": 1},
	"extra_ball": {"title": "ACH_EXTRA_BALL_T", "desc": "ACH_EXTRA_BALL_D", "stat": "extra_balls", "goal": 1},
	"multiball": {"title": "ACH_MULTIBALL_T", "desc": "ACH_MULTIBALL_D", "stat": "multiballs", "goal": 1},
	"jackpot": {"title": "ACH_JACKPOT_T", "desc": "ACH_JACKPOT_D", "stat": "jackpots", "goal": 1},
	"roulette_green": {"title": "ACH_ROULETTE_GREEN_T", "desc": "ACH_ROULETTE_GREEN_D", "stat": "roulette_greens", "goal": 1},
	"high_roller": {"title": "ACH_HIGH_ROLLER_T", "desc": "ACH_HIGH_ROLLER_D", "stat": "score", "goal": 100000},
	"no_tilt_game": {"title": "ACH_NO_TILT_T", "desc": "ACH_NO_TILT_D", "stat": "no_tilt_games", "goal": 1},
	"hall_of_fame": {"title": "ACH_HALL_OF_FAME_T", "desc": "ACH_HALL_OF_FAME_D", "stat": "hof_entries", "goal": 1},
	"dedicated": {"title": "ACH_DEDICATED_T", "desc": "ACH_DEDICATED_D", "stat": "games_played", "goal": 10},
}

var _stats := {}
var _unlocked := {}


func _ready() -> void:
	_load()


## Suma `amount` al contador de toda la vida `stat` y comprueba desbloqueos.
func add(stat: String, amount: int = 1) -> void:
	_stats[stat] = int(_stats.get(stat, 0)) + amount
	_check_unlocks()
	_save()


## Para contadores que son "el mejor hasta ahora" (p.ej. la puntuación más
## alta en una sola partida) en vez de una suma acumulada.
func set_stat_max(stat: String, value: int) -> void:
	if value > int(_stats.get(stat, 0)):
		_stats[stat] = value
		_check_unlocks()
		_save()


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


## Progreso actual hacia `id`: [valor_actual_recortado, meta].
func progress(id: String) -> Array:
	var def: Dictionary = DEFS[id]
	var goal: int = def["goal"]
	var current: int = mini(int(_stats.get(def["stat"], 0)), goal)
	return [current, goal]


func _check_unlocks() -> void:
	for id in ORDER:
		if _unlocked.has(id):
			continue
		var def: Dictionary = DEFS[id]
		if int(_stats.get(def["stat"], 0)) >= int(def["goal"]):
			_unlocked[id] = true
			unlocked.emit(id)


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	if typeof(data.get("stats")) == TYPE_DICTIONARY:
		_stats = data["stats"]
	if typeof(data.get("unlocked")) == TYPE_DICTIONARY:
		_unlocked = data["unlocked"]


func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"stats": _stats, "unlocked": _unlocked}))
