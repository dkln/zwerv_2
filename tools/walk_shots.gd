extends SceneTree
## Screenshots of the test figure (scripts/walker.gd) halfway along each of its routes,
## from behind (as in the tour) and in the iso view, to judge proportions, collisions
## and paths. Saves <out_dir>/wandelaar_<part>_<route>_{achter,iso}.png.
## usage: Godot --script tools/walk_shots.gd -- <out_dir> [part ...]
## Without parts: all parts.

const Common = preload("res://tools/tool_common.gd")
const WorldParts = preload("res://scripts/world_parts.gd")
const Iso = preload("res://scripts/iso_camera.gd")
## Simulated seconds per real second while walking to the middle.
const SPEED := 6


func _init() -> void:
	Common.watchdog(self, 1500)
	var out := Common.arg(0, "/tmp")
	var parts := []
	for i in range(1, Common.arg_count()):
		parts.append(int(Common.arg(i)))
	var sc := Common.instantiate(Common.WORLD)
	sc.get_node("Rondleiding").free()   # the tool loads the parts itself
	var walker := sc.get_node("Wandelaar")
	walker.auto = false
	var cam: Camera3D = sc.get_node("Camera")
	get_root().add_child(sc)
	Common.render_size(self, Vector2i(1600, 1000))
	await process_frame
	if parts.is_empty():
		parts = range(1, WorldParts.part_count(sc) + 1)
	for p in parts:
		WorldParts.show_part(sc, p)
		await walker.routes_ready
		await Common.wait_for_merge(sc)
		for k in walker.routes.size():
			walker.walk(k)
			Engine.time_scale = SPEED
			Engine.physics_ticks_per_second = 60 * SPEED
			Engine.max_physics_steps_per_frame = 4 * SPEED
			# walk to the middle of the path (or the end)
			var limit := 3000
			while limit > 0 and not walker.is_done() and (walker.stats.length == 0.0 or walker.stats.walked < walker.stats.length * 0.5):
				_follow(cam, walker)
				await process_frame
				limit -= 1
			Engine.time_scale = 1
			Engine.physics_ticks_per_second = 60
			walker.paused = true
			var feet: Vector3 = walker.body.global_position
			_follow(cam, walker)
			cam.attributes = null
			await Common.wait_frames(self, 12)
			var name := "wandelaar_%02d_%d" % [p, k + 1]
			Common.save_screenshot(self, out.path_join(name + "_achter.png"))
			Iso.place(cam, feet, 18.0)
			await Common.wait_frames(self, 12)
			Common.save_screenshot(self, out.path_join(name + "_iso.png"))
			print("saved %s: %s" % [name, walker.routes[k].title])
			walker.paused = false
			walker.stop()
	quit()


## Camera behind and above the figure, looking at it (as tour.gd's walk shots).
func _follow(cam: Camera3D, walker: Node) -> void:
	var feet: Vector3 = walker.body.global_position
	var facing: Vector3 = walker.facing
	var at := feet - facing * 4.5 + Vector3.UP * 2.2
	cam.fov = 55.0
	cam.near = 0.1
	cam.global_transform = Transform3D(Basis.looking_at(feet + Vector3.UP * 1.2 - at, Vector3.UP), at)
