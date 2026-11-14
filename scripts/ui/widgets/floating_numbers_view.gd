extends Control
## What the floating numbers look like (graphics; docs/CODE_LAGEN.md): each a text in the
## pixel font at a fixed size on the screen, with the faux 3D of the game's texts: a copy of
## the text a few pixels lower, behind it, in its colour half as light
## (UiStyle.faux_3d_colour); no outline. It makes the numbers floating_numbers.gd asks for
## and puts them where it says; the shadow's offset comes from floating_numbers_layout.gd.
##   const FloatingNumbersView = preload("res://scripts/ui/widgets/floating_numbers_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const FloatingNumbersLayout = preload("res://scripts/ui/widgets/floating_numbers_layout.gd")

## The font of the numbers to come (none: the default font).
var font: Font


func _init() -> void:
	name = "Beeld"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## A new number `text` in `colour`, `font_size` design pixels high, not shown yet; it turns
## and grows round its middle.
func add_number(text: String, colour: Color, font_size: int) -> Label:
	var label := _text_label(text, colour, font_size)
	label.visible = false
	add_child(label)
	label.reset_size()
	# the shadow is a child, so it follows the pop, the rise and the fade of the text itself
	var shadow := _text_label(text, UiStyle.faux_3d_colour(colour), font_size)
	shadow.show_behind_parent = true
	label.add_child(shadow)
	shadow.reset_size()
	shadow.position = FloatingNumbersLayout.SHADOW_OFFSET
	label.pivot_offset = label.size * 0.5
	return label


## Shows `label` at `at` (its top left corner), `grown` times its size and `opacity` opaque.
func show_number(label: Label, at: Vector2, grown: float, opacity: float) -> void:
	label.visible = true
	label.position = at
	label.scale = Vector2.ONE * grown
	label.modulate.a = opacity


## Hides `label` (its point is behind the camera).
func hide_number(label: Label) -> void:
	label.visible = false


## Takes `label` away for good.
func remove_number(label: Label) -> void:
	label.queue_free()


## The numbers there are now (not the ones on their way out).
func numbers() -> Array[Label]:
	var found: Array[Label] = []
	for child in get_children():
		if child is Label and not child.is_queued_for_deletion():
			found.append(child as Label)
	return found


func _text_label(text: String, colour: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	return label
