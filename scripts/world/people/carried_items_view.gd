extends RefCounted
## What a townsperson carries, as you see it (graphics; docs/CODE_LAGEN.md): a rucksack, a
## trolley case, a briefcase, a handbag or a shoulder bag, built in code from voxels at the
## size the figures are drawn at (TownsfolkFigure.VOXEL), one mesh per kind and colour,
## shared; hung on the figure where carried_items_layout.gd says, and the arm that holds it
## put right after each step of the walk. What is carried and in which colour:
## carried_items.gd.
##   const CarriedItemsView = preload("res://scripts/world/people/carried_items_view.gd")

const PlayerModel = preload("res://scripts/player/player_model.gd")
const CarriedItemsLayout = preload("res://scripts/world/people/carried_items_layout.gd")

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
## Someone in a suit (CarriedItems.business_look): the jackets (the trousers go with them),
## the shirts (the collar) and the polished shoes.
const SUITS := [Color("#22262E"), Color("#2A3448"), Color("#3A3C40"), Color("#1A1C20"), Color("#4A4A50"), Color("#2E2A36")]
const SHIRTS := [Color("#E8E6E0"), Color("#C8D8EC"), Color("#E8E0E4")]
const SUIT_SHOES := [Color("#1A1612"), Color("#3A2416")]
## The names of the holder (plus the kind), its model and the strap of a shoulder bag.
const HOLDER_PREFIX := "Draagt_"
const MODEL_NAME := "Model"
const STRAP_NAME := "Riem"

static var _meshes := {}   # "kind|colour" -> ArrayMesh


## Hangs a `kind` in `colour` on `figure`; the node it put there.
static func build(figure: TownsfolkFigure, kind: String, colour: Color) -> Node3D:
	var holder := Node3D.new()
	holder.name = HOLDER_PREFIX + kind
	holder.set_meta("kind", kind)
	var shape := MeshInstance3D.new()
	shape.name = MODEL_NAME
	shape.mesh = mesh_for(kind, colour)
	holder.add_child(shape)
	match kind:
		"aktetas", "handtas":
			_hang_in_hand(figure, holder, shape)
		"rugzak":
			_on_body(figure).add_child(holder)
			holder.position = CarriedItemsLayout.rucksack_spot(figure.hip_middle(), shape.mesh.get_aabb().size.z)
		"schoudertas":
			_on_body(figure).add_child(holder)
			# on the left hip, the strap over the right shoulder (a band across the chest)
			holder.position = CarriedItemsLayout.shoulder_bag_spot(figure.rest_joint("arm_left"), figure.hip_middle())
			_add_strap(holder, figure)
		"rolkoffer":
			figure.add_child(holder)
			_stand_trolley(figure, holder, shape)
		_:
			figure.add_child(holder)
	return holder


## The arm after the walk: at the handle of a trolley case; a briefcase or a handbag swings
## less (it is heavy).
static func show_pose(figure: TownsfolkFigure, kind: String) -> void:
	match kind:
		"rolkoffer":
			var holder := figure.get_node_or_null(HOLDER_PREFIX + "rolkoffer") as Node3D
			if holder == null:
				return
			var shape := holder.get_node_or_null(MODEL_NAME) as MeshInstance3D
			if shape == null:
				return
			figure.aim_arm("right", holder.transform * (_trolley_grip(shape.mesh) + shape.position))
		"aktetas", "handtas":
			var arm := figure.get_node_or_null("arm_right") as Node3D
			if arm:
				# a third of the swing: turn the joint back towards hanging straight
				arm.transform.basis = CarriedItemsLayout.heavy_arm(arm.transform.basis.get_euler().x)


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
			_trolley_voxels(figure, colour, darker)
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


## The case on its narrow side: ribbed shell, a band round it; the handle side at the front
## (z 0, the side that faces the one pulling it), the wheels at its bottom.
static func _trolley_voxels(figure: PlayerModel.VoxelFigure, colour: Color, darker: Color) -> void:
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


## A briefcase or a handbag in the right hand: a child of the arm's joint (it swings with
## the arm), the grip on top (the mesh stands on y = 0, so it hangs down from the hand).
static func _hang_in_hand(figure: TownsfolkFigure, holder: Node3D, shape: MeshInstance3D) -> void:
	var arm := figure.get_node_or_null("arm_right") as Node3D
	if arm == null:
		figure.add_child(holder)
		holder.position = CarriedItemsLayout.in_hand_from_shoulder(figure.rest_joint("arm_right"), TownsfolkFigure.arm_length())
	else:
		arm.add_child(holder)
		holder.position = CarriedItemsLayout.in_hand(TownsfolkFigure.arm_length())
	shape.position = CarriedItemsLayout.hanging_from_grip(shape.mesh.get_aabb().end.y)


## A trolley case behind the figure: its wheels on the ground, leaning over them towards the
## one pulling it, its grip at the hand.
static func _stand_trolley(figure: TownsfolkFigure, holder: Node3D, shape: MeshInstance3D) -> void:
	shape.position = CarriedItemsLayout.trolley_model_spot(shape.mesh.get_aabb())
	holder.rotation.x = CarriedItemsLayout.TROLLEY_TILT
	var hand := CarriedItemsLayout.trolley_hand(figure.rest_joint("arm_right"), TownsfolkFigure.arm_length())
	holder.position = CarriedItemsLayout.trolley_spot(hand, _trolley_grip(shape.mesh), shape.position)


## The body of the figure (what bobs with the walk), or the figure without one.
static func _on_body(figure: TownsfolkFigure) -> Node3D:
	var body := figure.get_node_or_null("Lijf") as Node3D
	return body if body else figure


static func _trolley_grip(mesh: Mesh) -> Vector3:
	return CarriedItemsLayout.trolley_grip(mesh.get_aabb(), TownsfolkFigure.VOXEL)


## The strap of a shoulder bag: a thin band from the bag up across the chest to the other
## shoulder.
static func _add_strap(holder: Node3D, figure: TownsfolkFigure) -> void:
	var ends := CarriedItemsLayout.strap_ends(figure.rest_joint("arm_right"), holder.position)
	var strap := MeshInstance3D.new()
	strap.name = STRAP_NAME
	var band := BoxMesh.new()
	band.size = CarriedItemsLayout.strap_size(ends[0], ends[1])
	strap.mesh = band
	var material := StandardMaterial3D.new()
	material.albedo_color = STRAP
	material.roughness = 0.6
	strap.material_override = material
	holder.add_child(strap)
	strap.transform = CarriedItemsLayout.strap_transform(ends[0], ends[1], holder.position)
