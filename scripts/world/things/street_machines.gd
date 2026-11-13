extends Node3D
## The machines in the streets (the node "Straatautomaten" of scenes/stad.tscn; the city
## builder puts a marker for each, tools/build/city/finishing.gd `_street_machines`, its +z
## the way the machine faces):
## - Geldautomaat_<n>: a cash machine (PINPUNT, MachineModels.cash_machine_mesh) flush
##   against a facade: beside supermarket entrances, in the shopping streets, on squares.
##   "[E] Pinnen" opens CashMachineScreen (scripts/ui/machines/cash_machine_screen.gd);
## - OVPaal_<n>: an OV post (the prop ov/ov_incheckpaal) beside the shelter of a tram or bus
##   stop: "[E] Inchecken" / "[E] Uitchecken" holds the OV-chipkaart to it, as the posts in
##   the station (OvCard.tap: a beep, refused without a card or with too little on it, the
##   boarding fare for a trip not checked out). Cards are bought and topped up at the machines
##   in the hall of Den Haag Centraal (OvMachineScreen).
## Each has a collider (MachineModels.instance) and stands on the ground under its marker (a
## ray down). The [E] spot is before its front (SPOT_AHEAD), in the group of the doors.

const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
const Interactable = preload("res://scripts/world/things/interactable.gd")
const CashMachineScreen = preload("res://scripts/ui/machines/cash_machine_screen.gd")
const Banks = preload("res://scripts/world/things/banks.gd")
const OvCard = preload("res://scripts/world/station/ov_card.gd")
const StationAudio = preload("res://scripts/world/station/station_audio.gd")
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const OV_POST_TILE := "ov/ov_incheckpaal"
const OV_POST_PREFIX := "OVPaal"
const SPOT_AHEAD := 0.75
const SPOT_REACH := 1.1
const TOWN_LAYER := 1
## What the post shows over it (the HUD's floating text): green, red when it says no or kept
## the boarding fare.
const POST_OK_COLOUR := Color("#3CE06A")
const POST_NO_COLOUR := Color("#FF5A4A")

@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")

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
	var post_mesh: Mesh = null
	var post_transform := Transform3D()
	for marker in get_children():
		var place := marker as Node3D
		if place == null:
			continue
		var is_cash := String(place.name).begins_with("Geldautomaat")
		var is_post := String(place.name).begins_with(OV_POST_PREFIX)
		if not (is_cash or is_post):
			continue
		_settle_on_ground(place)
		var machine: Node3D
		if is_cash:
			machine = MachineModels.instance(MachineModels.cash_machine_mesh(), "Geldautomaat")
		else:
			if post_mesh == null and ResourceLoader.exists(PROPS_LIBRARY):
				var library: MeshLibrary = load(PROPS_LIBRARY)
				var item := library.find_item_by_name(OV_POST_TILE)
				if item >= 0:
					post_mesh = library.get_item_mesh(item)
					post_transform = library.get_item_mesh_transform(item)
			if post_mesh == null:
				continue
			machine = MachineModels.instance(post_mesh, "OVPaal")
			(machine.get_node("Model") as Node3D).transform = post_transform
			(machine.get_node("Botsvorm") as Node3D).transform = post_transform   # the collider on the mesh
		place.add_child(machine)
		var spot: Node3D
		if is_cash:
			# a cash machine belongs to a bank: random, but always the same one for this place
			place.set_meta("bank", Banks.bank_for(place.global_position))
			# (a machine with a screen of its own: Interactable.KIND_MACHINE, set below)
			spot = InteriorSpot.create("Plek", Vector3(0.0, 0.0, SPOT_AHEAD + 0.25), "Pinnen",
				_open_cash_machine.bind(String(place.get_meta("bank", ""))), SPOT_REACH)
			spot.set("kind", "automaat")
		else:
			spot = Interactable.make("Plek", Vector3(0.0, 0.0, SPOT_AHEAD), Interactable.KIND_GATE, "Inchecken",
				_tap_post.bind(place), SPOT_REACH)
			spot.set("text_of", _post_action)
		place.add_child(spot)
		machines.append(place)


func _settle_on_ground(place: Node3D) -> void:
	var space := get_world_3d().direct_space_state
	var from := place.global_position + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, place.global_position + Vector3.DOWN * 3.0, TOWN_LAYER)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		place.global_position.y = (hit.position as Vector3).y


func _open_cash_machine(bank := "") -> void:
	if _player:
		CashMachineScreen.show_for(_player, "", true, bank)


## "[E] Inchecken" or "[E] Uitchecken" at a post.
func _post_action() -> String:
	return OvCard.post_action(_player) if _player else "Inchecken"


## The card held to the post at `place`: the beep (or the error tone) and what it says over it.
func _tap_post(place: Node3D) -> void:
	if _player == null:
		return
	var result := OvCard.tap(_player)
	var sound := StationAudio.stream(String(result.sound))
	if sound:
		var beep := AudioStreamPlayer3D.new()
		beep.stream = sound
		beep.volume_db = -6.0
		place.add_child(beep)
		beep.position = Vector3.UP * 1.1
		beep.finished.connect(beep.queue_free)
		beep.play()
	var hud := get_node_or_null(hud_path)
	if hud and hud.has_method("show_floating_number"):
		var red: bool = not result.ok or float(result.charge) > 0.0
		hud.show_floating_number(place.global_position + Vector3.UP * 1.6, String(result.text), POST_NO_COLOUR if red else POST_OK_COLOUR, 14)


## The cash machines in the town (for the checks).
func cash_machines() -> Array:
	return machines.filter(func(place: Node3D) -> bool: return String(place.name).begins_with("Geldautomaat"))


## The OV posts at the tram and bus stops (for the checks).
func ov_posts() -> Array:
	return machines.filter(func(place: Node3D) -> bool: return String(place.name).begins_with(OV_POST_PREFIX))
