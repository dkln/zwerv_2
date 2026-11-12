extends Node
## The loudspeakers of a supermarket (scripts/world/supermarket.gd makes one): while the
## player is inside, now and then an announcement, the way the station does it
## (scripts/world/station.gd _speak): the muzak goes down (GameHud.duck_music), the chain's
## jingle plays (assets/audio/muziek/jingle_<brand>.ogg, tools/muziek/derive.py), then the
## babble of the announcer's voice over the loudspeakers (StationAudio "Omroep") while the
## words type out at the bottom of the screen. What is said: an offer (a product of a shelf
## of this branch, with this branch's price; ALFRED STEYHN's bonus in its own words) or a
## notice (data/gesprekken/omroep_supermarkt.json).

const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const DATA_FILE := "res://data/gesprekken/omroep_supermarkt.json"
const MUSIC_FOLDER := "res://assets/audio/muziek/"
const JINGLE_PREFIX := "jingle_"
## Levels (dB) of the jingle and the voice on the loudspeakers.
const JINGLE_DB := -6.0
const VOICE_DB := -3.0
## A breath between the jingle and the voice (seconds).
const AFTER_JINGLE_SECONDS := 0.3
## As the station: the words type out at this share of the story box's speed, the whole
## line stays a little when it is all there; the voice talks at most this many clips.
const TYPE_SPEED := 0.4
const HOLD_SECONDS := 2.5
const MOST_CLIPS := 12
## The aisles a notice can name ({gang}).
const AISLES := 6

var _market: Node                    # the supermarket (brand, plan, chain(), product())
var _data := {}
var _random := RandomNumberGenerator.new()
var _clock := 0.0                    # seconds until the next announcement
var _inside := false
var _announcing := false
var _ducked := false
var _run := 0                        # which visit an announcement belongs to (stop() ends it)
var _last_text := ""
var _subtitle_layer: CanvasLayer
var _subtitle: RichTextLabel
var _typewriter: Typewriter


func _init(market: Node) -> void:
	_market = market
	name = "Omroep"


func _ready() -> void:
	_random.randomize()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
	_data = parsed if parsed is Dictionary else {}
	_make_subtitle()


## The player came in: the first announcement after a little while ("eerste").
func start() -> void:
	_inside = true
	_run += 1
	_clock = _seconds_between("eerste", Vector2(12.0, 30.0))


## The player went out: quiet, the text gone, the music up again.
func stop() -> void:
	_inside = false
	_run += 1
	_announcing = false
	if _subtitle_layer:
		_subtitle_layer.visible = false
	_set_ducked(false)


func _exit_tree() -> void:
	_set_ducked(false)


func _process(delta: float) -> void:
	if _announcing and _typewriter:
		_typewriter.update(delta * TYPE_SPEED)
	if not _inside or _announcing:
		return
	_clock -= delta
	if _clock <= 0.0:
		_speak(_next_text())


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


# ------------------------------------------------------------------ saying it

## The music down, the chain's jingle, then the voice talking while the words type out at the
## bottom of the screen; the line stays a little; the music up again.
func _speak(text: String) -> void:
	if text == "":
		_clock = _seconds_between("tussen", Vector2(45.0, 100.0))
		return
	_announcing = true
	var run := _run
	StationAudio.ensure_buses()
	_set_ducked(true)
	var jingle := _play_on_speakers(_jingle_stream(), JINGLE_DB)
	if jingle:
		await jingle.finished
	await get_tree().create_timer(AFTER_JINGLE_SECONDS, false).timeout
	if run != _run:
		return
	_typewriter.start(text)
	_subtitle_layer.visible = true
	var voice := String(_chain_lines().get("stem", "vrouw"))
	var clips_left := MOST_CLIPS
	while run == _run and is_inside_tree() and clips_left > 0 and not _typewriter.is_done():
		clips_left -= 1
		var babble := _play_on_speakers(StationAudio.stream("brabbel_%s_neutraal_%d" % [voice, _random.randi_range(1, 3)]), VOICE_DB)
		if babble:
			await babble.finished
		else:
			await get_tree().create_timer(0.6, false).timeout
		await get_tree().create_timer(0.06, false).timeout
	if run != _run:
		return
	_typewriter.finish()
	await get_tree().create_timer(HOLD_SECONDS, false).timeout
	if run != _run:
		return
	_subtitle_layer.visible = false
	_set_ducked(false)
	_clock = _seconds_between("tussen", Vector2(45.0, 100.0))
	_announcing = false


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


## Plays `stream` once over the loudspeakers (the announcer's bus); null without a stream.
func _play_on_speakers(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	if stream == null or not is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = StationAudio.ANNOUNCER_BUS
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


func _set_ducked(ducked: bool) -> void:
	if ducked == _ducked:
		return
	_ducked = ducked
	var hud := _hud()
	if hud and hud.has_method("duck_music"):
		hud.duck_music(ducked)


func _hud() -> Node:
	var interiors := _market.get_parent() if _market else null
	var hud_path: Variant = interiors.get("hud_path") if interiors else null
	return interiors.get_node_or_null(hud_path) if hud_path is NodePath else null


## The line at the bottom of the screen, as the station's (station.gd _make_subtitle).
func _make_subtitle() -> void:
	_subtitle_layer = CanvasLayer.new()
	_subtitle_layer.name = "Omroeptekst"
	_subtitle_layer.layer = 4
	_subtitle_layer.visible = false
	add_child(_subtitle_layer)
	_subtitle = RichTextLabel.new()
	_subtitle.add_theme_font_override("normal_font", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	_subtitle.add_theme_font_size_override("normal_font_size", UiStyle.ANNOUNCEMENT_FONT_SIZE)
	_subtitle.add_theme_color_override("default_color", Color("#FFE9B8"))
	UiStyle.faux_3d(_subtitle, 4)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.scroll_active = false
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.anchor_left = 0.08
	_subtitle.anchor_right = 0.92
	_subtitle.anchor_top = 0.74
	_subtitle.anchor_bottom = 0.95
	_subtitle_layer.add_child(_subtitle)
	_typewriter = Typewriter.new(_subtitle, self)
	_typewriter.sound = false
