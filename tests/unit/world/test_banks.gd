extends RefCounted
## Unit tests of the banks of the cash machines (scripts/world/things/banks.gd): every machine
## has one of them, always the same for its place, and the town's machines are spread over
## them; every bank has a name and an emblem whose rows are equally long.

const Banks = preload("res://scripts/world/things/banks.gd")


func test_a_machine_keeps_its_bank(test) -> void:
	var at := Vector3(123.4, 0.0, -56.7)
	test.check(Banks.bank_for(at) == Banks.bank_for(at), "dezelfde plek: dezelfde bank")
	test.check(Banks.bank_for(at) in Banks.ORDER, "een bestaande bank (%s)" % Banks.bank_for(at))
	var seen := {}
	for index in 60:
		seen[Banks.bank_for(Vector3(index * 7.0, 0.0, index * 13.0))] = true
	test.check(seen.size() == Banks.ORDER.size(), "verspreid over alle banken (%d)" % seen.size())


func test_every_bank_has_a_logo(test) -> void:
	for id: String in Banks.ORDER:
		var bank := Banks.bank(id)
		var rows: Array = bank.emblem
		var even := rows.all(func(row: String) -> bool: return row.length() == (rows[0] as String).length())
		test.check(String(bank.name) != "" and rows.size() > 3 and even, "%s: naam en embleem" % id)
	test.check(Banks.bank("bestaat_niet") == Banks.bank(Banks.ORDER[0]), "onbekend: de eerste bank")
