extends RefCounted
## The OV-chipkaart and its balance, and the single ticket (Items "ov_chipkaart",
## "los_kaartje"): bought at an OV-chipkaart machine (scripts/ui/machines/
## ov_machine_screen.gd: at Den Haag Centraal, at tram stops), used at the gates of the
## station (scripts/world/station/station_gates.gd) and the OV posts. The balance is kept on the
## player (metadata BALANCE_META). A new card costs CARD_PRICE and has START_BALANCE on it;
## checking in with it costs RIDE_FARE of the balance (too little: the gate says no);
## checking in with a single ticket is free, checking out with it the gate keeps it.
##   const OvCard = preload("res://scripts/world/station/ov_card.gd")
##   OvCard.buy_card(player)     # "ok", "geld", "vol" or "heb_al"
##   OvCard.top_up(player, 10.0)
##   OvCard.check_in(player)     # "kaart", "kaartje", "saldo" (too little) or "geen"
##   OvCard.refusal("saldo")     # what the reader says when it says no

const CARD_ITEM := "ov_chipkaart"
const TICKET_ITEM := "los_kaartje"
const BALANCE_META := "ov_saldo"
const CARD_PRICE := 7.5
const START_BALANCE := 2.5
const RIDE_FARE := 1.0
const TICKET_PRICE := 3.5
const TOP_UPS := [5.0, 10.0, 20.0]


static func has_card(player: Node) -> bool:
	return _count(player, CARD_ITEM) > 0


static func has_ticket(player: Node) -> bool:
	return _count(player, TICKET_ITEM) > 0


static func balance(player: Node) -> float:
	return float(player.get_meta(BALANCE_META, 0.0)) if player else 0.0


## A new card from the machine: "ok", "heb_al" (one is enough), "geld" or "vol".
static func buy_card(player: Node) -> String:
	if player == null:
		return "geld"
	if has_card(player):
		return "heb_al"
	var result := String(player.call("buy", CARD_ITEM, CARD_PRICE))
	if result == "ok":
		player.set_meta(BALANCE_META, START_BALANCE)
	return result


## Money from the wallet onto the card: "ok", "geen_kaart" or "geld".
static func top_up(player: Node, amount: float) -> String:
	if not has_card(player):
		return "geen_kaart"
	if float(player.get("money")) + 0.001 < amount:
		return "geld"
	player.call("add_money", -amount)
	player.set_meta(BALANCE_META, snappedf(balance(player) + amount, 0.01))
	return "ok"


## A single ride: "ok", "geld" or "vol" (PlayerController.buy).
static func buy_ticket(player: Node) -> String:
	if player == null:
		return "geld"
	return String(player.call("buy", TICKET_ITEM, TICKET_PRICE))


## Checking in at a gate or a post: with a card ("kaart", RIDE_FARE off the balance), else a
## single ticket ("kaartje"); "saldo" (a card but too little on it, no ticket) or "geen".
## `apply` false: only what it would be (nothing paid).
static func check_in(player: Node, apply := true) -> String:
	if has_card(player) and balance(player) + 0.001 >= RIDE_FARE:
		if apply:
			player.set_meta(BALANCE_META, snappedf(balance(player) - RIDE_FARE, 0.01))
		return "kaart"
	if has_ticket(player):
		return "kaartje"
	return "saldo" if has_card(player) else "geen"


## Checking out: with a card nothing more; with only a single ticket the gate keeps it.
## "kaart", "kaartje" or "geen". `apply` false: only what it would be.
static func check_out(player: Node, apply := true) -> String:
	if has_card(player):
		return "kaart"
	if has_ticket(player):
		if apply:
			player.call("drop_item", TICKET_ITEM)
		return "kaartje"
	return "geen"


static func _count(player: Node, item_id: String) -> int:
	if player == null or player.get("inventory") == null:
		return 0
	return int((player.get("inventory") as Dictionary).get(item_id, 0))


## What a reader shows when it says no (check_in / check_out gave "saldo" or "geen").
static func refusal(result: String) -> String:
	return "Saldo te laag (€ %s nodig)" % ("%.2f" % RIDE_FARE).replace(".", ",") if result == "saldo" else "Geen OV-chipkaart"
