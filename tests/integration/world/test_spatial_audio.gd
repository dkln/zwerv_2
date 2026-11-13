extends "res://tests/integration/support/town_test.gd"
## The spatial sound (scripts/audio/spatial_audio.gd, autoload RuimtelijkGeluid) in the town
## with its traffic: it switches on with the player, vehicles near the ear get engine sound,
## the traffic bus has only a compressor and a limiter (no echo or reverb); every sound in
## assets/audio/geluiden/ is imported, loads and is used by the code (the cries of pain by the
## player, for every voice of a character); a vehicle heading past the ear gets its pass-by
## clip (and its loops duck); an emergency vehicle slowing down with its siren on switches to
## the yelp.
##   tests/run_integration_tests.sh spatial_audio

const Babble = preload("res://scripts/audio/babble.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
## The scripts besides spatial_audio.gd that name sounds (the horns and bells: play_signal).
const SOUND_USERS := ["res://scripts/vehicles/vehicle.gd", "res://scripts/vehicles/fire_engine.gd",
	"res://scripts/world/people/pedestrian.gd", "res://scripts/effects/vehicle_fire.gd", "res://scripts/world/interiors/interiors.gd"]


static func world_options() -> Dictionary:
	return {"traffic": true}


## The spatial sound of the run (the autoload), switched on (it does so in its next frame
## once the player is there).
func _spatial() -> Node:
	var spatial := tree.root.get_node_or_null("RuimtelijkGeluid")
	if spatial:
		await wait_until(func() -> bool: return spatial._active, 4.0)
	return spatial


## The voices of the characters (their cries of pain: PlayerController.cry_out).
func _voices() -> Array[String]:
	var voices: Array[String] = []
	for archetype: Dictionary in PlayerCharacter.ARCHETYPES.values():
		var voice := String(archetype.get("voice", "man"))
		if voice not in voices:
			voices.append(voice)
	return voices


## The numbers and "hard": the cries of pain every voice has.
func _cries() -> Array:
	return ["hard"] + range(1, PlayerController.SHORT_CRY_COUNT + 1).map(func(number: int) -> String: return str(number))


## Whether the code uses the sound `sound_name`: named in `code`, or made from a pattern
## (a pass-by clip, a cry of pain, a babble, the player's own sounds).
func _is_used(spatial: Node, code: String, sound_name: String) -> bool:
	if code.contains('"%s"' % sound_name):
		return true
	# made from a pattern: <kind>_voorbij, <dienst>_sirene_loop -> <dienst>_voorbij
	if sound_name.ends_with("_voorbij") and (spatial.MOTOR_SOUNDS.has(sound_name.trim_suffix("_voorbij"))
			or code.contains('"%s_sirene_loop"' % sound_name.trim_suffix("_voorbij"))):
		return true
	# the thud of a hit, the splash, the jump
	if sound_name in [PlayerController.BODY_HIT_SOUND, PlayerController.SPLASH_SOUND, PlayerController.JUMP_SOUND]:
		return true
	# the cries of pain: pijn_<voice>_<1..3|hard> for a voice of a character
	for voice in _voices():
		var cry := sound_name.trim_prefix("pijn_%s_" % voice)
		if sound_name.begins_with("pijn_%s_" % voice) and cry in _cries():
			return true
	# the babble: brabbel_<voice>_<mood>_<n> (scripts/audio/babble.gd)
	for voice: String in Babble.VOICES:
		for mood: String in Babble.MOODS:
			for variant in range(1, Babble.VARIANTS + 1):
				if sound_name == "brabbel_%s_%s_%d" % [voice, mood, variant]:
					return true
	return false


## The first vehicle the spatial sound knows for which `wanted` holds, or null.
func _find_vehicle(spatial: Node, wanted: Callable) -> Vehicle:
	for vehicle in spatial._vehicles:
		if vehicle is Vehicle and wanted.call(vehicle):
			return vehicle
	return null


## With the player in the town the spatial sound is on, has its bus, knows the vehicles
## and has given the ones near the ear their sound.
func test_on_with_the_player_and_vehicles_sound(test) -> void:
	var spatial := await _spatial()
	test.check(spatial != null and spatial._active, "aan zodra de speler er is")
	if spatial == null:
		return
	test.check(AudioServer.get_bus_index(spatial.BUS_NAME) != -1, "bus %s gemaakt" % spatial.BUS_NAME)
	await wait_until(func() -> bool: return spatial._emitters.size() > 0, 4.0)
	print("voertuigen gevonden: %d, met geluid: %d" % [spatial._vehicles.size(), spatial._emitters.size()])
	for entry in spatial.emitter_report():
		print("  %-10s %5.1f m  toon %.2f%s" % [entry.kind, entry.distance, entry.pitch, "  sirene" if entry.siren else ""])
	test.check(spatial._vehicles.size() > 0, "voertuigen gevonden")
	test.check(spatial._emitters.size() > 0, "voertuigen dichtbij hebben geluid")


## Kept plain: only a compressor and a limiter on the traffic bus, no echo or reverb.
func test_bus_has_only_compressor_and_limiter(test) -> void:
	var spatial := await _spatial()
	var bus := AudioServer.get_bus_index(spatial.BUS_NAME)
	var effects := []
	for effect_index in AudioServer.get_bus_effect_count(bus):
		effects.append(AudioServer.get_bus_effect(bus, effect_index).get_class())
	print("effecten op de bus: ", effects)
	test.check(effects == ["AudioEffectCompressor", "AudioEffectHardLimiter"], "geen echo of galm, wel compressor en limiter")


## Every sound file is imported (so an exported game has it), loads, and is used by the code.
func test_every_sound_is_imported_loads_and_is_used(test) -> void:
	var spatial := await _spatial()
	var code := FileAccess.get_file_as_string(spatial.get_script().resource_path)
	for user_path: String in SOUND_USERS:
		code += FileAccess.get_file_as_string(user_path)
	var unused: Array[String] = []
	var not_imported: Array[String] = []
	var broken: Array[String] = []
	var count := 0
	for file_name in DirAccess.get_files_at(spatial.SOUND_FOLDER):
		if not file_name.ends_with(".ogg"):
			continue
		count += 1
		var sound_name := file_name.get_basename()
		if not ResourceLoader.exists(spatial.SOUND_FOLDER + file_name):
			not_imported.append(sound_name)
		var stream: AudioStream = spatial._stream(sound_name, false)
		if stream == null or stream.get_length() <= 0.0:
			broken.append(sound_name)
		if not _is_used(spatial, code, sound_name):
			unused.append(sound_name)
	print("geluiden: %d bestanden" % count)
	test.check(count > 0, "geluiden gevonden")
	test.check(not_imported.is_empty(), "alle geluiden geimporteerd %s" % [not_imported])
	test.check(broken.is_empty(), "alle geluiden laden %s" % [broken])
	test.check(unused.is_empty(), "alle geluiden worden gebruikt %s" % [unused])


## Every voice of a character has its cries of pain: the short ones and the hard one.
func test_every_voice_has_its_cries_of_pain(test) -> void:
	var spatial := await _spatial()
	for voice in _voices():
		for cry: String in _cries():
			test.check(FileAccess.file_exists(spatial.SOUND_FOLDER + "pijn_%s_%s.ogg" % [voice, cry]), "kreet pijn_%s_%s bestaat" % [voice, cry])


## A fast car heading straight for the ear (the ear put 10 m in front of it) gets its
## pass-by clip, once per pass, and its engine ducks meanwhile.
func test_car_passing_the_ear_plays_its_pass_by(test) -> void:
	var spatial := await _spatial()
	var car := _find_vehicle(spatial, func(vehicle: Vehicle) -> bool: return not vehicle.emergency and spatial._kind_of(vehicle) == "auto")
	test.check(car != null, "een auto in het verkeer")
	if car == null:
		return
	var emitter = spatial._make_emitter(car)
	var cruise: float = spatial.CRUISE_SPEED["auto"]
	spatial._ear = car.global_position + Vector3(10.0, 0.0, 0.0)
	spatial._ear_velocity = Vector3.ZERO
	emitter.pass_by_armed = true
	emitter.velocity = Vector3(cruise, 0.0, 0.0)
	var speed_before := car.speed
	car.speed = cruise
	spatial._check_pass_by(emitter)
	car.speed = speed_before
	var clip := car.get_node_or_null("Voorbij") as AudioStreamPlayer3D
	test.check(clip != null and clip.stream != null and clip.stream.resource_path.ends_with("auto_voorbij.ogg"),
		"auto die langsrijdt speelt auto_voorbij")
	test.check(emitter.pass_by_until > spatial._clock and not emitter.pass_by_armed, "motor duikt weg tijdens het voorbijgaan")
	spatial._check_pass_by(emitter)
	var clips := car.get_children().filter(func(child: Node) -> bool: return child.name.begins_with("Voorbij"))
	test.check(clips.size() == 1, "maar een keer per keer langsrijden")
	for child in car.get_children():
		if child.name.begins_with("Voorbij") or child.name.begins_with("Geluid_"):
			child.free()


## An emergency vehicle with its siren on, nearly standing: the yelp; speeding up: its own
## siren again (if one drives in the town now).
func test_emergency_vehicle_slowing_down_yelps(test) -> void:
	var spatial := await _spatial()
	test.check(spatial != null, "het ruimtelijk geluid is er")
	var emergency := _find_vehicle(spatial, func(vehicle: Vehicle) -> bool: return vehicle.emergency and spatial._kind_of(vehicle) != "")
	if emergency == null:
		print("geen hulpdienst gevonden (yelp niet getest)")
		return
	var emitter = spatial._make_emitter(emergency)
	var cruise: float = spatial.CRUISE_SPEED[emitter.kind]
	spatial._update_yelp(emitter, cruise * 0.2, true)
	test.check(emitter.siren.stream.resource_path.ends_with("sirene_yelp_loop.ogg"), "hulpdienst die afremt yelpt (%s)" % emergency.name)
	spatial._update_yelp(emitter, cruise, true)
	test.check(emitter.siren.stream.resource_path.ends_with(emitter.siren_name + ".ogg"), "optrekken: eigen sirene terug")
	print("hulpdienst: %s, sirene %s, voorbij %s" % [emergency.name, emitter.siren_name, spatial._pass_by_sound(emitter)])
	spatial._free_emitter(emitter)
