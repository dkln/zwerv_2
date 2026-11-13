extends RefCounted
## Unit tests of the voxel models of the items (scripts/world/item_models.gd), as the reward
## screen shows them: every item of Items.ITEMS has a model of its own, not empty, standing on
## y = 0, centred in x and z, about 10 to 24 voxels in its longest direction (an icon, not to
## scale); an unknown id gets the fallback bag.

const ItemModels = preload("res://scripts/world/item_models.gd")
const Items = preload("res://scripts/player/items.gd")

## The longest side of a model, in voxels: what an icon may be.
const SMALLEST_VOXELS := 9.5
const LARGEST_VOXELS := 25.5


## Every item of Items.ITEMS has a mesh from a model of its own.
func test_every_item_has_a_model(test) -> void:
	for item_id: String in Items.ITEMS:
		var mesh := ItemModels.mesh_for(item_id)
		test.check(mesh != null and mesh.get_surface_count() > 0, "%s heeft een mesh" % item_id)
		test.check(ItemModels.has_model(item_id), "%s heeft een eigen model" % item_id)


## Every item model stands on y = 0, centred in x and z.
func test_models_stand_centred_on_the_ground(test) -> void:
	var tolerance := ItemModels.ITEM_VOXEL * 0.01
	for item_id: String in Items.ITEMS:
		var box := ItemModels.mesh_for(item_id).get_aabb()
		var centre := box.get_center()
		test.check(absf(box.position.y) < tolerance, "%s staat op y = 0 (%.3f)" % [item_id, box.position.y])
		test.check(absf(centre.x) < tolerance and absf(centre.z) < tolerance,
				"%s staat in het midden (%.3f, %.3f)" % [item_id, centre.x, centre.z])


## Every item model is icon sized: about 10 to 24 voxels in its longest direction.
func test_models_have_icon_size(test) -> void:
	for item_id: String in Items.ITEMS:
		var size := ItemModels.mesh_for(item_id).get_aabb().size / ItemModels.ITEM_VOXEL
		var longest := maxf(size.x, maxf(size.y, size.z))
		test.check(longest >= SMALLEST_VOXELS and longest <= LARGEST_VOXELS,
				"%s is %.0f voxels lang" % [item_id, longest])


## No two items share a model, also those that look alike.
func test_models_differ(test) -> void:
	# items that look alike still get a model of their own
	for pair: Array in [["koffie", "cappuccino"], ["roos", "tulpen"], ["water", "mineraalwater"],
			["bier", "blikje"], ["stroopwafel", "pak_stroopwafels"], ["brood", "vers_brood"],
			["drop", "winegums"], ["ov_chipkaart", "pinpas"]]:
		var first := ItemModels.mesh_for(pair[0])
		var second := ItemModels.mesh_for(pair[1])
		test.check(first != second and (first.get_aabb() != second.get_aabb() \
				or _vertex_count(first) != _vertex_count(second)), "%s en %s verschillen" % pair)


## An unknown id gets the fallback mesh (no model of its own), made only once.
func test_unknown_item_gets_the_fallback(test) -> void:
	var mesh := ItemModels.mesh_for("bestaat_niet")
	test.check(mesh != null and mesh.get_surface_count() > 0, "een terugval-mesh")
	test.check(not ItemModels.has_model("bestaat_niet"), "geen eigen model")
	test.check(ItemModels.mesh_for("bestaat_niet") == mesh, "één keer gemaakt")


func _vertex_count(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		count += mesh.surface_get_array_len(surface)
	return count
