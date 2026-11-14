extends Node3D
## Cans in the waste bins of the town (the node "Prullenbakken" of scenes/stad.tscn;
## behaviour, docs/CODE_LAGEN.md: its rules litter_bins_rules.gd, where bin and can stand
## litter_bins_layout.gd, the can litter_bins_view.gd): the
## bins are props of the Props layer (straat/prullenbak_paal, straat/prullenbak_rond, put
## down by the city builder, tools/build/city/finishing.gd `_bins`); at the start some of
## them, drawn at random (`can_share`, at most `most_cans`), have an empty can sticking out of
## the top (MachineModels.can_mesh, with the glowing outline of things to pick up,
## QuestOutline). At such a bin "[E] Blikje pakken" (a spot in the group of the doors): the
## can in your pockets (Items "blikje", PlayerController.add_item: its own "+ Leeg blikje"
## and chime), worth statiegeld at the machine in every supermarket. Now and then
## (`refill_seconds`) an empty bin gets a new can.

const RandomPick = preload("res://scripts/common/random_pick.gd")
const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
const Interactable = preload("res://scripts/world/things/interactable.gd")
const LitterBinsRules = preload("res://scripts/world/things/litter_bins_rules.gd")
const LitterBinsLayout = preload("res://scripts/world/things/litter_bins_layout.gd")
const LitterBinsView = preload("res://scripts/world/things/litter_bins_view.gd")
const BIN_TILES := LitterBinsRules.BIN_TILES
const CAN_ITEM := LitterBinsRules.CAN_ITEM
const SPOT_REACH := LitterBinsLayout.SPOT_REACH

@export var can_share := 0.3
@export var most_cans := 60
@export var refill_seconds := 150.0
@export var random_seed := 53
@export var player_path := NodePath("../Speler")
@export var props_path := NodePath("../Props")
## The ground layer: a bin on a platform (a tile with PLATFORM_GROUND in its name, behind the
## OV gates) is not freely reachable, so the story never sends you there (fill_near, can_spots).
@export var ground_path := NodePath("../Grond")
const PLATFORM_GROUND := LitterBinsRules.PLATFORM_GROUND   # a railway platform; a tram stop (tram/tram_halte_perron) is free
## The buildings layer: fill_near with `in_sight` only takes bins with no building between them
## and the place (the first mission: on the square before Centraal, never behind it).
@export var buildings_path := NodePath("../Gebouwen")

var _player: Node3D
var _random := RandomNumberGenerator.new()
## Every bin: {"ground": Vector3 (at its foot), "top": Vector3, "spot": Node3D or null}.
var _bins: Array[Dictionary] = []
var _refill_clock := 0.0
## No new cans within `keep_empty_radius` m of `keep_empty_round` (world x, z): the first mission
## keeps the cans by the start to the ones it put there (Story: the fourth is in the station).
var keep_empty_round := Vector2.ZERO
var keep_empty_radius := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_random.seed = random_seed
	var props := get_node_or_null(props_path) as GridMap
	if props and props.mesh_library:
		_find_bins(props)
		_mark_platforms(get_node_or_null(ground_path) as GridMap)
	var order: Array = range(_bins.size())
	RandomPick.shuffle(_random, order)
	var wanted := LitterBinsRules.cans_at_start(_bins.size(), can_share, most_cans)
	for index in wanted:
		_put_can(int(order[index]))


func _process(delta: float) -> void:
	_refill_clock += delta
	if not LitterBinsRules.refill_due(_refill_clock, refill_seconds) or _bins.is_empty():
		return
	_refill_clock = 0.0
	if cans_left() >= most_cans:
		return
	var empty := LitterBinsRules.refillable(_bins, keep_empty_round, keep_empty_radius)
	if not empty.is_empty():
		_put_can(int(empty[_random.randi() % empty.size()]))


func _find_bins(props: GridMap) -> void:
	var library := props.mesh_library
	for tile_name: String in BIN_TILES:
		var item := library.find_item_by_name(tile_name)
		if item < 0:
			continue
		var box := library.get_item_mesh(item).get_aabb() if library.get_item_mesh(item) else AABB()
		for cell in props.get_used_cells_by_item(item):
			var basis := props.get_cell_item_basis(cell)
			var origin := props.map_to_local(cell)
			var foot := props.global_transform * LitterBinsLayout.foot(box, basis, origin)
			var top := props.global_transform * LitterBinsLayout.top(box, basis, origin)
			_bins.append({"ground": foot, "top": top, "spot": null, "free": true})


## Bins on a platform (PLATFORM_GROUND) are not "free": behind the gates.
func _mark_platforms(ground: GridMap) -> void:
	if ground == null or ground.mesh_library == null:
		return
	for bin: Dictionary in _bins:
		var at: Vector3 = bin.ground
		var cell := ground.local_to_map(ground.to_local(at))
		for level in range(LitterBinsRules.PLATFORM_LEVELS.x, LitterBinsRules.PLATFORM_LEVELS.y):
			var item := ground.get_cell_item(Vector3i(cell.x, level, cell.z))
			if item != -1 and LitterBinsRules.is_platform(ground.mesh_library.get_item_name(item)):
				bin.free = false
				break


## A can in bin `index`: sticking out of the top, a spot with "[E] Blikje pakken" at its foot.
func _put_can(index: int) -> void:
	var bin: Dictionary = _bins[index]
	if bin.spot != null:
		return
	var spot: Node3D = InteriorSpot.create(LitterBinsRules.spot_name(index), Vector3.ZERO, LitterBinsRules.TAKE_TEXT, _take.bind(index), SPOT_REACH)
	spot.set("kind", Interactable.KIND_PICKUP)
	add_child(spot)
	spot.global_position = bin.ground
	LitterBinsView.add_can(spot, bin.top, _random.randf() * TAU)
	bin.spot = spot


func _take(index: int) -> void:
	var bin: Dictionary = _bins[index]
	if bin.spot == null or _player == null:
		return
	# the bin empty before the can goes in the pockets: add_item signals inventory_changed,
	# on which the story points to the bins with a can again (this one no longer among them)
	var spot: Node3D = bin.spot
	bin.spot = null
	if not bool(_player.call("add_item", CAN_ITEM)):
		bin.spot = spot
		return
	spot.queue_free()


## How many bins have a can in them now (for the checks).
func cans_left() -> int:
	return LitterBinsRules.cans_in(_bins)


func bin_count() -> int:
	return _bins.size()


## The spot of a bin with a can (for the checks), or null.
func a_can_spot() -> Node3D:
	for bin: Dictionary in _bins:
		if bin.spot != null:
			return bin.spot
	return null


## The bins with a can in them nearest to `near` (world x, z), `count` of them (world x, z;
## the story points to them: Story "plekken" "blikjes").
func can_spots(near: Vector2, count := 3) -> Array:
	return LitterBinsRules.can_spots(_bins, near, count)


## Makes sure the `count` freely reachable bins nearest to `near` (world x, z) have a can
## (the first mission needs some by the start), and when `alone_within` > 0 takes the cans
## out of every other bin within that many metres (so these are the only ones there);
## returns the farthest of them from `near` in metres. `in_sight`: only bins with no building
## between them and `near` (in_sight_of: on the square, not behind the station on it).
func fill_near(near: Vector2, count: int, alone_within := 0.0, in_sight := false) -> float:
	var seen := Callable()
	if in_sight:
		var buildings := get_node_or_null(buildings_path) as GridMap
		seen = func(place: Vector2) -> bool: return in_sight_of(buildings, near, place)
	var chosen: Array = LitterBinsRules.nearest_free(_bins, near, seen).slice(0, count)
	for index: int in chosen:
		if _bins[index].spot == null:
			_put_can(index)
	if alone_within > 0.0:
		for index: int in LitterBinsRules.others_with_a_can(_bins, chosen, near, alone_within):
			(_bins[index].spot as Node3D).queue_free()
			_bins[index].spot = null
	return LitterBinsRules.farthest(_bins, chosen, near)


## Whether no building of `buildings` (its ground storey) stands on the straight line from
## `from` to `to` (world x, z), looked at every metre; true without a buildings layer.
static func in_sight_of(buildings: GridMap, from: Vector2, to: Vector2) -> bool:
	if buildings == null:
		return true
	for at: Vector2 in LitterBinsRules.sight_points(from, to):
		var cell := buildings.local_to_map(buildings.to_local(Vector3(at.x, 0.5, at.y)))
		if buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM:
			return false
	return true
