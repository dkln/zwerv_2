extends RefCounted
## The look the machines share (appearance only, used by the graphics layer of the close-up
## of a machine: machine_screen_view.gd and its parts machine_display_view.gd and
## machine_info_view.gd): the colour of each tone a text can have (the tones are named in
## machine_screen_rules.gd TONE_*; the machine's own screen colour is the tone "") and a
## label as the machines write one. No decisions, no sizes.
##   const MachineLook = preload("res://scripts/ui/machines/machine_look.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")

const WARNING := Color("#FF5D73")
const GOOD := Color("#3CE06A")
const REFUSED := Color("#FFB547")
const PAPER := Color("#F2F2EC")
## Tone -> colour; a tone that is not here has the colour of its place (tone_colour).
const TONES := {
	"tekst": UiStyle.TEXT,
	"accent": UiStyle.ACCENT,
	"gedempt": UiStyle.MUTED,
	"goed": GOOD,
	"waarschuwing": WARNING,
	"geweigerd": REFUSED,
	"papier": PAPER,
}


## The colour of `tone`; `otherwise` for a tone without one of its own (the tone "": the
## machine's screen colour on its screen, plain text in the panel).
static func tone_colour(tone: String, otherwise: Color) -> Color:
	return TONES.get(tone, otherwise)


## A line of text as the machines write it: this font, size and colour, wrapping on words,
## deaf to the mouse.
static func label(text: String, font: Font, font_size: int, colour := UiStyle.TEXT) -> Label:
	var made := UiStyle.label(text, font, font_size, colour)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return made
