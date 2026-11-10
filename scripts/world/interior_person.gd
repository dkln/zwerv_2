class_name InteriorPerson
extends Node3D
## Someone in an interior (scripts/world/interior.gd): the man or woman behind the counter
## (`role` "snackbarhouder") or someone at a table (`role` "klant", sitting on its chair); and
## the people on the terraces in the town (scripts/world/terraces.gd), sitting as well.
## A townsperson (TownsfolkFigure, its look from `look_seed`), in the group of who can be
## talked to (TALKABLE_GROUP, PlayerController), with what a conversation needs of it
## (Conversations: `figure`, `mobility`, voice()).
##   var person := InteriorPerson.create("klant", 17, true)

## Everyone the player can talk to (pedestrians too): PlayerController looks in it.
const TALKABLE_GROUP := "aanspreekbaar"
## Seat height (metres: the top of the chair, binnen/snackbar/stoel) and how far forward the
## feet stand from the hips (sitting).
const SEAT_HEIGHT := 0.625
const KNEE_REACH := 0.45

var role := "klant"
var mobility := ""
var figure: TownsfolkFigure
var sitting := false
var seat_height := SEAT_HEIGHT


## Someone of `person_role` with the look of `look_seed`; `sit`: on a chair at its origin
## (facing +z), else standing.
static func create(person_role: String, look_seed: int, sit: bool, on_seat_at := SEAT_HEIGHT) -> InteriorPerson:
	var person := InteriorPerson.new()
	person.seat_height = on_seat_at
	person.name = "Snackbarhouder" if person_role == "snackbarhouder" else "Klant"
	person.role = person_role
	person.sitting = sit
	var look := TownsfolkFigure.look_for(look_seed)
	if person_role == "snackbarhouder":
		# the white coat of the snack bar and a white cap
		look["coat"] = Color("#E8E6E0")
		look["trim"] = Color("#C8C4BA")
		look["hair_style"] = "pet"
		look["cap"] = Color("#E8E6E0")
		look["skirt"] = false
	person.figure = TownsfolkFigure.create(look)
	person.figure.name = "Figuur"
	person.add_child(person.figure)
	person.add_to_group(TALKABLE_GROUP)
	if sit:
		person._sit()
	return person


## Sitting on the chair: the hips on the seat, the feet on the floor before it, the hands on
## the table.
func _sit() -> void:
	figure.position = Vector3(0.0, seat_height, 0.0) - figure.hip_middle()
	for side: String in ["left", "right"]:
		var rest := figure.rest_joint("thigh_" + side)
		var foot := Vector3(rest.x, 0.0, KNEE_REACH) - figure.position
		figure.aim_leg(side, foot)
		var shoulder := figure.rest_joint("arm_" + side)
		figure.aim_arm(side, Vector3(shoulder.x * 0.8, seat_height + 0.15, 0.4) - figure.position)


## The voice of the cries and the babble (as Pedestrian.voice).
func voice() -> String:
	var look: Dictionary = figure.look if figure else {}
	if look.get("hair_style", "") == "lang" or look.get("skirt", false):
		return "vrouw"
	if look.get("hair_style", "") == "kaal":
		return "oude_man"
	return "man"
