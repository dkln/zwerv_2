extends Node3D
## The machines in the streets (the node "Straatautomaten" of scenes/stad.tscn; behaviour,
## docs/CODE_LAGEN.md: its rules street_machines_rules.gd, the places
## street_machines_layout.gd, the models and the beep street_machines_view.gd; the city
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

const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
const Interactable = preload("res://scripts/world/things/interactable.gd")
const CashMachineScreen = preload("res://scripts/ui/machines/cash_machine_screen.gd")
const Banks = preload("res://scripts/world/things/banks.gd")
const OvCard = preload("res://scripts/world/station/ov_card.gd")
const StationAudio = preload("res://scripts/world/station/station_audio.gd")
const StreetMachinesRules = preload("res://scripts/world/things/street_machines_rules.gd")
const StreetMachinesLayout = preload("res://scripts/world/things/street_machines_layout.gd")
const StreetMachinesView = preload("res://scripts/world/things/street_machines_view.gd")
const OV_POST_TILE := StreetMachinesRules.OV_POST_TILE
const OV_POST_PREFIX := StreetMachinesRules.OV_POST_PREFIX
const SPOT_AHEAD := StreetMachinesLayout.SPOT_AHEAD
const SPOT_REACH := StreetMachinesLayout.SPOT_REACH
const TOWN_LAYER := 1

@export var player_path := NodePath("../Speler")
@export var hud_path := NodePath("../HUD")

var _player: Node3D
var machines: Array[Node3D] = []
## The models, the beep and the text of the machines.
var view := StreetMachinesView.new()


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	# after the town is in (the ground for the rays)
	_dress.call_deferred()


func _dress() -> void:
	# the colliders of the town in the physics space first
	await get_tree().physics_frame
	await get_tree().physics_frame
	for marker in get_children():
		dress_marker(marker as Node3D)


## The machine of the marker `place` put on the ground under it, with its [E] spot; false
## when `place` is no marker of a machine (or its model is not there).
func dress_marker(place: Node3D) -> bool:
	var kind := StreetMachinesRules.kind_of(String(place.name)) if place else ""
	if kind == "":
		return false
	_settle_on_ground(place)
	var machine: Node3D = view.cash_machine() if kind == StreetMachinesRules.CASH else view.ov_post(OV_POST_TILE)
	if machine == null:
		return false
	place.add_child(machine)
	place.add_child(_cash_spot(place) if kind == StreetMachinesRules.CASH else _post_spot(place))
	machines.append(place)
	return true


## The [E] spot of the cash machine at `place`: a machine with a screen of its own, of the
## bank of this place (random, but always the same one for it).
func _cash_spot(place: Node3D) -> Node3D:
	place.set_meta("bank", Banks.bank_for(place.global_position))
	var spot: Node3D = InteriorSpot.create("Plek", StreetMachinesLayout.cash_spot(), StreetMachinesRules.CASH_TEXT,
		_open_cash_machine.bind(String(place.get_meta("bank", ""))), SPOT_REACH)
	spot.set("kind", Interactable.KIND_MACHINE)
	return spot


## The [E] spot of the OV post at `place`: "Inchecken" or "Uitchecken".
func _post_spot(place: Node3D) -> Node3D:
	var spot: Node3D = Interactable.make("Plek", StreetMachinesLayout.post_spot(), Interactable.KIND_GATE,
		StreetMachinesRules.POST_TEXT, _tap_post.bind(place), SPOT_REACH)
	spot.set("text_of", _post_action)
	return spot


func _settle_on_ground(place: Node3D) -> void:
	var space := get_world_3d().direct_space_state
	var ray := StreetMachinesLayout.ground_ray(place.global_position)
	var query := PhysicsRayQueryParameters3D.create(ray[0], ray[1], TOWN_LAYER)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		place.global_position.y = (hit.position as Vector3).y


func _open_cash_machine(bank := "") -> void:
	if _player:
		CashMachineScreen.show_for(_player, "", true, bank)


## "[E] Inchecken" or "[E] Uitchecken" at a post.
func _post_action() -> String:
	return OvCard.post_action(_player) if _player else StreetMachinesRules.POST_TEXT


## The card held to the post at `place`: the beep (or the error tone) and what it says over it.
func _tap_post(place: Node3D) -> void:
	if _player == null:
		return
	var result := OvCard.tap(_player)
	view.play_beep(place, StationAudio.stream(String(result.sound)))
	view.show_post_text(get_node_or_null(hud_path), place.global_position, String(result.text),
			StreetMachinesRules.is_refusal(result))


## The cash machines in the town (for the checks).
func cash_machines() -> Array:
	return machines.filter(func(place: Node3D) -> bool: return StreetMachinesRules.kind_of(String(place.name)) == StreetMachinesRules.CASH)


## The OV posts at the tram and bus stops (for the checks).
func ov_posts() -> Array:
	return machines.filter(func(place: Node3D) -> bool: return StreetMachinesRules.kind_of(String(place.name)) == StreetMachinesRules.POST)
