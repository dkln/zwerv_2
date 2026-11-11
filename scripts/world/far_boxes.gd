extends Node3D
## Far out the people on foot and the vehicles are only blocks (the "VerreBlokjes" node): from
## FAR_FROM metres in view (the iso camera's view size) a figure is a few pixels and its
## details are lost anyway, so their own models are hidden and each is drawn as a box of its
## size in its colour (the coat of someone on foot, the paint of a vehicle): one MultiMesh for
## all people, one for all vehicles, a single draw each. Back under NEAR_AGAIN their own
## models return (the gap between the two so it does not flip to and fro while zooming).
## There are only ever the people and vehicles round the player (Pedestrians, Traffic), so the
## boxes follow just those, moved every frame.

const Iso = preload("res://scripts/camera/iso_camera.gd")
const FAR_FROM := 95.0
const NEAR_AGAIN := 85.0
## The block of someone on foot (m): wide, tall, deep.
const PERSON_BOX := Vector3(0.5, 1.75, 0.35)
const UNKNOWN_COLOUR := Color("#8A8680")

var far := false
var _people: MultiMeshInstance3D
var _vehicles: MultiMeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_people = _boxes("Voetgangers")
	_vehicles = _boxes("Voertuigen")


func _boxes(boxes_name: String) -> MultiMeshInstance3D:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	cube.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	var instance := MultiMeshInstance3D.new()
	instance.name = boxes_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = false
	add_child(instance)
	return instance


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	if camera == null or _people == null:
		return
	var view := Iso.view_size(camera)
	far = view > (NEAR_AGAIN if far else FAR_FROM)
	_people.visible = far
	_vehicles.visible = far
	_show_people()
	_show_vehicles()


## Room for `count` blocks (the buffer only grows, in steps), `count` of them drawn.
static func _room_for(multimesh: MultiMesh, count: int) -> void:
	if multimesh.instance_count < count:
		multimesh.instance_count = count + 32
	multimesh.visible_instance_count = count


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
	var multimesh := _people.multimesh
	_room_for(multimesh, shown.size())
	for index in shown.size():
		var person: Node3D = shown[index]
		var look: Dictionary = person.figure.look if person.get("figure") else {}
		var at := Transform3D(Basis(Vector3.UP, person.global_rotation.y).scaled(PERSON_BOX),
				person.global_position + Vector3.UP * PERSON_BOX.y * 0.5)
		multimesh.set_instance_transform(index, at)
		multimesh.set_instance_color(index, look.get("coat", UNKNOWN_COLOUR))


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
	var multimesh := _vehicles.multimesh
	_room_for(multimesh, shown.size())
	for index in shown.size():
		var vehicle: Vehicle = shown[index]
		var box: AABB = vehicle.get("_outer_box")
		var at := vehicle.global_transform * Transform3D(Basis.from_scale(box.size), box.get_center())
		multimesh.set_instance_transform(index, at)
		multimesh.set_instance_color(index, vehicle._paint())
