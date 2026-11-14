extends RefCounted
## What the people of the town share, worked out (logic; docs/CODE_LAGEN.md): whose voice
## someone has by their look and what they ride, and how the cycle of their steps goes on.
## The node that holds who they are and their cycle: person.gd.
##   const PersonRules = preload("res://scripts/world/people/person_rules.gd")

## How fast the walk comes and goes, and the run blends in and out (per second).
const WALK_BLEND := 5.0
const RUN_BLEND := 4.0
## The voices there are (Babble.VOICES).
const VOICE_WOMAN := "vrouw"
const VOICE_OLD_MAN := "oude_man"
const VOICE_MAN := "man"


## The voice of someone with this `look` (TownsfolkFigure.look_for; empty without a figure)
## going about as `mobility` ("" on foot): a woman's with long hair or a skirt, an old man's
## when bald or riding a chair or a scooter, else a man's.
static func voice_of(look: Dictionary, mobility: String) -> String:
	if look.get("hair_style", "") == "lang" or look.get("skirt", false):
		return VOICE_WOMAN
	if mobility != "" or look.get("hair_style", "") == "kaal":
		return VOICE_OLD_MAN
	return VOICE_MAN


## The speed (m/s) of someone who went `moved` metres in `delta` seconds.
static func speed_of(moved: float, delta: float) -> float:
	return moved / maxf(delta, 0.0001)


## The phase of the steps (radians) after `moved` metres more in steps of `stride` metres.
static func phase_after(phase: float, moved: float, stride: float) -> float:
	return phase + moved / stride * PI


## How much someone walks (0..1) a moment later: towards 1 while moving, towards 0 standing.
static func walk_share_after(share: float, moving: bool, delta: float) -> float:
	return move_toward(share, 1.0 if moving else 0.0, delta * WALK_BLEND)


## How much someone runs (0..1) a moment later: towards `wanted`.
static func run_share_after(share: float, wanted: float, delta: float) -> float:
	return move_toward(share, wanted, delta * RUN_BLEND)
