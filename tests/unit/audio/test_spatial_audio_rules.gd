extends RefCounted
## Unit tests of the logic of the spatial sound of the city
## (scripts/audio/spatial_audio_rules.gd): the kinds and their sounds, the pitch and the
## level of an engine, the Doppler shift, distance, the picture, which vehicles get a sound,
## the yelp, passing by, the signals. The ear, the players and the buses:
## tests/unit/audio/test_spatial_audio.gd.
##   tests/run_unit_tests.sh spatial_audio

const Rules = preload("res://scripts/audio/spatial_audio_rules.gd")
const SoundFiles = preload("res://scripts/audio/sound_files.gd")


# ------------------------------------------------------------------ the ear and the picture

func test_bus_volume(test) -> void:
	test.check(Rules.bus_volume_db(false) == Rules.BUS_VOLUME_DB, "tijdens het spel: het gewone niveau")
	test.check(Rules.bus_volume_db(true) == Rules.BUS_VOLUME_DB + Rules.PAUSED_DB, "in de pauze zachter")
	test.check(Rules.bus_volume_db(true) < Rules.bus_volume_db(false), "de pauze is echt zachter")


func test_follow_weight(test) -> void:
	test.check(Rules.follow_weight(4.0, 0.0) == 0.0, "geen tijd: geen stap")
	test.check(is_equal_approx(Rules.follow_weight(4.0, 0.25), 1.0 - exp(-1.0)), "een kwart seconde op 4 per seconde")
	test.check(Rules.follow_weight(8.0, 0.1) > Rules.follow_weight(4.0, 0.1), "sneller volgen: een grotere stap")
	test.check(Rules.follow_weight(6.0, 100.0) <= 1.0 and Rules.follow_weight(6.0, 100.0) > 0.999, "na lange tijd: er helemaal")


func test_heading(test) -> void:
	test.check(Rules.heading(Vector3(0.0, -5.0, -1.0)).is_equal_approx(Vector3.FORWARD), "schuin omlaag kijken: alleen de richting")
	test.check(Rules.heading(Vector3(3.0, 2.0, 0.0)).is_equal_approx(Vector3.RIGHT), "naar rechts")
	test.check(Rules.heading(Vector3.DOWN) == Vector3.FORWARD, "recht omlaag: rechtdoor")
	test.check(Rules.heading(Vector3.ZERO) == Vector3.FORWARD, "geen richting: rechtdoor")
	var slanted := Rules.heading(Vector3(1.0, -8.0, 1.0))
	test.check(is_equal_approx(slanted.length(), 1.0) and slanted.y == 0.0, "altijd plat en van lengte 1")


func test_distance_db(test) -> void:
	test.check(Rules.distance_db(0.0) == 0.0 and Rules.distance_db(Rules.FULL_WITHIN) == 0.0, "dichtbij: op volle sterkte")
	test.check(is_equal_approx(Rules.distance_db(Rules.FULL_WITHIN + 10.0), -10.0 * Rules.DB_PER_METRE), "10 m verder: 2 dB zachter")
	test.check(is_equal_approx(Rules.distance_db(Rules.FULL_WITHIN + 60.0), -Rules.SOFTEST_DB), "precies op de grens: het zachtst")
	test.check(Rules.distance_db(1000.0) == -Rules.SOFTEST_DB, "heel ver: nooit zachter dan dat")
	test.check(Rules.distance_db(30.0) < Rules.distance_db(20.0), "verder is zachter")


func test_within_hearing(test) -> void:
	test.check(Rules.within_hearing(0.0) and Rules.within_hearing(Rules.HEARING_RANGE), "tot en met het bereik")
	test.check(not Rules.within_hearing(Rules.HEARING_RANGE + 0.1), "daarbuiten niet")


func test_in_picture(test) -> void:
	var picture := Rect2(0.0, 0.0, 1000.0, 500.0)
	test.check(Rules.in_picture(picture, Vector2(500.0, 250.0)), "midden in beeld")
	test.check(Rules.in_picture(picture, Vector2(-100.0, 250.0)), "net links buiten beeld (binnen de marge)")
	test.check(not Rules.in_picture(picture, Vector2(-160.0, 250.0)), "verder links niet")
	test.check(Rules.in_picture(picture, Vector2(1140.0, 250.0)) and not Rules.in_picture(picture, Vector2(1160.0, 250.0)), "rechts hetzelfde")
	test.check(Rules.in_picture(picture, Vector2(500.0, -70.0)) and not Rules.in_picture(picture, Vector2(500.0, -80.0)), "boven: de marge van de hoogte")
	test.check(Rules.in_picture(picture, Vector2(500.0, 570.0)) and not Rules.in_picture(picture, Vector2(500.0, 580.0)), "onder ook")


func test_nearest_ids(test) -> void:
	var entries := [[30.0, "ver"], [5.0, "dichtbij"], [12.0, "midden"]]
	test.check(Rules.nearest_ids(entries) == ["dichtbij", "midden", "ver"], "de dichtstbijzijnde eerst")
	test.check(Rules.nearest_ids(entries, 2) == ["dichtbij", "midden"], "niet meer dan er mogen")
	test.check(entries[0][1] == "ver", "de lijst zelf blijft zoals hij was")
	test.check(Rules.nearest_ids([]) == [], "niets: niets")
	var many := []
	for vehicle_index in 40:
		many.append([float(40 - vehicle_index), vehicle_index])
	var chosen := Rules.nearest_ids(many)
	test.check(chosen.size() == Rules.MAX_EMITTERS, "hooguit %d voertuigen met geluid" % Rules.MAX_EMITTERS)
	test.check(chosen[0] == 39 and chosen[Rules.MAX_EMITTERS - 1] == 40 - Rules.MAX_EMITTERS, "en dat zijn de dichtstbijzijnde")


# ------------------------------------------------------------------ the kinds

func test_kind_of(test) -> void:
	for kind: String in Rules.MOTOR_SOUNDS:
		test.check(Rules.kind_of(kind, false) == kind, "%s heeft een motor" % kind)
	test.check(Rules.kind_of("fiets", false) == "" and Rules.kind_of("", false) == "" and Rules.kind_of("<null>", false) == "", "een fiets en wat onbekend is zijn stil")
	test.check(Rules.kind_of("auto", true) == Rules.HELICOPTER_KIND and Rules.kind_of("<null>", true) == Rules.HELICOPTER_KIND, "de helikopter is zijn eigen soort")


func test_is_helicopter_script(test) -> void:
	test.check(Rules.is_helicopter_script("res://scripts/vehicles/police_helicopter.gd"), "het script van de helikopter")
	test.check(not Rules.is_helicopter_script("res://scripts/vehicles/vehicle.gd") and not Rules.is_helicopter_script(""), "een ander script niet")


func test_every_kind_has_its_numbers_and_sounds(test) -> void:
	for kind: String in Rules.MOTOR_SOUNDS:
		test.check(Rules.CRUISE_SPEED.has(kind) and Rules.MOTOR_VOLUME_DB.has(kind) and Rules.UNIT_SIZE.has(kind), "%s heeft snelheid, niveau en bereik" % kind)
		test.check(Rules.motor_sound(kind) == Rules.MOTOR_SOUNDS[kind], "%s: zijn motorlus" % kind)
		test.check(Rules.motor_base_db(kind) == Rules.MOTOR_VOLUME_DB[kind], "%s: zijn niveau" % kind)
		test.check(Rules.motor_unit(kind) == Rules.UNIT_SIZE[kind], "%s: zijn bereik" % kind)
		test.check(FileAccess.file_exists(SoundFiles.path_of(Rules.motor_sound(kind))), "de motorlus van %s bestaat" % kind)
		test.check(FileAccess.file_exists(SoundFiles.path_of(Rules.pass_by_sound(kind, "", false))), "het voorbijgaan van %s bestaat" % kind)
	test.check(Rules.motor_sound(Rules.HELICOPTER_KIND) == Rules.HELICOPTER_SOUND, "de helikopter: zijn rotor")
	test.check(Rules.motor_base_db(Rules.HELICOPTER_KIND) == Rules.HELICOPTER_VOLUME_DB, "de helikopter: zijn niveau")
	test.check(Rules.motor_unit(Rules.HELICOPTER_KIND) == Rules.HELICOPTER_UNIT_SIZE, "de helikopter: zijn bereik")
	for sound_name: String in [Rules.HELICOPTER_SOUND, Rules.HELICOPTER_PASS_BY, Rules.YELP_SOUND, Rules.FIRE_HORN, Rules.BUS_BRAKES,
			Rules.TRAM_BELL, Rules.TRAIN_HORN, Rules.HARD_CRASH_SOUND, Rules.LIGHT_CRASH_SOUND]:
		test.check(FileAccess.file_exists(SoundFiles.path_of(sound_name)), "%s bestaat" % sound_name)


func test_siren_sound(test) -> void:
	test.check(Rules.siren_sound(false, "politie") == "" and Rules.siren_sound(false, "ambulance") == "", "geen hulpdienst: geen sirene")
	test.check(Rules.siren_sound(true, "ambulance") == "ambulance_sirene_loop", "de ambulance")
	test.check(Rules.siren_sound(true, "brandweer") == "brandweer_sirene_loop", "de brandweer")
	test.check(Rules.siren_sound(true, "politie") == "politie_sirene_loop", "de politie")
	test.check(Rules.siren_sound(true, "onbekend") == "politie_sirene_loop", "elke andere hulpdienst klinkt als de politie")
	for service: String in Rules.SIREN_SOUNDS:
		test.check(FileAccess.file_exists(SoundFiles.path_of(Rules.siren_sound(true, service))), "de sirene van %s bestaat" % service)
		test.check(FileAccess.file_exists(SoundFiles.path_of(Rules.pass_by_sound("auto", Rules.siren_sound(true, service), true))), "het voorbijgaan van %s bestaat" % service)


# ------------------------------------------------------------------ the engines

func test_is_standing(test) -> void:
	test.check(Rules.is_standing(0.0) and Rules.is_standing(0.49), "stil of bijna stil")
	test.check(not Rules.is_standing(0.5) and not Rules.is_standing(8.0), "vanaf een halve meter per seconde rijdt het")


func test_engine_pitch(test) -> void:
	test.check(Rules.engine_pitch(0.0, 13.0) == Rules.IDLE_PITCH, "stilstaand: stationair")
	test.check(is_equal_approx(Rules.engine_pitch(13.0, 13.0), 1.0), "op kruissnelheid: 1")
	test.check(is_equal_approx(Rules.engine_pitch(6.5, 13.0), (Rules.IDLE_PITCH + 1.0) * 0.5), "halverwege: ertussenin")
	test.check(is_equal_approx(Rules.engine_pitch(19.5, 13.0), 1.25), "anderhalf keer zo snel: een kwart hoger")
	test.check(Rules.engine_pitch(200.0, 13.0) == Rules.MAX_PITCH, "nooit hoger dan het maximum")
	test.check(Rules.engine_pitch(8.0, 13.0) > Rules.engine_pitch(4.0, 13.0), "sneller is hoger")


func test_motor_pitch(test) -> void:
	test.check(is_equal_approx(Rules.motor_pitch(13.0, 13.0, 1.0, 1.0), 1.0), "op kruissnelheid, zonder doppler: 1")
	test.check(is_equal_approx(Rules.motor_pitch(13.0, 13.0, 1.1, 1.05), 1.155), "doppler en eigen toonhoogte tellen mee")
	test.check(Rules.motor_pitch(0.0, 13.0, 0.1, 1.0) == 0.3, "nooit lager dan 0,3")
	test.check(Rules.motor_pitch(40.0, 13.0, 3.0, 1.0) == 2.5, "nooit hoger dan 2,5")


func test_helicopter_and_siren_pitch(test) -> void:
	test.check(is_equal_approx(Rules.helicopter_pitch(1.1, 1.04), 1.144), "de rotor: doppler maal eigen toonhoogte")
	test.check(Rules.helicopter_pitch(0.1, 1.0) == 0.5 and Rules.helicopter_pitch(5.0, 1.0) == 2.0, "tussen 0,5 en 2")
	test.check(Rules.siren_pitch(1.2) == 1.2, "de sirene: alleen de doppler")
	test.check(Rules.siren_pitch(0.2) == 0.5 and Rules.siren_pitch(3.0) == 2.0, "tussen 0,5 en 2")


func test_engine_db(test) -> void:
	test.check(Rules.engine_db("auto", 0.0, 13.0) == Rules.IDLE_DB, "een auto die stilstaat: stationair zachter")
	test.check(Rules.engine_db("auto", 13.0, 13.0) == 0.0 and Rules.engine_db("auto", 30.0, 13.0) == 0.0, "op en boven kruissnelheid: vol")
	test.check(is_equal_approx(Rules.engine_db("bus", 4.5, 9.0), Rules.IDLE_DB * 0.5), "halverwege: ertussenin")
	test.check(Rules.engine_db("tram", 0.0, 8.0) <= -80.0, "een tram die stilstaat is stil")
	test.check(Rules.engine_db("trein", 0.0, 20.0) <= -80.0, "een trein ook")
	test.check(is_equal_approx(Rules.engine_db("tram", Rules.RAIL_SILENT_BELOW, 8.0), lerpf(Rules.IDLE_DB, 0.0, Rules.RAIL_SILENT_BELOW / 8.0)),
			"vanaf %.1f m/s klinkt een tram als ieder ander" % Rules.RAIL_SILENT_BELOW)
	test.check(Rules.engine_db("tram", 0.75, 8.0) < Rules.engine_db("auto", 0.75, 8.0), "daaronder zakt hij weg")


func test_duck_db(test) -> void:
	test.check(Rules.duck_db(0.0) == 0.0, "niet weggedoken: niets")
	test.check(Rules.duck_db(1.0) == Rules.PASS_BY_DUCK_DB, "helemaal: het volle bedrag")
	test.check(is_equal_approx(Rules.duck_db(0.5), Rules.PASS_BY_DUCK_DB * 0.5), "half: de helft")


func test_motor_volume(test) -> void:
	test.check(is_equal_approx(Rules.motor_volume_db("auto", -11.0, 13.0, 13.0, 0.0, 0.0, false), -11.0), "op kruissnelheid, dichtbij: zijn eigen niveau")
	test.check(is_equal_approx(Rules.motor_volume_db("auto", -11.0, 0.0, 13.0, -7.0, -4.0, false), -11.0 + Rules.IDLE_DB - 7.0 - 4.0), "stationair, weggedoken en ver: alles opgeteld")
	test.check(Rules.motor_volume_db("auto", -11.0, 13.0, 13.0, 0.0, 0.0, true) == Rules.CRASHED_DB, "een wrak is stil")
	test.check(Rules.motor_volume_db("tram", -7.0, 0.0, 8.0, 0.0, 0.0, false) < -80.0, "een stilstaande tram is stil")


func test_helicopter_and_siren_volume(test) -> void:
	test.check(is_equal_approx(Rules.helicopter_volume_db(0.3, -14.0), -13.7), "de rotor: zijn niveau en het wegduiken, niet de afstand")
	test.check(Rules.siren_volume_db(0.0, 0.0) == Rules.SIREN_VOLUME_DB, "de sirene dichtbij: zijn niveau")
	test.check(is_equal_approx(Rules.siren_volume_db(-7.0, -3.0), Rules.SIREN_VOLUME_DB - 10.0), "weggedoken en ver: opgeteld")


func test_doppler(test) -> void:
	test.check(Rules.doppler(Vector3(10.0, 0.0, 0.0), Vector3.ZERO, Vector3(0.2, 0.0, 0.0)) == 1.0, "vlak bij het oor: geen verschuiving")
	test.check(Rules.doppler(Vector3.ZERO, Vector3.ZERO, Vector3(20.0, 0.0, 0.0)) == 1.0, "niets beweegt: geen verschuiving")
	var coming := Rules.doppler(Vector3(13.0, 0.0, 0.0), Vector3.ZERO, Vector3(20.0, 0.0, 0.0))
	var going := Rules.doppler(Vector3(-13.0, 0.0, 0.0), Vector3.ZERO, Vector3(20.0, 0.0, 0.0))
	test.check(coming > 1.0 and going < 1.0, "komt het eraan dan hoger (%.3f), gaat het weg dan lager (%.3f)" % [coming, going])
	test.check(is_equal_approx(coming, 343.0 / (343.0 - 13.0 * Rules.DOPPLER_BOOST)), "de formule, aangezet met DOPPLER_BOOST")
	test.check(Rules.doppler(Vector3(0.0, 0.0, 13.0), Vector3.ZERO, Vector3(20.0, 0.0, 0.0)) == 1.0, "dwars erlangs: geen verschuiving")
	test.check(Rules.doppler(Vector3(13.0, 0.0, 0.0), Vector3(13.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0)) == 1.0, "het oor rijdt mee: geen verschuiving")
	test.check(Rules.doppler(Vector3.ZERO, Vector3(-13.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0)) > 1.0, "het oor komt eraan: hoger")
	test.check(is_equal_approx(Rules.doppler(Vector3(5000.0, 0.0, 0.0), Vector3.ZERO, Vector3(20.0, 0.0, 0.0)), 2.0), "nooit meer dan een octaaf omhoog")
	test.check(is_equal_approx(Rules.doppler(Vector3(-5000.0, 0.0, 0.0), Vector3.ZERO, Vector3(20.0, 0.0, 0.0)), 2.0 / 3.0), "en begrensd omlaag")


func test_loop_start(test) -> void:
	test.check(Rules.loop_start(0.0, 4.0) == 0.0, "trekking 0: aan het begin")
	test.check(is_equal_approx(Rules.loop_start(0.5, 4.05), 2.0), "halverwege, net voor het eind gerekend")
	test.check(Rules.loop_start(1.0, 4.0) < 4.0, "nooit op het eind zelf")
	test.check(Rules.loop_start(0.8, 0.02) == 0.0, "een heel korte lus: aan het begin")


func test_one_shot_max_db(test) -> void:
	test.check(Rules.one_shot_max_db(Rules.EVENT_DB) == Rules.EVENT_DB, "boven 0 dB mag het zo luid als gevraagd")
	test.check(Rules.one_shot_max_db(-6.0) == 0.0, "onder 0 dB: hooguit 0")


# ------------------------------------------------------------------ crashes and signals

func test_levels_of_the_one_shots(test) -> void:
	test.check(Rules.EVENT_DB > Rules.SIGNAL_DB and Rules.SIGNAL_DB > Rules.BACKGROUND_DB, "wat jou overkomt het luidst, dan de signalen, dan de achtergrond")
	test.check(Rules.PASS_BY_VOLUME_DB == Rules.BACKGROUND_DB, "voorbijgaan hoort bij de achtergrond")


func test_crash_sound(test) -> void:
	test.check(Rules.crash_sound(Rules.HARD_CRASH_SPEED + 0.1) == "auto_botsing_hard", "hard gereden: een harde klap")
	test.check(Rules.crash_sound(Rules.HARD_CRASH_SPEED) == "auto_botsing_licht", "precies op de grens: licht")
	test.check(Rules.crash_sound(0.0) == "auto_botsing_licht", "zacht gereden: een lichte klap")


func test_just_crashed(test) -> void:
	test.check(Rules.just_crashed(true, false), "net een wrak geworden")
	test.check(not Rules.just_crashed(true, true), "was al een wrak")
	test.check(not Rules.just_crashed(false, false) and not Rules.just_crashed(false, true), "geen wrak")


func test_bus_brakes(test) -> void:
	test.check(Rules.bus_brakes("bus", true, false, 4.0), "een bus die net stopt sist")
	test.check(not Rules.bus_brakes("bus", true, true, 4.0), "die al stond niet")
	test.check(not Rules.bus_brakes("bus", false, false, 4.0), "die rijdt niet")
	test.check(not Rules.bus_brakes("bus", true, false, 0.0), "die nog niet gereden had niet")
	test.check(not Rules.bus_brakes("auto", true, false, 4.0) and not Rules.bus_brakes("tram", true, false, 4.0), "alleen een bus")


func test_tram_rings(test) -> void:
	test.check(Rules.tram_rings("tram", false, true), "een tram die wegrijdt belt")
	test.check(not Rules.tram_rings("tram", false, false) and not Rules.tram_rings("tram", true, true) and not Rules.tram_rings("tram", true, false), "anders niet")
	test.check(not Rules.tram_rings("bus", false, true), "alleen een tram")


func test_train_may_hoot(test) -> void:
	test.check(Rules.train_may_hoot("trein", false, true), "een trein die wegrijdt mag toeteren")
	test.check(not Rules.train_may_hoot("trein", false, false) and not Rules.train_may_hoot("trein", true, true) and not Rules.train_may_hoot("trein", true, false), "anders niet")
	test.check(not Rules.train_may_hoot("tram", false, true), "alleen een trein")


func test_chance_hits(test) -> void:
	test.check(Rules.chance_hits(0.0, 0.5) and Rules.chance_hits(0.49, 0.5), "onder de kans: raak")
	test.check(not Rules.chance_hits(0.5, 0.5) and not Rules.chance_hits(0.9, 0.5), "erop of erboven: mis")
	test.check(not Rules.chance_hits(0.0, 0.0), "kans nul: nooit")
	test.check(Rules.chance_hits(0.999, 1.0), "kans één: altijd")


# ------------------------------------------------------------------ the yelp

func test_yelps(test) -> void:
	var cruise := 13.0
	test.check(Rules.yelps(false, cruise * 0.2, cruise, true), "langzaam met de sirene aan: de yelp begint")
	test.check(not Rules.yelps(true, cruise, cruise, true), "weer op snelheid: de yelp stopt")
	test.check(Rules.yelps(true, cruise * 0.6, cruise, true), "ertussenin: hij blijft yelpen")
	test.check(not Rules.yelps(false, cruise * 0.6, cruise, true), "ertussenin: hij begint er niet aan")
	test.check(not Rules.yelps(false, cruise * Rules.YELP_BELOW, cruise, true), "precies op de ondergrens: nog niet")
	test.check(Rules.yelps(true, cruise * Rules.YELP_UNTIL, cruise, true), "precies op de bovengrens: nog wel")
	test.check(not Rules.yelps(true, 0.0, cruise, false) and not Rules.yelps(false, 0.0, cruise, false), "sirene uit: geen yelp")


func test_siren_loop(test) -> void:
	test.check(Rules.siren_loop(true, "politie_sirene_loop") == Rules.YELP_SOUND, "yelpend: de yelp")
	test.check(Rules.siren_loop(false, "politie_sirene_loop") == "politie_sirene_loop", "anders zijn eigen sirene")


func test_horn(test) -> void:
	test.check(Rules.horn_may_blow(true, true, 10.0, 0.0), "een brandweerwagen die gaat yelpen mag toeteren")
	test.check(not Rules.horn_may_blow(false, true, 10.0, 0.0), "die ophoudt met yelpen niet")
	test.check(not Rules.horn_may_blow(true, false, 10.0, 0.0), "een politieauto niet")
	test.check(not Rules.horn_may_blow(true, true, 10.0, 12.0), "niet te snel na de vorige keer")
	test.check(Rules.horn_may_blow(true, true, 12.0, 12.0), "wel zodra de pauze om is")
	test.check(Rules.horn_ready_after(10.0) == 10.0 + Rules.HORN_PAUSE, "daarna weer na de pauze")
	test.check(Rules.HORN_CHANCE > 0.0 and Rules.HORN_CHANCE < 1.0, "de hoorn klinkt soms")


# ------------------------------------------------------------------ passing by

func test_pass_by_distances(test) -> void:
	test.check(Rules.pass_by_distance("auto") == Rules.PASS_BY_DISTANCE and Rules.pass_by_distance("trein") == Rules.PASS_BY_DISTANCE, "een voertuig: dichtbij")
	test.check(Rules.pass_by_distance(Rules.HELICOPTER_KIND) == Rules.HELICOPTER_PASS_BY_DISTANCE, "de helikopter: ruimer")
	test.check(Rules.rearm_distance("auto") == Rules.PASS_BY_REARM, "een voertuig kan opnieuw vanaf 40 m")
	test.check(Rules.rearm_distance(Rules.HELICOPTER_KIND) == Rules.PASS_BY_REARM * 2.5, "de helikopter vanaf 100 m")
	test.check(Rules.pass_by_unit("bus") == Rules.PASS_BY_UNIT and Rules.pass_by_unit(Rules.HELICOPTER_KIND) == Rules.HELICOPTER_UNIT_SIZE, "het bereik van het fragment")


func test_passing_part(test) -> void:
	test.check(Rules.passing_part("auto", Vector3(1.0, 2.0, 3.0)) == Vector3(1.0, 2.0, 3.0), "een voertuig: de hele afstand")
	test.check(Rules.passing_part(Rules.HELICOPTER_KIND, Vector3(1.0, 40.0, 3.0)) == Vector3(1.0, 0.0, 3.0), "de helikopter: de hoogte telt niet")


func test_arming(test) -> void:
	test.check(Rules.armed_at_start("auto", 16.1) and not Rules.armed_at_start("auto", 16.0), "al naast het oor als het geluid krijgt: geen voorbijgaan")
	test.check(Rules.armed_at_start(Rules.HELICOPTER_KIND, 71.0) and not Rules.armed_at_start(Rules.HELICOPTER_KIND, 60.0), "de helikopter op zijn eigen afstand")
	test.check(Rules.rearms("auto", 40.1) and not Rules.rearms("auto", 40.0), "een voertuig kan weer voorbijgaan voorbij 40 m")
	test.check(Rules.rearms(Rules.HELICOPTER_KIND, 101.0) and not Rules.rearms(Rules.HELICOPTER_KIND, 99.0), "de helikopter voorbij 100 m")


func test_fast_enough(test) -> void:
	test.check(Rules.car_fast_enough("auto", 13.0, 13.0), "een auto op snelheid")
	test.check(Rules.car_fast_enough("auto", -13.0, 13.0), "achteruit telt ook")
	test.check(Rules.car_fast_enough("auto", 13.0 * Rules.PASS_BY_MIN_SHARE, 5.0), "precies op de grens")
	test.check(not Rules.car_fast_enough("auto", 7.0, 7.0), "een auto die te langzaam rijdt")
	test.check(not Rules.car_fast_enough("auto", 13.0, 1.0), "die even hard meerijdt met het oor")
	test.check(Rules.car_fast_enough("tram", 5.0, 5.0) and not Rules.car_fast_enough("trein", 5.0, 5.0), "elke soort naar zijn eigen kruissnelheid")
	test.check(Rules.helicopter_fast_enough(Rules.HELICOPTER_PASS_BY_MIN_SPEED) and not Rules.helicopter_fast_enough(7.9), "de helikopter vanaf 8 m/s")


func test_seconds_until_nearest_and_miss(test) -> void:
	var offset := Vector3(-26.0, 0.0, 5.0)
	var relative := Vector3(13.0, 0.0, 0.0)
	test.check(is_equal_approx(Rules.seconds_until_nearest(offset, relative), 2.0), "26 m ervoor met 13 m/s: over 2 s het dichtst")
	test.check(is_equal_approx(Rules.miss_distance(offset, relative, 2.0), 5.0), "en dan 5 m van het oor")
	test.check(Rules.seconds_until_nearest(Vector3(26.0, 0.0, 5.0), relative) < 0.0, "al voorbij: negatief")
	test.check(is_equal_approx(Rules.seconds_until_nearest(Vector3(0.0, 0.0, 5.0), relative), 0.0), "precies ernaast: nu")


func test_passes(test) -> void:
	var relative := Vector3(13.0, 0.0, 0.0)
	test.check(Rules.passes("auto", Vector3(-26.0, 0.0, 5.0), relative), "komt eraan en gaat op 5 m langs: voorbij")
	test.check(Rules.passes("auto", Vector3(-26.0, 0.0, 8.0), relative), "op precies 8 m ook nog")
	test.check(not Rules.passes("auto", Vector3(-26.0, 0.0, 9.0), relative), "op 9 m niet")
	test.check(not Rules.passes("auto", Vector3(26.0, 0.0, 5.0), relative), "rijdt het weg dan niet")
	test.check(not Rules.passes("auto", Vector3(0.0, 0.0, 5.0), relative), "is het al op zijn dichtst dan niet meer")
	test.check(Rules.passes(Rules.HELICOPTER_KIND, Vector3(-60.0, 0.0, 30.0), relative), "de helikopter mag op 30 m langs")
	test.check(not Rules.passes(Rules.HELICOPTER_KIND, Vector3(-60.0, 0.0, 36.0), relative), "maar niet op 36 m")


func test_clip_in_reach_and_start(test) -> void:
	test.check(Rules.clip_in_reach(2.0, 4.0) and Rules.clip_in_reach(0.5, 4.0), "het dichtste punt binnen een half fragment: nu beginnen")
	test.check(not Rules.clip_in_reach(2.1, 4.0), "verder weg: nog wachten")
	test.check(Rules.pass_by_start(4.0, 2.0) == 0.0, "een half fragment ervoor: vanaf het begin")
	test.check(is_equal_approx(Rules.pass_by_start(4.0, 0.5), 1.5), "dichterbij: verderop in het fragment, zodat het midden op het dichtste punt valt")
	test.check(Rules.pass_by_start(4.0, 3.0) == 0.0, "nooit voor het begin")
	test.check(is_equal_approx(Rules.pass_by_start(4.0, -5.0), 3.9), "nooit voorbij het eind")


func test_pass_by_sound(test) -> void:
	test.check(Rules.pass_by_sound("auto", "", false) == "auto_voorbij", "een auto: auto_voorbij")
	test.check(Rules.pass_by_sound("tram", "", false) == "tram_voorbij", "een tram: tram_voorbij")
	test.check(Rules.pass_by_sound("auto", "politie_sirene_loop", true) == "politie_voorbij", "de politie met de sirene aan")
	test.check(Rules.pass_by_sound("auto", "ambulance_sirene_loop", true) == "ambulance_voorbij", "de ambulance met de sirene aan")
	test.check(Rules.pass_by_sound("auto", "brandweer_sirene_loop", true) == "brandweer_voorbij", "de brandweer met de sirene aan")
	test.check(Rules.pass_by_sound("auto", "politie_sirene_loop", false) == "auto_voorbij", "met de sirene uit: als een gewone auto")
	test.check(Rules.pass_by_sound("auto", "", true) == "auto_voorbij", "zonder sirene: als een gewone auto")
	test.check(Rules.pass_by_sound(Rules.HELICOPTER_KIND, "", false) == Rules.HELICOPTER_PASS_BY, "de helikopter zijn eigen fragment")
