extends RefCounted
## What a text that types itself out looks and sounds like (graphics; docs/CODE_LAGEN.md):
## the words that have appeared, a block cursor right after them, the words still to come
## already laid out but transparent (so nothing jumps to another line as the text grows),
## the blip of a word and the scrolling of a text taller than its label. It shows what
## typewriter.gd hands it.
##   const TypewriterView = preload("res://scripts/ui/widgets/typewriter_view.gd")

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## Between the last word and the cursor: two non-breaking spaces (they stay on the word's line).
const CURSOR_GAP := "  "
## The blip: dB softer than the menu sounds.
const BLIP_SOFTER_DB := -11.0

var label: RichTextLabel
var cursor_colour := UiStyle.ACCENT

var _sound_owner: Node


func _init(text_label: RichTextLabel, sound_owner: Node) -> void:
	label = text_label
	label.bbcode_enabled = true
	_sound_owner = sound_owner


## Shows the first `shown` characters of `text`, the rest transparent. `with_cursor`: there
## is a cursor after them (it has its place, also while it is off); `cursor_on`: it is lit.
func show_text(text: String, shown: int, with_cursor: bool, cursor_on: bool) -> void:
	var rest := text.substr(shown)
	label.text = escaped(text.substr(0, shown)) + _cursor(with_cursor, cursor_on) \
			+ ("[color=#00000000]%s[/color]" % escaped(rest) if rest != "" else "")


## The blip of a word, at `pitch_scale`.
func play_blip(pitch_scale: float) -> void:
	UiSounds.play(_sound_owner, "tekst", BLIP_SOFTER_DB, pitch_scale)


## How far the text has to be scrolled (px) to have the line of character `shown` (the last
## one that appeared) in view; -1 when there is no such line (yet).
func scroll_target(shown: int) -> float:
	if shown <= 0:
		return -1.0
	var line := label.get_character_line(shown - 1)
	if line < 0:
		return -1.0
	var line_bottom := label.get_line_offset(line + 1) if line + 1 < label.get_line_count() \
			else float(label.get_content_height())
	return clampf(line_bottom - label.size.y, 0.0, label.get_v_scroll_bar().max_value)


## Scrolls the text to `scroll` px.
func show_scroll(scroll: float) -> void:
	label.get_v_scroll_bar().value = scroll


## `plain` as text for the label: what would be a tag is shown as it is.
static func escaped(plain: String) -> String:
	return plain.replace("[", "[lb]")


## The cursor: a space before it (CURSOR_GAP), so it stands a little apart from the last word.
func _cursor(with_cursor: bool, cursor_on: bool) -> String:
	if not with_cursor:
		return ""
	return CURSOR_GAP + ("[bgcolor=#%s] [/bgcolor]" % cursor_colour.to_html(false) if cursor_on else "[color=#00000000] [/color]")
