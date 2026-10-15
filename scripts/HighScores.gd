extends RefCounted
## Tabla de récords persistente en user://highscores.json: lista de
## {"initials": "ABC", "score": 12345}, ordenada de mayor a menor.

const PATH := "user://highscores.json"
const MAX_ENTRIES := 8
## Tabla de fábrica la primera vez que se juega: vacía, sin puntuaciones de relleno.
const DEFAULT_SCORES: Array = []


static func load_scores() -> Array:
	if not FileAccess.file_exists(PATH):
		return DEFAULT_SCORES.duplicate(true)
	var file := FileAccess.open(PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		return DEFAULT_SCORES.duplicate(true)
	return data


static func save_scores(scores: Array) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(scores))


## ¿Esta puntuación entraría en la tabla (aunque sea de las últimas)?
static func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	var scores := load_scores()
	if scores.size() < MAX_ENTRIES:
		return true
	for entry in scores:
		if score > int(entry["score"]):
			return true
	return false


## Añade la puntuación, reordena, recorta a MAX_ENTRIES, guarda y devuelve la tabla final.
static func insert(initials: String, score: int) -> Array:
	var scores := load_scores()
	scores.append({"initials": initials, "score": score})
	scores.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if scores.size() > MAX_ENTRIES:
		scores = scores.slice(0, MAX_ENTRIES)
	save_scores(scores)
	return scores
