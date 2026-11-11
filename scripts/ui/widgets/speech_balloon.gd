extends Control
## A speech balloon: a short spoken line or a shout of someone, over their head, typed out
## like the story box (Typewriter: word by word), but without its cursor and silent: the
## shout itself is what you hear, the words come without blips.
## An ink panel with a border in the speaker's colour, the text in the pixel font, a tail
## pointing down at the speaker; the balloon (not its text) with the faux 3D of the game's
## texts (UiStyle.faux_3d): a darker copy straight under it, in the border's colour half as
## light, BALLOON_DEPTH px lower. It pops up, types, holds `hold` seconds
## once it is all there, then fades; `finished` fires when it is gone.
## Where: the node's position is the tip of the tail (the balloon stands above it).
## - In the UI (the character creation screen): set `position` yourself.
## - In the world (shouts on the street): follow(node, camera) keeps the tip over a Node3D
##   (`head_height` m above its origin), hidden while that point is behind the camera; put
##   the balloon on a CanvasLayer (the HUD).
##   var balloon := SpeechBalloon.new()
##   hud_layer.add_child(balloon)
##   balloon.follow(passer_by, camera)
##   balloon.say("Hé, zwerver!")

signal finished

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const Typewriter = preload("res://scripts/ui/widgets/typewriter.gd")

## The widest the text runs before it wraps (px), the font size, the padding.
const MAX_TEXT_WIDTH := 320.0
const TEXT_SIZE := 18
const PADDING := Vector2(12, 8)
## How far the darker copy under the balloon sits lower (px).
const BALLOON_DEPTH := 4
## The tail: how high and how wide at the panel.
const TAIL_HEIGHT := 12.0
const TAIL_WIDTH := 14.0
const BORDER_WIDTH := 2
const POP_SECONDS := 0.14
const FADE_SECONDS := 0.3

## The colour of the border and the tail (whose balloon it is).
var accent := UiStyle.ACCENT
var head_height := 2.4

var _panel: PanelContainer
var _tail: Control
var _text: RichTextLabel
var _typewriter: Typewriter
var _hold_left := 0.0
var _hold := 1.6
var _fading := false
var _follow_node: Node3D
var _camera: Camera3D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("normal_font", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	_text.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_text.add_theme_color_override("default_color", UiStyle.TEXT)
	_text.add_theme_constant_override("line_separation", 4)
	# the text plain (only the balloon has the faux 3D)
	_text.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_text)
	# the tail over the panel: its fill covers the panel's bottom border where they meet, so
	# panel and tail are one shape with one outline
	_tail = Control.new()
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.draw.connect(_draw_tail)
	add_child(_tail)
	_typewriter = Typewriter.new(_text, self)
	# the shout itself is heard; the words come silently and without a cursor
	_typewriter.sound = false
	_typewriter.show_cursor = false


## Types `line` out and keeps it `hold` seconds once it is all there; a new line replaces the
## one under way.
func say(line: String, hold := 1.6) -> void:
	_hold = hold
	_hold_left = hold
	_fading = false
	var style := UiStyle.box_style(UiStyle.PANEL, accent, BORDER_WIDTH)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	# the faux 3D: a darker copy of the balloon (in the border's colour) straight under it
	style.shadow_color = UiStyle.faux_3d_colour(accent)
	style.shadow_offset = Vector2(0, BALLOON_DEPTH)
	_panel.add_theme_stylebox_override("panel", style)
	# as wide as the whole line needs (up to MAX_TEXT_WIDTH), so it does not grow while typing
	var font := UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	var line_width := font.get_string_size(line + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	_text.custom_minimum_size.x = minf(ceilf(line_width) + 2.0, MAX_TEXT_WIDTH)
	_typewriter.start(line)
	_panel.reset_size()
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE * 0.6
	pivot_offset = Vector2.ZERO
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, POP_SECONDS)
	_place()


## Keeps the balloon over `node` (head_height m up), seen through `camera`.
func follow(node: Node3D, camera: Camera3D) -> void:
	_follow_node = node
	_camera = camera


func is_talking() -> bool:
	return visible and not _fading


func _process(delta: float) -> void:
	if not visible:
		return
	_typewriter.update(delta)
	_place()
	if _fading:
		return
	if _typewriter.is_done():
		_hold_left -= delta
		if _hold_left <= 0.0:
			_fading = true
			var fade := create_tween()
			fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
			fade.tween_callback(func() -> void:
				visible = false
				finished.emit())


## The panel above the tip, in the middle; in the world the tip over the followed node.
func _place() -> void:
	if _follow_node and _camera:
		if not is_instance_valid(_follow_node):
			_follow_node = null
			visible = false
			return
		var head := _follow_node.global_position + Vector3.UP * head_height
		if _camera.is_position_behind(head):
			modulate.a = 0.0
			return
		position = _camera.unproject_position(head).round()
	var panel_size := _panel.get_combined_minimum_size()
	_panel.size = panel_size
	_panel.position = Vector2(-roundf(panel_size.x * 0.5), -panel_size.y - TAIL_HEIGHT + BORDER_WIDTH)
	queue_redraw()
	_tail.queue_redraw()


## The faux 3D of the tail, under the panel (the panel's own is its stylebox's shadow): the
## tail's shape with its border, BALLOON_DEPTH px lower, in the darker colour.
func _draw() -> void:
	var half := TAIL_WIDTH * 0.5 + BORDER_WIDTH
	var depth := Vector2(0, BALLOON_DEPTH)
	draw_colored_polygon(PackedVector2Array([Vector2(-half, -TAIL_HEIGHT) + depth, Vector2(half, -TAIL_HEIGHT) + depth,
			Vector2(0, BORDER_WIDTH) + depth]), UiStyle.faux_3d_colour(accent))


## The tail, over the panel, pixel-hard: the outline in the accent from the panel's bottom
## border down to the tip, and the fill in the panel's colour from a pixel inside the panel
## (so the bottom border is gone where the tail joins) down to just above the tip.
func _draw_tail() -> void:
	var half := TAIL_WIDTH * 0.5
	var top := -TAIL_HEIGHT
	_tail.draw_colored_polygon(PackedVector2Array([Vector2(-half - BORDER_WIDTH, top), Vector2(half + BORDER_WIDTH, top), Vector2(0, BORDER_WIDTH)]), accent)
	_tail.draw_colored_polygon(PackedVector2Array([Vector2(-half, top - 1.0), Vector2(half, top - 1.0), Vector2(0, -BORDER_WIDTH)]), UiStyle.PANEL)
