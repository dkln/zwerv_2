extends RefCounted
## Unit tests of the statiegeld (scripts/world/things/deposit_return.gd): what the machine
## takes, what it is worth, putting one in and cashing the bon.
##   tests/run_unit_tests.sh deposit_return

const DepositReturn = preload("res://scripts/world/things/deposit_return.gd")


## Someone with pockets and a wallet.
class Carrier extends Node:
	signal deposited(amount: float)
	var inventory := {}
	var money := 0.0

	func drop_item(item_id: String) -> void:
		inventory[item_id] = int(inventory.get(item_id, 0)) - 1

	func add_money(amount: float) -> void:
		money += amount


func test_returnable_keeps_the_order_of_the_machine(test) -> void:
	var found := DepositReturn.returnable({"statiegeld": 2, "kroket": 1, "blikje": 3})
	test.check(found == {"blikje": 3, "statiegeld": 2} and found.keys() == ["blikje", "statiegeld"], "blikjes en flessen, in de volgorde van de automaat (%s)" % str(found))
	test.check(DepositReturn.returnable({"kroket": 4}).is_empty(), "een kroket neemt hij niet")
	test.check(DepositReturn.returnable({"blikje": 0}).is_empty(), "nul blikjes: niets")
	test.check(DepositReturn.returnable({}).is_empty(), "lege zakken: niets")


func test_total_value(test) -> void:
	test.check(is_equal_approx(DepositReturn.total_value({"blikje": 3, "statiegeld": 2}), 1.5), "drie blikjes en twee flessen: € 1,50")
	test.check(DepositReturn.total_value({}) == 0.0 and DepositReturn.total_value({"kroket": 9}) == 0.0, "niets in te leveren: niets")
	test.check(is_equal_approx(DepositReturn.total_value({"statiegeld": 7}), 1.05), "afgerond op centen")


func test_insert_one_takes_it_out_of_the_pockets(test) -> void:
	var carrier := Carrier.new()
	carrier.inventory = {"blikje": 2}
	test.check(is_equal_approx(DepositReturn.insert_one(carrier, "blikje"), 0.4) and carrier.inventory.blikje == 1, "een blikje erin: 40 cent, één minder in de zakken")
	test.check(DepositReturn.insert_one(carrier, "statiegeld") == 0.0, "geen fles bij je: niets")
	test.check(DepositReturn.insert_one(carrier, "kroket") == 0.0, "wat hij niet neemt: niets")
	test.check(DepositReturn.insert_one(null, "blikje") == 0.0, "niemand: niets")
	carrier.free()


func test_pay_out_puts_the_bon_in_the_wallet(test) -> void:
	var carrier := Carrier.new()
	var heard := []
	carrier.deposited.connect(func(amount: float) -> void: heard.append(amount))
	DepositReturn.pay_out(carrier, 0.755)
	test.check(is_equal_approx(carrier.money, 0.76) and heard.size() == 1 and is_equal_approx(heard[0], 0.76), "de bon uitbetaald, afgerond, met het signaal (%s)" % carrier.money)
	DepositReturn.pay_out(carrier, 0.0)
	DepositReturn.pay_out(null, 1.0)
	test.check(is_equal_approx(carrier.money, 0.76) and heard.size() == 1, "een lege bon of niemand: niets")
	carrier.free()
