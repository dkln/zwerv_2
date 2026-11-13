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
## Sounds: assets/audio/geluiden/ (tools/megadrive/geluiden.py, docs/GELUIDEN.md).
## Test: tests/integration/world/test_spatial_audio.gd.

const SoundVariation = preload("res://scripts/audio/sound_variation.gd")
const LoadingScreen = preload("res://scripts/ui/loading_screen.gd")
const SOUND_FOLDER := "res://assets/audio/geluiden/"
const BUS_NAME := "Verkeer"
## The one-shots (horns, bells, cries, hits, splashes) have a bus of their own, with only a
## limiter: through the compressor of the traffic bus the engines around would squash them
## to their own level, and they would be lost under the traffic and the music.
const EVENT_BUS_NAME := "Voorvallen"
const LISTENER_HEIGHT := 1.7
const MAX_EMITTERS := 14
const HEARING_RANGE := 90.0
## How far outside the picture (a share of its size on every side) a sound is still heard.
const VIEW_MARGIN := 0.15
## The gentle softening with distance (distance_db).
const FULL_WITHIN := 8.0
const DB_PER_METRE := 0.2
const SOFTEST_DB := 12.0
const POOL_INTERVAL := 0.5
## Engine loop and cruising speed (m/s) per vehicle_kind; the loop's pitch is 1 at that speed.
const MOTOR_SOUNDS := {"auto": "auto_motor_loop", "brommer": "brommer_motor_loop", "bus": "bus_motor_loop",
	"tram": "tram_motor_loop", "trein": "trein_motor_loop"}
const CRUISE_SPEED := {"auto": 13.0, "brommer": 10.0, "bus": 9.0, "tram": 8.0, "trein": 20.0}
## The files are all equally loud (-16 LUFS, tools/megadrive/loudness.py), so these numbers are
## the real balance between the engines.
const MOTOR_VOLUME_DB := {"auto": -11.0, "brommer": -10.0, "bus": -10.0, "tram": -7.0, "trein": -8.0}
## How near (m) a source is at full loudness (unit_size), per kind; bigger is heard further.
const UNIT_SIZE := {"auto": 10.0, "brommer": 8.0, "bus": 14.0, "tram": 14.0, "trein": 22.0}
const IDLE_PITCH := 0.7
## Under this speed (m/s) a tram or train fades out; standing still it is silent.
const RAIL_SILENT_BELOW := 1.5
const MAX_PITCH := 1.45
const DOPPLER_BOOST := 1.6
const SPEED_OF_SOUND := 343.0
const SIREN_VOLUME_DB := -6.0
## The levels of the one-shots (the files are all equally loud: their loudest moment at -16 LUFS,
## tools/megadrive/loudness.py): what happens to you or right by you (a crash, a hit, a cry, a splash)
## loudest, the signals of the traffic (horns, bells) a little under that, what goes on in the
## background (passing by, brakes) under those.
const EVENT_DB := 1.0
const SIGNAL_DB := -1.0
const BACKGROUND_DB := -1.5
const HARD_CRASH_SPEED := 9.0
const HELICOPTER_SOUND := "helikopter_loop"
const HELICOPTER_SCRIPT := "police_helicopter.gd"
const HELICOPTER_PASS_BY := "helikopter_voorbij"
## Passing by (see the top): how near, how fast (share of the cruising speed), how much the
## loops duck meanwhile, how far it must get before it can pass again.
const PASS_BY_DISTANCE := 8.0
const HELICOPTER_PASS_BY_DISTANCE := 35.0
const PASS_BY_MIN_SHARE := 0.6
const HELICOPTER_PASS_BY_MIN_SPEED := 8.0
const PASS_BY_DUCK_DB := -14.0
const PASS_BY_REARM := 40.0
const PASS_BY_VOLUME_DB := -1.5   # BACKGROUND_DB
## The yelp (see the top): below and above which share of the cruising speed.
const YELP_SOUND := "sirene_yelp_loop"
const YELP_BELOW := 0.5
const YELP_UNTIL := 0.75
const FIRE_HORN := "brandweer_hoorn"
const HORN_CHANCE := 0.6
const HORN_PAUSE := 8.0
const PAUSED_DB := -14.0
## The level of the traffic bus as a whole, and how its peaks are held down: a compressor
## evens out the loud moments (a siren racing past, a crash next to you), a limiter keeps
## every peak under LIMITER_CEILING_DB; Master gets a limiter of its own as a last guard.
const BUS_VOLUME_DB := -3.0
const COMPRESSOR_THRESHOLD_DB := -16.0
const COMPRESSOR_RATIO := 3.0
const LIMITER_CEILING_DB := -3.0
const MASTER_CEILING_DB := -1.0

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
	return script != null and script.resource_path.ends_with(HELICOPTER_SCRIPT)


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
	AudioServer.set_bus_volume_db(_bus_index, BUS_VOLUME_DB + (PAUSED_DB if paused else 0.0))
	AudioServer.set_bus_volume_db(_event_bus_index, BUS_VOLUME_DB + (PAUSED_DB if paused else 0.0))
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
		_ear_velocity = _ear_velocity.lerp((_ear - _ear_previous) / delta, 1.0 - exp(-4.0 * delta))
	_ear_previous = _ear
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	if camera != null:
		forward = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	_listener.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), _ear)


# ----------------------------------------------------------------------------- the vehicles


func _update_pool() -> void:
	var nearby: Array = []
	for vehicle in _vehicles:
		if not is_instance_valid(vehicle) or not vehicle.is_inside_tree():
			continue
		var kind := _kind_of(vehicle)
		if kind == "":
			continue
		# only what is in view (or just outside it); the nearest first when there are too many
		if in_view(vehicle.global_position):
			nearby.append([vehicle.global_position.distance_to(_ear), vehicle])
	nearby.sort_custom(func(first, second): return first[0] < second[0])
	var wanted := {}
	for entry in nearby.slice(0, MAX_EMITTERS):
		wanted[(entry[1] as Node3D).get_instance_id()] = entry[1]
	for id in _emitters.keys():
		if not wanted.has(id):
			_free_emitter(_emitters[id])
			_emitters.erase(id)
	for id in wanted:
		if not _emitters.has(id):
			_emitters[id] = _make_emitter(wanted[id])


func _kind_of(vehicle: Node3D) -> String:
	if _is_helicopter(vehicle):
		return "helikopter"
	var kind := str(vehicle.get("vehicle_kind"))
	return kind if MOTOR_SOUNDS.has(kind) else ""


func _siren_of(vehicle: Node3D) -> String:
	var car := vehicle as Vehicle
	if car == null or not car.emergency:
		return ""
	if vehicle is Ambulance:
		return "ambulance_sirene_loop"
	if vehicle is FireEngine:
		return "brandweer_sirene_loop"
	return "politie_sirene_loop"


func _make_emitter(vehicle: Node3D) -> Emitter:
	var emitter := Emitter.new()
	emitter.vehicle = vehicle
	emitter.pitch_factor = SoundVariation.pitch(SoundVariation.LOOP_SPREAD)
	emitter.kind = _kind_of(vehicle)
	var sound_name: String = HELICOPTER_SOUND if emitter.kind == "helikopter" else MOTOR_SOUNDS[emitter.kind]
	emitter.base_db = 0.3 if emitter.kind == "helikopter" else MOTOR_VOLUME_DB[emitter.kind]
	var unit: float = 30.0 if emitter.kind == "helikopter" else UNIT_SIZE[emitter.kind]
	emitter.motor = _make_player(vehicle, sound_name, unit, emitter.base_db, true)
	emitter.siren_name = _siren_of(vehicle)
	if emitter.siren_name != "":
		emitter.siren = _make_player(vehicle, emitter.siren_name, 12.0, SIREN_VOLUME_DB, false)
	emitter.previous_position = vehicle.global_position
	# already right next to the ear when it gets its sound: no pass-by for this approach
	emitter.pass_by_armed = vehicle.global_position.distance_to(_ear) > _pass_by_distance(emitter) * 2.0
	var car := vehicle as Vehicle
	if car != null:
		emitter.was_crashed = car.crashed
		emitter.last_speed = absf(car.speed)
		emitter.was_standing = emitter.last_speed < 0.5
	return emitter


func _make_player(parent: Node3D, sound_name: String, unit: float, volume_db: float, play_now: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = "Geluid_" + sound_name
	player.stream = _stream(sound_name, true)
	player.bus = BUS_NAME
	player.unit_size = unit
	player.max_distance = HEARING_RANGE * (2.5 if sound_name == HELICOPTER_SOUND else 1.2)
	player.volume_db = volume_db
	player.attenuation_filter_db = 0.0   # no muffling with distance: only softer
	_even_out(player)
	player.position = Vector3.UP * 0.8
	parent.add_child(player)
	if play_now and player.stream != null:
		# start somewhere in the loop, so a street full of the same cars does not phase
		player.play(_random.randf() * maxf(player.stream.get_length() - 0.05, 0.0))
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
		emitter.velocity = emitter.velocity.lerp(moved, 1.0 - exp(-6.0 * delta))
	emitter.previous_position = vehicle.global_position
	_check_pass_by(emitter)
	emitter.duck = lerpf(emitter.duck, 1.0 if _clock < emitter.pass_by_until else 0.0, 1.0 - exp(-8.0 * delta))
	var duck_db := PASS_BY_DUCK_DB * emitter.duck
	var doppler := _doppler(vehicle)
	var car := vehicle as Vehicle
	if car == null:
		emitter.motor.pitch_scale = clampf(doppler * emitter.pitch_factor, 0.5, 2.0)
	else:
		var speed := absf(car.speed)
		var cruise: float = CRUISE_SPEED[emitter.kind]
		var crashed := car.crashed
		var engine_pitch := lerpf(IDLE_PITCH, 1.0, clampf(speed / cruise, 0.0, 1.0))
		if speed > cruise:
			engine_pitch = minf(MAX_PITCH, 1.0 + (speed - cruise) / cruise * 0.5)
		emitter.motor.pitch_scale = clampf(engine_pitch * doppler * emitter.pitch_factor, 0.3, 2.5)
		var idle_db := lerpf(-5.0, 0.0, clampf(speed / cruise, 0.0, 1.0))
		# a tram or a train standing still makes no sound: it fades out under RAIL_SILENT_BELOW m/s
		if emitter.kind == "tram" or emitter.kind == "trein":
			idle_db += linear_to_db(maxf(clampf(speed / RAIL_SILENT_BELOW, 0.0, 1.0), 0.0001))
		emitter.motor.volume_db = emitter.base_db + idle_db + duck_db + distance_db(vehicle.global_position)
		if crashed and not emitter.was_crashed:
			_one_shot(vehicle.global_position, "auto_botsing_hard" if emitter.last_speed > HARD_CRASH_SPEED else "auto_botsing_licht", 10.0, EVENT_DB)
		if crashed:
			emitter.motor.volume_db = -80.0
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
			emitter.siren.pitch_scale = clampf(doppler, 0.5, 2.0)
			emitter.siren.volume_db = SIREN_VOLUME_DB + duck_db + distance_db(vehicle.global_position)
	if emitter.kind == "helikopter":
		emitter.motor.volume_db = emitter.base_db + duck_db


## Little events: a bus stopping hisses, a tram pulling away rings, a train now and then hoots.
func _signals(emitter: Emitter, speed: float) -> void:
	var standing := speed < 0.5
	var position := emitter.vehicle.global_position
	if emitter.kind == "bus" and standing and not emitter.was_standing and emitter.last_speed > 0.0:
		_one_shot(position, "bus_remmen", 8.0, BACKGROUND_DB)
	if emitter.kind == "tram" and not standing and emitter.was_standing:
		_one_shot(position, "tram_bel", 10.0, SIGNAL_DB)
	if emitter.kind == "trein" and not standing and emitter.was_standing and _random.randf() < 0.5:
		_one_shot(position, "trein_hoorn", 20.0, SIGNAL_DB)
	emitter.was_standing = standing


## The yelp at a crossing: below YELP_BELOW of its cruising speed the siren swaps to the fast
## yelp, above YELP_UNTIL back to its own; a fire engine starting to yelp may blow its horn.
func _update_yelp(emitter: Emitter, speed: float, siren_on: bool) -> void:
	var cruise: float = CRUISE_SPEED[emitter.kind]
	var yelp := emitter.yelping
	if not siren_on:
		yelp = false
	elif speed < cruise * YELP_BELOW:
		yelp = true
	elif speed > cruise * YELP_UNTIL:
		yelp = false
	if yelp == emitter.yelping:
		return
	emitter.yelping = yelp
	var was_playing := emitter.siren.playing
	emitter.siren.stream = _stream(YELP_SOUND if yelp else emitter.siren_name, true)
	if was_playing:
		emitter.siren.play()
	if yelp and emitter.vehicle is FireEngine and _clock >= emitter.horn_ready_at:
		emitter.horn_ready_at = _clock + HORN_PAUSE
		if _random.randf() < HORN_CHANCE:
			_one_shot(emitter.vehicle.global_position, FIRE_HORN, 14.0, SIGNAL_DB)


func _pass_by_distance(emitter: Emitter) -> float:
	return HELICOPTER_PASS_BY_DISTANCE if emitter.kind == "helikopter" else PASS_BY_DISTANCE


## The pass-by clip of a vehicle (see the top): when it will pass the ear close enough and
## fast enough, and the nearest point is half the clip away, the clip starts on the vehicle.
func _check_pass_by(emitter: Emitter) -> void:
	var vehicle := emitter.vehicle
	var offset := vehicle.global_position - _ear
	if emitter.kind == "helikopter":
		offset.y = 0.0   # it flies over: what counts is passing overhead
	if not emitter.pass_by_armed:
		if offset.length() > PASS_BY_REARM * (2.5 if emitter.kind == "helikopter" else 1.0):
			emitter.pass_by_armed = true
		return
	if get_tree().paused:
		return
	var relative := emitter.velocity - _ear_velocity
	if emitter.kind == "helikopter":
		relative.y = 0.0
	var relative_speed := relative.length()
	var car := vehicle as Vehicle
	var fast_enough := relative_speed >= HELICOPTER_PASS_BY_MIN_SPEED
	if car != null:
		fast_enough = absf(car.speed) >= CRUISE_SPEED[emitter.kind] * PASS_BY_MIN_SHARE and relative_speed > 1.0
	if not fast_enough or (car != null and car.crashed):
		return
	var until_nearest := -offset.dot(relative) / (relative_speed * relative_speed)
	if until_nearest <= 0.0:
		return
	var miss := (offset + relative * until_nearest).length()
	if miss > _pass_by_distance(emitter):
		return
	var sound_name := _pass_by_sound(emitter)
	var stream := _stream(sound_name, false)
	if stream == null or until_nearest > stream.get_length() * 0.5:
		return
	emitter.pass_by_armed = false
	var player := AudioStreamPlayer3D.new()
	player.name = "Voorbij"
	player.stream = stream
	player.bus = BUS_NAME
	# the clip has its own swell and fade: the 3D part only places it (left/right), barely softens
	player.unit_size = 30.0 if emitter.kind == "helikopter" else 20.0
	player.max_distance = HEARING_RANGE * 2.0
	player.volume_db = PASS_BY_VOLUME_DB
	player.attenuation_filter_db = 0.0
	_even_out(player)
	player.position = Vector3.UP * 0.8
	vehicle.add_child(player)
	player.finished.connect(player.queue_free)
	# start so the loudest moment (halfway) falls on the nearest point
	var start := clampf(stream.get_length() * 0.5 - until_nearest, 0.0, stream.get_length() - 0.1)
	player.play(start)
	emitter.pass_by_until = _clock + stream.get_length() - start


func _pass_by_sound(emitter: Emitter) -> String:
	if emitter.kind == "helikopter":
		return HELICOPTER_PASS_BY
	var car := emitter.vehicle as Vehicle
	if emitter.siren_name != "" and car != null and car.siren_on:
		return emitter.siren_name.replace("_sirene_loop", "_voorbij")
	return emitter.kind + "_voorbij"


## The pitch factor of a source moving towards (above 1) or away from (below 1) the ear.
func _doppler(vehicle: Node3D) -> float:
	var velocity := Vector3.ZERO
	var car := vehicle as Vehicle
	if car != null:
		velocity = car.velocity
	var to_ear := _ear - vehicle.global_position
	var distance := to_ear.length()
	if distance < 0.5:
		return 1.0
	var direction := to_ear / distance
	var closing := (velocity.dot(direction) - _ear_velocity.dot(direction)) * DOPPLER_BOOST
	closing = clampf(closing, -SPEED_OF_SOUND * 0.5, SPEED_OF_SOUND * 0.5)
	return SPEED_OF_SOUND / (SPEED_OF_SOUND - closing)


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
	var player := AudioStreamPlayer3D.new()
	player.name = "Geluid_" + sound_name
	player.stream = stream
	player.bus = EVENT_BUS_NAME
	player.unit_size = unit
	player.max_distance = HEARING_RANGE * 1.5
	player.volume_db = volume_db
	player.attenuation_filter_db = 0.0
	_even_out(player)
	player.max_db = maxf(volume_db, 0.0)
	player.pitch_scale = SoundVariation.pitch(SoundVariation.LOOP_SPREAD)
	parent.add_child(player)
	player.play()
	return player


func play_at(at: Vector3, sound_name: String, volume_db := 0.0, unit := 8.0) -> void:
	if _active:
		_one_shot(at, sound_name, unit, volume_db)


## Distance softens a sound gently (logarithmic), and never makes it louder than its level
## close by: so what is near and what is far differ less (HEARING_RANGE).
static func _even_out(player: AudioStreamPlayer3D) -> void:
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.max_distance = 0.0
	player.max_db = 0.0


## How much softer a sound at `at` is for its distance from the ear (dB, <= 0; see the top).
func distance_db(at: Vector3) -> float:
	return -clampf((at.distance_to(_ear) - FULL_WITHIN) * DB_PER_METRE, 0.0, SOFTEST_DB)


## True if `at` is in the picture or just outside it (VIEW_MARGIN): what may make a sound.
## Without a camera: within HEARING_RANGE of the ear.
func in_view(at: Vector3) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return at.distance_to(_ear) <= HEARING_RANGE
	if camera.is_position_behind(at):
		return false
	var picture := get_viewport().get_visible_rect()
	return picture.grow_individual(picture.size.x * VIEW_MARGIN, picture.size.y * VIEW_MARGIN,
			picture.size.x * VIEW_MARGIN, picture.size.y * VIEW_MARGIN).has_point(camera.unproject_position(at))


func _one_shot(at: Vector3, sound_name: String, unit: float, volume_db: float) -> void:
	var stream := _stream(sound_name, false)
	if stream == null or not in_view(at):
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = EVENT_BUS_NAME
	player.unit_size = unit
	player.max_distance = HEARING_RANGE * 1.5
	player.volume_db = volume_db + distance_db(at)
	player.attenuation_filter_db = 0.0
	_even_out(player)
	# max_db caps volume_db too: at 0 dB a horn or a cry above 0 (EVENT_DB, SIGNAL_DB) would
	# be cut back to the level of the engines and be lost under them and the music
	player.max_db = maxf(volume_db, 0.0)
	player.pitch_scale = SoundVariation.pitch()   # never twice quite the same
	add_child(player)
	player.global_position = at + Vector3.UP
	player.finished.connect(player.queue_free)
	player.play()


func _stream(sound_name: String, looping: bool) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var path := SOUND_FOLDER + sound_name + ".ogg"
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
	_bus_index = AudioServer.get_bus_index(BUS_NAME)
	if _bus_index == -1:
		AudioServer.add_bus()
		_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_index, BUS_NAME)
		AudioServer.set_bus_send(_bus_index, "Master")
	while AudioServer.get_bus_effect_count(_bus_index) > 0:
		AudioServer.remove_bus_effect(_bus_index, 0)
	var compressor := AudioEffectCompressor.new()
	compressor.threshold = COMPRESSOR_THRESHOLD_DB
	compressor.ratio = COMPRESSOR_RATIO
	compressor.attack_us = 5000.0
	compressor.release_ms = 180.0
	compressor.gain = 0.0
	AudioServer.add_bus_effect(_bus_index, compressor)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(_bus_index, limiter)
	_event_bus_index = AudioServer.get_bus_index(EVENT_BUS_NAME)
	if _event_bus_index == -1:
		AudioServer.add_bus()
		_event_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_event_bus_index, EVENT_BUS_NAME)
		AudioServer.set_bus_send(_event_bus_index, "Master")
	while AudioServer.get_bus_effect_count(_event_bus_index) > 0:
		AudioServer.remove_bus_effect(_event_bus_index, 0)
	var event_limiter := AudioEffectHardLimiter.new()
	event_limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(_event_bus_index, event_limiter)
	AudioServer.set_bus_volume_db(_event_bus_index, BUS_VOLUME_DB)
	_guard_master()


## A limiter on Master (once), so no sound of the game ever clips.
func _guard_master() -> void:
	var master := AudioServer.get_bus_index("Master")
	for effect_index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, effect_index) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = MASTER_CEILING_DB
	AudioServer.add_bus_effect(master, limiter)


## For the test: the vehicles that have sound now.
func emitter_report() -> Array:
	var report := []
	for emitter: Emitter in _emitters.values():
		if is_instance_valid(emitter.vehicle):
			report.append({"kind": emitter.kind, "distance": emitter.vehicle.global_position.distance_to(_ear),
				"pitch": emitter.motor.pitch_scale,
				"siren": emitter.siren != null and emitter.siren.playing})
	return report
