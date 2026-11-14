extends Control
## The death screen (the node "Dood" of the HUD; GameHud.show_death, when the player dies):
## the town goes on behind a dark red veil, "JE BENT DOOD" big in the middle with how it
## happened. Enter starts again with the same zwerver (the scene reloaded), Escape goes to
## the main menu; the keys only work after a moment (KEYS_AFTER), so a key held while dying
## does not skip it. The music (it fades out, the death tune plays once) is the HUD's.
## This is the behaviour layer: open or not, the wait before the keys, what the keys do.
## death_screen_rules.gd has the logic (the line with how it happened, from when the keys
## work), death_screen_view.gd builds the veil and the texts and fades them in.
##   const DeathScreen = preload("res://scripts/ui/screens/death_screen.gd")

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const DeathScreenRules = preload("res://scripts/ui/screens/death_screen_rules.gd")
const DeathScreenView = preload("res://scripts/ui/screens/death_screen_view.gd")
const MAIN_MENU_SCENE := "res://scenes/hoofdmenu.tscn"
## The lines of DeathScreenRules, here for whoever has the screen at hand (the tests of
## the player ask it whether a cause has a line).
const CAUSES := DeathScreenRules.CAUSES

var _view: DeathScreenView
## When the screen opened (seconds on the clock of the engine).
var _since := 0.0


func _init() -> void:
	name = "Dood"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_view = DeathScreenView.new()
	add_child(_view)


## How `who` died of `cause` (DeathScreenRules.reason, here for whoever has the screen at
## hand: the HUD's tests).
static func reason(cause: String, who: String) -> String:
	return DeathScreenRules.reason(cause, who)


## Shows the screen, fading in: `who` died of `cause`. False when it is showing already.
func open(cause: String, who: String) -> bool:
	if visible:
		return false
	_view.show_reason(DeathScreenRules.reason(cause, who))
	visible = true
	_since = Time.get_ticks_msec() / 1000.0
	_view.fade_in(DeathScreenRules.KEYS_AFTER)
	return true


func is_open() -> bool:
	return visible


## Whether the keys work yet (DeathScreenRules.KEYS_AFTER s after it opened).
func keys_ready() -> bool:
	return visible and DeathScreenRules.keys_work(_since, Time.get_ticks_msec() / 1000.0)


## The line that says how it happened, as it stands on the screen ("" before it opened).
func reason_text() -> String:
	return _view.reason_text()


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
