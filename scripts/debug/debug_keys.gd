extends Node
## Debug keys, in a debug build, anywhere in the town (also with a menu open or the game paused):
## - F7: AMOUNT euros, Shift+F7 AMOUNT_BIG. It does not count as earned
##   (PlayerController.add_money, earned = false), so no mission is done by it.
## - F9: XP_AMOUNT experience, Shift+F9 just enough for the next level (the level-up screen).
## - F5: health full, Shift+F5 STAT_STEP health off (a real hurt: it blinks, at 0 you die).
## - F6: hunger full (fed), Shift+F6 STAT_STEP hungrier.
## - F2: stamina full, Shift+F2 STAT_STEP off.
## - F4: overstimulation empty (calm), Shift+F4 STAT_STEP more (full is the bad end).
## (F3 is the stutter meter, frame_meter.gd; F10 and F11 are left alone: macOS takes them.)
## The HUD puts it in the town (GameHud._ready, debug builds only), next to the mission picker
## (F8, mission_picker.gd).

const KEY_MONEY := KEY_F7
const KEY_XP := KEY_F9
const AMOUNT := 10.0
const AMOUNT_BIG := 100.0
const XP_AMOUNT := 100.0
const KEY_HEALTH := KEY_F5
const KEY_HUNGER := KEY_F6
const KEY_STAMINA := KEY_F2
const KEY_OVERSTIMULATION := KEY_F4
const STAT_STEP := 20.0
## What the keys do, as the mission picker shows them (mission_picker.gd): key, without Shift,
## with Shift.
const HELP := [
	["F2", "uithoudingsvermogen vol", "-20"],
	["F4", "overprikkeldheid 0", "+20"],
	["F5", "gezondheid vol", "-20 (schade)"],
	["F6", "honger vol", "-20"],
	["F7", "+€10", "+€100"],
	["F9", "+100 XP", "naar volgend level"],
]
const MONEY_COLOUR := Color("#FFD447")

## The player (scripts/player/player_controller.gd); found in the current scene when empty.
var player: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_MONEY:
			get_viewport().set_input_as_handled()
			give(AMOUNT_BIG if key_event.shift_pressed else AMOUNT)
		KEY_XP:
			get_viewport().set_input_as_handled()
			give_xp(-1.0 if key_event.shift_pressed else XP_AMOUNT)
		KEY_HEALTH:
			get_viewport().set_input_as_handled()
			change_stat("gezondheid", -STAT_STEP if key_event.shift_pressed else INF)
		KEY_HUNGER:
			get_viewport().set_input_as_handled()
			change_stat("honger", -STAT_STEP if key_event.shift_pressed else INF)
		KEY_STAMINA:
			get_viewport().set_input_as_handled()
			change_stat("uithoudingsvermogen", -STAT_STEP if key_event.shift_pressed else INF)
		KEY_OVERSTIMULATION:
			get_viewport().set_input_as_handled()
			change_stat("overprikkeldheid", STAT_STEP if key_event.shift_pressed else -INF)


## Gives the player `euros`, shown rising over them as money found is.
func give(euros: float) -> void:
	if not _find_player("add_money"):
		return
	player.add_money(euros, false)
	var hud := get_parent()
	if hud and hud.has_method("show_floating_number") and player is Node3D:
		hud.show_floating_number((player as Node3D).global_position + Vector3.UP * 2.3, "+€%d" % roundi(euros), MONEY_COLOUR, 18, true)
	print("debug: +€%.2f (nu €%.2f)" % [euros, float(player.money)])


## Gives the player `points` experience (rising over them, as from a step); below zero just
## enough for the next level.
func give_xp(points: float) -> void:
	if not _find_player("add_xp"):
		return
	if points < 0.0:
		points = maxf(float(player.xp_for_level) - float(player.xp), 1.0)
	player.add_xp(points)
	print("debug: +%d XP (level %d, %d / %d)" % [roundi(points), int(player.level), roundi(float(player.xp)), roundi(float(player.xp_for_level))])


## Changes a stat of the player by `amount` (PlayerController.change_stat); INF fills it up,
## -INF empties it.
func change_stat(stat_name: String, amount: float) -> void:
	if not _find_player("change_stat"):
		return
	var now: Vector2 = player.stat(stat_name)
	if amount == INF:
		amount = now.y - now.x
	elif amount == -INF:
		amount = -now.x
	player.change_stat(stat_name, amount)
	var after: Vector2 = player.stat(stat_name)
	print("debug: %s %d -> %d / %d" % [stat_name, roundi(now.x), roundi(after.x), roundi(after.y)])


func _find_player(method: String) -> bool:
	if player == null:
		var scene := get_tree().current_scene
		player = scene.get_node_or_null("Speler") if scene else null
	if player == null or not player.has_method(method):
		push_warning("debugtoetsen: geen speler")
		return false
	return true
