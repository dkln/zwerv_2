extends Node3D
## Rucksacks lying about in the town (the node "Rugzakken" of scenes/stad.tscn): nobody starts
## with one, and a zwerver's pockets hold only a few kinds of thing (Items.BASE_SLOTS). One
## lies close to where the player starts (within `near`), the others further off (within
## `reach`), on squares and pavements. Each is the same plain canvas rucksack the figure
## wears (PlayerModel.BACKPACK_CANVAS, its flap darker), standing up and slowly turning so it
## catches the eye, with a pulsing rim round it (QuestOutline). Walking over one (within `pick_up_distance`) puts it on
## (PlayerController.pick_up_backpack: Items.BACKPACK_SLOTS more room, worn on the back), with
## a chime and "Rugzak! +8 vakjes" rising from it; one who wears a rucksack already leaves the
## others lying. Like the coins it has no collider: it is walked over, not bumped into.

const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const Items = preload("res://scripts/player/items.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
## Ground tile folders a rucksack lies on.
const BACKPACK_GROUND := ["plein/", "stoep/"]
const TOWN_LAYER := 1
## The rucksack lying there: its size in voxels (across, up, deep), as worn.
const SIZE := Vector3i(6, 9, 3)
const TURN_SPEED := 0.8
const PICK_UP_COLOUR := Color("#C8D07A")

@export var count := 3
@export var reach := 160.0
@export var near := 30.0
@export var pick_up_distance := 1.1
@export var random_seed := 31
@export var player_path := NodePath("../Speler")
@export var ground_path := NodePath("../Grond")
@export var buildings_path := NodePath("../Gebouwen")

var _backpacks: Array[Node3D] = []
var _laid := false
var _player: Node3D
var _ground: GridMap
var _buildings: GridMap
var _random := RandomNumberGenerator.new()
var _clock := 0.0
static var _mesh: ArrayMesh


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_ground = get_node_or_null(ground_path) as GridMap
	_buildings = get_node_or_null(buildings_path) as GridMap
	_random.seed = random_seed


func _physics_process(_delta: float) -> void:
	if _player == null or _ground == null:
		return
	if not _laid:
		if _player.get("_placed"):
			_lay_backpacks(_player.global_position)
		return
	if _player.get("has_backpack") == true or _player.call("is_asleep") or _player.call("is_dead"):
		return
	var feet := _player.global_position
	for index in range(_backpacks.size() - 1, -1, -1):
		var at := _backpacks[index].global_position
		if absf(at.y - feet.y) < 1.6 and Vector2(at.x - feet.x, at.z - feet.z).length() < pick_up_distance:
			_pick_up(index)
			return


func _process(delta: float) -> void:
	_clock += delta
	for backpack: Node3D in _backpacks:
		backpack.rotation.y = _clock * TURN_SPEED + backpack.get_meta("phase", 0.0)


## Puts the rucksacks on open ground: the first within `near` of `start`, the rest further
## off; a ray down for the height (it has to hit the ground layer, not a bench or a roof).
func _lay_backpacks(start: Vector3) -> void:
	_laid = true
	var near_cells: Array[Vector3i] = []
	var far_cells: Array[Vector3i] = []
	var start_flat := Vector2(start.x, start.z)
	for cell in _ground.get_used_cells():
		if cell.y != 0:
			continue
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var distance := Vector2(middle.x, middle.z).distance_to(start_flat)
		if distance > reach or distance < 8.0:
			continue
		var item_name := _ground.mesh_library.get_item_name(_ground.get_cell_item(cell))
		if not BACKPACK_GROUND.any(func(folder: String) -> bool: return item_name.begins_with(folder)):
			continue
		if _buildings and (_buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM
				or _buildings.get_cell_item(Vector3i(cell.x, 1, cell.z)) != GridMap.INVALID_CELL_ITEM):
			continue
		(near_cells if distance <= near else far_cells).append(cell)
	_shuffle(near_cells)
	_shuffle(far_cells)
	# spread the far ones: each at least a quarter of `reach` from the others
	var chosen: Array[Vector3i] = []
	chosen.append_array(near_cells.slice(0, 1))
	for cell in far_cells:
		if chosen.size() >= count:
			break
		var middle := _ground.map_to_local(cell)
		var spread := chosen.all(func(other: Vector3i) -> bool:
			return Vector2(middle.x, middle.z).distance_to(Vector2(_ground.map_to_local(other).x, _ground.map_to_local(other).z)) > reach * 0.25)
		if spread:
			chosen.append(cell)
	var space := get_world_3d().direct_space_state
	for cell in chosen:
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var spot := middle + Vector3(_random.randf_range(-1.0, 1.0), 0.0, _random.randf_range(-1.0, 1.0))
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 2.0, TOWN_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider != _ground:
			continue
		_add_backpack(hit.position as Vector3)


func _add_backpack(at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Rugzak"
	holder.set_meta("phase", _random.randf() * TAU)
	add_child(holder)
	holder.global_position = at
	var shape := MeshInstance3D.new()
	shape.mesh = backpack_mesh()
	holder.add_child(shape)
	QuestOutline.add(shape, 0.035)
	_backpacks.append(holder)


func _pick_up(index: int) -> void:
	if not bool(_player.call("pick_up_backpack")):
		return
	var backpack := _backpacks[index]
	_backpacks.remove_at(index)
	UiSounds.play(self, "doe", -2.0)
	var hud: Node = _player.get("_hud")
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(backpack.global_position + Vector3.UP * 0.8, "Rugzak! +%d vakjes" % Items.BACKPACK_SLOTS, PICK_UP_COLOUR, 14)
	backpack.queue_free()


func _shuffle(cells: Array[Vector3i]) -> void:
	for index in range(cells.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var kept := cells[index]
		cells[index] = cells[other]
		cells[other] = kept


## Rucksacks still lying in the town (for the tests).
func backpacks_left() -> int:
	return _backpacks.size()


## The rucksack lying on the ground: the one the figure wears, at the size it is worn in the
## town (PlayerModel.VOXEL at PlayerController.FIGURE_SCALE), standing on y = 0, centred.
static func backpack_mesh() -> ArrayMesh:
	if _mesh == null:
		var figure := PlayerModel.VoxelFigure.new()
		figure.box(Vector3i.ZERO, SIZE - Vector3i.ONE, PlayerModel.BACKPACK_CANVAS)
		figure.box(Vector3i(0, SIZE.y - 2, 0), SIZE - Vector3i.ONE, PlayerModel.BACKPACK_FLAP)
		figure.mark("cloth", [PlayerModel.BACKPACK_CANVAS, PlayerModel.BACKPACK_FLAP])
		var materials := {}
		for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
			materials[kind] = PlayerModel.material_for(kind)
		var parts: Dictionary = figure.to_parts(PlayerModel.VOXEL * PlayerController.FIGURE_SCALE, {}, materials, PlayerModel.graded)
		_mesh = parts.meshes.body
	return _mesh
