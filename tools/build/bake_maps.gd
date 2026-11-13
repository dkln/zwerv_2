extends SceneTree
## Bakes the merged meshes of the maps ahead of time, so starting the game only loads them
## from the cache instead of baking them first (minutes for the town).
##
## It opens each map (by default every scene in res://scenes with a DetailNiveau node:
## scripts/world/town/level_of_detail.gd), lets its DetailNiveau merge the layers into the
## cache in user://merged (layer_baker.gd) exactly as the game would, and waits until it is
## done. A map whose cache is up to date is left as it is. Afterwards it removes the cache files
## of maps that no longer exist (and the cache folder of older versions, user://samengevoegd).
## "opnieuw" empties the cache of the maps first, so everything is baked again.
##
## usage: tools/bake.sh [opnieuw] [res://scenes/<map>.tscn ...]
##   or:  GODOT_TIMEOUT=3600 tools/godot.sh --headless --script tools/build/bake_maps.gd -- [opnieuw] [map ...]

const Common = preload("res://tools/tool_common.gd")
const LevelOfDetail = preload("res://scripts/world/town/level_of_detail.gd")
const Progress = preload("res://tools/progress.gd")
const SCENES_DIR := "res://scenes"
## Cache folders no longer used: of an older version of level_of_detail.gd, and of the
## old per-cell bake of where buildings hide the player (hidden_map.gd, gone: the rim is a
## shader now, figure_rim_mask.gdshader).
const OLD_CACHE_DIRS := ["user://samengevoegd", "user://verborgen"]
## Seconds before the tool gives up (the town takes a few minutes from scratch).
const TIME_LIMIT := 3600.0


func _init() -> void:
	Common.watchdog(self, TIME_LIMIT)
	var arguments := OS.get_cmdline_user_args()
	var rebake := "opnieuw" in arguments
	var maps: Array[String] = []
	for argument in arguments:
		if argument.ends_with(".tscn") or argument.ends_with(".scn"):
			maps.append(argument if argument.begins_with("res://") else "res://" + argument)
	if maps.is_empty():
		maps = _maps_with_detail_level()
	await process_frame
	for map_index in maps.size():
		var map_path := maps[map_index]
		if rebake:
			_empty_cache_of(map_path)
		var started := Time.get_ticks_msec()
		print("bake: kaart %d van %d: %s ..." % [map_index + 1, maps.size(), map_path])
		var map := Common.instantiate(map_path)
		# only fill the cache: an up-to-date level is not even loaded (headless, two
		# levels loading in threads at once clash in the rendering server)
		var detail_level := map.get_node("DetailNiveau")
		detail_level.bake_only = true
		detail_level.loading_screen = false
		get_root().add_child(map)
		# the progress of the merge jobs, until they are done
		var progress := Progress.new("bake %s" % map_path.get_file().get_basename(), 100)
		await process_frame
		while detail_level.is_merging():
			progress.set_done(int(detail_level.merge_progress() * 100.0))
			await create_timer(0.5).timeout
		await Common.wait_for_merge(map)
		print("bake: %s ready in %.1f s" % [map_path, (Time.get_ticks_msec() - started) / 1000.0])
		map.queue_free()
		await process_frame
	_remove_stale_caches()
	quit()


## Every scene in SCENES_DIR that has a DetailNiveau node (only those bake anything).
func _maps_with_detail_level() -> Array[String]:
	var maps: Array[String] = []
	for file_name in DirAccess.get_files_at(SCENES_DIR):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path := SCENES_DIR.path_join(file_name)
		var scene_state := (load(scene_path) as PackedScene).get_state()
		for node_index in scene_state.get_node_count():
			if scene_state.get_node_name(node_index) == "DetailNiveau":
				maps.append(scene_path)
				break
	return maps


## Removes the cache of one map (all its layers and levels): its files, and the folders of
## its streamed finest levels (RegionStream: one scene per region; left there, they would be
## used again as they are).
func _empty_cache_of(map_path: String) -> void:
	var prefix := map_path.get_file().get_basename() + "_"
	for file_name in DirAccess.get_files_at(LevelOfDetail.CACHE_DIR):
		if file_name.begins_with(prefix):
			DirAccess.remove_absolute(LevelOfDetail.CACHE_DIR.path_join(file_name))
	for folder_name in DirAccess.get_directories_at(LevelOfDetail.CACHE_DIR):
		if folder_name.begins_with(prefix):
			var folder := LevelOfDetail.CACHE_DIR.path_join(folder_name)
			for file_name in DirAccess.get_files_at(folder):
				DirAccess.remove_absolute(folder.path_join(file_name))
			DirAccess.remove_absolute(folder)


## Removes the cache files of maps that are no longer in SCENES_DIR, and the old cache folders.
func _remove_stale_caches() -> void:
	var map_names: Array[String] = []
	for file_name in DirAccess.get_files_at(SCENES_DIR):
		map_names.append(file_name.get_basename())
	var removed := 0
	for file_name in DirAccess.get_files_at(LevelOfDetail.CACHE_DIR):
		var belongs_to_a_map := false
		for map_name in map_names:
			if file_name.begins_with(map_name + "_"):
				belongs_to_a_map = true
				break
		if not belongs_to_a_map:
			DirAccess.remove_absolute(LevelOfDetail.CACHE_DIR.path_join(file_name))
			removed += 1
	for old_dir: String in OLD_CACHE_DIRS:
		if DirAccess.dir_exists_absolute(old_dir):
			for file_name in DirAccess.get_files_at(old_dir):
				DirAccess.remove_absolute(old_dir.path_join(file_name))
				removed += 1
			DirAccess.remove_absolute(old_dir)
	if removed > 0:
		print("bake: %d old cache files removed" % removed)
