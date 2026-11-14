class_name CarriedItems
extends RefCounted
## What a townsperson (TownsfolkFigure) carries: a rucksack, a trolley case pulled along
## behind, a briefcase, a handbag or a shoulder bag. Built in code from voxels at the size the
## figures are drawn at (TownsfolkFigure.VOXEL), like the figures themselves, one mesh per kind
## and colour, shared. Used by the travellers in the station (scripts/world/station/station.gd) and the
## pedestrians in the town.
##   var bag := CarriedItems.attach(figure, "aktetas", 17)
##   ...each update, after figure.walk(phase, amount):
##   CarriedItems.pose(figure, "aktetas")
## Where it hangs: a briefcase and a handbag in the right hand (a child of the arm's joint, so
## it swings with the arm), a rucksack and a shoulder bag on the body (they bob with it), a
## trolley case on the ground behind, its handle in the right hand (pose aims the arm at it).
## Voxels: x across, y up, z from the front (0) backwards, as the figures.
## Behaviour (docs/CODE_LAGEN.md): which kinds there are, the colour of a seed, the look of
## someone in a suit. The models and their colours: carried_items_view.gd; where they hang:
## carried_items_layout.gd.

const CarriedItemsView = preload("res://scripts/world/people/carried_items_view.gd")
const CarriedItemsLayout = preload("res://scripts/world/people/carried_items_layout.gd")

const KINDS: Array[String] = ["rugzak", "rolkoffer", "aktetas", "handtas", "schoudertas"]
## The kind whose colours something of an unknown kind gets.
const DEFAULT_KIND := "rugzak"
## Colours per kind (picked by colour_seed).
const COLOURS := CarriedItemsView.COLOURS
const DARK_METAL := CarriedItemsView.DARK_METAL
const LIGHT_METAL := CarriedItemsView.LIGHT_METAL
const STRAP := CarriedItemsView.STRAP
const TROLLEY_TILT := CarriedItemsLayout.TROLLEY_TILT
const TROLLEY_HAND_BACK := CarriedItemsLayout.TROLLEY_HAND_BACK
const HAND_GRIP_DROP := CarriedItemsLayout.HAND_GRIP_DROP
## Someone in a suit: the chance of a skirt (with long hair).
const SUIT_SKIRT_CHANCE := 0.45


## Hangs a `kind` (KINDS) on `figure` in a colour of `colour_seed`; the node it put there.
static func attach(figure: TownsfolkFigure, kind: String, colour_seed: int) -> Node3D:
	return CarriedItemsView.build(figure, kind, colour_of(kind, colour_seed))


## The colour of a `kind` for `colour_seed`: always the same for the same seed.
static func colour_of(kind: String, colour_seed: int) -> Color:
	var colours: Array = COLOURS.get(kind, COLOURS[DEFAULT_KIND])
	return colours[absi(colour_seed) % colours.size()]


## The arm after the walk: at the handle of a trolley case; a briefcase or a handbag swings
## less (it is heavy). Call it after figure.walk().
static func pose(figure: TownsfolkFigure, kind: String) -> void:
	CarriedItemsView.show_pose(figure, kind)


## A look in a suit: a dark jacket with a white collar (the shirt), the trousers of the
## jacket, polished shoes, short hair or long (never a cap); now and then a skirt.
static func business_look(look_seed: int) -> Dictionary:
	var look := TownsfolkFigure.look_for(look_seed)
	var random := RandomNumberGenerator.new()
	random.seed = look_seed * 31 + 7
	var suit: Color = CarriedItemsView.SUITS[random.randi() % CarriedItemsView.SUITS.size()]
	look["coat"] = suit
	look["trim"] = CarriedItemsView.SHIRTS[random.randi() % CarriedItemsView.SHIRTS.size()]
	look["trousers"] = suit
	look["shoes"] = CarriedItemsView.SUIT_SHOES[random.randi() % CarriedItemsView.SUIT_SHOES.size()]
	if look.hair_style == "pet":
		look["hair_style"] = "kort"
	look["skirt"] = look.hair_style == "lang" and random.randf() < SUIT_SKIRT_CHANCE
	return look


## The mesh of a kind in a colour, built once.
static func mesh_for(kind: String, colour: Color) -> ArrayMesh:
	return CarriedItemsView.mesh_for(kind, colour)
