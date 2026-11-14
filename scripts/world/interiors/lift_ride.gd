extends Node3D
## A lift ride, for any building with floors (scenes/binnen/lift.tscn, built by
## tools/build/build_interiors.gd from cabin_plan(); the city hall first,
## scripts/world/interiors/city_hall.gd). Behaviour (docs/CODE_LAGEN.md): the ride itself, in time;
## its logic (which levels, what the display says): lift_ride_rules.gd; where things stand:
## lift_ride_layout.gd; what you see and hear: lift_ride_view.gd. The ride is a scene of its own: the swipe, and you see yourself
## standing in the cabin (a stand-in of your character), the camera from the front, close in;
## the display behind you shows the floor the lift is at, an arrow up or down, a floor every
## FLOOR_SECONDS (the further, the longer); the motor hums while it moves (MOVING_SOUND), the
## view dips as it starts and stops; there the "ding-dong" (DING_SOUND), and under the next
## swipe the building puts you out on that floor (`arrive`). The real player is hidden
## meanwhile. Put the lift somewhere far off the map, out of sight of the rest.
##   const LIFT_SCENE := "res://scenes/binnen/lift.tscn"
##   var lift: Node3D = (load(LIFT_SCENE) as PackedScene).instantiate()
##   add_child(lift)
##   lift.position = Vector3(400, 0, 0)
##   await lift.ride(0, 3, player, func() -> void: ...)   # `arrive`: put the player on floor 3

const LiftRideRules = preload("res://scripts/world/interiors/lift_ride_rules.gd")
const LiftRideLayout = preload("res://scripts/world/interiors/lift_ride_layout.gd")
const LiftRideView = preload("res://scripts/world/interiors/lift_ride_view.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const LIBRARY := LiftRideView.LIBRARY
const PREFIX := LiftRideView.PREFIX
const DING_SOUND := LiftRideView.DING_SOUND
const MOVING_SOUND := LiftRideView.MOVING_SOUND
const FLOOR_SECONDS := LiftRideRules.FLOOR_SECONDS
const ARRIVE_SECONDS := LiftRideRules.ARRIVE_SECONDS
const CAMERA_AT := LiftRideLayout.CAMERA_AT
const LOOK_AT := LiftRideLayout.LOOK_AT

## The floor the lift is at (during a ride the one it is passing).
var floor_number := 0
var riding := false
## Its picture.
var view: LiftRideView


## The plan of the cabin (LiftRideLayout.cabin_plan: the builder lays its tiles from it).
static func cabin_plan() -> Dictionary:
	return LiftRideLayout.cabin_plan()


func _ready() -> void:
	view = LiftRideView.new()
	add_child(view)
	view.build(self)
	_rest(true)


## The ride from floor `from` to `to` for `player` (see the top): `arrive` is called under
## the swipe at the end, to put the player out on that floor. `animate` false: at once.
func ride(from: int, to: int, player: Node3D, arrive: Callable, animate := true) -> void:
	if riding:
		return
	riding = true
	floor_number = from
	var swipe: Node = SwipeTransition.swipe(get_tree()) if animate else null
	if swipe:
		await swipe.covered
	_rest(false)
	_show_stand_in(player)
	if player:
		player.visible = false
	view.show_cabin_camera()
	var direction := LiftRideRules.step(from, to)
	view.show_display(LiftRideRules.display_text(floor_number, LiftRideRules.arrow(from, to)))
	if swipe and is_instance_valid(swipe) and swipe.has_signal("finished"):
		await swipe.finished
	if animate and to != from:
		view.play_jolt()
		view.play_motor(true)
	while floor_number != to:
		view.show_display(LiftRideRules.display_text(floor_number, direction))
		if animate:
			await get_tree().create_timer(LiftRideRules.FLOOR_SECONDS).timeout
		floor_number += direction
	view.show_display(LiftRideRules.display_text(floor_number, 0))
	view.play_motor(false, animate)
	view.play_ding()
	if animate:
		view.play_jolt()
		await get_tree().create_timer(LiftRideRules.ARRIVE_SECONDS).timeout
		swipe = SwipeTransition.swipe(get_tree())
		await swipe.covered
	# out: the camera back, the player back, the building puts them on the floor
	view.hide_stand_in()
	view.show_usual_camera()
	if player:
		player.visible = true
	_rest(true)
	riding = false
	if arrive.is_valid():
		arrive.call()
	if swipe and is_instance_valid(swipe) and swipe.has_signal("finished"):
		await swipe.finished


## The text on the display ("▲ 2", "3").
func display_text() -> String:
	return view.display_text() if view else ""


func motor_running() -> bool:
	return view != null and view.motor_running()


func camera() -> Camera3D:
	return view.camera if view else null


func stand_in() -> Node3D:
	return view.stand_in if view else null


## Not in use: hidden and still.
func _rest(resting: bool) -> void:
	visible = not resting
	process_mode = Node.PROCESS_MODE_DISABLED if resting else Node.PROCESS_MODE_INHERIT


## You in the cabin: the character of `player`, at its scale, in its coat or not.
func _show_stand_in(player: Node3D) -> void:
	var figure_scale := float(player.get("FIGURE_SCALE")) if player and player.get("FIGURE_SCALE") != null else LiftRideRules.FIGURE_SCALE
	var coat: bool = player.wears_coat() if player and player.has_method("wears_coat") else true
	view.show_stand_in(PlayerCharacter.current_id(), figure_scale, coat)
