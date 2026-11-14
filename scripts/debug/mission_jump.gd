extends Node
## Debug: straight to a mission (or a step of it), to test it. Start the game with
##
##   -- --snel --missie 2                 the start of MISSIE 2 (its "label"), or
##   -- --snel --missie missie_2_bekend_gezicht
##   -- --snel --missie 2 --stap hofvijver   at that step: the steps before it done
##   -- --snel --missie 2 --plek plein       and you standing there (a place of the map)
##
## Where you stand: --plek; else the "debug_start" of the step you jump to (with --stap), else
## that of the mission (data/missies: a place of the map, as "plein"); else by the one the step
## under way is about (its "persoon": Ome Wim), so you need not walk there first.
## (quick_start.gd puts this on the root). In the city it presses the prologue away, finishes
## the missions the target follows on ("start": "na:<id>", back to the prologue: Story.
## complete_mission) and presses their last pages and reward screens away, until the target
## has started; with --stap it then does its steps before that one (Story.complete_step) and
## presses their pages away. What the target (or that step) shows itself, you see. Then it goes.
## In the game (a debug build) F8 opens the mission picker (scripts/debug/mission_picker.gd),
## which starts the same jump without arguments: start_in_game (the town loaded again).

var target := ""
var step := ""
var place := ""
## How far from the one the step is about you are put (m).
const NEAR_THE_PERSON := 5.0
var _chain: Array[String] = []      # the missions before the target, the first first
var _resolved := false
var _old_scene_id := 0              # the scene being left (start_in_game): not acted on


## Jumps from the game to mission `mission_id` (at step `step_id`, "" = its start): the town is
## loaded again (a clean start, so also back to an earlier mission) and the jump goes on in it.
static func start_in_game(tree: SceneTree, mission_id: String, step_id := "") -> void:
	var jump := new()
	jump.name = "Missiesprong"
	jump.target = mission_id
	jump.step = step_id
	jump._old_scene_id = tree.current_scene.get_instance_id() if tree.current_scene else 0
	tree.root.add_child(jump)
	tree.paused = false
	tree.reload_current_scene()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if target != "":
		return   # given in the game (start_in_game)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--missie")
	if at != -1 and at + 1 < args.size():
		target = args[at + 1]
	at = args.find("--stap")
	if at != -1 and at + 1 < args.size():
		step = args[at + 1]
	at = args.find("--plek")
	if at != -1 and at + 1 < args.size():
		place = args[at + 1]


## True when the game was started to jump (`--missie`).
static func wanted() -> bool:
	return "--missie" in OS.get_cmdline_user_args()


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get_instance_id() == _old_scene_id:
		return
	var story := scene.get_node_or_null("Verhaal")
	var hud := scene.get_node_or_null("HUD")
	if story == null or hud == null or story.missions.is_empty():
		return
	if not _resolved and not _resolve(story):
		return
	if story.is_started(target) and _steps_left(story).is_empty():
		print("missiesprong: %s%s begint" % [target, (", stap " + step) if step != "" else ""])
		_put_the_player(scene, story)
		queue_free()
		return
	# what comes before it: pressed away
	if hud.is_showing_reward():
		hud._reward_screen.next_page()
		return
	if hud.is_showing_story():
		var box: Control = hud._story_box
		box._pages = box._pages.slice(-1)
		box._page_index = 0
		box._next_page()
		return
	if not story.is_started(target):
		for earlier: String in _chain:
			if story.is_started(earlier) and not story.is_finished(earlier):
				story.complete_mission(earlier)
				return
		return
	var left := _steps_left(story)
	if not left.is_empty():
		story.complete_step(target, left[0])


## The target as a mission id ("2": the mission labelled "MISSIE 2"), and the chain before it;
## false (and gone) when there is none such.
func _resolve(story: Node) -> bool:
	var found := ""
	for data: Dictionary in story.missions:
		if str(data.id) == target or str(data.get("label", "")) == "MISSIE " + target:
			found = str(data.id)
	if found == "":
		push_error("missiesprong: geen missie '%s'" % target)
		queue_free()
		return false
	target = found
	_resolved = true
	var current := story.mission(target) as Dictionary
	while str(current.get("start", "")).begins_with("na:"):
		var before := str(current.start).trim_prefix("na:")
		_chain.push_front(before)
		current = story.mission(before)
	return true


## The steps of the target still to do before --stap (none without one, or once there).
func _steps_left(story: Node) -> Array[String]:
	var left: Array[String] = []
	if step == "" or not story.is_started(target):
		return left
	for data_step: Dictionary in story.mission(target).get("stappen", []):
		if str(data_step.id) == step:
			return left
		if not story.step_done(target, str(data_step.id)):
			left.append(str(data_step.id))
	return left


## The player to --plek, or by the one the step under way is about (NEAR_THE_PERSON), facing it.
func _put_the_player(scene: Node, story: Node) -> void:
	var player := scene.get_node_or_null("Speler") as Node3D
	if player == null or not player.has_method("teleport"):
		return
	var spot := Vector2.INF
	var look_at := Vector2.INF
	var data: Dictionary = story.mission(target)
	var start_place := place
	if start_place == "" and step != "":
		start_place = str(story.current_step(data).get("debug_start", ""))
	if start_place == "":
		start_place = str(data.get("debug_start", ""))
	if start_place != "":
		spot = story._place(start_place)
		if spot == Vector2.INF:
			push_error("missiesprong: geen plek '%s'" % start_place)
			return
	else:
		var who := str(story.current_step(story.mission(target)).get("doel", {}).get("persoon", ""))
		var characters := scene.get_node_or_null("Personages")
		if who == "" or characters == null or not characters.has_character(who):
			return
		characters.appear(who)
		look_at = characters.spot_of(who)
		if look_at == Vector2.INF:
			return
		spot = look_at + Vector2(NEAR_THE_PERSON, 0.0)
	var yaw := player.rotation.y
	if look_at != Vector2.INF:
		var towards := look_at - spot
		yaw = atan2(-towards.x, -towards.y)
	player.teleport(Vector3(spot.x, player.global_position.y + 2.0, spot.y), yaw)
	print("missiesprong: speler bij %s" % spot)
