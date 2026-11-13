extends RefCounted
## Statiegeld: what the deposit machine in every supermarket (scripts/ui/machines/
## deposit_machine_screen.gd) takes and what each is worth: the cans from the waste bins
## (Items "blikje") and the bottles some carry ("statiegeld"), DEPOSIT euros each. Put in one
## by one; at the end the machine prints a bon for the total, and the bon is paid out at once.
##   const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")
##   DepositReturn.returnable(player.inventory)       # {"blikje": 3}
##   DepositReturn.insert_one(player, "blikje")       # 0.15 (the can gone from the pockets)
##   DepositReturn.pay_out(player, 0.45)

const DEPOSIT := {"blikje": 0.15, "statiegeld": 0.15}
## The order they are offered in the machine.
const ORDER := ["blikje", "statiegeld"]


## What in `inventory` (item id -> count) the machine takes: id -> count.
static func returnable(inventory: Dictionary) -> Dictionary:
	var found := {}
	for item_id: String in ORDER:
		var count := int(inventory.get(item_id, 0))
		if count > 0:
			found[item_id] = count
	return found


## How much everything returnable in `inventory` is worth.
static func total_value(inventory: Dictionary) -> float:
	var total := 0.0
	var found := returnable(inventory)
	for item_id: String in found:
		total += float(DEPOSIT[item_id]) * int(found[item_id])
	return snappedf(total, 0.01)


## Puts one `item_id` in the machine: gone from the player's pockets, its deposit as the
## result (0 if it has none of them or the machine does not take it).
static func insert_one(player: Node, item_id: String) -> float:
	if player == null or not DEPOSIT.has(item_id):
		return 0.0
	var inventory: Dictionary = player.get("inventory") if player.get("inventory") != null else {}
	if int(inventory.get(item_id, 0)) <= 0:
		return 0.0
	player.call("drop_item", item_id)
	return float(DEPOSIT[item_id])


## The bon cashed: the money in the wallet.
static func pay_out(player: Node, amount: float) -> void:
	if player and amount > 0.0 and player.has_method("add_money"):
		player.call("add_money", snappedf(amount, 0.01))
