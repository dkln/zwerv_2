extends Node
## Level of detail and performance for the world scene (the "DetailNiveau" node).
##
## - LOD switching, two levels at most: for each GridMap in `layers` a coarse ("_lod") copy
##   is created at startup with the LOD MeshLibrary that library_builder.gd writes next to the
##   normal one. Depending on the zoom (view size, see iso_camera.gd) exactly one of the two
##   is visible. (The very coarse "_lod2" libraries are only for the menu's map.)
## - Merging: the layers in `merge_layers` are additionally baked into chunk meshes
##   without hidden faces (layer_baker.gd), per LOD level. The baked nodes replace the
##   GridMap rendering; the GridMap itself stays (hidden) for collisions and editing.
##   Baking takes long, so results are cached as scenes in user://merged, keyed on the
##   scene, map part ("part" metadata of the layer), layer, cell data, transform, library modification time and Bakker.VERSION.
##   While merging, an optional loading screen is shown; `merge_finished` fires when done.
## - Distance culling: the Details and Props layers (and their LOD copies) are hidden
##   when zoomed out.
## - The shadow distance follows the camera distance.
##
## You just edit the normal GridMaps; all copies are created automatically. When the
## layers are replaced, clear() drops everything made for the old layers and setup() starts over.

const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const Bakker = preload("res://scripts/world/layer_baker.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const LoadingScreen = preload("res://scripts/ui/loading_screen.gd")
const CACHE_DIR := "user://merged"
## File-name suffixes of the MeshLibraries per LOD level: normal, coarse (two levels at most).
const LEVEL_SUFFIXES := ["", "_lod"]
## Chunk size in cells of the baked finest level: it is only shown up close (below
## `coarse_from`), where a 32 m chunk is as big as the whole view and mostly drawn off
## screen; the coarse levels keep the bigger Bakker.CHUNK (fewer draw calls far out).
const FINE_CHUNK_CELLS := 4

## All layers have been merged (or there was nothing to merge).
signal merge_finished

@export var camera_path := NodePath("../Camera")
@export var sun_path := NodePath("../Zon")
## GridMap layers (node names under the scene root) that get LOD copies.
@export var layers: Array[String] = ["Grond", "Gebouwen", "Props"]
## These layers are merged at startup into large meshes without hidden
## faces (scripts/world/layer_baker.gd); the GridMap itself stays for collisions and editing.
@export var merge_layers: Array[String] = ["Gebouwen", "Grond"]
## Layers baked into the merged meshes of another layer, per merged layer: the facade
## details go into the building chunks (fewer draw calls, LOD for the details, and they
## fade with their own building, scripts/world/building_fade.gd). The extra layer's own
## GridMap stays (hidden) for editing.
@export var merge_with := {"Gebouwen": ["Details"]}
## Merged layers whose vertices carry the cell they belong to, for the see-through
## buildings (scripts/world/building_fade.gd); see layer_baker.gd.
@export var fade_layers: Array[String] = ["Gebouwen"]
## Merged layers whose facades with windows cast a filled shadow, without the shadows of
## their windows and flat facade details (see layer_baker.gd).
@export var filled_shadow_layers: Array[String] = ["Gebouwen"]
## Layers in which tiles are as tall as the cell (top face may go under a neighbouring block).
@export var hide_top_layers: Array[String] = ["Gebouwen"]
## From this zoom size (metres in view, see scripts/camera/iso_camera.gd) coarse tiles are used.
@export var coarse_from := 100.0
## From this zoom size (metres in view) the Details layer is hidden.
@export var details_until := 120.0
## From this zoom size (metres in view) the Props layer is hidden.
@export var props_until := 300.0
## Shadow distance = camera-ground distance + factor * zoom size (metres).
@export var shadow_factor := 1.0
## The shadow distance only changes when it is this share too short or too long, and
## then to this share more than needed: a shadow distance that changes every frame (a
## camera that zooms smoothly) re-divides the shadow cascades every frame, so the edges
## of all shadows crawl and flicker; a fixed one keeps them still.
const SHADOW_DISTANCE_SLACK := 1.25
const MIN_SHADOW_DISTANCE := 60.0
## Largest share of the shadow distance the first cascade may take (the part before what is
## in view: a tower close to the camera still gets a shadow).
const MAX_FIRST_SPLIT := 0.6
## Show a loading screen while merging is in progress.
@export var loading_screen := true
## Text of the loading screen.
@export var loading_text := "Stad laden…"
## Only fill the cache (tools/build/bake_maps.gd): a level whose cache file exists is not
## loaded, a missing one is baked and saved; nothing is shown.
var bake_only := false

var _cam: Camera3D
var _sun: DirectionalLight3D
## Per layer the nodes per LOD level: [normal, coarse]; null = level missing.
## Before merging these are GridMaps, after merging the baked Node3Ds.
var _pairs := []
## Layer name per entry of _pairs.
var _names: Array[String] = []
## LOD level currently shown (-1 = reapply on the next frame).
var _level := -1
## Layer name -> hidden by distance culling, as last applied.
var _culled := {}
## Number of layers still being merged.
var _busy := 0
var _holds := 0                     # others still at work under the loading screen (hold_screen)
var _screen: LoadingScreen
## Libraries of every level, loaded before any merge starts (see setup).
var _libraries: Array[MeshLibrary] = []
## A cache file is loading in a thread (headless only one at a time, see _merge).
var _threaded_load_busy := false
var _progress := {}   # "<layer><suffix>" -> fraction done (0..1) of every merge job
## Counts setup()/clear(); a merge that finds it changed belongs to layers that are gone.
var _generation := 0
## Extra layers baked into another layer's meshes (merge_with): name -> that layer.
var _baked_into := {}
## Still waiting for the swipe of the scene change to go through before setting up.
var _waiting_for_swipe := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_cam = get_node_or_null(camera_path)
	_sun = get_node_or_null(sun_path)
	# coming in under the swipe of a scene change (SwipeTransition): the loading screen first,
	# the heavy work once the swipe is through, so it does not stutter
	var swipe := get_tree().root.get_node_or_null(NodePath(SwipeTransition.NODE_NAME))
	if swipe and loading_screen and not bake_only:
		_waiting_for_swipe = true
		_open_screen()
		while is_instance_valid(swipe) and swipe.is_inside_tree():
			await get_tree().process_frame
			if not is_inside_tree():
				return   # the town is gone again before the swipe was through
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_waiting_for_swipe = false
	setup()
	_close_screen_when_done()


## Creates the LOD copies of each layer under the scene root and starts merging
## (asynchronously). Call clear() first when the layers were set up before.
func setup() -> void:
	var root := get_parent()
	var merges := []   # [index in _pairs, layer name, GridMap]
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
		_names.append(layer_name)
		if layer_name in merge_layers:
			_busy += 1
			for suffix in LEVEL_SUFFIXES:
				if ResourceLoader.exists(_library_path(gm, suffix)):
					_progress[layer_name + suffix] = 0.0
			merges.append([_pairs.size() - 1, layer_name, gm])
	# every library a merge needs is loaded before the first merge starts: a library loaded
	# on the main thread while a cached bake loads in a thread clashes over resource ids
	# in the headless rendering server (a crash in the checks)
	for merge in merges:
		_load_libraries(merge[2])
		for extra_name in merge_with.get(merge[1], []):
			var extra := root.get_node_or_null(str(extra_name)) as GridMap
			if extra and extra.mesh_library:
				_load_libraries(extra)
	for merge in merges:
		_merge(merge[0], merge[1], merge[2])
	if _busy > 0 and loading_screen and not bake_only:
		_open_screen()
		_set_progress("", 0.0)


func _open_screen() -> void:
	if _screen:
		return
	_screen = LoadingScreen.new()
	_screen.text = loading_text
	_screen.hud = get_parent().get_node_or_null("HUD")
	add_child(_screen)


## Loads the libraries of every LOD level of `gm` (kept in _libraries).
func _load_libraries(gm: GridMap) -> void:
	for suffix in LEVEL_SUFFIXES:
		var path := _library_path(gm, suffix)
		if ResourceLoader.exists(path):
			_libraries.append(load(path))


## Frees the LOD copies and merged meshes of the current layers and stops their merges
## (the layers themselves are left alone), so new layers can be set up.
func clear() -> void:
	_generation += 1
	for p in _pairs:
		for i in p.size():
			if i > 0 or not p[i] is GridMap:
				if p[i] != null and is_instance_valid(p[i]):
					p[i].queue_free()
	_pairs.clear()
	_names.clear()
	_baked_into.clear()
	_progress.clear()
	_level = -1
	_libraries.clear()
	if _screen:
		_screen.queue_free()
		_screen = null
	if _busy > 0:
		_busy = 0
		merge_finished.emit()


## How far the merging is (0..1, the average of all merge jobs); 1 when there is nothing to do.
func merge_progress() -> float:
	if _progress.is_empty():
		return 1.0
	var done := 0.0
	for fraction: float in _progress.values():
		done += fraction
	return done / _progress.size()


## Busy merging? Then wait for the `merge_finished` signal.
func is_merging() -> bool:
	return _busy > 0 or _waiting_for_swipe


## Path of the MeshLibrary of `gm` for an LOD suffix from LEVEL_SUFFIXES.
func _library_path(gm: GridMap, suffix: String) -> String:
	return gm.mesh_library.resource_path.replace(".res", suffix + ".res")


## Hidden, collision-free copy of `gm` called `copy_name` that renders the same cells
## with `lib`; added to the scene root (deferred while the root is still setting up).
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
	if get_parent().is_node_ready():
		get_parent().add_child(copy)
	else:
		get_parent().add_child.call_deferred(copy)
	return copy


## Records the progress of one merge job (key from _progress) and shows the average
## of all jobs on the loading screen.
func _set_progress(key: String, fraction: float) -> void:
	if key != "":
		_progress[key] = clampf(fraction, 0.0, 1.0)
	if _screen == null or _progress.is_empty():
		return
	_screen.set_progress(merge_progress())


## Called when one layer is merged; after the last one emits `merge_finished`
## and fades out the loading screen.
func _layer_finished() -> void:
	_busy -= 1
	if _busy > 0:
		return
	merge_finished.emit()
	_close_screen_when_done()


## Keeps the loading screen up for work of someone else (Interiors: building and warming up
## the interiors under it), until release_screen.
func hold_screen() -> void:
	_holds += 1


func release_screen() -> void:
	_holds = maxi(_holds - 1, 0)
	_close_screen_when_done()


## Whether the loading screen is there now (so work under it is not seen).
func screen_is_up() -> bool:
	return _screen != null


func _close_screen_when_done() -> void:
	# still waiting for the swipe: the merging has not even started (setup() follows), so
	# a release by someone else (Interiors) must not close it in between
	if _busy == 0 and _holds == 0 and not _waiting_for_swipe and _screen:
		_screen.fade_out()
		_screen = null


## Replaces the GridMap rendering of layer `index` (_pairs) with merged meshes for every
## LOD level (scripts/world/layer_baker.gd), loaded from the user://merged cache when possible.
## Spread over frames; a fresh bake is stored so the next start is ready immediately
## (as long as the map and the tiles don't change). Frees the LOD GridMap copies.
func _merge(index: int, layer_name: String, gm: GridMap) -> void:
	var t := Time.get_ticks_msec()
	var generation := _generation
	var data: Dictionary = gm.get("data")   # raw cell data, hashed for the cache key
	var root := get_parent()
	var extra_grids: Array[GridMap] = []
	for extra_name in merge_with.get(layer_name, []):
		var extra := root.get_node_or_null(str(extra_name)) as GridMap
		if extra and extra.mesh_library:
			extra_grids.append(extra)
	var result := []
	for suffix in LEVEL_SUFFIXES:
		var path := _library_path(gm, suffix)
		if not ResourceLoader.exists(path):
			result.append(null)
			continue
		# the extra layers at this level (their normal library if they have no such level)
		var extras := []
		var extras_key := 0
		for extra in extra_grids:
			var extra_path := _library_path(extra, suffix)
			if not ResourceLoader.exists(extra_path):
				extra_path = extra.mesh_library.resource_path
			extras.append([extra, load(extra_path)])
			extras_key = hash([extras_key, extra.get("data").get("cells", PackedInt32Array()), extra.transform,
				FileAccess.get_modified_time(extra_path)])
		var chunk_cells: int = FINE_CHUNK_CELLS if suffix == "" else Bakker.CHUNK
		# everything before "__" identifies scene + layer + level, the rest the content
		var scene := root.scene_file_path.get_file().get_basename()
		if gm.has_meta("part"):
			scene += "_" + str(gm.get_meta("part"))
		var key := "%s_%s%s__%x_%x_%x_%d" % [scene, layer_name, suffix,
			hash(data.get("cells", PackedInt32Array())), hash([gm.transform, chunk_cells]), extras_key,
			FileAccess.get_modified_time(path) + Bakker.VERSION]
		var cache := CACHE_DIR.path_join(key + ".scn")
		var baked: Node3D
		var job: String = layer_name + suffix
		if bake_only and ResourceLoader.exists(cache):
			result.append(null)
			_set_progress(job, 1.0)
			continue
		if ResourceLoader.exists(cache):
			# headless the dummy rendering server is not thread-safe: one cache at a time
			var one_at_a_time := DisplayServer.get_name() == "headless"
			while one_at_a_time and _threaded_load_busy and is_inside_tree():
				await get_tree().process_frame
			_threaded_load_busy = one_at_a_time
			ResourceLoader.load_threaded_request(cache)
			var loaded := []
			while ResourceLoader.load_threaded_get_status(cache, loaded) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_set_progress(job, loaded[0])
				if not is_inside_tree():
					break   # the town was left while loading (back to the main menu)
				await get_tree().process_frame
			var ps := ResourceLoader.load_threaded_get(cache) as PackedScene
			_threaded_load_busy = false
			if not is_inside_tree() or generation != _generation:
				_drop(result)
				return
			if ps:
				baked = ps.instantiate()
		if baked == null:
			baked = await Bakker.bake(gm, load(path), layer_name + "_merged" + suffix, layer_name in hide_top_layers,
				func(fraction: float): _set_progress(job, fraction), extras, layer_name in fade_layers, layer_name in filled_shadow_layers, chunk_cells)
			if not is_inside_tree() or generation != _generation or baked == null:
				if baked:
					baked.free()
				_drop(result)
				return
			_save(baked, cache)
		if bake_only:
			baked.free()
			result.append(null)
			_set_progress(job, 1.0)
			continue
		baked.visible = false
		root.add_child(baked)
		result.append(baked)
		_set_progress(job, 1.0)
	if not is_inside_tree() or generation != _generation:
		_drop(result)
		return
	var old: Array = _pairs[index]
	_pairs[index] = result
	gm.visible = false
	for extra in extra_grids:
		extra.visible = false
		_baked_into[str(extra.name)] = layer_name
	for i in old.size():
		if old[i] != null and old[i] != gm:
			old[i].queue_free()
	_level = -1   # reapply visibility
	print("%s merged in %d ms" % [layer_name, Time.get_ticks_msec() - t])
	_layer_finished()


## Frees the merged nodes of a merge that was overtaken by clear().
func _drop(nodes: Array) -> void:
	for n in nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()


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
## shadow distance with the camera distance.
func _process(_delta: float) -> void:
	if _cam == null:
		return
	var zoom := Iso.view_size(_cam)
	var distance := Iso.distance_to_ground(_cam)
	var level := 1 if zoom > coarse_from else 0
	var culled := {"Details": zoom >= details_until, "Props": zoom >= props_until}
	if level != _level or culled != _culled:
		_level = level
		_culled = culled
		var root := get_parent()
		for k in _pairs.size():
			var p: Array = _pairs[k]
			var shown: bool = not culled.get(_names[k], false)
			# fall back to a finer level if this one does not exist
			var choice := level
			while choice > 0 and p[choice] == null:
				choice -= 1
			for i in p.size():
				if p[i] != null:
					p[i].visible = shown and i == choice
		# culled layers without LOD copies are toggled directly (not the ones baked into
		# another layer's meshes: their GridMap stays hidden)
		for layer_name in culled:
			if not layer_name in _names and not _baked_into.has(layer_name):
				var gm := root.get_node_or_null(layer_name) as Node3D
				if gm:
					gm.visible = not culled[layer_name]
	if _sun:
		# at least MIN_SHADOW_DISTANCE: below street level (a chase camera in a tunnel) both are negative
		var needed := maxf(distance + zoom * shadow_factor, MIN_SHADOW_DISTANCE)
		var current := _sun.directional_shadow_max_distance
		if needed > current or needed * SHADOW_DISTANCE_SLACK * SHADOW_DISTANCE_SLACK < current:
			var shadow_distance := needed * SHADOW_DISTANCE_SLACK
			_sun.directional_shadow_max_distance = shadow_distance
			# the cascades round what is in view: the camera looks from far off (a narrow
			# field of view), so the default splits would spend the sharp ones on the empty
			# air before it and leave the town in the coarsest one (stripes of "shadow acne")
			var nearest_in_view := clampf((distance - zoom) / shadow_distance, 0.0, MAX_FIRST_SPLIT)
			_sun.directional_shadow_split_1 = maxf(nearest_in_view, 0.05)
			_sun.directional_shadow_split_2 = nearest_in_view + (1.0 - nearest_in_view) * 0.25
			_sun.directional_shadow_split_3 = nearest_in_view + (1.0 - nearest_in_view) * 0.55
