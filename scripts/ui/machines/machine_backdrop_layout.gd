extends RefCounted
## Where the wall and the ground behind a machine are in its close-up (the layout of
## scripts/ui/machines/machine_backdrop_view.gd, which builds them; part of the scene of
## machine_stage_view.gd). Metres, the machine's front at the origin facing +z. Either the
## town's own tiles side by side (wall_tile_spots, ground_tile_spots), or plain boxes with
## the joints of bricks or panels and of the paving laid over them (wall_joints,
## ground_joints). Constants and plain functions, without nodes.
##   const MachineBackdropLayout = preload("res://scripts/ui/machines/machine_backdrop_layout.gd")

## The plain wall and ground: how wide, high and deep.
const WALL_SIZE := Vector3(8.0, 4.0, 0.2)
const GROUND_SIZE := Vector3(8.0, 0.1, 6.0)
## A joint: how thick its line is and how far it lies on the wall or the ground.
const JOINT := 0.012
const JOINT_DEPTH := 0.01
const GROUND_JOINT_HEIGHT := 0.004
## The courses of the wall (m): bricks of two voxels high and four long, or panels.
const BRICK_COURSE := 0.0625 * 2.0
const BRICK_LENGTH := 0.25
const PANEL_COURSE := 0.5
const PANEL_LENGTH := 1.0
## The paving: a line every so far, this many each way.
const PAVING := 0.5
const PAVING_LINES := 13
## The tiles: how many side by side (left to right of the machine), how high the wall goes
## and how many rows of ground come forward.
const TILE_COLUMNS := [-2, -1, 0, 1, 2]
const TILE_WALL_HEIGHT := 4.5
const TILE_GROUND_ROWS := 3


## The face of the wall (z) behind a machine whose front is `front` before its middle.
static func wall_z(front: float) -> float:
	return -front * 2.0 - 0.02


## The middle of the plain wall, its face at `face_z`.
static func wall_at(face_z: float) -> Vector3:
	return Vector3(0.0, WALL_SIZE.y * 0.5, face_z - WALL_SIZE.z * 0.5)


## The middle of the plain ground, its top at y = 0, from the wall at `face_z` forward.
static func ground_at(face_z: float) -> Vector3:
	return Vector3(0.0, -GROUND_SIZE.y * 0.5, face_z + GROUND_SIZE.z * 0.5)


## The joints on the plain wall at `face_z`, as [size, middle] each, in the order they are
## laid: per course its line, then its upright joints (bricks half a brick further every
## other course).
static func wall_joints(brick: bool, face_z: float) -> Array:
	var joints: Array = []
	var course := BRICK_COURSE if brick else PANEL_COURSE
	var step := BRICK_LENGTH if brick else PANEL_LENGTH
	for row in int(WALL_SIZE.y / course):
		var height := row * course
		joints.append([Vector3(WALL_SIZE.x, JOINT, JOINT_DEPTH), Vector3(0.0, height, face_z + JOINT_DEPTH * 0.5)])
		var offset := (step * 0.5 if row % 2 == 1 else 0.0) if brick else 0.0
		var column := -WALL_SIZE.x * 0.5 + offset
		while column < WALL_SIZE.x * 0.5:
			joints.append([Vector3(JOINT, course, JOINT_DEPTH), Vector3(column, height + course * 0.5, face_z + JOINT_DEPTH * 0.5)])
			column += step
	return joints


## The joints of the paving before the wall at `face_z`, as [size, middle] each: per line
## one across and one forward.
static func ground_joints(face_z: float) -> Array:
	var joints: Array = []
	var middle_z := face_z + GROUND_SIZE.z * 0.5
	for line in PAVING_LINES:
		var along := -GROUND_SIZE.z * 0.5 + line * PAVING
		joints.append([Vector3(GROUND_SIZE.x, GROUND_JOINT_HEIGHT, JOINT), Vector3(0.0, GROUND_JOINT_HEIGHT * 0.5, middle_z + along)])
		joints.append([Vector3(JOINT, GROUND_JOINT_HEIGHT, GROUND_SIZE.z), Vector3(along, GROUND_JOINT_HEIGHT * 0.5, middle_z)])
	return joints


## Where the wall tiles go (what to add to each tile's own place): side by side and stacked
## behind the machine, the tile's box being `tile_box`, its face at `face_z`, from y = 0 up.
static func wall_tile_spots(tile_box: AABB, face_z: float) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var rows := ceili(TILE_WALL_HEIGHT / maxf(tile_box.size.y, 0.5))
	for column: int in TILE_COLUMNS:
		for row in rows:
			spots.append(Vector3(column * tile_box.size.x - tile_box.get_center().x, row * tile_box.size.y - tile_box.position.y,
				face_z - tile_box.end.z))
	return spots


## Where the ground tiles go (what to add to each tile's own place): side by side from the
## wall at `face_z` forward, their top at y = 0.
static func ground_tile_spots(tile_box: AABB, face_z: float) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for column: int in TILE_COLUMNS:
		for row in TILE_GROUND_ROWS:
			spots.append(Vector3(column * tile_box.size.x - tile_box.get_center().x, -tile_box.end.y,
				face_z + row * tile_box.size.z - tile_box.position.z))
	return spots
