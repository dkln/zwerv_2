extends SceneTree
## See-through buildings (scripts/world/building_fade.gd): a building between the one followed
## and the camera counts as in front (it may fade), one behind it does not (you see them standing
## in front of it, so it stays).
## usage: tools/godot.sh --headless --script tools/check/building_fade_test.gd

const Common = preload("res://tools/tool_common.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 120)
	var scene := Common.instantiate(Common.CITY)
	var fade: Node = scene.get_node("Doorkijk")
	var buildings: GridMap = scene.get_node("Gebouwen")
	get_root().add_child(scene)
	await process_frame
	var cell: Vector3i = buildings.get_used_cells()[0]
	var middle := buildings.to_global(buildings.map_to_local(cell))
	var towards := Iso.DIRECTION.normalized()
	_check(fade._in_front(cell, middle - towards * 6.0, towards), "gebouw tussen speler en camera telt mee")
	_check(not fade._in_front(cell, middle + towards * 6.0, towards), "gebouw achter de speler blijft staan")
	_check_wall_beside(scene, fade, buildings)
	print("doorkijk ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)


## Someone walking up to a facade that is not between them and the camera (the building
## behind them, its front running on beside them across the picture) keeps it: the view
## hole lies round them and only cuts what is on the camera's side of them.
func _check_wall_beside(scene: Node, fade: Node, buildings: GridMap) -> void:
	var player: Node3D = scene.get_node("Speler")
	var camera := get_root().get_camera_3d()
	if camera == null:
		_problems.append("geen camera")
		return
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
		for offset in [Vector3i.ZERO, along, -along, along * 2]:
			for level in 3:
				if buildings.get_cell_item(before + offset + Vector3i(0, level, 0)) != GridMap.INVALID_CELL_ITEM:
					free = false
		if not free:
			continue
		if buildings.get_cell_item(cell + along) == GridMap.INVALID_CELL_ITEM or buildings.get_cell_item(cell + along * 2) == GridMap.INVALID_CELL_ITEM:
			continue
		var middle := buildings.to_global(buildings.map_to_local(before))
		spot = Vector3(middle.x, 0.375, middle.z) + Vector3(away) * 1.7   # 0.3 m off the facade
		wall = cell
		break
	if spot == Vector3.INF:
		_problems.append("geen gevel gevonden")
		return
	player.global_position = spot
	# a stand-in for the follow camera (the tool's camera stands still): it follows the player
	var follow_script := GDScript.new()
	follow_script.source_code = "extends Node\nvar target_node: Node3D\n"
	follow_script.reload()
	var follow := Node.new()
	follow.set_script(follow_script)
	follow.set("target_node", player)
	fade._follow = follow
	if fade._building_cells.is_empty():
		fade._find_buildings()   # without a follow camera it did not set itself up
	camera.global_basis = Basis.from_euler(Iso.ROTATION * PI / 180.0)
	camera.global_position = Iso.position(spot, 34.0)
	# the view hole: round the player, and only on the camera's side of it (as
	# voxel_fade.gdshaderinc cuts), so the facade behind the player keeps its wall
	fade._fade[fade._building_of[Vector2i(wall.x, wall.z)]] = 1.0
	fade._place_hole()
	var hole: Color = fade._image.get_pixel(0, fade._image.get_height() - 1)
	var centre := Vector3(hole.r, hole.g, hole.b)
	_check(Vector2(centre.x, centre.z).distance_to(Vector2(spot.x, spot.z)) < 0.01 and is_equal_approx(hole.a, fade.hole_radius),
		"kijkgat om de speler (straal %.1f m)" % hole.a)
	var towards_camera := camera.global_basis.z
	var on_facade := spot + Vector3(away) * 0.3 + Vector3.UP * 1.5
	_check((on_facade - centre).dot(towards_camera) < 0.4, "gevel achter de speler (niet ervoor) blijft staan, bij %s" % spot)
	var in_front := centre + towards_camera * 4.0
	_check((in_front - centre).dot(towards_camera) >= 0.4 and (in_front - centre - towards_camera * (in_front - centre).dot(towards_camera)).length() < hole.a,
		"wat ervoor staat valt in het kijkgat")
	# standing in front of the facade: that building does not cover the player, so it gets no hole
	var blocking: Dictionary = fade._blocking()
	_check(not blocking.has(fade._building_of[Vector2i(wall.x, wall.z)]),
		"voor een gevel staan geeft dat gebouw geen kijkgat")
	fade._fade.clear()
	follow.free()
