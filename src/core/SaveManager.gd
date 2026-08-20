extends Node

# Zapis i odczyt Kronik do katalogu użytkownika (user://kroniki).
# Każda kronika to jeden plik .json ze stanem sesji.
#
# Zapis jest ATOMOWY: dane idą najpierw do pliku tymczasowego, są odczytywane
# z powrotem i sprawdzane, dopiero potem podmieniają właściwy plik, a poprzednia
# wersja zostaje jako kopia .bak. Dzięki temu wyłączenie komputera w trakcie
# zapisywania nie zostawia gracza z uciętym, nieczytelnym JSON-em.

# Katalogi są zmienne wyłącznie po to, żeby testy mogły pisać do własnego
# miejsca zamiast po prawdziwych zapisach gracza (patrz use_test_dirs).
var dir_saves := "user://kroniki"
var dir_chars := "user://postacie"

# Przełącza zapisy na katalog testowy i zwraca go, żeby test mógł po sobie
# posprzątać. Nigdy nie wołane przez samą grę.
func use_test_dirs(tag := "test") -> String:
	dir_saves = "user://%s-kroniki" % tag
	dir_chars = "user://%s-postacie" % tag
	DirAccess.make_dir_recursive_absolute(dir_saves)
	DirAccess.make_dir_recursive_absolute(dir_chars)
	return dir_saves

# Powód ostatniego niepowodzenia — ekran pokazuje go graczowi zamiast udawać,
# że wszystko się udało.
var last_error := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir_saves)

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

# ——— Atomowy zapis pliku ————————————————————————————————————

# Zapisuje tekst pod wskazaną ścieżką, nie ryzykując uszkodzenia poprzedniej
# wersji. Zwraca true tylko wtedy, gdy plik naprawdę leży na dysku i daje się
# odczytać jako poprawny JSON.
func _write_json_atomic(path: String, payload: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "Nie udało się otworzyć pliku do zapisu (błąd %d)." % FileAccess.get_open_error()
		return false
	f.store_string(payload)
	f.close()

	# Czytamy z powrotem: dysk mógł się zapełnić albo zapis mógł się urwać.
	var check := FileAccess.open(tmp, FileAccess.READ)
	if check == null:
		last_error = "Zapis powstał, ale nie daje się odczytać."
		return false
	var back := check.get_as_text()
	check.close()
	if back.length() != payload.length() or typeof(JSON.parse_string(back)) != TYPE_DICTIONARY:
		last_error = "Zapis wyszedł niekompletny — plik nie został podmieniony."
		DirAccess.remove_absolute(tmp)
		return false

	# Poprzednia wersja zostaje jako kopia bezpieczeństwa.
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	if DirAccess.rename_absolute(tmp, path) != OK:
		last_error = "Nie udało się podmienić pliku zapisu."
		return false
	last_error = ""
	return true

# ——— Kroniki ————————————————————————————————————————————————

# Zapisuje bieżący stan gry. Zwraca true przy powodzeniu.
# Każda kronika ma własny plik. Raz nadany zapisuje się w Game.save_path,
# więc kolejne zapisy tej samej rozgrywki aktualizują go zamiast mnożyć pliki,
# a dwie przygody o tej samej nazwie świata nie kasują się nawzajem.
func save_current() -> bool:
	if not Game.started:
		last_error = "Nie ma czego zapisać."
		return false
	if Game.busy:
		# Zapis w połowie tury utrwaliłby akcję gracza bez odpowiedzi narratora.
		last_error = "Trwa tura — zapis po jej zakończeniu."
		return false
	DirAccess.make_dir_recursive_absolute(dir_saves)
	if str(Game.save_path) == "":
		Game.save_path = _new_save_path(str(Game.world.get("name", "kronika")))
	return _write_json_atomic(Game.save_path, JSON.stringify(Game.to_dict(), "\t"))

func _new_save_path(world_name: String) -> String:
	var base := "%s_%s" % [_slug(world_name), Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")]
	var path := "%s/%s.json" % [dir_saves, base]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/%s-%d.json" % [dir_saves, base, n]
		n += 1
	return path

# Lista zapisanych Kronik posortowana od najnowszej. Plik, którego nie da się
# odczytać, NIE znika po cichu — wraca z oznaczeniem „broken”, żeby gracz
# wiedział, że kronika istnieje, tylko jest uszkodzona.
func list_saves() -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_saves)
	if not d:
		return out
	for fname in d.get_files():
		if not fname.ends_with(".json"):
			continue
		var path := "%s/%s" % [dir_saves, fname]
		var parsed = _read_json(path)
		var has_backup := FileAccess.file_exists(path + ".bak")
		if typeof(parsed) != TYPE_DICTIONARY or not validate_save(parsed):
			out.append({
				"path": path, "broken": true, "backup": has_backup,
				"name": fname.get_basename(), "genre": "", "hero": "",
				"turn": 0, "saved_at": "", "mtime": FileAccess.get_modified_time(path),
			})
			continue
		var world: Dictionary = parsed.get("world", {})
		out.append({
			"path": path,
			"broken": false,
			"backup": has_backup,
			"name": world.get("name", "Bez nazwy"),
			"genre": Genres.label(world.get("genre_key", "fantasy")),
			"hero": (parsed.get("character", {}) as Dictionary).get("name", "?"),
			"turn": int(parsed.get("turn", 0)),
			"saved_at": parsed.get("saved_at", ""),
			"mtime": FileAccess.get_modified_time(path),
		})
	out.sort_custom(func(a, b): return a["mtime"] > b["mtime"])
	return out

func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	return JSON.parse_string(txt)

# Sprawdza, czy zapis ma pola właściwych typów. Sam fakt, że plik jest
# słownikiem, niczego nie gwarantuje: "history": "tekst" przeszłoby dalej
# i wysypało grę dopiero przy rysowaniu kroniki.
func validate_save(d: Dictionary) -> bool:
	var arrays := ["history", "locations", "discoveries", "quests", "npcs", "suggestions"]
	for k in arrays:
		if d.has(k) and typeof(d[k]) != TYPE_ARRAY:
			return false
	for k in ["world", "character"]:
		if d.has(k) and typeof(d[k]) != TYPE_DICTIONARY:
			return false
	if d.has("turn") and typeof(d["turn"]) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if d.has("summary") and typeof(d["summary"]) != TYPE_STRING:
		return false
	for k in ["facts", "events"]:
		if d.has(k) and typeof(d[k]) != TYPE_ARRAY:
			return false
	# Kronika bez świata i bohatera nie nadaje się do wczytania.
	return typeof(d.get("world", {})) == TYPE_DICTIONARY \
		and typeof(d.get("character", {})) == TYPE_DICTIONARY

func load_into_game(path: String) -> bool:
	var parsed = _read_json(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		# Uszkodzony plik główny — próbujemy kopii bezpieczeństwa.
		return _load_backup(path, "Plik zapisu jest uszkodzony.")
	if not validate_save(parsed):
		return _load_backup(path, "Zapis ma nieprawidłową strukturę.")
	Game.from_dict(parsed)
	Game.save_path = path   # dalsze zapisy trafiają do tego samego pliku
	last_error = ""
	return true

func _load_backup(path: String, why: String) -> bool:
	var bak := path + ".bak"
	var parsed = _read_json(bak)
	if typeof(parsed) == TYPE_DICTIONARY and validate_save(parsed):
		Game.from_dict(parsed)
		Game.save_path = path
		last_error = "%s Wczytano kopię bezpieczeństwa z poprzedniego zapisu." % why
		return true
	last_error = "%s Kopia bezpieczeństwa też jest niedostępna." % why
	return false

func delete_save(path: String) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

# ——— Magazyn postaci (user://postacie) ————————————————————————
# Postacie gracza zapisują się osobno od kronik, żeby można było ich użyć
# ponownie w kolejnych opowieściach — razem z poziomem i atrybutami.

# Nazwa pliku bierze się z identyfikatora, nie z imienia. Dwaj bohaterowie
# o imieniu „Bruno” to dwie różne postacie i nie mogą się nadpisywać.
func character_path(c: Dictionary) -> String:
	var id := str(c.get("id", "")).strip_edges()
	if id == "":
		id = new_character_id()
		c["id"] = id
	return "%s/%s-%s.json" % [dir_chars, _slug(str(c.get("name", "postac"))), id.substr(0, 8)]

func new_character_id() -> String:
	# Wystarczająco unikalne jak na magazyn postaci jednego gracza.
	return "%d%04d" % [Time.get_unix_time_from_system(), randi() % 10000]

func save_character(c: Dictionary) -> bool:
	if str(c.get("name", "")).strip_edges() == "":
		return false
	DirAccess.make_dir_recursive_absolute(dir_chars)
	var snapshot := c.duplicate(true)
	snapshot.erase("dead")
	return _write_json_atomic(character_path(c), JSON.stringify(snapshot, "\t"))

func list_characters() -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_chars)
	if not d:
		return out
	for fname in d.get_files():
		if not fname.ends_with(".json"):
			continue
		var path := "%s/%s" % [dir_chars, fname]
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
	var parsed = _read_json(path)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
