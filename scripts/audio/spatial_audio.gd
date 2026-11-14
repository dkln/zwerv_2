extends Node
## Spatial sound of the city (autoload "RuimtelijkGeluid", project.godot): you hear where the
## traffic is (placed in 3D, with a Doppler shift as it comes and goes). Kept plain: no ray
## casts, no muffling behind buildings, no echo or reverb.
## Active only while a player (PlayerController) is in the tree, so: in the city, not in the
## menu or the intro. Nothing in the vehicles needs to know about it: it finds every Vehicle
## and the police helicopter itself (SceneTree.node_added) and hangs players on them.
##
## - The ear: an AudioListener3D at the player (or at the vehicle the follow camera follows),
##   LISTENER_HEIGHT up, turned with the camera (only its heading), so left and right on the
##   screen are left and right in your ears.
## - Engines: the MAX_EMITTERS vehicles nearest to the ear (within HEARING_RANGE) get an
##   AudioStreamPlayer3D with the engine loop of their kind (`vehicle_kind`: auto, brommer, bus,
##   tram, trein; bikes are silent), pitch following the speed (CRUISE_SPEED) plus a Doppler
##   shift from their speed towards the ear (DOPPLER_BOOST); emergency vehicles a second one
##   with their siren while `siren_on` (politie: PoliceCar, RiotVan; ambulance; brandweer:
##   FireEngine). A vehicle that crashes gives a crash (hard above HARD_CRASH_SPEED); a bus
##   that stops hisses its brakes, a tram pulling away rings its bell, a train now and then
##   sounds its horn. The helicopter has its rotor loop.
## - Passing by: a vehicle that will pass the ear closer than PASS_BY_DISTANCE (the helicopter
##   HELICOPTER_PASS_BY_DISTANCE) at PASS_BY_MIN_SHARE of its cruising speed or more plays its
##   `<kind>_voorbij` (an emergency vehicle with its siren on: politie/ambulance/brandweer_voorbij,
##   the helicopter helikopter_voorbij), started so its loudest moment (halfway) falls on the
##   nearest point; meanwhile its engine loop and siren duck PASS_BY_DUCK_DB (the clip has the
##   Doppler baked in). Once per approach: it can pass again when it is PASS_BY_REARM m away.
## - Yelp: an emergency vehicle with its siren on that slows down below YELP_BELOW of its
##   cruising speed (braking for a crossing, stuck in traffic) switches to the fast yelp
##   (sirene_yelp_loop) and back to its own siren above YELP_UNTIL; a fire engine that starts
##   yelping blows its air horn (brandweer_hoorn) with HORN_CHANCE, at most every HORN_PAUSE s.
## - Distance: not Godot's own softening (_even_out: off), but a gentle one of its own
##   (distance_db): full up to FULL_WITHIN m from the ear, then DB_PER_METRE softer, at most
##   SOFTEST_DB; placed left or right. What makes a sound is what is in view or just outside
##   it (in_view: the picture grown by VIEW_MARGIN on every side), the rest is silent.
## - While the game is paused the traffic is PAUSED_DB softer. The bus as a whole sits at
##   BUS_VOLUME_DB with a compressor and a limiter on it (and Master a limiter), so a loud
##   moment never blasts.
## This is the behaviour layer: the ear, the players on the vehicles and the buses, over
## time. What plays for which kind, how loud, at what pitch and when (the yelp, passing by,
## the signals) are plain sums in the rules layer (spatial_audio_rules.gd); sound has no view
## and no layout.
## Sounds: assets/audio/geluiden/ (tools/megadrive/geluiden.py, docs/GELUIDEN.md).
## Test: tests/integration/world/test_spatial_audio.gd.

const SoundVariation = preload("res://scripts/audio/sound_variation.gd")
const LoadingScreen = preload("res://scripts/ui/loading_screen.gd")
const SoundFiles = preload("res://scripts/audio/sound_files.gd")
const SpatialAudioRules = preload("res://scripts/audio/spatial_audio_rules.gd")
const SOUND_FOLDER := "res://assets/audio/geluiden/"
## How high (m) above a vehicle its players hang, and a one-shot above its place.
const PLAYER_ABOVE := Vector3.UP * 0.8
const ONE_SHOT_ABOVE := Vector3.UP
## The kinds, the levels and the numbers are the rules' (SpatialAudioRules); here under
## their old names for whoever uses the sound (the vehicles, the tests).
const BUS_NAME := SpatialAudioRules.BUS_NAME
const EVENT_BUS_NAME := SpatialAudioRules.EVENT_BUS_NAME
const LISTENER_HEIGHT := SpatialAudioRules.LISTENER_HEIGHT
const MAX_EMITTERS := SpatialAudioRules.MAX_EMITTERS
const HEARING_RANGE := SpatialAudioRules.HEARING_RANGE
const VIEW_MARGIN := SpatialAudioRules.VIEW_MARGIN
const FULL_WITHIN := SpatialAudioRules.FULL_WITHIN
const DB_PER_METRE := SpatialAudioRules.DB_PER_METRE
const SOFTEST_DB := SpatialAudioRules.SOFTEST_DB
const POOL_INTERVAL := SpatialAudioRules.POOL_INTERVAL
const MOTOR_SOUNDS := SpatialAudioRules.MOTOR_SOUNDS
const CRUISE_SPEED := SpatialAudioRules.CRUISE_SPEED
const MOTOR_VOLUME_DB := SpatialAudioRules.MOTOR_VOLUME_DB
const UNIT_SIZE := SpatialAudioRules.UNIT_SIZE
const IDLE_PITCH := SpatialAudioRules.IDLE_PITCH
const RAIL_SILENT_BELOW := SpatialAudioRules.RAIL_SILENT_BELOW
const MAX_PITCH := SpatialAudioRules.MAX_PITCH
const DOPPLER_BOOST := SpatialAudioRules.DOPPLER_BOOST
const SPEED_OF_SOUND := SpatialAudioRules.SPEED_OF_SOUND
const SIREN_VOLUME_DB := SpatialAudioRules.SIREN_VOLUME_DB
const EVENT_DB := SpatialAudioRules.EVENT_DB
const SIGNAL_DB := SpatialAudioRules.SIGNAL_DB
const BACKGROUND_DB := SpatialAudioRules.BACKGROUND_DB
const HARD_CRASH_SPEED := SpatialAudioRules.HARD_CRASH_SPEED
const HELICOPTER_SOUND := SpatialAudioRules.HELICOPTER_SOUND
const HELICOPTER_SCRIPT := SpatialAudioRules.HELICOPTER_SCRIPT
const HELICOPTER_PASS_BY := SpatialAudioRules.HELICOPTER_PASS_BY
const PASS_BY_DISTANCE := SpatialAudioRules.PASS_BY_DISTANCE
const HELICOPTER_PASS_BY_DISTANCE := SpatialAudioRules.HELICOPTER_PASS_BY_DISTANCE
const PASS_BY_MIN_SHARE := SpatialAudioRules.PASS_BY_MIN_SHARE
const HELICOPTER_PASS_BY_MIN_SPEED := SpatialAudioRules.HELICOPTER_PASS_BY_MIN_SPEED
const PASS_BY_DUCK_DB := SpatialAudioRules.PASS_BY_DUCK_DB
const PASS_BY_REARM := SpatialAudioRules.PASS_BY_REARM
const PASS_BY_VOLUME_DB := SpatialAudioRules.PASS_BY_VOLUME_DB
const YELP_SOUND := SpatialAudioRules.YELP_SOUND
const YELP_BELOW := SpatialAudioRules.YELP_BELOW
const YELP_UNTIL := SpatialAudioRules.YELP_UNTIL
const FIRE_HORN := SpatialAudioRules.FIRE_HORN
const HORN_CHANCE := SpatialAudioRules.HORN_CHANCE
const HORN_PAUSE := SpatialAudioRules.HORN_PAUSE
const PAUSED_DB := SpatialAudioRules.PAUSED_DB
const BUS_VOLUME_DB := SpatialAudioRules.BUS_VOLUME_DB
const COMPRESSOR_THRESHOLD_DB := SpatialAudioRules.COMPRESSOR_THRESHOLD_DB
const COMPRESSOR_RATIO := SpatialAudioRules.COMPRESSOR_RATIO
const LIMITER_CEILING_DB := SpatialAudioRules.LIMITER_CEILING_DB
const MASTER_CEILING_DB := SpatialAudioRules.MASTER_CEILING_DB

var _vehicles: Array[Node3D] = []       # every Vehicle (and the helicopter) in the tree
var _emitters := {}                     # vehicle instance id -> Emitter
var _player: Node3D                     # the PlayerController
var _listener: AudioListener3D
var _active := false
var _bus_index := -1
var _event_bus_index := -1
var _streams := {}
var _pool_clock := 0.0
var _ear := Vector3.ZERO
var _ear_previous := Vector3.ZERO
var _ear_velocity := Vector3.ZERO
var _random := RandomNumberGenerator.new()
var _clock := 0.0                       # seconds of unpaused play (pass-by ducking, horn pause)


## The sound of one vehicle: its engine (and siren) players, its last state.
class Emitter:
	var vehicle: Node3D
	var kind := ""
	var motor: AudioStreamPlayer3D
	var siren: AudioStreamPlayer3D
	var pitch_factor := 1.0             # the engine's own pitch (SoundVariation.LOOP_SPREAD)
	var base_db := 0.0
	var last_speed := 0.0
	var was_crashed := false
	var was_standing := false
	var siren_name := ""                # its own siren loop (the yelp swaps in and out)
	var yelping := false
	var horn_ready_at := 0.0
	var pass_by_armed := true
	var pass_by_until := -1.0           # _clock until which its pass-by clip plays
	var duck := 0.0                     # 0..1, how far its loops are ducked for the clip
	var previous_position := Vector3.ZERO
	var velocity := Vector3.ZERO        # measured (the helicopter has no speed of its own)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_random.randomize()


func _on_node_added(node: Node) -> void:
	if (node is Vehicle or _is_helicopter(node)) and not _vehicles.has(node):
		_vehicles.append(node as Node3D)
		node.tree_exiting.connect(_forget.bind(node), CONNECT_ONE_SHOT)
	elif node is PlayerController:
		_player = node as Node3D
		node.tree_exiting.connect(_player_left.bind(node), CONNECT_ONE_SHOT)


func _forget(node: Node) -> void:
	_vehicles.erase(node)
	var id := node.get_instance_id()
	if _emitters.has(id):
		_emitters.erase(id)   # its players are its children: they go with it


func _player_left(node: Node) -> void:
	if _player == node:
		_player = null


func _is_helicopter(node: Node) -> bool:
	var script := node.get_script() as Script
	return script != null and SpatialAudioRules.is_helicopter_script(script.resource_path)


func _process(delta: float) -> void:
	# not while the town is loading: then only the waiting music plays
	var should_run := _player != null and is_instance_valid(_player) and _player.is_inside_tree() \
			and not LoadingScreen.showing(get_tree())
	if should_run != _active:
		_set_active(should_run)
	if not _active:
		return
	_update_ear(delta)
	var paused := get_tree().paused
	AudioServer.set_bus_volume_db(_bus_index, SpatialAudioRules.bus_volume_db(paused))
	AudioServer.set_bus_volume_db(_event_bus_index, SpatialAudioRules.bus_volume_db(paused))
	if not paused:
		_clock += delta
	_pool_clock -= delta
	if _pool_clock <= 0.0:
		_pool_clock = POOL_INTERVAL
		_update_pool()
	for emitter: Emitter in _emitters.values():
		_update_emitter(emitter, delta)


func _set_active(on: bool) -> void:
	_active = on
	if on:
		_ensure_bus()
		if _listener == null:
			_listener = AudioListener3D.new()
			_listener.name = "Oor"
			add_child(_listener)
		_listener.make_current()
		_ear_previous = _focus()
		_pool_clock = 0.0
	else:
		for emitter: Emitter in _emitters.values():
			_free_emitter(emitter)
		_emitters.clear()
		if _listener != null:
			_listener.clear_current()


# ----------------------------------------------------------------------------- the ear


## Where the player is: the vehicle the follow camera follows, else the PlayerController.
func _focus() -> Vector3:
	var scene := _player.get_parent()
	var follow := scene.get_node_or_null("Volgcamera") if scene != null else null
	if follow != null and follow.has_method("is_following") and follow.is_following():
		var followed: Node3D = follow.get("target_node")
		if followed != null and is_instance_valid(followed):
			return followed.global_position
	return _player.global_position


func _update_ear(delta: float) -> void:
	_ear = _focus() + Vector3.UP * LISTENER_HEIGHT
	if delta > 0.0:
		_ear_velocity = _ear_velocity.lerp((_ear - _ear_previous) / delta,
				SpatialAudioRules.follow_weight(SpatialAudioRules.EAR_FOLLOW, delta))
	_ear_previous = _ear
	var camera := get_viewport().get_camera_3d()
	var forward := SpatialAudioRules.heading(-camera.global_basis.z if camera != null else Vector3.FORWARD)
	_listener.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), _ear)


# ----------------------------------------------------------------------------- the vehicles


func _update_pool() -> void:
	var nearby: Array = []
	var by_id := {}
	for vehicle in _vehicles:
		if not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
			continue
		if _kind_of(vehicle) == "":
			continue
		# only what is in view (or just outside it); the nearest first when there are too many
		if in_view(vehicle.global_position):
			nearby.append([vehicle.global_position.distance_to(_ear), vehicle.get_instance_id()])
			by_id[vehicle.get_instance_id()] = vehicle
	var wanted := SpatialAudioRules.nearest_ids(nearby)
	for id in _emitters.keys():
		if not wanted.has(id):
			_free_emitter(_emitters[id])
			_emitters.erase(id)
	for id in wanted:
		if not _emitters.has(id):
			_emitters[id] = _make_emitter(by_id[id])


func _kind_of(vehicle: Node3D) -> String:
	return SpatialAudioRules.kind_of(str(vehicle.get("vehicle_kind")), _is_helicopter(vehicle))


func _siren_of(vehicle: Node3D) -> String:
	var car := vehicle as Vehicle
	return SpatialAudioRules.siren_sound(car != null and car.emergency, _service_of(vehicle))


## The emergency service a vehicle drives for (SpatialAudioRules.siren_sound).
func _service_of(vehicle: Node3D) -> String:
	if vehicle is Ambulance:
		return "ambulance"
	return "brandweer" if vehicle is FireEngine else "politie"


func _make_emitter(vehicle: Node3D) -> Emitter:
	var emitter := Emitter.new()
	emitter.vehicle = vehicle
	emitter.pitch_factor = SoundVariation.pitch(SoundVariation.LOOP_SPREAD)
	emitter.kind = _kind_of(vehicle)
	emitter.base_db = SpatialAudioRules.motor_base_db(emitter.kind)
	emitter.motor = _make_player(vehicle, SpatialAudioRules.motor_sound(emitter.kind),
			SpatialAudioRules.motor_unit(emitter.kind), emitter.base_db, true)
	emitter.siren_name = _siren_of(vehicle)
	if emitter.siren_name != "":
		emitter.siren = _make_player(vehicle, emitter.siren_name, SpatialAudioRules.SIREN_UNIT_SIZE, SIREN_VOLUME_DB, false)
	emitter.previous_position = vehicle.global_position
	# already right next to the ear when it gets its sound: no pass-by for this approach
	emitter.pass_by_armed = SpatialAudioRules.armed_at_start(emitter.kind, vehicle.global_position.distance_to(_ear))
	var car := vehicle as Vehicle
	if car != null:
		emitter.was_crashed = car.crashed
		emitter.last_speed = absf(car.speed)
		emitter.was_standing = SpatialAudioRules.is_standing(emitter.last_speed)
	return emitter


## A player of a loop on a vehicle (its engine, its siren), on the traffic bus.
func _make_player(parent: Node3D, sound_name: String, unit: float, volume_db: float, play_now: bool) -> AudioStreamPlayer3D:
	var player := _new_player(_stream(sound_name, true), BUS_NAME, unit, volume_db)
	player.name = "Geluid_" + sound_name
	player.position = PLAYER_ABOVE
	parent.add_child(player)
	if play_now and player.stream != null:
		# start somewhere in the loop, so a street full of the same cars does not phase
		player.play(SpatialAudioRules.loop_start(_random.randf(), player.stream.get_length()))
	return player


## A player of `stream` on `bus`, at `volume_db`, softened by distance in its own way only
## (_even_out), not yet in the tree.
func _new_player(stream: AudioStream, bus: String, unit: float, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.unit_size = unit
	player.volume_db = volume_db
	player.attenuation_filter_db = 0.0   # no muffling with distance: only softer
	_even_out(player)
	return player


func _free_emitter(emitter: Emitter) -> void:
	for player in [emitter.motor, emitter.siren]:
		if player != null and is_instance_valid(player):
			player.queue_free()


func _update_emitter(emitter: Emitter, delta: float) -> void:
	var vehicle := emitter.vehicle
	if not is_instance_valid(vehicle) or emitter.motor == null or not is_instance_valid(emitter.motor):
		return
	if delta > 0.0 and not get_tree().paused:
		var moved := (vehicle.global_position - emitter.previous_position) / delta
		emitter.velocity = emitter.velocity.lerp(moved, SpatialAudioRules.follow_weight(SpatialAudioRules.VEHICLE_FOLLOW, delta))
	emitter.previous_position = vehicle.global_position
	_check_pass_by(emitter)
	emitter.duck = lerpf(emitter.duck, 1.0 if _clock < emitter.pass_by_until else 0.0,
			SpatialAudioRules.follow_weight(SpatialAudioRules.DUCK_FOLLOW, delta))
	var duck_db := SpatialAudioRules.duck_db(emitter.duck)
	var doppler := _doppler(vehicle)
	var car := vehicle as Vehicle
	if car == null:
		emitter.motor.pitch_scale = SpatialAudioRules.helicopter_pitch(doppler, emitter.pitch_factor)
	else:
		_update_car(emitter, car, duck_db, doppler)
	if emitter.kind == SpatialAudioRules.HELICOPTER_KIND:
		emitter.motor.volume_db = SpatialAudioRules.helicopter_volume_db(emitter.base_db, duck_db)


## The engine, the crash, the signals and the siren of a car, a bus, a tram or a train.
func _update_car(emitter: Emitter, car: Vehicle, duck_db: float, doppler: float) -> void:
	var speed := absf(car.speed)
	var cruise: float = CRUISE_SPEED[emitter.kind]
	var crashed := car.crashed
	var softer_db := distance_db(car.global_position)
	emitter.motor.pitch_scale = SpatialAudioRules.motor_pitch(speed, cruise, doppler, emitter.pitch_factor)
	if SpatialAudioRules.just_crashed(crashed, emitter.was_crashed):
		_one_shot(car.global_position, SpatialAudioRules.crash_sound(emitter.last_speed), SpatialAudioRules.CRASH_UNIT, EVENT_DB)
	emitter.motor.volume_db = SpatialAudioRules.motor_volume_db(emitter.kind, emitter.base_db, speed, cruise, duck_db, softer_db, crashed)
	_signals(emitter, speed)
	emitter.was_crashed = crashed
	emitter.last_speed = speed
	if emitter.siren != null and is_instance_valid(emitter.siren):
		var wants_siren := car.siren_on and not crashed
		_update_yelp(emitter, speed, wants_siren)
		if wants_siren and not emitter.siren.playing:
			emitter.siren.play()
		elif not wants_siren and emitter.siren.playing:
			emitter.siren.stop()
		emitter.siren.pitch_scale = SpatialAudioRules.siren_pitch(doppler)
		emitter.siren.volume_db = SpatialAudioRules.siren_volume_db(duck_db, softer_db)


## Little events: a bus stopping hisses, a tram pulling away rings, a train now and then hoots.
func _signals(emitter: Emitter, speed: float) -> void:
	var standing := SpatialAudioRules.is_standing(speed)
	var position := emitter.vehicle.global_position
	if SpatialAudioRules.bus_brakes(emitter.kind, standing, emitter.was_standing, emitter.last_speed):
		_one_shot(position, SpatialAudioRules.BUS_BRAKES, SpatialAudioRules.BUS_BRAKES_UNIT, BACKGROUND_DB)
	if SpatialAudioRules.tram_rings(emitter.kind, standing, emitter.was_standing):
		_one_shot(position, SpatialAudioRules.TRAM_BELL, SpatialAudioRules.TRAM_BELL_UNIT, SIGNAL_DB)
	if SpatialAudioRules.train_may_hoot(emitter.kind, standing, emitter.was_standing) \
			and SpatialAudioRules.chance_hits(_random.randf(), SpatialAudioRules.TRAIN_HORN_CHANCE):
		_one_shot(position, SpatialAudioRules.TRAIN_HORN, SpatialAudioRules.TRAIN_HORN_UNIT, SIGNAL_DB)
	emitter.was_standing = standing


## The yelp at a crossing: below YELP_BELOW of its cruising speed the siren swaps to the fast
## yelp, above YELP_UNTIL back to its own; a fire engine starting to yelp may blow its horn.
func _update_yelp(emitter: Emitter, speed: float, siren_on: bool) -> void:
	var yelp := SpatialAudioRules.yelps(emitter.yelping, speed, CRUISE_SPEED[emitter.kind], siren_on)
	if yelp == emitter.yelping:
		return
	emitter.yelping = yelp
	var was_playing := emitter.siren.playing
	emitter.siren.stream = _stream(SpatialAudioRules.siren_loop(yelp, emitter.siren_name), true)
	if was_playing:
		emitter.siren.play()
	if SpatialAudioRules.horn_may_blow(yelp, emitter.vehicle is FireEngine, _clock, emitter.horn_ready_at):
		emitter.horn_ready_at = SpatialAudioRules.horn_ready_after(_clock)
		if SpatialAudioRules.chance_hits(_random.randf(), HORN_CHANCE):
			_one_shot(emitter.vehicle.global_position, FIRE_HORN, SpatialAudioRules.FIRE_HORN_UNIT, SIGNAL_DB)


func _pass_by_distance(emitter: Emitter) -> float:
	return SpatialAudioRules.pass_by_distance(emitter.kind)


## The pass-by clip of a vehicle (see the top): when it will pass the ear close enough and
## fast enough, and the nearest point is half the clip away, the clip starts on the vehicle.
func _check_pass_by(emitter: Emitter) -> void:
	var vehicle := emitter.vehicle
	var offset := SpatialAudioRules.passing_part(emitter.kind, vehicle.global_position - _ear)
	if not emitter.pass_by_armed:
		if SpatialAudioRules.rearms(emitter.kind, offset.length()):
			emitter.pass_by_armed = true
		return
	if get_tree().paused:
		return
	var relative := SpatialAudioRules.passing_part(emitter.kind, emitter.velocity - _ear_velocity)
	var car := vehicle as Vehicle
	var fast_enough := SpatialAudioRules.helicopter_fast_enough(relative.length())
	if car != null:
		fast_enough = SpatialAudioRules.car_fast_enough(emitter.kind, car.speed, relative.length())
	if not fast_enough or (car != null and car.crashed):
		return
	if not SpatialAudioRules.passes(emitter.kind, offset, relative):
		return
	var until_nearest := SpatialAudioRules.seconds_until_nearest(offset, relative)
	var stream := _stream(_pass_by_sound(emitter), false)
	if stream == null or not SpatialAudioRules.clip_in_reach(until_nearest, stream.get_length()):
		return
	emitter.pass_by_armed = false
	# start so the loudest moment (halfway) falls on the nearest point
	var start := SpatialAudioRules.pass_by_start(stream.get_length(), until_nearest)
	_play_pass_by(vehicle, stream, SpatialAudioRules.pass_by_unit(emitter.kind), start)
	emitter.pass_by_until = _clock + stream.get_length() - start


## The pass-by clip `stream` on `vehicle`, from `start` s in; gone when it is over.
func _play_pass_by(vehicle: Node3D, stream: AudioStream, unit: float, start: float) -> void:
	# the clip has its own swell and fade: the 3D part only places it (left/right), barely softens
	var player := _new_player(stream, BUS_NAME, unit, PASS_BY_VOLUME_DB)
	player.name = "Voorbij"
	player.position = PLAYER_ABOVE
	vehicle.add_child(player)
	player.finished.connect(player.queue_free)
	player.play(start)


func _pass_by_sound(emitter: Emitter) -> String:
	var car := emitter.vehicle as Vehicle
	return SpatialAudioRules.pass_by_sound(emitter.kind, emitter.siren_name, car != null and car.siren_on)


## The pitch factor of a source moving towards (above 1) or away from (below 1) the ear.
func _doppler(vehicle: Node3D) -> float:
	var car := vehicle as Vehicle
	var velocity := car.velocity if car != null else Vector3.ZERO
	return SpatialAudioRules.doppler(velocity, _ear_velocity, _ear - vehicle.global_position)


## A sound from assets/audio/geluiden/ once at `at`, placed in 3D like the traffic; for others
## than the traffic, such as the player's cries of pain (PlayerController). Nothing happens
## outside the city.
## Something that happens to you or right by you (a hit, a cry, a splash): at EVENT_DB.
func play_event(at: Vector3, sound_name: String, unit := 8.0) -> void:
	play_at(at, sound_name, EVENT_DB, unit)


## A signal of the traffic (a horn, a bell): at SIGNAL_DB.
func play_signal(at: Vector3, sound_name: String, unit := 8.0) -> void:
	play_at(at, sound_name, SIGNAL_DB, unit)


## A sound looping on `parent` (a fire on a wreck: VehicleFire), on the bus of the one-shots
## (no compressor), softer with distance as the rest; returns its player (set its volume_db,
## free it with the parent), or null outside the city or without the file.
func attach_loop(parent: Node3D, sound_name: String, unit := 10.0, volume_db := 0.0) -> AudioStreamPlayer3D:
	var stream := _stream(sound_name, true)
	if stream == null or parent == null:
		return null
	var player := _new_player(stream, EVENT_BUS_NAME, unit, volume_db)
	player.name = "Geluid_" + sound_name
	player.max_db = SpatialAudioRules.one_shot_max_db(volume_db)
	player.pitch_scale = SoundVariation.pitch(SoundVariation.LOOP_SPREAD)
	parent.add_child(player)
	player.play()
	return player


func play_at(at: Vector3, sound_name: String, volume_db := 0.0, unit := 8.0) -> void:
	if _active:
		_one_shot(at, sound_name, unit, volume_db)


## Godot's own softening with distance is off (distance_db does it, gently), and a sound is
## never louder than its level close by.
static func _even_out(player: AudioStreamPlayer3D) -> void:
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.max_distance = 0.0
	player.max_db = 0.0


## How much softer a sound at `at` is for its distance from the ear (dB, <= 0; see the top).
func distance_db(at: Vector3) -> float:
	return SpatialAudioRules.distance_db(at.distance_to(_ear))


## True if `at` is in the picture or just outside it (VIEW_MARGIN): what may make a sound.
## Without a camera: within HEARING_RANGE of the ear.
func in_view(at: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return SpatialAudioRules.within_hearing(at.distance_to(_ear))
	if camera.is_position_behind(at):
		return false
	return SpatialAudioRules.in_picture(get_viewport().get_visible_rect(), camera.unproject_position(at))


func _one_shot(at: Vector3, sound_name: String, unit: float, volume_db: float) -> void:
	var stream := _stream(sound_name, false)
	if stream == null or not in_view(at):
		return
	var player := _new_player(stream, EVENT_BUS_NAME, unit, volume_db + distance_db(at))
	# max_db caps volume_db too: at 0 dB a horn or a cry above 0 (EVENT_DB, SIGNAL_DB) would
	# be cut back to the level of the engines and be lost under them and the music
	player.max_db = SpatialAudioRules.one_shot_max_db(volume_db)
	player.pitch_scale = SoundVariation.pitch()   # never twice quite the same
	add_child(player)
	player.global_position = at + ONE_SHOT_ABOVE
	player.finished.connect(player.queue_free)
	player.play()


func _stream(sound_name: String, looping: bool) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var path := SoundFiles.path_of(sound_name)   # in its category's folder
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		push_warning("spatial_audio: no sound %s" % path)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = looping
	_streams[sound_name] = stream
	return stream


# ----------------------------------------------------------------------------- the bus


func _ensure_bus() -> void:
	_bus_index = _bus(BUS_NAME)
	var compressor := AudioEffectCompressor.new()
	compressor.threshold = COMPRESSOR_THRESHOLD_DB
	compressor.ratio = COMPRESSOR_RATIO
	compressor.attack_us = 5000.0
	compressor.release_ms = 180.0
	compressor.gain = 0.0
	AudioServer.add_bus_effect(_bus_index, compressor)
	_add_limiter(_bus_index, LIMITER_CEILING_DB)
	_event_bus_index = _bus(EVENT_BUS_NAME)
	_add_limiter(_event_bus_index, LIMITER_CEILING_DB)
	AudioServer.set_bus_volume_db(_event_bus_index, BUS_VOLUME_DB)
	_guard_master()


## The index of the bus `bus_name` (made when it is not there yet, sending to Master),
## without the effects it had.
func _bus(bus_name: String) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, "Master")
	while AudioServer.get_bus_effect_count(bus_index) > 0:
		AudioServer.remove_bus_effect(bus_index, 0)
	return bus_index


## A limiter on the bus `bus_index` that keeps every peak under `ceiling_db`.
func _add_limiter(bus_index: int, ceiling_db: float) -> void:
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = ceiling_db
	AudioServer.add_bus_effect(bus_index, limiter)


## A limiter on Master (once), so no sound of the game ever clips.
func _guard_master() -> void:
	var master := AudioServer.get_bus_index("Master")
	for effect_index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, effect_index) is AudioEffectHardLimiter:
			return
	_add_limiter(master, MASTER_CEILING_DB)


## For the test: the vehicles that have sound now.
func emitter_report() -> Array:
	var report := []
	for emitter: Emitter in _emitters.values():
		if is_instance_valid(emitter.vehicle):
			report.append({"kind": emitter.kind, "distance": emitter.vehicle.global_position.distance_to(_ear),
				"pitch": emitter.motor.pitch_scale,
				"siren": emitter.siren != null and emitter.siren.playing})
	return report
