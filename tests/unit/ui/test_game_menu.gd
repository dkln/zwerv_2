extends RefCounted
## Unit tests of the game menu (scripts/ui/game_menu.gd): the cash machines as places of the map.
##   tests/run_unit_tests.sh game_menu

const GameMenu = preload("res://scripts/ui/game_menu.gd")


## GameMenu tells the cash machines among the places of the map: pinautomaat_3 is one
## and no supermarket, a supermarket is no cash machine.
func test_the_cash_machines_are_places_of_the_map(test) -> void:
	test.check(GameMenu.is_cash_machine("pinautomaat_3"), "pinautomaat_3 is een pinautomaat")
	test.check(not GameMenu.is_cash_machine("derrek_2") and GameMenu.supermarket_chain("pinautomaat_3") == "",
		"geen supermarkt, en een supermarkt geen pinautomaat")
