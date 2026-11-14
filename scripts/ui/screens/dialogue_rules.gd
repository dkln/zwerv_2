extends RefCounted
## The logic the story box and the shop screen share (rules; docs/CODE_LAGEN.md): the
## babble of someone whose line types out (which mood a sound gets, when a question still
## rises at its end), and the blinking arrows of a list that scrolls. Plain functions,
## without nodes; the behaviours (scripts/ui/story_box.gd, scripts/ui/shop_screen.gd) hand
## in what the typewriter and the scroll say.
##   const DialogueRules = preload("res://scripts/ui/screens/dialogue_rules.gd")

## The mood of the babble of a question as it ends: the voice goes up.
const QUESTION_MOOD := "vraag"
## The mood of a line that names none.
const DEFAULT_MOOD := "neutraal"
## A question rises over its last words: this many still to come, or fewer.
const QUESTION_WORDS := 2
## The arrows and the ▼ blink: on for BLINK_ON of every BLINK_SECONDS.
const BLINK_SECONDS := 0.8
const BLINK_ON := 0.5
## A list scrolls when it is more than this (pixels) taller than its window, and an arrow
## shows when it is more than this from that end.
const SCROLL_SLACK := 1.0


## Whether `line` is a question (it ends in "?"): its babble goes up at the end.
static func is_question(line: String) -> bool:
	return line.strip_edges().ends_with("?")


## The mood of the next sound of a line that is still typing out: that of the line
## (`line_mood`), or for a question with `words_left` words to come the rising one.
static func typing_mood(question: bool, words_left: int, line_mood: String) -> String:
	return QUESTION_MOOD if question and words_left <= QUESTION_WORDS else line_mood


## Whether a line that has typed out still gets its rising sound: a question whose babble
## has not gone up yet (`asked_aloud`).
static func asks_after_typing(question: bool, asked_aloud: bool) -> bool:
	return question and not asked_aloud


## Whether what blinks is on now, `clock` seconds on its clock.
static func blink_on(clock: float) -> bool:
	return fmod(clock, BLINK_SECONDS) < BLINK_ON


## How far a list `content_height` high can scroll in a window `window_height` high (0 or
## less: it fits).
static func scroll_room(content_height: float, window_height: float) -> float:
	return content_height - window_height


## Whether the arrow down shows: there is more below (`room` to scroll, `scrolled` so far)
## and the blink is on.
static func more_below(room: float, scrolled: float, blink: bool) -> bool:
	return room > SCROLL_SLACK and scrolled < room - SCROLL_SLACK and blink


## Whether the arrow up shows: there is more above and the blink is on.
static func more_above(room: float, scrolled: float, blink: bool) -> bool:
	return room > SCROLL_SLACK and scrolled > SCROLL_SLACK and blink
