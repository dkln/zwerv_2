extends Node
## Level of detail and performance for the world scene (the "DetailNiveau" node).
##
## - LOD switching: for each GridMap in `layers` a coarse ("_lod") and a very coarse
##   ("_lod2") copy are created at startup with the LOD MeshLibraries that
##   library_builder.gd writes next to the normal one. Depending on the zoom (view size,
##   see iso_camera.gd) exactly one of the three is visible.
## - Merging: the layers in `merge_layers` are additionally baked into chunk meshes
##   without hidden faces (layer_baker.gd), per LOD level. The baked nodes replace the
##   GridMap rendering; the GridMap itself stays (hidden) for collisions and editing.
##   Baking takes long, so results are cached as scenes in user://merged, keyed on the
##   scene, layer, cell data, transform, library modification time and Bakker.VERSION.
##   While merging, an optional loading screen is shown; `merge_finished` fires when done.
## - Distance culling: the Details and Props layers are hidden when zoomed out.
## - Shadow distance and depth of field (tilt-shift) follow the camera distance.
##
## You just edit the normal GridMaps; all copies are created automatically.

const Bakker = preload("res://scripts/layer_baker.gd")
const Iso = preload("res://scripts/iso_camera.gd")
const CACHE_DIR := "user://merged"
## File-name suffixes of the MeshLibraries per LOD level: normal, coarse, very coarse.
const LEVEL_SUFFIXES := ["", "_lod", "_lod2"]

## All layers have been merged (or there was nothing to merge).
signal merge_finished

@export var camera_path := NodePath("../Camera")
@export var sun_path := NodePath("../Zon")
## GridMap layers (node names under the scene root) that get LOD copies.
@export var layers: Array[String] = ["Grond", "Gebouwen"]
## These layers are merged at startup into large meshes without hidden
## faces (scripts/layer_baker.gd); the GridMap itself stays for collisions and editing.
@export var merge_layers: Array[String] = ["Gebouwen", "Grond"]
## Layers in which tiles are as tall as the cell (top face may go under a neighbouring block).
@export var hide_top_layers: Array[String] = ["Gebouwen"]
## From this zoom size (metres in view, see scripts/iso_camera.gd) coarse tiles are used.
@export var coarse_from := 100.0
## From this zoom size the very coarse tiles (25 cm blocks).
@export var very_coarse_from := 130.0
## From this zoom size (metres in view) the Details layer is hidden.
@export var details_until := 120.0
## From this zoom size (metres in view) the Props layer is hidden.
@export var props_until := 300.0
## Shadow distance = camera-ground distance + factor * zoom size (metres).
@export var shadow_factor := 1.0
## Depth of field (tilt-shift) scales with the distance to the ground.
@export var depth_of_field := true
## Show a loading screen while merging is in progress.
@export var loading_screen := true

var _cam: Camera3D
var _sun: DirectionalLight3D
## Per layer the nodes per LOD level: [normal, coarse, very coarse]; null = level missing.
## Before merging these are GridMaps, after merging the baked Node3Ds.
var _pairs := []
## LOD level currently shown (-1 = reapply on the next frame).
var _level := -1
## Number of layers still being merged.
var _busy := 0
var _screen: CanvasLayer
var _screen_label: Label
var _progress := {}   # "<layer><suffix>" -> fraction done (0..1) of every merge job


## Creates the LOD copies of each layer and starts merging (asynchronously).
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cam = get_node_or_null(camera_path)
	_sun = get_node_or_null(sun_path)
	var root := get_parent()
	for layer_name in layers:
		var gm := root.get_node_or_null(layer_name) as GridMap
		if gm == null or gm.mesh_library == null:
			continue
		var pair := [gm]
		for suffix in LEVEL_SUFFIXES.slice(1):
			var path := _library_path(gm, suffix)
			if not ResourceLoader.exists(path):
				pair.append(null)
				continue
			pair.append(_lod_copy(gm, layer_name + suffix, load(path)))
		_pairs.append(pair)
		if layer_name in merge_layers:
			_busy += 1
			for suffix in LEVEL_SUFFIXES:
				if ResourceLoader.exists(_library_path(gm, suffix)):
					_progress[layer_name + suffix] = 0.0
			_merge(_pairs.size() - 1, layer_name, gm)
	if _busy > 0 and loading_screen:
		_create_loading_screen()


## Busy merging? Then wait for the `merge_finished` signal.
func is_merging() -> bool:
	return _busy > 0


## Path of the MeshLibrary of `gm` for an LOD suffix from LEVEL_SUFFIXES.
func _library_path(gm: GridMap, suffix: String) -> String:
	return gm.mesh_library.resource_path.replace(".res", suffix + ".res")


## Hidden, collision-free copy of `gm` called `copy_name` that renders the same cells
## with `lib`; added to the scene root (deferred, the root may still be setting up).
func _lod_copy(gm: GridMap, copy_name: String, lib: MeshLibrary) -> GridMap:
	var copy := GridMap.new()
	copy.name = copy_name
	copy.mesh_library = lib
	copy.cell_size = gm.cell_size
	copy.cell_octant_size = gm.cell_octant_size
	copy.cell_center_x = gm.cell_center_x
	copy.cell_center_y = gm.cell_center_y
	copy.cell_center_z = gm.cell_center_z
	copy.transform = gm.transform
	copy.collision_layer = 0
	copy.collision_mask = 0
	for c in gm.get_used_cells():
		copy.set_cell_item(c, gm.get_cell_item(c), gm.get_cell_item_orientation(c))
	copy.visible = false
	get_parent().add_child.call_deferred(copy)
	return copy


## Full-screen "Stad laden…" overlay with a percentage (_set_progress), faded out by
## _layer_finished.
func _create_loading_screen() -> void:
	_screen = CanvasLayer.new()
	_screen.layer = 100
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.1, 0.13)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(panel)
	var label := Label.new()
	_screen_label = label
	label.text = "Stad laden…"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.95))
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_child(label)
	add_child(_screen)
	_set_progress("", 0.0)


## Records the progress of one merge job (key from _progress) and shows the average
## of all jobs on the loading screen.
func _set_progress(key: String, fraction: float) -> void:
	if key != "":
		_progress[key] = clampf(fraction, 0.0, 1.0)
	if _screen_label == null or _progress.is_empty():
		return
	var done := 0.0
	for f in _progress.values():
		done += f
	_screen_label.text = "Stad laden… %d%%" % floori(100.0 * done / _progress.size())


## Called when one layer is merged; after the last one emits `merge_finished`
## and fades out the loading screen.
func _layer_finished() -> void:
	_busy -= 1
	if _busy > 0:
		return
	merge_finished.emit()
	if _screen:
		var panel := _screen.get_child(0) as ColorRect
		var t := create_tween()
		t.tween_property(panel, "modulate:a", 0.0, 0.6)
		t.tween_callback(_screen.queue_free)
		_screen = null
		_screen_label = null


## Replaces the GridMap rendering of layer `index` (_pairs) with merged meshes for every
## LOD level (scripts/layer_baker.gd), loaded from the user://merged cache when possible.
## Spread over frames; a fresh bake is stored so the next start is ready immediately
## (as long as the map and the tiles don't change). Frees the LOD GridMap copies.
func _merge(index: int, layer_name: String, gm: GridMap) -> void:
	var t := Time.get_ticks_msec()
	var data: Dictionary = gm.get("data")   # raw cell data, hashed for the cache key
	var root := get_parent()
	var result := []
	for suffix in LEVEL_SUFFIXES:
		var path := _library_path(gm, suffix)
		if not ResourceLoader.exists(path):
			result.append(null)
			continue
		# everything before "__" identifies scene + layer + level, the rest the content
		var key := "%s_%s%s__%x_%x_%d" % [root.scene_file_path.get_file().get_basename(), layer_name, suffix,
			hash(data.get("cells", PackedInt32Array())), hash(gm.transform),
			FileAccess.get_modified_time(path) + Bakker.VERSION]
		var cache := CACHE_DIR.path_join(key + ".scn")
		var baked: Node3D
		var job: String = layer_name + suffix
		if ResourceLoader.exists(cache):
			ResourceLoader.load_threaded_request(cache)
			var loaded := []
			while ResourceLoader.load_threaded_get_status(cache, loaded) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_set_progress(job, loaded[0])
				await get_tree().process_frame
			var ps := ResourceLoader.load_threaded_get(cache) as PackedScene
			if ps:
				baked = ps.instantiate()
		if baked == null:
			baked = await Bakker.bake(gm, load(path), layer_name + "_merged" + suffix, layer_name in hide_top_layers,
				func(fraction: float): _set_progress(job, fraction))
			if not is_inside_tree():
				return
			_save(baked, cache)
		baked.visible = false
		root.add_child(baked)
		result.append(baked)
		_set_progress(job, 1.0)
	if not is_inside_tree():
		return
	var old: Array = _pairs[index]
	_pairs[index] = result
	gm.visible = false
	for i in old.size():
		if old[i] != null and old[i] != gm:
			old[i].queue_free()
	_level = -1   # reapply visibility
	print("%s merged in %d ms" % [layer_name, Time.get_ticks_msec() - t])
	_layer_finished()


## Saves a baked node as a compressed PackedScene at `path` (in CACHE_DIR) and removes
## older cache files of the same scene/layer/level.
func _save(node: Node3D, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	# clean up old versions of this layer (and this LOD level)
	var prefix := path.get_file().split("__")[0] + "__"
	for f in DirAccess.get_files_at(CACHE_DIR):
		if f.begins_with(prefix) and f != path.get_file():
			DirAccess.remove_absolute(CACHE_DIR.path_join(f))
	for k in node.get_children():
		k.owner = node
	var ps := PackedScene.new()
	ps.pack(node)
	ResourceSaver.save(ps, path, ResourceSaver.FLAG_COMPRESS)


## Per frame: picks the LOD level from the zoom, toggles Details/Props, and scales the
## shadow distance and depth of field with the camera distance.
func _process(_delta: float) -> void:
	if _cam == null:
		return
	var zoom := Iso.view_size(_cam)
	var distance := Iso.distance_to_ground(_cam)
	var level := 0
	if zoom > very_coarse_from:
		level = 2
	elif zoom > coarse_from:
		level = 1
	if level != _level:
		_level = level
		for p in _pairs:
			# fall back to a finer level if this one does not exist
			var choice := level
			while choice > 0 and p[choice] == null:
				choice -= 1
			for i in p.size():
				if p[i] != null:
					p[i].visible = i == choice
	var root := get_parent()
	var details := root.get_node_or_null("Details")
	if details:
		details.visible = zoom < details_until
	var props := root.get_node_or_null("Props")
	if props:
		props.visible = zoom < props_until
	if _sun:
		_sun.directional_shadow_max_distance = distance + zoom * shadow_factor
	var attr := _cam.attributes as CameraAttributesPractical
	if attr and depth_of_field:
		# sharp band around the focus point, as fractions of the camera-ground distance
		attr.dof_blur_far_distance = distance * 1.1
		attr.dof_blur_far_transition = distance * 0.4
		attr.dof_blur_near_distance = distance * 0.83
		attr.dof_blur_near_transition = distance * 0.3
