extends SceneTree
## Loads scenes/stad.tscn with its traffic and the spatial sound (scripts/audio/spatial_audio.gd,
## autoload RuimtelijkGeluid; added here when the autoload is not there), headless, and checks:
## it switches on with the player, vehicles near the ear get engine sound, the traffic bus has
## only a compressor and a limiter (no echo or reverb); every sound in assets/audio/geluiden/ is imported, loads and is
## used by the code (the cries of pain by the player, for every voice of a character); a vehicle heading past the ear gets its pass-by clip (and its loops duck);
## an emergency vehicle slowing down with its siren on switches to the yelp.
## usage: tools/godot.sh --headless --script tools/check/spatial_audio_test.gd

const BABBLE = preload("res://scripts/audio/babble.gd")
const Common = preload("res://tools/tool_common.gd")
const SPATIAL_AUDIO = preload("res://scripts/audio/spatial_audio.gd")
const PLAYER = preload("res://scripts/player/player_controller.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 300)
	var spatial: Node = get_root().get_node_or_null("RuimtelijkGeluid")
	if spatial == null:
		spatial = SPATIAL_AUDIO.new()
		spatial.name = "RuimtelijkGeluid"
		get_root().add_child(spatial)
	await process_frame
	var scene := Common.instantiate(Common.CITY)
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	get_root().add_child(scene)
	for frame_index in 240:
		await process_frame

	_check(spatial._active, "aan zodra de speler er is")
	_check(AudioServer.get_bus_index(spatial.BUS_NAME) != -1, "bus %s gemaakt" % spatial.BUS_NAME)
	print("voertuigen gevonden: %d, met geluid: %d" % [spatial._vehicles.size(), spatial._emitters.size()])
	for entry in spatial.emitter_report():
		print("  %-10s %5.1f m  toon %.2f%s" % [entry.kind, entry.distance, entry.pitch, "  sirene" if entry.siren else ""])
	_check(spatial._vehicles.size() > 0, "voertuigen gevonden")
	_check(spatial._emitters.size() > 0, "voertuigen dichtbij hebben geluid")

	# kept plain: only a compressor and a limiter on the bus, no echo or reverb
	var bus := AudioServer.get_bus_index(spatial.BUS_NAME)
	var effects := []
	for effect_index in AudioServer.get_bus_effect_count(bus):
		effects.append(AudioServer.get_bus_effect(bus, effect_index).get_class())
	print("effecten op de bus: ", effects)
	_check(effects == ["AudioEffectCompressor", "AudioEffectHardLimiter"], "geen echo of galm, wel compressor en limiter")
	_check_sound_files(spatial)
	_check_pass_by(spatial)
	_check_yelp(spatial)
	print("ruimtelijk geluid ok" if _problems.is_empty() else "problemen: " + str(_problems))
	quit(0 if _problems.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	print(("ok   " if condition else "FOUT ") + label)
	if not condition:
		_problems.append(label)


## Every sound file is imported (so an exported game has it), loads, and is named in the code.
func _check_sound_files(spatial: Node) -> void:
	var code := FileAccess.get_file_as_string(spatial.get_script().resource_path)
	# the horns and bells are named by the vehicles and the pedestrians (play_signal)
	for user_path in ["res://scripts/vehicles/vehicle.gd", "res://scripts/vehicles/fire_engine.gd", "res://scripts/world/pedestrian.gd",
			"res://scripts/effects/vehicle_fire.gd", "res://scripts/world/interiors.gd"]:
		code += FileAccess.get_file_as_string(user_path)
	var unused: Array[String] = []
	var not_imported: Array[String] = []
	var broken: Array[String] = []
	var files := DirAccess.get_files_at(spatial.SOUND_FOLDER)
	var count := 0
	for file_name in files:
		if not file_name.ends_with(".ogg"):
			continue
		count += 1
		var sound_name := file_name.get_basename()
		if not ResourceLoader.exists(spatial.SOUND_FOLDER + file_name):
			not_imported.append(sound_name)
		var stream: AudioStream = spatial._stream(sound_name, false)
		if stream == null or stream.get_length() <= 0.0:
			broken.append(sound_name)
		var named := code.contains('"%s"' % sound_name)
		# made from a pattern: <kind>_voorbij, <dienst>_sirene_loop -> <dienst>_voorbij
		if sound_name.ends_with("_voorbij") and (spatial.MOTOR_SOUNDS.has(sound_name.trim_suffix("_voorbij"))
				or code.contains('"%s_sirene_loop"' % sound_name.trim_suffix("_voorbij"))):
			named = true
		# the cries of pain: pijn_<voice>_<1..3|hard> for a voice of a character, the thud of a hit
		if sound_name in [PLAYER.BODY_HIT_SOUND, PLAYER.SPLASH_SOUND, PLAYER.JUMP_SOUND]:
			named = true
		for voice in _voices():
			var cry := sound_name.trim_prefix("pijn_%s_" % voice)
			if sound_name.begins_with("pijn_%s_" % voice) and (cry == "hard" or int(cry) in range(1, PLAYER.SHORT_CRY_COUNT + 1)):
				named = true
		# the babble: brabbel_<voice>_<mood>_<n> (scripts/audio/babble.gd)
		for voice: String in BABBLE.VOICES:
			for mood: String in BABBLE.MOODS:
				for variant in range(1, BABBLE.VARIANTS + 1):
					if sound_name == "brabbel_%s_%s_%d" % [voice, mood, variant]:
						named = true
		if not named:
			unused.append(sound_name)
	for voice in _voices():
		for cry in ["hard"] + range(1, PLAYER.SHORT_CRY_COUNT + 1).map(func(number: int) -> String: return str(number)):
			_check(FileAccess.file_exists(spatial.SOUND_FOLDER + "pijn_%s_%s.ogg" % [voice, cry]), "kreet pijn_%s_%s bestaat" % [voice, cry])
	print("geluiden: %d bestanden" % count)
	_check(count > 0, "geluiden gevonden")
	_check(not_imported.is_empty(), "alle geluiden geimporteerd %s" % [not_imported])
	_check(broken.is_empty(), "alle geluiden laden %s" % [broken])
	_check(unused.is_empty(), "alle geluiden worden gebruikt %s" % [unused])


## A fast car heading straight for the ear (the ear put 10 m in front of it) gets its pass-by.
func _check_pass_by(spatial: Node) -> void:
	var car: Vehicle = null
	for vehicle in spatial._vehicles:
		if vehicle is Vehicle and not (vehicle as Vehicle).emergency and spatial._kind_of(vehicle) == "auto":
			car = vehicle
			break
	if car == null:
		print("geen auto gevonden (voorbij niet getest)")
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
	_check(clip != null and clip.stream != null and clip.stream.resource_path.ends_with("auto_voorbij.ogg"),
			"auto die langsrijdt speelt auto_voorbij")
	_check(emitter.pass_by_until > spatial._clock and not emitter.pass_by_armed, "motor duikt weg tijdens het voorbijgaan")
	spatial._check_pass_by(emitter)
	var clips := car.get_children().filter(func(child): return child.name.begins_with("Voorbij"))
	_check(clips.size() == 1, "maar een keer per keer langsrijden")
	for child in car.get_children():
		if child.name.begins_with("Voorbij") or child.name.begins_with("Geluid_"):
			child.free()


## An emergency vehicle with its siren on, nearly standing: the yelp; speeding up: its own siren.
func _check_yelp(spatial: Node) -> void:
	var emergency: Vehicle = null
	for vehicle in spatial._vehicles:
		if vehicle is Vehicle and (vehicle as Vehicle).emergency and spatial._kind_of(vehicle) != "":
			emergency = vehicle
			break
	if emergency == null:
		print("geen hulpdienst gevonden (yelp niet getest)")
		return
	var emitter = spatial._make_emitter(emergency)
	var cruise: float = spatial.CRUISE_SPEED[emitter.kind]
	spatial._update_yelp(emitter, cruise * 0.2, true)
	_check(emitter.siren.stream.resource_path.ends_with("sirene_yelp_loop.ogg"), "hulpdienst die afremt yelpt (%s)" % emergency.name)
	spatial._update_yelp(emitter, cruise, true)
	_check(emitter.siren.stream.resource_path.ends_with(emitter.siren_name + ".ogg"), "optrekken: eigen sirene terug")
	print("hulpdienst: %s, sirene %s, voorbij %s" % [emergency.name, emitter.siren_name, spatial._pass_by_sound(emitter)])
	spatial._free_emitter(emitter)


## The voices of the characters (their cries of pain: PlayerController.cry_out).
func _voices() -> Array[String]:
	var voices: Array[String] = []
	for archetype: Dictionary in PlayerCharacter.ARCHETYPES.values():
		var voice := String(archetype.get("voice", "man"))
		if voice not in voices:
			voices.append(voice)
	return voices
