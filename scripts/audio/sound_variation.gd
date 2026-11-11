extends RefCounted
## A little random pitch for every sound effect, so the same sound never sounds quite the same
## twice (a door chime, a beep, a horn, a cry): each time it plays it is up to SPREAD higher or
## lower (pitch_scale 1 +- SPREAD; 0.06 is about a semitone). The interface blips vary less
## (UI_SPREAD: a menu should still sound like itself), an engine or a loop gets one pitch of
## its own when it starts (LOOP_SPREAD: every car a slightly different engine). Music, the
## background loops of a place and the babble (which varies already) are left alone.
##   const SoundVariation = preload("res://scripts/audio/sound_variation.gd")
##   player.pitch_scale = SoundVariation.pitch()

const SPREAD := 0.06
const UI_SPREAD := 0.03
const LOOP_SPREAD := 0.05


## A pitch_scale round 1, at most `spread` off.
static func pitch(spread := SPREAD) -> float:
	return 1.0 + randf_range(-spread, spread)
