extends RefCounted
## The rules of the face in a portrait (logic; docs/CODE_LAGEN.md): how open the mouth of a
## townsperson is on each letter of what is said, when the eyes blink and how the figure
## breathes. Kept by player_portrait.gd.
##   const PlayerPortraitRules = preload("res://scripts/ui/widgets/player_portrait_rules.gd")

## The talking mouth: letters a second, and how open per kind of letter.
const MOUTH_LETTERS := 14.0
const WIDE_VOWELS := "aouáàóòúùäöü"
const SMALL_VOWELS := "eiyéèëïí"
const MOUTH_WIDE := 1.0
const MOUTH_HALF := 0.55
const MOUTH_LITTLE := 0.2
const MOUTH_SHUT := 0.0
## Seconds between blinks (fewest, most), until the first one, and how long the eyes stay shut.
const BLINK_EVERY := Vector2(2.2, 5.0)
const FIRST_BLINK := 3.0
const BLINK_SECONDS := 0.12
## Breathing: how much the figure rises (share of its height) and seconds a breath.
const BREATH_SHARE := 0.006
const BREATH_SECONDS := 3.4


## How open the mouth is on `letter` (0 shut .. 1 wide): wide on a, o, u, half on e, i, y, a
## little on any other letter, shut on a space, a digit or a sign.
static func mouth_opening(letter: String) -> float:
	letter = letter.to_lower()
	if WIDE_VOWELS.contains(letter):
		return MOUTH_WIDE
	if SMALL_VOWELS.contains(letter):
		return MOUTH_HALF
	if letter.to_upper() != letter.to_lower():   # another letter
		return MOUTH_LITTLE
	return MOUTH_SHUT


## Whether the mouth moves: someone is `speaking` and there is something said (`speech`).
static func is_talking(speaking: bool, speech: String) -> bool:
	return speaking and not speech.is_empty()


## The letter of `speech` (not empty) the mouth is at `clock` seconds into it: MOUTH_LETTERS
## a second, going round.
static func letter_at(speech: String, clock: float) -> String:
	return speech[int(clock * MOUTH_LETTERS) % speech.length()]


## How open the mouth is `clock` seconds into `speech` (not empty).
static func mouth_at(speech: String, clock: float) -> float:
	return mouth_opening(letter_at(speech, clock))


## Whether the eyes are shut `clock` seconds after the last blink, the next one due at `next`.
static func is_blinking(clock: float, next: float) -> bool:
	return clock >= next


## Whether the blink due at `next` is over `clock` seconds after the last one.
static func is_blink_over(clock: float, next: float) -> bool:
	return clock >= next + BLINK_SECONDS


## How much higher the figure stands `clock` seconds in (share of its height, up and down).
static func breath(clock: float) -> float:
	return sin(clock * TAU / BREATH_SECONDS) * BREATH_SHARE
