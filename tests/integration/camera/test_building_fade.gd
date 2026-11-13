extends "res://tests/integration/support/town_test.gd"
## See-through buildings (scripts/world/town/building_fade.gd): a building between the one followed
## and the camera counts as in front (it may fade), one behind it does not (you see them standing
## in front of it, so it stays); and the view hole lies round the player and only cuts what
## is on the camera's side of them.
##   tests/run_integration_tests.sh building_fade

const Iso = preload("res://scripts/camera/iso_camera.gd")
## Metres the player stands off the facade.
const OFF_THE_FACADE := 0.3


## The player put in front of a facade that is not between them and the camera (the
## building behind them, its front running on beside them across the picture), the camera
## looking at them and the view hole placed for that building:
## {"spot", "away" (the cell step from the camera's side to the facade), "building" (its
## number in the fade), "hole" (the pixel of the view hole: centre and radius), "camera"};
## empty if the town has no such facade. _leave_facade puts things back.
func _stand_before_facade() -> Dictionary:
	var fade: Node = scene.get_node("Doorkijk")
	var buildings: GridMap = scene.get_node("Gebouwen")
	var camera := tree.root.get_camera_3d()
	if camera == null:
		return {}
	# the side of a cell away from the camera (seen from above), and along the facade
	var towards := Vector2(Iso.DIRECTION.x, Iso.DIRECTION.z)
	var away := Vector3i(0, 0, 1) if towards.y < 0.0 else Vector3i(0, 0, -1)
	var along := Vector3i(1, 0, 0) if towards.x > 0.0 else Vector3i(-1, 0, 0)
	var spot := Vector3.INF
	var wall := Vector3i.ZERO
	for cell in buildings.get_used_cells():
		if cell.y != 0:
			continue
		var before := cell - away
		var free := true
		for offset: Vector3i in [Vector3i.ZERO, along, -along, along * 2]:
			for level in 3:
				if buildings.get_cell_item(before + offset + Vector3i(0, level, 0)) != GridMap.INVALID_CELL_ITEM:
					free = false
		if not free:
			continue
		if buildings.get_cell_item(cell + along) == GridMap.INVALID_CELL_ITEM or buildings.get_cell_item(cell + along * 2) == GridMap.INVALID_CELL_ITEM:
			continue
		var middle := buildings.to_global(buildings.map_to_local(before))
		spot = Vector3(middle.x, 0.375, middle.z) + Vector3(away) * (2.0 - OFF_THE_FACADE)
		wall = cell
		break
	if spot == Vector3.INF:
		return {}
	player.global_position = spot
	if fade._building_cells.is_empty():
		fade._find_buildings()
	camera.global_basis = Basis.from_euler(Iso.ROTATION * PI / 180.0)
	camera.global_position = Iso.position(spot, 34.0)
	# the view hole: round the player, and only on the camera's side of it (as
	# voxel_fade.gdshaderinc cuts), so the facade behind the player keeps its wall
	var building: int = fade._building_of[Vector2i(wall.x, wall.z)]
	fade._fade[building] = 1.0
	fade._place_hole()
	return {"spot": spot, "away": Vector3(away), "building": building, "camera": camera,
		"hole": fade._image.get_pixel(0, fade._image.get_height() - 1)}


## The fade as it was before _stand_before_facade.
func _leave_facade() -> void:
	scene.get_node("Doorkijk")._fade.clear()


## A building between the one followed and the camera counts as in front, one behind it does not.
func test_in_front_or_behind_the_followed(test) -> void:
	var fade: Node = scene.get_node("Doorkijk")
	var buildings: GridMap = scene.get_node("Gebouwen")
	var cell: Vector3i = buildings.get_used_cells()[0]
	var middle := buildings.to_global(buildings.map_to_local(cell))
	var towards := Iso.DIRECTION.normalized()
	test.check(fade._in_front(cell, middle - towards * 6.0, towards), "gebouw tussen speler en camera telt mee")
	test.check(not fade._in_front(cell, middle + towards * 6.0, towards), "gebouw achter de speler blijft staan")


## The view hole is a circle round the player, of the fade's hole_radius.
func test_view_hole_lies_round_the_player(test) -> void:
	var stand := _stand_before_facade()
	test.check(not stand.is_empty(), "een gevel gevonden om voor te staan")
	if stand.is_empty():
		return
	var hole: Color = stand.hole
	var spot: Vector3 = stand.spot
	test.check(Vector2(hole.r, hole.b).distance_to(Vector2(spot.x, spot.z)) < 0.01 and is_equal_approx(hole.a, scene.get_node("Doorkijk").hole_radius),
		"kijkgat om de speler (straal %.1f m)" % hole.a)
	_leave_facade()


## The hole only cuts what is on the camera's side of the player: the facade behind them
## stays, what stands in front of them falls in it.
func test_view_hole_only_cuts_the_cameras_side(test) -> void:
	var stand := _stand_before_facade()
	test.check(not stand.is_empty(), "een gevel gevonden om voor te staan")
	if stand.is_empty():
		return
	var hole: Color = stand.hole
	var centre := Vector3(hole.r, hole.g, hole.b)
	var towards_camera: Vector3 = (stand.camera as Camera3D).global_basis.z
	var on_facade: Vector3 = stand.spot + stand.away * OFF_THE_FACADE + Vector3.UP * 1.5
	test.check((on_facade - centre).dot(towards_camera) < 0.4, "gevel achter de speler (niet ervoor) blijft staan, bij %s" % stand.spot)
	var in_front := centre + towards_camera * 4.0
	test.check((in_front - centre).dot(towards_camera) >= 0.4 and (in_front - centre - towards_camera * (in_front - centre).dot(towards_camera)).length() < hole.a,
		"wat ervoor staat valt in het kijkgat")
	_leave_facade()


## Standing in front of a facade: that building does not cover the player, so it is not
## among the blocking ones (no hole for it).
func test_facade_behind_the_player_does_not_block(test) -> void:
	var stand := _stand_before_facade()
	test.check(not stand.is_empty(), "een gevel gevonden om voor te staan")
	if stand.is_empty():
		return
	var blocking: Dictionary = scene.get_node("Doorkijk")._blocking()
	test.check(not blocking.has(stand.building), "voor een gevel staan geeft dat gebouw geen kijkgat")
	_leave_facade()
