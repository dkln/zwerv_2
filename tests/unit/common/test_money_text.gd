extends RefCounted
## Unit tests of numbers and money as the Dutch write them (scripts/common/money_text.gd).
##   tests/run_unit_tests.sh common

const MoneyText = preload("res://scripts/common/money_text.gd")


func test_thousands_are_grouped_by_points(test) -> void:
	var cases := {0: "0", 7: "7", 999: "999", 1000: "1.000", 12345: "12.345", 1234567: "1.234.567", -1500: "-1.500"}
	for number: int in cases:
		test.check(MoneyText.thousands(number) == cases[number], "%d: %s (verwacht %s)" % [number, MoneyText.thousands(number), cases[number]])


func test_amount_has_cents_after_a_comma(test) -> void:
	var cases := {0.0: "0,00", 0.05: "0,05", 0.1: "0,10", 12.0: "12,00", 1284.5: "1.284,50", -3.5: "-3,50", -0.25: "-0,25", 0.999: "1,00"}
	for euros_amount: float in cases:
		test.check(MoneyText.amount(euros_amount) == cases[euros_amount], "%s: %s (verwacht %s)" % [euros_amount, MoneyText.amount(euros_amount), cases[euros_amount]])


func test_euros_has_the_sign_and_a_space(test) -> void:
	test.check(MoneyText.euros(0.5) == "€ 0,50", "een munt: € 0,50 (%s)" % MoneyText.euros(0.5))
	test.check(MoneyText.euros(7.5) == "€ 7,50", "een OV-kaart: € 7,50 (%s)" % MoneyText.euros(7.5))
	test.check(MoneyText.euros(2500.0) == "€ 2.500,00", "duizenden met een punt: € 2.500,00 (%s)" % MoneyText.euros(2500.0))
