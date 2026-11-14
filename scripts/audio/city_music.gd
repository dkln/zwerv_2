extends Node
## The music of the game while in the town (the node "Muziek" of the HUD): the tune that
## opens the map once (MAP_JINGLE), then one loop everywhere (CITY_MUSIC, tools/muziek/: made
## from the composition, docs/MUZIEK.md), fading in. Going into a building with music of its
## own (set_indoor: the merchant's) crossfades to that and back (equal power: the amplitudes
## follow a quarter sine and cosine, so the sum stays as loud and there is no dip halfway),
## and going back to a loop that is still fading out fades that one in again. Softer while
## the game is paused (pause menu, game menu, story box: PAUSED_DB) and under a jingle
## (play_jingle, duck: JINGLE_DUCK_DB). The levels themselves are plain sums (level_target,
## own_level_db, loop_volume_db), without the players.
##   const CityMusic = preload("res://scripts/audio/city_music.gd")

const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
## The tune that opens the map when the game starts (max 6 s), and how loud.
const MAP_JINGLE := "res://assets/audio/muziek/deuntje_kaart_start.ogg"
const MAP_JINGLE_VOLUME_DB := -5.0
const MUSIC_FOLDER := "res://assets/audio/muziek/"
const CITY_MUSIC := "spel_loop.ogg"
## Inside a building: how fast its music takes over; how much softer the music is under a jingle.
const INDOOR_MUSIC_FADE := 1.2
const JINGLE_DUCK_DB := 6.0
const VOLUME_DB := -11.0
const PAUSED_DB := -13.0
## The city's own loop (CITY_MUSIC) plays this much softer still: it runs quietly in the
## background, under the sounds of the town; music of a building (the merchant's) does not.
const CITY_LOOP_SOFTER_DB := 3.0
## The muzak of a supermarket (Interiors SUPERMARKET_MUZAK, files starting with this) plays
## softer still: background music in a shop, about as loud as the shop's own sound.
const MUZAK_PREFIX := "supermarkt_muzak_"
const MUZAK_SOFTER_DB := 6.0
const FADE_IN := 3.0
## How fast (dB per second) the level follows pausing and going on.
const LEVEL_SPEED := 30.0
const SILENT_DB := -80.0
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
	_level_db = move_toward(_level_db, level_target(get_tree().paused, loud, _jingles_playing), LEVEL_SPEED * delta)
	# slow motion slows every sound down (AudioServer.playback_speed_scale), but not the music
	var music_pitch := 1.0 / maxf(AudioServer.playback_speed_scale, 0.01)
	for file: String in _players.keys():
		var player: AudioStreamPlayer = _players[file]
		player.pitch_scale = music_pitch
		var weight: float = move_toward(_weights[file], 1.0 if file == _file else 0.0, delta / _fade)
		_weights[file] = weight
		if weight <= 0.0 and file != _file:
			player.queue_free()
			_players.erase(file)
			_weights.erase(file)
			continue
		player.volume_db = loop_volume_db(_level_db, file, weight)


# ------------------------------------------------------------------ the levels

## The level (dB) the music goes to: softer while the game is paused (unless `loud_paused`:
## the shop) and softer still while a jingle plays over it, so the jingle is heard.
static func level_target(paused: bool, loud_paused: bool, jingles_playing: int) -> float:
	var level := PAUSED_DB if paused and not loud_paused else VOLUME_DB
	return level - (JINGLE_DUCK_DB if jingles_playing > 0 else 0.0)


## How much softer (dB, negative) the loop `file` plays than the level of the music: the
## city's own loop a little, the muzak of a supermarket more, a building's music not.
static func own_level_db(file: String) -> float:
	if file.begins_with(MUZAK_PREFIX):
		return -MUZAK_SOFTER_DB
	return -CITY_LOOP_SOFTER_DB if file == CITY_MUSIC else 0.0


## The volume (dB) of the loop `file`, `weight` (0..1) along its fade at the music level
## `level_db`: equal power, the amplitude along a quarter sine.
static func loop_volume_db(level_db: float, file: String, weight: float) -> float:
	return level_db + own_level_db(file) + linear_to_db(maxf(sin(clampf(weight, 0.0, 1.0) * PI * 0.5), 0.0001))


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
	_jingles_playing = maxi(_jingles_playing + (1 if ducked else -1), 0)


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
	_fade = maxf(fade, 0.05)
	if new_file == "" or _players.has(new_file):
		return
	var stream := _load_stream(MUSIC_FOLDER + new_file, true)
	if stream == null:
		push_warning("city music: no music %s" % new_file)
		return
	var player := AudioStreamPlayer.new()
	player.name = "StadMuziek"
	player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)
	# the same point in the bar as the loudest loop now (they all share one length)
	player.play(fmod(_loudest_position(), maxf(stream.get_length(), 0.01)))
	_players[new_file] = player
	_weights[new_file] = 0.0


## Where in its loop the loudest loop is now (seconds; 0 when none plays).
func _loudest_position() -> float:
	var position := 0.0
	var loudest := -1.0
	for other_file: String in _players:
		var other: AudioStreamPlayer = _players[other_file]
		if other.playing and _weights[other_file] > loudest:
			loudest = _weights[other_file]
			position = other.get_playback_position() + AudioServer.get_time_since_last_mix()
	return position


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
