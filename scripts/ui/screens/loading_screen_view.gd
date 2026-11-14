extends Control
## How the loading screen looks (the graphics layer of scripts/ui/loading_screen.gd, which
## is the behaviour and has this as its child; loading_screen_rules.gd has the logic,
## loading_screen_layout.gd the sizes): full-screen ink blue in the style of the HUD, the
## title, the line with what is loading and a segmented bar with the percentage on a
## bordered panel, under the CRT look. It shows what it is handed (show_progress) and fades
## away (fade_out); it decides nothing.
##   const LoadingScreenView = preload("res://scripts/ui/screens/loading_screen_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const LoadingScreenLayout = preload("res://scripts/ui/screens/loading_screen_layout.gd")
## Seconds of the fade when it is done.
const FADE_SECONDS := 0.35
## The CRT look without a HUD to take it from: how far the picture bulges and its corners.
const CRT_CURVATURE := 0.05
const CRT_CORNER := 0.035
const TITLE_FONT_SIZE := 56
const TEXT_FONT_SIZE := 14
## How much lighter than the ink the empty segments of the bar are.
const EMPTY_LIGHTER := 0.08

## The ink behind everything, the bar, the percentage beside it and the CRT look over it.
var panel: ColorRect
var bar: SegmentBar
var percentage: Label
var crt: ColorRect
var _title: Label
var _heading: Label


## `title` big, `heading` (what is loading) under it; the CRT look bulging `curvature` with
## corners of `corner`, for a screen of `screen_size`.
func _init(title := "", heading := "", curvature := CRT_CURVATURE, corner := CRT_CORNER, screen_size := Vector2.ZERO) -> void:
	name = "Beeld"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	panel = ColorRect.new()
	panel.color = UiStyle.INK
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", LoadingScreenLayout.COLUMN_SEPARATION)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_child(column)
	_title = _label(title, UiStyle.FONT_TITLE, TITLE_FONT_SIZE, UiStyle.TEXT, 4)
	column.add_child(_title)
	_heading = _label(heading, UiStyle.FONT_PIXEL, TEXT_FONT_SIZE, UiStyle.ACCENT, 2)
	column.add_child(_heading)
	column.add_child(_bar_box())
	crt = UiStyle.make_crt_overlay(curvature, corner, screen_size)
	add_child(crt)


## Fills the bar for `fill` (0..1) and writes `percentage_text` beside it.
func show_progress(fill: float, percentage_text: String) -> void:
	percentage.text = percentage_text
	bar.fill = fill


## Fades the screen and its CRT look out in FADE_SECONDS; the tween it runs on (chain what
## must happen after it).
func fade_out() -> Tween:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_SECONDS)
	var crt_material := crt.material as ShaderMaterial
	tween.tween_method(func(value: float) -> void: crt_material.set_shader_parameter("opacity", value), 1.0, 0.0, FADE_SECONDS)
	return tween


## What the big title says.
func title_text() -> String:
	return _title.text


## What the line with what is loading says.
func heading_text() -> String:
	return _heading.text


## The bar on a panel with a border, the percentage beside it.
func _bar_box() -> PanelContainer:
	var box := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, LoadingScreenLayout.BOX_BORDER)
	style.set_content_margin_all(LoadingScreenLayout.BOX_MARGIN)
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", LoadingScreenLayout.ROW_SEPARATION)
	box.add_child(row)
	bar = SegmentBar.new()
	bar.segments = LoadingScreenLayout.SEGMENTS
	bar.segment_height = LoadingScreenLayout.SEGMENT_HEIGHT
	bar.full_colour = UiStyle.ACCENT
	bar.empty_colour = UiStyle.INK.lightened(EMPTY_LIGHTER)
	bar.fill = 0.0
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	percentage = _label("0%", UiStyle.FONT_PIXEL, TEXT_FONT_SIZE, UiStyle.TEXT, 2)
	percentage.custom_minimum_size = LoadingScreenLayout.PERCENTAGE_SIZE
	percentage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(percentage)
	return box


## A label of the loading screen: this font, size and colour, with the hard ink text
## shadow of the HUD (`shadow` pixels).
static func _label(label_text: String, font_path: String, font_size: int, colour: Color, shadow: int) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiStyle.font(font_path))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if shadow > 0:
		UiStyle.faux_3d(label, shadow)
	return label
