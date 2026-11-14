extends RefCounted
## The logic of music running into the next piece (the rules layer of
## scripts/audio/music_fade.gd, which is the behaviour: the players and the tweens; sound has
## no view and no layout): the volume of the piece coming in and of the piece going out along
## their fade. Equal power: the amplitudes follow a quarter sine and a quarter cosine, so the
## two together stay as loud and there is no dip and no bump halfway. Plain sums.
##   const MusicFadeRules = preload("res://scripts/audio/music_fade_rules.gd")

## The seconds of a crossfade: what goes out and what comes in take as long, so they meet.
const SECONDS := 1.6
const SILENT_DB := -80.0
## The softest amplitude of a fade (the dB of nothing is minus infinity).
const QUIETEST := 0.00001


## The volume (dB) of a piece fading in to `volume_db`, `share` (0..1) along its fade.
static func fade_in_db(volume_db: float, share: float) -> float:
	return linear_to_db(maxf(db_to_linear(volume_db) * sin(share * PI * 0.5), QUIETEST))


## The volume (dB) of a piece fading out from `from_db`, `share` (0..1) along its fade.
static func fade_out_db(from_db: float, share: float) -> float:
	return linear_to_db(maxf(db_to_linear(from_db) * cos(share * PI * 0.5), QUIETEST))
