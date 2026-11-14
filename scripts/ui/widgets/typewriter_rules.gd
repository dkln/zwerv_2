extends RefCounted
## The rules of a text that types itself out word by word (logic; docs/CODE_LAGEN.md): where
## its words end, how long the rest after a word is, how much of it has appeared, when the
## cursor shows and how the text scrolls after it. Kept by typewriter.gd.
##   const TypewriterRules = preload("res://scripts/ui/widgets/typewriter_rules.gd")

## Seconds before the first word, between two words, and the extra rest after a sentence or
## a comma.
const START_REST := 0.15
const WORD_SECONDS := 0.075
const SENTENCE_REST := 0.32
const COMMA_REST := 0.12
const SENTENCE_ENDS := [".", "!", "?", ":", "…"]
const COMMAS := [",", ";"]
## Seconds a blink of the cursor takes, and the share of it the cursor is on.
const BLINK_SECONDS := 0.8
const BLINK_ON_SHARE := 0.6
## How far the pitch of a blip wanders (share).
const BLIP_PITCH_SPREAD := 0.06
## How fast the text scrolls after the cursor (share of the distance left per second, about).
const FOLLOW_SPEED := 8.0
## ...but never slower than this (pixels per second), so it does arrive.
const FOLLOW_SLOWEST := 30.0


## The number of characters at the end of each word (spaces and line ends between).
static func word_ends_of(plain: String) -> Array[int]:
	var ends: Array[int] = []
	var in_word := false
	for index in plain.length():
		var is_space := plain[index] in [" ", "\n", "\t"]
		if in_word and is_space:
			ends.append(index)
		in_word = not is_space
	if in_word:
		ends.append(plain.length())
	return ends


## How many characters have appeared when `words_shown` of the words (`word_ends`) have.
static func shown_characters(word_ends: Array[int], words_shown: int) -> int:
	return word_ends[words_shown - 1] if words_shown > 0 else 0


## How much of a text of `length` characters has appeared (0..1, by characters) when
## `words_shown` of its words (`word_ends`) have; a text without words is all there.
static func shown_share(word_ends: Array[int], words_shown: int, length: int) -> float:
	if word_ends.is_empty() or length == 0:
		return 1.0
	if words_shown <= 0:
		return 0.0
	return clampf(float(word_ends[mini(words_shown, word_ends.size()) - 1]) / float(length), 0.0, 1.0)


## Seconds until the next word after a word that ends in `last_character`: WORD_SECONDS, and
## a rest after a sentence or a comma.
static func rest_after(last_character: String) -> float:
	if last_character in SENTENCE_ENDS:
		return WORD_SECONDS + SENTENCE_REST
	if last_character in COMMAS:
		return WORD_SECONDS + COMMA_REST
	return WORD_SECONDS


## Whether the cursor is lit: while typing always; when `done` it blinks (`blink_clock`
## seconds in) if `blink_when_done`, else it is off. Never without `show_cursor`.
static func is_cursor_on(show_cursor: bool, done: bool, blink_when_done: bool, blink_clock: float) -> bool:
	return show_cursor and (not done or (blink_when_done and fmod(blink_clock, BLINK_SECONDS) < BLINK_SECONDS * BLINK_ON_SHARE))


## The pitch of a blip of a voice at `voice_pitch`, wandering `wander` (-1..1) of
## BLIP_PITCH_SPREAD.
static func blip_pitch(voice_pitch: float, wander: float) -> float:
	return voice_pitch * (1.0 + wander * BLIP_PITCH_SPREAD)


## Where a text scrolled to `scroll` px is `delta` seconds later on its way down to `target`
## (never back up): fast when far, never slower than FOLLOW_SLOWEST.
static func followed(scroll: float, target: float, delta: float) -> float:
	if target <= scroll:
		return scroll
	var step := maxf((target - scroll) * FOLLOW_SPEED, FOLLOW_SLOWEST) * delta
	return minf(scroll + step, target)
