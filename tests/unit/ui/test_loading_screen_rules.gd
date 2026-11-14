extends RefCounted
## Unit tests of the logic of the loading screen (scripts/ui/screens/loading_screen_rules.gd):
## the line with what is loading, the percentage and the setting it takes of the HUD.
##   tests/run_unit_tests.sh loading_screen_rules

const LoadingScreenRules = preload("res://scripts/ui/screens/loading_screen_rules.gd")


func test_heading(test) -> void:
	test.check(LoadingScreenRules.heading("Stad laden…") == "— STAD LADEN —", "in hoofdletters, zonder puntjes, tussen streepjes")
	test.check(LoadingScreenRules.heading("Wijk laden") == "— WIJK LADEN —", "zonder puntjes: ook goed")
	test.check(LoadingScreenRules.heading("") == "—  —", "leeg: alleen de streepjes")
	test.check(LoadingScreenRules.heading("Eén… twee…") == "— EÉN… TWEE —", "alleen de puntjes aan het eind gaan weg")
	test.check(LoadingScreenRules.TITLE == "ZWERVR", "de titel erboven")


func test_percentage_text(test) -> void:
	test.check(LoadingScreenRules.percentage_text(0.0) == "0%", "nog niets")
	test.check(LoadingScreenRules.percentage_text(0.5) == "50%", "halverwege")
	test.check(LoadingScreenRules.percentage_text(0.999) == "99%", "naar beneden afgerond: pas 100% als het af is")
	test.check(LoadingScreenRules.percentage_text(1.0) == "100%", "af")
	test.check(LoadingScreenRules.percentage_text(0.009) == "0%", "minder dan een procent: 0%")


func test_setting(test) -> void:
	test.check(LoadingScreenRules.setting(null, 0.05) == 0.05, "zonder HUD of zonder die instelling: de gewone")
	test.check(LoadingScreenRules.setting(0.2, 0.05) == 0.2, "met een instelling: die")
	test.check(LoadingScreenRules.setting(0.0, 0.05) == 0.0, "nul is ook een instelling")
	test.check(LoadingScreenRules.setting(1, 0.05) == 1.0, "een heel getal wordt een kommagetal")
