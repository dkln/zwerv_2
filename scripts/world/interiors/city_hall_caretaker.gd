extends Node
## The caretaker of the basement of the city hall going his round with his cleaning cart
## (behaviour, docs/CODE_LAGEN.md): to the next point of his round, standing still there a
## moment to mop, on to the next. The city hall (city_hall.gd) makes him with its people,
## hands him over (take) and moves him on while the player is down there (advance); he
## walks as the interior walks its people (`walker`: walk_evictor and evictor_stops, over
## the free floor). His pace and his pauses: city_hall_rules.gd.
##   const CityHallCaretaker = preload("res://scripts/world/interiors/city_hall_caretaker.gd")
##   var caretaker := CityHallCaretaker.new(self, random)
##   add_child(caretaker)

const CityHallRules = preload("res://scripts/world/interiors/city_hall_rules.gd")

## The caretaker himself (null before the basement was visited).
var person: Node3D
## The point of his round he walks to, and the seconds he still stands mopping.
var point := 1
var rest := 0.0

var _walker: Object
var _random: RandomNumberGenerator


## `walker`: who walks him (walk_evictor(person, target, speed, delta), evictor_stops(person));
## `random`: the generator his pauses are drawn from (the city hall's own).
func _init(walker: Object, random: RandomNumberGenerator) -> void:
	name = "Conciergeronde"
	_walker = walker
	_random = random


## `who` is the caretaker from now on.
func take(who: Node3D) -> void:
	person = who


## Whether he stands mopping now.
func is_mopping() -> bool:
	return rest > 0.0


## His round `delta` seconds on, along `round_points` (global): mopping, or walking to the
## next point, where he stops to mop.
func advance(delta: float, round_points: Array[Vector3]) -> void:
	if person == null or round_points.is_empty():
		return
	if rest > 0.0:
		rest -= delta
		if rest <= 0.0:
			point = CityHallRules.next_round_point(point, round_points.size())
		return
	var target := round_points[point]
	_walker.call("walk_evictor", person, target, CityHallRules.CARETAKER_PACE, delta)
	if CityHallRules.is_at_round_point(person.global_position, target):
		_walker.call("evictor_stops", person)
		rest = _random.randf_range(CityHallRules.CARETAKER_MOP.x, CityHallRules.CARETAKER_MOP.y)
