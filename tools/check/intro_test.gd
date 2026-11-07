extends SceneTree
## Plays the intro (scenes/intro.tscn), breaks it off with a key after a moment and checks
## that the main menu comes up at once, then that its 3D map (loaded in the background)
## arrives. Prints "intro ok" for each step that went well.
## With "volledig" it lets the intro play to the end and prints how long it took.
## usage: Godot --headless --script tools/check/intro_test.gd [-- volledig]

const Common = preload("res://tools/tool_common.gd")


func _init() -> void:
	Common.watchdog(self, 200)
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	get_root().add_child(intro)
	current_scene = intro
	if Common.arg(0, "") == "volledig":
		# the whole intro without breaking it off: how long it takes
		var begin := Time.get_ticks_msec()
		while current_scene == intro:
			await process_frame
		print("intro ok: de hele intro duurt %.1f s" % ((Time.get_ticks_msec() - begin) / 1000.0))
		quit()
		return
	for frame_index in 30:
		await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key)
	var started := Time.get_ticks_msec()
	while current_scene == null or current_scene.name != "Hoofdmenu":
		await process_frame
		if Time.get_ticks_msec() - started > 20000:
			print("FOUT: geen hoofdmenu na de toets")
			quit()
			return
	print("intro ok: hoofdmenu na %d ms" % (Time.get_ticks_msec() - started))
	started = Time.get_ticks_msec()
	while not current_scene.has_node("Menukaart"):
		await process_frame
		if Time.get_ticks_msec() - started > 120000:
			print("FOUT: het 3D-kaartje kwam niet")
			quit()
			return
	print("intro ok: 3D-kaartje na %d ms" % (Time.get_ticks_msec() - started))
	await process_frame
	var moon := current_scene.get_node_or_null("Menukaart/Zonneschijf") as Node3D
	print("intro ok: zon op %s" % moon.global_position if moon else "FOUT: geen zon")
	for library in ["grond", "gebouwen", "details", "props", "grond_lod2", "grond_lod"]:
		if ResourceLoader.has_cached("res://assets/libraries/%s.res" % library):
			print("FOUT: het menu laadde de bibliotheek %s" % library)
	var tram := current_scene.get_node_or_null("Menukaart/Tramlijn1/Tram") as Node3D
	var tram_seen := false
	started = Time.get_ticks_msec()
	while tram and Time.get_ticks_msec() - started < 12000 and not tram_seen:
		await process_frame
		tram_seen = tram.visible
	print("intro ok: tram rijdt (bij %s)" % tram.global_position if tram_seen else "FOUT: geen tram gezien")
	# a column (tractors or the police) within half a minute
	var column_seen := ""
	started = Time.get_ticks_msec()
	while column_seen == "" and Time.get_ticks_msec() - started < 30000:
		await process_frame
		for holder_name in ["Trekkers", "Politie"]:
			var holder := current_scene.get_node_or_null("Menukaart/" + holder_name)
			if holder:
				for vehicle in holder.get_children():
					if vehicle.has_meta("rijdt") and (vehicle as Node3D).visible:
						column_seen = "%s (%s)" % [holder_name, vehicle.name]
	print("intro ok: colonne rijdt: %s" % column_seen if column_seen != "" else "FOUT: geen colonne gezien")
	# a crash (forced): the vehicle becomes a wreck that falls on the floor and goes
	var menu := current_scene
	var driving: Node3D = null
	for holder_name in ["Trekkers", "Politie"]:
		var holder := menu.get_node_or_null("Menukaart/" + holder_name)
		for vehicle in holder.get_children() if holder else []:
			if vehicle.has_meta("rijdt") and (vehicle as Node3D).visible:
				driving = vehicle
	if driving:
		var menu_script: Node = menu if menu.has_method("_crash") else menu.find_children("*", "", true, false).filter(
				func(node: Node) -> bool: return node.has_method("_crash")).front()
		menu_script.call("_crash", driving)
		var wreck := driving.get_parent() as RigidBody3D
		for frame_index in 90:
			await physics_frame
		print("intro ok: wrak op %s" % wreck.global_position if wreck and is_instance_valid(wreck) else "FOUT: geen wrak")
	# the fire: after 30 s (time four times as fast)
	Engine.time_scale = 4.0
	var flames := menu.get_node_or_null("Menukaart/Brand/Vlammen") as GPUParticles3D
	started = Time.get_ticks_msec()
	while flames and not flames.visible and Time.get_ticks_msec() - started < 20000:
		await process_frame
	var fire := menu.get_node_or_null("Menukaart/Brand") as Node3D
	print("intro ok: brand op %s" % fire.global_position if flames and flames.visible else "FOUT: geen brand")
	# it grows: wider and more flames after a while
	var box_at_start := (flames.process_material as ParticleProcessMaterial).emission_box_extents if flames else Vector3.ZERO
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 5000:
		await process_frame
	if flames:
		var box_later := (flames.process_material as ParticleProcessMaterial).emission_box_extents
		print("intro ok: brand groeit (%s -> %s)" % [box_at_start, box_later] if box_later.x > box_at_start.x else "FOUT: brand groeit niet")
	# a tractor that crashes goes up in flames
	var tractor: Node3D = null
	started = Time.get_ticks_msec()
	while tractor == null and Time.get_ticks_msec() - started < 20000:
		await process_frame
		for vehicle in menu.get_node("Menukaart/Trekkers").get_children():
			if vehicle.has_meta("rijdt") and (vehicle as Node3D).visible:
				tractor = vehicle
	if tractor:
		var crasher: Node = menu if menu.has_method("_crash") else menu.find_children("*", "", true, false).filter(
				func(node: Node) -> bool: return node.has_method("_crash")).front()
		crasher.call("_crash", tractor)
		var burning := tractor.get_parent().get_node_or_null("Vlammen") as GPUParticles3D
		print("intro ok: trekker in de fik" if burning else "FOUT: trekkerwrak brandt niet")
	else:
		print("FOUT: geen trekker gezien")
	Engine.time_scale = 1.0
	quit()
