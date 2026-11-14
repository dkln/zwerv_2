extends Control
## How the pause menu looks (the graphics layer of scripts/ui/screens/pause_menu.gd, which
## is the behaviour and has this as its child; pause_menu_rules.gd has the logic,
## pause_menu_layout.gd the sizes): the game dimmed, a panel in the middle with the title,
## a column of buttons and the line with the keys. It builds and styles them and shows what
## it is handed (show_entries, show_selected); it decides nothing: the mouse over or on a
## button it only passes on (entry_hovered, entry_pressed).
##   const PauseMenuView = preload("res://scripts/ui/screens/pause_menu_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const PauseMenuLayout = preload("res://scripts/ui/screens/pause_menu_layout.gd")
const TITLE := "— PAUZE —"
const KEYS := "[↑↓] KIEZEN   [ENTER] KIES   [ESC] TERUG"
const DIM_ALPHA := 0.55
const PANEL_ALPHA := 0.94
const TITLE_FONT_SIZE := 12
const KEYS_FONT_SIZE := 10
const BUTTON_FONT_SIZE := 22
## Before the text of a button: the arrow on the selected one, as much room on the others.
const ARROW := "→  "
const NO_ARROW := "    "

## The mouse came over button `index`.
signal entry_hovered(index: int)
## Button `index` was clicked.
signal entry_pressed(index: int)

var _buttons: Array[Button] = []
var _column: VBoxContainer
var _title: Label
var _keys: Label
var _font_title_medium: Font


func _init() -> void:
	name = "Beeld"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonts := UiStyle.fonts()
	_font_title_medium = fonts.title_medium
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PauseMenuLayout.ROW_SEPARATION)
	_panel().add_child(column)
	_title = UiStyle.label(TITLE, fonts.pixel, TITLE_FONT_SIZE, UiStyle.ACCENT, 2)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", PauseMenuLayout.ROW_SEPARATION)
	column.add_child(_column)
	_keys = UiStyle.label(KEYS, fonts.pixel, KEYS_FONT_SIZE, UiStyle.MUTED)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_keys)


## Puts a button per label in the panel, top to bottom, each `width` wide, in place of the
## ones there were; none selected yet (show_selected).
func show_entries(labels: Array, width: float) -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for index in labels.size():
		_buttons.append(_button(index, width))
	show_selected(-1, labels)


## Puts the arrow on button `index` (none: -1) and writes every label anew.
func show_selected(index: int, labels: Array) -> void:
	for button_index in mini(_buttons.size(), labels.size()):
		_style_button(_buttons[button_index], button_index == index, String(labels[button_index]))


## The buttons shown now, top to bottom.
func buttons() -> Array[Button]:
	return _buttons


## What the title above the buttons says.
func title_text() -> String:
	return _title.text


## What the line with the keys under the buttons says.
func keys_text() -> String:
	return _keys.text


func _panel() -> PanelContainer:
	var box := PanelContainer.new()
	var style := UiStyle.box_style(Color(UiStyle.INK, PANEL_ALPHA), UiStyle.BORDER, PauseMenuLayout.PANEL_BORDER)
	style.content_margin_left = PauseMenuLayout.PANEL_MARGIN_SIDE
	style.content_margin_right = PauseMenuLayout.PANEL_MARGIN_SIDE
	style.content_margin_top = PauseMenuLayout.PANEL_MARGIN_TOP
	style.content_margin_bottom = PauseMenuLayout.PANEL_MARGIN_BOTTOM
	box.add_theme_stylebox_override("panel", style)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(box)
	return box


func _button(index: int, width: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = PauseMenuLayout.button_size(width)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font_title_medium)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.mouse_entered.connect(func() -> void: entry_hovered.emit(index))
	button.pressed.connect(func() -> void: entry_pressed.emit(index))
	_column.add_child(button)
	return button


static func _style_button(button: Button, on: bool, text: String) -> void:
	var style := UiStyle.menu_item_style(on)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(colour_name, UiStyle.INK if on else UiStyle.TEXT)
	button.text = (ARROW if on else NO_ARROW) + text
