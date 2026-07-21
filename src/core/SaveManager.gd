extends Node

# Zapis i odczyt Kronik do katalogu użytkownika (user://kroniki).
# Każda kronika to jeden plik .json ze stanem sesji.

const DIR := "user://kroniki"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func _slug(name: String) -> String:
	var s := name.strip_edges().to_lower()
	var out := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "-" or ch == "_":
			out += "-"
	out = out.strip_edges().lstrip("-").rstrip("-")
	if out == "":
		out = "kronika"
	return out

# Zapisuje bieżący stan gry. Zwraca ścieżkę pliku.
func save_current() -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var base := _slug(Game.world.get("name", "kronika"))
	var path := "%s/%s.json" % [DIR, base]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(Game.to_dict(), "\t"))
		f.close()
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
	return true

func delete_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
