extends "res://scripts/world/things/interactable.gd"
## A spot in an interior where [E] does something (an Interactable of KIND_SPOT) (PlayerController looks for it in the group
## of the doors, Interiors.DOORS_GROUP, as for a way in): take a trolley or a basket, take
## something off a shelf, pay at a checkout (scripts/world/interiors/supermarket.gd), call the lift or
## take a number (scripts/world/interiors/city_hall.gd). Its text is shown as "[E] <text>"; `text_of`
## (a Callable returning a String) makes it change with what is going on ("Karretje pakken",
## "Karretje terugzetten").
##   const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
##   var spot := InteriorSpot.create("Kassa1", Vector3(2, 0, -3), "Afrekenen", _pay.bind(1))
##   add_child(spot)

const DOORS_GROUP := "deuren"


static func create(spot_name: String, at: Vector3, action: String, use: Callable, reach_in_metres := REACH) -> Node3D:
	var spot: Node3D = (load("res://scripts/world/interiors/interior_spot.gd") as GDScript).new()
	spot.name = spot_name
	spot.position = at
	spot.set("kind", KIND_SPOT)
	spot.set("text", action)
	spot.set("on_use", use)
	spot.set("reach_metres", reach_in_metres)
	spot.call("make_usable")
	return spot
