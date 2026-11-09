extends Node
## Spatial sound of the city (autoload "RuimtelijkGeluid", project.godot): you hear where the
## traffic is, buildings in between muffle it, and the streets echo by how built-up they are.
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
## - Occlusion ("ray cast"): every OCCLUSION_INTERVAL s three rays per source go from the ear
##   to the source (straight, and from a little left and right of the ear) against the town
##   (TOWN_LAYER); the share that hits a building muffles the source (its
##   attenuation_filter_cutoff_hz from OPEN_CUTOFF_HZ down to OCCLUDED_CUTOFF_HZ) and makes it
##   OCCLUDED_DB softer, smoothly.
## - Echo and reverb: every ENVIRONMENT_INTERVAL s ENVIRONMENT_RAYS rays go round the ear
##   (ENVIRONMENT_REACH m) and one goes up. How many hit, how far, and the nearest wall on the
##   left and the right set the effects of the bus BUS_NAME (made here, sent to Master; the
##   music stays dry): a slap-back echo off the left and right facades (AudioEffectDelay, its
##   taps at the walls' echo times, panned their way, feedback as a flutter between close
##   facades), and a reverb (AudioEffectReverb) that is big and wet in a street canyon or a
##   tunnel and nearly dry on an open square or in a park. All values glide (SMOOTHING).
## - While the game is paused the traffic is PAUSED_DB softer. The bus as a whole sits at
##   BUS_VOLUME_DB with a compressor and a limiter on it (and Master a limiter), so a loud
##   moment never blasts.
## Sounds: assets/audio/geluiden/ (tools/megadrive/geluiden.py, docs/MUZIEK.md).
## Test: tools/check/spatial_audio_test.gd.

const SOUND_FOLDER := "res://assets/audio/geluiden/"
const BUS_NAME := "Verkeer"
const TOWN_LAYER := 1
const LISTENER_HEIGHT := 1.7
const MAX_EMITTERS := 14
const HEARING_RANGE := 90.0
const POOL_INTERVAL := 0.5
## Engine loop and cruising speed (m/s) per vehicle_kind; the loop's pitch is 1 at that speed.
const MOTOR_SOUNDS := {"auto": "auto_motor_loop", "brommer": "brommer_motor_loop", "bus": "bus_motor_loop",
	"tram": "tram_motor_loop", "trein": "trein_motor_loop"}
const CRUISE_SPEED := {"auto": 13.0, "brommer": 10.0, "bus": 9.0, "tram": 8.0, "trein": 20.0}
const MOTOR_VOLUME_DB := {"auto": -6.0, "brommer": -7.0, "bus": -3.0, "tram": -4.0, "trein": -1.0}
## How near (m) a source is at full loudness (unit_size), per kind; bigger is heard further.
const UNIT_SIZE := {"auto": 6.0, "brommer": 5.0, "bus": 9.0, "tram": 9.0, "trein": 14.0}
const IDLE_PITCH := 0.7
const MAX_PITCH := 1.45
const DOPPLER_BOOST := 1.6
const SPEED_OF_SOUND := 343.0
const SIREN_VOLUME_DB := -4.0
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
const PASS_BY_VOLUME_DB := -2.0
## The yelp (see the top): below and above which share of the cruising speed.
const YELP_SOUND := "sirene_yelp_loop"
const YELP_BELOW := 0.5
const YELP_UNTIL := 0.75
const FIRE_HORN := "brandweer_hoorn"
const HORN_CHANCE := 0.6
const HORN_PAUSE := 8.0
## Occlusion: how often, and what a source fully behind buildings sounds like.
const OCCLUSION_INTERVAL := 0.1
const OCCLUSION_SIDE_OFFSET := 2.0
const OPEN_CUTOFF_HZ := 9000.0
const OCCLUDED_CUTOFF_HZ := 650.0
const OCCLUDED_DB := -11.0
## The surroundings of the ear: how often, how many rays round it, how far they reach.
const ENVIRONMENT_INTERVAL := 0.25
const ENVIRONMENT_RAYS := 12
const ENVIRONMENT_REACH := 60.0
const ENVIRONMENT_HEIGHT := 2.0
const COVER_REACH := 25.0
## How fast the occlusion and the echo glide to new values (per second).
const SMOOTHING := 5.0
const PAUSED_DB := -14.0
## The level of the traffic bus as a whole, and how its peaks are held down: a compressor
## evens out the loud moments (a siren racing past, a crash next to you), a limiter keeps
## every peak under LIMITER_CEILING_DB; Master gets a limiter of its own as a last guard.
const BUS_VOLUME_DB := -6.0
const COMPRESSOR_THRESHOLD_DB := -20.0
const COMPRESSOR_RATIO := 4.0
const LIMITER_CEILING_DB := -3.0
const MASTER_CEILING_DB := -1.0

var _vehicles: Array[Node3D] = []       # every Vehicle (and the helicopter) in the tree
var _emitters := {}                     # vehicle instance id -> Emitter
var _player: Node3D                     # the PlayerController
var _listener: AudioListener3D
var _active := false
var _bus_index := -1
var _delay: AudioEffectDelay
var _reverb: AudioEffectReverb
var _streams := {}
var _pool_clock := 0.0
var _occlusion_clock := 0.0
var _environment_clock := 0.0
var _ear := Vector3.ZERO
var _ear_previous := Vector3.ZERO
var _ear_velocity := Vector3.ZERO
var _ear_right := Vector3.RIGHT
var _random := RandomNumberGenerator.new()
var _clock := 0.0                       # seconds of unpaused play (pass-by ducking, horn pause)
## What the surroundings ask of the effects (glided to in _glide_environment).
var _target := {"wet": 0.05, "room": 0.3, "predelay": 20.0, "left_ms": 120.0, "right_ms": 120.0,
	"left_db": -60.0, "right_db": -60.0, "feedback_db": -60.0, "feedback_ms": 200.0}
var _current := _target.duplicate()
## What the last survey measured (for the test and for tuning): share of rays that hit,
## mean distance, nearest wall left and right (metres; ENVIRONMENT_REACH = nothing), covered.
var survey := {"enclosure": 0.0, "mean_distance": ENVIRONMENT_REACH, "left": ENVIRONMENT_REACH,
	"right": ENVIRONMENT_REACH, "covered": false}


## The sound of one vehicle: its engine (and siren) players, smoothed occlusion, last state.
class Emitter:
	var vehicle: Node3D
	var kind := ""
	var motor: AudioStreamPlayer3D
	var siren: AudioStreamPlayer3D
	var occlusion := 0.0
	var occlusion_target := 0.0
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
	var should_run := _player != null and is_instance_valid(_player) and _player.is_inside_tree()
	if should_run != _active:
		_set_active(should_run)
	if not _active:
		return
	_update_ear(delta)
	var paused := get_tree().paused
	AudioServer.set_bus_volume_db(_bus_index, BUS_VOLUME_DB + (PAUSED_DB if paused else 0.0))
	if not paused:
		_clock += delta
	_pool_clock -= delta
	if _pool_clock <= 0.0:
		_pool_clock = POOL_INTERVAL
		_update_pool()
	_occlusion_clock -= delta
	if _occlusion_clock <= 0.0:
		_occlusion_clock = OCCLUSION_INTERVAL
		_measure_occlusion()
	_environment_clock -= delta
	if _environment_clock <= 0.0:
		_environment_clock = ENVIRONMENT_INTERVAL
		_survey_surroundings()
	var blend := 1.0 - exp(-SMOOTHING * delta)
	for emitter: Emitter in _emitters.values():
		_update_emitter(emitter, delta, blend)
	_glide_environment(blend)


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
	_ear_right = forward.cross(Vector3.UP).normalized()
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
		var distance := vehicle.global_position.distance_to(_ear)
		var reach := HEARING_RANGE * (2.5 if kind == "helikopter" else 1.0)
		if distance <= reach:
			nearby.append([distance, vehicle])
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
	emitter.kind = _kind_of(vehicle)
	var sound_name: String = HELICOPTER_SOUND if emitter.kind == "helikopter" else MOTOR_SOUNDS[emitter.kind]
	emitter.base_db = 2.0 if emitter.kind == "helikopter" else MOTOR_VOLUME_DB[emitter.kind]
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
	player.attenuation_filter_cutoff_hz = OPEN_CUTOFF_HZ
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


func _update_emitter(emitter: Emitter, delta: float, blend: float) -> void:
	var vehicle := emitter.vehicle
	if not is_instance_valid(vehicle) or emitter.motor == null or not is_instance_valid(emitter.motor):
		return
	emitter.occlusion = lerpf(emitter.occlusion, emitter.occlusion_target, blend)
	var muffle := emitter.occlusion
	var cutoff := lerpf(OPEN_CUTOFF_HZ, OCCLUDED_CUTOFF_HZ, sqrt(muffle))
	if delta > 0.0 and not get_tree().paused:
		var moved := (vehicle.global_position - emitter.previous_position) / delta
		emitter.velocity = emitter.velocity.lerp(moved, 1.0 - exp(-6.0 * delta))
	emitter.previous_position = vehicle.global_position
	_check_pass_by(emitter, cutoff)
	emitter.duck = lerpf(emitter.duck, 1.0 if _clock < emitter.pass_by_until else 0.0, 1.0 - exp(-8.0 * delta))
	var occluded_db := OCCLUDED_DB * muffle + PASS_BY_DUCK_DB * emitter.duck
	var doppler := _doppler(vehicle)
	var car := vehicle as Vehicle
	if car == null:
		emitter.motor.pitch_scale = clampf(doppler, 0.5, 2.0)
	else:
		var speed := absf(car.speed)
		var cruise: float = CRUISE_SPEED[emitter.kind]
		var crashed := car.crashed
		var engine_pitch := lerpf(IDLE_PITCH, 1.0, clampf(speed / cruise, 0.0, 1.0))
		if speed > cruise:
			engine_pitch = minf(MAX_PITCH, 1.0 + (speed - cruise) / cruise * 0.5)
		emitter.motor.pitch_scale = clampf(engine_pitch * doppler, 0.3, 2.5)
		var idle_db := lerpf(-5.0, 0.0, clampf(speed / cruise, 0.0, 1.0))
		emitter.motor.volume_db = emitter.base_db + idle_db + occluded_db
		if crashed and not emitter.was_crashed:
			_one_shot(vehicle.global_position, "auto_botsing_hard" if emitter.last_speed > HARD_CRASH_SPEED else "auto_botsing_licht", 10.0, -3.0)
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
			# a siren cuts through more
			emitter.siren.volume_db = SIREN_VOLUME_DB + OCCLUDED_DB * muffle * 0.7 + PASS_BY_DUCK_DB * emitter.duck
			emitter.siren.attenuation_filter_cutoff_hz = lerpf(OPEN_CUTOFF_HZ, OCCLUDED_CUTOFF_HZ * 2.0, sqrt(muffle))
	if emitter.kind == "helikopter":
		# it is above the roofs
		emitter.motor.volume_db = emitter.base_db + OCCLUDED_DB * muffle * 0.4 + PASS_BY_DUCK_DB * emitter.duck
	emitter.motor.attenuation_filter_cutoff_hz = cutoff


## Little events: a bus stopping hisses, a tram pulling away rings, a train now and then hoots.
func _signals(emitter: Emitter, speed: float) -> void:
	var standing := speed < 0.5
	var position := emitter.vehicle.global_position
	if emitter.kind == "bus" and standing and not emitter.was_standing and emitter.last_speed > 0.0:
		_one_shot(position, "bus_remmen", 8.0, -4.0)
	if emitter.kind == "tram" and not standing and emitter.was_standing:
		_one_shot(position, "tram_bel", 10.0, -3.0)
	if emitter.kind == "trein" and not standing and emitter.was_standing and _random.randf() < 0.5:
		_one_shot(position, "trein_hoorn", 20.0, -4.0)
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
			_one_shot(emitter.vehicle.global_position, FIRE_HORN, 14.0, -4.0)


func _pass_by_distance(emitter: Emitter) -> float:
	return HELICOPTER_PASS_BY_DISTANCE if emitter.kind == "helikopter" else PASS_BY_DISTANCE


## The pass-by clip of a vehicle (see the top): when it will pass the ear close enough and
## fast enough, and the nearest point is half the clip away, the clip starts on the vehicle.
func _check_pass_by(emitter: Emitter, cutoff: float) -> void:
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
	player.attenuation_filter_cutoff_hz = cutoff
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


## A sound from assets/audio/geluiden/ once at `at`, in the street like the traffic (muffled
## behind buildings, with the echo of the street); for others than the traffic, such as the
## player's cries of pain (PlayerController). Nothing happens outside the city.
func play_at(at: Vector3, sound_name: String, volume_db := 0.0, unit := 8.0) -> void:
	if _active:
		_one_shot(at, sound_name, unit, volume_db)


func _one_shot(at: Vector3, sound_name: String, unit: float, volume_db: float) -> void:
	var stream := _stream(sound_name, false)
	if stream == null or at.distance_to(_ear) > HEARING_RANGE * 1.5:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS_NAME
	player.unit_size = unit
	player.max_distance = HEARING_RANGE * 1.5
	player.volume_db = volume_db - 11.0 * _occlusion_of(at)
	player.attenuation_filter_cutoff_hz = lerpf(OPEN_CUTOFF_HZ, OCCLUDED_CUTOFF_HZ, sqrt(_occlusion_of(at)))
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


# ----------------------------------------------------------------------------- occlusion


func _measure_occlusion() -> void:
	for emitter: Emitter in _emitters.values():
		if is_instance_valid(emitter.vehicle):
			emitter.occlusion_target = _occlusion_of(emitter.vehicle.global_position + Vector3.UP * 1.0)


## Share (0..1) of three rays from the ear (and a little left and right of it) to `point`
## that hit a building of the town on the way.
func _occlusion_of(point: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state if get_viewport() != null else null
	if space == null:
		return 0.0
	var blocked := 0
	for side in [0.0, -OCCLUSION_SIDE_OFFSET, OCCLUSION_SIDE_OFFSET]:
		var from: Vector3 = _ear + _ear_right * float(side)
		var line := point - from
		var length := line.length()
		if length < 3.0:
			continue
		var direction := line / length
		# start clear of the player's own body, stop short of the vehicle's own collider
		var query := PhysicsRayQueryParameters3D.create(from + direction * 1.2, point - direction * 2.5, TOWN_LAYER)
		if not space.intersect_ray(query).is_empty():
			blocked += 1
	return blocked / 3.0


# ----------------------------------------------------------------------------- echo and reverb


func _ensure_bus() -> void:
	_bus_index = AudioServer.get_bus_index(BUS_NAME)
	if _bus_index == -1:
		AudioServer.add_bus()
		_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_index, BUS_NAME)
		AudioServer.set_bus_send(_bus_index, "Master")
	while AudioServer.get_bus_effect_count(_bus_index) > 0:
		AudioServer.remove_bus_effect(_bus_index, 0)
	_delay = AudioEffectDelay.new()
	_delay.dry = 1.0
	_delay.tap1_active = true
	_delay.tap2_active = true
	_delay.tap1_pan = -0.7
	_delay.tap2_pan = 0.7
	_delay.feedback_active = true
	_delay.feedback_lowpass = 3500.0
	_reverb = AudioEffectReverb.new()
	_reverb.dry = 1.0
	_reverb.damping = 0.35
	_reverb.spread = 0.8
	_reverb.hipass = 0.15
	AudioServer.add_bus_effect(_bus_index, _delay)
	AudioServer.add_bus_effect(_bus_index, _reverb)
	var compressor := AudioEffectCompressor.new()
	compressor.threshold = COMPRESSOR_THRESHOLD_DB
	compressor.ratio = COMPRESSOR_RATIO
	compressor.attack_us = 5000.0
	compressor.release_ms = 180.0
	compressor.gain = 2.0
	AudioServer.add_bus_effect(_bus_index, compressor)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(_bus_index, limiter)
	_guard_master()
	_apply_environment()


## A limiter on Master (once), so no sound of the game ever clips.
func _guard_master() -> void:
	var master := AudioServer.get_bus_index("Master")
	for effect_index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, effect_index) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = MASTER_CEILING_DB
	AudioServer.add_bus_effect(master, limiter)


## Rays round the ear and one up: how enclosed, how far the walls, a wall left and right,
## a roof overhead; turned into what the echo and the reverb should do.
func _survey_surroundings() -> void:
	var space := get_viewport().world_3d.direct_space_state
	var origin := _ear + Vector3.UP * (ENVIRONMENT_HEIGHT - LISTENER_HEIGHT)
	var hits := 0
	var distance_sum := 0.0
	var nearest_left := ENVIRONMENT_REACH
	var nearest_right := ENVIRONMENT_REACH
	var nearest := ENVIRONMENT_REACH
	for ray_index in ENVIRONMENT_RAYS:
		var angle := TAU * ray_index / ENVIRONMENT_RAYS
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(origin + direction * 1.0, origin + direction * ENVIRONMENT_REACH, TOWN_LAYER)
		var hit := space.intersect_ray(query)
		var distance := ENVIRONMENT_REACH
		if not hit.is_empty():
			hits += 1
			distance = origin.distance_to(hit.position)
		distance_sum += distance
		nearest = minf(nearest, distance)
		var side := direction.dot(_ear_right)
		if side > 0.5:
			nearest_right = minf(nearest_right, distance)
		elif side < -0.5:
			nearest_left = minf(nearest_left, distance)
	var up := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.UP * COVER_REACH, TOWN_LAYER)
	var covered := not space.intersect_ray(up).is_empty()
	var enclosure := float(hits) / ENVIRONMENT_RAYS
	var mean_distance := distance_sum / ENVIRONMENT_RAYS
	survey = {"enclosure": enclosure, "mean_distance": mean_distance, "left": nearest_left,
		"right": nearest_right, "covered": covered}

	var cover := 1.0 if covered else 0.0
	_target["wet"] = clampf(0.03 + 0.3 * enclosure + 0.3 * cover, 0.0, 0.7)
	_target["room"] = clampf(0.2 + 0.7 * mean_distance / ENVIRONMENT_REACH, 0.15, 0.95) * (0.7 if covered else 1.0)
	_target["predelay"] = clampf(2.0 * nearest / SPEED_OF_SOUND * 1000.0, 5.0, 200.0)
	for side_name in ["left", "right"]:
		var wall: float = nearest_left if side_name == "left" else nearest_right
		var strength := 1.0 - wall / ENVIRONMENT_REACH        # 0: nothing there, 1: right next to it
		_target[side_name + "_ms"] = clampf(2.0 * wall / SPEED_OF_SOUND * 1000.0, 15.0, 1500.0)
		_target[side_name + "_db"] = lerpf(-60.0, -13.0, clampf(strength, 0.0, 1.0)) if wall < ENVIRONMENT_REACH else -60.0
	var both_walls := nearest_left < ENVIRONMENT_REACH and nearest_right < ENVIRONMENT_REACH
	var street_width := nearest_left + nearest_right
	_target["feedback_ms"] = clampf(2.0 * street_width / SPEED_OF_SOUND * 1000.0, 20.0, 1500.0)
	_target["feedback_db"] = lerpf(-60.0, -16.0, clampf(1.0 - street_width / 50.0, 0.0, 1.0)) if both_walls else -60.0


func _glide_environment(blend: float) -> void:
	for key in _target:
		var slow := blend * (0.4 if key.ends_with("_ms") else 1.0)   # moving delay times warble: slower
		_current[key] = lerpf(float(_current[key]), float(_target[key]), slow)
	_apply_environment()


func _apply_environment() -> void:
	if _delay == null or _reverb == null:
		return
	_reverb.wet = _current["wet"]
	_reverb.room_size = _current["room"]
	_reverb.predelay_msec = _current["predelay"]
	_reverb.predelay_feedback = 0.25
	_delay.tap1_delay_ms = _current["left_ms"]
	_delay.tap1_level_db = _current["left_db"]
	_delay.tap2_delay_ms = _current["right_ms"]
	_delay.tap2_level_db = _current["right_db"]
	_delay.feedback_delay_ms = _current["feedback_ms"]
	_delay.feedback_level_db = _current["feedback_db"]


## For the test: how many vehicles have sound now, and their occlusion.
func emitter_report() -> Array:
	var report := []
	for emitter: Emitter in _emitters.values():
		if is_instance_valid(emitter.vehicle):
			report.append({"kind": emitter.kind, "distance": emitter.vehicle.global_position.distance_to(_ear),
				"occlusion": emitter.occlusion_target, "pitch": emitter.motor.pitch_scale,
				"siren": emitter.siren != null and emitter.siren.playing})
	return report
