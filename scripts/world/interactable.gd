extends Node3D
## Something in the world the player can use with [E] (not a person: those are talked to,
## scripts/world/person.gd). One contract for all of them, so it is clear what there is to
## interact with and PlayerController treats them alike: it looks in USE_GROUP for the
## nearest within reach(), shows "[E] <action_text()>" and calls go_through() on E.
## What kind of thing it is says `kind`:
## - KIND_DOOR: a way into or out of a building (Interiors.Entrance);
## - KIND_SPOT: a spot where something is done (InteriorSpot: take a trolley, something off
##   a shelf, pay at a till, call the lift, take a number);
## - KIND_MACHINE: a machine with a screen of its own (the cash machine, the deposit
##   machine, the OV-chipkaart machine: scripts/ui/machines/);
## - KIND_GATE: a lane of the OV gates of the station (check in, check out), an OV post;
## - KIND_PICKUP: something lying about to pick up (a rucksack, a lost bank card, a can).
## Who makes one sets `kind`, adds it with make_usable() and gives it its text and what E does
## (a subclass overrides action_text and go_through, or sets `text` and `on_use`).
##   const Interactable = preload("res://scripts/world/interactable.gd")
##   var spot := Interactable.make("Kassa1", at, Interactable.KIND_SPOT, "Afrekenen", _pay)

## Everything used with [E] that is not a person: PlayerController looks in it.
const USE_GROUP := "deuren"
const KIND_DOOR := "deur"
const KIND_SPOT := "plek"
const KIND_MACHINE := "automaat"
const KIND_GATE := "poortje"
const KIND_PICKUP := "oppakken"
const KINDS := [KIND_DOOR, KIND_SPOT, KIND_MACHINE, KIND_GATE, KIND_PICKUP]
## How far off (metres) it can be used when nothing else is said.
const REACH := 1.3

var kind := KIND_SPOT
## What is shown as "[E] <text>"; `text_of` (a Callable returning a String) makes it change
## with what is going on ("Karretje pakken", "Karretje terugzetten").
var text := ""
var text_of := Callable()
## What E does.
var on_use := Callable()
var reach_metres := REACH


## One of `of_kind` at `at`, shown as `action`, doing `use` on E.
static func make(node_name: String, at: Vector3, of_kind: String, action: String, use: Callable,
		reach_in_metres := REACH) -> Node3D:
	var made: Node3D = (load("res://scripts/world/interactable.gd") as GDScript).new()
	made.name = node_name
	made.position = at
	made.set("kind", of_kind)
	made.set("text", action)
	made.set("on_use", use)
	made.set("reach_metres", reach_in_metres)
	made.call("make_usable")
	return made


## In the group the player looks in (USE_GROUP).
func make_usable() -> void:
	add_to_group(USE_GROUP)


func action_text() -> String:
	if text_of.is_valid():
		return String(text_of.call())
	return text


func reach() -> float:
	return reach_metres


func go_through() -> void:
	if on_use.is_valid():
		on_use.call()


## Everything of `tree` the player can use now, per kind: kind -> Array of nodes (also the
## ones that do not extend this script: they count as KIND_SPOT unless they say their kind).
static func all_by_kind(tree: SceneTree) -> Dictionary:
	var found := {}
	for node in tree.get_nodes_in_group(USE_GROUP):
		var of_kind := String(node.get("kind")) if node.get("kind") != null else KIND_SPOT
		if not found.has(of_kind):
			found[of_kind] = []
		(found[of_kind] as Array).append(node)
	return found
