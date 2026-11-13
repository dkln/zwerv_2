extends SceneTree
## Finds what makes a frame slow now and then: loads the city in the game's own view (the
## follow camera, the player standing still), waits for the descent, then measures every
## frame for <seconds>. Between the scene's top-level nodes it puts timing markers (the tree
## processes in order), so each frame's _process and _physics_process time is split per
## top-level node (with everything under it). Prints the slow frames (more than SPIKE_FACTOR
## times the median) with the nodes that cost the most in them, and per node how often it
## was the main cost of a slow frame.
## usage: tools/godot.sh --headless --script tools/check/stutter_profile.gd -- <seconds>

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const SPIKE_FACTOR := 2.5
const SPIKE_MIN_MS := 6.0


class Marker extends Node:
	var stamps: Dictionary   # shared: marker index -> usec
	var physics_stamps: Dictionary
	var index := 0
	var on_physics_end := Callable()   # only the last marker: sums up the physics step

	func _process(_delta: float) -> void:
		stamps[index] = Time.get_ticks_usec()

	func _physics_process(_delta: float) -> void:
		physics_stamps[index] = Time.get_ticks_usec()
		if on_physics_end.is_valid():
			on_physics_end.call()


var _names: Array[String] = []
var _stamps := {}
var _physics_stamps := {}
var _physics_cost := {}   # this frame: node name -> usec (summed over physics steps)
var _physics_steps := 0   # this frame


func _init() -> void:
	var seconds := Common.arg_float(0, 40.0)
	Common.watchdog(self, seconds + 200.0)
	PlayerCharacter.choose("martin")
	Engine.max_fps = 0
	var scene := Common.instantiate(Common.CITY, false)
	# markers between the top-level nodes: marker k stands before node k
	var children := scene.get_children()
	for child_index in children.size() + 1:
		var marker := Marker.new()
		marker.index = child_index
		marker.stamps = _stamps
		marker.physics_stamps = _physics_stamps
		marker.name = "Meetpunt%d" % child_index
		scene.add_child(marker)
		if child_index < children.size():
			_names.append(String(children[child_index].name))
			scene.move_child(marker, children[child_index].get_index())
		else:
			marker.on_physics_end = _collect_physics
	_names.append("(einde)")
	get_root().add_child(scene)
	await Common.wait_for_merge(scene)
	var player: Node3D = scene.get_node("Speler")
	var camera: Node = scene.get_node("Volgcamera")
	var hud: Node = scene.get_node("HUD")
	for frame_index in 600:
		await process_frame
		if player._placed and not camera.is_arriving():
			break
	if player._sleeping:
		player._wake_up()
	for frame_index in 240:
		await process_frame
		if hud._story_box != null and hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
		# and the reward screen after it (a task done: GameHud.show_reward)
		if hud.has_method("rewards_waiting"):
			hud.rewards_waiting().clear()
		while hud.has_method("is_showing_reward") and hud.is_showing_reward():
			hud._reward_screen.next_page()
	# the merging (DetailNiveau) may start late and pauses the game while it runs
	var detail: Node = scene.get_node_or_null("DetailNiveau")
	var calm_frames := 0
	var waited_from := Time.get_ticks_msec()
	while calm_frames < 120 and Time.get_ticks_msec() - waited_from < 60000:
		await process_frame
		if hud._story_box != null and hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
		# and the reward screen after it (a task done: GameHud.show_reward)
		if hud.has_method("rewards_waiting"):
			hud.rewards_waiting().clear()
		while hud.has_method("is_showing_reward") and hud.is_showing_reward():
			hud._reward_screen.next_page()
		var busy: bool = paused or (detail != null and detail.has_method("is_merging") and detail.is_merging())
		calm_frames = 0 if busy else calm_frames + 1
	print("rustig na %.1f s (gepauzeerd %s, samenvoegen %s)" % [(Time.get_ticks_msec() - waited_from) / 1000.0,
		paused, detail != null and detail.has_method("is_merging") and detail.is_merging()])
	print("meten: %.0f s, stilstaand in het spelbeeld" % seconds)
	await _measure(seconds)
	quit()


func _order_check() -> bool:
	for marker_index in range(1, _names.size()):
		if not _stamps.has(marker_index) or _stamps[marker_index] < _stamps[marker_index - 1]:
			return false
	return true


func _measure(seconds: float) -> void:
	var frames: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec() - started < seconds * 1000000.0:
		_physics_cost = {}
		_physics_steps = 0
		await process_frame
		var now := Time.get_ticks_usec()
		var costs := {}
		for marker_index in range(0, _names.size() - 1):
			if _stamps.has(marker_index) and _stamps.has(marker_index + 1):
				costs[_names[marker_index]] = _stamps[marker_index + 1] - _stamps[marker_index]
		frames.append({"at": (now - started) / 1000000.0, "ms": (now - last) / 1000.0,
			"process": costs, "physics": _physics_cost.duplicate(),
			"steps": _physics_steps, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"bodies": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
			"pairs": int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))})
		last = now
	print("volgorde meetpunten klopt: ", _order_check())
	var sorted_ms: Array = frames.map(func(frame: Dictionary) -> float: return frame.ms)
	sorted_ms.sort()
	var median: float = sorted_ms[sorted_ms.size() / 2]
	var threshold := maxf(median * SPIKE_FACTOR, SPIKE_MIN_MS)
	print("frames %d, mediaan %.1f ms, p99 %.1f ms, traagst %.1f ms; hapering = boven %.1f ms" % [
		frames.size(), median, sorted_ms[int(sorted_ms.size() * 0.99)], sorted_ms[-1], threshold])
	# average cost per node per frame
	var totals := {}
	for frame in frames:
		for kind in ["process", "physics"]:
			for node_name in frame[kind]:
				var key: String = "%s %s" % [kind, node_name]
				totals[key] = totals.get(key, 0) + frame[kind][node_name]
	var total_keys := totals.keys()
	total_keys.sort_custom(func(a, b) -> bool: return totals[a] > totals[b])
	print("gemiddeld per frame:")
	for key in total_keys.slice(0, 12):
		print("  %-32s %.2f ms" % [key, totals[key] / 1000.0 / frames.size()])
	var blame := {}
	var spikes := 0
	var spike_times: Array[float] = []
	for frame in frames:
		if frame.ms <= threshold or frame.at < 1.0:
			continue
		spikes += 1
		spike_times.append(frame.at)
		var parts := []
		for kind in ["process", "physics"]:
			for node_name in frame[kind]:
				parts.append(["%s %s" % [kind, node_name], frame[kind][node_name]])
		parts.sort_custom(func(a, b) -> bool: return a[1] > b[1])
		var accounted := 0
		for part in parts:
			accounted += part[1]
		var top := parts.slice(0, 3).map(func(part) -> String: return "%s %.1f" % [part[0], part[1] / 1000.0])
		print("  %6.2f s  %5.1f ms  (scripts %.1f ms)  %s  | stappen %d, physics %.1f ms, process %.1f ms, actief %d, paren %d" % [
			frame.at, frame.ms, accounted / 1000.0, ", ".join(top), frame.steps, frame.physics_ms, frame.process_ms, frame.bodies, frame.pairs])
		if not parts.is_empty():
			blame[parts[0][0]] = blame.get(parts[0][0], 0) + 1
	print("haperingen: %d" % spikes)
	var gaps := []
	for spike_index in range(1, spike_times.size()):
		gaps.append("%.2f" % (spike_times[spike_index] - spike_times[spike_index - 1]))
	print("tijd tussen haperingen (s): ", " ".join(gaps))
	print("grootste kosten in een hapering: ", blame)


func _collect_physics() -> void:
	# called by the last marker at the end of each physics step
	_physics_steps += 1
	for marker_index in range(0, _names.size() - 1):
		if _physics_stamps.has(marker_index) and _physics_stamps.has(marker_index + 1):
			var node_name: String = _names[marker_index]
			_physics_cost[node_name] = _physics_cost.get(node_name, 0) + _physics_stamps[marker_index + 1] - _physics_stamps[marker_index]
