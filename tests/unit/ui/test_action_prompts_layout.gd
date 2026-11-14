extends RefCounted
## Unit tests of the sizes of the action prompts (scripts/ui/screens/action_prompts_layout.gd):
## the gaps and how wide the key caps get.
##   tests/run_unit_tests.sh action_prompts_layout

const ActionPromptsLayout = preload("res://scripts/ui/screens/action_prompts_layout.gd")


func test_gaps_and_margins(test) -> void:
	test.check(ActionPromptsLayout.PANEL_GAP == 8 and ActionPromptsLayout.KEY_GAP == 10, "ruimte tussen de paneeltjes en na de toets")
	test.check(ActionPromptsLayout.PANEL_MARGIN_RIGHT > ActionPromptsLayout.PANEL_MARGIN_LEFT, "rechts van de tekst wat meer ruimte dan links van de toets")
	test.check(ActionPromptsLayout.KEY_SHADOW.x == 0.0 and ActionPromptsLayout.KEY_SHADOW.y > 0.0, "de schaduw van een toets valt recht omlaag")


func test_key_cap_width(test) -> void:
	test.check(ActionPromptsLayout.key_cap_width(40.0, 16.0) == 56.0, "de naam plus de randen")
	test.check(ActionPromptsLayout.key_cap_width(40.0, 0.0) == 40.0, "zonder randen: de naam")
	test.check(ActionPromptsLayout.key_cap_width(0.0, 16.0) == 16.0, "een lege naam: alleen de randen")


func test_widest(test) -> void:
	test.check(ActionPromptsLayout.widest([]) == 0.0, "geen toetsen: 0")
	test.check(ActionPromptsLayout.widest([24.0]) == 24.0, "een toets: die")
	test.check(ActionPromptsLayout.widest([24.0, 80.5, 30.0]) == 80.5, "de breedste van drie")
	test.check(ActionPromptsLayout.widest([50.0, 50.0]) == 50.0, "even breed: die breedte")


func test_needs_width(test) -> void:
	test.check(ActionPromptsLayout.needs_width(0.0, 56.0), "nog geen breedte: zetten")
	test.check(not ActionPromptsLayout.needs_width(56.0, 56.0), "al goed: laten")
	test.check(not ActionPromptsLayout.needs_width(56.3, 56.0), "een haar ernaast: laten (het komt tot rust)")
	test.check(not ActionPromptsLayout.needs_width(55.5, 56.0), "precies de speling: laten")
	test.check(ActionPromptsLayout.needs_width(80.0, 56.0), "te breed: smaller maken")
