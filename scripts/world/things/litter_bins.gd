extends Node3D
## Cans in the waste bins of the town (the node "Prullenbakken" of scenes/stad.tscn): the
## bins are props of the Props layer (straat/prullenbak_paal, straat/prullenbak_rond, put
## down by the city builder, tools/build/city/finishing.gd `_bins`); at the start some of
## them, drawn at random (`can_share`, at most `most_cans`), have an empty can sticking out of
## the top (MachineModels.can_mesh, with the glowing outline of things to pick up,
## QuestOutline). At such a bin "[E] Blikje pakken" (a spot in the group of the doors): the
## can in your pockets (Items "blikje", PlayerController.add_item: its own "+ Leeg blikje"
## and chime), worth statiegeld at the machine in every supermarket. Now and then
## (`refill_seconds`) an empty bin gets a new can.

const RandomPick = preload("res://scripts/common/random_pick.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
const BIN_TILES := ["straat/prullenbak_paal", "straat/prullenbak_rond"]
const CAN_ITEM := "blikje"
const SPOT_REACH := 1.3

@export var can_share := 0.3
@export var most_cans := 60
@export var refill_seconds := 150.0
@export var random_seed := 53
@export var player_path := NodePath("../Speler")
@export var props_path := NodePath("../Props")
## The ground layer: a bin on a platform (a tile with PLATFORM_GROUND in its name, behind the
## OV gates) is not freely reachable, so the story never sends you there (fill_near, can_spots).
@export var ground_path := NodePath("../Grond")
const PLATFORM_GROUND := "spoor/perron"   # a railway platform; a tram stop (tram/tram_halte_perron) is free
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
	var wanted := mini(most_cans, roundi(_bins.size() * can_share))
	for index in wanted:
		_put_can(int(order[index]))


func _process(delta: float) -> void:
	_refill_clock += delta
	if _refill_clock < refill_seconds or _bins.is_empty():
		return
	_refill_clock = 0.0
	if cans_left() >= most_cans:
		return
	var empty: Array = []
	for index in _bins.size():
		var at: Vector3 = _bins[index].ground
		if _bins[index].spot == null and Vector2(at.x, at.z).distance_to(keep_empty_round) > keep_empty_radius:
			empty.append(index)
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
			var middle := Vector3(box.get_center().x, 0.0, box.get_center().z)
			var foot := props.global_transform * (origin + basis * middle)
			var top := props.global_transform * (origin + basis * Vector3(middle.x, box.end.y, middle.z))
			_bins.append({"ground": foot, "top": top, "spot": null, "free": true})


## Bins on a platform (PLATFORM_GROUND) are not "free": behind the gates.
func _mark_platforms(ground: GridMap) -> void:
	if ground == null or ground.mesh_library == null:
		return
	for bin: Dictionary in _bins:
		var at: Vector3 = bin.ground
		var cell := ground.local_to_map(ground.to_local(at))
		for level in range(-2, 8):
			var item := ground.get_cell_item(Vector3i(cell.x, level, cell.z))
			if item != -1 and ground.mesh_library.get_item_name(item).contains(PLATFORM_GROUND):
				bin.free = false
				break


## A can in bin `index`: sticking out of the top, a spot with "[E] Blikje pakken" at its foot.
func _put_can(index: int) -> void:
	var bin: Dictionary = _bins[index]
	if bin.spot != null:
		return
	var spot: Node3D = InteriorSpot.create("Blikje%d" % (index + 1), Vector3.ZERO, "Blikje pakken", _take.bind(index), SPOT_REACH)
	spot.set("kind", "oppakken")   # Interactable.KIND_PICKUP
	add_child(spot)
	spot.global_position = bin.ground
	var can := MeshInstance3D.new()
	can.name = "Blikje"
	can.mesh = MachineModels.can_mesh()
	spot.add_child(can)
	can.global_position = (bin.top as Vector3) - Vector3.UP * 0.08
	can.rotation = Vector3(0.35, _random.randf() * TAU, 0.2)
	QuestOutline.add(can, 0.02)
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
	var count := 0
	for bin: Dictionary in _bins:
		if bin.spot != null:
			count += 1
	return count


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
	var spots: Array = []
	for bin: Dictionary in _bins:
		if bin.spot != null and bin.free:   # not on a platform behind the gates
			spots.append(Vector2(bin.ground.x, bin.ground.z))
	spots.sort_custom(func(first: Vector2, second: Vector2) -> bool: return first.distance_to(near) < second.distance_to(near))
	return spots.slice(0, count)


## Makes sure the `count` freely reachable bins nearest to `near` (world x, z) have a can
## (the first mission needs some by the start), and when `alone_within` > 0 takes the cans
## out of every other bin within that many metres (so these are the only ones there);
## returns the farthest of them from `near` in metres. `in_sight`: only bins with no building
## between them and `near` (in_sight_of: on the square, not behind the station on it).
func fill_near(near: Vector2, count: int, alone_within := 0.0, in_sight := false) -> float:
	var order: Array = range(_bins.size()).filter(func(index: int) -> bool: return _bins[index].free)
	if in_sight:
		var buildings := get_node_or_null(buildings_path) as GridMap
		order = order.filter(func(index: int) -> bool:
			var at: Vector3 = _bins[index].ground
			return in_sight_of(buildings, near, Vector2(at.x, at.z)))
	order.sort_custom(func(first: int, second: int) -> bool:
		var a: Vector3 = _bins[first].ground
		var b: Vector3 = _bins[second].ground
		return Vector2(a.x, a.z).distance_to(near) < Vector2(b.x, b.z).distance_to(near))
	var farthest := 0.0
	for index: int in order.slice(0, count):
		if _bins[index].spot == null:
			_put_can(index)
		var at: Vector3 = _bins[index].ground
		farthest = maxf(farthest, Vector2(at.x, at.z).distance_to(near))
	var chosen: Array = order.slice(0, count)
	if alone_within > 0.0:
		for index in _bins.size():
			var bin: Dictionary = _bins[index]
			var at: Vector3 = bin.ground
			if bin.spot != null and not chosen.has(index) and Vector2(at.x, at.z).distance_to(near) <= alone_within:
				(bin.spot as Node3D).queue_free()
				bin.spot = null
	return farthest


## Whether no building of `buildings` (its ground storey) stands on the straight line from
## `from` to `to` (world x, z), looked at every metre; true without a buildings layer.
static func in_sight_of(buildings: GridMap, from: Vector2, to: Vector2) -> bool:
	if buildings == null:
		return true
	var steps := maxi(ceili(from.distance_to(to)), 1)
	for step in range(1, steps):
		var at := from.lerp(to, float(step) / steps)
		var cell := buildings.local_to_map(buildings.to_local(Vector3(at.x, 0.5, at.y)))
		if buildings.get_cell_item(Vector3i(cell.x, 0, cell.z)) != GridMap.INVALID_CELL_ITEM:
			return false
	return true
