extends MarginContainer
## What the QUESTS tab of the game menu looks like (graphics; docs/CODE_LAGEN.md): the
## buttons VERHAAL and ZIJMISSIES and the list of that kind on the left (a row per quest:
## tag, title, how far it is), the chosen quest on the right (tag, title, giver, distance,
## description, steps with boxes, the follow button, rewards), or one panel in the middle
## when there are no quests at all. It shows what quest_tab.gd hands it and says what was
## clicked; its sizes come from quest_tab_layout.gd.
##   const QuestTabView = preload("res://scripts/ui/game_menu/quest_tab_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const QuestTrackerView = preload("res://scripts/ui/hud/quest_tracker_view.gd")
const MenuParts = preload("res://scripts/ui/game_menu/menu_parts_view.gd")
const MenuBox = preload("res://scripts/ui/game_menu/menu_box.gd")
const Layout = preload("res://scripts/ui/game_menu/quest_tab_layout.gd")
const KEYS := "[↑↓] KIEZEN   [ENTER] VOLGEN   [←→] VERHAAL / ZIJMISSIES   [Q/E] TAB   [TAB] SLUITEN"

## The button of a list was clicked (its kind).
signal kind_pressed(kind: String)
## A row of the list was clicked (its index).
signal row_pressed(index: int)
## The follow button of the chosen quest was clicked.
signal follow_pressed

var _fonts := {}
var _colour := UiStyle.ACCENT      # of the list that is shown
var _list_column: VBoxContainer
var _kind_row: HBoxContainer
var _kind_boxes := {}              # kind -> MenuBox
var _kind_labels := {}             # kind -> Label
var _kind_colours := {}            # kind -> Color
var _rows: VBoxContainer
var _detail: MenuBox
var _detail_column: VBoxContainer
var _empty: MenuBox


func _init() -> void:
	name = "Beeld"
	_fonts = MenuParts.fonts()
	var content := MenuParts.fill_page(self, KEYS, _fonts.pixel)
	content.add_child(_list())
	_detail = MenuParts.box(_detail_style(UiStyle.ACCENT), Layout.DETAIL_SHADOW)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_column = MenuParts.vbox(16)
	_detail.add_child(_detail_column)
	content.add_child(_detail)
	content.add_child(_empty_panel())


## The button of a list, after the ones before it: its `kind`, the `label` on it and
## whether it is the list of the story (`main`: amber) or of the side quests (teal).
func add_kind(kind: String, label: String, main: bool) -> void:
	var button := MenuParts.box(_kind_style(false, UiStyle.BORDER), 0.0, true)
	button.custom_minimum_size = Vector2(0, Layout.KIND_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button_label := UiStyle.label(label, _fonts.pixel, 11, UiStyle.MUTED)
	button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(button_label)
	button.pressed.connect(func() -> void: kind_pressed.emit(kind))
	_kind_row.add_child(button)
	_kind_boxes[kind] = button
	_kind_labels[kind] = button_label
	_kind_colours[kind] = UiStyle.ACCENT if main else UiStyle.SIDE_ACCENT


## No quests at all: one panel in the middle instead of the list and the chosen quest.
func show_no_quests() -> void:
	_empty.visible = true
	_list_column.visible = false
	_detail.visible = false


## The list of `kind`: its button raised, a row for each of `rows` (QuestTabRules.row),
## the one at `selected` chosen; without rows only `nothing_text`.
func show_list(kind: String, rows: Array, selected: int, nothing_text: String) -> void:
	_empty.visible = false
	_list_column.visible = true
	_detail.visible = true
	_colour = _kind_colours[kind]
	for name_of_kind: String in _kind_boxes:
		var on := name_of_kind == kind
		(_kind_boxes[name_of_kind] as MenuBox).style = _kind_style(on, _kind_colours[name_of_kind])
		(_kind_labels[name_of_kind] as Label).add_theme_color_override("font_color", UiStyle.TEXT if on else UiStyle.MUTED)
	for row in _rows.get_children():
		row.queue_free()
	if rows.is_empty():
		_rows.add_child(UiStyle.label(nothing_text, _fonts.italic, 13, UiStyle.MUTED))
	for index in rows.size():
		_rows.add_child(_row(rows[index], index, index == selected))


## The chosen quest on the right (QuestTabRules.detail), in the colour of the list shown.
func show_quest(detail: Dictionary) -> void:
	_clear_detail()
	var heading := MenuParts.hbox(16)
	_detail_column.add_child(heading)
	var names := MenuParts.vbox(6)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(names)
	names.add_child(UiStyle.label(detail.tag, UiStyle.spaced(_fonts.pixel, 3), 11, _colour))
	var title := UiStyle.label(detail.title, _fonts.title_spaced, 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(title)
	if detail.giver != "":
		names.add_child(UiStyle.label(detail.giver, _fonts.body, 12, UiStyle.MUTED))
	if detail.distance != "":
		var chip := MenuParts.box(MenuParts.style(MenuParts.NOTHING, UiStyle.BORDER, 2, 8, 4))
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		chip.add_child(UiStyle.label(detail.distance, _fonts.pixel, 11))
		heading.add_child(chip)
	if detail.description != "":
		var text := UiStyle.label(detail.description, _fonts.body, 14, MenuParts.SOFT_TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_constant_override("line_spacing", 6)
		_detail_column.add_child(text)
	if not (detail.steps as Array).is_empty():
		_detail_column.add_child(_goals(detail.steps))
	_detail_column.add_child(_follow_button(detail.follow_text, detail.followed, detail.finished))
	_detail_column.add_child(MenuParts.spacer())
	if not (detail.rewards as Array).is_empty():
		_detail_column.add_child(_rewards(detail.rewards))


## No quest is chosen (the list is empty): only a line of text on the right.
func show_no_quest() -> void:
	_clear_detail()
	_detail_column.add_child(UiStyle.label("Kies een opdracht.", _fonts.italic, 14, UiStyle.MUTED))


## Whether the panel of no quests at all is shown.
func is_showing_no_quests() -> bool:
	return _empty.visible


## Whether the panel of the chosen quest is shown.
func is_showing_detail() -> bool:
	return _detail.visible


## How many rows the list has now (the line of an empty list counts as one).
func row_count() -> int:
	return _live_children(_rows).size()


## The texts in the list now, top to bottom.
func list_texts() -> Array:
	var texts: Array = []
	for row in _live_children(_rows):
		texts.append_array(_texts_under(row))
	return texts


## The texts in the panel of the chosen quest now, top to bottom.
func detail_texts() -> Array:
	var texts: Array = []
	for part in _live_children(_detail_column):
		texts.append_array(_texts_under(part))
	return texts


## The rows of the steps of the chosen quest (their box first, then their texts).
func step_rows() -> Array:
	var goals := _detail_column.find_child("Doelen", false, false)
	return goals.get_children().slice(1) if goals and not goals.is_queued_for_deletion() else []


static func _live_children(parent: Node) -> Array:
	return parent.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion())


static func _texts_under(node: Node) -> Array:
	var texts: Array = [(node as Label).text] if node is Label else []
	for child in node.get_children():
		texts.append_array(_texts_under(child))
	return texts


func _clear_detail() -> void:
	for child in _detail_column.get_children():
		child.queue_free()
	_detail.style = _detail_style(_colour)


static func _kind_style(on: bool, colour: Color) -> StyleBoxFlat:
	return MenuParts.style(MenuParts.RAISED if on else UiStyle.INK, colour if on else UiStyle.BORDER, 2, 8, 4)


static func _detail_style(colour: Color) -> StyleBoxFlat:
	return MenuParts.style(UiStyle.PANEL, colour, 3, 28, 24)


func _list() -> Control:
	_list_column = MenuParts.vbox(12)
	_list_column.custom_minimum_size = Vector2(Layout.LIST_WIDTH, 0)
	_kind_row = MenuParts.hbox(6)
	_list_column.add_child(_kind_row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_list_column.add_child(scroll)
	_rows = MenuParts.vbox(6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	return _list_column


func _empty_panel() -> Control:
	_empty = MenuParts.box(MenuParts.style(UiStyle.PANEL, UiStyle.BORDER, 3, 40, 32), UiStyle.SHADOW_OFFSET)
	_empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty_column := MenuParts.vbox(10)
	var empty_heading := UiStyle.label("— GEEN OPDRACHTEN —", UiStyle.spaced(_fonts.pixel, 3), 12, UiStyle.ACCENT)
	empty_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_column.add_child(empty_heading)
	var empty_text := UiStyle.label("Nog geen opdrachten. Zwerf wat rond.", _fonts.italic, 14, MenuParts.SOFT_TEXT)
	empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_column.add_child(empty_text)
	_empty.add_child(empty_column)
	return _empty


func _row(row: Dictionary, index: int, selected: bool) -> Control:
	var row_style := MenuParts.style(MenuParts.RAISED if selected else UiStyle.PANEL, Color.WHITE if selected else UiStyle.BORDER, 2, Layout.ROW_MARGIN_X, Layout.ROW_MARGIN_Y)
	row_style.content_margin_left = Layout.row_margin_left()
	var box := MenuParts.box(row_style, Layout.CHOSEN_ROW_SHADOW if selected else 0.0, true)
	box.strip_width = Layout.ROW_STRIP
	box.strip_colour = _colour
	box.custom_minimum_size = Layout.row_size()
	var line := MenuParts.hbox(12)
	box.add_child(line)
	var texts := MenuParts.vbox(3)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	texts.add_child(UiStyle.label(row.tag, UiStyle.spaced(_fonts.pixel, 2), 10, _colour))
	var title := UiStyle.label(row.title, _fonts.title_medium, 17, UiStyle.MUTED if row.done else UiStyle.TEXT)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(title)
	var status := UiStyle.label(row.status, _fonts.pixel, 10, UiStyle.ACCENT if row.followed else UiStyle.MUTED)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(status)
	box.pressed.connect(func() -> void: row_pressed.emit(index))
	return box


func _goals(steps: Array) -> Control:
	var goals := MenuParts.vbox(8)
	goals.name = "Doelen"
	goals.add_child(UiStyle.label("DOELEN", UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.MUTED))
	for step: Dictionary in steps:
		goals.add_child(_step(step))
	return goals


func _step(step: Dictionary) -> Control:
	var step_colour := UiStyle.MUTED if step.done else UiStyle.TEXT
	var row := MenuParts.hbox(10)
	var check := Panel.new()
	check.custom_minimum_size = Vector2(Layout.STEP_BOX, Layout.STEP_BOX)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.add_theme_stylebox_override("panel", UiStyle.box_style(step_colour if step.done else MenuParts.NOTHING, step_colour, 2))
	row.add_child(check)
	var step_text := UiStyle.label(step.text, _fonts.body, 14, step_colour)
	step_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(step_text)
	if step.has_progress:
		row.add_child(UiStyle.label(step.progress, _fonts.pixel, 11, step_colour))
	if step.xp != "":
		row.add_child(UiStyle.label(step.xp, _fonts.pixel, 11, step_colour if step.done else StatLook.XP_COLOUR))
	# a step that cannot be done yet: see-through
	if step.locked:
		row.modulate.a = QuestTrackerView.LOCKED_STEP_OPACITY
	return row


func _follow_button(text: String, followed: bool, finished: bool) -> Control:
	var can_follow := not followed and not finished
	var follow := MenuParts.box(MenuParts.style(MenuParts.RAISED if followed else UiStyle.INK, _colour if followed else UiStyle.BORDER, 2, 12, 6), 0.0, can_follow)
	follow.name = "Volgen"
	follow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	follow.add_child(UiStyle.label(text, _fonts.pixel, 11, _colour if followed else (UiStyle.MUTED if finished else UiStyle.TEXT)))
	if can_follow:
		follow.pressed.connect(func() -> void: follow_pressed.emit())
	return follow


func _rewards(rewards: Array) -> Control:
	var footer := MenuParts.box(_footer_style())
	var footer_column := MenuParts.vbox(8)
	footer.add_child(footer_column)
	footer_column.add_child(UiStyle.label("BELONINGEN", UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.MUTED))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for reward: String in rewards:
		var chip := MenuParts.box(MenuParts.style(UiStyle.INK, _colour, 2, 10, 6))
		var chip_row := MenuParts.hbox(6)
		var square := ColorRect.new()
		square.color = _colour
		square.custom_minimum_size = Vector2(Layout.REWARD_SQUARE, Layout.REWARD_SQUARE)
		square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_row.add_child(square)
		chip_row.add_child(UiStyle.label(reward, _fonts.pixel, 11))
		chip.add_child(chip_row)
		chips.add_child(chip)
	footer_column.add_child(chips)
	return footer


## A line over the rewards, with room under it.
static func _footer_style() -> StyleBoxFlat:
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = MenuParts.NOTHING
	footer_style.border_color = UiStyle.BORDER
	footer_style.border_width_top = 2
	footer_style.content_margin_top = 16
	footer_style.anti_aliasing = false
	return footer_style
