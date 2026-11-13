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

const MachineModels = preload("res://scripts/world/machine_models.gd")
const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const InteriorSpot = preload("res://scripts/world/interior_spot.gd")
const BIN_TILES := ["straat/prullenbak_paal", "straat/prullenbak_rond"]
const CAN_ITEM := "blikje"
const SPOT_REACH := 1.3

@export var can_share := 0.3
@export var most_cans := 60
@export var refill_seconds := 150.0
@export var random_seed := 53
@export var player_path := NodePath("../Speler")
@export var props_path := NodePath("../Props")

var _player: Node3D
var _random := RandomNumberGenerator.new()
## Every bin: {"ground": Vector3 (at its foot), "top": Vector3, "spot": Node3D or null}.
var _bins: Array[Dictionary] = []
var _refill_clock := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_random.seed = random_seed
	var props := get_node_or_null(props_path) as GridMap
	if props and props.mesh_library:
		_find_bins(props)
	var order: Array = range(_bins.size())
	for index in range(order.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var kept: Variant = order[index]
		order[index] = order[other]
		order[other] = kept
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
		if _bins[index].spot == null:
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
			_bins.append({"ground": foot, "top": top, "spot": null})


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
	if not bool(_player.call("add_item", CAN_ITEM)):
		return
	(bin.spot as Node3D).queue_free()
	bin.spot = null


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
