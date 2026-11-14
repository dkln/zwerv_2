extends RefCounted
## Unit tests of scripts/ui/widgets/bank_logo.gd on its own: the logo of a bank on a cash
## machine (what its drawing depends on: sizes, shapes, flags, clocks).
##   tests/run_unit_tests.sh bank_logo

const BankLogo = preload("res://scripts/ui/widgets/bank_logo.gd")
const Banks = preload("res://scripts/world/things/banks.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")


func test_bank_logo_shows_a_bank(test) -> void:
	var logo := BankLogo.new()
	test.check(logo.bank_id == "" and logo.custom_minimum_size == Vector2.ZERO, "eerst geen bank")
	test.check(logo.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	logo.show_bank("og_bank", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	var rows: Array = Banks.bank("og_bank").emblem
	test.check(logo.bank_id == "og_bank", "de bank onthouden")
	test.check(logo.custom_minimum_size == Vector2(0.0, rows.size() * BankLogo.PIXEL + 4.0), "zo hoog als het embleem (%s)" % logo.custom_minimum_size)
	test.check(logo.custom_minimum_size.y >= BankLogo.NAME_SIZE + 4.0, "nooit lager dan de naam")
	logo.free()


func test_bank_logo_of_an_unknown_bank_is_the_first_bank(test) -> void:
	var logo := BankLogo.new()
	logo.show_bank("bestaat_niet", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	var first_rows: Array = Banks.bank(Banks.ORDER[0]).emblem
	test.check(logo.bank_id == "bestaat_niet", "het gevraagde id blijft staan")
	test.check(logo.custom_minimum_size.y == maxf(first_rows.size() * BankLogo.PIXEL, float(BankLogo.NAME_SIZE)) + 4.0, "met het embleem van de eerste bank")
	logo.free()
