@tool
extends EditorPlugin
## Vox Tiles: importeert .vox en houdt de GridMap-bibliotheken automatisch bij.

const Builder = preload("res://addons/vox_tiles/library_builder.gd")
const MENU_REBUILD := "Vox Tiles: bibliotheken volledig herbouwen"

var _importer: EditorImportPlugin
var _timer: Timer
var _pending := {}
var _busy := false


func _enter_tree() -> void:
	_importer = preload("res://addons/vox_tiles/vox_import_plugin.gd").new()
	add_import_plugin(_importer)
	add_tool_menu_item(MENU_REBUILD, _rebuild_all)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 1.0
	_timer.timeout.connect(_flush)
	add_child(_timer)
	var fs := EditorInterface.get_resource_filesystem()
	fs.resources_reimported.connect(_on_reimported)
	fs.filesystem_changed.connect(_schedule)
	_schedule()


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs.resources_reimported.is_connected(_on_reimported):
		fs.resources_reimported.disconnect(_on_reimported)
	if fs.filesystem_changed.is_connected(_schedule):
		fs.filesystem_changed.disconnect(_schedule)
	remove_tool_menu_item(MENU_REBUILD)
	remove_import_plugin(_importer)
	_importer = null


func _on_reimported(paths: PackedStringArray) -> void:
	for p in paths:
		if p.begins_with(Builder.TILE_ROOT) and p.get_extension() == "vox":
			_pending[p] = true
	_schedule()


func _schedule() -> void:
	if _timer:
		_timer.start()


func _previews_possible() -> bool:
	return DisplayServer.get_name() != "headless"


func _flush() -> void:
	# make_mesh_previews laat de editor tussendoor events verwerken; voorkom dat
	# we onszelf dan opnieuw starten.
	if _busy or EditorInterface.get_resource_filesystem().is_scanning():
		_timer.start()
		return
	_busy = true
	var changed := _pending
	_pending = {}
	for cat in Builder.CATEGORIES:
		Builder.build_category(cat, changed, _previews_possible())
	_busy = false


func _rebuild_all() -> void:
	if _busy:
		return
	_busy = true
	for cat in Builder.CATEGORIES:
		Builder.build_category(cat, {}, _previews_possible(), true)
	_busy = false
