extends RefCounted
## Types a text out word by word into a RichTextLabel, as the text boxes of 16-bit console
## games: a word every WORD_SECONDS (a longer rest after a sentence or a comma), a block cursor
## right after the last word that appeared, and (if `sound`) the text blip (UiSounds "tekst")
## with each word, a little higher or lower each time. The words still to come are already laid out
## (drawn transparent), so nothing jumps to another line as the text grows. Shared by the
## story box (story_box.gd) and the speech balloons (speech_balloon.gd).
##   var typewriter := Typewriter.new(label, self)
##   typewriter.start("Hoi!")
##   ...in _process: typewriter.update(delta)
## When it is all there the cursor blinks (`blink_when_done`) or goes (false). `show_cursor`
## and `sound` off: no cursor and no blips (the speech balloons; the story box has both).
## `follow_cursor`: a text taller than its label scrolls along by itself, so the line being
## typed stays in view (the label needs scroll_active; the character creation screen).

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## Seconds between two words, and the extra rest after a sentence or a comma.
const WORD_SECONDS := 0.075
const SENTENCE_REST := 0.32
const COMMA_REST := 0.12
const BLINK_SECONDS := 0.8
## Between the last word and the cursor: two non-breaking spaces (they stay on the word's line).
const CURSOR_GAP := "\u00A0\u00A0"
## The blip: dB softer than the menu sounds, and how far its pitch wanders (share).
const BLIP_SOFTER_DB := -11.0
const BLIP_PITCH_SPREAD := 0.06
## How fast the text scrolls after the cursor (share of the distance left per second, about).
const FOLLOW_SPEED := 8.0
## ...but never slower than this (pixels per second), so it does arrive.
const FOLLOW_SLOWEST := 30.0

var label: RichTextLabel
var cursor_colour := UiStyle.ACCENT
var blink_when_done := true
var sound := true
var show_cursor := true
var follow_cursor := false
## The pitch of the blips (higher for a higher voice).
var voice_pitch := 1.0
var text := ""

var _sound_owner: Node
var _word_ends: Array[int] = []
var _words_shown := 0
var _word_clock := 0.0
var _blink_clock := 0.0
var _random := RandomNumberGenerator.new()
var _scroll := 0.0


func _init(text_label: RichTextLabel, sound_owner: Node) -> void:
	label = text_label
	label.bbcode_enabled = true
	_sound_owner = sound_owner
	_random.randomize()


## Starts typing `new_text` out from nothing.
func start(new_text: String) -> void:
	text = new_text
	_word_ends = word_ends_of(text)
	_words_shown = 0
	_word_clock = 0.15
	_blink_clock = 0.0
	_render()
	if follow_cursor:
		_scroll = 0.0
		label.get_v_scroll_bar().value = 0.0


## The rest of the text at once.
func finish() -> void:
	_words_shown = _word_ends.size()
	_render()


## How much of the text has appeared (0..1, by characters).
func shown_share() -> float:
	if _word_ends.is_empty() or text.is_empty():
		return 1.0
	if _words_shown <= 0:
		return 0.0
	return clampf(float(_word_ends[mini(_words_shown, _word_ends.size()) - 1]) / float(text.length()), 0.0, 1.0)


## How many words have not appeared yet.
func words_left() -> int:
	return _word_ends.size() - _words_shown


func is_done() -> bool:
	return _words_shown >= _word_ends.size()


## Call every frame.
func update(delta: float) -> void:
	_blink_clock += delta
	if follow_cursor:
		_follow(delta)
	if is_done():
		if blink_when_done:
			_render()
		return
	_word_clock -= delta
	var appeared := false
	while _word_clock <= 0.0 and _words_shown < _word_ends.size():
		_words_shown += 1
		appeared = true
		var last := text.substr(_word_ends[_words_shown - 1] - 1, 1)
		_word_clock += WORD_SECONDS + (SENTENCE_REST if last in [".", "!", "?", ":", "…"] else COMMA_REST if last in [",", ";"] else 0.0)
	if appeared and sound:
		UiSounds.play(_sound_owner, "tekst", BLIP_SOFTER_DB,
				voice_pitch * (1.0 + _random.randf_range(-BLIP_PITCH_SPREAD, BLIP_PITCH_SPREAD)))
	_render()


## The words shown, the cursor right after them, and the rest transparent (laid out already).
func _render() -> void:
	var shown := _word_ends[_words_shown - 1] if _words_shown > 0 else 0
	var cursor_on := show_cursor and (not is_done() or (blink_when_done and fmod(_blink_clock, BLINK_SECONDS) < BLINK_SECONDS * 0.6))
	# a space before the cursor (CURSOR_GAP), so it stands a little apart from the last word
	var cursor := CURSOR_GAP + ("[bgcolor=#%s]\u00A0[/bgcolor]" % cursor_colour.to_html(false) if cursor_on else "[color=#00000000]\u00A0[/color]")
	if not show_cursor:
		cursor = ""
	var rest := text.substr(shown)
	label.text = _escaped(text.substr(0, shown)) + cursor \
			+ ("[color=#00000000]%s[/color]" % _escaped(rest) if rest != "" else "")


## Scrolls smoothly down until the line with the last word shown is in view (never back up).
func _follow(delta: float) -> void:
	var shown := _word_ends[_words_shown - 1] if _words_shown > 0 else 0
	if shown <= 0:
		return
	var line := label.get_character_line(shown - 1)
	if line < 0:
		return
	var line_bottom := label.get_line_offset(line + 1) if line + 1 < label.get_line_count() \
			else float(label.get_content_height())
	var scroll_bar := label.get_v_scroll_bar()
	var target := clampf(line_bottom - label.size.y, 0.0, scroll_bar.max_value)
	if target > _scroll:
		# kept as a float of its own: the scroll bar rounds to whole pixels, and small steps
		# (a high frame rate) would never get there
		var step := maxf((target - _scroll) * FOLLOW_SPEED, FOLLOW_SLOWEST) * delta
		_scroll = minf(_scroll + step, target)
		scroll_bar.value = _scroll


static func _escaped(plain: String) -> String:
	return plain.replace("[", "[lb]")


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
