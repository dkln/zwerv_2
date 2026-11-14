extends MarginContainer
## What the INVENTARIS tab of the game menu looks like (graphics; docs/CODE_LAGEN.md): the
## character on the left (name, level and subtitle, the figure in 3D, the stats as segment
## bars), the category buttons and the grid of slots in the middle (border in the colour of
## the rarity, count bottom right), the chosen item on the right (rarity, name, kind,
## effects, text, use and drop buttons). It shows what inventory_tab.gd hands it and says
## what was clicked or hovered; its sizes come from inventory_tab_layout.gd.
##   const InventoryTabView = preload("res://scripts/ui/game_menu/inventory_tab_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const Items = preload("res://scripts/player/items.gd")
const ItemLook = preload("res://scripts/ui/game_menu/item_look.gd")
const MenuParts = preload("res://scripts/ui/game_menu/menu_parts_view.gd")
const MenuBox = preload("res://scripts/ui/game_menu/menu_box.gd")
const Layout = preload("res://scripts/ui/game_menu/inventory_tab_layout.gd")
const KEYS := "[←↑↓→] KIEZEN   [ENTER] GEBRUIKEN   [X] WEGGOOIEN   [1-5] SOORT   [Q/E] TAB   [TAB] SLUITEN"
## How much of a shut slot shows (beyond the room the player has).
const LOCKED_SLOT_ALPHA := 0.3
## How fast the figure turns (degrees a second).
const FIGURE_SPIN := 22.0

## A category button was clicked (its index, in the order they were added).
signal category_pressed(index: int)
## A slot was clicked or hovered (hovering shows it on the right too).
signal slot_pressed(index: int)
signal use_pressed
signal drop_pressed

var _fonts := {}
var _character_name: Label
var _character_line: Label
var _portrait_holder: Control
var _portrait: PlayerPortrait
var _stats_column: VBoxContainer
var _stat_bars := {}            # stat name -> SegmentBar
var _stat_texts := {}           # stat name -> Label
var _category_row: HBoxContainer
var _category_boxes: Array[MenuBox] = []
var _category_labels: Array[Label] = []
var _slots: Array[MenuBox] = []
var _slot_icons: Array[PixelIcon] = []
var _slot_counts: Array[Label] = []
var _slots_used: Label
var _detail_box: MenuBox
var _detail_icon_box: MenuBox
var _detail_icon: PixelIcon
var _detail_rarity: Label
var _detail_name: Label
var _detail_kind: Label
var _detail_lines_box: MenuBox
var _detail_lines: VBoxContainer
var _detail_text: Label
var _detail_empty: Label
var _detail_buttons: HBoxContainer
var _action_box: MenuBox
var _action_label: Label
var _drop_box: MenuBox
var _drop_label: Label


func _init() -> void:
	name = "Beeld"
	_fonts = MenuParts.fonts()
	var content := MenuParts.fill_page(self, KEYS, _fonts.pixel)
	content.add_child(_character_column())
	content.add_child(_item_grid())
	content.add_child(_item_detail())


## A stat under the figure, after the ones before it: its icon and colours (StatLook), how
## it is called (`label`), its value and its bar.
func add_stat(stat_name: String, label: String) -> void:
	var look: Dictionary = StatLook.STATS[stat_name]
	var stat_column := MenuParts.vbox(4)
	var heading := MenuParts.hbox(8)
	var icon := PixelIcon.new()
	icon.bitmap = StatLook.PIXEL_ICONS[look.icon]
	icon.colour = look.colour
	icon.pixel = 2.0
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(icon)
	var stat_label := UiStyle.label(label, _fonts.pixel, 12)
	stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(stat_label)
	var value_text := UiStyle.label("", _fonts.pixel, 12, MenuParts.SOFT_TEXT)
	heading.add_child(value_text)
	stat_column.add_child(heading)
	var bar := SegmentBar.new()
	bar.segments = Layout.STAT_SEGMENTS
	bar.segment_height = Layout.STAT_SEGMENT_HEIGHT
	bar.full_colour = look.colour
	bar.empty_colour = look.empty
	stat_column.add_child(bar)
	_stats_column.add_child(stat_column)
	_stat_bars[stat_name] = bar
	_stat_texts[stat_name] = value_text


## A category button over the grid, after the ones before it.
func add_category(label: String) -> void:
	var index := _category_boxes.size()
	var button := MenuParts.box(_category_style(false), 0.0, true)
	button.custom_minimum_size = Vector2(0, Layout.CATEGORY_HEIGHT)
	var button_label := UiStyle.label(label, _fonts.pixel, 11, UiStyle.MUTED)
	button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(button_label)
	button.pressed.connect(func() -> void: category_pressed.emit(index))
	_category_row.add_child(button)
	_category_boxes.append(button)
	_category_labels.append(button_label)


## The character: its name and the line under it ("LV 3 · De schilder").
func show_character(character_name: String, line: String) -> void:
	_character_name.text = character_name
	_character_line.text = line


## The figure of this archetype (PlayerPortrait), whole and turning slowly; made anew
## only when the archetype changed (it renders every frame).
func show_figure(archetype_id: String) -> void:
	if _portrait and _portrait.archetype_id == archetype_id:
		return
	hide_figure()
	_portrait = PlayerPortrait.new()
	_portrait.name = "Figuur"
	_portrait.archetype_id = archetype_id
	_portrait.zoom = 0.0
	_portrait.spin = FIGURE_SPIN
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait_holder.add_child(_portrait)


## No figure (the menu is closed: nothing to render).
func hide_figure() -> void:
	if _portrait:
		_portrait.queue_free()
		_portrait = null


## A stat: the share of its bar that is full and its value ("35/80").
func show_stat(stat_name: String, fill: float, text: String) -> void:
	(_stat_bars[stat_name] as SegmentBar).fill = fill
	(_stat_texts[stat_name] as Label).text = text


## The category that is chosen (its index): raised, the others plain.
func show_category(chosen_index: int) -> void:
	for index in _category_boxes.size():
		var on := index == chosen_index
		_category_boxes[index].style = _category_style(on)
		_category_labels[index].add_theme_color_override("font_color", UiStyle.TEXT if on else UiStyle.MUTED)


## A slot with an item (InventoryTabRules.slot: "icon", "rarity", "count", "tooltip",
## "selected", "missing"); `lit`: within the room the player has, else shut.
func show_slot(index: int, slot: Dictionary, lit: bool) -> void:
	var box := _slots[index]
	var rarity_colour: Color = Items.RARITY_COLOURS[slot.rarity]
	box.modulate.a = 1.0 if lit else LOCKED_SLOT_ALPHA
	if slot.missing:
		# the slot kept for your ID card: empty, the card a shadow in it
		box.style = _slot_style(MenuParts.EMPTY_SLOT, Color.WHITE if slot.selected else MenuParts.EMPTY_BORDER)
		box.shadow_offset = 0.0
	else:
		box.style = _slot_style(MenuParts.SELECTED_SLOT if slot.selected else UiStyle.PANEL, Color.WHITE if slot.selected else rarity_colour)
		box.shadow_offset = Layout.CHOSEN_SHADOW if slot.selected else 0.0
	box.shadow_colour = rarity_colour
	_show_icon(_slot_icons[index], slot.icon, slot.missing)
	_slot_counts[index].text = slot.count
	box.tooltip_text = slot.tooltip


## A slot without an item; `lit`: within the room the player has, else shut.
func show_empty_slot(index: int, lit: bool, tooltip: String) -> void:
	var box := _slots[index]
	box.modulate.a = 1.0 if lit else LOCKED_SLOT_ALPHA
	box.style = _slot_style(MenuParts.EMPTY_SLOT, MenuParts.EMPTY_BORDER)
	box.shadow_offset = 0.0
	_slot_icons[index].bitmap = []
	_slot_icons[index].modulate.a = 1.0
	_slot_counts[index].text = ""
	box.tooltip_text = tooltip


## Under the grid: "4 / 6 VAKJES".
func show_slots_used(text: String) -> void:
	_slots_used.text = text


## The chosen item on the right (InventoryTabRules.detail).
func show_item(detail: Dictionary) -> void:
	_show_detail_parts(true)
	var rarity_colour: Color = Items.RARITY_COLOURS[detail.rarity]
	_detail_box.style = _detail_style(rarity_colour)
	_detail_icon_box.style = MenuParts.style(UiStyle.INK, rarity_colour, 2)
	_show_icon(_detail_icon, detail.icon, detail.missing)
	_detail_rarity.text = detail.rarity_text
	_detail_rarity.add_theme_color_override("font_color", rarity_colour)
	_detail_name.text = detail.name
	_detail_kind.text = detail.kind_text
	for line in _detail_lines.get_children():
		line.queue_free()
	for line: Dictionary in detail.lines:
		_detail_lines.add_child(_detail_line(line.key, line.value, _tone_colour(line.tone)))
	_detail_text.text = detail.text
	_detail_text.visible = detail.text != ""
	_action_box.visible = detail.can_use
	_action_label.text = detail.action
	_drop_box.mouse_filter = Control.MOUSE_FILTER_STOP if detail.can_drop else Control.MOUSE_FILTER_IGNORE
	_drop_label.add_theme_color_override("font_color", UiStyle.TEXT if detail.can_drop else MenuParts.EMPTY_BORDER)
	_drop_box.size_flags_horizontal = Control.SIZE_FILL if detail.can_use else Control.SIZE_EXPAND_FILL


## No item is chosen: only this text on the right ("Je zakken zijn leeg.").
func show_no_item(text: String) -> void:
	_show_detail_parts(false)
	_detail_box.style = _detail_style(UiStyle.BORDER)
	_detail_empty.text = text


## What is written now, for the tests: {"name", "line", "slots_used", "empty", "item_name",
## "item_rarity", "item_kind", "item_text", "action"}.
func shown_texts() -> Dictionary:
	return {"name": _character_name.text, "line": _character_line.text, "slots_used": _slots_used.text,
		"empty": _detail_empty.text if _detail_empty.visible else "", "item_name": _detail_name.text,
		"item_rarity": _detail_rarity.text, "item_kind": _detail_kind.text, "item_text": _detail_text.text,
		"action": _action_label.text}


## The value written beside a stat ("35/80").
func stat_text(stat_name: String) -> String:
	return (_stat_texts[stat_name] as Label).text


## The share of the bar of a stat that is full.
func stat_fill(stat_name: String) -> float:
	return (_stat_bars[stat_name] as SegmentBar).fill


## The box of a slot (its style, shadow, tooltip and how lit it is).
func slot_box(index: int) -> MenuBox:
	return _slots[index]


## The icon in a slot.
func slot_icon(index: int) -> PixelIcon:
	return _slot_icons[index]


## The number bottom right in a slot.
func slot_count_text(index: int) -> String:
	return _slot_counts[index].text


## The lines of the chosen item as [key, value] pairs.
func item_lines() -> Array:
	var lines: Array = []
	for line in _detail_lines.get_children():
		if not line.is_queued_for_deletion():
			lines.append([(line.get_child(0) as Label).text, (line.get_child(1) as Label).text])
	return lines


## The figure; null while there is none.
func figure() -> PlayerPortrait:
	return _portrait


## Whether the use button and the drop button can be clicked now.
func buttons_enabled() -> Dictionary:
	return {"use": _detail_buttons.visible and _action_box.visible,
		"drop": _detail_buttons.visible and _drop_box.mouse_filter == Control.MOUSE_FILTER_STOP}


func _show_detail_parts(has_item: bool) -> void:
	for part: Control in [_detail_icon_box, _detail_rarity, _detail_name, _detail_kind, _detail_lines_box, _detail_text, _detail_buttons]:
		part.visible = has_item
	_detail_empty.visible = not has_item


## The icon by its name: an item's own (ItemLook) or one of the HUD's (StatLook).
func _show_icon(icon: PixelIcon, icon_name: String, missing: bool) -> void:
	if ItemLook.ITEM_ICONS.has(icon_name):
		icon.bitmap = ItemLook.ITEM_ICONS[icon_name].rows
		icon.colour = ItemLook.ITEM_ICONS[icon_name].colour
	else:
		icon.bitmap = StatLook.PIXEL_ICONS[icon_name]
		icon.colour = ItemLook.HUD_ICON_COLOURS.get(icon_name, UiStyle.TEXT)
	icon.modulate.a = ItemLook.MISSING_ITEM_ALPHA if missing else 1.0


static func _tone_colour(tone: String) -> Color:
	match tone:
		"good":
			return MenuParts.GOOD
		"bad":
			return MenuParts.BAD
		"muted":
			return UiStyle.MUTED
	return UiStyle.TEXT


static func _category_style(on: bool) -> StyleBoxFlat:
	return MenuParts.style(MenuParts.RAISED if on else UiStyle.INK, UiStyle.ACCENT if on else UiStyle.BORDER, 2, 12, 4)


static func _slot_style(background: Color, border: Color) -> StyleBoxFlat:
	return MenuParts.style(background, border, 2, 4, 1)


static func _detail_style(border: Color) -> StyleBoxFlat:
	return MenuParts.style(UiStyle.PANEL, border, 3, 20, 20)


func _detail_line(key: String, value: String, colour: Color) -> Control:
	var row := MenuParts.hbox(8)
	var key_label := UiStyle.label(key, _fonts.pixel, 12, MenuParts.SOFT_TEXT)
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)
	row.add_child(UiStyle.label(value, _fonts.body_bold, 13, colour))
	return row


func _character_column() -> Control:
	var column := MenuParts.vbox(14)
	column.custom_minimum_size = Vector2(Layout.CHARACTER_WIDTH, 0)
	var card := MenuParts.box(MenuParts.style(UiStyle.PANEL, UiStyle.BORDER, 3, 16, 16), UiStyle.SHADOW_OFFSET)
	column.add_child(card)
	var card_column := MenuParts.vbox(6)
	card.add_child(card_column)
	_character_name = UiStyle.label("", _fonts.title, 24)
	card_column.add_child(_character_name)
	_character_line = UiStyle.label("", _fonts.pixel, 11, UiStyle.ACCENT)
	_character_line.clip_text = true
	_character_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card_column.add_child(_character_line)
	# the figure in 3D on ink (made on opening, see show_figure)
	var figure_frame := MenuParts.box(MenuParts.style(UiStyle.INK, UiStyle.BORDER, 2))
	figure_frame.custom_minimum_size = Vector2(0, Layout.FIGURE_HEIGHT)
	_portrait_holder = Control.new()
	_portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_holder.clip_contents = true
	figure_frame.add_child(_portrait_holder)
	card_column.add_child(MenuParts.gap(Vector2(0, 6)))
	card_column.add_child(figure_frame)
	var stats := MenuParts.box(MenuParts.style(UiStyle.PANEL, UiStyle.BORDER, 2, 16, 14))
	column.add_child(stats)
	_stats_column = MenuParts.vbox(9)
	stats.add_child(_stats_column)
	_stats_column.add_child(UiStyle.label("TOESTAND", UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.MUTED))
	return column


func _item_grid() -> Control:
	var column := MenuParts.vbox(12)
	_category_row = MenuParts.hbox(6)
	column.add_child(_category_row)
	var grid := GridContainer.new()
	grid.columns = Layout.GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", Layout.SLOT_GAP)
	grid.add_theme_constant_override("v_separation", Layout.SLOT_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	for slot_index in Layout.slot_count():
		grid.add_child(_slot(slot_index))
	_slots_used = UiStyle.label("", _fonts.pixel, 10, UiStyle.MUTED)
	column.add_child(_slots_used)
	return column


func _slot(slot_index: int) -> MenuBox:
	var box := MenuParts.box(_slot_style(MenuParts.EMPTY_SLOT, MenuParts.EMPTY_BORDER), 0.0, true)
	box.custom_minimum_size = Layout.slot_size()
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PixelIcon.new()
	icon.pixel = Layout.SLOT_ICON_PIXEL
	centre.add_child(icon)
	box.add_child(centre)
	var count := UiStyle.label("", _fonts.pixel, 10)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_constant_override("line_spacing", 0)
	box.add_child(count)
	box.pressed.connect(func() -> void: slot_pressed.emit(slot_index))
	# hovering shows it on the right too (a found bank card: the riddle of its PIN)
	box.mouse_entered.connect(func() -> void: slot_pressed.emit(slot_index))
	_slots.append(box)
	_slot_icons.append(icon)
	_slot_counts.append(count)
	return box


func _item_detail() -> Control:
	_detail_box = MenuParts.box(_detail_style(UiStyle.BORDER), UiStyle.SHADOW_OFFSET)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := MenuParts.vbox(12)
	_detail_box.add_child(column)
	var heading := MenuParts.hbox(14)
	column.add_child(heading)
	_detail_icon_box = MenuParts.box(MenuParts.style(UiStyle.INK, UiStyle.BORDER, 2))
	_detail_icon_box.custom_minimum_size = Vector2(Layout.DETAIL_ICON_FRAME, Layout.DETAIL_ICON_FRAME)
	_detail_icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon = PixelIcon.new()
	_detail_icon.pixel = Layout.DETAIL_ICON_PIXEL
	centre.add_child(_detail_icon)
	_detail_icon_box.add_child(centre)
	heading.add_child(_detail_icon_box)
	var names := MenuParts.vbox(4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_child(names)
	_detail_rarity = UiStyle.label("", UiStyle.spaced(_fonts.pixel, 2), 11)
	names.add_child(_detail_rarity)
	_detail_name = UiStyle.label("", _fonts.title, 22)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(_detail_name)
	_detail_kind = UiStyle.label("", _fonts.body, 12, UiStyle.MUTED)
	names.add_child(_detail_kind)
	# the effects between two lines
	_detail_lines_box = MenuParts.box(MenuParts.lines_style(2, 2, 10, 10))
	_detail_lines = MenuParts.vbox(6)
	_detail_lines_box.add_child(_detail_lines)
	column.add_child(_detail_lines_box)
	_detail_text = UiStyle.label("", _fonts.italic, 13, MenuParts.SOFT_TEXT)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.add_theme_constant_override("line_spacing", 5)
	column.add_child(_detail_text)
	_detail_empty = UiStyle.label("Je zakken zijn leeg.", _fonts.italic, 13, UiStyle.MUTED)
	_detail_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_empty)
	column.add_child(MenuParts.spacer())
	_detail_buttons = MenuParts.hbox(8)
	column.add_child(_detail_buttons)
	_action_box = MenuParts.box(MenuParts.style(UiStyle.ACCENT, UiStyle.ACCENT, 0, 14), Layout.CHOSEN_SHADOW, true)
	_action_box.custom_minimum_size = Vector2(0, Layout.BUTTON_HEIGHT)
	_action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_label = UiStyle.label("", _fonts.pixel_bold, 12, UiStyle.INK)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_box.add_child(_action_label)
	_action_box.pressed.connect(func() -> void: use_pressed.emit())
	_detail_buttons.add_child(_action_box)
	_drop_box = MenuParts.box(MenuParts.style(UiStyle.PANEL, UiStyle.BORDER, 2, 14), 0.0, true)
	_drop_box.custom_minimum_size = Vector2(0, Layout.BUTTON_HEIGHT)
	_drop_label = UiStyle.label("WEGGOOIEN", _fonts.pixel, 12)
	_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drop_box.add_child(_drop_label)
	_drop_box.pressed.connect(func() -> void: drop_pressed.emit())
	_detail_buttons.add_child(_drop_box)
	return _detail_box
