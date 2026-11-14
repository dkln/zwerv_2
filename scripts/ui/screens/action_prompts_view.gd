extends VBoxContainer
## How the action prompts look (the graphics layer of scripts/ui/action_prompts.gd, which is
## the behaviour and has this as its child; action_prompts_rules.gd has the logic,
## action_prompts_layout.gd the sizes): one under the other, each action on an ink panel of
## its own with a border, all as wide as the widest, each a key cap ("SPATIE") and what it
## does ("Overslaan"); the key caps are as wide as each other, their names in the middle, so
## they line up. It shows the texts it is handed (show_actions) and decides nothing; mouse
## clicks go through it.
##   const ActionPromptsView = preload("res://scripts/ui/screens/action_prompts_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const ActionPromptsLayout = preload("res://scripts/ui/screens/action_prompts_layout.gd")
const FONT_SIZE := 14


func _init() -> void:
	name = "Beeld"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", ActionPromptsLayout.PANEL_GAP)


## A panel per row of `rows` ([key text, action text] each), top to bottom, in place of the
## ones there were.
func show_actions(rows: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for row: Array in rows:
		add_child(_panel(String(row[0]), String(row[1])))


## How many panels there are now.
func panel_count() -> int:
	return get_child_count()


## The key cap (the cap round the key's name) of panel `index`.
func key_cap(index: int) -> Control:
	return get_child(index).get_child(0).get_child(0) as Control


## What the key cap of panel `index` says.
func key_text(index: int) -> String:
	return (key_cap(index).get_child(0) as Label).text


## What the action of panel `index` says.
func action_text(index: int) -> String:
	return (get_child(index).get_child(0).get_child(1) as Label).text


## All key caps as wide as the widest, their names in the middle: the caps line up under
## each other, and the texts after them start at the same place. Done as the panels are
## laid out (only then are the fonts' widths known); it settles at once, since it only
## changes a width that differs.
func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var widths: Array = []
	for index in get_child_count():
		var cap := key_cap(index)
		var style := cap.get_theme_stylebox("panel")
		widths.append(ActionPromptsLayout.key_cap_width((cap.get_child(0) as Control).get_combined_minimum_size().x,
			style.get_minimum_size().x if style else 0.0))
	var widest := ActionPromptsLayout.widest(widths)
	for index in get_child_count():
		var cap := key_cap(index)
		if ActionPromptsLayout.needs_width(cap.custom_minimum_size.x, widest):
			cap.custom_minimum_size.x = widest


## One action on its own ink panel, filling the width of the column (so all panels are as
## wide as the widest).
static func _panel(key_text_shown: String, action_text_shown: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, ActionPromptsLayout.PANEL_BORDER)
	style.content_margin_left = ActionPromptsLayout.PANEL_MARGIN_LEFT
	style.content_margin_right = ActionPromptsLayout.PANEL_MARGIN_RIGHT
	style.content_margin_top = ActionPromptsLayout.PANEL_MARGIN_TOP
	style.content_margin_bottom = ActionPromptsLayout.PANEL_MARGIN_BOTTOM
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ActionPromptsLayout.KEY_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_key_cap(key_text_shown))
	row.add_child(_action_label(action_text_shown))
	panel.add_child(row)
	return panel


## A key cap: the key's name in ink on a light cap with a hard shadow under it.
static func _key_cap(key_text_shown: String) -> PanelContainer:
	var key := PanelContainer.new()
	var key_style := UiStyle.box_style(UiStyle.TEXT, UiStyle.TEXT, 0)
	key_style.content_margin_left = ActionPromptsLayout.KEY_MARGIN_SIDE
	key_style.content_margin_right = ActionPromptsLayout.KEY_MARGIN_SIDE
	key_style.content_margin_top = ActionPromptsLayout.KEY_MARGIN_TOP
	key_style.content_margin_bottom = ActionPromptsLayout.KEY_MARGIN_BOTTOM
	key_style.shadow_color = UiStyle.MUTED
	key_style.shadow_offset = ActionPromptsLayout.KEY_SHADOW
	key.add_theme_stylebox_override("panel", key_style)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var key_label := Label.new()
	key_label.text = key_text_shown
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	key_label.add_theme_font_size_override("font_size", FONT_SIZE)
	key_label.add_theme_color_override("font_color", UiStyle.INK)
	key.add_child(key_label)
	return key


static func _action_label(action_text_shown: String) -> Label:
	var action := Label.new()
	action.text = action_text_shown
	action.add_theme_font_override("font", UiStyle.weighted(UiStyle.font(UiStyle.FONT_BODY), 400))
	action.add_theme_font_size_override("font_size", FONT_SIZE)
	action.add_theme_color_override("font_color", UiStyle.TEXT)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return action
