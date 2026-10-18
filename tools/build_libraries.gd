extends SceneTree
## Bouwt de MeshLibraries zonder editor (zonder previews; die maakt de editor-plugin).
## gebruik: Godot --headless --script tools/build_libraries.gd
func _init():
	var B = load("res://addons/vox_tiles/library_builder.gd")
	for cat in B.CATEGORIES:
		B.build_category(cat, {}, false)
	quit()
