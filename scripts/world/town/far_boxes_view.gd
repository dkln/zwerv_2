extends RefCounted
## The blocks of the far-off people and vehicles (graphics; docs/CODE_LAGEN.md): one
## MultiMesh of unit cubes for all people ("Voetgangers") and one for all vehicles
## ("Voertuigen"), a single draw each, every block in its own colour, without shadows. Built
## into the node of far_boxes.gd (build), which says whether they show and where each block
## is (show_far, show_blocks).
##   const FarBoxesView = preload("res://scripts/world/town/far_boxes_view.gd")

## The colour of a block whose figure has none.
const UNKNOWN_COLOUR := Color("#8A8680")

var people: MultiMeshInstance3D
var vehicles: MultiMeshInstance3D


## Builds the two sets of blocks as children of `host`, hidden.
func build(host: Node3D) -> void:
	people = _boxes(host, "Voetgangers")
	vehicles = _boxes(host, "Voertuigen")


static func _boxes(host: Node3D, boxes_name: String) -> MultiMeshInstance3D:
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
	host.add_child(instance)
	return instance


## The blocks shown (far) or not.
func show_far(far: bool) -> void:
	people.visible = far
	vehicles.visible = far


## Room for `room` blocks in `boxes` (people or vehicles), `count` of them drawn.
func show_count(boxes: MultiMeshInstance3D, room: int, count: int) -> void:
	if boxes.multimesh.instance_count != room:
		boxes.multimesh.instance_count = room
	boxes.multimesh.visible_instance_count = count


## Block `index` of `boxes` at `block` (a unit cube placed and stretched) in `colour`.
func show_block(boxes: MultiMeshInstance3D, index: int, block: Transform3D, colour: Color) -> void:
	boxes.multimesh.set_instance_transform(index, block)
	boxes.multimesh.set_instance_color(index, colour)
