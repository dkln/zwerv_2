extends "res://tests/integration/support/town_test.gd"
## The night's crowd drunk (scripts/world/people/pedestrian.gd `drunk`, Crowd.drunkenness): who is
## very drunk weaves and sways, and near the player throws up now and then: a balloon, bent far
## over, the retch, and a puddle on the ground that stays a while.
##   tests/run_integration_tests.sh drunk

const Crowd = preload("res://scripts/world/people/crowd.gd")


func _someone_near_the_player() -> Pedestrian:
	var walkers: Pedestrians = scene.get_node("Voetgangers")
	var nearest: Pedestrian = null
	for person: Pedestrian in walkers.people():
		if person.aid == null and person.figure != null and (nearest == null
				or person.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position)):
			nearest = person
	return nearest


## Who is drunk: the night revellers late at night, not in the daytime, not the commuters.
func test_who_is_drunk(test) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 11
	var at_night := 0
	var in_the_day := 0
	for draw in 200:
		if Crowd.drunkenness("nachtbraker", 1.0, random) > 0.0:
			at_night += 1
		if Crowd.drunkenness("nachtbraker", 14.0, random) > 0.0 or Crowd.drunkenness("forens", 1.0, random) > 0.0:
			in_the_day += 1
	test.check(at_night > 120, "'s nachts zijn de meeste nachtbrakers dronken (%d van 200)" % at_night)
	test.check(in_the_day == 0, "overdag niemand, en forensen nooit")


## Very drunk, it throws up: bent over, and a puddle on the ground after it.
func test_throwing_up_leaves_a_puddle(test) -> void:
	await physics_frames(30)
	var drunk := _someone_near_the_player()
	test.check(drunk != null, "iemand in de buurt")
	if drunk == null:
		return
	drunk.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
	drunk.drunk = 1.0
	Pedestrian._last_throw_up = -1000.0
	var puddles_before := Pedestrian._puddles.size()
	drunk.throw_up()
	test.check(drunk.is_throwing_up(), "hij geeft over")
	await seconds(1.6)
	test.check(drunk._drawn.rotation.x > 0.4, "voorover gebogen (%.2f)" % drunk._drawn.rotation.x)
	await seconds(1.0)
	test.check(Pedestrian._puddles.size() == puddles_before + 1 or Pedestrian._puddles.size() == Pedestrian.PUDDLES_MOST,
		"een plas op de grond (%d)" % Pedestrian._puddles.size())
	var puddle: Node3D = Pedestrian._puddles.back() if not Pedestrian._puddles.is_empty() else null
	test.check(puddle != null and absf(puddle.global_position.y - drunk.global_position.y) < 0.6, "op de grond bij hem")
	await seconds(2.0)
	test.check(not drunk.is_throwing_up() and drunk._drawn.rotation.x < 0.5, "daarna loopt hij weer (%.2f)" % drunk._drawn.rotation.x)
	Pedestrian._last_throw_up = -1000.0
	drunk.drunk = 0.0
