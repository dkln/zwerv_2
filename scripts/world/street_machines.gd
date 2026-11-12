extends Node3D
## The machines in the streets (the node "Straatautomaten" of scenes/stad.tscn; the city
## builder puts a marker for each, tools/build/city/finishing.gd `_street_machines`, its +z
## the way the machine faces):
## - Geldautomaat_<n>: a cash machine (PINPUNT, MachineModels.cash_machine_mesh) flush
##   against a facade: beside supermarket entrances, in the shopping streets, on squares.
##   "[E] Pinnen" opens CashMachineScreen (scripts/ui/machines/cash_machine_screen.gd);
## - OVAutomaat_<n>: an OV-chipkaart machine (the tile binnen/station/kaartautomaat of the
##   station hall) beside a tram shelter; "[E] OV-chipkaartautomaat" opens OvMachineScreen.
## Each has a collider (MachineModels.instance) and stands on the ground under its marker (a
## ray down). The [E] spot is before its front (SPOT_AHEAD), in the group of the doors.

const MachineModels = preload("res://scripts/world/machine_models.gd")
const InteriorSpot = preload("res://scripts/world/interior_spot.gd")
const CashMachineScreen = preload("res://scripts/ui/machines/cash_machine_screen.gd")
const OvMachineScreen = preload("res://scripts/ui/machines/ov_machine_screen.gd")
const INTERIOR_LIBRARY := "res://assets/libraries/binnen.res"
const OV_TILE := "station/kaartautomaat"
const SPOT_AHEAD := 0.75
const SPOT_REACH := 1.1
const TOWN_LAYER := 1

@export var player_path := NodePath("../Speler")

var _player: Node3D
var machines: Array[Node3D] = []


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	# after the town is in (the ground for the rays)
	_dress.call_deferred()


func _dress() -> void:
	# the colliders of the town in the physics space first
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ov_mesh: Mesh = null
	var ov_transform := Transform3D()
	for marker in get_children():
		var place := marker as Node3D
		if place == null:
			continue
		var is_cash := String(place.name).begins_with("Geldautomaat")
		var is_ov := String(place.name).begins_with("OVAutomaat")
		if not (is_cash or is_ov):
			continue
		_settle_on_ground(place)
		var machine: Node3D
		if is_cash:
			machine = MachineModels.instance(MachineModels.cash_machine_mesh(), "Geldautomaat")
		else:
			if ov_mesh == null and ResourceLoader.exists(INTERIOR_LIBRARY):
				var library: MeshLibrary = load(INTERIOR_LIBRARY)
				var item := library.find_item_by_name(OV_TILE)
				if item >= 0:
					ov_mesh = library.get_item_mesh(item)
					ov_transform = library.get_item_mesh_transform(item)
			if ov_mesh == null:
				continue
			machine = MachineModels.instance(ov_mesh, "OVAutomaat")
			(machine.get_node("Model") as Node3D).transform = ov_transform
			(machine.get_node("Botsvorm") as Node3D).transform = ov_transform   # the collider on the mesh
		place.add_child(machine)
		var use := _open_cash_machine if is_cash else _open_ov_machine
		var spot: Node3D = InteriorSpot.create("Plek", Vector3(0.0, 0.0, SPOT_AHEAD + 0.25), "Pinnen" if is_cash else "OV-chipkaartautomaat",
			use, SPOT_REACH)
		place.add_child(spot)
		machines.append(place)


func _settle_on_ground(place: Node3D) -> void:
	var space := get_world_3d().direct_space_state
	var from := place.global_position + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, place.global_position + Vector3.DOWN * 3.0, TOWN_LAYER)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		place.global_position.y = (hit.position as Vector3).y


func _open_cash_machine() -> void:
	if _player:
		CashMachineScreen.show_for(_player)


func _open_ov_machine() -> void:
	if _player:
		OvMachineScreen.show_for(_player, "TRAMHALTE")


## The cash machines and OV machines in the town (for the checks).
func cash_machines() -> Array:
	return machines.filter(func(place: Node3D) -> bool: return String(place.name).begins_with("Geldautomaat"))
