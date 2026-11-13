class_name CarriedItems
extends RefCounted
## What a townsperson (TownsfolkFigure) carries: a rucksack, a trolley case pulled along
## behind, a briefcase, a handbag or a shoulder bag. Built in code from voxels at the size the
## figures are drawn at (TownsfolkFigure.VOXEL), like the figures themselves, one mesh per kind
## and colour, shared. Used by the travellers in the station (scripts/world/station/station.gd) and the
## pedestrians in the town.
##   var bag := CarriedItems.attach(figure, "aktetas", 17)
##   ...each update, after figure.walk(phase, amount):
##   CarriedItems.pose(figure, "aktetas")
## Where it hangs: a briefcase and a handbag in the right hand (a child of the arm's joint, so
## it swings with the arm), a rucksack and a shoulder bag on the body (they bob with it), a
## trolley case on the ground behind, its handle in the right hand (pose aims the arm at it).
## Voxels: x across, y up, z from the front (0) backwards, as the figures.

const PlayerModel = preload("res://scripts/player/player_model.gd")

const KINDS: Array[String] = ["rugzak", "rolkoffer", "aktetas", "handtas", "schoudertas"]
## Colours per kind (picked by colour_seed).
const COLOURS := {
	"rugzak": [Color("#5E6440"), Color("#2A3A5A"), Color("#8A2A2A"), Color("#22242A"), Color("#C86A20")],
	"rolkoffer": [Color("#22242A"), Color("#3E5A86"), Color("#9A2A2A"), Color("#8A8E94"), Color("#2A6A5A"), Color("#C8A040")],
	"aktetas": [Color("#2A1E16"), Color("#4A3020"), Color("#141210")],
	"handtas": [Color("#5A3A22"), Color("#8A2A2A"), Color("#22242A"), Color("#C8B48A")],
	"schoudertas": [Color("#3A3A40"), Color("#5A3A22"), Color("#2A4A3A"), Color("#6A5A4A")],
}
const DARK_METAL := Color("#2A2C30")
const LIGHT_METAL := Color("#B8BCC2")
const STRAP := Color("#1A1612")
## The trolley case: how far it leans over its wheels towards the one pulling it (radians)
## and how far behind the shoulder the hand holds its handle (metres).
const TROLLEY_TILT := 0.75
const TROLLEY_HAND_BACK := 0.3
## The case hangs this far below the hand (metres: from the hand to the top of its grip).
const HAND_GRIP_DROP := 0.02

static var _meshes := {}   # "kind|colour" -> ArrayMesh


## Hangs a `kind` (KINDS) on `figure` in a colour of `colour_seed`; the node it put there.
static func attach(figure: TownsfolkFigure, kind: String, colour_seed: int) -> Node3D:
	var colours: Array = COLOURS.get(kind, COLOURS.rugzak)
	var colour: Color = colours[absi(colour_seed) % colours.size()]
	var holder := Node3D.new()
	holder.name = "Draagt_" + kind
	holder.set_meta("kind", kind)
	var shape := MeshInstance3D.new()
	shape.name = "Model"
	shape.mesh = mesh_for(kind, colour)
	holder.add_child(shape)
	var hips := figure.hip_middle()
	match kind:
		"aktetas", "handtas":
			# in the hand: below the arm's joint by the length of the arm
			var arm := figure.get_node_or_null("arm_right") as Node3D
			if arm == null:
				figure.add_child(holder)
				holder.position = figure.rest_joint("arm_right") + Vector3(0.0, -TownsfolkFigure.arm_length(), 0.0)
			else:
				arm.add_child(holder)
				holder.position = Vector3(0.0, -TownsfolkFigure.arm_length() - HAND_GRIP_DROP, 0.0)
			# the grip on top: the mesh stands on y = 0, so it hangs down from the hand
			shape.position = Vector3(0.0, -_height_of(shape.mesh), 0.0)
		"rugzak":
			var body := figure.get_node_or_null("Lijf") as Node3D
			(body if body else figure).add_child(holder)
			var depth := _depth_of(shape.mesh)
			holder.position = Vector3(hips.x, hips.y + 0.08, hips.z - 0.1 - depth * 0.5)
		"schoudertas":
			var body := figure.get_node_or_null("Lijf") as Node3D
			(body if body else figure).add_child(holder)
			# on the left hip, the strap over the right shoulder (a band across the chest)
			var shoulder := figure.rest_joint("arm_left")
			holder.position = Vector3(shoulder.x * 0.95, hips.y - 0.05, hips.z)
			_add_strap(holder, figure)
		"rolkoffer":
			figure.add_child(holder)
			# the wheels (the bottom of its handle side) on the ground at the holder, the case
			# leaning over them towards the one pulling it
			var box := shape.mesh.get_aabb()
			shape.position = Vector3(-box.get_center().x, 0.0, -box.end.z)
			holder.rotation.x = TROLLEY_TILT
			var hand := _trolley_hand(figure)
			var grip := Basis(Vector3.RIGHT, TROLLEY_TILT) * (_trolley_grip(shape.mesh) + shape.position)
			holder.position = Vector3(hand.x - grip.x, 0.0, hand.z - grip.z)
		_:
			figure.add_child(holder)
	return holder


## The arm after the walk: at the handle of a trolley case; a briefcase or a handbag swings
## less (it is heavy). Call it after figure.walk().
static func pose(figure: TownsfolkFigure, kind: String) -> void:
	match kind:
		"rolkoffer":
			var holder := figure.get_node_or_null("Draagt_rolkoffer") as Node3D
			if holder == null:
				return
			var shape := holder.get_node_or_null("Model") as MeshInstance3D
			if shape == null:
				return
			figure.aim_arm("right", holder.transform * (_trolley_grip(shape.mesh) + shape.position))
		"aktetas", "handtas":
			var arm := figure.get_node_or_null("arm_right") as Node3D
			if arm:
				# a third of the swing: turn the joint back towards hanging straight
				var swing := arm.transform.basis.get_euler().x
				arm.transform.basis = Basis(Vector3.RIGHT, swing * 0.35)


## A look in a suit: a dark jacket with a white collar (the shirt), the trousers of the
## jacket, polished shoes, short hair or long (never a cap); now and then a skirt.
static func business_look(look_seed: int) -> Dictionary:
	var look := TownsfolkFigure.look_for(look_seed)
	var random := RandomNumberGenerator.new()
	random.seed = look_seed * 31 + 7
	var suits := [Color("#22262E"), Color("#2A3448"), Color("#3A3C40"), Color("#1A1C20"), Color("#4A4A50"), Color("#2E2A36")]
	var suit: Color = suits[random.randi() % suits.size()]
	look["coat"] = suit
	look["trim"] = [Color("#E8E6E0"), Color("#C8D8EC"), Color("#E8E0E4")][random.randi() % 3]
	look["trousers"] = suit
	look["shoes"] = [Color("#1A1612"), Color("#3A2416")][random.randi() % 2]
	if look.hair_style == "pet":
		look["hair_style"] = "kort"
	look["skirt"] = look.hair_style == "lang" and random.randf() < 0.45
	return look


## The mesh of a kind in a colour, built once.
static func mesh_for(kind: String, colour: Color) -> ArrayMesh:
	var key := "%s|%s" % [kind, colour.to_html()]
	if _meshes.has(key):
		return _meshes[key]
	var figure := PlayerModel.VoxelFigure.new()
	var darker := colour.darkened(0.3)
	match kind:
		"rugzak":
			figure.box(Vector3i(0, 0, 0), Vector3i(6, 9, 3), colour)
			figure.box(Vector3i(0, 8, 0), Vector3i(6, 9, 3), darker)          # the flap
			figure.box(Vector3i(1, 2, -1), Vector3i(5, 5, -1), darker)        # the front pocket
			figure.mark("cloth", [colour, darker])
		"rolkoffer":
			# the case on its narrow side: ribbed shell, a band round it; the handle side at the
			# front (z 0, the side that faces the one pulling it), the wheels at its bottom
			figure.box(Vector3i(0, 1, 1), Vector3i(7, 11, 5), colour)
			for rib_x: int in [2, 5]:
				figure.box(Vector3i(rib_x, 2, 6), Vector3i(rib_x, 10, 6), darker)
			figure.box(Vector3i(0, 6, 0), Vector3i(7, 6, 6), darker)
			for wheel_x: int in [0, 7]:
				figure.put(wheel_x, 0, 1, DARK_METAL)
			# the pulled-out handle: two rods up along the handle side, the grip across them
			for rod_x: int in [2, 5]:
				figure.box(Vector3i(rod_x, 1, 0), Vector3i(rod_x, 19, 0), LIGHT_METAL)
			figure.box(Vector3i(2, 20, 0), Vector3i(5, 20, 0), DARK_METAL)
			figure.mark("plastic", [colour, darker])
			figure.mark("metal", [LIGHT_METAL, DARK_METAL])
		"aktetas":
			figure.box(Vector3i(0, 0, 0), Vector3i(8, 6, 1), colour)
			figure.box(Vector3i(0, 6, 0), Vector3i(8, 6, 1), darker)          # the flap
			figure.box(Vector3i(3, 7, 0), Vector3i(5, 7, 1), DARK_METAL)      # the grip
			figure.put(4, 5, -1, LIGHT_METAL)                                  # the lock
			figure.mark("leather", [colour, darker])
			figure.mark("metal", [LIGHT_METAL, DARK_METAL])
		"handtas":
			figure.box(Vector3i(0, 0, 0), Vector3i(5, 4, 2), colour)
			figure.box(Vector3i(1, 5, 1), Vector3i(1, 6, 1), darker)
			figure.box(Vector3i(4, 5, 1), Vector3i(4, 6, 1), darker)
			figure.box(Vector3i(1, 7, 1), Vector3i(4, 7, 1), darker)          # the handles
			figure.mark("leather", [colour, darker])
		"schoudertas":
			figure.box(Vector3i(0, 0, 0), Vector3i(1, 6, 6), colour)
			figure.box(Vector3i(0, 5, 0), Vector3i(1, 6, 6), darker)
			figure.mark("cloth", [colour, darker])
		_:
			figure.box(Vector3i.ZERO, Vector3i(3, 3, 3), colour)
	var materials := {}
	for material_kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[material_kind] = PlayerModel.material_for(material_kind, true)
	var parts: Dictionary = figure.to_parts(TownsfolkFigure.VOXEL, {}, materials, PlayerModel.graded)
	var mesh: ArrayMesh = parts.meshes.body
	_meshes[key] = mesh
	return mesh


## Where the hand of the one pulling a trolley case is (in the figure): behind and below the
## shoulder, the arm almost straight.
static func _trolley_hand(figure: TownsfolkFigure) -> Vector3:
	var shoulder := figure.rest_joint("arm_right")
	var down := sqrt(maxf(pow(TownsfolkFigure.arm_length() * 0.95, 2.0) - TROLLEY_HAND_BACK * TROLLEY_HAND_BACK, 0.01))
	return shoulder + Vector3(0.0, -down, -TROLLEY_HAND_BACK)


## The grip of a trolley case in the space of its mesh (upright): the top middle of its
## handle, on the handle side (the highest z of the mesh: voxel z 0 is its front).
static func _trolley_grip(mesh: Mesh) -> Vector3:
	var box := mesh.get_aabb()
	return Vector3(box.get_center().x, box.end.y, box.end.z - TownsfolkFigure.VOXEL * 0.5)


static func _height_of(mesh: Mesh) -> float:
	return mesh.get_aabb().end.y


static func _depth_of(mesh: Mesh) -> float:
	return mesh.get_aabb().size.z


## The strap of a shoulder bag: a thin band from the bag up across the chest to the other
## shoulder.
static func _add_strap(holder: Node3D, figure: TownsfolkFigure) -> void:
	var other_shoulder := figure.rest_joint("arm_right")
	var top := other_shoulder + Vector3(0.0, 0.02, 0.0)
	var bottom := holder.position + Vector3(0.0, 0.3, 0.0)
	var strap := MeshInstance3D.new()
	strap.name = "Riem"
	var band := BoxMesh.new()
	var length := top.distance_to(bottom)
	band.size = Vector3(0.04, length, 0.03)
	strap.mesh = band
	var material := StandardMaterial3D.new()
	material.albedo_color = STRAP
	material.roughness = 0.6
	strap.material_override = material
	holder.add_child(strap)
	var middle := (top + bottom) * 0.5
	var up := (top - bottom).normalized()
	var side := up.cross(Vector3.BACK).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var basis := Basis(side, up, side.cross(up).normalized())
	# the strap goes over the front of the chest: half a torso in front of the hips
	strap.transform = Transform3D(basis, middle - holder.position + Vector3(0.0, 0.0, 0.12))
