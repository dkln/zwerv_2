extends CanvasLayer
## What an announcement over the loudspeakers shows and sounds like (graphics,
## docs/CODE_LAGEN.md): the line at the bottom of the screen (the node "Omroeptekst") whose
## words type out, and the sounds on the announcer's bus. It decides nothing: the node
## (announcer.gd) says which line, when it types on, and which sound plays.
##   const AnnouncerView = preload("res://scripts/world/interiors/announcer_view.gd")

const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

const SUBTITLE_COLOUR := Color("#FFE9B8")
const SUBTITLE_LAYER := 4
const NODE_NAME := "Omroeptekst"

var _subtitle: RichTextLabel
var _typewriter: Typewriter


func _init() -> void:
	name = NODE_NAME
	layer = SUBTITLE_LAYER
	visible = false
	_subtitle = RichTextLabel.new()
	_subtitle.add_theme_font_override("normal_font", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	_subtitle.add_theme_font_size_override("normal_font_size", UiStyle.ANNOUNCEMENT_FONT_SIZE)
	_subtitle.add_theme_color_override("default_color", SUBTITLE_COLOUR)
	UiStyle.faux_3d(_subtitle, 4)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.scroll_active = false
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.anchor_left = 0.08
	_subtitle.anchor_right = 0.92
	_subtitle.anchor_top = 0.74
	_subtitle.anchor_bottom = 0.95
	add_child(_subtitle)
	_typewriter = Typewriter.new(_subtitle, self)
	_typewriter.sound = false


## Starts typing out `text`; `on_screen`: whether the line is shown while it does.
func show_line(text: String, on_screen: bool) -> void:
	_typewriter.start(text)
	visible = on_screen


## The words `delta` seconds further.
func type_on(delta: float) -> void:
	_typewriter.update(delta)


## The whole line at once.
func show_whole_line() -> void:
	_typewriter.finish()


## The line off the screen.
func hide_line() -> void:
	visible = false


## The text on the screen now.
func shown_text() -> String:
	return _subtitle.text


## Whether every word of the line is there.
func is_typed_out() -> bool:
	return _typewriter.is_done()


## Whether the line is on the screen, still typing out.
func is_typing() -> bool:
	return visible and not _typewriter.is_done()


## Plays `stream` once on `bus` (the loudspeakers) at `volume_db`; the player frees itself
## when it is over. Null without a stream or outside the tree.
func play_sound(stream: AudioStream, volume_db: float, bus: String) -> AudioStreamPlayer:
	if stream == null or not is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
