extends RefCounted
## Unit tests of the shroud (scripts/story/shroud.gd, data/gebieden.json): the start circle,
## growing it, opening an area of wijken, and that outside the map (the interiors) nothing
## is shrouded.

const Shroud = preload("res://scripts/story/shroud.gd")


func _shroud() -> RefCounted:
	var root := Node.new()
	root.set_meta("places", {"centraal": Vector2(332, 256), "plein": Vector2(220, 168)})
	root.set_meta("wijken", [["Centrum", 0, 0, 71, 108], ["Centraal Station", 72, 61, 94, 77], ["Den Haag", 0, 0, 215, 175]])
	var shroud := Shroud.new()
	shroud.setup(root)
	root.free()
	return shroud


## At the start only the circle round Centraal is open.
func test_the_start_circle(test) -> void:
	var shroud := _shroud()
	test.check(shroud.is_open(332, 256), "de startplek is open")
	test.check(shroud.is_open(332 + shroud.start_radius - 1.0, 256), "binnen de cirkel open")
	test.check(not shroud.is_open(332 + shroud.start_radius + 5.0, 256), "erbuiten dicht")
	test.check(not shroud.is_open(100, 100), "het Centrum is dicht")


## The circle grows (never shrinks) and an area of wijken opens as a whole.
func test_growing_and_opening(test) -> void:
	var shroud := _shroud()
	test.check(shroud.set_start_radius(120.0), "groeit")
	test.check(not shroud.set_start_radius(60.0), "krimpt niet")
	test.check(shroud.is_open(332 - 110.0, 256), "verder weg nu open")
	test.check(shroud.open_area("centrum"), "het Centrum gaat open")
	test.check(shroud.is_open(100, 100), "het Centrum is open")
	test.check(not shroud.open_area("centrum"), "niet twee keer")


## Outside the map (the interiors, far off it) nothing is shrouded; open_everything opens all.
func test_off_the_map_and_everything(test) -> void:
	var shroud := _shroud()
	test.check(shroud.is_open(-1500, 900), "binnenruimtes buiten de kaart")
	shroud.open_everything()
	test.check(shroud.is_open(800, 600), "alles open")
