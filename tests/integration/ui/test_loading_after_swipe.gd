extends "res://tests/integration/support/town_test.gd"
## Into the town under the swipe of a scene change (scripts/world/town/level_of_detail.gd): while the
## swipe (SwipeTransition) still runs, the loading screen is already up (its waiting music
## playing) and nothing heavy is started, and it stays up (also when the interiors are ready
## under it); the merging starts once the swipe is through, under that same screen.
## A run of its own: it starts the whole town itself (with DetailNiveau and its merging
## threads, a swipe already in the tree before the town enters it).
##   tests/run_integration_tests.sh loading_after_swipe

const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")


static func world_options() -> Dictionary:
	return {"town": false, "own_process": true}


## The whole town (with DetailNiveau, no traffic) entering the tree while a swipe is still
## there: a stand-in for the swipe of the scene change (only its node, so it is not through
## yet). Returns {"swipe", "detail" (the DetailNiveau node)}.
func _enter_town_under_a_swipe() -> Dictionary:
	var swipe := CanvasLayer.new()
	swipe.name = SwipeTransition.NODE_NAME
	add_to_root(swipe)
	var town := Common.instantiate(Common.CITY, false)
	town.get_node("Verkeer").vehicle_count = 0
	add_to_root(town)
	# long enough for the interiors to be built and warmed up under the screen (Interiors
	# holds and then releases it): that must not close it while the swipe still runs
	await frames(40)
	return {"swipe": swipe, "detail": town.get_node("DetailNiveau")}


## While the swipe runs the loading screen stands and the heavy work waits; once the swipe
## is gone the merging starts, under that same one loading screen.
func test_loading_screen_stays_and_merging_waits_for_the_swipe(test) -> void:
	var entered := await _enter_town_under_a_swipe()
	var detail: Node = entered.detail
	test.check(LoadingScreenScript.showing(tree) and detail._screen != null, "het laadscherm staat er meteen en blijft staan")
	var first_screen: Node = detail._screen
	test.check(detail.is_merging(), "de stad telt als nog niet klaar")
	test.check(detail._busy == 0 and detail._pairs.is_empty(), "het zware werk wacht op de overgang")
	(entered.swipe as Node).queue_free()
	var frames_waited := 0
	while detail._pairs.is_empty() and frames_waited < 600:
		await tree.process_frame
		frames_waited += 1
	test.check(not detail._pairs.is_empty(), "na de overgang begint het samenvoegen (na %d frames)" % frames_waited)
	test.check(LoadingScreenScript.showing(tree) and detail._screen == first_screen
			and detail.get_children().filter(func(child: Node) -> bool: return child is LoadingScreenScript).size() == 1,
		"met hetzelfde ene laadscherm (niet dicht en weer open)")
