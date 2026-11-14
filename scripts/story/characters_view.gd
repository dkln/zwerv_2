extends Node
## What you see and hear of the people of the story beyond their own figure (graphics;
## docs/CODE_LAGEN.md): the amber diamond over the one you walk with, what they call and say
## in a balloon, the shopping trolley full of cans, the smoke of a roll-up, the hands on the
## handle and the drag at the mouth. characters.gd (its parent) says what to show; the places
## come from characters_layout.gd.
##   const CharactersView = preload("res://scripts/story/characters_view.gd")

const CharactersLayout = preload("res://scripts/story/characters_layout.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const CigaretteSmokeScript = preload("res://scripts/effects/cigarette_smoke.gd")
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const TROLLEY_MODEL := "winkel/winkelwagen"
## The keys of a look of personages.json ("uiterlijk") that are colours (#RRGGBB).
const LOOK_COLOURS := ["skin", "hair", "coat", "trim", "trousers", "shoes", "cap", "helmet"]
## The marker over the one you walk with: an amber diamond (the colour of the quest places on
## the map), turning this fast.
const LEAD_MARKER_NAME := "Meeloopmarkering"
const LEAD_MARKER_COLOUR := Color("#FFB830")
const LEAD_MARKER_TURN := 2.0
const BAG_COLOURS := [Color("#2A2C30"), Color("#3A5A8A")]
const CALL_COLOUR := Color.WHITE
const CALL_FONT_SIZE := 13
## The trolley is always filled the same way.
const TROLLEY_SEED := 4711
## Seconds between two looks whether a figure is built yet (the smoke waits for it).
const FIGURE_WAIT := 0.3


func _init() -> void:
	name = "Beeld"


## A look of personages.json ("uiterlijk": colours as #RRGGBB) as TownsfolkFigure has it.
static func look_of(entry: Dictionary) -> Dictionary:
	var look := {}
	for key: String in entry:
		look[key] = Color(str(entry[key])) if key in LOOK_COLOURS else entry[key]
	return look


# ------------------------------------------------------------------ the marker

## The marker over the head (`head_height` over the feet) of the one you walk with.
func show_lead_marker(person: Node3D, head_height: float) -> void:
	if lead_marker_of(person):
		return
	var diamond := SphereMesh.new()   # four sides, one ring: a diamond
	diamond.radial_segments = 4
	diamond.rings = 1
	diamond.radius = CharactersLayout.marker_radius()
	diamond.height = CharactersLayout.marker_length()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = LEAD_MARKER_COLOUR
	material.no_depth_test = true   # seen through roofs and trees too
	material.render_priority = 1
	diamond.material = material
	var marker := MeshInstance3D.new()
	marker.name = LEAD_MARKER_NAME
	marker.mesh = diamond
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	person.add_child(marker)
	marker.position.y = head_height + CharactersLayout.LEAD_MARKER_ABOVE


## The marker gone.
func hide_lead_marker(person: Node3D) -> void:
	var marker := lead_marker_of(person)
	if marker:
		marker.queue_free()


## The marker of `person`, null when it has none.
func lead_marker_of(person: Node3D) -> MeshInstance3D:
	return person.get_node_or_null(LEAD_MARKER_NAME) as MeshInstance3D


## The marker bobs and turns: where it is at `clock` seconds.
func move_lead_marker(person: Node3D, head_height: float, clock: float) -> void:
	var marker := lead_marker_of(person)
	if marker == null:
		return
	marker.position.y = CharactersLayout.marker_height(head_height, clock)
	marker.rotation.y = clock * LEAD_MARKER_TURN


# ------------------------------------------------------------------ what they say

## The call of the one waiting for you, rising over it (the HUD's floating text).
func show_call(hud: Node, person: Node3D, text: String) -> void:
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(person.global_position + Vector3.UP * CharactersLayout.CALL_HEIGHT, text, CALL_COLOUR, CALL_FONT_SIZE)


## A line in a speech balloon `height` over its feet, with its babble in `mood`; false when
## it could not be shown (not in sight, DriverShout.shout_line).
func show_line(person: Node3D, line: String, height: float, mood: String) -> bool:
	return DriverShout.shout_line(person, line, height, mood)


# ------------------------------------------------------------------ the walk of who wanders

## The walk of its figure at `phase`, `walking` 1 (walking) or 0 (standing).
func show_walk(person: Node3D, phase: float, walking: float) -> void:
	var figure: Node3D = person.get("figure")
	if figure:
		figure.call("walk", phase, walking)


## Its hands: on the handle of the trolley it pushes (`pushing`), the right one at the mouth
## while it takes a drag (`dragging`).
func show_hands(person: Node3D, pushing: bool, dragging: bool) -> void:
	var figure: Node3D = person.get("figure")
	if figure == null:
		return
	var handle := figure.to_local(person.to_global(CharactersLayout.handle_point()))
	if pushing:
		figure.call("aim_arm", "left", CharactersLayout.hand_point(handle, -1.0))
		if not dragging:
			figure.call("aim_arm", "right", CharactersLayout.hand_point(handle, 1.0))
	if dragging:
		figure.call("aim_arm", "right", TownsfolkFigure.cell_point(CharactersLayout.DRAG_CELL))


## A cloud blown out after a drag.
func show_puff(smoke: Node) -> void:
	smoke.call("exhale")


## The smoke of a roll-up for `person`, put at the mouth of its figure once that is built.
func show_smoke(person: Node3D) -> Node3D:
	var smoke: Node3D = CigaretteSmokeScript.new()
	smoke.name = "Rook"
	_put_smoke_at_mouth.call_deferred(person, smoke)
	return smoke


func _put_smoke_at_mouth(person: Node3D, smoke: Node3D) -> void:
	if not is_instance_valid(person) or not is_instance_valid(smoke):
		return
	var figure: Node3D = person.get("figure")
	if figure == null:
		get_tree().create_timer(FIGURE_WAIT).timeout.connect(_put_smoke_at_mouth.bind(person, smoke))
		return
	figure.add_child(smoke)
	smoke.position = TownsfolkFigure.cell_point(CharactersLayout.SMOKE_CELL)


# ------------------------------------------------------------------ the trolley

## A shopping trolley (the props' winkel/winkelwagen) before `person`, full of cans
## (MachineModels.can_mesh) and a few bulging bin bags.
func show_trolley(person: Node3D) -> Node3D:
	var trolley := Node3D.new()
	trolley.name = "Winkelkarretje"
	trolley.position = CharactersLayout.trolley_position()
	person.add_child(trolley)
	var basket := _add_trolley_model(trolley)
	var random := RandomNumberGenerator.new()
	random.seed = TROLLEY_SEED
	# the bags first, low in the basket; the cans heaped up over and round them
	for bag_index in CharactersLayout.BAGS:
		trolley.add_child(_bag(bag_index, basket, random))
	for can_index in CharactersLayout.CANS:
		trolley.add_child(_can(can_index, basket, random))
	return trolley


## The model of the trolley under `trolley`; returns its basket (the usual one without a model).
func _add_trolley_model(trolley: Node3D) -> AABB:
	var library := load(PROPS_LIBRARY) as MeshLibrary
	var item := library.find_item_by_name(TROLLEY_MODEL) if library else -1
	if item < 0:
		return CharactersLayout.BASKET
	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = library.get_item_mesh(item)
	model.transform = library.get_item_mesh_transform(item)
	trolley.add_child(model)
	return CharactersLayout.basket_in(model.transform * model.mesh.get_aabb())


func _bag(bag_index: int, basket: AABB, random: RandomNumberGenerator) -> MeshInstance3D:
	var bag := MeshInstance3D.new()
	bag.name = "Vuilniszak%d" % (bag_index + 1)
	var bag_mesh := BoxMesh.new()
	bag_mesh.size = CharactersLayout.BAG_SIZE
	var bag_material := StandardMaterial3D.new()
	bag_material.albedo_color = BAG_COLOURS[bag_index % BAG_COLOURS.size()]
	bag_material.roughness = 0.4
	bag_mesh.material = bag_material
	bag.mesh = bag_mesh
	bag.position = CharactersLayout.bag_position(basket, bag_index)
	bag.rotation.y = random.randf_range(-0.4, 0.4)
	return bag


func _can(can_index: int, basket: AABB, random: RandomNumberGenerator) -> MeshInstance3D:
	var can := MeshInstance3D.new()
	can.name = "Blikje%d" % (can_index + 1)
	can.mesh = MachineModels.can_mesh()
	var across := random.randf()
	var up := random.randf_range(0.5, 1.0)
	var along := random.randf()
	can.position = CharactersLayout.can_position(basket, across, up, along)
	can.scale = Vector3.ONE * CharactersLayout.CAN_SCALE
	var tilt := random.randf_range(-1.4, 1.4)
	var turn := random.randf() * TAU
	var roll := random.randf_range(-1.4, 1.4)
	can.rotation = Vector3(tilt, turn, roll)
	return can
