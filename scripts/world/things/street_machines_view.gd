extends RefCounted
## What the machines in the streets look and sound like (graphics; docs/CODE_LAGEN.md;
## street_machines.gd): the cash machine (MachineModels.cash_machine_mesh) and the OV post
## (a prop of the props library) with their colliders, the beep of a post and the colour of
## what it says. It makes and shows what street_machines.gd asks for and decides nothing;
## heights come from street_machines_layout.gd.
##   const StreetMachinesView = preload("res://scripts/world/things/street_machines_view.gd")
##   var view := StreetMachinesView.new()
##   place.add_child(view.cash_machine())

const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const StreetMachinesLayout = preload("res://scripts/world/things/street_machines_layout.gd")
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const CASH_NAME := "Geldautomaat"
const POST_NAME := "OVPaal"
## What the post shows over it (the HUD's floating text): green, red when it says no or kept
## the boarding fare.
const POST_OK_COLOUR := Color("#3CE06A")
const POST_NO_COLOUR := Color("#FF5A4A")
const BEEP_VOLUME := -6.0

var _post_mesh: Mesh
var _post_transform := Transform3D()


## A cash machine: the model and its collider.
func cash_machine() -> Node3D:
	return MachineModels.instance(MachineModels.cash_machine_mesh(), CASH_NAME)


## An OV post: the prop tile `tile_name` of the props library (looked up once) with a
## collider on its mesh; null when the library or the tile is not there.
func ov_post(tile_name: String) -> Node3D:
	if _post_mesh == null and ResourceLoader.exists(PROPS_LIBRARY):
		var library: MeshLibrary = load(PROPS_LIBRARY)
		var item := library.find_item_by_name(tile_name)
		if item >= 0:
			_post_mesh = library.get_item_mesh(item)
			_post_transform = library.get_item_mesh_transform(item)
	if _post_mesh == null:
		return null
	var machine := MachineModels.instance(_post_mesh, POST_NAME)
	(machine.get_node("Model") as Node3D).transform = _post_transform
	(machine.get_node("Botsvorm") as Node3D).transform = _post_transform   # the collider on the mesh
	return machine


## The beep (or the error tone) `sound` of the post at `place`; gone when it has sounded.
func play_beep(place: Node3D, sound: AudioStream) -> AudioStreamPlayer3D:
	if sound == null:
		return null
	var beep := AudioStreamPlayer3D.new()
	beep.stream = sound
	beep.volume_db = BEEP_VOLUME
	place.add_child(beep)
	beep.position = StreetMachinesLayout.beep_place()
	beep.finished.connect(beep.queue_free)
	beep.play()
	return beep


## What the post at `at` says, floating over it on `hud` (GameHud.show_floating_number):
## red when `refused`, green otherwise.
func show_post_text(hud: Node, at: Vector3, text: String, refused: bool) -> void:
	if hud and hud.has_method("show_floating_number"):
		hud.call("show_floating_number", StreetMachinesLayout.text_place(at), text,
				POST_NO_COLOUR if refused else POST_OK_COLOUR, StreetMachinesLayout.TEXT_SIZE)
