extends SceneTree
## Bouwt de MeshLibraries zonder editor (zonder previews; die maakt de editor-plugin).
## gebruik: Godot --headless --script tools/build_libraries.gd [-- force]
func _init():
	var B = load("res://addons/vox_tiles/library_builder.gd")
	var force := "force" in OS.get_cmdline_user_args()
	for cat in B.CATEGORIES:
		B.build_category(cat, {}, false, force)
	quit()
