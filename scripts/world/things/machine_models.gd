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
## The dark grey round the cash machine's screen, keypad and reader; the grey round the
## deposit machine's screen.
const ATM_BEZEL := Color("#252A34")
const DEPOSIT_BEZEL := Color("#9AA0A6")
## The deposit machine's hole for cans and bottles and its bay for crates (voxels x, y of
## the openings, the corners included) and how deep they go behind its face.
const HOLE_FROM := Vector2i(5, 13)
const HOLE_TO := Vector2i(8, 17)
const HOLE_DEPTH := 5
const BAY_FROM := Vector2i(2, 3)
const BAY_TO := Vector2i(11, 9)
const BAY_DEPTH := 7
const STEEL := Color("#8C939E")

static var _meshes := {}


## The cash machine: a dark pillar with a yellow top (PINPUNT). Its front (voxel z = 1) has the
## screen sunk a voxel deep in a dark bezel under a hood, soft keys either side of it, the
## card reader with its slit and green light, the keypad (twelve keys standing out of a
## darker panel, and the red, yellow and green keys beside them) and below that the steel
## mouth the money comes out of, its slit sunk into it. What stands out is on z = 0.
static func cash_machine_mesh() -> ArrayMesh:
	if not _meshes.has("geldautomaat"):
		var figure := PlayerModel.VoxelFigure.new()
		var width := 12
		var depth := 8
		# the front is voxel z = 0 (VoxelFigure mirrors z: z = 0 faces +z), the back against the wall;
		# the face of the body is z = 1, what stands out of it z = 0
		var face := 1
		var back := depth - 1
		_box(figure, Vector3i(0, 0, 0), Vector3i(width - 1, 1, back), DARK, "metal")
		_box(figure, Vector3i(0, 2, face), Vector3i(width - 1, 23, back), ATM_BODY, "plastic")
		# the screen: in a dark bezel, sunk (the glass on z = 2), a hood over it
		_box(figure, Vector3i(1, 15, face), Vector3i(width - 2, 21, face), ATM_BEZEL, "plastic")
		_recess(figure, Vector3i(2, 16, face), Vector3i(width - 3, 20, face))
		_box(figure, Vector3i(2, 16, face + 1), Vector3i(width - 3, 20, face + 1), ATM_SCREEN, "glow", true)
		_box(figure, Vector3i(1, 22, 0), Vector3i(width - 2, 22, 0), DARK, "plastic")
		# the soft keys either side of the screen
		for key_y in [16, 18, 20]:
			_box(figure, Vector3i(1, key_y, 0), Vector3i(1, key_y, 0), STEEL, "metal")
			_box(figure, Vector3i(width - 2, key_y, 0), Vector3i(width - 2, key_y, 0), STEEL, "metal")
		# the card reader: a dark block with a slit, its light green
		_box(figure, Vector3i(9, 11, 0), Vector3i(10, 13, 0), ATM_BEZEL, "plastic")
		_box(figure, Vector3i(9, 12, 0), Vector3i(10, 12, 0), DARK, "plastic")
		_box(figure, Vector3i(10, 14, 0), Vector3i(10, 14, 0), Color("#3CE06A"), "glow", true)
		# the keypad: a dark panel, twelve keys and the three function keys standing out of it
		_box(figure, Vector3i(1, 7, face), Vector3i(7, 13, face), ATM_BEZEL, "plastic")
		for key_row in 4:
			for key_column in 3:
				var key := Vector3i(1 + key_column * 2, 7 + key_row * 2, 0)
				_box(figure, key, key, ATM_KEYS, "plastic")
		_box(figure, Vector3i(7, 13, 0), Vector3i(7, 13, 0), Color("#D8352A"), "plastic")
		_box(figure, Vector3i(7, 11, 0), Vector3i(7, 11, 0), Color("#F2C230"), "plastic")
		_box(figure, Vector3i(7, 9, 0), Vector3i(7, 9, 0), Color("#2EA84A"), "plastic")
		# where the money comes out: a steel mouth standing out, its slit sunk into the body
		_box(figure, Vector3i(2, 3, 0), Vector3i(9, 5, 0), STEEL, "metal")
		_recess(figure, Vector3i(3, 4, 0), Vector3i(8, 4, face))
		_box(figure, Vector3i(3, 4, face + 1), Vector3i(8, 4, face + 1), DARK, "plastic")
		# the sign on top
		_box(figure, Vector3i(0, 24, face), Vector3i(width - 1, 27, back), ATM_TRIM, "glow", true)
		_box(figure, Vector3i(2, 25, face), Vector3i(width - 3, 26, face), ATM_BODY, "plastic")
		figure.mark("metal", [STEEL])
		_meshes["geldautomaat"] = _mesh_of(figure, MACHINE_VOXEL)
	return _meshes["geldautomaat"]


## The deposit machine: a white cabinet with a green top (STATIEGELD). Its front (voxel
## z = 1): a little screen sunk in a grey bezel near the top, the green BON key and the slot
## of the bon beside it; under the screen the round hole the cans and bottles go in (a steel
## collar standing out, a dark tunnel HOLE_DEPTH deep into the cabinet); under that the
## larger bay for crates of beer, open and BAY_DEPTH deep, with rollers on its floor.
static func deposit_machine_mesh() -> ArrayMesh:
	if not _meshes.has("statiegeldautomaat"):
		var figure := PlayerModel.VoxelFigure.new()
		var width := 14
		var depth := 10
		# the front is voxel z = 0 (VoxelFigure mirrors z: z = 0 faces +z); the face of the body
		# is z = 1, what stands out of it z = 0
		var face := 1
		var back := depth - 1
		_box(figure, Vector3i(0, 0, 0), Vector3i(width - 1, 1, back), DARK, "metal")
		_box(figure, Vector3i(0, 2, face), Vector3i(width - 1, 25, back), DEPOSIT_BODY, "plastic")
		# the little screen, sunk in its bezel (the glass on z = 2)
		_box(figure, Vector3i(4, 21, face), Vector3i(9, 25, face), DEPOSIT_BEZEL, "plastic")
		_recess(figure, Vector3i(5, 22, face), Vector3i(8, 24, face))
		_box(figure, Vector3i(5, 22, face + 1), Vector3i(8, 24, face + 1), DEPOSIT_SCREEN, "glow", true)
		# the BON key and, under it, the slot the bon comes out of
		_box(figure, Vector3i(11, 23, 0), Vector3i(11, 23, 0), DEPOSIT_TRIM.lightened(0.25), "glow", true)
		_box(figure, Vector3i(10, 20, 0), Vector3i(12, 20, 0), STEEL, "metal")
		_recess(figure, Vector3i(10, 19, face), Vector3i(12, 19, face))
		_box(figure, Vector3i(10, 19, face + 1), Vector3i(12, 19, face + 1), DARK, "plastic")
		# the hole for the cans and bottles: a steel collar standing out (its corners off), a
		# dark tunnel deep in, its inner corners filled so it looks round
		_frame(figure, HOLE_FROM - Vector2i(1, 1), HOLE_TO + Vector2i(1, 1), true)
		_opening(figure, HOLE_FROM, HOLE_TO, HOLE_DEPTH, true)
		# the bay for crates: a steel frame standing out, open and deep, rollers on its floor
		_frame(figure, BAY_FROM - Vector2i(1, 1), BAY_TO + Vector2i(1, 1), false)
		_opening(figure, BAY_FROM, BAY_TO, BAY_DEPTH, false)
		for z in range(1, BAY_DEPTH + 1, 2):
			_box(figure, Vector3i(BAY_FROM.x, BAY_FROM.y - 1, z), Vector3i(BAY_TO.x, BAY_FROM.y - 1, z), STEEL, "metal")
		# the sign on top
		_box(figure, Vector3i(0, 26, face), Vector3i(width - 1, 29, back), DEPOSIT_TRIM, "glow", true)
		_box(figure, Vector3i(2, 27, face), Vector3i(width - 3, 28, face), DEPOSIT_BODY, "plastic")
		# the steel of the collar and the rollers matt (as metal it mirrors the dark and goes black)
		figure.mark("plastic", [STEEL])
		_meshes["statiegeldautomaat"] = _mesh_of(figure, MACHINE_VOXEL)
	return _meshes["statiegeldautomaat"]


## A bottle with deposit, upright: brown glass, a light label, a gold cap.
static func bottle_mesh() -> ArrayMesh:
	if not _meshes.has("fles"):
		var figure := PlayerModel.VoxelFigure.new()
		var glass := Color("#6A3C14")
		_box(figure, Vector3i(0, 0, 0), Vector3i(2, 4, 2), glass, "plastic")
		_box(figure, Vector3i(0, 2, 2), Vector3i(2, 3, 2), Color("#F2E6C8"), "plastic")
		_box(figure, Vector3i(1, 5, 1), Vector3i(1, 7, 1), glass, "plastic")
		_box(figure, Vector3i(1, 8, 1), Vector3i(1, 8, 1), Color("#D8B030"), "metal")
		_meshes["fles"] = _mesh_of(figure, SMALL_VOXEL)
	return _meshes["fles"]


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


## Empties the voxels from `from` to `to` (a screen or slot sunk into the body).
static func _recess(figure: PlayerModel.VoxelFigure, from: Vector3i, to: Vector3i) -> void:
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			for z in range(from.z, to.z + 1):
				figure.clear(x, y, z)


## A steel frame standing out of the face (z = 0) round the opening: the ring of voxels
## from `from` to `to`; `round`: without its four corners.
static func _frame(figure: PlayerModel.VoxelFigure, from: Vector2i, to: Vector2i, round: bool) -> void:
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var edge := x == from.x or x == to.x or y == from.y or y == to.y
			var corner := (x == from.x or x == to.x) and (y == from.y or y == to.y)
			if edge and not (round and corner):
				figure.put(x, y, 0, STEEL)


## An opening into the body from `from` to `to` (x, y), `depth` voxels behind the face (z = 1):
## emptied, its inside walls and its back dark, so it looks deep; `round`: its corners filled
## (dark) so it looks round.
static func _opening(figure: PlayerModel.VoxelFigure, from: Vector2i, to: Vector2i, depth: int, round: bool) -> void:
	for x in range(from.x - 1, to.x + 2):
		for y in range(from.y - 1, to.y + 2):
			var wall := x < from.x or x > to.x or y < from.y or y > to.y
			var corner := (x == from.x or x == to.x) and (y == from.y or y == to.y)
			for z in range(1, depth + 2):
				if wall or (round and corner) or z == depth + 1:
					figure.put(x, y, z, DARK)
				else:
					figure.clear(x, y, z)
	figure.mark("plastic", [DARK])


static func _mesh_of(figure: PlayerModel.VoxelFigure, voxel: float) -> ArrayMesh:
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind)
	var parts: Dictionary = figure.to_parts(voxel, {}, materials, PlayerModel.graded)
	return parts.meshes.body
