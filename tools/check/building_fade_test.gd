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
	print("doorkijk ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
