extends RefCounted
## Unit tests of Traffic.maniac_chances (scripts/traffic/traffic.gd): how often a car comes
## with an idiot at the wheel. Aggressive drivers go with how busy the roads are (the rush
## hours most), drunk ones come at night.

const TrafficScript = preload("res://scripts/traffic/traffic.gd")


## Aggressive drivers come far more often in the rush hours (about 5%) than otherwise,
## and hardly at night.
func test_the_rush_hours_make_people_angry(test) -> void:
	var traffic: Node = TrafficScript.new()
	var rush: Vector2 = traffic.maniac_chances(17.0)
	var midday: Vector2 = traffic.maniac_chances(12.5)
	var night: Vector2 = traffic.maniac_chances(3.5)
	test.check(rush.y > midday.y * 3.0, "in de spits veel meer agressieve bestuurders (%.3f tegen %.3f)" % [rush.y, midday.y])
	test.check(rush.y > 0.04 and rush.y < 0.07, "in de spits zo'n 5%% (%.3f)" % rush.y)
	test.check(night.y < 0.002, "'s nachts haast geen (%.4f)" % night.y)
	traffic.free()


## Drunk drivers come far more often at night, and never with maniac_chance 0.
func test_drunk_at_night(test) -> void:
	var traffic: Node = TrafficScript.new()
	test.check(traffic.maniac_chances(23.0).x > traffic.maniac_chances(12.5).x * 5.0, "'s nachts veel meer dronken bestuurders")
	traffic.maniac_chance = 0.0
	test.check(traffic.maniac_chances(17.0) == Vector2.ZERO, "maniac_chance 0: nooit")
	traffic.free()
