extends RefCounted
## On-screen caption panel (title + explanation, optionally a "3 / 40" counter) in the
## top-left corner. Shared by the tour (tour.gd) and tools/screenshots.gd so
## both show exactly the same caption.
##
## Usage: `var caption := Caption.new(parent)`, then set `caption.title.text` etc.

const FONT := "res://assets/fonts/Rubik.ttf"
## Width of the panel's text column in pixels.
const WIDTH := 620

## Root control of the caption; fade it with `panel.modulate.a`.
var panel: PanelContainer
var title: Label
var text: Label
## Small orange counter above the title; null when created without one.
var counter: Label


## Creates the caption in a new CanvasLayer added to `parent`.
## with_counter: also add the counter label above the title.
func _init(parent: Node, with_counter := false) -> void:
	var layer := CanvasLayer.new()
	parent.add_child(layer)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.78)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(28, 28)
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	if with_counter:
		counter = Label.new()
		counter.add_theme_font_size_override("font_size", 14)
		counter.add_theme_color_override("font_color", Color(0.95, 0.6, 0.45))
		vb.add_child(counter)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 34)
	# semi-bold Rubik via the variable font's weight axis
	var bold := FontVariation.new()
	bold.base_font = load(FONT)
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	title.add_theme_font_override("font", bold)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	vb.add_child(title)
	text = Label.new()
	text.add_theme_font_size_override("font_size", 19)
	text.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH, 0)
	vb.add_child(text)


## Shows a stop from tour_data.gd (`title` and `text` keys).
func show_stop(stop: Dictionary) -> void:
	title.text = stop["title"]
	text.text = stop["text"]
