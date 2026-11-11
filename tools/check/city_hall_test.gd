extends SceneTree
## The city hall on the Spui (scripts/world/city_hall.gd, Interiors KINDS "stadhuis"): the doors
## in the ground floor of its two white slabs are ways in (out again where you came in); inside you are on floor 0 by the entrance (only that floor shown),
## the reception staffed; the five floors each have their own layout (no two the same, not
## all the same size) and the lift stands at the same place on all of them, free to walk to
## from where you come out of it; at the lift [E] Lift asks which floor; the ride is a scene of
## its own (the cabin, the camera from the front, close in, you in it, the motor humming, the
## display showing the floor the lift is at); out at that floor (the floor shown, you before its doors, the doors open, the minimap the plan of
## that floor, the people of that floor there: Burgerzaken its civil servants at the counters,
## the council chamber its mayor); a number from the machine; back down and out of the door.
## usage: tools/godot.sh --headless --script tools/check/city_hall_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Layout = preload("res://scripts/world/city_hall_layout.gd")

var _problems: Array[String] = []
var _player: Node3D
var _hud: Node
var _interiors: Node


func _init() -> void:
	Common.watchdog(self, 300)
	_check_layouts()
	PlayerCharacter.choose("sjaan")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	_player = scene.get_node("Speler")
	_hud = scene.get_node("HUD")
	_interiors = scene.get_node("Binnenruimtes")
	scene.get_node("Volgcamera")._end_arrival()
	for frame_index in 600:
		await physics_frame
		if _player._placed and not _player._sleeping:
			break
	_player._wake_up()
	for attempt in 40:
		if not _player._sleeping:
			break
		await create_timer(0.1, true).timeout
	for frame_index in 120:
		await process_frame
		_skip_story()
	var ways_in: Array = _interiors.ways_in().filter(func(way_in: Dictionary) -> bool: return way_in.kind == "stadhuis")
	_check(ways_in.size() >= 2, "ingangen van het stadhuis: de deuren van de twee witte schijven (%d)" % ways_in.size())
	if ways_in.is_empty():
		_finish()
		return
	var way_in: Dictionary = ways_in[ways_in.size() - 1]
	var places: Dictionary = scene.get_meta("places")
	print("ingang %s, het stadhuis op de kaart %s" % [(way_in.door as Vector3).snapped(Vector3.ONE * 0.1), places.get("stadhuis")])
	_player.teleport(way_in.door, 0.0)
	for frame_index in 4:
		await physics_frame
	_check(_actions() == [["E", "Naar binnen"]], "bij de deur: [E] Naar binnen")
	_use()
	await create_timer(1.3, true).timeout
	var hall: Node3D = _interiors._interior
	_check(_interiors.is_inside() and hall != null and hall.has_method("ride"), "binnen in het stadhuis")
	if hall == null or not hall.has_method("ride"):
		_finish()
		return
	_check(hall.current_floor == 0 and hall.floor_node(0).visible and not hall.floor_node(1).visible, "op de begane grond, alleen die te zien")
	_check(_player.global_position.distance_to(hall.to_global(Vector3(0.0, 0.0, -9.1))) < 1.5, "binnen bij de ingang")
	var receptionists: Array = hall.people().filter(func(person: Node) -> bool: return person.role == "receptioniste")
	_check(receptionists.size() == 2, "twee receptionistes achter de balie (%d)" % receptionists.size())
	_check(hall.people().any(func(person: Node) -> bool: return person.role == "beveiliger"), "een beveiliger bij de deur")
	for frame_index in 6:
		await physics_frame
	_check(_player._fits(_player.global_position), "binnen staat de speler vrij")
	# to the lift: the question, then up
	var lift: Node3D = hall.floor_node(0).get_node("Lift")
	_player.teleport(lift.global_position, 0.0)
	_player._talk_partner = null
	for frame_index in 4:
		await physics_frame
	_check(_actions() == [["E", "Lift"]], "bij de lift: [E] Lift (%s)" % [_actions()])
	_use()
	await process_frame
	var box: Control = _hud._story_box
	_check(box.is_showing() and box._current_choices().size() == 5, "de lift vraagt welke etage (5 keuzes)")
	print("  ", box._current_choices())
	box.hide()
	box._pages = []
	paused = false
	# the ride as it goes: a scene of its own, the camera from the front, the display counting
	var cabin: Node3D = hall.lift()
	var camera_before := get_root().get_viewport().get_camera_3d()
	hall.ride(2, true)
	for wait in 30:
		await create_timer(0.1, true).timeout
		if hall.in_cabin():
			break
	await create_timer(0.6, true).timeout
	var camera := get_root().get_viewport().get_camera_3d()
	_check(hall.in_cabin() and cabin.visible, "in de lift: de liftscène")
	_check(camera != null and camera.name == "Liftcamera", "met de camera van de lift (%s)" % (camera.name if camera else "geen"))
	_check(cabin.has_node("Speler") and not _player.visible, "jij in de lift (een stand-in), de echte speler weg")
	if camera and cabin.has_node("Speler"):
		var to_player := (cabin.get_node("Speler") as Node3D).global_position - camera.global_position
		_check(to_player.length() < 3.0 and camera.global_basis.z.dot(Vector3(0.0, 0.0, 1.0)) < -0.8,
			"ingezoomd, van voren (%.1f m)" % to_player.length())
	for wait in 20:
		if hall.motor_running():
			break
		await create_timer(0.1, true).timeout
	_check(hall.motor_running(), "de liftmotor zoemt (zodra de swipe weg is)")
	var seen := {}
	for wait in 80:
		seen[hall.display_text()] = true
		if not hall.is_riding():
			break
		await create_timer(0.1, true).timeout
	print("  display onderweg: ", seen.keys())
	_check(seen.has("▲ 0") and seen.has("▲ 1") and seen.has("2"), "het display toont waar de lift is: ▲ 0, ▲ 1, 2")
	_check(not hall.in_cabin() and hall.current_floor == 2 and _player.visible, "uitgestapt op etage 2")
	_check(get_root().get_viewport().get_camera_3d() == camera_before, "de gewone camera weer")
	_check(not hall.motor_running(), "de motor stil")
	for floor_number in [1, 4, 2, 3, 0]:
		await _ride(hall, floor_number)
	# a number at Burgerzaken
	await _ride(hall, 1)
	var machine: Node3D = hall.floor_node(1).get_node("Nummerautomaat")
	_player.teleport(machine.global_position, 0.0)
	_player._talk_partner = null
	for frame_index in 4:
		await physics_frame
	_check(_actions() == [["E", "Nummertje trekken"]], "bij de automaat: [E] Nummertje trekken")
	_use()
	_check(hall.number_taken() > 0, "een nummertje: B %03d" % hall.number_taken())
	await _ride(hall, 0)
	var door: Node3D = hall.get_node("Deur")
	_player.teleport(door.global_position, 0.0)
	_player._talk_partner = null
	for frame_index in 4:
		await physics_frame
	_check(_actions() == [["E", "Naar buiten"]], "bij de deur binnen: [E] Naar buiten")
	_use()
	await create_timer(1.3, true).timeout
	_check(not _interiors.is_inside() and _player.global_position.distance_to(way_in.door) < 2.0, "weer buiten op het Spui")
	_finish()


## The lift to `number` (at once), and what should be true there.
func _ride(hall: Node3D, number: int) -> void:
	hall.ride(number, false)
	for frame_index in 6:
		await physics_frame
	var floor_node: Node3D = hall.floor_node(number)
	var lift: Node3D = floor_node.get_node("Lift")
	var others_hidden := true
	for index in hall.floor_count():
		if index != number and hall.floor_node(index).visible:
			others_hidden = false
	print("etage %d (%s): %d mensen" % [number, Layout.NAMES[number],
		floor_node.get_children().filter(func(node: Node) -> bool: return node is InteriorPerson).size()])
	_check(hall.current_floor == number and floor_node.visible and others_hidden, "  de lift naar etage %d: alleen die te zien" % number)
	_check(_player.global_position.distance_to(lift.global_position) < 0.6, "  de speler voor de lift")
	_check(_player._fits(_player.global_position), "  daar staat de speler vrij")
	_check(hall.doors_open(number), "  de liftdeuren open")
	_check(hall.plan_root() == floor_node, "  het kaartje toont deze etage")
	match number:
		1:
			var at_counters := floor_node.get_children().filter(func(node: Node) -> bool:
				return node is InteriorPerson and node.role == "ambtenaar" and node.sitting)
			_check(at_counters.size() == 4, "  ambtenaren achter de vier loketten (%d)" % at_counters.size())
		2:
			var at_desks := floor_node.get_children().filter(func(node: Node) -> bool: return node is InteriorPerson and node.role == "ambtenaar")
			_check(at_desks.size() >= 12, "  de kantoortuin bemand (%d)" % at_desks.size())
		4:
			_check(floor_node.get_children().any(func(node: Node) -> bool: return node is InteriorPerson and node.role == "burgemeester"),
				"  de burgemeester in de raadzaal")


## The plans: five floors, each its own layout, not all the same size, the lift in one place.
func _check_layouts() -> void:
	var floors: Array[Dictionary] = Layout.floors()
	_check(floors.size() == 5, "vijf etages")
	var layouts := {}
	var sizes := {}
	var lifts := {}
	for plan: Dictionary in floors:
		var tiles := {}
		for entry: Array in plan.tiles:
			if String(entry[0]) != "muur" and String(entry[0]) != "muur_laag" and String(entry[0]) != "lift":
				tiles[String(entry[0])] = true
		layouts[str(tiles.keys())] = true
		sizes["%dx%d" % [int(plan.width), int(plan.depth)]] = true
		lifts[(plan.lift as Vector3).x] = true
		print("etage %d %s: %d x %d m, %s" % [int(plan.number), plan.name, int(plan.width), int(plan.depth), ", ".join(tiles.keys())])
	_check(layouts.size() == 5, "elke etage een andere inrichting (%d)" % layouts.size())
	_check(sizes.size() >= 3, "niet allemaal even groot (%s)" % [sizes.keys()])
	_check(lifts.size() == 1, "de lift op elke etage op dezelfde plek")
	_check(floors[0].has("door") and floors[0].tiles.any(func(entry: Array) -> bool: return entry[0] == "receptie"), "een receptie op de begane grond")


func _actions() -> Array:
	return _hud._action_prompts.actions() if _hud._action_prompts.visible else []


func _use() -> void:
	if _player._talk_partner and _player._talk_partner.has_method("go_through"):
		_player._talk_partner.go_through()


func _skip_story() -> void:
	var box: Control = _hud._story_box
	for attempt in 6:
		if not box.is_showing():
			return
		box._pages = box._pages.slice(-1)
		box._page_index = 0
		box._next_page()


func _finish() -> void:
	print("stadhuis ok" if _problems.is_empty() else "stadhuis problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
