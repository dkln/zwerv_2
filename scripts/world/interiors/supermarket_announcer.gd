extends "res://scripts/world/interiors/announcer.gd"
## The loudspeakers of a supermarket (scripts/world/interiors/supermarket.gd makes one): while the
## player is inside, now and then an announcement (the Announcer this extends: the muzak down,
## the chain's jingle, assets/audio/muziek/jingle_<brand>.ogg from tools/muziek/derive.py, then
## the announcer's voice while the words type out). What is said: an offer (a product of a
## shelf of this branch, with this branch's price; ALFRED STEYHN's bonus in its own words) or a
## notice (data/gesprekken/omroep_supermarkt.json).

const DATA_FILE := "res://data/gesprekken/omroep_supermarkt.json"
const MUSIC_FOLDER := "res://assets/audio/muziek/"
const JINGLE_PREFIX := "jingle_"
## The aisles a notice can name ({gang}).
const AISLES := 6

var _market: Node                    # the supermarket (brand, plan, chain(), product())
var _data := {}
var _clock := 0.0                    # seconds until the next announcement
var _inside := false
var _last_text := ""


func _init(market: Node) -> void:
	super(_hud_of_market.bind(market))
	_market = market
	intro_db = -6.0
	after_intro_seconds = 0.3
	voice_clips = 3
	clip_gap = 0.06
	missing_clip_seconds = 0.6
	most_clips = 12
	type_speed = 0.4
	hold_seconds = 2.5
	finished.connect(_on_finished)


func _ready() -> void:
	super()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
	_data = parsed if parsed is Dictionary else {}


## The player came in: the first announcement after a little while ("eerste").
func start() -> void:
	_inside = true
	_clock = _seconds_between("eerste", Vector2(12.0, 30.0))


## The player went out: quiet, the text gone, the music up again.
func stop() -> void:
	_inside = false
	super()


func _process(delta: float) -> void:
	super(delta)
	if not _inside or is_speaking():
		return
	_clock -= delta
	if _clock <= 0.0:
		_announce(_next_text())


## The chain's jingle, then `text` (none: the next try a while later).
func _announce(text: String) -> void:
	_clock = _seconds_between("tussen", Vector2(45.0, 100.0))
	if text == "":
		return
	voice = String(_chain_lines().get("stem", "vrouw"))
	intro_stream = _jingle_stream()
	say(text)


func _on_finished(_text: String) -> void:
	_clock = _seconds_between("tussen", Vector2(45.0, 100.0))


# ------------------------------------------------------------------ what is said

func _chain_lines() -> Dictionary:
	return ((_data.get("ketens", {}) as Dictionary).get(String(_market.get("brand")), {}) as Dictionary)


## An offer or a notice, not the same as the last one.
func _next_text() -> String:
	for _attempt in 4:
		var text := _offer() if _random.randf() < float(_data.get("aanbieding_kans", 0.5)) else _notice()
		if text != "" and text != _last_text:
			_last_text = text
			return text
	return _notice()


## A product of one of this branch's shelves, at this branch's price.
func _offer() -> String:
	var categories: Array[String] = []
	var plan: Dictionary = _market.get("plan")
	for shelf: Dictionary in plan.get("shelves", []):
		var category := String(shelf.get("category", ""))
		if category != "" and not categories.has(category):
			categories.append(category)
	if categories.is_empty():
		return ""
	var product: Dictionary = _market.call("product", categories[_random.randi() % categories.size()])
	if product.is_empty() or String(product.get("name", "")) == "":
		return ""
	var lines := _chain_lines()
	var templates: Array = lines.get("bonus", []) if bool(product.get("bonus", false)) and not (lines.get("bonus", []) as Array).is_empty() \
		else lines.get("aanbieding", [])
	if templates.is_empty():
		return ""
	return String(templates[_random.randi() % templates.size()]).format({
		"naam": String(product["name"]), "prijs": GameHud.money_text(float(product["price"]))})


## A notice of every supermarket or of this chain, with a checkout of this branch and an aisle.
func _notice() -> String:
	var notices: Array = (_data.get("mededelingen", []) as Array) + (_chain_lines().get("mededelingen", []) as Array)
	if notices.is_empty():
		return ""
	var checkouts: Array = (_market.get("plan") as Dictionary).get("checkouts", [])
	var checkout_number := 1
	if not checkouts.is_empty():
		checkout_number = int((checkouts[_random.randi() % checkouts.size()] as Dictionary).get("number", 1))
	return String(notices[_random.randi() % notices.size()]).format({
		"kassa": str(checkout_number), "gang": str(_random.randi_range(1, AISLES))})


func _seconds_between(key: String, fallback: Vector2) -> float:
	var span: Variant = _data.get(key, [])
	if span is Array and (span as Array).size() == 2:
		return _random.randf_range(float(span[0]), float(span[1]))
	return _random.randf_range(fallback.x, fallback.y)


# ------------------------------------------------------------------ the jingle

func _jingle_stream() -> AudioStream:
	var path := MUSIC_FOLDER + JINGLE_PREFIX + String(_market.get("brand")) + ".ogg"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)   # not imported yet
	if stream is AudioStreamOggVorbis:
		stream = (stream as AudioStreamOggVorbis).duplicate()
		(stream as AudioStreamOggVorbis).loop = false
	return stream


## The HUD of the town the supermarket `market` stands in (Interiors.hud_path).
static func _hud_of_market(market: Node) -> Node:
	var interiors := market.get_parent() if market else null
	var hud_path: Variant = interiors.get("hud_path") if interiors else null
	return interiors.get_node_or_null(hud_path) if hud_path is NodePath else null
