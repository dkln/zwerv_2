extends "res://scripts/world/interiors/announcer.gd"
## The loudspeakers of a supermarket (scripts/world/interiors/supermarket.gd makes one): while the
## player is inside, now and then an announcement (the Announcer this extends: the muzak down,
## the chain's jingle, assets/audio/muziek/jingle_<brand>.ogg from tools/muziek/derive.py, then
## the announcer's voice while the words type out). What is said: an offer (a product of a
## shelf of this branch, with this branch's price; ALFRED STEYHN's bonus in its own words) or a
## notice (data/gesprekken/omroep_supermarkt.json). This is the behaviour (docs/CODE_LAGEN.md):
## when the next one comes; what is said: supermarket_announcer_rules.gd.

const SupermarketAnnouncerRules = preload("res://scripts/world/interiors/supermarket_announcer_rules.gd")
const DATA_FILE := "res://data/gesprekken/omroep_supermarkt.json"
const MUSIC_FOLDER := SupermarketAnnouncerRules.MUSIC_FOLDER
const JINGLE_PREFIX := SupermarketAnnouncerRules.JINGLE_PREFIX
const AISLES := SupermarketAnnouncerRules.AISLES

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
	_clock = _seconds_between("eerste", SupermarketAnnouncerRules.FIRST_SECONDS)


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
	_clock = _seconds_between("tussen", SupermarketAnnouncerRules.BETWEEN_SECONDS)
	if text == "":
		return
	voice = SupermarketAnnouncerRules.voice(_chain_lines())
	intro_stream = _jingle_stream()
	say(text)


func _on_finished(_text: String) -> void:
	_clock = _seconds_between("tussen", SupermarketAnnouncerRules.BETWEEN_SECONDS)


# ------------------------------------------------------------------ what is said

func _chain_lines() -> Dictionary:
	return SupermarketAnnouncerRules.chain_lines(_data, String(_market.get("brand")))


## An offer or a notice, not the same as the last one.
func _next_text() -> String:
	var text := SupermarketAnnouncerRules.fresh_text(_data, String(_market.get("brand")), _market.get("plan"), _products(),
		_last_text, _random)
	if text == "":
		return _notice()
	_last_text = text
	return text


## Per kind of shelf of this branch its product, at this branch's price.
func _products() -> Dictionary:
	var products := {}
	for category in SupermarketAnnouncerRules.shelf_categories(_market.get("plan")):
		products[category] = _market.call("product", category)
	return products


## A product of one of this branch's shelves, at this branch's price.
func _offer() -> String:
	return SupermarketAnnouncerRules.offer(_data, String(_market.get("brand")), _market.get("plan"), _products(), _random)


## A notice of every supermarket or of this chain, with a checkout of this branch and an aisle.
func _notice() -> String:
	return SupermarketAnnouncerRules.notice(_data, String(_market.get("brand")), _market.get("plan"), _random)


func _seconds_between(key: String, fallback: Vector2) -> float:
	return SupermarketAnnouncerRules.seconds_between(_data, key, fallback, _random)


# ------------------------------------------------------------------ the jingle

func _jingle_stream() -> AudioStream:
	var path := SupermarketAnnouncerRules.jingle_path(String(_market.get("brand")))
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
