extends Node
## An announcement over the loudspeakers of a building, the way the station and the supermarkets
## do it (station.gd _speak, supermarket_announcer.gd): the music down (GameHud.duck_music), a
## sound first (`intro`, the gong of the city hall: SoundFiles "omroep_gong"), a breath, then
## the announcer's voice (babble on the announcer's bus, StationAudio) while the words type out
## at the bottom of the screen, the line held a moment, the music up again. One at a time:
## a new one waits till the last is over (queued).
##   var announcer := Announcer.new(hud_getter)
##   add_child(announcer)
##   announcer.say("Nummer B 047, loket 3.")

const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const SoundFiles = preload("res://scripts/audio/sound_files.gd")

const INTRO_DB := -4.0
const VOICE_DB := -3.0
const AFTER_INTRO_SECONDS := 0.35
const TYPE_SPEED := 0.45
const HOLD_SECONDS := 2.2
const MOST_CLIPS := 10

## The sound before the words (a name of SoundFiles) and the announcer's voice (Babble).
var intro := "omroep_gong"
var voice := "vrouw"
var _hud_of: Callable
var _queue: Array[String] = []
var _speaking := false
var _ducked := false
var _subtitle_layer: CanvasLayer
var _subtitle: RichTextLabel
var _typewriter: Typewriter
var _random := RandomNumberGenerator.new()


## `hud_of`: a Callable giving the HUD (for ducking the music), or an empty one.
func _init(hud_of := Callable()) -> void:
	_hud_of = hud_of
	name = "Omroep"


func _ready() -> void:
	_random.randomize()
	_make_subtitle()


func _process(delta: float) -> void:
	if _speaking and _typewriter:
		_typewriter.update(delta * TYPE_SPEED)


## Says `text` over the loudspeakers (after the one under way, if any).
func say(text: String) -> void:
	if text == "":
		return
	_queue.append(text)
	if not _speaking:
		_next()


## Whether an announcement is under way, and its text (for the checks).
func is_speaking() -> bool:
	return _speaking


func shown_text() -> String:
	return _subtitle.text if _subtitle else ""


## Quiet at once: the text gone, the music up (going out of the building).
func stop() -> void:
	_queue.clear()
	_speaking = false
	if _subtitle_layer:
		_subtitle_layer.visible = false
	_set_ducked(false)


func _exit_tree() -> void:
	_set_ducked(false)


func _next() -> void:
	if _queue.is_empty() or not is_inside_tree():
		_speaking = false
		return
	_speaking = true
	var text: String = _queue.pop_front()
	StationAudio.ensure_buses()
	_set_ducked(true)
	var gong := _play_on_speakers(_load(SoundFiles.path_of(intro)), INTRO_DB)
	if gong:
		await gong.finished
	await get_tree().create_timer(AFTER_INTRO_SECONDS, false).timeout
	if not _speaking:
		return
	_typewriter.start(text)
	_subtitle_layer.visible = true
	var clips_left := MOST_CLIPS
	while _speaking and is_inside_tree() and clips_left > 0 and not _typewriter.is_done():
		clips_left -= 1
		var babble := _play_on_speakers(StationAudio.stream("brabbel_%s_neutraal_%d" % [voice, _random.randi_range(1, 6)]), VOICE_DB)
		if babble:
			await babble.finished
		else:
			await get_tree().create_timer(0.5, false).timeout
		await get_tree().create_timer(0.05, false).timeout
	if not _speaking:
		return
	_typewriter.finish()
	await get_tree().create_timer(HOLD_SECONDS, false).timeout
	if not _speaking:
		return
	_subtitle_layer.visible = false
	if _queue.is_empty():
		_set_ducked(false)
	_next()


static func _load(path: String) -> AudioStream:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	return stream


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
	var hud: Node = _hud_of.call() if _hud_of.is_valid() else null
	if hud and hud.has_method("duck_music"):
		hud.duck_music(ducked)


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
