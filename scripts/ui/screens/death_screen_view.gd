extends Control
## How the death screen looks (the graphics layer of scripts/ui/screens/death_screen.gd,
## which is the behaviour and has this as its child; death_screen_rules.gd has the logic;
## there is no layout file: its only sizes are those of its letters): a dark red veil over
## the town, "JE BENT DOOD" big in the middle, the line with how it happened (show_reason)
## and the line with the keys, which comes up later than the rest (fade_in). It decides
## nothing: the text and the moment the keys show are handed to it.
##   const DeathScreenView = preload("res://scripts/ui/screens/death_screen_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const TITLE := "JE BENT DOOD"
const KEYS := "[ENTER] OPNIEUW   [ESC] HOOFDMENU"
const TITLE_COLOUR := Color("#FF5D73")
const VEIL_COLOUR := Color(0.25, 0.02, 0.06, 0.55)
const TITLE_FONT_SIZE := 72
const REASON_FONT_SIZE := 18
const KEYS_FONT_SIZE := 12
const ROW_SEPARATION := 14
## Seconds the screen takes to come up, and the line with the keys after it.
const FADE_IN := 0.6
const KEYS_FADE_IN := 0.4

var _title: Label
var _reason: Label
var _keys: Label


func _init() -> void:
	name = "Beeld"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonts := UiStyle.fonts()
	var veil := ColorRect.new()
	veil.color = VEIL_COLOUR
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", ROW_SEPARATION)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_title = UiStyle.label(TITLE, fonts.title, TITLE_FONT_SIZE, TITLE_COLOUR, 7)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_reason = UiStyle.label("", fonts.body, REASON_FONT_SIZE, UiStyle.TEXT, 3)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_reason)
	_keys = UiStyle.label(KEYS, fonts.pixel, KEYS_FONT_SIZE, UiStyle.MUTED, 2)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_keys)


## Writes how it happened under the title.
func show_reason(text: String) -> void:
	_reason.text = text


## Brings the screen up from nothing (FADE_IN s), and the line with the keys `keys_after` s
## from now (when they work).
func fade_in(keys_after: float) -> void:
	modulate.a = 0.0
	_keys.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, FADE_IN)
	fade.tween_property(_keys, "modulate:a", 1.0, KEYS_FADE_IN).set_delay(keys_after - FADE_IN)


## What the big title says.
func title_text() -> String:
	return _title.text


## What the line under the title says (show_reason).
func reason_text() -> String:
	return _reason.text


## What the line with the keys says.
func keys_text() -> String:
	return _keys.text


## How far the line with the keys has come up (0: not to be seen, 1: fully).
func keys_shown() -> float:
	return _keys.modulate.a
