extends Node3D
## What a lost bank card on the streets looks like (graphics; docs/CODE_LAGEN.md;
## lost_bank_cards.gd): the bank card of the machine models standing up, with the glowing
## outline of things to pick up (QuestOutline) in its own light blue. It shows what
## lost_bank_cards.gd hands it (show_turn) and decides nothing.
##   const LostBankCardsView = preload("res://scripts/world/things/lost_bank_cards_view.gd")
##   var card := LostBankCardsView.create()

const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
## How high a card stands above the ground, and how wide its outline is (metres).
const LIFT := 0.12
const OUTLINE := 0.025
const OUTLINE_COLOUR := Color("#7AD8FF")


## A card (the node "Pinpas", its model the child "Kaart").
static func create() -> Node3D:
	var view: Node3D = (load("res://scripts/world/things/lost_bank_cards_view.gd") as GDScript).new()
	view.name = "Pinpas"
	var shape := MeshInstance3D.new()
	shape.name = "Kaart"
	shape.mesh = MachineModels.bank_card_mesh()
	view.add_child(shape)
	QuestOutline.add(shape, OUTLINE, OUTLINE_COLOUR)
	return view


## The card turned `angle` radians.
func show_turn(angle: float) -> void:
	rotation.y = angle
