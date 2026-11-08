class_name ActionPrompts
extends VBoxContainer
## The actions the player can do now, in the style of the HUD's action prompt: one under
## the other, each on an ink panel of its own with a border, all as wide as the widest,
## each a key cap ("SPATIE") and what it does ("Overslaan"); the key caps are as wide as
## each other, their names in the middle, so they line up. Context-sensitive:
## set_actions replaces them whenever what can be done changes (an empty list hides it).
## Mouse clicks go through it.
##   var prompts := ActionPrompts.new()
##   prompts.set_actions([["SPATIE", "Overslaan"], ["ENTER", "Sneller"]])

const UiStyle = preload("res://scripts/ui/ui_style.gd")
## Pixels between the panels, and between a key cap and its text.
const PANEL_GAP := 8
const KEY_GAP := 10

var _actions: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", PANEL_GAP)
	visible = false


## The actions shown, top to bottom: [key text, action text] each.
func set_actions(actions: Array) -> void:
	if actions == _actions:
		return
	_actions = actions.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for action: Array in _actions:
		add_child(_panel(str(action[0]), str(action[1])))
	visible = not _actions.is_empty()
	# shrink back to the panels (fewer or shorter actions than before)
	reset_size()


## All key caps as wide as the widest, their names in the middle: the caps line up under
## each other, and the texts after them start at the same place. Done as the panels are
## laid out (only then are the fonts' widths known); it settles at once, since it only
## changes a width that differs.
func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var key_caps: Array[Control] = []
	var widest := 0.0
	for panel in get_children():
		var key_cap := panel.get_child(0).get_child(0) as Control
		key_caps.append(key_cap)
		var label := key_cap.get_child(0) as Control
		var style := key_cap.get_theme_stylebox("panel")
		widest = maxf(widest, label.get_combined_minimum_size().x + (style.get_minimum_size().x if style else 0.0))
	for key_cap in key_caps:
		if absf(key_cap.custom_minimum_size.x - widest) > 0.5:
			key_cap.custom_minimum_size.x = widest


func actions() -> Array:
	return _actions.duplicate(true)


## One action on its own ink panel, filling the width of the column (so all panels are as
## wide as the widest).
static func _panel(key_text: String, action_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, 2)
	style.content_margin_left = 10
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", KEY_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_key_cap(key_text))
	row.add_child(_action_label(action_text))
	panel.add_child(row)
	return panel


## A key cap: the key's name in ink on a light cap with a hard shadow under it.
static func _key_cap(key_text: String) -> PanelContainer:
	var key := PanelContainer.new()
	var key_style := UiStyle.box_style(UiStyle.TEXT, UiStyle.TEXT, 0)
	key_style.content_margin_left = 8
	key_style.content_margin_right = 8
	key_style.content_margin_top = 4
	key_style.content_margin_bottom = 4
	key_style.shadow_color = UiStyle.MUTED
	key_style.shadow_offset = Vector2(0, 3)
	key.add_theme_stylebox_override("panel", key_style)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var key_label := Label.new()
	key_label.text = key_text
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_color", UiStyle.INK)
	key.add_child(key_label)
	return key


static func _action_label(action_text: String) -> Label:
	var action := Label.new()
	action.text = action_text
	action.add_theme_font_override("font", UiStyle.weighted(UiStyle.font(UiStyle.FONT_BODY), 400))
	action.add_theme_font_size_override("font_size", 14)
	action.add_theme_color_override("font_color", UiStyle.TEXT)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return action
