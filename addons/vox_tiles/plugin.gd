@tool
extends EditorPlugin
## Vox Tiles: registers the .vox importer and keeps the GridMap libraries up to date.
##
## Flow in the editor: you save a .vox -> Godot reimports it (vox_import_plugin.gd)
## -> _on_reimported() remembers the path -> a second later _flush() rebuilds the
## affected libraries (library_builder.gd). Saving a side file (.tile.json or
## .lod.vox, see tile_metadata.gd) triggers a reimport of its tile first.
##
## Scenes built with the tiles are marked as a "Vox Tiles scene" (checkbox at the top of
## the Build dock, saved as metadata on the scene root). In such a scene the 3D views
## run in a light "editor view" (editor_view.gd) for a high frame rate: light voxel
## shaders with lines on the 4 m tile borders, no shadows, reflections, SSAO/SSIL/glow/
## fog, motion blur or smoke; and the build tools below are available. The game itself
## (F5/F6 and exports) never uses the editor view.

const Builder = preload("res://addons/vox_tiles/library_builder.gd")
const TileMetadata = preload("res://addons/vox_tiles/tile_metadata.gd")
const Importer = preload("res://addons/vox_tiles/vox_import_plugin.gd")
const BuildTools = preload("res://addons/vox_tiles/build_tools.gd")
const EditorView = preload("res://addons/vox_tiles/editor_view.gd")
const MENU_REBUILD := "Vox Tiles: rebuild all libraries"

var _importer: EditorImportPlugin
var _build: BuildTools
var _view: EditorView
var _timer: Timer
var _pending := {}
var _busy := false
var _meta_handled := {}   # vox path -> side file mtime that was already reimported


func _enter_tree() -> void:
	_importer = Importer.new()
	add_import_plugin(_importer)
	add_tool_menu_item(MENU_REBUILD, _rebuild_all)
	_view = EditorView.new()
	scene_changed.connect(_view.refresh)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 1.0
	_timer.timeout.connect(_flush)
	add_child(_timer)
	var fs := EditorInterface.get_resource_filesystem()
	fs.resources_reimported.connect(_on_reimported)
	fs.filesystem_changed.connect(_schedule)
	_schedule()
	_build = BuildTools.new(self)
	_build.view = _view
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _build.dock)
	scene_changed.connect(_build.refresh)
	_build.marked_changed.connect(_view.refresh)
	_build.refresh()


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs.resources_reimported.is_connected(_on_reimported):
		fs.resources_reimported.disconnect(_on_reimported)
	if fs.filesystem_changed.is_connected(_schedule):
		fs.filesystem_changed.disconnect(_schedule)
	_build.cleanup()
	remove_control_from_docks(_build.dock)
	_build.dock.queue_free()
	_build = null
	remove_tool_menu_item(MENU_REBUILD)
	if _view:
		_view.cleanup()
		_view = null
	remove_import_plugin(_importer)
	_importer = null


## Collects reimported tiles; the libraries are rebuilt in _flush().
func _on_reimported(paths: PackedStringArray) -> void:
	for p in paths:
		if p.begins_with(Builder.TILE_ROOT) and p.get_extension() == "vox":
			_pending[p] = true
	_schedule()


## (Re)starts the one-second timer, so a burst of changes is handled once.
func _schedule() -> void:
	if _timer:
		_timer.start()


## Mesh previews need a display; not available when running headless.
func _previews_possible() -> bool:
	return DisplayServer.get_name() != "headless"


## Reimports tiles with changed side files, otherwise updates all libraries
## with the tiles reimported since the last flush.
func _flush() -> void:
	# make_mesh_previews lets the editor process events in between; prevent
	# restarting ourselves while that happens.
	if _busy or EditorInterface.get_resource_filesystem().is_scanning():
		_timer.start()
		return
	# Godot only watches the .vox itself; reimport tiles whose metadata or coarse
	# version (.lod.vox) is newer than their last import. Their libraries are
	# updated after the reimport.
	var stale := _tiles_with_newer_side_files()
	if not stale.is_empty():
		EditorInterface.get_resource_filesystem().reimport_files(stale)
		return
	_busy = true
	var changed := _pending
	_pending = {}
	for cat in Builder.CATEGORIES:
		Builder.build_category(cat, changed, _previews_possible())
	_busy = false


## Tiles whose side files were saved after their last import.
func _tiles_with_newer_side_files() -> PackedStringArray:
	var out := PackedStringArray()
	var files := PackedStringArray()
	Builder.list_vox(Builder.TILE_ROOT, files)
	for vox in files:
		var t := 0
		for side_file in TileMetadata.side_files(vox):
			if FileAccess.file_exists(side_file):
				t = maxi(t, FileAccess.get_modified_time(side_file))
		if t > FileAccess.get_modified_time(vox + ".import") and _meta_handled.get(vox, 0) != t:
			_meta_handled[vox] = t   # at most once per save, even if the import fails
			out.append(vox)
	return out


## Tool menu: rebuilds every library from scratch (including previews).
func _rebuild_all() -> void:
	if _busy:
		return
	_busy = true
	for cat in Builder.CATEGORIES:
		Builder.build_category(cat, {}, _previews_possible(), true)
	_busy = false


# ------------------------------------------------------------------ Build dock hooks

func _handles(object: Object) -> bool:
	return _build != null and _build.handles(object)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return _build.forward_input(camera, event)


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	_build.draw_overlay(overlay)


func _apply_changes() -> void:
	if _build:
		_build.apply_changes()
	if _view:
		_view.restore_for_save()
