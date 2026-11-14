extends RefCounted
## The sizes and the openings of the machine models (layout; docs/CODE_LAGEN.md): how big a
## voxel is, how wide and deep the cash machine and the deposit machine are, where the
## deposit machine's hole and bay sit, and which voxels a frame, an opening or the keys of
## the keypad take. Pure arithmetic; machine_models.gd paints them.
##   const MachineModelsLayout = preload("res://scripts/world/things/machine_models_layout.gd")

## Metres per voxel of the machines and of the small things.
const MACHINE_VOXEL := 0.0625
const SMALL_VOXEL := 0.05
## The cash machine and the deposit machine: voxels wide (x) and deep (y).
const CASH_SIZE := Vector2i(12, 8)
const DEPOSIT_SIZE := Vector2i(14, 10)
## The face of the body of a machine is voxel z = FACE; what stands out of it is z = 0.
const FACE := 1
## The deposit machine's hole for cans and bottles and its bay for crates (voxels x, y of
## the openings, the corners included) and how deep they go behind its face.
const HOLE_FROM := Vector2i(5, 13)
const HOLE_TO := Vector2i(8, 17)
const HOLE_DEPTH := 5
const BAY_FROM := Vector2i(2, 3)
const BAY_TO := Vector2i(11, 9)
const BAY_DEPTH := 7
## The keypad of the cash machine: rows and columns of keys, every other voxel from KEYPAD_FROM.
const KEYPAD_FROM := Vector2i(1, 7)
const KEY_ROWS := 4
const KEY_COLUMNS := 3
## The heights (voxels) of the soft keys either side of the cash machine's screen.
const SOFT_KEY_LEVELS := [16, 18, 20]


## The twelve keys of the keypad (standing out of the face: z = 0), row by row from below.
static func keypad_keys() -> Array[Vector3i]:
	var keys: Array[Vector3i] = []
	for key_row in KEY_ROWS:
		for key_column in KEY_COLUMNS:
			keys.append(Vector3i(KEYPAD_FROM.x + key_column * 2, KEYPAD_FROM.y + key_row * 2, 0))
	return keys


## The ring of voxels (x, y) from `from` to `to`: a frame round an opening; `round`: without
## its four corners.
static func frame_cells(from: Vector2i, to: Vector2i, round: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			var edge := x == from.x or x == to.x or y == from.y or y == to.y
			var corner := (x == from.x or x == to.x) and (y == from.y or y == to.y)
			if edge and not (round and corner):
				cells.append(Vector2i(x, y))
	return cells


## The voxels of an opening into the body from `from` to `to` (x, y), `depth` voxels behind
## the face: each {"cell": Vector3i, "wall": bool}. A wall is filled (the sides, the back
## and, when `round`, the inner corners); the others are emptied.
static func opening_cells(from: Vector2i, to: Vector2i, depth: int, round: bool) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for x in range(from.x - 1, to.x + 2):
		for y in range(from.y - 1, to.y + 2):
			var side := x < from.x or x > to.x or y < from.y or y > to.y
			var corner := (x == from.x or x == to.x) and (y == from.y or y == to.y)
			for z in range(FACE, depth + 2):
				cells.append({"cell": Vector3i(x, y, z), "wall": side or (round and corner) or z == depth + 1})
	return cells


## The depths (z) of the rollers on the floor of the crate bay: every other voxel.
static func roller_depths() -> Array[int]:
	var depths: Array[int] = []
	for z in range(FACE, BAY_DEPTH + 1, 2):
		depths.append(z)
	return depths


## The size (metres) of an opening from `from` to `to` (voxels, the corners included).
static func opening_size(from: Vector2i, to: Vector2i) -> Vector2:
	return Vector2(to - from + Vector2i.ONE) * MACHINE_VOXEL
