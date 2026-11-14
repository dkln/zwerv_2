extends Node3D
## Far out the people on foot and the vehicles are only blocks (the "VerreBlokjes" node;
## behaviour, docs/CODE_LAGEN.md): from FAR_FROM metres in view (the iso camera's view size)
## a figure is a few pixels and its details are lost anyway, so their own models are hidden
## and each is drawn as a box of its size in its colour (the coat of someone on foot, the
## paint of a vehicle): one MultiMesh for all people, one for all vehicles
## (far_boxes_view.gd). Back under NEAR_AGAIN their own models return (far_boxes_rules.gd).
## There are only ever the people and vehicles round the player (Pedestrians, Traffic), so the
## boxes follow just those, moved every frame (their places: far_boxes_layout.gd).

const Iso = preload("res://scripts/camera/iso_camera.gd")
const FarBoxesRules = preload("res://scripts/world/town/far_boxes_rules.gd")
const FarBoxesLayout = preload("res://scripts/world/town/far_boxes_layout.gd")
const FarBoxesView = preload("res://scripts/world/town/far_boxes_view.gd")
const FAR_FROM := FarBoxesRules.FAR_FROM
const NEAR_AGAIN := FarBoxesRules.NEAR_AGAIN
## The block of someone on foot (m): wide, tall, deep.
const PERSON_BOX := FarBoxesLayout.PERSON_BOX
const UNKNOWN_COLOUR := FarBoxesView.UNKNOWN_COLOUR

var far := false
## Its picture: the blocks (null in the editor).
var view: FarBoxesView
var _people: MultiMeshInstance3D
var _vehicles: MultiMeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	view = FarBoxesView.new()
	view.build(self)
	_people = view.people
	_vehicles = view.vehicles


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	if camera == null or view == null:
		return
	far = FarBoxesRules.is_far(Iso.view_size(camera), far)
	view.show_far(far)
	_show_people()
	_show_vehicles()


## Room for `count` blocks (the buffer only grows, in steps), `count` of them drawn.
func _room_for(boxes: MultiMeshInstance3D, count: int) -> void:
	view.show_count(boxes, FarBoxesRules.room_for(boxes.multimesh.instance_count, count), count)


## Everyone on foot: their own figure near, a block far (`far`).
func _show_people() -> void:
	var walkers := get_parent().get_node_or_null("Voetgangers")
	var people: Array = walkers.call("people") if walkers and walkers.has_method("people") else []
	var shown := []
	for person: Node3D in people:
		var drawn: Node3D = person.get("_drawn")
		if drawn == null or not person.is_inside_tree() or person.get("_ragdoll") != null:
			continue
		if drawn.visible == far:
			drawn.visible = not far
		if far:
			shown.append(person)
	if not far:
		return
	_room_for(_people, shown.size())
	for index in shown.size():
		var person: Node3D = shown[index]
		var look: Dictionary = person.figure.look if person.get("figure") else {}
		view.show_block(_people, index, FarBoxesLayout.person_block(person.global_position, person.global_rotation.y),
				look.get("coat", UNKNOWN_COLOUR))


## Every vehicle: its own model near, a block of its size in its paint far (`far`).
func _show_vehicles() -> void:
	var shown := []
	for vehicle: Vehicle in Vehicle.all_vehicles:
		if not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
			continue
		var body: Node3D = vehicle.get("_body")
		# a wreck blinks by itself (Vehicle._follow_wreck): left alone, no block
		if body == null or vehicle.crashed:
			continue
		if body.visible == far:
			body.visible = not far
		if far:
			shown.append(vehicle)
	if not far:
		return
	_room_for(_vehicles, shown.size())
	for index in shown.size():
		var vehicle: Vehicle = shown[index]
		view.show_block(_vehicles, index, FarBoxesLayout.vehicle_block(vehicle.global_transform, vehicle.get("_outer_box")), vehicle._paint())
