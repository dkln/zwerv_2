extends Node
## An announcement over the loudspeakers of a building: the same for the station
## (scripts/world/station/station.gd), the supermarkets (supermarket_announcer.gd extends this)
## and the city hall (city_hall.gd). The music down (GameHud.duck_music, when there is a HUD),
## a sound first (the gong: SoundFiles `intro`, or `intro_stream`, a supermarket's jingle), a
## breath, then the announcer's voice (babble on the announcer's bus, StationAudio) while the
## words type out at the bottom of the screen, the line held a moment, the music up again.
## One at a time: a new one waits till the last is over (queued). `finished` after each.
## This is the behaviour (docs/CODE_LAGEN.md): the queue, the timing, the music; its rules:
## announcer_rules.gd; the line on the screen and the sounds: announcer_view.gd.
##   var announcer := Announcer.new(hud_getter)
##   add_child(announcer)
##   announcer.say("Nummer B 047, loket 3.")

const AnnouncerRules = preload("res://scripts/world/interiors/announcer_rules.gd")
const AnnouncerView = preload("res://scripts/world/interiors/announcer_view.gd")

## An announcement is over (the line gone): `text` was said.
signal finished(text: String)

const SUBTITLE_COLOUR := AnnouncerView.SUBTITLE_COLOUR
const SUBTITLE_LAYER := AnnouncerView.SUBTITLE_LAYER

## The sound before the words: a name of SoundFiles, or a stream of its own (intro_stream, when set).
var intro := "omroep_gong"
var intro_stream: AudioStream = null
var intro_db := -4.0
## Seconds from the start of the intro to the words: -1 waits till the intro is over, then
## after_intro_seconds.
var intro_seconds := -1.0
var after_intro_seconds := 0.35
## The announcer's voice (Babble: brabbel_<voice>_neutraal_<1..voice_clips>).
var voice := "vrouw"
var voice_clips := 6
var voice_db := -3.0
## A pause after each clip, and how long a clip that is missing counts for.
var clip_gap := 0.05
var missing_clip_seconds := 0.5
## The voice talks at most this many clips.
var most_clips := 10
## The words type out at this share of the story box's speed; the whole line stays this long.
var type_speed := 0.45
var hold_seconds := 2.2
## Whether the line is shown (a Callable() -> bool; an empty one: always).
var subtitle_wanted := Callable()

var _hud_of: Callable
var _queue: Array[String] = []
var _speaking := false
var _run := 0                        # which announcement is under way (stop() ends it)
var _ducked := false
## The line on the screen and the sounds (made in _ready: null before).
var view: AnnouncerView
var _random := RandomNumberGenerator.new()


## `hud_of`: a Callable giving the HUD (for ducking the music), or an empty one (no ducking).
func _init(hud_of := Callable()) -> void:
	_hud_of = hud_of
	name = "Omroep"


func _ready() -> void:
	_random.randomize()
	view = AnnouncerView.new()
	add_child(view)


func _process(delta: float) -> void:
	if _speaking and view:
		view.type_on(delta * type_speed)


## Says `text` over the loudspeakers (after the one under way, if any).
func say(text: String) -> void:
	if text == "":
		return
	_queue.append(text)
	if not _speaking:
		_next()


## Whether an announcement is under way.
func is_speaking() -> bool:
	return _speaking


## The text on the screen now (for the checks).
func shown_text() -> String:
	return view.shown_text() if view else ""


## Whether the line is on the screen now, still typing out (for the checks).
func is_typing() -> bool:
	return view != null and view.is_typing()


## Quiet at once: the queue and the text gone, the music up (going out of the building).
func stop() -> void:
	_queue.clear()
	_speaking = false
	_run += 1
	hide_subtitle()
	_set_ducked(false)


## The line off the screen (the announcement goes on: the player went out).
func hide_subtitle() -> void:
	if view:
		view.hide_line()


func _exit_tree() -> void:
	_set_ducked(false)


func _next() -> void:
	if _queue.is_empty() or not is_inside_tree():
		_speaking = false
		return
	_speaking = true
	_run += 1
	var run := _run
	var text: String = _queue.pop_front()
	StationAudio.ensure_buses()
	_set_ducked(true)
	await _play_intro()
	if run != _run:
		return
	await _talk(text, run)
	if run != _run:
		return
	view.show_whole_line()
	await get_tree().create_timer(hold_seconds, false).timeout
	if run != _run:
		return
	hide_subtitle()
	if AnnouncerRules.music_back_up(_queue.size()):
		_set_ducked(false)
	_speaking = false
	finished.emit(text)
	if not _queue.is_empty():
		_next()


## The gong (or the jingle), and the breath after it.
func _play_intro() -> void:
	var sound := intro_stream if intro_stream else StationAudio.stream(intro)
	var player := _play_on_speakers(sound, intro_db)
	if not AnnouncerRules.waits_for_intro_end(intro_seconds):
		await get_tree().create_timer(intro_seconds, false).timeout
		return
	if player:
		await player.finished
	await get_tree().create_timer(after_intro_seconds, false).timeout


## The words typing out while the voice talks on, clip after clip, until the last word is there.
func _talk(text: String, run: int) -> void:
	view.show_line(text, not subtitle_wanted.is_valid() or bool(subtitle_wanted.call()))
	var clips_left := most_clips
	while run == _run and is_inside_tree() and AnnouncerRules.talks_on(clips_left, view.is_typed_out()):
		clips_left -= 1
		var clip := StationAudio.stream(AnnouncerRules.clip_name(voice, _random.randi_range(1, voice_clips)))
		var player := _play_on_speakers(clip, voice_db)
		if player:
			await player.finished
		else:
			await get_tree().create_timer(missing_clip_seconds, false).timeout
		await get_tree().create_timer(clip_gap, false).timeout


## Plays `stream` once over the loudspeakers (the announcer's bus); null without a stream.
func _play_on_speakers(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	if not is_inside_tree():
		return null
	return view.play_sound(stream, volume_db, StationAudio.ANNOUNCER_BUS)


func _set_ducked(ducked: bool) -> void:
	if ducked == _ducked:
		return
	_ducked = ducked
	var hud: Node = _hud_of.call() if _hud_of.is_valid() else null
	if hud and hud.has_method("duck_music"):
		hud.duck_music(ducked)

