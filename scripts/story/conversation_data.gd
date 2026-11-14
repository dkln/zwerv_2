extends RefCounted
## The data of the conversations (data/gesprekken/*.json), each file read once and kept
## (reload reads them again). Only the files: what is said, to whom and when is
## conversation_rules.gd (logic, docs/CODE_LAGEN.md), which gets these dictionaries handed in.
##   const ConversationData = preload("res://scripts/story/conversation_data.gd")

const STREET_FILE := "res://data/gesprekken/voorbijgangers.json"
const COUNTER_FILE := "res://data/gesprekken/snackbarhouder.json"
const SHOPS_FILE := "res://data/gesprekken/winkels.json"
const STAFF_FILE := "res://data/gesprekken/personeel.json"
const CHARACTERS_FILE := "res://data/gesprekken/personages.json"

static var _street := {}
static var _counter := {}
static var _shops := {}
static var _staff := {}
static var _characters := {}


## The street conversations (data/gesprekken/voorbijgangers.json), read once.
static func street() -> Dictionary:
	if _street.is_empty():
		_street = read(STREET_FILE)
	return _street


## Behind the counter (data/gesprekken/snackbarhouder.json), read once.
static func counter() -> Dictionary:
	if _counter.is_empty():
		_counter = read(COUNTER_FILE)
	return _counter


## The shops of Den Haag Centraal (data/gesprekken/winkels.json), read once.
static func shops() -> Dictionary:
	if _shops.is_empty():
		_shops = read(SHOPS_FILE)
	return _shops


## The people on duty (data/gesprekken/personeel.json), read once.
static func staff() -> Dictionary:
	if _staff.is_empty():
		_staff = read(STAFF_FILE)
	return _staff


## The people of the story (data/gesprekken/personages.json "personen": id -> data), read once.
static func characters() -> Dictionary:
	if _characters.is_empty():
		_characters = read(CHARACTERS_FILE)
	return _characters.get("personen", {})


## Reads them again (after changing the files, while the game runs).
static func reload() -> void:
	_characters = {}
	_staff = {}
	_street = {}
	_counter = {}
	_shops = {}


## The JSON object in the file at `path`; {} (and an error) when it is none.
static func read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("conversations: %s is no valid JSON (%s)" % [path, "leeg" if text.is_empty() else "fout in het bestand"])
		return {}
	return data
