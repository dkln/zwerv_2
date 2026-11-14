extends RefCounted
## Unit tests of the wipe between two pictures (scripts/ui/swipe_transition.gd, the
## behaviour): what swipe() puts over everything, one wipe for two calls before it has
## covered, a new one after. (The wipe itself runs over frames: `covered`, the hold and
## `finished` are for the integration tests.) Its logic and look:
## test_swipe_transition_rules.gd, test_swipe_transition_view.gd.
##   tests/run_unit_tests.sh swipe_transition

const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func test_swipe_puts_a_still_over_everything(test) -> void:
	var swipe := SwipeTransition.swipe(tree)
	test.check(swipe != null and swipe.get_parent() == tree.root, "een laag onder de root")
	test.check(swipe.name == SwipeTransition.NODE_NAME and swipe.layer == SwipeTransition.LAYER, "boven alles (laag %d)" % swipe.layer)
	test.check(swipe.process_mode == Node.PROCESS_MODE_ALWAYS, "het loopt door als het spel stilstaat")
	test.check(not swipe.has_covered, "nog niet bedekt")
	test.check(not swipe.hold_until.is_valid() and swipe.max_hold_seconds == SwipeTransition.MAX_HOLD_SECONDS, "zonder iets om op te wachten")
	var still := swipe.get_child(0) as TextureRect
	test.check(still != null and still.mouse_filter == Control.MOUSE_FILTER_STOP, "het stilstaande beeld houdt klikken tegen")
	test.check(still.material is ShaderMaterial and (still.material as ShaderMaterial).shader.code == SwipeTransition.SHADER, "met de shader die het wegveegt")
	swipe.free()


func test_two_calls_before_it_covered_are_one_wipe(test) -> void:
	var first := SwipeTransition.swipe(tree)
	var second := SwipeTransition.swipe(tree)
	test.check(second == first, "twee keer vragen: dezelfde veeg")
	var layers := tree.root.get_children().filter(func(child: Node) -> bool: return child is CanvasLayer and child.get_script() == SwipeTransition)
	test.check(layers.size() == 1, "er is er maar één (%d)" % layers.size())
	first.free()


func test_a_wipe_that_covered_makes_way_for_a_new_one(test) -> void:
	var first := SwipeTransition.swipe(tree)
	first.has_covered = true
	var second := SwipeTransition.swipe(tree)
	test.check(second != first and not second.has_covered, "na het bedekken: een nieuwe veeg")
	test.check(second.name == SwipeTransition.NODE_NAME and first.name != SwipeTransition.NODE_NAME, "die nu de veeg is (de oude heet %s)" % first.name)
	test.check(SwipeTransition.swipe(tree) == second, "en die krijg je bij een volgende vraag")
	first.free()
	second.free()


func test_the_edge_goes_to_the_view(test) -> void:
	var swipe := SwipeTransition.swipe(tree)
	var material := (swipe.get_child(0) as TextureRect).material as ShaderMaterial
	test.check(swipe.edge() == 0.0, "eerst het hele stilstaande beeld")
	swipe._set_edge(0.4)
	test.check(is_equal_approx(material.get_shader_parameter("edge"), 0.4) and is_equal_approx(swipe.edge(), 0.4), "de rand staat waar hij gezet is")
	swipe.free()


func test_the_numbers_are_those_of_the_layers(test) -> void:
	test.check(SwipeTransition.MAX_HOLD_SECONDS == 5.0 and SwipeTransition.SETTLE_FRAMES == 3, "wachten zoals de logica zegt")
	test.check(is_equal_approx(SwipeTransition.WIPE_SECONDS, 1.1), "vegen zoals het beeld zegt")
