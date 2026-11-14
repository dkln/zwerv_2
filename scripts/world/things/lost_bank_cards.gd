extends "res://scripts/world/things/street_finds.gd"
## Lost bank cards on the streets (the node "Pinpassen" of scenes/stad.tscn): none until the
## story unlocks it ("pinpassen", a later mission), then a rare find,
## `count` (one) in the whole town, on a square or pavement well away from where the player
## starts (between `near` and `reach` m; `near_count` of them within `near`, none by default),
## more than one a third of `reach` apart. No story needs one. Where they lie and walking
## over them: StreetFinds. A card stands up and
## slowly turns, with the glowing outline of things to pick up (QuestOutline). Walking over
## one (within `pick_up_distance`) puts it in your pockets as a "pinpas" with its own account:
## a modest balance, a PIN and the riddle of it on the back (BankCards.give_found_bank_card,
## the inventory shows the riddle), announced with the reward screen ("GEVONDEN", the card
## big and turning: GameHud.show_reward). Full pockets: it stays lying.

const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const CARD_SEED := 97
const TURN_SPEED := 1.1
const LIFT := 0.12
const OUTLINE_COLOUR := Color("#7AD8FF")

@export var hud_path := NodePath("../HUD")


func _init() -> void:
	random_seed = CARD_SEED   # their own lots, not those of the coins


func _unlock_name() -> String:
	return "pinpassen"


func _closest() -> float:
	return 12.0


func _apart() -> float:
	return reach / 3.0


func _scatter() -> float:
	return 1.2


func _make_find(at: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Pinpas"
	holder.set_meta("phase", _random.randf() * TAU)
	holder.set_meta("seed", _random.randi())
	add_child(holder)
	holder.global_position = at + Vector3.UP * LIFT
	var shape := MeshInstance3D.new()
	shape.mesh = MachineModels.bank_card_mesh()
	holder.add_child(shape)
	QuestOutline.add(shape, 0.025, OUTLINE_COLOUR)
	return holder


func _turn_find(card: Node3D) -> void:
	card.rotation.y = _clock * TURN_SPEED + float(card.get_meta("phase", 0.0))


## A new bank card in the pockets (its own account from the card's seed); full pockets: it
## stays.
func _take(card: Node3D) -> bool:
	var random := RandomNumberGenerator.new()
	random.seed = int(card.get_meta("seed", 0))
	var hud := get_node_or_null(hud_path)
	var announced := hud != null and hud.has_method("show_reward")
	# quiet when the reward screen announces it (no "picked up" note as well)
	if not BankCards.give_found_bank_card(_player, random, announced):
		return false
	if announced:
		hud.show_reward({"heading": "GEVONDEN", "title": "Op straat", "items": [{"item": BankCards.ITEM, "count": 1}]})
	return true
