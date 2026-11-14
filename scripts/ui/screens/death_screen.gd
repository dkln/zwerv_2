extends Control
## The death screen (the node "Dood" of the HUD; GameHud.show_death, when the player dies):
## the town goes on behind a dark red veil, "JE BENT DOOD" big in the middle with how it
## happened. Enter starts again with the same zwerver (the scene reloaded), Escape goes to
## the main menu; the keys only work after KEYS_AFTER s, so a key held while dying does not
## skip it. The music (it fades out, the death tune plays once) is the HUD's.
##   const DeathScreen = preload("res://scripts/ui/screens/death_screen.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const MAIN_MENU_SCENE := "res://scenes/hoofdmenu.tscn"
## How it happened: the cause (PlayerController) -> the line, %s the name of who died.
const CAUSES := {
	"honger": "%s is van de honger omgekomen.",
	"aangereden": "%s is aangereden en niet meer opgestaan.",
	"verdronken": "%s is in het water gevallen en verdronken.",
	"eruit_gegooid": "%s is een gebouw uit gesmeten en niet meer opgestaan.",
}
const UNKNOWN_CAUSE := "%s heeft het niet gered."
const TITLE_COLOUR := Color("#FF5D73")
const VEIL_COLOUR := Color(0.25, 0.02, 0.06, 0.55)
## Seconds before the keys work (so a key held while dying does not skip it).
const KEYS_AFTER := 1.2
const FADE_IN := 0.6

var _reason: Label
var _keys: Label
var _since := 0.0


func _init() -> void:
	name = "Dood"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
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
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title := UiStyle.label("JE BENT DOOD", fonts.title, 72, TITLE_COLOUR, 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_reason = UiStyle.label("", fonts.body, 18, UiStyle.TEXT, 3)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_reason)
	_keys = UiStyle.label("[ENTER] OPNIEUW   [ESC] HOOFDMENU", fonts.pixel, 12, UiStyle.MUTED, 2)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_keys)


## How `who` died of `cause` (a key of CAUSES; anything else: a general line).
static func reason(cause: String, who: String) -> String:
	return String(CAUSES.get(cause, UNKNOWN_CAUSE)) % who


## Shows the screen, fading in: `who` died of `cause`. False when it is showing already.
func open(cause: String, who: String) -> bool:
	if visible:
		return false
	_reason.text = reason(cause, who)
	visible = true
	modulate.a = 0.0
	_keys.modulate.a = 0.0
	_since = Time.get_ticks_msec() / 1000.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, FADE_IN)
	fade.tween_property(_keys, "modulate:a", 1.0, 0.4).set_delay(KEYS_AFTER - FADE_IN)
	return true


func is_open() -> bool:
	return visible


## Whether the keys work yet (KEYS_AFTER s after it opened).
func keys_ready() -> bool:
	return visible and Time.get_ticks_msec() / 1000.0 - _since >= KEYS_AFTER


## A key while the screen shows: Enter again, Escape to the main menu (once keys_ready).
func handle_input(event: InputEvent) -> void:
	if not keys_ready():
		return
	var again := event.is_action_pressed("ui_accept")
	if not again and not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	UiSounds.play(self, "doe")
	await SwipeTransition.swipe(get_tree()).covered
	if again:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
