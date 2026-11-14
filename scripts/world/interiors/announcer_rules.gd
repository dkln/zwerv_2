extends RefCounted
## The rules of an announcement over the loudspeakers (logic, docs/CODE_LAGEN.md): which
## clip of the announcer's voice is played, whether the words wait for the end of the sound
## before them, and whether the voice talks on. The node: announcer.gd; the line on the
## screen and the sound: announcer_view.gd.
##   const AnnouncerRules = preload("res://scripts/world/interiors/announcer_rules.gd")


## The name (SoundFiles) of clip `clip_number` of the voice `voice`: its neutral babble.
static func clip_name(voice: String, clip_number: int) -> String:
	return "brabbel_%s_neutraal_%d" % [voice, clip_number]


## Whether the words wait until the sound before them is over (`intro_seconds` below 0),
## in place of a fixed time after its start.
static func waits_for_intro_end(intro_seconds: float) -> bool:
	return intro_seconds < 0.0


## Whether the voice starts another clip: there are clips left and the line is not typed out.
static func talks_on(clips_left: int, typed_out: bool) -> bool:
	return clips_left > 0 and not typed_out


## Whether the music goes up again after an announcement: nothing waits behind it.
static func music_back_up(waiting: int) -> bool:
	return waiting == 0
