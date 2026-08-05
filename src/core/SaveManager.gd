extends Node

# Zapis i odczyt Kronik do katalogu użytkownika (user://kroniki).
# Każda kronika to jeden plik .json ze stanem sesji.

const DIR := "user://kroniki"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

# Polskie znaki mają odpowiedniki łacińskie — bez tego „Świat” stałby się
# „wiat”, a „Żaneta” i „Aneta” trafiłyby do jednego pliku.
const TRANSLIT := {
	"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
	"ó": "o", "ś": "s", "ź": "z", "ż": "z",
}

func _slug(name: String) -> String:
	var s := name.strip_edges().to_lower()
	var out := ""
	for ch in s:
		if TRANSLIT.has(ch):
			ch = TRANSLIT[ch]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "-" or ch == "_":
			out += "-"
	out = out.strip_edges().lstrip("-").rstrip("-")
	if out == "":
		out = "kronika"
	return out

# Zapisuje bieżący stan gry. Zwraca ścieżkę pliku.
# Każda kronika ma własny plik. Raz nadany zapisuje się w Game.save_path,
# więc kolejne zapisy tej samej rozgrywki aktualizują go zamiast mnożyć pliki,
# a dwie przygody o tej samej nazwie świata nie kasują się nawzajem.
func save_current() -> String:
	if not Game.started:
		return ""
	DirAccess.make_dir_recursive_absolute(DIR)
	if str(Game.save_path) == "":
		Game.save_path = _new_save_path(str(Game.world.get("name", "kronika")))
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(Game.to_dict(), "\t"))
		f.close()
	return Game.save_path

func _new_save_path(world_name: String) -> String:
	var base := "%s_%s" % [_slug(world_name), Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")]
	var path := "%s/%s.json" % [DIR, base]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/%s-%d.json" % [DIR, base, n]
		n += 1
	return path

# Lista zapisanych Kronik posortowana od najnowszej.
func list_saves() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if not d:
		return out
	for fname in d.get_files():
		if not fname.ends_with(".json"):
			continue
		var path := "%s/%s" % [DIR, fname]
		var f := FileAccess.open(path, FileAccess.READ)
		if not f:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var world: Dictionary = parsed.get("world", {})
		out.append({
			"path": path,
			"name": world.get("name", "Bez nazwy"),
			"genre": Genres.label(world.get("genre_key", "fantasy")),
			"hero": (parsed.get("character", {}) as Dictionary).get("name", "?"),
			"turn": int(parsed.get("turn", 0)),
			"saved_at": parsed.get("saved_at", ""),
			"mtime": FileAccess.get_modified_time(path),
		})
	out.sort_custom(func(a, b): return a["mtime"] > b["mtime"])
	return out

func load_into_game(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	Game.from_dict(parsed)
	Game.save_path = path   # dalsze zapisy trafiają do tego samego pliku
	return true

func delete_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ——— Magazyn postaci (user://postacie) ————————————————————————
# Postacie gracza zapisują się osobno od kronik, żeby można było ich użyć
# ponownie w kolejnych opowieściach — razem z poziomem i atrybutami.

const CHAR_DIR := "user://postacie"

func save_character(c: Dictionary) -> void:
	if str(c.get("name", "")).strip_edges() == "":
		return
	DirAccess.make_dir_recursive_absolute(CHAR_DIR)
	var snapshot := c.duplicate(true)
	snapshot.erase("dead")
	var f := FileAccess.open("%s/%s.json" % [CHAR_DIR, _slug(c["name"])], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(snapshot, "\t"))
		f.close()

func list_characters() -> Array:
	var out: Array = []
	var d := DirAccess.open(CHAR_DIR)
	if not d:
		return out
	for fname in d.get_files():
		if not fname.ends_with(".json"):
			continue
		var path := "%s/%s" % [CHAR_DIR, fname]
		var c := load_character(path)
		if c.is_empty():
			continue
		out.append({
			"path": path,
			"name": c.get("name", "?"),
			"gender": c.get("gender", ""),
			"archetype": c.get("archetype", ""),
			"level": int(c.get("level", 1)),
		})
	out.sort_custom(func(a, b): return str(a["name"]) < str(b["name"]))
	return out

func load_character(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
