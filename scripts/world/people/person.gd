extends Node3D
## Anyone in the town: what the three kinds of people share. Each kind extends this and says
## which it is (actor_kind), so it is clear who behaves how:
## - ACTOR_STREET, Pedestrian (scripts/world/people/pedestrian.gd): walks the pavements of the town
##   to a place a few blocks off, crosses at the zebras and waits for the lights, steps aside,
##   can be run over, rides a wheelchair or a mobility scooter, goes into the station;
## - ACTOR_INTERIOR, InteriorPerson (scripts/world/interiors/interior_person.gd): has a place inside
##   (behind the counter, at a table, at a till) and stays there; who sells is a merchant
##   (the shop screen); who works there can warn the player and come to put them out
##   (Eviction), walking over the floor of the room and back to their place;
## - ACTOR_STATION, StationPerson (scripts/world/station/station_person.gd): walks the routes of Den
##   Haag Centraal step by step (through the gates, to a train, a round of the staff), can
##   fall off a platform and climb back, chases a fare dodger (the conductor).
## Shared here: who they are (`role`, `mobility`, their `figure`, whether they sit), their
## voice (voice), being talked to (TALKABLE_GROUP, set_talkable), standing still for a
## conversation (stand_neutral) and the cycle of their steps (walk_cycle: the walk and, at
## speed, the run of the player, TownsfolkFigure.walk).
## The things the player can use with [E] are not people: see scripts/world/things/interactable.gd.

## Everyone the player can talk to: PlayerController looks in it ("[E] Praten").
const TALKABLE_GROUP := "aanspreekbaar"
const ACTOR_STREET := "straat"
const ACTOR_INTERIOR := "binnen"
const ACTOR_STATION := "station"
## How fast the walk comes and goes, and the run blends in and out (per second).
const WALK_BLEND := 5.0
const RUN_BLEND := 4.0

## What they are there (a kind of the crowd on duty, "snackbarhouder", "conducteur", ...).
var role := ""
## "" walking, "rolstoel" in a wheelchair, "scootmobiel" on a mobility scooter (MobilityAid).
@export var mobility := ""
var figure: TownsfolkFigure
var sitting := false
## The cycle of their steps (walk_cycle): where in it, how much they walk and run (0..1).
var _step_phase := 0.0
var _walk_share := 0.0
var _run_share_now := 0.0


## Which kind of person this is (ACTOR_STREET, ACTOR_INTERIOR, ACTOR_STATION).
func actor_kind() -> String:
	return ""


## The meta with someone's own voice (voice()).
const VOICE_META := "stem"


## The voice of their cries and their babble (Babble.VOICES): their own (the meta VOICE_META, a
## character of the story with a "stem": Characters), else by their look; who rides a
## chair or a scooter sounds old.
func voice() -> String:
	if has_meta(VOICE_META):
		return str(get_meta(VOICE_META))
	var look: Dictionary = figure.look if figure else {}
	if look.get("hair_style", "") == "lang" or look.get("skirt", false):
		return "vrouw"
	if mobility != "" or look.get("hair_style", "") == "kaal":
		return "oude_man"
	return "man"


## Whether the player can talk to them ("[E] Praten").
func set_talkable(on: bool) -> void:
	if on and not is_in_group(TALKABLE_GROUP):
		add_to_group(TALKABLE_GROUP)
	elif not on and is_in_group(TALKABLE_GROUP):
		remove_from_group(TALKABLE_GROUP)


func is_talkable() -> bool:
	return is_in_group(TALKABLE_GROUP)


## Standing still and straight at once, as when the player starts talking to them
## (PlayerController.talk_to): the conversation pauses the game, so mid-stride a leg would
## stay in the air. Who sits stays as they sit.
func stand_neutral() -> void:
	_step_phase = 0.0
	_walk_share = 0.0
	_run_share_now = 0.0
	if figure and not sitting:
		figure.walk(0.0, 0.0)


## Their legs and arms after `moved` metres in `delta` seconds: the walk coming and going,
## the run of the player blended in at speed (TownsfolkFigure.run_share); the steps as long
## as that asks (stride_at).
func walk_cycle(moved: float, delta: float) -> void:
	if figure == null:
		return
	var run_wanted := TownsfolkFigure.run_share(moved / maxf(delta, 0.0001)) if moved > 0.0 else 0.0
	_run_share_now = move_toward(_run_share_now, run_wanted, delta * RUN_BLEND)
	if moved > 0.0:
		_step_phase += moved / TownsfolkFigure.stride_at(_run_share_now) * PI
		_walk_share = move_toward(_walk_share, 1.0, delta * WALK_BLEND)
	else:
		_walk_share = move_toward(_walk_share, 0.0, delta * WALK_BLEND)
	figure.walk(_step_phase, _walk_share, _run_share_now)
