extends Node
## The music of the game while in the town (the node "Muziek" of the HUD): the tune that
## opens the map once (MAP_JINGLE), then one loop everywhere (CITY_MUSIC, tools/muziek/: made
## from the composition, docs/MUZIEK.md), fading in. Going into a building with music of its
## own (set_indoor: the merchant's) crossfades to that and back (equal power: the amplitudes
## follow a quarter sine and cosine, so the sum stays as loud and there is no dip halfway),
## and going back to a loop that is still fading out fades that one in again. Softer while
## the game is paused (pause menu, game menu, story box: PAUSED_DB) and under a jingle
## (play_jingle, duck: JINGLE_DUCK_DB).
## This is the behaviour layer: the players, the fades over time, the jingles. The levels
## and the steps of the fades are plain sums in the rules layer (city_music_rules.gd); sound
## has no view and no layout.
##   const CityMusic = preload("res://scripts/audio/city_music.gd")

const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
const CityMusicRules = preload("res://scripts/audio/city_music_rules.gd")
## The tune that opens the map when the game starts (max 6 s), and how loud.
const MAP_JINGLE := "res://assets/audio/muziek/deuntje_kaart_start.ogg"
const MAP_JINGLE_VOLUME_DB := -5.0
const MUSIC_FOLDER := "res://assets/audio/muziek/"
## The levels and the fades are the rules' (CityMusicRules); here under their old names for
## whoever uses the music (the HUD, the interiors, the tests).
const CITY_MUSIC := CityMusicRules.CITY_MUSIC
const INDOOR_MUSIC_FADE := CityMusicRules.INDOOR_MUSIC_FADE
const JINGLE_DUCK_DB := CityMusicRules.JINGLE_DUCK_DB
const VOLUME_DB := CityMusicRules.VOLUME_DB
const PAUSED_DB := CityMusicRules.PAUSED_DB
const CITY_LOOP_SOFTER_DB := CityMusicRules.CITY_LOOP_SOFTER_DB
const MUZAK_PREFIX := CityMusicRules.MUZAK_PREFIX
const MUZAK_SOFTER_DB := CityMusicRules.MUZAK_SOFTER_DB
const FADE_IN := CityMusicRules.FADE_IN
## The DetailNiveau of the city scene (beside the HUD): the jingle waits until it has merged the map.
const DETAIL_PATH := NodePath("../../DetailNiveau")

## Whether the music stays at full level although the game is paused (the shop screen
## pauses the game but its music is the point of it); none: never.
var loud_while_paused := Callable()

var _file := ""                 # the loop that is (fading) in; "" fades them all out (death)
var _on := false                # the jingle is over: the city music plays
var _players := {}              # file -> AudioStreamPlayer, also the ones fading out
var _weights := {}              # file -> 0..1, where in its fade it is
var _fade := FADE_IN            # seconds of the running fade
var _level_db := VOLUME_DB
var _indoor_file := ""          # the loop of the building the player is in (set_indoor)
var _jingles_playing := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # it fades on while the game is paused


func _process(delta: float) -> void:
	var loud := loud_while_paused.is_valid() and bool(loud_while_paused.call())
	_level_db = CityMusicRules.next_level_db(_level_db, CityMusicRules.level_target(get_tree().paused, loud, _jingles_playing), delta)
	# slow motion slows every sound down (AudioServer.playback_speed_scale), but not the music
	var music_pitch := CityMusicRules.music_pitch(AudioServer.playback_speed_scale)
	for file: String in _players.keys():
		var player: AudioStreamPlayer = _players[file]
		player.pitch_scale = music_pitch
		var weight := CityMusicRules.next_weight(_weights[file], file == _file, delta, _fade)
		_weights[file] = weight
		if CityMusicRules.is_faded_out(weight, file == _file):
			player.queue_free()
			_players.erase(file)
			_weights.erase(file)
			continue
		player.volume_db = CityMusicRules.loop_volume_db(_level_db, file, weight)


# ------------------------------------------------------------------ what plays

## The short tune that opens the map (MAP_JINGLE): once, as soon as the map is there; while
## the DetailNiveau is still merging (the loading screen) it waits for that. After it the
## city music.
func start_with_map_jingle() -> void:
	var level_of_detail := get_node_or_null(DETAIL_PATH)
	if level_of_detail and level_of_detail.has_method("is_merging") and level_of_detail.is_merging():
		await level_of_detail.merge_finished
	# and until the loading screen is gone: meanwhile only its waiting music plays
	while LoadingScreenScript.showing(get_tree()):
		await get_tree().process_frame
	var stream := _load_stream(MAP_JINGLE, false)
	if stream == null:
		push_warning("city music: no map jingle at %s" % MAP_JINGLE)
		play_city()
		return
	var player := AudioStreamPlayer.new()
	player.name = "KaartDeuntje"
	player.stream = stream
	player.volume_db = MAP_JINGLE_VOLUME_DB
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	player.finished.connect(play_city)


## Starts the city music (after the jingle).
func play_city() -> void:
	if _on:
		return
	_on = true
	_fade_to(CITY_MUSIC, FADE_IN)


## Inside a building (Interiors): its own loop (`file`, in MUSIC_FOLDER; the merchant's for a
## snack bar) in place of the city's, fading over INDOOR_MUSIC_FADE s; "" back to the city's.
func set_indoor(file: String) -> void:
	_indoor_file = file
	if file != "":
		_fade_to(file, INDOOR_MUSIC_FADE)
	elif _on:
		_fade_to(CITY_MUSIC, INDOOR_MUSIC_FADE)


## The loop of the building the player is in ("" outside).
func indoor_file() -> String:
	return _indoor_file


## Fades all the music out over `seconds` and leaves it out (the player died).
func stop(seconds: float) -> void:
	_on = false
	_fade_to("", seconds)


## Holds the music down as under a jingle (JINGLE_DUCK_DB) while something else must be heard
## (an announcement in a supermarket: Announcer); every true needs a false after it.
func duck(ducked: bool) -> void:
	_jingles_playing = CityMusicRules.jingles_after(_jingles_playing, ducked)


## Plays a jingle once over the music, which is held down meanwhile (nothing without the
## file). `player_name` names its player (a child of this node).
func play_jingle(path: String, volume_db: float, player_name: String) -> void:
	var stream := _load_stream(path, false)
	if stream == null:
		push_warning("city music: no jingle at %s" % path)
		return
	var jingle := AudioStreamPlayer.new()
	jingle.name = player_name
	jingle.stream = stream
	jingle.volume_db = volume_db
	jingle.process_mode = Node.PROCESS_MODE_ALWAYS   # also while the story box holds the game
	add_child(jingle)
	jingle.play()
	duck(true)
	jingle.finished.connect(func() -> void:
		duck(false)
		jingle.queue_free())


# ------------------------------------------------------------------ for whoever looks on

## The file of the loop that is (fading) in; "" when all fade out.
func file() -> String:
	return _file


## The level of the music now (dB), before a loop's own level and its fade.
func level_db() -> float:
	return _level_db


## How many jingles (and announcements) hold the music down now.
func jingles_playing() -> int:
	return _jingles_playing


## Where the loop `loop_file` is along its fade (0..1; 0 when it does not play).
func weight_of(loop_file: String) -> float:
	return float(_weights.get(loop_file, 0.0))


## The player of the loop `loop_file` (null when it does not play).
func player_of(loop_file: String) -> AudioStreamPlayer:
	return _players.get(loop_file) as AudioStreamPlayer


## How many loops play now (more than one during a crossfade).
func loop_count() -> int:
	return _players.size()


# ------------------------------------------------------------------ the players

## Makes `file` the loop that fades in over `fade` s (the others fade out); "" fades all out.
func _fade_to(new_file: String, fade: float) -> void:
	_file = new_file
	_fade = CityMusicRules.fade_seconds(fade)
	if new_file == "" or _players.has(new_file):
		return
	var stream := _load_stream(MUSIC_FOLDER + new_file, true)
	if stream == null:
		push_warning("city music: no music %s" % new_file)
		return
	var player := AudioStreamPlayer.new()
	player.name = "StadMuziek"
	player.stream = stream
	player.volume_db = CityMusicRules.SILENT_DB
	add_child(player)
	# the same point in the bar as the loudest loop now (they all share one length)
	player.play(CityMusicRules.start_position(_loudest_position(), stream.get_length()))
	_players[new_file] = player
	_weights[new_file] = 0.0


## Where in its loop the loudest loop is now (seconds; 0 when none plays).
func _loudest_position() -> float:
	var playing: Array = _players.keys().filter(func(loop_file: String) -> bool: return (_players[loop_file] as AudioStreamPlayer).playing)
	var loudest := _players.get(CityMusicRules.loudest_loop(_weights, playing)) as AudioStreamPlayer
	if loudest == null:
		return 0.0
	return loudest.get_playback_position() + AudioServer.get_time_since_last_mix()


## The music at `path` (imported, or the loose file when not imported yet), looping or
## not; null without the file.
static func _load_stream(path: String, looping: bool) -> AudioStream:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	return stream
