extends RefCounted
## Unit tests of the logic of what drifts through the intro (scripts/ui/intro/drifter_rules.gd):
## what drifts next, when one may set off, and the flight it makes.
##   tests/run_unit_tests.sh drifter_rules

const DrifterRules = preload("res://scripts/ui/intro/drifter_rules.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

const SCREEN := Vector2(1280, 720)
const LARGEST := 190.0


static func _random(seed_value: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return random


func test_what_drifts_by_is_never_twice_the_same(test) -> void:
	var random := _random(1992)
	var last := ""
	var characters := 0
	var tractors := 0
	var repeated := false
	var unknown := false
	for flight in 400:
		var picked := DrifterRules.pick_drifter(random, last)
		repeated = repeated or picked == last
		if picked in PlayerCharacter.ORDER:
			characters += 1
		elif picked in DrifterRules.TRACTOR_MODELS:
			tractors += 1
		else:
			unknown = true
		last = picked
	test.check(not repeated, "nooit twee keer achter elkaar dezelfde")
	test.check(not unknown and characters > 0 and tractors > 0, "zwervers en trekkers (%d, %d)" % [characters, tractors])
	test.check(characters > tractors, "vaker een zwerver dan een trekker")
	test.check(DrifterRules.pick_drifter(_random(7), "jos") == DrifterRules.pick_drifter(_random(7), "jos"), "met hetzelfde toeval dezelfde keuze")


func test_is_character(test) -> void:
	test.check(DrifterRules.is_character(PlayerCharacter.ORDER[0]), "een zwerver van het spel")
	test.check(not DrifterRules.is_character("trekker") and not DrifterRules.is_character(""), "een trekker (of niets) niet")


func test_may_start(test) -> void:
	test.check(not DrifterRules.may_start(10.0, 20.0, 50.0), "voor zijn tijd: nog niet")
	test.check(DrifterRules.may_start(20.0, 20.0, 50.0) and DrifterRules.may_start(50.0, 20.0, 50.0), "vanaf zijn tijd tot en met het laatste moment")
	test.check(not DrifterRules.may_start(50.1, 20.0, 50.0), "vlak voor het eind van de intro niet meer")
	test.check(not DrifterRules.may_start(1000.0, INF, 5000.0), "nooit als er niets te zweven is")


func test_a_flight_crosses_the_screen(test) -> void:
	var sides := {}
	for seed_value in 40:
		var flight := DrifterRules.plan_flight(_random(seed_value), 30.0, SCREEN, LARGEST)
		var from: Vector2 = flight.from
		var to: Vector2 = flight.to
		var shown: float = flight.shown
		var from_left := from.x < to.x
		sides[from_left] = true
		test.check(shown >= LARGEST * DrifterRules.SHOWN_SHARE.x and shown <= LARGEST, "vlucht %d: tussen klein en de grootste maat" % seed_value)
		test.check(is_equal_approx(minf(from.x, to.x), -shown) and maxf(from.x, to.x) == SCREEN.x, "vlucht %d: van net buiten de ene rand tot net buiten de andere" % seed_value)
		var comes_in := from.y if from_left else to.y
		var goes_out := to.y if from_left else from.y
		test.check(comes_in >= SCREEN.y * DrifterRules.START_HEIGHT.x and comes_in <= SCREEN.y * DrifterRules.START_HEIGHT.y and goes_out >= 0.0 and goes_out <= SCREEN.y - shown + 0.01,
			"vlucht %d: binnen het beeld" % seed_value)
		test.check(float(flight.seconds) >= DrifterRules.SECONDS.x and float(flight.seconds) <= DrifterRules.SECONDS.y and flight.start == 30.0, "vlucht %d: zijn duur en begin" % seed_value)
		test.check((flight.axis as Vector3).is_normalized() and absf(flight.spin) >= deg_to_rad(DrifterRules.SPIN.x) and absf(flight.spin) <= deg_to_rad(DrifterRules.SPIN.y),
			"vlucht %d: tuimelt om een eigen as" % seed_value)
	test.check(sides.size() == 2, "van links en van rechts")
	test.check(DrifterRules.plan_flight(_random(3), 1.0, SCREEN, LARGEST) == DrifterRules.plan_flight(_random(3), 1.0, SCREEN, LARGEST), "met hetzelfde toeval dezelfde vlucht")


func test_along_the_flight(test) -> void:
	var flight := {"from": Vector2(-100, 200), "to": Vector2(1280, 300), "start": 10.0, "seconds": 20.0, "axis": Vector3.UP, "spin": 0.5}
	test.check(DrifterRules.flown(flight, 10.0) == 0.0 and is_equal_approx(DrifterRules.flown(flight, 20.0), 0.5) and DrifterRules.flown(flight, 31.0) > 1.0, "hoe ver hij is")
	test.check(DrifterRules.position_at(flight, 0.0) == Vector2(-100, 200) and DrifterRules.position_at(flight, 0.5).is_equal_approx(Vector2(590, 250)), "in een rechte lijn")
	test.check(DrifterRules.tumble(flight, 2.0).is_equal_approx(Basis(Vector3.UP, 1.0)) and DrifterRules.tumble(flight, 0.0).is_equal_approx(Basis.IDENTITY), "hij tuimelt om zijn as, zo snel als zijn draai")


func test_far_and_next(test) -> void:
	test.check(DrifterRules.far_share(190.0, 190.0) == 0.0 and is_equal_approx(DrifterRules.far_share(95.0, 190.0), 0.5), "kleiner is verder weg")
	var next := DrifterRules.next_start(_random(5), 100.0)
	test.check(next >= 100.0 + DrifterRules.EVERY.x and next <= 100.0 + DrifterRules.EVERY.y, "de volgende na een poos (%.1f)" % next)
