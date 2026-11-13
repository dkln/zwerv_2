extends SceneTree
## Where the time of starting the town goes (for the integration tests, which all load it):
## reading scenes/stad.tscn, making its nodes, adding them to the tree (every _ready), and
## the first frames after (deferred set-up: the traffic, the interiors, the minimap). Per
## node of the town the time its own entering of the tree took (the slowest first).
##   tools/godot.sh --headless --script tools/check/load_profile.gd

const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self, 200)
	var started := Time.get_ticks_usec()
	# "-- binair": read the binary copy (user://stad_proef.scn) first, in a fresh run
	var binary := "user://stad_proef.scn"
	var from_binary := Common.arg(0, "") == "binair" and ResourceLoader.exists(binary)
	var packed: PackedScene = load(binary) if from_binary else load(Common.CITY)
	var read_at := Time.get_ticks_usec()
	if not from_binary:
		ResourceSaver.save(packed, binary)
	print("bron        %s" % (binary if from_binary else Common.CITY))
	var scene := packed.instantiate()
	# as the integration tests: without the merged meshes (their own test: test_fps)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	var made_at := Time.get_ticks_usec()
	print("lezen       %6.0f ms" % ((read_at - started) / 1000.0))
	print("maken       %6.0f ms" % ((made_at - read_at) / 1000.0))
	# every child of the town added on its own, its time measured
	var children: Array[Node] = []
	for child in scene.get_children():
		children.append(child)
	for child in children:
		scene.remove_child(child)
	# one frame first: then the root is in the tree and every _ready runs as it is added
	await process_frame
	get_root().add_child(scene)
	var timings: Array = []
	var after_timings: Array = []
	for child in children:
		var before := Time.get_ticks_usec()
		scene.add_child(child)
		timings.append([(Time.get_ticks_usec() - before) / 1000.0, String(child.name)])
		# what it puts off to the next frames (call_deferred, its first _process)
		before = Time.get_ticks_usec()
		for frame_index in 3:
			await process_frame
		after_timings.append([(Time.get_ticks_usec() - before) / 1000.0, String(child.name)])
	after_timings.sort_custom(func(first: Array, second: Array) -> bool: return first[0] > second[0])
	print("uitgesteld werk (3 frames na het toevoegen):")
	for timing: Array in after_timings.slice(0, 12):
		print("    %6.0f ms  %s" % [timing[0], timing[1]])
	var added_at := Time.get_ticks_usec()
	print("in de boom  %6.0f ms" % ((added_at - made_at) / 1000.0))
	timings.sort_custom(func(first: Array, second: Array) -> bool: return first[0] > second[0])
	for timing: Array in timings.slice(0, 12):
		print("    %6.0f ms  %s" % [timing[0], timing[1]])
	var frame_times: Array[float] = []
	for frame_index in 120:
		var before := Time.get_ticks_usec()
		await process_frame
		frame_times.append((Time.get_ticks_usec() - before) / 1000.0)
	var total := 0.0
	for frame_time in frame_times:
		total += frame_time
	var slow := []
	for frame_index in frame_times.size():
		if frame_times[frame_index] > 50.0:
			slow.append("%d: %d ms" % [frame_index, roundi(frame_times[frame_index])])
	print("120 frames  %6.0f ms (trage: %s)" % [total, ", ".join(slow)])
	print("totaal      %6.0f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	Common.finish(self, 0)
