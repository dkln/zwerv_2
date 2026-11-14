extends Node3D
## The people on the terraces of the town (the node "Terrassen" of scenes/stad.tscn): on the
## chairs of the café tables with two chairs (TERRACE_TILES of the Props map: the table in the
## middle, a chair before it and one behind, CHAIR_OFFSET m from it, their seats SEAT_HEIGHT
## up, both facing the table) some sit (OCCUPIED in 100 of the chairs, the same ones every
## game: from the cell), townspeople you can talk to as the people in a snack bar
## (InteriorPerson, the group of who can be talked to).
## Behaviour (docs/CODE_LAGEN.md); where the chairs stand: terraces_layout.gd; which are
## taken: terraces_rules.gd.

const TerracesLayout = preload("res://scripts/world/people/terraces_layout.gd")
const TerracesRules = preload("res://scripts/world/people/terraces_rules.gd")
const TERRACE_TILES := TerracesLayout.TERRACE_TILES
const CHAIR_OFFSET := TerracesLayout.CHAIR_OFFSET
const SEAT_HEIGHT := TerracesLayout.SEAT_HEIGHT
const OCCUPIED := TerracesRules.OCCUPIED

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
	for side: float in TerracesLayout.SIDES:
		if not TerracesRules.is_taken(random.randi_range(1, TerracesRules.ROLL_MOST)):
			continue
		var guest := InteriorPerson.create(TerracesRules.GUEST_KIND, random.randi(), true, SEAT_HEIGHT)
		guest.name = "Terrasgast"
		add_child(guest)
		guest.global_position = TerracesLayout.chair_spot(table, turn, side, props.global_position.y)
		guest.rotation.y = TerracesLayout.facing_of(turn, side)
		_guests.append(guest)
