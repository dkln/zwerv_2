extends RefCounted
## Unit tests of the logic of the action prompts (scripts/ui/screens/action_prompts_rules.gd):
## whether a list changes anything, whether there is anything to show, the actions as texts.
##   tests/run_unit_tests.sh action_prompts_rules

const ActionPromptsRules = preload("res://scripts/ui/screens/action_prompts_rules.gd")


func test_changed(test) -> void:
	test.check(not ActionPromptsRules.changed([], []), "niets en weer niets: niets veranderd")
	test.check(ActionPromptsRules.changed([], [["E", "Praten"]]), "een eerste actie: veranderd")
	test.check(not ActionPromptsRules.changed([["E", "Praten"]], [["E", "Praten"]]), "dezelfde acties: niets veranderd")
	test.check(ActionPromptsRules.changed([["E", "Praten"]], [["E", "Naar binnen"]]), "een andere tekst: veranderd")
	test.check(ActionPromptsRules.changed([["E", "Praten"], ["F", "Eten"]], [["F", "Eten"], ["E", "Praten"]]), "een andere volgorde: veranderd")
	test.check(ActionPromptsRules.changed([["E", "Praten"]], []), "niets meer te doen: veranderd")


func test_shown(test) -> void:
	test.check(not ActionPromptsRules.shown([]), "niets te doen: verborgen")
	test.check(ActionPromptsRules.shown([["E", "Praten"]]), "iets te doen: te zien")


func test_texts(test) -> void:
	test.check(ActionPromptsRules.texts([]) == [], "geen acties: geen teksten")
	test.check(ActionPromptsRules.texts([["E", "Praten"], ["SPATIE", "Springen"]]) == [["E", "Praten"], ["SPATIE", "Springen"]], "teksten blijven, in dezelfde volgorde")
	test.check(ActionPromptsRules.texts([[1, 2.5]]) == [["1", "2.5"]], "wat geen tekst is wordt tekst")
	var given := [["E", "Praten"]]
	var made := ActionPromptsRules.texts(given)
	made[0][1] = "Anders"
	test.check(given[0][1] == "Praten", "de lijst van de aanroeper blijft zoals hij was")
