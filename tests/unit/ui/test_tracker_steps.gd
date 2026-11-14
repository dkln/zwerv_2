extends RefCounted
## Unit tests of the steps the quest tracker shows (scripts/ui/hud.gd GameHud.tracker_steps): only
## the last one done and the one open now, not the locked ones still to come nor the older ones done.

const Hud = preload("res://scripts/ui/hud.gd")


func test_only_the_last_done_and_the_open_one(test) -> void:
	var quest := {"steps": [{"text": "a", "done": true}, {"text": "b", "done": true}, {"text": "c", "done": false},
		{"text": "d", "done": false, "locked": true}, {"text": "e", "done": false, "locked": true}]}
	var shown: Array = Hud.tracker_steps(quest).map(func(step: Dictionary) -> String: return step.text)
	test.check(shown == ["b", "c"], "de laatste afgeronde en de open taak (%s)" % [shown])
	var at_start := {"steps": [{"text": "a", "done": false}, {"text": "b", "done": false, "locked": true}]}
	shown = Hud.tracker_steps(at_start).map(func(step: Dictionary) -> String: return step.text)
	test.check(shown == ["a"], "aan het begin alleen de eerste (%s)" % [shown])
	var optional_first := {"steps": [{"text": "x", "done": false, "optional": true}, {"text": "y", "done": false}]}
	shown = Hud.tracker_steps(optional_first).map(func(step: Dictionary) -> String: return step.text)
	test.check(shown == ["y"], "een optionele niet als er een gewone open is (%s)" % [shown])
