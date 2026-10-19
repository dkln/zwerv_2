extends SceneTree
## Renders the palette previews of every library item outside the editor, into the
## preview cache (library_builder.gd PREVIEW_CACHE) and the libraries themselves, so the
## editor has nothing left to do ("Creating mesh previews") when it opens a scene.
## Items whose cached preview matches their current import are skipped; "all" renders
## every item again. Renders BATCH items per frame, each in a small viewport of its own;
## an empty render is tried again. Needs a display (not --headless).
## usage: tools/godot.sh --script tools/build_previews.gd [-- all]

const Common = preload("res://tools/tool_common.gd")
const Builder = preload("res://addons/vox_tiles/library_builder.gd")
const BATCH := 48

var _slots := []   # [viewport, camera, mesh instance] per slot


func _init() -> void:
	Common.watchdog(self, 900.0)
	# keep the window drawing: macOS stops drawing windows that are behind others
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var all := "all" in OS.get_cmdline_user_args()
	for i in BATCH:
		_slots.append(_make_slot())
	await process_frame
	var rendered := 0
	var loaded := 0
	for cat in Builder.CATEGORIES:
		var path := Builder.library_path(cat)
		if not ResourceLoader.exists(path):
			continue
		var lib: MeshLibrary = load(path)
		var done := {}   # mesh -> texture: aliases share their tile's mesh
		var todo := []   # item ids still to render
		for id in lib.get_item_list():
			var mesh := lib.get_item_mesh(id)
			if mesh == null or done.has(mesh):
				continue
			var tex: Texture2D = null
			if not all:
				tex = Builder._cached_preview(cat, lib.get_item_name(id), int(mesh.get_meta("source_stamp", 0)))
			if tex:
				done[mesh] = tex
				loaded += 1
			else:
				done[mesh] = null
				todo.append(id)
		# render in batches; empty renders go round once more
		for attempt in 2:
			var again := []
			for start in range(0, todo.size(), BATCH):
				var ids: Array = todo.slice(start, start + BATCH)
				for k in ids.size():
					_frame(_slots[k], lib.get_item_mesh(ids[k]))
				await process_frame
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				for k in ids.size():
					var id: int = ids[k]
					var img: Image = _slots[k][0].get_texture().get_image()
					if Builder.is_blank(img) and attempt == 0:
						again.append(id)
						continue
					var tex := ImageTexture.create_from_image(img)
					var mesh := lib.get_item_mesh(id)
					done[mesh] = tex
					Builder._cache_preview(cat, lib.get_item_name(id), int(mesh.get_meta("source_stamp", 0)), tex)
					rendered += 1
				for slot in _slots:
					slot[2].mesh = null
			todo = again
			if todo.is_empty():
				break
		var changed := false
		for id in lib.get_item_list():
			var tex: Texture2D = done.get(lib.get_item_mesh(id))
			if tex and lib.get_item_preview(id) != tex:
				lib.set_item_preview(id, tex)
				changed = true
		if changed:
			ResourceSaver.save(lib, path)
		print("previews: library '%s' done (%d rendered so far)" % [cat, rendered])
	print("previews: %d rendered, %d from the cache" % [rendered, loaded])
	quit()


## A preview slot: a small transparent viewport with its own world, light and camera.
func _make_slot() -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(Builder.PREVIEW_SIZE, Builder.PREVIEW_SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var item := MeshInstance3D.new()
	vp.add_child(item)
	return [vp, cam, item]


## Puts a mesh in a slot, framed by its bounding box, seen from the front right and above.
func _frame(slot: Array, mesh: Mesh) -> void:
	var box := mesh.get_aabb()
	var centre := box.get_center()
	# fill the picture with the largest dimension, so thin poles and masts stay visible
	var reach := maxf(maxf(box.size.x, box.size.z) * 1.3, box.size.y) * 1.15
	reach = maxf(reach, 0.1)
	slot[2].mesh = mesh
	slot[1].size = reach
	slot[1].look_at_from_position(centre + Vector3(1.0, 0.8, 1.2).normalized() * reach * 2.0, centre)
