extends Node3D
## The finest level of a merged layer (LevelOfDetail, layer_baker.gd), streamed: the game
## looks from close by (some tens of metres in view), so of the whole town only what is round
## the camera is ever seen at that level. Its chunk meshes are saved per region of
## REGION_METRES (save_regions: a folder with one scene per region, the materials they share
## and index.json with the places of the regions), and this node, standing in for the whole baked layer (the same name and
## transform), loads the regions within LOAD_DISTANCE of what it is told to keep round
## (update: the camera's focus, the player) in a thread, a few at a time, and drops them
## again beyond DROP_DISTANCE. So the town starts without loading (and sending to the video
## card) the fine meshes of all of it, and holds far less in memory.
## `regions_changed` fires when chunks came or went (BuildingFade keeps a list of them).
##   RegionStream.save_regions(baked, "user://merged/stad_Gebouwen__1a2b")
##   var stream := RegionStream.open("user://merged/stad_Gebouwen__1a2b", "Gebouwen_merged", grid.transform)
##   stream.update([camera_focus, player.global_position])

signal regions_changed

const REGION_METRES := 32.0
## Metres from an anchor to the nearest point of a region within which it is loaded, and
## beyond which it is dropped again (the difference: no loading and dropping to and fro).
## The finest level is shown up to LevelOfDetail.coarse_from (100 m in view: 50 m either
## side of what the camera looks at, more along the diagonal of the screen, and what casts
## its shadow into view); the game itself looks from much closer (18 to 44 m in view).
const LOAD_DISTANCE := 80.0
const DROP_DISTANCE := 130.0
## Regions loading at once (headless one: the dummy rendering server is not thread-safe).
const LOADS_AT_ONCE := 3
## Regions put into the scene per update (a frame) once loaded; the others wait their turn.
const PLACED_PER_UPDATE := 1
const INDEX_FILE := "index.json"
const NOT_LOADED := 0
const LOADING := 1
const LOADED := 2

var folder := ""
## Per region: {"path", "rect": Rect2 (x, z in this node's space), "state", "node"}.
var _regions: Array[Dictionary] = []
var _loading := 0


## Whether `region_folder` holds a whole saved level (its index is written last).
static func is_saved(region_folder: String) -> bool:
	return FileAccess.file_exists(region_folder.path_join(INDEX_FILE))


## Saves the chunks of `baked` (a baked layer: its children) per region into
## `region_folder`; `baked` keeps its children. The index last: only a whole save counts.
static func save_regions(baked: Node3D, region_folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(region_folder)
	# the materials are shared by all regions: one that is not a file of the project by
	# itself gets a file of its own here, so no region saves a copy of it
	# (a copy per region: more to load, more to draw, the fade shaders compiled per region)
	var shared_materials := 0
	for child in baked.get_children():
		var instance := child as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			# (one inside a library file counts too: a scene saves its own copy of such a one)
			var its_own_file := material != null and material.resource_path.begins_with("res://") \
					and not material.resource_path.contains("::")
			if material == null or its_own_file or material.resource_path.begins_with(region_folder):
				continue
			var material_path := region_folder.path_join("materiaal_%d.res" % shared_materials)
			shared_materials += 1
			ResourceSaver.save(material, material_path, ResourceSaver.FLAG_COMPRESS)
			material.take_over_path(material_path)
	var by_region := {}
	for child in baked.get_children():
		var spatial := child as Node3D
		if spatial == null:
			continue
		var centre := spatial.position
		if spatial is MeshInstance3D and (spatial as MeshInstance3D).mesh:
			centre = (spatial.transform * (spatial as MeshInstance3D).get_aabb()).get_center()
		var region := Vector2i(floori(centre.x / REGION_METRES), floori(centre.z / REGION_METRES))
		if not by_region.has(region):
			by_region[region] = []
		(by_region[region] as Array).append(spatial)
	var index := []
	for region: Vector2i in by_region:
		var holder := Node3D.new()
		holder.name = "Regio_%d_%d" % [region.x, region.y]
		var bounds := Rect2()
		var first := true
		for spatial: Node3D in by_region[region]:
			var copy := spatial.duplicate() as Node3D
			holder.add_child(copy)
			copy.owner = holder
			var box := AABB(spatial.position, Vector3.ZERO)
			if spatial is MeshInstance3D and (spatial as MeshInstance3D).mesh:
				box = spatial.transform * (spatial as MeshInstance3D).get_aabb()
			var area := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
			bounds = area if first else bounds.merge(area)
			first = false
		var packed := PackedScene.new()
		packed.pack(holder)
		var file_name := "regio_%d_%d.scn" % [region.x, region.y]
		ResourceSaver.save(packed, region_folder.path_join(file_name), ResourceSaver.FLAG_COMPRESS)
		holder.free()
		index.append({"file": file_name, "x": bounds.position.x, "z": bounds.position.y, "width": bounds.size.x, "depth": bounds.size.y})
	var file := FileAccess.open(region_folder.path_join(INDEX_FILE), FileAccess.WRITE)
	file.store_string(JSON.stringify(index))
	file.close()


## The stream of the level saved in `region_folder`, named and placed as the baked layer
## would be; nothing loaded yet (update).
static func open(region_folder: String, node_name: String, placed: Transform3D) -> Node3D:
	var stream: Node3D = (load("res://scripts/world/town/region_stream.gd") as GDScript).new()
	stream.name = node_name
	stream.transform = placed
	stream.set("folder", region_folder)
	stream.call("_read_index")
	return stream


func _read_index() -> void:
	_regions.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(INDEX_FILE)))
	if not parsed is Array:
		return
	for entry: Dictionary in parsed:
		_regions.append({"path": folder.path_join(String(entry.file)),
			"rect": Rect2(float(entry.x), float(entry.z), float(entry.width), float(entry.depth)),
			"state": NOT_LOADED, "node": null})


## Loads what is near one of `anchors` (global positions) and drops what is far from all
## of them; call it every frame (cheap: a distance per region, and the loads under way).
func update(anchors: Array) -> void:
	var local_anchors: Array[Vector2] = []
	for anchor: Vector3 in anchors:
		var local := to_local(anchor) if is_inside_tree() else transform.affine_inverse() * anchor
		local_anchors.append(Vector2(local.x, local.z))
	var most := 1 if DisplayServer.get_name() == "headless" else LOADS_AT_ONCE
	var changed := false
	# loaded in the thread, but put into the scene (instantiate, add_child: the main thread,
	# and the meshes go to the video card) at most PLACED_PER_UPDATE a frame, so several
	# regions done at once do not make one frame stutter; the rest waits a frame, loaded
	var placed := 0
	for region in _regions:
		var distance := INF
		for anchor in local_anchors:
			distance = minf(distance, _distance_to(region.rect, anchor))
		match int(region.state):
			NOT_LOADED:
				if distance <= LOAD_DISTANCE and _loading < most:
					ResourceLoader.load_threaded_request(String(region.path))
					region.state = LOADING
					_loading += 1
			LOADING:
				var status := ResourceLoader.load_threaded_get_status(String(region.path))
				if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					continue
				if status == ResourceLoader.THREAD_LOAD_LOADED and placed >= PLACED_PER_UPDATE:
					continue   # loaded: put in on a next frame
				placed += 1
				_loading -= 1
				var packed := ResourceLoader.load_threaded_get(String(region.path)) as PackedScene if status == ResourceLoader.THREAD_LOAD_LOADED else null
				if packed == null:
					region.state = NOT_LOADED
					continue
				var node := packed.instantiate() as Node3D
				add_child(node)
				region.node = node
				region.state = LOADED
				changed = true
			LOADED:
				if distance > DROP_DISTANCE:
					if is_instance_valid(region.node):
						(region.node as Node).queue_free()
					region.node = null
					region.state = NOT_LOADED
					changed = true
	if changed:
		regions_changed.emit()


## Whether every region near one of `anchors` (global) is there.
func is_ready_around(anchors: Array) -> bool:
	return share_ready_around(anchors) >= 1.0


## The share (0..1) of the regions near `anchors` (global) that are there.
func share_ready_around(anchors: Array) -> float:
	var wanted := 0
	var there := 0
	for region in _regions:
		for anchor: Vector3 in anchors:
			var local := to_local(anchor) if is_inside_tree() else transform.affine_inverse() * anchor
			if _distance_to(region.rect, Vector2(local.x, local.z)) <= LOAD_DISTANCE:
				wanted += 1
				if int(region.state) == LOADED:
					there += 1
				break
	return 1.0 if wanted == 0 else float(there) / wanted


## How many regions there are, and how many are loaded now (for the checks).
func region_counts() -> Vector2i:
	var loaded := 0
	for region in _regions:
		if int(region.state) == LOADED:
			loaded += 1
	return Vector2i(_regions.size(), loaded)


static func _distance_to(rect: Rect2, point: Vector2) -> float:
	var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	return nearest.distance_to(point)
