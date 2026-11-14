extends Node3D
## The wall a machine stands against and the ground before it in its close-up (a graphics
## layer of scripts/ui/machines/machine_screen.gd; machine_stage_view.gd has this in its
## scene, machine_backdrop_layout.gd says where everything goes): the town's own tiles (the
## wall tile side by side and stacked behind the machine, the ground tiles before it), or,
## when a tile is missing, plain boxes in the colour of the place with the joints of the
## bricks or panels and of the paving laid over them (BACKDROPS). It builds what it is
## handed; which tiles stand where a machine is, is decided elsewhere.
##   const MachineBackdropView = preload("res://scripts/ui/machines/machine_backdrop_view.gd")

const MachineBackdropLayout = preload("res://scripts/ui/machines/machine_backdrop_layout.gd")
const NODE_NAME := "Achtergrond"
const LIBRARY_FOLDER := "res://assets/libraries/"
const DEFAULT_BACKDROP := "straat"
const ROUGHNESS := 0.95
## The wall and the ground of each backdrop without tiles: its colour, the colour of its
## joints, and whether the wall is of bricks (else panels).
const BACKDROPS := {
	"straat": {"wall": Color("#8A4A3A"), "joint": Color("#B8A898"), "ground": Color("#8C8A92"), "ground_joint": Color("#6E6C76"), "brick": true},
	"supermarkt": {"wall": Color("#E8E4DA"), "joint": Color("#C8C2B4"), "ground": Color("#D8D2C4"), "ground_joint": Color("#B8B0A0"), "brick": false},
	"station": {"wall": Color("#C8C4BC"), "joint": Color("#9A968E"), "ground": Color("#6A6A70"), "ground_joint": Color("#56565C"), "brick": false},
}

var _tiled := false


func _init() -> void:
	name = NODE_NAME


## Builds the wall and the ground behind a machine whose front is `front` (m) before its
## middle: of `tiles` ({"wall": [library, item], "ground": [library, item]}) when both are
## there, else the boxes of `backdrop` (BACKDROPS).
func build(backdrop: String, tiles: Dictionary, front: float) -> void:
	var face_z := MachineBackdropLayout.wall_z(front)
	_tiled = _build_tiles(tiles, face_z)
	if not _tiled:
		_build_boxes(BACKDROPS.get(backdrop, BACKDROPS[DEFAULT_BACKDROP]), face_z)


## Whether it is made of the town's tiles (else: the plain boxes).
func is_tiled() -> bool:
	return _tiled


## [mesh, its transform] of a tile ([library, item]: ["binnen", "station/wand"]) from its
## library, or [] when there is no such library or item.
static func library_tile(tile: Array) -> Array:
	if tile.size() < 2:
		return []
	var path := LIBRARY_FOLDER + String(tile[0]) + ".res"
	if not ResourceLoader.exists(path):
		return []
	var library := load(path) as MeshLibrary
	var item := library.find_item_by_name(String(tile[1])) if library else -1
	if item < 0 or library.get_item_mesh(item) == null:
		return []
	return [library.get_item_mesh(item), library.get_item_mesh_transform(item)]


## A plain box `box_size` big at `at` in `colour`.
static func box_of(box_size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = ROUGHNESS
	instance.material_override = material
	instance.position = at
	return instance


## The backdrop of the town's own tiles; false when one is missing (then the boxes).
func _build_tiles(tiles: Dictionary, face_z: float) -> bool:
	var wall := library_tile(tiles.get("wall", []))
	var ground := library_tile(tiles.get("ground", []))
	if wall.is_empty() or ground.is_empty():
		return false
	for spot in MachineBackdropLayout.wall_tile_spots(_box_of_tile(wall), face_z):
		_lay_tile(wall, spot)
	for spot in MachineBackdropLayout.ground_tile_spots(_box_of_tile(ground), face_z):
		_lay_tile(ground, spot)
	return true


static func _box_of_tile(tile: Array) -> AABB:
	return (tile[1] as Transform3D) * (tile[0] as Mesh).get_aabb()


func _lay_tile(tile: Array, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = tile[0]
	var placed: Transform3D = tile[1]
	instance.transform = Transform3D(placed.basis, placed.origin + at)
	add_child(instance)


func _build_boxes(look: Dictionary, face_z: float) -> void:
	add_child(box_of(MachineBackdropLayout.WALL_SIZE, MachineBackdropLayout.wall_at(face_z), look.wall))
	add_child(box_of(MachineBackdropLayout.GROUND_SIZE, MachineBackdropLayout.ground_at(face_z), look.ground))
	for joint: Array in MachineBackdropLayout.wall_joints(bool(look.brick), face_z):
		add_child(box_of(joint[0], joint[1], look.joint))
	for joint: Array in MachineBackdropLayout.ground_joints(face_z):
		add_child(box_of(joint[0], joint[1], look.ground_joint))
