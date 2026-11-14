extends RefCounted
## The logic of the babble (the rules layer of scripts/audio/babble.gd, which is the
## behaviour: the random draws, what was played last and the players; sound has no view and
## no layout): which voices and moods there are and what an unknown one becomes, which
## variant plays for a draw given the ones played last, what its sound is called, its pitch,
## and which word of a line a sound is for. Plain data and sums, without draws of its own.
##   const BabbleRules = preload("res://scripts/audio/babble_rules.gd")

const VOICES := ["man", "oude_man", "vrouw"]
## Voices of one person only (a character's "stem", data/gesprekken/personages.json): never handed
## out to anyone else (DriverShout.voice_of picks from VOICES).
const OWN_VOICES := ["rasperig"]
const MOODS := ["neutraal", "blij", "opgewonden", "boos", "verdrietig", "vraag"]
## What an unknown voice and an unknown mood become.
const FALLBACK_VOICE := "man"
const FALLBACK_MOOD := "neutraal"
const VARIANTS := 32
## How many of the last variants of a voice and mood are not played again yet.
const RECENT := 6
## How loud the babble is in the UI (dB) and how far the pitch of a word lies from 1 at most
## (share, random for every word).
const UI_DB := -7.0
const PITCH_SPREAD := 0.1
## How near (m) a shout in the world is at full loudness.
const SHOUT_UNIT := 7.0


## The voice that speaks for `voice`: itself when it is one, else FALLBACK_VOICE.
static func voice_name(voice: String) -> String:
	return voice if voice in VOICES or voice in OWN_VOICES else FALLBACK_VOICE


## The mood that sounds for `mood`: itself when it is one, else FALLBACK_MOOD.
static func mood_name(mood: String) -> String:
	return mood if mood in MOODS else FALLBACK_MOOD


## Under what the last variants of a voice and a mood are remembered.
static func recent_key(voice: String, mood: String) -> String:
	return voice_name(voice) + "/" + mood_name(mood)


## The variant (1..VARIANTS) that plays for the draw `drawn`: itself, or the first one after
## it (round to 1 after the last) that is not among `recent`.
static func free_variant(drawn: int, recent: Array) -> int:
	var variant := drawn
	while variant in recent:
		variant = variant % VARIANTS + 1
	return variant


## The variants played last once `variant` has played: `recent` with it at the end, the
## oldest gone when there are more than RECENT. `recent` itself is left as it was.
static func recent_after(recent: Array, variant: int) -> Array:
	var after := recent.duplicate()
	after.append(variant)
	if after.size() > RECENT:
		after.pop_front()
	return after


## The sound name of variant `variant` of `voice` in `mood`: brabbel_<voice>_<mood>_<n>.
static func name_of(voice: String, mood: String, variant: int) -> String:
	return "brabbel_%s_%s_%d" % [voice_name(voice), mood_name(mood), variant]


## The pitch a sound plays at for the draw `offset` (within PITCH_SPREAD either way): 1 and that.
static func pitch_of(offset: float) -> float:
	return 1.0 + clampf(offset, -PITCH_SPREAD, PITCH_SPREAD)


## The word of `text` that the sound number `index` (0: the first) of its line is: its nth
## word, the last ones again when the line has fewer; "" for a text without words.
static func word_at(text: String, index: int) -> String:
	var words := text.split(" ", false)
	return words[mini(index, words.size() - 1)] if words.size() > 0 else ""
