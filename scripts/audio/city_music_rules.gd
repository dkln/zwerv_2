extends RefCounted
## The logic of the music of the town (the rules layer of scripts/audio/city_music.gd, which
## is the behaviour: the players, the fades, the jingles; sound has no view and no layout):
## how loud the music is (softer while paused, softer still under a jingle), how much softer
## a loop plays by itself, the volume of a loop along its fade (equal power: the amplitudes
## follow a quarter sine and cosine, so the sum stays as loud and there is no dip halfway),
## and the steps of the fades. Plain sums, without players or the tree.
##   const CityMusicRules = preload("res://scripts/audio/city_music_rules.gd")

## The loop of the town itself.
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
## The shortest fade (seconds): a fade of nothing would divide by zero.
const SHORTEST_FADE := 0.05


# ------------------------------------------------------------------ the levels

## The level (dB) the music goes to: softer while the game is paused (unless `loud_paused`:
## the shop) and softer still while a jingle plays over it, so the jingle is heard.
static func level_target(paused: bool, loud_paused: bool, jingles_playing: int) -> float:
	var level := PAUSED_DB if paused and not loud_paused else VOLUME_DB
	return level - (JINGLE_DUCK_DB if jingles_playing > 0 else 0.0)


## The level (dB) `delta` s later, on its way from `level_db` to `target_db` at LEVEL_SPEED.
static func next_level_db(level_db: float, target_db: float, delta: float) -> float:
	return move_toward(level_db, target_db, LEVEL_SPEED * delta)


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


## The pitch of the music while every sound plays at `playback_speed_scale` (slow motion
## slows every sound down, but not the music).
static func music_pitch(playback_speed_scale: float) -> float:
	return 1.0 / maxf(playback_speed_scale, 0.01)


## How many jingles hold the music down after one more starts (`ducked`) or ends; never
## below zero.
static func jingles_after(jingles_playing: int, ducked: bool) -> int:
	return maxi(jingles_playing + (1 if ducked else -1), 0)


# ------------------------------------------------------------------ the fades

## The seconds a fade asked to take `seconds` really takes (never shorter than SHORTEST_FADE).
static func fade_seconds(seconds: float) -> float:
	return maxf(seconds, SHORTEST_FADE)


## Where a loop is along its fade `delta` s later: towards 1 when it is the one fading in
## (`fading_in`), else towards 0, the whole way in `fade` s.
static func next_weight(weight: float, fading_in: bool, delta: float, fade: float) -> float:
	return move_toward(weight, 1.0 if fading_in else 0.0, delta / fade)


## Whether a loop at `weight` has faded out and can go (never the one fading in).
static func is_faded_out(weight: float, fading_in: bool) -> bool:
	return weight <= 0.0 and not fading_in


## The loudest of the loops that play: `weights` is file -> 0..1, `playing` the files whose
## player plays, in their order (the first of equals wins); "" when none plays.
static func loudest_loop(weights: Dictionary, playing: Array) -> String:
	var loudest_file := ""
	var loudest := -1.0
	for file: String in playing:
		var weight := float(weights.get(file, 0.0))
		if weight > loudest:
			loudest = weight
			loudest_file = file
	return loudest_file


## Where a new loop of `length` s starts so it is at the same point in the bar as a loop
## that is at `position` s (they all share one length).
static func start_position(position: float, length: float) -> float:
	return fmod(position, maxf(length, 0.01))
