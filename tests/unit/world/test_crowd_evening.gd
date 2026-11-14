extends RefCounted
## Unit tests of the evening of an area (scripts/world/people/crowd.gd, data/drukte.json "avond"):
## the Plein and the Grote Markt fill up with the night's crowd in the evening and at night,
## not in the daytime.

const Crowd = preload("res://scripts/world/people/crowd.gd")


func test_the_plein_and_the_grote_markt_fill_up_at_night(test) -> void:
	for area: String in ["Plein", "Grote Markt"]:
		var day := Crowd.pedestrian_share(14.0, area)
		var night := Crowd.pedestrian_share(23.0, area)
		var late := Crowd.pedestrian_share(1.0, area)
		test.check(night > Crowd.pedestrian_share(23.0, "Lange Voorhout") * 1.5, "%s 's avonds drukker dan elders (%.2f)" % [area, night])
		test.check(late > Crowd.pedestrian_share(1.0, "Lange Voorhout") * 1.5, "%s ook na middernacht (%.2f)" % [area, late])
		test.check(Crowd._evening(area, 14.0).is_empty(), "%s overdag gewoon (%.2f)" % [area, day])
		var random := RandomNumberGenerator.new()
		random.seed = 7
		var night_out := 0
		for draw in 400:
			if Crowd.person_kind(23.0, area, random) in ["nachtbraker", "uitgaanspubliek"]:
				night_out += 1
		test.check(night_out > 300, "%s: 's avonds vooral uitgaanspubliek en nachtbrakers (%d van 400)" % [area, night_out])
