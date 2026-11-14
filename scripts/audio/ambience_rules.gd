extends RefCounted
## The logic of the background sound of a place (the rules layer of scripts/audio/ambience.gd,
## which is the behaviour: the players and the crossfade; sound has no view and no layout):
## which loop belongs to which place, how loud it plays, what its player is called and where
## in the loop it starts. Plain data and sums, without players or the tree.
##   const AmbienceRules = preload("res://scripts/audio/ambience_rules.gd")

const FOLDER := "res://assets/audio/omgeving/"
## Per place: its loop and how loud it plays (dB: soft, the sounds of the game over it).
const PLACES := {
	"straat": {"file": "straat_loop.ogg", "volume_db": -16.0},
	"station": {"file": "station_loop.ogg", "volume_db": -13.0},
	"winkel": {"file": "winkel_loop.ogg", "volume_db": -15.0},
}
const FADE_SECONDS := 2.0
const SILENT_DB := -60.0
## What the player of a place is called: this and the place.
const PLAYER_PREFIX := "Omgeving_"


## Whether `place` has a sound of its own ("" and places nobody knows have none).
static func has_sound(place: String) -> bool:
	return file_of(place) != ""


## The file of the loop of `place` (in FOLDER); "" for a place without a sound.
static func file_of(place: String) -> String:
	var settings: Dictionary = PLACES.get(place, {})
	return String(settings.get("file", ""))


## The path of the loop of `place`; "" for a place without a sound.
static func path_of(place: String) -> String:
	var file := file_of(place)
	return FOLDER + file if file != "" else ""


## How loud (dB) the loop of `place` plays once faded in; silent for a place without a sound.
static func volume_db_of(place: String) -> float:
	var settings: Dictionary = PLACES.get(place, {})
	return float(settings.get("volume_db", SILENT_DB))


## The name of the player of `place`.
static func player_name(place: String) -> String:
	return PLAYER_PREFIX + place


## Where (s) in a loop of `length` s it starts for a draw `share` (0..1): anywhere, so the
## same place never starts at the same murmur.
static func start_position(share: float, length: float) -> float:
	return share * length
