extends "res://tests/integration/support/town_test.gd"
## The street lights (scripts/world/town/street_lights.gd): the city has its lamps found, at night
## the ones nearest the view burn (at most MAX_LIGHTS, all within reach), by day none.
##   tests/run_integration_tests.sh street_lights

## Where the view is held (a street with lamps) and how many metres are in view.
const VIEW_FOCUS := Vector3(160.0, 0.0, 250.0)
const VIEW_SIZE := 40.0


## The clock stopped at `hour` for this test and the view held on VIEW_FOCUS, `wait_frames`
## frames on so the lights have followed; returns the street lights.
func _lights_at(hour: float, wait_frames: int) -> Node:
	var day_cycle: Node = scene.get_node("Dagcyclus")
	set_for_test(day_cycle, "time_of_day", day_cycle.time_of_day)
	set_for_test(day_cycle, "speed", 0.0)
	hold_view(VIEW_FOCUS, VIEW_SIZE)
	day_cycle.set_time(hour)
	await frames(wait_frames)
	return scene.get_node_or_null("Straatverlichting")


## The day cycle made the street lights, and they found every lamp head of the town.
func test_every_lamp_is_found(test) -> void:
	var street_lights: Node = scene.get_node_or_null("Straatverlichting")
	test.check(street_lights != null, "straatverlichting gemaakt")
	if street_lights == null:
		return
	print("lantaarnkoppen: ", street_lights.lamp_count())
	test.check(street_lights.lamp_count() > 800, "alle lantaarns gevonden")


## At one in the night the lamps in view burn, never more than MAX_LIGHTS.
func test_at_night_the_lamps_in_view_burn(test) -> void:
	var street_lights := await _lights_at(1.0, 40)
	test.check(street_lights != null, "straatverlichting gemaakt")
	if street_lights == null:
		return
	var lit: int = street_lights.lit_count()
	print("'s nachts aan: ", lit)
	test.check(lit > 0 and lit <= street_lights.MAX_LIGHTS, "'s nachts branden de lampen in beeld")


## After a night, by day (13:00) none burn.
func test_by_day_all_are_off(test) -> void:
	var street_lights := await _lights_at(1.0, 40)
	test.check(street_lights != null, "straatverlichting gemaakt")
	if street_lights == null:
		return
	scene.get_node("Dagcyclus").set_time(13.0)
	await frames(5)
	test.check(street_lights.lit_count() == 0, "overdag uit")
