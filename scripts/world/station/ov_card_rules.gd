extends RefCounted
## The fares and the answers of the OV-chipkaart and the single ticket (logic;
## docs/CODE_LAGEN.md): what a card and a ride cost, whether a reader lets someone in or out
## and with what, what a trip not checked out costs, and what a reader or a post writes.
## It knows no player: ov_card.gd (which keeps the card on the player) asks it with what the
## player has (a card, a ticket, the balance) and does what it answers.
##   const OvCardRules = preload("res://scripts/world/station/ov_card_rules.gd")

const MoneyText = preload("res://scripts/common/money_text.gd")
const CARD_PRICE := 7.5
const START_BALANCE := 2.5
const RIDE_FARE := 1.0
const TICKET_PRICE := 3.5
const TOP_UPS := [5.0, 10.0, 20.0]
## The boarding fare (instaptarief): what a trip with the card costs when you do not check out.
const BOARDING_FARE := 4.0
## What a trip was paid with (CHECKED_IN_WITH_META) and what a reader answers.
const WITH_CARD := "kaart"
const WITH_TICKET := "kaartje"
const TOO_LITTLE := "saldo"
const NOTHING := "geen"
## The sounds of a reader.
const SOUND_IN := "ov_inchecken"
const SOUND_OUT := "ov_uitchecken"
const SOUND_REFUSED := "ov_geweigerd"


## What a reader answers to a check-in: WITH_CARD (a card with RIDE_FARE on it after `owed`,
## the charge of a trip not checked out), else WITH_TICKET, else TOO_LITTLE (a card, too
## little on it) or NOTHING.
static func check_in_result(has_card: bool, has_ticket: bool, balance: float, owed: float) -> String:
	if has_card and balance - owed + 0.001 >= RIDE_FARE:
		return WITH_CARD
	if has_ticket:
		return WITH_TICKET
	return TOO_LITTLE if has_card else NOTHING


## The balance after a check-in with the card that also kept `owed`.
static func balance_after_check_in(balance: float, owed: float) -> float:
	return snappedf(balance - owed - RIDE_FARE, 0.01)


## What a reader answers to a check-out: WITH_CARD, WITH_TICKET (it keeps the ticket) or NOTHING.
static func check_out_result(has_card: bool, has_ticket: bool) -> String:
	if has_card:
		return WITH_CARD
	return WITH_TICKET if has_ticket else NOTHING


## Whether a reader said no (TOO_LITTLE or NOTHING).
static func is_refused(result: String) -> bool:
	return result == TOO_LITTLE or result == NOTHING


## What the next check-in with the card keeps for a trip not checked out: the rest of
## BOARDING_FARE (RIDE_FARE was paid checking in), for a trip left open (`missed`) or one
## still open with the card; 0 without a card or when there is none.
static func missed_check_out_charge(has_card: bool, missed: bool, open_with_card: bool) -> float:
	if has_card and (missed or open_with_card):
		return BOARDING_FARE - RIDE_FARE
	return 0.0


## Whether `money` in the wallet is enough to put `amount` on the card.
static func can_top_up(money: float, amount: float) -> bool:
	return money + 0.001 >= amount


## The balance after putting `amount` on the card.
static func balance_after_top_up(balance: float, amount: float) -> float:
	return snappedf(balance + amount, 0.01)


## What an OV post offers: "Uitchecken" when checked in, else "Inchecken".
static func post_action(checked_in: bool) -> String:
	return "Uitchecken" if checked_in else "Inchecken"


## What a reader shows after a check-in that kept `charge` (missed_check_out_charge before it).
static func check_in_text(charge: float) -> String:
	if charge <= 0.0:
		return "Ingecheckt"
	return "Niet uitgecheckt: %s ingehouden" % MoneyText.euros(charge)


## What a reader shows when it says no (`result` TOO_LITTLE or NOTHING); what is needed
## counts `owed`, the charge of a trip not checked out.
static func refusal(result: String, owed := 0.0) -> String:
	if result != TOO_LITTLE:
		return "Geen OV-chipkaart"
	return "Saldo te laag (%s nodig)" % MoneyText.euros(RIDE_FARE + owed)


## What an OV post answers to a card held to it: {"ok", "text", "sound", "charge"}.
## `was_checked_in`: it checked out (else in); `result` what the reader answered; `charge`
## what the check-in kept; `owed` what a refusal counts on top of the fare.
static func tap_result(was_checked_in: bool, result: String, charge: float, owed: float) -> Dictionary:
	if is_refused(result):
		return {"ok": false, "text": refusal(result, owed), "sound": SOUND_REFUSED, "charge": 0.0}
	return {"ok": true, "text": "Uitgecheckt" if was_checked_in else check_in_text(charge),
		"sound": SOUND_OUT if was_checked_in else SOUND_IN, "charge": charge}
