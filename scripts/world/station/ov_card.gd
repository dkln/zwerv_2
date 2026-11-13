extends RefCounted
## The OV-chipkaart and its balance, and the single ticket (Items "ov_chipkaart",
## "los_kaartje"): bought at an OV-chipkaart machine (scripts/ui/machines/
## ov_machine_screen.gd: in the hall of Den Haag Centraal), used at the gates of the
## station (scripts/world/station/station_gates.gd) and the OV posts (tap: in the station and
## at the tram stops, scripts/world/things/street_machines.gd). The balance is kept on the
## player (metadata BALANCE_META). A new card costs CARD_PRICE and has START_BALANCE on it;
## checking in with it costs RIDE_FARE of the balance (too little: the gate says no);
## checking in with a single ticket is free, checking out with it the gate keeps it.
## A trip: checking in sets CHECKED_IN_META on the player (and with what: CHECKED_IN_WITH_META,
## "kaart" or "kaartje"), checking out clears it. Not checking out (leaving the station still
## checked in: leave_open_trip) costs, as in the Netherlands, the boarding fare: with a card
## the next check-in keeps the rest of BOARDING_FARE (MISSED_CHECK_OUT_META until then; the
## balance may go below zero, then the gates say no until it is topped up); a single ticket
## is used up. Checking in again while still checked in with the card costs the same.
##   const OvCard = preload("res://scripts/world/station/ov_card.gd")
##   OvCard.buy_card(player)     # "ok", "geld", "vol" or "heb_al"
##   OvCard.top_up(player, 10.0)
##   OvCard.check_in(player)     # "kaart", "kaartje", "saldo" (too little) or "geen"
##   OvCard.refusal("saldo")     # what the reader says when it says no
##   OvCard.leave_open_trip(player)  # out of the station still checked in (boarding fare)

const CARD_ITEM := "ov_chipkaart"
const TICKET_ITEM := "los_kaartje"
const BALANCE_META := "ov_saldo"
const CARD_PRICE := 7.5
const START_BALANCE := 2.5
const RIDE_FARE := 1.0
const TICKET_PRICE := 3.5
const TOP_UPS := [5.0, 10.0, 20.0]
## The boarding fare (instaptarief): what a trip with the card costs when you do not check out.
const BOARDING_FARE := 4.0
const CHECKED_IN_META := "ov_ingecheckt"
const CHECKED_IN_WITH_META := "ov_ingecheckt_met"
const MISSED_CHECK_OUT_META := "ov_niet_uitgecheckt"


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
## A trip not checked out with the card is charged first (missed_check_out_charge).
static func check_in(player: Node, apply := true) -> String:
	var owed := missed_check_out_charge(player)
	if has_card(player) and balance(player) - owed + 0.001 >= RIDE_FARE:
		if apply:
			player.set_meta(BALANCE_META, snappedf(balance(player) - owed - RIDE_FARE, 0.01))
			player.remove_meta(MISSED_CHECK_OUT_META)
			_start_trip(player, "kaart")
		return "kaart"
	if has_ticket(player):
		if apply:
			_start_trip(player, "kaartje")
		return "kaartje"
	return "saldo" if has_card(player) else "geen"


## Checking out: with a card nothing more; with only a single ticket the gate keeps it.
## "kaart", "kaartje" or "geen". `apply` false: only what it would be.
static func check_out(player: Node, apply := true) -> String:
	if has_card(player):
		if apply:
			_end_trip(player)
		return "kaart"
	if has_ticket(player):
		if apply:
			player.call("drop_item", TICKET_ITEM)
			_end_trip(player)
		return "kaartje"
	return "geen"


## Holding the card to an OV post (in the station, at a tram or bus stop): checks out when
## checked in, else checks in (a trip not checked out keeps the boarding fare). Returns
## {"ok", "text" (what the post shows), "sound" (ov_inchecken, ov_uitchecken, ov_geweigerd)}.
static func tap(player: Node) -> Dictionary:
	var checked_in := is_checked_in(player)
	var charge := 0.0 if checked_in or check_in(player, false) != "kaart" else missed_check_out_charge(player)
	var ticket := check_out(player) if checked_in else check_in(player)
	if ticket == "saldo" or ticket == "geen":
		return {"ok": false, "text": refusal(ticket, player), "sound": "ov_geweigerd", "charge": 0.0}
	return {"ok": true, "text": "Uitgecheckt" if checked_in else check_in_text(charge),
		"sound": "ov_uitchecken" if checked_in else "ov_inchecken", "charge": charge}


## What an OV post offers the player: "Uitchecken" when checked in, else "Inchecken".
static func post_action(player: Node) -> String:
	return "Uitchecken" if is_checked_in(player) else "Inchecken"


## Whether the player is checked in (a trip not checked out yet).
static func is_checked_in(player: Node) -> bool:
	return player != null and bool(player.get_meta(CHECKED_IN_META, false))


## What the next check-in with the card keeps for a trip not checked out: the rest of
## BOARDING_FARE (RIDE_FARE was paid checking in), for a trip left open (MISSED_CHECK_OUT_META)
## or one still open with the card; 0 when there is none.
static func missed_check_out_charge(player: Node) -> float:
	if player == null or not has_card(player):
		return 0.0
	var open_with_card := is_checked_in(player) and String(player.get_meta(CHECKED_IN_WITH_META, "kaart")) == "kaart"
	if bool(player.get_meta(MISSED_CHECK_OUT_META, false)) or open_with_card:
		return BOARDING_FARE - RIDE_FARE
	return 0.0


## The player leaves the station still checked in: with the card the boarding fare is owed
## (kept at the next check-in); a single ticket is used up. Returns "kaart", "kaartje" or ""
## (not checked in).
static func leave_open_trip(player: Node) -> String:
	if not is_checked_in(player):
		return ""
	var paid_with := String(player.get_meta(CHECKED_IN_WITH_META, "kaart"))
	_end_trip(player)
	if paid_with == "kaartje":
		if has_ticket(player):
			player.call("drop_item", TICKET_ITEM)
		return "kaartje"
	player.set_meta(MISSED_CHECK_OUT_META, true)
	return "kaart"


## What a reader shows after a check-in that kept `charge` (missed_check_out_charge before it).
static func check_in_text(charge: float) -> String:
	if charge <= 0.0:
		return "Ingecheckt"
	return "Niet uitgecheckt: %s ingehouden" % euros(charge)


static func euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")


static func _start_trip(player: Node, paid_with: String) -> void:
	player.set_meta(CHECKED_IN_META, true)
	player.set_meta(CHECKED_IN_WITH_META, paid_with)


static func _end_trip(player: Node) -> void:
	player.set_meta(CHECKED_IN_META, false)
	if player.has_meta(CHECKED_IN_WITH_META):
		player.remove_meta(CHECKED_IN_WITH_META)


static func _count(player: Node, item_id: String) -> int:
	if player == null or player.get("inventory") == null:
		return 0
	return int((player.get("inventory") as Dictionary).get(item_id, 0))


## What a reader shows when it says no (check_in / check_out gave "saldo" or "geen"); with
## `player` what is needed counts a trip not checked out (missed_check_out_charge).
static func refusal(result: String, player: Node = null) -> String:
	if result != "saldo":
		return "Geen OV-chipkaart"
	return "Saldo te laag (%s nodig)" % euros(RIDE_FARE + missed_check_out_charge(player))
