extends RefCounted
## Types a text out word by word into a RichTextLabel, as the text boxes of 16-bit console
## games: a word every WORD_SECONDS (a longer rest after a sentence or a comma), a block cursor
## right after the last word that appeared, and (if `sound`) the text blip (UiSounds "tekst")
## with each word, a little higher or lower each time. The words still to come are already laid out
## (drawn transparent), so nothing jumps to another line as the text grows. Shared by the
## story box (story_box.gd) and the speech balloons (speech_balloon.gd).
##   const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")
##   var typewriter := Typewriter.new(label, self)
##   typewriter.start("Hoi!")
##   ...in _process: typewriter.update(delta)
## When it is all there the cursor blinks (`blink_when_done`) or goes (false). `show_cursor`
## and `sound` off: no cursor and no blips (the speech balloons; the story box has both).
## `follow_cursor`: a text taller than its label scrolls along by itself, so the line being
## typed stays in view (the label needs scroll_active; the character creation screen).
## Behaviour (docs/CODE_LAGEN.md): it keeps how far the text is and the clocks; when a word
## comes is typewriter_rules.gd, what it looks and sounds like typewriter_view.gd.

const TypewriterRules = preload("res://scripts/ui/widgets/typewriter_rules.gd")
const TypewriterView = preload("res://scripts/ui/widgets/typewriter_view.gd")
const WORD_SECONDS := TypewriterRules.WORD_SECONDS

## The label it types into.
var label: RichTextLabel:
	get:
		return view.label
var cursor_colour: Color:
	get:
		return view.cursor_colour
	set(value):
		view.cursor_colour = value
var blink_when_done := true
var sound := true
var show_cursor := true
var follow_cursor := false
## The pitch of the blips (higher for a higher voice).
var voice_pitch := 1.0
var text := ""
## Its picture and sound.
var view: TypewriterView

var _word_ends: Array[int] = []
var _words_shown := 0
var _word_clock := 0.0
var _blink_clock := 0.0
var _random := RandomNumberGenerator.new()
var _scroll := 0.0


func _init(text_label: RichTextLabel, sound_owner: Node) -> void:
	view = TypewriterView.new(text_label, sound_owner)
	_random.randomize()


## Starts typing `new_text` out from nothing.
func start(new_text: String) -> void:
	text = new_text
	_word_ends = TypewriterRules.word_ends_of(text)
	_words_shown = 0
	_word_clock = TypewriterRules.START_REST
	_blink_clock = 0.0
	_render()
	if follow_cursor:
		_scroll = 0.0
		view.show_scroll(0.0)


## The rest of the text at once.
func finish() -> void:
	_words_shown = _word_ends.size()
	_render()


## How much of the text has appeared (0..1, by characters).
func shown_share() -> float:
	return TypewriterRules.shown_share(_word_ends, _words_shown, text.length())


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
		_word_clock += TypewriterRules.rest_after(text.substr(_word_ends[_words_shown - 1] - 1, 1))
	if appeared and sound:
		view.play_blip(TypewriterRules.blip_pitch(voice_pitch, _random.randf_range(-1.0, 1.0)))
	_render()


## The words shown, the cursor right after them, and the rest transparent (laid out already).
func _render() -> void:
	view.show_text(text, TypewriterRules.shown_characters(_word_ends, _words_shown), show_cursor,
			TypewriterRules.is_cursor_on(show_cursor, is_done(), blink_when_done, _blink_clock))


## Scrolls smoothly down until the line with the last word shown is in view (never back up).
func _follow(delta: float) -> void:
	var target := view.scroll_target(TypewriterRules.shown_characters(_word_ends, _words_shown))
	if target > _scroll:
		# kept as a float of its own: the scroll bar rounds to whole pixels, and small steps
		# (a high frame rate) would never get there
		_scroll = TypewriterRules.followed(_scroll, target, delta)
		view.show_scroll(_scroll)
