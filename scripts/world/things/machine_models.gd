extends RefCounted
## The voxel models of the machines and the small things to pick up, made in code from voxels
## (PlayerModel.VoxelFigure, as the rucksack lying in the town) so they need no tiles in the
## libraries: the cash machine on the pavement (PINPUNT), the deposit machine of the
## supermarkets (STATIEGELD), an empty can and a lost bank card. Each mesh is made once and
## shared; it stands on y = 0, centred, its front facing +z (as the tiles at turn 0).
## `with_collider` gives a StaticBody3D (the town layer) the size of the model, so the player
## and the people walk round it.
##   const MachineModels = preload("res://scripts/world/things/machine_models.gd")
##   add_child(MachineModels.cash_machine())

const PlayerModel = preload("res://scripts/player/player_model.gd")
## Metres per voxel of the machines and of the small things.
const MACHINE_VOXEL := 0.0625
const SMALL_VOXEL := 0.05
const TOWN_LAYER := 1

## The house colours of the cash machine (fictional bank: PINPUNT) and of the deposit machine.
const ATM_BODY := Color("#3A4250")
const ATM_TRIM := Color("#F2B705")
const ATM_SCREEN := Color("#5FE0FF")
const ATM_KEYS := Color("#C9CED6")
const DEPOSIT_BODY := Color("#E8ECEA")
const DEPOSIT_TRIM := Color("#2E9A48")
const DEPOSIT_SCREEN := Color("#9CFF7A")
const DARK := Color("#14161C")
const STEEL := Color("#8C939E")

static var _meshes := {}


## The cash machine: a dark pillar with a yellow top (PINPUNT), its screen, card slot,
## keypad and the slot the money comes out of.
static func cash_machine_mesh() -> ArrayMesh:
	if not _meshes.has("geldautomaat"):
		var figure := PlayerModel.VoxelFigure.new()
		var width := 12
		var depth := 8
		# the front is voxel z = 0 (VoxelFigure mirrors z: z = 0 faces +z), the back against the wall
		var front := 0
		var back := depth - 1
		_box(figure, Vector3i(0, 0, 0), Vector3i(width - 1, 1, back), DARK, "metal")
		_box(figure, Vector3i(0, 2, front + 1), Vector3i(width - 1, 23, back), ATM_BODY, "plastic")
		# the front face: a recess round the screen, a hood over it
		_box(figure, Vector3i(1, 2, front), Vector3i(width - 2, 22, front), ATM_BODY.darkened(0.15), "plastic")
		_box(figure, Vector3i(2, 16, front), Vector3i(width - 3, 20, front), ATM_SCREEN, "glow", true)
		_box(figure, Vector3i(1, 21, front), Vector3i(width - 2, 22, front), DARK, "plastic")
		_box(figure, Vector3i(7, 14, front), Vector3i(9, 14, front), DARK, "plastic")          # card slot
		_box(figure, Vector3i(3, 10, front), Vector3i(6, 13, front), ATM_KEYS, "metal")        # keypad
		for key_row in 2:
			for key_column in 2:
				figure.put(3 + key_column * 2, 10 + key_row * 2, front, STEEL)
		_box(figure, Vector3i(8, 11, front), Vector3i(8, 11, front), Color("#3CE06A"), "glow", true)
		_box(figure, Vector3i(3, 7, front), Vector3i(8, 7, front), DARK, "plastic")            # money slot
		# the sign on top
		_box(figure, Vector3i(0, 24, 0), Vector3i(width - 1, 27, back), ATM_TRIM, "glow", true)
		_box(figure, Vector3i(2, 25, front), Vector3i(width - 3, 26, front), ATM_BODY, "plastic")
		figure.mark("metal", [STEEL])
		_meshes["geldautomaat"] = _mesh_of(figure, MACHINE_VOXEL)
	return _meshes["geldautomaat"]


## The deposit machine: a white cabinet with a green top (STATIEGELD), the round hole the
## cans and bottles go in, a little screen and the slot of the bon.
static func deposit_machine_mesh() -> ArrayMesh:
	if not _meshes.has("statiegeldautomaat"):
		var figure := PlayerModel.VoxelFigure.new()
		var width := 14
		var depth := 10
		# the front is voxel z = 0 (VoxelFigure mirrors z: z = 0 faces +z)
		var front := 0
		var back := depth - 1
		_box(figure, Vector3i(0, 0, 0), Vector3i(width - 1, 1, back), DARK, "metal")
		_box(figure, Vector3i(0, 2, 0), Vector3i(width - 1, 25, back), DEPOSIT_BODY, "plastic")
		# the hole: a dark ring in a steel collar
		_box(figure, Vector3i(4, 12, front), Vector3i(9, 17, front), STEEL, "metal")
		_box(figure, Vector3i(5, 13, front), Vector3i(8, 16, front), DARK, "plastic")
		_box(figure, Vector3i(4, 20, front), Vector3i(9, 23, front), DEPOSIT_SCREEN, "glow", true)
		_box(figure, Vector3i(10, 9, front), Vector3i(12, 9, front), DARK, "plastic")          # the bon
		_box(figure, Vector3i(11, 13, front), Vector3i(11, 14, front), Color("#E83A30"), "glow", true)
		_box(figure, Vector3i(0, 26, 0), Vector3i(width - 1, 29, back), DEPOSIT_TRIM, "glow", true)
		_box(figure, Vector3i(2, 27, front), Vector3i(width - 3, 28, front), DEPOSIT_BODY, "plastic")
		_meshes["statiegeldautomaat"] = _mesh_of(figure, MACHINE_VOXEL)
	return _meshes["statiegeldautomaat"]


## An empty can, a little dented: red with a silver top.
static func can_mesh() -> ArrayMesh:
	if not _meshes.has("blikje"):
		var figure := PlayerModel.VoxelFigure.new()
		var red := Color("#C8242C")
		_box(figure, Vector3i(0, 0, 0), Vector3i(2, 0, 2), STEEL, "metal")
		_box(figure, Vector3i(0, 1, 0), Vector3i(2, 3, 2), red, "metal")
		_box(figure, Vector3i(1, 2, 2), Vector3i(1, 2, 2), Color("#F2F2F2"), "plastic")
		_box(figure, Vector3i(0, 4, 0), Vector3i(2, 4, 2), STEEL, "metal")
		figure.clear(2, 3, 0)   # the dent
		_meshes["blikje"] = _mesh_of(figure, SMALL_VOXEL)
	return _meshes["blikje"]


## A bank card, upright: blue with a gold chip and a white stripe.
static func bank_card_mesh() -> ArrayMesh:
	if not _meshes.has("pinpas"):
		var figure := PlayerModel.VoxelFigure.new()
		var blue := Color("#2A5CC8")
		_box(figure, Vector3i(0, 0, 0), Vector3i(5, 3, 0), blue, "plastic")
		_box(figure, Vector3i(1, 1, 0), Vector3i(1, 2, 0), Color("#F2C230"), "metal")
		_box(figure, Vector3i(3, 3, 0), Vector3i(5, 3, 0), Color("#F2F2F2"), "plastic")
		_meshes["pinpas"] = _mesh_of(figure, SMALL_VOXEL)
	return _meshes["pinpas"]


## A cash machine (or another of these meshes) as a node: the mesh and, with
## `with_collider`, a body round it.
static func instance(mesh: Mesh, node_name: String, with_collider := true) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	var shape_instance := MeshInstance3D.new()
	shape_instance.name = "Model"
	shape_instance.mesh = mesh
	holder.add_child(shape_instance)
	if with_collider:
		var box := mesh.get_aabb()
		var body := StaticBody3D.new()
		body.name = "Botsvorm"
		body.collision_layer = TOWN_LAYER
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		collider.shape = shape
		collider.position = box.get_center()
		body.add_child(collider)
		holder.add_child(body)
	return holder


static func _box(figure: PlayerModel.VoxelFigure, from: Vector3i, to: Vector3i, colour: Color, kind: String,
		glow := false) -> void:
	figure.box(from, to, colour, glow)
	figure.mark(kind if kind != "glow" else "plastic", [colour])


static func _mesh_of(figure: PlayerModel.VoxelFigure, voxel: float) -> ArrayMesh:
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind)
	var parts: Dictionary = figure.to_parts(voxel, {}, materials, PlayerModel.graded)
	return parts.meshes.body
