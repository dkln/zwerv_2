extends Node3D
## A spot in an interior where [E] does something (PlayerController looks for it in the group
## of the doors, Interiors.DOORS_GROUP, as for a way in): take a trolley or a basket, take
## something off a shelf, pay at a checkout (scripts/world/supermarket.gd), call the lift or
## take a number (scripts/world/city_hall.gd). Its text is shown as "[E] <text>"; `text_of`
## (a Callable returning a String) makes it change with what is going on ("Karretje pakken",
## "Karretje terugzetten").
##   const InteriorSpot = preload("res://scripts/world/interior_spot.gd")
##   var spot := InteriorSpot.create("Kassa1", Vector3(2, 0, -3), "Afrekenen", _pay.bind(1))
##   add_child(spot)

const DOORS_GROUP := "deuren"
const REACH := 1.3

var text := ""
var text_of := Callable()
var on_use := Callable()
var reach_metres := REACH


static func create(spot_name: String, at: Vector3, action: String, use: Callable, reach_in_metres := REACH) -> Node3D:
	var spot: Node3D = (load("res://scripts/world/interior_spot.gd") as GDScript).new()
	spot.name = spot_name
	spot.position = at
	spot.text = action
	spot.on_use = use
	spot.reach_metres = reach_in_metres
	spot.add_to_group(DOORS_GROUP)
	return spot


func action_text() -> String:
	if text_of.is_valid():
		return String(text_of.call())
	return text


func reach() -> float:
	return reach_metres


func go_through() -> void:
	if on_use.is_valid():
		on_use.call()
