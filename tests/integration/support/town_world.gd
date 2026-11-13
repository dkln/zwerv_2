extends RefCounted
## The town the integration tests play in (tests/run_integration_tests.gd,
## tests/integration/support/town_test.gd): started once for all suites that want the same
## world, as every test used to do for itself: the character chosen, scenes/stad.tscn
## without what a test of the game's behaviour does not need (the merged meshes of
## DetailNiveau, the smoke), the traffic there or not, the arrival skipped, the player woken
## and the first story pages closed. reset() puts it back between two tests.

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

## What a suite can ask for (TownTest.world_options):
##   "town"         false: no town at all, an empty tree (the suite builds its own small scene;
##                  reset frees what a test left under the root)
##   "own_process"  true: the suite is not run with the others but in a run of its own
##                  (a measurement, a long simulation, something that changes the engine)
##   "character"    who the player is
##   "traffic"      false: no vehicles; true: as the town has them; a number: that many
##   "without"      nodes of the town left out
##   "settings"     {node path: {property: value}}, set before the town enters the tree
##   "still_camera" true: without the follow camera (Common.instantiate)
##   "wake"         false: the town as the game starts it (the arrival still to come, the
##                  player asleep, the story open); the suite takes it from there
const DEFAULTS := {"town": true, "own_process": false, "character": "martin", "traffic": false,
	"without": ["DetailNiveau", "Rook"], "settings": {}, "still_camera": false, "wake": true}
const START_META := "test_start"
## The story as the town started with it (story_state), and what of the Story that is.
const STORY_META := "test_story"
const STORY_PROPERTIES := ["_started", "_done", "_finished", "_targets", "_xp_given"]
## What a test changed for itself only (set_for_test: [node, property, value before]) and
## the camera it took away (camera_off); reset puts them back.
const CHANGED_META := "test_changed"
const CAMERA_META := "test_camera"
## What was under the root before a world without a town started (reset keeps those).
static var _root_before: Array[Node] = []


## The options of a suite with the defaults filled in, and the key that says which suites
## can share a town (the same options).
static func options_of(asked: Dictionary) -> Dictionary:
	var options := DEFAULTS.duplicate(true)
	options.merge(asked, true)
	(options.without as Array).sort()
	return options


static func key_of(options: Dictionary) -> String:
	return JSON.stringify(options, "", true)


## Starts the town with `options` in `tree` and returns it once the player is awake on the
## street with nothing open (null for a world without a town).
static func start(tree: SceneTree, options: Dictionary) -> Node3D:
	_root_before.assign(tree.root.get_children())
	if not bool(options.town):
		return null
	PlayerCharacter.choose(String(options.character))
	var scene := Common.instantiate(Common.CITY, bool(options.still_camera)) as Node3D
	for node_name: String in options.without:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	if scene.has_node("Verkeer"):
		if typeof(options.traffic) != TYPE_BOOL:
			scene.get_node("Verkeer").vehicle_count = int(options.traffic)
		elif not bool(options.traffic):
			scene.get_node("Verkeer").vehicle_count = 0
	for node_path: String in options.settings:
		var node := scene if node_path == "." else scene.get_node_or_null(node_path)
		if node:
			for property: String in options.settings[node_path]:
				node.set(property, options.settings[node_path][property])
	tree.root.add_child(scene)
	if not bool(options.wake):
		for frame_index in 2:
			await tree.process_frame
		return scene
	var player: Node3D = scene.get_node("Speler")
	if scene.has_node("Volgcamera"):
		scene.get_node("Volgcamera")._end_arrival()
	for frame_index in 600:
		await tree.physics_frame
		if player._placed and not player._sleeping:
			break
	player._wake_up()
	for attempt in 40:
		if not player._sleeping:
			break
		await tree.create_timer(0.1, true).timeout
	for frame_index in 60:
		await tree.process_frame
		await close_screens(tree, scene.get_node_or_null("HUD"))
	scene.set_meta(START_META, {"at": player.global_position, "money": float(player.money),
		"inventory": (player.inventory as Dictionary).duplicate()})
	scene.set_meta(STORY_META, story_state(scene.get_node_or_null("Verhaal")))
	return scene


## How far the story is (Story: the missions started, the steps done, what was rewarded), to
## put back with restore_story; {} without a story.
static func story_state(story: Node) -> Dictionary:
	if story == null:
		return {}
	var state := {}
	for property: String in STORY_PROPERTIES:
		state[property] = story.get(property).duplicate(true)
	return state


## The story back as it was at `state` (story_state): a mission a test started or finished
## is as before again, also in the tracker.
static func restore_story(story: Node, state: Dictionary) -> void:
	if story == null or state.is_empty():
		return
	for property: String in STORY_PROPERTIES:
		story.get(property).assign(state[property].duplicate(true))
	story._update_tracker()


## Sets `property` of `node` (in the town) to `value` for this test only: the next reset
## puts back what it was (the first value remembered, however often a test sets it).
static func set_for_test(scene: Node3D, node: Node, property: String, value: Variant) -> void:
	var changed: Array = scene.get_meta(CHANGED_META, [])
	if not changed.any(func(change: Array) -> bool: return change[0] == node and change[1] == property):
		changed.append([node, property, node.get(property)])
	scene.set_meta(CHANGED_META, changed)
	node.set(property, value)


## Takes the camera away for this test (no current camera: then nothing in the town is out
## of sight, so every vehicle and every person steps every physics step and is drawn
## moving, as in the tools without a camera); the next reset makes it the current one again.
static func camera_off(tree: SceneTree, scene: Node3D) -> void:
	var camera := tree.root.get_camera_3d()
	if camera:
		scene.set_meta(CAMERA_META, camera)
		camera.clear_current(false)


## What set_for_test and camera_off changed, put back.
static func restore_changes(scene: Node3D) -> void:
	for change: Array in scene.get_meta(CHANGED_META, []):
		if is_instance_valid(change[0]):
			(change[0] as Node).set(change[1], change[2])
	scene.set_meta(CHANGED_META, [])
	var camera: Variant = scene.get_meta(CAMERA_META) if scene.has_meta(CAMERA_META) else null
	if camera != null and is_instance_valid(camera):
		(camera as Camera3D).make_current()
	scene.set_meta(CAMERA_META, null)


## Takes the town away again (before the next one).
static func stop(tree: SceneTree, scene: Node3D) -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	var machine := tree.root.get_node_or_null("Automaatscherm")
	if machine:
		machine.free()
	if scene:
		scene.queue_free()
	await clear_root(tree)
	for frame_index in 5:
		await tree.process_frame


## Without a town: what the tests left under the root, freed.
static func clear_root(tree: SceneTree) -> void:
	for node in tree.root.get_children():
		if not _root_before.has(node) and not node.is_queued_for_deletion():
			node.queue_free()
	for frame_index in 2:
		await tree.process_frame


## Everything that holds the game shut, closed: the story box (to its last page and past
## it), the reward screen and the rewards still waiting, a machine's screen, the shop.
static func close_screens(tree: SceneTree, hud: Node) -> void:
	if hud == null:
		return
	for attempt in 6:
		var closed := false
		if hud._story_box != null and hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
			closed = true
		if hud.has_method("rewards_waiting"):
			hud.rewards_waiting().clear()
		while hud.has_method("is_showing_reward") and hud.is_showing_reward():
			hud._reward_screen.next_page()
			closed = true
		if hud.has_method("is_showing_shop") and hud.is_showing_shop():
			hud._shop_screen._close()
			closed = true
		var machine := tree.root.get_node_or_null("Automaatscherm")
		if machine and not machine.is_closing():
			machine.animate = false
			machine.close()
			closed = true
		if not closed:
			break
		await tree.process_frame
	tree.paused = false


## The player on their feet again, whatever a test did to them: a death (run over, starved,
## drowned) let run to its end (the slow motion, the sinking, the death screen up) and
## undone, a body still lying waited for until it has got up, the figure upright.
static func back_on_feet(tree: SceneTree, scene: Node3D) -> void:
	var player: Node3D = scene.get_node_or_null("Speler")
	if player == null or player.get("_dead") == null:
		return
	var hud: Node = scene.get_node_or_null("HUD")
	var was_down: bool = player._dead or player._drowning or player._ragdoll != null
	if player._dead or player._drowning:
		for frame_index in 1200:
			if player._dead and (hud == null or hud._death_layer.visible):
				break
			await tree.process_frame
		if hud:
			hud._death_layer.visible = false
		player._dead = false
		player._drowning = false
		if Engine.time_scale != 1.0:
			player._set_game_speed(1.0)
		var camera := scene.get_node_or_null("Volgcamera")
		if camera and camera.has_method("dramatic_close_up"):
			camera.dramatic_close_up(false)
	for step_index in 1200:
		if player._ragdoll == null and player._rising_left <= 0.0:
			break
		await tree.physics_frame
	if was_down:
		await tree.process_frame
		player._model.transform = Transform3D.IDENTITY
		player._model.idle = true
		for limb: String in ["arm_left", "arm_right", "leg_left", "leg_right"]:
			player._model.pose_limb(limb, Vector3.ZERO)
		player._blink_left = 0.0
		player._invulnerable_left = 0.0


## Between two tests: the screens closed, out of any interior, welcome everywhere again,
## the player back where the town started them with what they had, the game at its speed.
static func reset(tree: SceneTree, scene: Node3D) -> void:
	if scene == null:
		tree.paused = false
		Engine.time_scale = 1.0
		await clear_root(tree)
		return
	var hud: Node = scene.get_node_or_null("HUD")
	var player: Node3D = scene.get_node("Speler")
	var interiors: Node = scene.get_node_or_null("Binnenruimtes")
	Engine.time_scale = 1.0
	restore_changes(scene)
	await back_on_feet(tree, scene)
	await close_screens(tree, hud)
	if interiors:
		# a throw still under way: let it end (the story it ends with is closed after)
		var waited := 0
		while bool(interiors.get("_throwing")) and waited < 900:
			await tree.process_frame
			await close_screens(tree, hud)
			waited += 1
		if interiors.is_inside():
			interiors.call("_end_eviction")
			await interiors._go_out(0)
			for frame_index in 40:
				await tree.process_frame
		interiors._barred_until.clear()
		interiors.set("_offences", {})
		interiors.warnings_given = 0
		interiors.last_warning = {}
	restore_story(scene.get_node_or_null("Verhaal"), scene.get_meta(STORY_META, {}))
	var start: Dictionary = scene.get_meta(START_META, {})
	if not start.is_empty():
		player.inventory = (start.inventory as Dictionary).duplicate()
		player.add_money(float(start.money) - float(player.money))
		player.money_earned = 0.0
		player.teleport(start.at, 0.0)
	if player.has_method("change_stat") and player.get("_stats") != null:
		for stat_name: String in ["gezondheid", "uithoudingsvermogen", "honger"]:
			var stat: Vector2 = player._stats.get(stat_name, Vector2.ZERO)
			player.change_stat(stat_name, stat.y - stat.x)
	await close_screens(tree, hud)
	for frame_index in 10:
		await tree.process_frame
	await close_screens(tree, hud)
