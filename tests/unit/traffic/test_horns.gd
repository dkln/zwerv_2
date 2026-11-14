extends RefCounted
## Unit tests of the horn of each kind of vehicle (Vehicle._horn, scripts/vehicles/*.gd):
## what it warns someone in its way with, and that the sound is there.

## Vehicle script (scripts/vehicles/<name>.gd) -> the sound it warns with.
const HORNS := {"cyclist": "fiets_bel", "fatbike": "fiets_bel", "moped": "brommer_toeter", "city_bus": "bus_toeter",
	"hatchback": "auto_toeter", "truck": "bus_toeter", "fire_engine": "brandweer_hoorn", "randstadrail": "tram_bel"}


## Each kind has its own horn: a bell on a bicycle and a tram, a hooter on a car, a bus and
## a moped, the horn of the fire engine.
func test_each_kind_has_its_own_horn(test) -> void:
	for script_name: String in HORNS:
		var vehicle: Vehicle = load("res://scripts/vehicles/%s.gd" % script_name).new()
		var horn := vehicle._horn()
		test.check(horn == HORNS[script_name], "%s waarschuwt met %s (%s)" % [script_name, HORNS[script_name], horn])
		vehicle.free()


## The sound of every horn exists in assets/audio/geluiden.
func test_the_sound_of_every_horn_exists(test) -> void:
	for script_name: String in HORNS:
		var horn: String = HORNS[script_name]
		test.check(ResourceLoader.exists((load("res://scripts/audio/sound_files.gd") as GDScript).call("path_of", horn)), "geluid %s bestaat" % horn)
