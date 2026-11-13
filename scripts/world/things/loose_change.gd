extends Node3D
## Loose change on the streets (the node "Kleingeld" of scenes/stad.tscn): none until the story
## unlocks it ("kleingeld", a later mission), then a very rare find, only a
## coin (`count`: one) of 10, 20 or 50 cents (now and then a euro) in the whole town, on squares and
## pavements well away from where the player starts (between `near` and `reach` metres;
## `near_count` of them closer by, none by default: the first mission pays for its kroket
## with cans, not coins).
## A coin stands on its edge, turns and bobs a little, glinting gold; walking over it (within
## `pick_up_distance`) picks it up: PlayerController.add_money, a chime ("munt") and its
## value rising from where it lay ("+€ 0,50", GameHud.show_floating_number). A pulsing rim
## (QuestOutline) makes them stand out from the street.

const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
## Ground tile folders coins lie on.
const COIN_GROUND := ["plein/", "stoep/"]
## Values (euros) and how often each comes.
const VALUES := [0.1, 0.2, 0.5, 1.0]
const VALUE_WEIGHTS := [3.0, 3.0, 3.0, 1.0]
const COIN_GOLD := Color("#E8B83A")
const TOWN_LAYER := 1
## What the story unlocks before any coin lies on the streets (_unlocked).
const UNLOCK := "kleingeld"

@export var count := 1
@export var reach := 400.0
## How many of them lie within `near` metres of the start.
@export var near_count := 0
@export var near := 60.0
@export var pick_up_distance := 1.0
@export var random_seed := 7
@export var player_path := NodePath("../Speler")
@export var ground_path := NodePath("../Grond")
@export var buildings_path := NodePath("../Gebouwen")

var _coins: Array[Dictionary] = []   # {"node": Node3D, "value": float, "base": float, "phase": float}
var _laid := false
var _player: Node3D
var _ground: GridMap
var _buildings: GridMap
var _random := RandomNumberGenerator.new()
var _clock := 0.0
static var _coin_mesh: CylinderMesh


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_ground = get_node_or_null(ground_path) as GridMap
	_buildings = get_node_or_null(buildings_path) as GridMap
	_random.seed = random_seed


func _physics_process(_delta: float) -> void:
	if _player == null or _ground == null:
		return
	if not _laid:
		if _player.get("_placed") and _unlocked():
			_lay_coins(_player.global_position)
		return
	if _player.call("is_asleep") or _player.call("is_dead"):
		return
	var feet := _player.global_position
	for index in range(_coins.size() - 1, -1, -1):
		var coin: Dictionary = _coins[index]
		var at: Vector3 = (coin.node as Node3D).global_position
		if absf(at.y - feet.y) < 1.6 and Vector2(at.x - feet.x, at.z - feet.z).length() < pick_up_distance:
			_pick_up(index)


func _process(delta: float) -> void:
	_clock += delta
	for coin: Dictionary in _coins:
		var node: Node3D = coin.node
		node.rotation.y = _clock * 2.4 + coin.phase
		node.position.y = coin.base + sin(_clock * 2.0 + coin.phase) * 0.05


## Puts the coins on open ground round `start`: candidate cells first, then a ray down for
## the height (it has to hit the ground layer, not a bench or a roof).
func _lay_coins(start: Vector3) -> void:
	_laid = true
	var near_cells: Array[Vector3i] = []
	var far_cells: Array[Vector3i] = []
	var start_flat := Vector2(start.x, start.z)
	for cell in _ground.get_used_cells():
		if cell.y != 0:
			continue
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var distance := Vector2(middle.x, middle.z).distance_to(start_flat)
		if distance > reach or distance < 3.0:
			continue
		var item_name := _ground.mesh_library.get_item_name(_ground.get_cell_item(cell))
		if not COIN_GROUND.any(func(folder: String) -> bool: return item_name.begins_with(folder)):
			continue
		if _buildings and (_buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM
				or _buildings.get_cell_item(Vector3i(cell.x, 1, cell.z)) != GridMap.INVALID_CELL_ITEM):
			continue
		(near_cells if distance <= near else far_cells).append(cell)
	_shuffle(near_cells)
	_shuffle(far_cells)
	var chosen: Array[Vector3i] = []
	chosen.append_array(near_cells.slice(0, near_count))
	chosen.append_array(far_cells.slice(0, count - chosen.size()))
	var space := get_world_3d().direct_space_state
	for cell in chosen:
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var spot := middle + Vector3(_random.randf_range(-1.4, 1.4), 0.0, _random.randf_range(-1.4, 1.4))
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 2.0, TOWN_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider != _ground:
			continue
		_add_coin((hit.position as Vector3) + Vector3.UP * 0.32, _random_value())


func _add_coin(at: Vector3, value: float) -> void:
	var holder := Node3D.new()
	holder.name = "Munt"
	add_child(holder)
	holder.global_position = at
	var coin := MeshInstance3D.new()
	coin.mesh = _mesh()
	coin.rotation_degrees.x = 90.0   # on its edge
	coin.scale = Vector3.ONE * (1.25 if value >= 1.0 else 1.0)
	holder.add_child(coin)
	QuestOutline.add(coin, 0.03)
	_coins.append({"node": holder, "value": value, "base": holder.position.y, "phase": _random.randf() * TAU})


func _pick_up(index: int) -> void:
	var coin: Dictionary = _coins[index]
	_coins.remove_at(index)
	var node: Node3D = coin.node
	_player.call("add_money", coin.value)
	UiSounds.play(self, "munt", -2.0)
	var hud: Node = _player.get("_hud")
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(node.global_position + Vector3.UP * 0.6, "+" + _euros(coin.value), COIN_GOLD)
	node.queue_free()


func _random_value() -> float:
	var total := 0.0
	for weight: float in VALUE_WEIGHTS:
		total += weight
	var pick := _random.randf() * total
	for index in VALUES.size():
		pick -= VALUE_WEIGHTS[index]
		if pick <= 0.0:
			return VALUES[index]
	return VALUES[0]


func _shuffle(cells: Array[Vector3i]) -> void:
	for index in range(cells.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var kept := cells[index]
		cells[index] = cells[other]
		cells[other] = kept


## Coins left on the streets (for the tests).
func coins_left() -> int:
	return _coins.size()


static func _mesh() -> CylinderMesh:
	if _coin_mesh == null:
		_coin_mesh = CylinderMesh.new()
		_coin_mesh.top_radius = 0.16
		_coin_mesh.bottom_radius = 0.16
		_coin_mesh.height = 0.045
		_coin_mesh.radial_segments = 10
		_coin_mesh.rings = 1
		var material := StandardMaterial3D.new()
		material.albedo_color = COIN_GOLD
		material.metallic = 0.8
		material.roughness = 0.35
		material.emission_enabled = true
		material.emission = COIN_GOLD
		material.emission_energy_multiplier = 0.35
		_coin_mesh.material = material
	return _coin_mesh


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")


## Whether the story lets coins lie on the streets ("kleingeld", Story.UNLOCKABLE: not at the
## start of the game; a later mission unlocks it); without a story always.
func _unlocked() -> bool:
	var story := get_tree().get_first_node_in_group("verhaal")
	return story == null or not story.has_method("is_unlocked") or bool(story.is_unlocked(UNLOCK))
