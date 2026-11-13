extends Node3D
## Lost bank cards on the streets (the node "Pinpassen" of scenes/stad.tscn): a few cards
## lying on squares and pavements, one not far from where the player starts (within `near`),
## the others spread further off (within `reach`, a third of it apart). A card stands up and
## slowly turns, with the glowing outline of things to pick up (QuestOutline). Walking over
## one (within `pick_up_distance`) puts it in your pockets as a "pinpas" with its own account:
## a modest balance, a PIN and the riddle of it on the back (BankCards.give_found_bank_card,
## the inventory shows the riddle). Full pockets: it stays lying.

const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const CARD_GROUND := ["plein/", "stoep/"]
const TOWN_LAYER := 1
const TURN_SPEED := 1.1
const LIFT := 0.12
const OUTLINE_COLOUR := Color("#7AD8FF")

@export var count := 5
@export var reach := 260.0
@export var near := 60.0
@export var pick_up_distance := 1.0
@export var random_seed := 97
@export var player_path := NodePath("../Speler")
@export var ground_path := NodePath("../Grond")
@export var buildings_path := NodePath("../Gebouwen")

var _cards: Array[Node3D] = []
var _laid := false
var _player: Node3D
var _ground: GridMap
var _buildings: GridMap
var _random := RandomNumberGenerator.new()
var _clock := 0.0
var _refused_until := 0.0


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
			_lay_cards(_player.global_position)
		return
	if _player.call("is_asleep") or _player.call("is_dead") or _clock < _refused_until:
		return
	var feet := _player.global_position
	for index in range(_cards.size() - 1, -1, -1):
		var at := _cards[index].global_position
		if absf(at.y - feet.y) < 1.6 and Vector2(at.x - feet.x, at.z - feet.z).length() < pick_up_distance:
			pick_up(index)
			return


func _process(delta: float) -> void:
	_clock += delta
	for card: Node3D in _cards:
		card.rotation.y = _clock * TURN_SPEED + float(card.get_meta("phase", 0.0))


func _lay_cards(start: Vector3) -> void:
	_laid = true
	var near_cells: Array[Vector3i] = []
	var far_cells: Array[Vector3i] = []
	var start_flat := Vector2(start.x, start.z)
	for cell in _ground.get_used_cells():
		if cell.y != 0:
			continue
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var distance := Vector2(middle.x, middle.z).distance_to(start_flat)
		if distance > reach or distance < 12.0:
			continue
		var item_name := _ground.mesh_library.get_item_name(_ground.get_cell_item(cell))
		if not CARD_GROUND.any(func(folder: String) -> bool: return item_name.begins_with(folder)):
			continue
		if _buildings and (_buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM
				or _buildings.get_cell_item(Vector3i(cell.x, 1, cell.z)) != GridMap.INVALID_CELL_ITEM):
			continue
		(near_cells if distance <= near else far_cells).append(cell)
	_shuffle(near_cells)
	_shuffle(far_cells)
	var chosen: Array[Vector3i] = []
	chosen.append_array(near_cells.slice(0, 1))
	for cell in far_cells:
		if chosen.size() >= count:
			break
		var middle := _ground.map_to_local(cell)
		if chosen.all(func(other: Vector3i) -> bool:
				var other_middle := _ground.map_to_local(other)
				return Vector2(middle.x, middle.z).distance_to(Vector2(other_middle.x, other_middle.z)) > reach / 3.0):
			chosen.append(cell)
	var space := get_world_3d().direct_space_state
	for cell in chosen:
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var spot := middle + Vector3(_random.randf_range(-1.2, 1.2), 0.0, _random.randf_range(-1.2, 1.2))
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 2.0, TOWN_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider != _ground:
			continue
		_add_card(hit.position as Vector3)


func _add_card(at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Pinpas"
	holder.set_meta("phase", _random.randf() * TAU)
	holder.set_meta("seed", _random.randi())
	add_child(holder)
	holder.global_position = at + Vector3.UP * LIFT
	var shape := MeshInstance3D.new()
	shape.mesh = MachineModels.bank_card_mesh()
	holder.add_child(shape)
	QuestOutline.add(shape, 0.025, OUTLINE_COLOUR)
	_cards.append(holder)


## Picks up card `index`: a new bank card in the pockets (its own account from the card's
## seed); full pockets: it stays (and is not tried again for a few seconds).
func pick_up(index: int) -> bool:
	var card := _cards[index]
	var random := RandomNumberGenerator.new()
	random.seed = int(card.get_meta("seed", 0))
	if not BankCards.give_found_bank_card(_player, random):
		_refused_until = _clock + 3.0
		return false
	_cards.remove_at(index)
	card.queue_free()
	return true


func cards_left() -> int:
	return _cards.size()


func _shuffle(cells: Array[Vector3i]) -> void:
	for index in range(cells.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var kept := cells[index]
		cells[index] = cells[other]
		cells[other] = kept
