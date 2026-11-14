extends "res://scripts/ui/machines/machine_screen_view.gd"
## How the deposit machine looks (the graphics layer of
## scripts/ui/machines/deposit_machine_screen.gd, which is the behaviour and has this as its
## view; deposit_machine_screen_rules.gd has the logic, deposit_machine_screen_layout.gd says
## where its parts are): the view of a machine (machine_screen_view.gd) with the model of
## the deposit machine of the supermarkets, its colours, a little screen that shows a few
## big words (no buttons: you use its hole and its BON key), and a can or bottle going into
## the hole, carried off or coming back out (play_into_hole). It decides nothing.
##   const DepositMachineScreenView = preload("res://scripts/ui/machines/deposit_machine_screen_view.gd")

const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const DepositMachineScreenLayout = preload("res://scripts/ui/machines/deposit_machine_screen_layout.gd")
const BODY := Color("#E8ECEA")
const TRIM := Color("#2E9A48")
const SCREEN := Color("#9CFF7A")
## A little screen: a few big words (px).
const TITLE_SIZE := 78
const TEXT_SIZE := 64
const PACKAGE_NAME := "Verpakking"
## The names of the parts you can click (as DepositMachineScreenRules.HOLE and BON_KEY).
const HOLE_NAME := "gat"
const BON_KEY_NAME := "bon"
## The seconds a can or bottle takes to the hole, into it, waiting in it and back out
## (refused), and how long it lies there then.
const TO_HOLE_SECONDS := 0.22
const INTO_HOLE_SECONDS := 0.28
const WAIT_IN_HOLE_SECONDS := 0.35
const BACK_OUT_SECONDS := 0.3
const BACK_REST_SECONDS := 0.25


func _init() -> void:
	body_colour = BODY
	trim_colour = TRIM
	screen_colour = SCREEN
	display_title_size = TITLE_SIZE
	display_text_size = TEXT_SIZE


## The deposit machine of the supermarkets (MachineModels.deposit_machine_mesh): its model
## and where its screen, BON key, slot and hole are; the hole and the key can be clicked.
func machine_parts() -> Dictionary:
	var made := DepositMachineScreenLayout.parts(HOLE_NAME, BON_KEY_NAME)
	made["mesh"] = MachineModels.deposit_machine_mesh()
	return made


## The can (or `bottle`) in the scene: lying, bottom first, it comes from before the hole
## (machine_parts "hole"), slides in and is gone; `rejected`: it waits a moment in the hole
## and slides back out to where it came from. Returns when that is over (at once without
## `animate`).
func play_into_hole(bottle: bool, rejected: bool) -> void:
	var hole: Variant = parts().get("hole")
	if not animate or not hole is Vector3:
		return
	var thing := MeshInstance3D.new()
	thing.name = PACKAGE_NAME
	thing.mesh = MachineModels.bottle_mesh() if bottle else MachineModels.can_mesh()
	# lying, its bottom (y = 0) towards the machine
	thing.rotation_degrees.x = 90.0
	var before := DepositMachineScreenLayout.insert_before(hole)
	thing.position = before
	if not stage().add_piece(thing):
		thing.free()
		return
	var move := thing.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	move.tween_property(thing, "position", DepositMachineScreenLayout.insert_at_mouth(hole), TO_HOLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move.tween_property(thing, "position:z", DepositMachineScreenLayout.insert_deep_z(hole), INTO_HOLE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if rejected:
		move.tween_interval(WAIT_IN_HOLE_SECONDS)
		move.tween_property(thing, "position", before, BACK_OUT_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		move.tween_interval(BACK_REST_SECONDS)
	move.tween_callback(thing.queue_free)
	await move.finished
