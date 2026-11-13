extends Node3D
## The people on the terraces of the town (the node "Terrassen" of scenes/stad.tscn): on the
## chairs of the café tables with two chairs (TERRACE_TILES of the Props map: the table in the
## middle, a chair before it and one behind, CHAIR_OFFSET m from it, their seats SEAT_HEIGHT
## up, both facing the table) some sit (OCCUPIED in 100 of the chairs, the same ones every
## game: from the cell), townspeople you can talk to as the people in a snack bar
## (InteriorPerson, the group of who can be talked to).

## The terrace tiles with a chair on either side of the table (props/terras/, terrace_set).
const TERRACE_TILES := ["terras/terras_set", "terras/terras_set_parasol", "terras/terras_set_parasol_groen"]
const CHAIR_OFFSET := 0.81
const SEAT_HEIGHT := 0.5
const OCCUPIED := 35

@export var props_path := NodePath("../Props")

var _guests: Array[InteriorPerson] = []


func _ready() -> void:
	var props := get_node_or_null(props_path) as GridMap
	if props == null or props.mesh_library == null:
		return
	for tile_name in TERRACE_TILES:
		var item := props.mesh_library.find_item_by_name(tile_name)
		if item < 0:
			continue
		for cell in props.get_used_cells_by_item(item):
			_seat_people(props, cell)


func guests() -> Array[InteriorPerson]:
	return _guests


## Who sits at the table in `cell`: each of its two chairs taken or not (from the cell).
func _seat_people(props: GridMap, cell: Vector3i) -> void:
	var table := props.to_global(props.map_to_local(cell))
	var turn := props.get_basis_with_orthogonal_index(props.get_cell_item_orientation(cell))
	var random := RandomNumberGenerator.new()
	random.seed = hash(cell)
	# the chair before the table (+z of the tile) faces back to it (-z), the one behind faces +z
	for side: float in [1.0, -1.0]:
		if random.randi_range(1, 100) > OCCUPIED:
			continue
		var guest := InteriorPerson.create("klant", random.randi(), true, SEAT_HEIGHT)
		guest.name = "Terrasgast"
		add_child(guest)
		var chair := table + turn * Vector3(0.0, 0.0, CHAIR_OFFSET * side)
		guest.global_position = Vector3(chair.x, props.global_position.y, chair.z)
		var facing := turn * Vector3(0.0, 0.0, -side)
		guest.rotation.y = atan2(facing.x, facing.z)
		_guests.append(guest)
