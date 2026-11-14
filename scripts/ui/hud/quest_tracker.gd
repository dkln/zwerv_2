extends VBoxContainer
## The quest tracker of the HUD (the node "Opdrachten", on the right): the quest that is
## followed (QuestLog: chosen in the game menu, else the first open one) in a panel, a main
## quest with its title, how far its nearest place is and the steps that matter now
## (QuestLog.tracker_steps: the last one done and the one open), a side quest as its label
## and title; hidden while no quest is followed. The others are in the quest log of the
## game menu.
##   const QuestTracker = preload("res://scripts/ui/hud/quest_tracker.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const QuestLog = preload("res://scripts/ui/hud/quest_log.gd")
const CheckSquare = preload("res://scripts/ui/widgets/check_square.gd")
const WIDTH := 300.0
## How see-through a quest step is that cannot be done yet (the one before it first).
const LOCKED_STEP_OPACITY := 0.35
## The colour of the experience a step gives ("+25 XP"), as the experience bar.
const XP_COLOUR := Color("#47D6C2")

## The quests and which one is followed.
var quest_log := QuestLog.new()

var _distance: Label         # the distance in the followed quest's panel (a main quest)
var _fonts := {}


func _init() -> void:
	name = "Opdrachten"
	add_theme_constant_override("separation", 10)
	custom_minimum_size = Vector2(WIDTH, 0)
	size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_fonts = UiStyle.fonts()


## The quests, top to bottom (QuestLog.set_quests); the panel of the followed one anew.
func set_quests(quests: Array) -> void:
	quest_log.set_quests(quests)
	rebuild()


## Follows the quest `id` (QuestLog.track); its panel in place of the one before.
func track(id: String) -> void:
	if quest_log.track(id):
		rebuild()


## How far (m) the nearest place of the followed quest is, in its panel; INF: nothing.
func set_distance(metres: float) -> void:
	if _distance != null and is_instance_valid(_distance):
		_distance.text = QuestLog.distance_text(metres)


## The distance the panel shows now ("" when none, or no main quest is followed).
func distance_text() -> String:
	return _distance.text if _distance != null and is_instance_valid(_distance) else ""


## The panel of the followed quest again (the quests changed, or which one is followed).
func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_distance = null
	var followed := quest_log.tracked()
	if not followed.is_empty():
		add_child(_main_quest_panel(followed) if QuestLog.is_main(followed) else _side_quest_panel(followed))
	visible = not followed.is_empty()


# ------------------------------------------------------------------ building

static func _panel(accent: Color, background_alpha: float, vertical_margin: int, separation: int) -> Array:
	var panel := PanelContainer.new()
	var style := UiStyle.box_style(Color(UiStyle.INK, background_alpha), accent, 4, true)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	return [panel, column]


func _main_quest_panel(quest: Dictionary) -> Control:
	var parts := _panel(UiStyle.ACCENT, 0.82, 12, 8)
	var column: VBoxContainer = parts[1]
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiStyle.label("◆ " + str(quest.get("label", "VERHAAL")), UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.ACCENT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	_distance = UiStyle.label(str(quest.get("distance", "")), _fonts.pixel, 11, UiStyle.MUTED)
	header.add_child(_distance)
	column.add_child(header)
	var title := UiStyle.label(str(quest.get("title", "")), _fonts.title_medium, 19, UiStyle.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var steps := VBoxContainer.new()
	steps.name = "Stappen"
	steps.add_theme_constant_override("separation", 6)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for step: Dictionary in QuestLog.tracker_steps(quest):
		steps.add_child(_step_row(step))
	column.add_child(steps)
	return parts[0]


## A step of a main quest: its box (ticked when done), its text (struck through when done)
## and the experience it gives; see-through while it cannot be done yet.
func _step_row(step: Dictionary) -> Control:
	var done: bool = step.get("done", false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
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
	text.text = step_text(step)
	row.add_child(text)
	if int(step.get("xp", 0)) > 0:
		var points := UiStyle.label("+%d XP" % int(step.xp), _fonts.pixel, 10, UiStyle.MUTED if done else XP_COLOUR)
		points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(points)
	if step.get("locked", false) and not done:
		row.modulate.a = LOCKED_STEP_OPACITY
	return row


## The text of a step as BBCode: its brackets taken literally, struck through when done.
static func step_text(step: Dictionary) -> String:
	var escaped := str(step.get("text", "")).replace("[", "[lb]")
	return "[s]%s[/s]" % escaped if step.get("done", false) else escaped


func _side_quest_panel(quest: Dictionary) -> Control:
	var parts := _panel(UiStyle.SIDE_ACCENT, 0.7, 10, 4)
	var column: VBoxContainer = parts[1]
	column.add_child(UiStyle.label("! " + str(quest.get("label", "ZIJMISSIE")), UiStyle.spaced(_fonts.pixel, 2), 11, UiStyle.SIDE_ACCENT))
	var title := UiStyle.label(str(quest.get("title", "")), _fonts.body, 13, UiStyle.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	return parts[0]
