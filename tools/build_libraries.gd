extends SceneTree
## Builds the MeshLibraries (and their LOD copies) without the editor, so without
## previews; the editor plugin makes those. "force" rebuilds even unchanged categories.
## usage: Godot --headless --script tools/build_libraries.gd [-- force]

const Common = preload("res://tools/tool_common.gd")
const Builder = preload("res://addons/vox_tiles/library_builder.gd")


func _init() -> void:
	Common.watchdog(self)
	var force := "force" in OS.get_cmdline_user_args()
	for cat in Builder.CATEGORIES:
		Builder.build_category(cat, {}, false, force)
	quit()
