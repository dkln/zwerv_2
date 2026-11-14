extends Control
## What a speech balloon looks like (graphics; docs/CODE_LAGEN.md): an ink panel with a
## border in the speaker's colour, the text in the pixel font, a tail pointing down at the
## speaker; the balloon (not its text) with the faux 3D of the game's texts
## (UiStyle.faux_3d): a darker copy straight under it, in the border's colour half as light.
## Its origin is the tip of the tail. It shows what speech_balloon.gd hands it; its sizes
## come from speech_balloon_layout.gd.
##   const SpeechBalloonView = preload("res://scripts/ui/widgets/speech_balloon_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const SpeechBalloonLayout = preload("res://scripts/ui/widgets/speech_balloon_layout.gd")

var _panel: PanelContainer
var _tail: Control
var _text: RichTextLabel
var _accent := UiStyle.ACCENT


func _init() -> void:
	name = "Beeld"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	_text.add_theme_font_size_override("normal_font_size", SpeechBalloonLayout.TEXT_SIZE)
	_text.add_theme_color_override("default_color", UiStyle.TEXT)
	_text.add_theme_constant_override("line_separation", SpeechBalloonLayout.LINE_SEPARATION)
	# the text plain (only the balloon has the faux 3D)
	_text.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_text)
	# the tail over the panel: its fill covers the panel's bottom border where they meet, so
	# panel and tail are one shape with one outline
	_tail = Control.new()
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.draw.connect(_draw_tail)
	add_child(_tail)


## Makes the balloon ready for `line`, with its border and tail in `accent`: as wide as the
## whole line needs and as high as the whole line wrapped at that width, so a long line (a
## warning) does not stretch the balloon while its words type out.
func show_line(line: String, accent: Color) -> void:
	_accent = accent
	var style := UiStyle.box_style(UiStyle.PANEL, accent, SpeechBalloonLayout.BORDER_WIDTH)
	style.content_margin_left = SpeechBalloonLayout.PADDING.x
	style.content_margin_right = SpeechBalloonLayout.PADDING.x
	style.content_margin_top = SpeechBalloonLayout.PADDING.y
	style.content_margin_bottom = SpeechBalloonLayout.PADDING.y
	_panel.add_theme_stylebox_override("panel", style)
	var font := UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	var line_width := font.get_string_size(line + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, SpeechBalloonLayout.TEXT_SIZE).x
	_text.custom_minimum_size.x = SpeechBalloonLayout.text_width(line_width)
	_text.custom_minimum_size.y = text_height(line, _text.custom_minimum_size.x)


## The panel back to the size its text asks (after the text is put in it).
func settle() -> void:
	_panel.reset_size()


## Puts the panel above the tip, in the middle, and draws the balloon anew.
func place_panel() -> void:
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = SpeechBalloonLayout.panel_position(panel_size)
	queue_redraw()
	_tail.queue_redraw()


## The label the line is typed into.
func text_label() -> RichTextLabel:
	return _text


## The panel round the text.
func panel() -> PanelContainer:
	return _panel


## The colour of the border and the tail now.
func accent() -> Color:
	return _accent


## How high `line` stands in the balloon's text when wrapped at `width` px: its rows of the
## font with the line separation between them.
static func text_height(line: String, width: float) -> float:
	var font := UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	var wrapped := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, width, SpeechBalloonLayout.TEXT_SIZE, -1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	return SpeechBalloonLayout.rows_height(wrapped.y, font.get_height(SpeechBalloonLayout.TEXT_SIZE))


## The faux 3D of the balloon, drawn under the panel and the tail (this node draws before its
## children): the panel's rectangle and the tail's shape with its border, a few px lower, in
## the border's colour half as light.
func _draw() -> void:
	draw_rect(SpeechBalloonLayout.panel_shadow(_panel.position, _panel.size), UiStyle.faux_3d_colour(_accent))
	draw_colored_polygon(SpeechBalloonLayout.tail_shadow(), UiStyle.faux_3d_colour(_accent))


## The tail, over the panel, pixel-hard: the outline in the accent, the fill in the panel's
## colour.
func _draw_tail() -> void:
	_tail.draw_colored_polygon(SpeechBalloonLayout.tail_outline(), _accent)
	_tail.draw_colored_polygon(SpeechBalloonLayout.tail_fill(), UiStyle.PANEL)
