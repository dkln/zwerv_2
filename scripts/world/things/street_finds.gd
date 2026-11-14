extends Node3D
## Things to find on the streets (behaviour; docs/CODE_LAGEN.md), shared by the loose change (loose_change.gd) and the lost
## bank cards (lost_bank_cards.gd): nothing until the story unlocks them (`_unlock_name`),
## then `count` finds on squares and pavements round where the player starts (between
## `near` and `reach` m; `near_count` of them within `near`), each lying on the ground
## itself (a ray down: not on a bench or a roof). Walking over one (within
## `pick_up_distance`) takes it. Which cells get one: street_finds_rules.gd.
## A kind of find gives its own look and what taking it does:
##   _unlock_name()        what the story unlocks before any lies on the streets
##   _closest()            how far from the start the nearest may lie (m)
##   _apart()              how far the far ones lie apart (m; 0: anywhere)
##   _scatter()            how far off the middle of its cell a find lies (m)
##   _make_find(at)        the node of a find on the ground at `at` (added as a child here)
##   _turn_find(find)      its movement each frame (_clock: the seconds so far)
##   _take(find) -> bool   the player walks over it; false: it stays (tried again later)

const StreetFindsRules = preload("res://scripts/world/things/street_finds_rules.gd")
const RandomPick = preload("res://scripts/common/random_pick.gd")
## Ground tile folders finds lie on (the rules').
const FIND_GROUND := StreetFindsRules.FIND_GROUND
const TOWN_LAYER := 1
## How long a find that could not be taken (full pockets) is left alone (the rules').
const RETRY_SECONDS := StreetFindsRules.RETRY_SECONDS

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

var _finds: Array[Node3D] = []
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
		if _player.get("_placed") and _unlocked():
			_lay(_player.global_position)
		return
	if not StreetFindsRules.may_take(_player.call("is_asleep"), _player.call("is_dead"), _clock, _refused_until):
		return
	_take_what_is_walked_over(_player.global_position)


func _process(delta: float) -> void:
	_clock += delta
	for find in _finds:
		_turn_find(find)


## Finds left on the streets.
func finds_left() -> int:
	return _finds.size()


## The player takes find `index`; false (and it stays, left alone for RETRY_SECONDS) when
## that cannot be (_take).
func pick_up(index: int) -> bool:
	var find := _finds[index]
	if not _take(find):
		_refused_until = StreetFindsRules.refused_until(_clock)
		return false
	_finds.remove_at(index)
	find.queue_free()
	return true


# ------------------------------------------------------------------ a kind of find

func _unlock_name() -> String:
	return ""


func _closest() -> float:
	return StreetFindsRules.CLOSEST


func _apart() -> float:
	return StreetFindsRules.APART


func _scatter() -> float:
	return StreetFindsRules.SCATTER


func _make_find(_at: Vector3) -> Node3D:
	return null


func _turn_find(_find: Node3D) -> void:
	pass


func _take(_find: Node3D) -> bool:
	return true


# ------------------------------------------------------------------ laying them out

## Puts the finds on open ground round `start`: candidate cells first (StreetFindsRules.choose),
## then a ray down for the height.
func _lay(start: Vector3) -> void:
	_laid = true
	var rings := _candidate_cells(Vector2(start.x, start.z))
	RandomPick.shuffle(_random, rings.near)
	RandomPick.shuffle(_random, rings.far)
	var chosen := StreetFindsRules.choose(rings.near, rings.far, near_count, count, _apart(), _ground.map_to_local)
	for cell in chosen:
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var spot := middle + Vector3(_random.randf_range(-_scatter(), _scatter()), 0.0, _random.randf_range(-_scatter(), _scatter()))
		var ground_at: Variant = _ground_below(spot)
		if ground_at == null:
			continue
		var find := _make_find(ground_at)
		if find:
			_finds.append(find)


## The open cells of find ground round `start`, by their ring: {"near": [...], "far": [...]}.
func _candidate_cells(start: Vector2) -> Dictionary:
	var rings := {"near": [], "far": []}
	for cell in _ground.get_used_cells():
		if cell.y != 0:
			continue
		var middle := _ground.to_global(_ground.map_to_local(cell))
		var ring := StreetFindsRules.ring(Vector2(middle.x, middle.z).distance_to(start), _closest(), near, reach)
		if ring == "" or _built_over(cell):
			continue
		if StreetFindsRules.is_find_ground(_ground.mesh_library.get_item_name(_ground.get_cell_item(cell)), FIND_GROUND):
			(rings[ring] as Array).append(cell)
	return rings


func _built_over(cell: Vector3i) -> bool:
	return _buildings != null and StreetFindsRules.built_over(_buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)),
			_buildings.get_cell_item(Vector3i(cell.x, 1, cell.z)), GridMap.INVALID_CELL_ITEM)


## The point of the ground itself below `spot` (a Vector3), or null when something else
## lies there (a bench, a roof) or nothing.
func _ground_below(spot: Vector3) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 2.0, TOWN_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != _ground:
		return null
	return hit.position


func _take_what_is_walked_over(feet: Vector3) -> void:
	for index in range(_finds.size() - 1, -1, -1):
		if StreetFindsRules.walked_over(feet, _finds[index].global_position, pick_up_distance) and not pick_up(index):
			return


## Whether the story lets these finds lie on the streets (Story.UNLOCKABLE: not at the start
## of the game; a later mission unlocks it); without a story always.
func _unlocked() -> bool:
	var story := get_tree().get_first_node_in_group("verhaal")
	return story == null or not story.has_method("is_unlocked") or bool(story.is_unlocked(_unlock_name()))
