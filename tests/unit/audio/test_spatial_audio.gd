extends RefCounted
## Unit tests of the spatial sound of the city (scripts/audio/spatial_audio.gd, the
## behaviour): off until there is a player, then the ear, the buses, one-shots where asked,
## loops on a parent and the sound of a vehicle in view; on a small stage of its own, stepped
## by hand. The sums: tests/unit/audio/test_spatial_audio_rules.gd. In the whole city:
## tests/integration/world/test_spatial_audio.gd.
##   tests/run_unit_tests.sh spatial_audio

const SpatialAudio = preload("res://scripts/audio/spatial_audio.gd")
const Helicopter = preload("res://scripts/vehicles/police_helicopter.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree
var _buses_before := 0
var _master_effects_before := 0


## A spatial sound of its own beside the game's, with a stand-in for the player at the
## origin: on after one step.
func _stage(with_player := true) -> Dictionary:
	_buses_before = AudioServer.bus_count
	_master_effects_before = AudioServer.get_bus_effect_count(0)
	var spatial: Node = SpatialAudio.new()
	spatial.name = "RuimtelijkGeluidTest"
	tree.root.add_child(spatial)
	var player := Node3D.new()
	tree.root.add_child(player)
	if with_player:
		spatial._player = player
		spatial._process(0.016)
	return {"spatial": spatial, "player": player}


## Everything of the stage gone, and the audio buses as they were.
func _clear(stage: Dictionary) -> void:
	stage.spatial.free()
	stage.player.free()
	while AudioServer.bus_count > _buses_before:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	while AudioServer.get_bus_effect_count(0) > _master_effects_before:
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)


func _one_shots(spatial: Node) -> Array:
	return spatial.get_children().filter(func(child: Node) -> bool: return child is AudioStreamPlayer3D)


func test_off_without_a_player(test) -> void:
	var stage := _stage(false)
	var spatial: Node = stage.spatial
	spatial._process(0.016)
	spatial.play_event(Vector3.ZERO, "tram_bel")
	spatial.play_signal(Vector3.ZERO, "tram_bel")
	spatial.play_at(Vector3.ZERO, "tram_bel")
	test.check(_one_shots(spatial).is_empty(), "buiten de stad klinkt er niets")
	test.check(spatial.get_node_or_null("Oor") == null, "en is er geen oor")
	test.check(spatial.emitter_report().is_empty(), "geen voertuigen met geluid")
	_clear(stage)


func test_on_with_a_player_makes_the_ear_and_the_buses(test) -> void:
	var stage := _stage()
	var spatial: Node = stage.spatial
	var ear := spatial.get_node_or_null("Oor") as AudioListener3D
	test.check(ear != null, "met een speler is er een oor")
	test.check(ear != null and ear.global_position.is_equal_approx(Vector3.UP * SpatialAudio.LISTENER_HEIGHT), "op oorhoogte boven de speler")
	var traffic_bus := AudioServer.get_bus_index(SpatialAudio.BUS_NAME)
	var event_bus := AudioServer.get_bus_index(SpatialAudio.EVENT_BUS_NAME)
	test.check(traffic_bus != -1 and event_bus != -1, "de bussen van het verkeer en de voorvallen bestaan")
	test.check(AudioServer.get_bus_effect_count(traffic_bus) == 2 and AudioServer.get_bus_effect(traffic_bus, 0) is AudioEffectCompressor
			and AudioServer.get_bus_effect(traffic_bus, 1) is AudioEffectHardLimiter, "het verkeer: een compressor en een begrenzer")
	test.check(AudioServer.get_bus_effect_count(event_bus) == 1 and AudioServer.get_bus_effect(event_bus, 0) is AudioEffectHardLimiter, "de voorvallen: alleen een begrenzer")
	test.check(is_equal_approx(AudioServer.get_bus_volume_db(traffic_bus), SpatialAudio.BUS_VOLUME_DB), "het verkeer op zijn niveau")
	var master_limiters := 0
	for effect_index in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, effect_index) is AudioEffectHardLimiter:
			master_limiters += 1
	spatial._ensure_bus()
	var master_limiters_after := 0
	for effect_index in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, effect_index) is AudioEffectHardLimiter:
			master_limiters_after += 1
	test.check(master_limiters == 1 and master_limiters_after == 1, "Master heeft één begrenzer, ook na nog een keer")
	test.check(AudioServer.get_bus_effect_count(traffic_bus) == 2, "en de bus krijgt zijn effecten niet dubbel")
	tree.paused = true
	spatial._process(0.016)
	test.check(is_equal_approx(AudioServer.get_bus_volume_db(traffic_bus), SpatialAudio.BUS_VOLUME_DB + SpatialAudio.PAUSED_DB), "in de pauze zachter")
	tree.paused = false
	_clear(stage)


func test_distance_db_from_the_ear(test) -> void:
	var stage := _stage()
	var spatial: Node = stage.spatial
	test.check(spatial.distance_db(Vector3(0.0, SpatialAudio.LISTENER_HEIGHT, 3.0)) == 0.0, "vlakbij: op volle sterkte")
	test.check(is_equal_approx(spatial.distance_db(Vector3(0.0, SpatialAudio.LISTENER_HEIGHT, 18.0)), -2.0), "18 m van het oor: 2 dB zachter")
	test.check(spatial.distance_db(Vector3(0.0, 0.0, 500.0)) == -SpatialAudio.SOFTEST_DB, "heel ver: het zachtst")
	_clear(stage)


func test_in_view_without_a_camera_is_within_hearing(test) -> void:
	var stage := _stage()
	var spatial: Node = stage.spatial
	if tree.root.get_camera_3d() == null:
		test.check(spatial.in_view(Vector3(20.0, 0.0, 0.0)), "zonder camera: binnen gehoorsafstand telt")
		test.check(not spatial.in_view(Vector3(200.0, 0.0, 0.0)), "en daarbuiten niet")
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.global_position = Vector3(0.0, 2.0, 10.0)   # looks along -Z, at the origin
	camera.make_current()
	test.check(spatial.in_view(Vector3.ZERO), "met een camera: wat in beeld is")
	test.check(not spatial.in_view(Vector3(0.0, 0.0, 40.0)), "wat achter de camera is niet")
	test.check(not spatial.in_view(Vector3(4000.0, 0.0, 0.0)), "wat ver buiten beeld is niet")
	camera.free()
	_clear(stage)


func test_one_shots_play_at_their_place_and_level(test) -> void:
	var stage := _stage()
	var spatial: Node = stage.spatial
	spatial.play_event(Vector3(0.0, 0.0, 3.0), "tram_bel", 9.0)
	var players := _one_shots(spatial)
	test.check(players.size() == 1, "een voorval geeft één speler")
	if players.size() == 1:
		var player: AudioStreamPlayer3D = players[0]
		test.check(player.global_position.is_equal_approx(Vector3(0.0, 1.0, 3.0)), "een meter boven zijn plek")
		test.check(is_equal_approx(player.volume_db, SpatialAudio.EVENT_DB) and player.max_db == SpatialAudio.EVENT_DB, "dichtbij op het niveau van een voorval")
		test.check(player.bus == SpatialAudio.EVENT_BUS_NAME and player.unit_size == 9.0, "op de bus van de voorvallen, met zijn bereik")
		test.check(player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED and player.attenuation_filter_db == 0.0, "Godots eigen demping staat uit")
		test.check(absf(player.pitch_scale - 1.0) <= 0.0601, "op een eigen toonhoogte")
		test.check(player.stream != null and not (player.stream as AudioStreamOggVorbis).loop, "het geluid speelt één keer")
	spatial.play_signal(Vector3(0.0, SpatialAudio.LISTENER_HEIGHT, 28.0), "tram_bel")
	players = _one_shots(spatial)
	test.check(players.size() == 2 and is_equal_approx(players[1].volume_db, SpatialAudio.SIGNAL_DB - 4.0), "een signaal 28 m verder: zijn niveau min 4 dB")
	test.check(players.size() == 2 and players[1].max_db == 0.0 and players[1].unit_size == 8.0, "nooit boven 0 dB, het gewone bereik")
	spatial.play_at(Vector3.ZERO, "tram_bel", -6.0, 5.0)
	players = _one_shots(spatial)
	test.check(players.size() == 3 and is_equal_approx(players[2].volume_db, -6.0) and players[2].unit_size == 5.0, "play_at: het gevraagde niveau en bereik")
	spatial.play_event(Vector3(0.0, 0.0, 500.0), "tram_bel")
	test.check(_one_shots(spatial).size() == 3, "wat te ver weg is klinkt niet")
	_clear(stage)


func test_attach_loop(test) -> void:
	var stage := _stage()
	var spatial: Node = stage.spatial
	var wreck := Node3D.new()
	tree.root.add_child(wreck)
	var player: AudioStreamPlayer3D = spatial.attach_loop(wreck, "brand_loop", 12.0, -3.0)
	test.check(player != null and player.get_parent() == wreck and player.name == "Geluid_brand_loop", "de lus hangt aan wie hem vroeg")
	test.check(player != null and player.bus == SpatialAudio.EVENT_BUS_NAME and player.unit_size == 12.0 and player.volume_db == -3.0 and player.max_db == 0.0,
			"op de bus van de voorvallen, met zijn bereik en niveau")
	test.check(player != null and (player.stream as AudioStreamOggVorbis).loop and player.playing, "hij herhaalt en speelt")
	test.check(player != null and absf(player.pitch_scale - 1.0) <= 0.0501, "op een eigen toonhoogte")
	test.check(spatial.attach_loop(null, "brand_loop") == null, "zonder ouder: geen speler")
	wreck.free()
	_clear(stage)


func test_a_helicopter_in_view_gets_its_sound(test) -> void:
	var stage := _stage()
	var spatial: Node = stage.spatial
	var helicopter: Node3D = Helicopter.new()
	tree.root.add_child(helicopter)
	helicopter.global_position = Vector3(0.0, 20.0, -30.0)
	test.check(spatial.emitter_report().is_empty(), "eerst nog geen geluid")
	spatial._process(1.0)
	var report: Array = spatial.emitter_report()
	test.check(report.size() == 1 and report[0].kind == "helikopter", "na een stap heeft de helikopter geluid")
	if report.size() == 1:
		test.check(is_equal_approx(report[0].distance, helicopter.global_position.distance_to(Vector3.UP * SpatialAudio.LISTENER_HEIGHT)), "op zijn afstand van het oor")
		test.check(report[0].pitch >= 0.5 and report[0].pitch <= 2.0 and not report[0].siren, "met een toonhoogte en zonder sirene")
	var rotor := helicopter.get_node_or_null("Geluid_helikopter_loop") as AudioStreamPlayer3D
	test.check(rotor != null and rotor.bus == SpatialAudio.BUS_NAME and rotor.unit_size == 30.0, "zijn rotorlus hangt aan hem, op de bus van het verkeer")
	test.check(rotor != null and is_equal_approx(rotor.volume_db, 0.3), "op zijn niveau")
	helicopter.global_position = Vector3(0.0, 20.0, -900.0)
	spatial._process(1.0)
	test.check(spatial.emitter_report().is_empty() and (rotor == null or rotor.is_queued_for_deletion()), "buiten gehoor raakt hij zijn geluid kwijt")
	helicopter.free()
	test.check(spatial._vehicles.is_empty(), "en weg uit de boom is hij vergeten")
	_clear(stage)
