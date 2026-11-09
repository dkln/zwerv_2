extends SceneTree
## Loads scenes/stad.tscn with its traffic and the spatial sound (scripts/audio/spatial_audio.gd,
## autoload RuimtelijkGeluid; added here when the autoload is not there), headless, and checks:
## it switches on with the player, vehicles near the ear get engine sound, a point behind a
## building is occluded and an open one is not, and the survey of the surroundings sets the echo
## and reverb of the traffic bus; every sound in assets/audio/geluiden/ is imported, loads and is
## used by the code (the cries of pain by the player, for every voice of a character); a vehicle heading past the ear gets its pass-by clip (and its loops duck);
## an emergency vehicle slowing down with its siren on switches to the yelp.
## usage: tools/godot.sh --headless --script tools/check/spatial_audio_test.gd

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
		print("  %-10s %5.1f m  afgeschermd %.2f  toon %.2f%s" % [entry.kind, entry.distance, entry.occlusion,
			entry.pitch, "  sirene" if entry.siren else ""])
	_check(spatial._vehicles.size() > 0, "voertuigen gevonden")
	_check(spatial._emitters.size() > 0, "voertuigen dichtbij hebben geluid")

	# occlusion: a point behind the first building a ray finds, and a point in the open
	var ear: Vector3 = spatial._ear
	var space := get_root().world_3d.direct_space_state
	var behind := Vector3.INF
	var open := Vector3.INF
	for ray_index in 36:
		var angle := TAU * ray_index / 36.0
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(ear + direction * 1.2, ear + direction * 80.0, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and behind == Vector3.INF and ear.distance_to(hit.position) > 6.0:
			behind = (hit.position as Vector3) + direction * 25.0
		var short := PhysicsRayQueryParameters3D.create(ear + direction * 1.2, ear + direction * 12.0, 1)
		if space.intersect_ray(short).is_empty() and open == Vector3.INF:
			open = ear + direction * 10.0
	if behind != Vector3.INF:
		var occluded: float = spatial._occlusion_of(behind)
		print("achter een gebouw: afgeschermd %.2f" % occluded)
		_check(occluded > 0.3, "achter een gebouw klinkt het gedempt")
	else:
		print("geen gebouw rondom gevonden (afscherming niet getest)")
	if open != Vector3.INF:
		var clear: float = spatial._occlusion_of(open)
		print("vrij zicht: afgeschermd %.2f" % clear)
		_check(clear < 0.34, "met vrij zicht klinkt het helder")

	var survey: Dictionary = spatial.survey
	print("omgeving: ingesloten %.2f, gemiddeld %.1f m, links %.1f m, rechts %.1f m, overdekt %s" % [
		survey.enclosure, survey.mean_distance, survey.left, survey.right, survey.covered])
	var bus := AudioServer.get_bus_index(spatial.BUS_NAME)
	var delay := AudioServer.get_bus_effect(bus, 0) as AudioEffectDelay
	var reverb := AudioServer.get_bus_effect(bus, 1) as AudioEffectReverb
	_check(delay != null and reverb != null, "echo en galm op de bus")
	if delay != null and reverb != null:
		print("galm: nat %.2f, kamer %.2f, voorvertraging %.0f ms; echo links %.0f ms %.0f dB, rechts %.0f ms %.0f dB, flutter %.0f ms %.0f dB" % [
			reverb.wet, reverb.room_size, reverb.predelay_msec, delay.tap1_delay_ms, delay.tap1_level_db,
			delay.tap2_delay_ms, delay.tap2_level_db, delay.feedback_delay_ms, delay.feedback_level_db])
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
		if sound_name in [PLAYER.BODY_HIT_SOUND, PLAYER.SPLASH_SOUND]:
			named = true
		for voice in _voices():
			var cry := sound_name.trim_prefix("pijn_%s_" % voice)
			if sound_name.begins_with("pijn_%s_" % voice) and (cry == "hard" or int(cry) in range(1, PLAYER.SHORT_CRY_COUNT + 1)):
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
	spatial._check_pass_by(emitter, spatial.OPEN_CUTOFF_HZ)
	car.speed = speed_before
	var clip := car.get_node_or_null("Voorbij") as AudioStreamPlayer3D
	_check(clip != null and clip.stream != null and clip.stream.resource_path.ends_with("auto_voorbij.ogg"),
			"auto die langsrijdt speelt auto_voorbij")
	_check(emitter.pass_by_until > spatial._clock and not emitter.pass_by_armed, "motor duikt weg tijdens het voorbijgaan")
	spatial._check_pass_by(emitter, spatial.OPEN_CUTOFF_HZ)
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
