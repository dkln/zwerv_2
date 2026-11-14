extends VBoxContainer
## What the quest tracker of the HUD looks like (graphics; docs/CODE_LAGEN.md): one panel,
## the quest that is followed. A main quest with its label, how far its nearest place is,
## its title and its steps (a box ticked when done, the text struck through, the experience
## it gives); a side quest as its label and title. It shows what quest_tracker.gd hands it
## (show_main_quest, show_side_quest, show_nothing, show_distance) and decides nothing; its
## sizes come from quest_tracker_layout.gd.
##   const QuestTrackerView = preload("res://scripts/ui/hud/quest_tracker_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const Layout = preload("res://scripts/ui/hud/quest_tracker_layout.gd")
const CheckSquare = preload("res://scripts/ui/widgets/check_square.gd")
## How see-through a quest step is that cannot be done yet (the one before it first).
const LOCKED_STEP_OPACITY := 0.35
const MAIN_BACKGROUND_OPACITY := 0.82
const SIDE_BACKGROUND_OPACITY := 0.7

var _distance: Label         # the distance in the panel of a main quest
var _fonts := {}


func _init() -> void:
	name = "Beeld"
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(Layout.WIDTH, 0)
	size = Vector2(Layout.WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonts = UiStyle.fonts()


## The panel of a main quest: `label` ("VERHAAL"), `title`, `distance` ("240 M", "" none)
## and its steps, each {"text": BBCode, "done": bool, "locked": bool, "xp": "+25 XP" or ""}.
func show_main_quest(label: String, title: String, distance: String, steps: Array) -> void:
	_clear()
	var parts := _panel(UiStyle.ACCENT, MAIN_BACKGROUND_OPACITY, Layout.MAIN_MARGIN, Layout.MAIN_SEPARATION)
	var column: VBoxContainer = parts[1]
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_text := UiStyle.label("◆ " + label, UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.ACCENT)
	label_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label_text)
	_distance = UiStyle.label(distance, _fonts.pixel, 11, UiStyle.MUTED)
	header.add_child(_distance)
	column.add_child(header)
	var title_text := UiStyle.label(title, _fonts.title_medium, 19, UiStyle.TEXT)
	title_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_text)
	var rows := VBoxContainer.new()
	rows.name = "Stappen"
	rows.add_theme_constant_override("separation", Layout.STEP_SEPARATION)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for step: Dictionary in steps:
		rows.add_child(_step_row(step))
	column.add_child(rows)
	add_child(parts[0])


## The panel of a side quest: `label` ("ZIJMISSIE") and `title`.
func show_side_quest(label: String, title: String) -> void:
	_clear()
	var parts := _panel(UiStyle.SIDE_ACCENT, SIDE_BACKGROUND_OPACITY, Layout.SIDE_QUEST_MARGIN, Layout.SIDE_QUEST_SEPARATION)
	var column: VBoxContainer = parts[1]
	column.add_child(UiStyle.label("! " + label, UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.SIDE_ACCENT))
	var title_text := UiStyle.label(title, _fonts.body, 13, UiStyle.TEXT)
	title_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title_text)
	add_child(parts[0])


## No quest is followed: no panel.
func show_nothing() -> void:
	_clear()


## The distance in the panel of a main quest ("240 M"; "" none); nothing without one.
func show_distance(text: String) -> void:
	if _distance != null and is_instance_valid(_distance):
		_distance.text = text


## The distance the panel shows now ("" when none, or no main quest is shown).
func distance_text() -> String:
	return _distance.text if _distance != null and is_instance_valid(_distance) else ""


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_distance = null


static func _panel(accent: Color, background_alpha: float, vertical_margin: int, separation: int) -> Array:
	var panel := PanelContainer.new()
	var style := UiStyle.box_style(Color(UiStyle.INK, background_alpha), accent, Layout.ACCENT_WIDTH, true)
	style.content_margin_left = Layout.SIDE_MARGIN
	style.content_margin_right = Layout.SIDE_MARGIN
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	return [panel, column]


## A step of a main quest: its box (ticked when done), its text and the experience it
## gives; see-through while it cannot be done yet.
func _step_row(step: Dictionary) -> Control:
	var done: bool = step.get("done", false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Layout.STEP_PART_SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := CheckSquare.new()
	box.done = done
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", _fonts.body)
	text.add_theme_font_size_override("normal_font_size", 13)
	text.add_theme_color_override("default_color", UiStyle.MUTED if done else UiStyle.TEXT)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = str(step.get("text", ""))
	row.add_child(text)
	if str(step.get("xp", "")) != "":
		var points := UiStyle.label(str(step.xp), _fonts.pixel, 10, UiStyle.MUTED if done else StatLook.XP_COLOUR)
		points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(points)
	if step.get("locked", false):
		row.modulate.a = LOCKED_STEP_OPACITY
	return row
