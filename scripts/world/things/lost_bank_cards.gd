extends "res://scripts/world/things/street_finds.gd"
## Lost bank cards on the streets (the node "Pinpassen" of scenes/stad.tscn; behaviour,
## docs/CODE_LAGEN.md): none until the story unlocks it ("pinpassen", a later mission), then
## a rare find, `count` (one) in the whole town, on a square or pavement well away from
## where the player starts (between `near` and `reach` m; `near_count` of them within
## `near`, none by default), more than one a third of `reach` apart
## (lost_bank_cards_rules.gd). No story needs one. Where they lie and walking over them:
## street_finds.gd. A card stands up and slowly turns, with the glowing outline of things to
## pick up (lost_bank_cards_view.gd). Walking over one (within `pick_up_distance`) puts it
## in your pockets as a "pinpas" with its own account: a modest balance, a PIN and the
## riddle of it on the back (BankCards.give_found_bank_card, the inventory shows the
## riddle), announced with the reward screen ("GEVONDEN", the card big and turning:
## GameHud.show_reward). Full pockets: it stays lying.

const LostBankCardsRules = preload("res://scripts/world/things/lost_bank_cards_rules.gd")
const LostBankCardsView = preload("res://scripts/world/things/lost_bank_cards_view.gd")
const BankCards = preload("res://scripts/player/bank_cards.gd")
const CARD_SEED := LostBankCardsRules.CARD_SEED
const LIFT := LostBankCardsView.LIFT

@export var hud_path := NodePath("../HUD")


func _init() -> void:
	random_seed = CARD_SEED   # their own lots, not those of the coins


func _unlock_name() -> String:
	return LostBankCardsRules.UNLOCK


func _closest() -> float:
	return LostBankCardsRules.CLOSEST


func _apart() -> float:
	return LostBankCardsRules.apart(reach)


func _scatter() -> float:
	return LostBankCardsRules.SCATTER


func _make_find(at: Vector3) -> Node3D:
	var card := LostBankCardsView.create()
	card.set_meta("phase", _random.randf() * TAU)
	card.set_meta("seed", _random.randi())
	add_child(card)
	card.global_position = at + Vector3.UP * LIFT
	return card


func _turn_find(card: Node3D) -> void:
	card.call("show_turn", LostBankCardsRules.turn(_clock, float(card.get_meta("phase", 0.0))))


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
		hud.show_reward(LostBankCardsRules.found_reward(BankCards.ITEM))
	return true
