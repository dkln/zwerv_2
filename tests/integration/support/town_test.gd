extends RefCounted
## The base of an integration test suite (tests/integration/<category>/test_*.gd that
## `extends "res://tests/integration/support/town_test.gd"`): its functions whose name starts
## with "test_" are the tests, each a coroutine that gets a `test` to check things on
## (test.check(condition, "what"), as the unit tests) and plays its scenario in the town.
## The runner (tests/run_integration_tests.gd) starts the town once for all suites that
## want the same world (world_options) and calls reset() before every test, so a test finds
## the player awake on the street with nothing open; what the tests share is here:
## waiting (frames, seconds), the screens (close_screens), going in and out of the
## interiors (enter, leave_interior) and putting the player somewhere (put_player).
##   extends "res://tests/integration/support/town_test.gd"
##   func test_begging_gets_you_warned(test) -> void:
##       await enter("snackbar")
##       ...
##       test.check(interiors.warnings_given == 1, "een waarschuwing")

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const TownWorld = preload("res://tests/integration/support/town_world.gd")

## Set by the runner: the tree, the town and what every test reaches for in it.
var tree: SceneTree
var scene: Node3D
var player: Node3D
var hud: Node
var interiors: Node


## The world this suite wants (TownWorld.DEFAULTS: "character", "traffic", "without",
## "settings", "town": false for no town at all, "own_process": true for a run of its own,
## ...); suites that want the same share one town.
static func world_options() -> Dictionary:
	return {}


## Argument `index` given to this suite on the command line
## (tests/run_integration_tests.sh <name> -- <arguments>), or `default`.
func argument(index: int, default := "") -> String:
	return Common.arg(index + 1, default)


## Adds `node` to the root of the tree (a suite without a town builds its own scene so; the
## reset after the test frees it) and returns it.
func add_to_root(node: Node) -> Node:
	tree.root.add_child(node)
	return node


## Sets `property` of `node` to `value` for this test only (the reset before the next test
## puts back what it was): the hour, how fast the crowd changes, a setting of the traffic.
func set_for_test(node: Node, property: String, value: Variant) -> void:
	TownWorld.set_for_test(scene, node, property, value)


## No current camera for this test: nothing in the town counts as out of sight, so
## everything steps every physics step (the reset gives the camera back).
func camera_off() -> void:
	TownWorld.camera_off(tree, scene)


## The view held still on `focus` (global) with `view_size` metres in view, in the usual iso
## direction: the follow camera stops for this test (the reset lets it follow again).
## Returns the camera.
func hold_view(focus: Vector3, view_size: float) -> Camera3D:
	var follow := scene.get_node_or_null("Volgcamera")
	if follow:
		set_for_test(follow, "process_mode", Node.PROCESS_MODE_DISABLED)
	var camera := tree.root.get_camera_3d()
	camera.rotation_degrees = Common.Iso.ROTATION
	camera.global_position = Common.Iso.position(focus, view_size)
	return camera


## `count` physics steps on.
func physics_frames(count := 1) -> void:
	for frame_index in count:
		await tree.physics_frame


## `count` frames on.
func frames(count := 1) -> void:
	for frame_index in count:
		await tree.process_frame


## `seconds` of game time on (the runner lets game time run faster than the clock).
func seconds(duration: float) -> void:
	await tree.create_timer(duration, true).timeout


## Waits until `condition` holds, at most `most_seconds` of game time; returns whether it did.
func wait_until(condition: Callable, most_seconds := 20.0) -> bool:
	var waited := 0.0
	while not bool(condition.call()):
		if waited >= most_seconds:
			return false
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
	return true


## Everything that holds the game shut: the story box, the reward screen (also the ones
## still waiting), a machine's screen, the shop, the pause.
func close_screens() -> void:
	await TownWorld.close_screens(tree, hud)


## The story's pages out of the way at once (to the last page and past it) and the reward
## screens after them, without a frame passing and leaving the rest as it is (a shop or a
## machine stays open, the pause as it was), unlike close_screens.
func skip_story() -> void:
	if hud._story_box.is_showing():
		hud._story_box._pages = hud._story_box._pages.slice(-1)
		hud._story_box._page_index = 0
		hud._story_box._next_page()
	if hud.has_method("rewards_waiting"):
		hud.rewards_waiting().clear()
	while hud.has_method("is_showing_reward") and hud.is_showing_reward():
		hud._reward_screen.next_page()


## The player as at the start of a test: outside, awake, nothing open, welcome everywhere,
## the game at its own speed.
func reset() -> void:
	await TownWorld.reset(tree, scene)


## Goes into the first interior of `kind` (Interiors KINDS: "snackbar", "centraal", "derrek",
## "alfred_steyhn", "stadhuis"; `which`: the how-manieth, -1 the last); returns its way in.
func enter(kind: String, which := 0) -> Dictionary:
	var ways: Array = interiors.ways_in().filter(func(way: Dictionary) -> bool: return String(way.kind) == kind)
	if ways.is_empty():
		return {}
	await interiors.enter(ways[which])
	await frames(30)
	return ways[which]


## Out of the interior the player is in, through door `door_index` (0: the one of the way in).
func leave_interior(door_index := 0) -> void:
	if interiors.is_inside():
		await interiors.leave(door_index)
		await frames(30)


## The player put at `at` (global), facing `heading` (radians), what they stood at before
## forgotten and the physics a few steps on: the HUD then offers what is to do there (prompts).
func stand_at(at: Vector3, heading := 0.0) -> void:
	player.teleport(at, heading)
	player._talk_partner = null
	for step_index in 6:
		await tree.physics_frame


## `key` pressed down or let go as the keyboard would (Input: what the player walks by).
static func press_key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = down
	Input.parse_input_event(event)


## `duration` seconds on that do not slow down with the game (Engine.time_scale: the slow
## motion of a death or a throw), as the game's own timers for those.
func unscaled_seconds(duration: float) -> void:
	await tree.create_timer(duration, true, false, true).timeout


## A key pressed (not released), to hand to a screen's handle_input.
static func key_press(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


## The player put at `at` (global), facing `heading` (radians).
func put_player(at: Vector3, heading := 0.0) -> void:
	player.teleport(at, heading)
	await frames(4)


## The player put at `at` in the space of `space` (an interior: its own coordinates), with
## no one to talk to left over from where they stood; a few physics frames on, so the action
## of the spot (a door, a shelf, a gate) is offered.
func put_player_in(space: Node3D, at: Vector3, heading := 0.0) -> void:
	player.teleport(space.to_global(at), heading)
	player._talk_partner = null
	for frame_index in 4:
		await tree.physics_frame


## The actions offered at the bottom of the screen now ([["E", "Naar binnen"]]; empty: none).
func prompts() -> Array:
	return hud._action_prompts.actions() if hud._action_prompts.visible else []


## Does what [E] does where the player stands: through the door, the gate, the shelf's product
## taken (the go_through of what the player is at).
func use_prompt() -> void:
	if player._talk_partner and player._talk_partner.has_method("go_through"):
		player._talk_partner.go_through()


## Through the door the player stands at, as [E] does (use_prompt), and waited for: the walk
## swipe, until the
## player is on the other side (inside or outside) or, for a door that stays shut, a while.
func use_door() -> void:
	var was_inside: bool = interiors.is_inside()
	use_prompt()
	await wait_until(func() -> bool: return interiors.is_inside() != was_inside, 10.0)
	await frames(30)
