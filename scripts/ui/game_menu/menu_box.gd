extends Container
## A box of the game menu (graphics, a widget; docs/CODE_LAGEN.md): a style box with a hard
## shadow down and to the right and, if set, a coloured strip on its left; its children fill
## it inside the style's content margins. Clickable (the `pressed` signal) when its mouse
## filter is STOP. Made by menu_parts_view.gd (`box`), used by every view of the menu.
##   const MenuBox = preload("res://scripts/ui/game_menu/menu_box.gd")

signal pressed

var style: StyleBox:
	set(value):
		style = value
		update_minimum_size()
		queue_sort()
		queue_redraw()
var shadow_offset := 0.0:
	set(value):
		shadow_offset = value
		queue_redraw()
var shadow_colour := Color.BLACK:
	set(value):
		shadow_colour = value
		queue_redraw()
var strip_colour := Color(0, 0, 0, 0):
	set(value):
		strip_colour = value
		queue_redraw()
var strip_width := 0.0


func _init(box_style: StyleBox = null) -> void:
	style = box_style if box_style else StyleBoxEmpty.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var top_left := Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
		var inner := Rect2(top_left, (size - style.get_minimum_size()).max(Vector2.ZERO))
		for child in get_children():
			if child is Control and not (child as Control).top_level:
				fit_child_in_rect(child, inner)


func _get_minimum_size() -> Vector2:
	var largest := Vector2.ZERO
	for child in get_children():
		if child is Control and (child as Control).visible and not (child as Control).top_level:
			largest = largest.max((child as Control).get_combined_minimum_size())
	return largest + style.get_minimum_size()


func _draw() -> void:
	if shadow_offset > 0.0:
		draw_rect(Rect2(Vector2.ONE * shadow_offset, size), shadow_colour)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	if strip_width > 0.0 and strip_colour.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(strip_width, size.y)), strip_colour)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
