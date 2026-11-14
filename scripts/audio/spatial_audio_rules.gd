extends RefCounted
## The logic of the spatial sound of the city (the rules layer of
## scripts/audio/spatial_audio.gd, which is the behaviour: the ear, the players on the
## vehicles, the buses; sound has no view and no layout): which sound belongs to which kind
## of vehicle and how loud, the pitch of an engine for its speed, the Doppler shift, how
## much softer a sound is for its distance, what is in the picture, which vehicles get a
## sound, when a siren yelps, when a vehicle passes by and where its clip starts, the little
## signals of the traffic. Plain data and sums, without players, the tree or draws.
##   const SpatialAudioRules = preload("res://scripts/audio/spatial_audio_rules.gd")

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
## How much softer (dB) an engine is standing still than at its cruising speed.
const IDLE_DB := -5.0
## Under this speed (m/s) a vehicle counts as standing still (the signals).
const STANDING_BELOW := 0.5
## Under this speed (m/s) a tram or train fades out; standing still it is silent.
const RAIL_SILENT_BELOW := 1.5
const RAIL_KINDS := ["tram", "trein"]
const MAX_PITCH := 1.45
const DOPPLER_BOOST := 1.6
const SPEED_OF_SOUND := 343.0
## Nearer to the ear than this (m) a source has no Doppler shift.
const DOPPLER_FROM := 0.5
const SIREN_VOLUME_DB := -6.0
const SIREN_UNIT_SIZE := 12.0
## The sirens per service (siren_sound); the police's is the one of every other emergency vehicle.
const SIREN_SOUNDS := {"ambulance": "ambulance_sirene_loop", "brandweer": "brandweer_sirene_loop",
	"politie": "politie_sirene_loop"}
const SIREN_SUFFIX := "_sirene_loop"
const PASS_BY_SUFFIX := "_voorbij"
## The levels of the one-shots (the files are all equally loud: their loudest moment at -16 LUFS,
## tools/megadrive/loudness.py): what happens to you or right by you (a crash, a hit, a cry, a splash)
## loudest, the signals of the traffic (horns, bells) a little under that, what goes on in the
## background (passing by, brakes) under those.
const EVENT_DB := 1.0
const SIGNAL_DB := -1.0
const BACKGROUND_DB := -1.5
const HARD_CRASH_SPEED := 9.0
const HARD_CRASH_SOUND := "auto_botsing_hard"
const LIGHT_CRASH_SOUND := "auto_botsing_licht"
const CRASH_UNIT := 10.0
## A wreck's engine is silent.
const CRASHED_DB := -80.0
## The little signals of the traffic: their sound and how near (m) they are at full loudness.
const BUS_BRAKES := "bus_remmen"
const BUS_BRAKES_UNIT := 8.0
const TRAM_BELL := "tram_bel"
const TRAM_BELL_UNIT := 10.0
const TRAIN_HORN := "trein_hoorn"
const TRAIN_HORN_UNIT := 20.0
## The chance that a train pulling away sounds its horn.
const TRAIN_HORN_CHANCE := 0.5
const HELICOPTER_KIND := "helikopter"
const HELICOPTER_SOUND := "helikopter_loop"
const HELICOPTER_SCRIPT := "police_helicopter.gd"
const HELICOPTER_PASS_BY := "helikopter_voorbij"
const HELICOPTER_VOLUME_DB := 0.3
const HELICOPTER_UNIT_SIZE := 30.0
## Passing by (see spatial_audio.gd): how near, how fast (share of the cruising speed), how
## much the loops duck meanwhile, how far it must get before it can pass again.
const PASS_BY_DISTANCE := 8.0
const HELICOPTER_PASS_BY_DISTANCE := 35.0
const PASS_BY_MIN_SHARE := 0.6
const HELICOPTER_PASS_BY_MIN_SPEED := 8.0
const PASS_BY_DUCK_DB := -14.0
const PASS_BY_REARM := 40.0
const PASS_BY_VOLUME_DB := -1.5   # BACKGROUND_DB
const PASS_BY_UNIT := 20.0
## How fast the measured speed of the ear and of a vehicle, and the ducking, follow (per second).
const EAR_FOLLOW := 4.0
const VEHICLE_FOLLOW := 6.0
const DUCK_FOLLOW := 8.0
## The yelp (see spatial_audio.gd): below and above which share of the cruising speed.
const YELP_SOUND := "sirene_yelp_loop"
const YELP_BELOW := 0.5
const YELP_UNTIL := 0.75
const FIRE_HORN := "brandweer_hoorn"
const FIRE_HORN_UNIT := 14.0
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


# ------------------------------------------------------------------ the ear and the picture

## The level (dB) of the buses of the traffic and the one-shots: softer while the game is paused.
static func bus_volume_db(paused: bool) -> float:
	return BUS_VOLUME_DB + (PAUSED_DB if paused else 0.0)


## How far (0..1) something that follows at `rate` per second gets to where it is going in
## `delta` s.
static func follow_weight(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


## The way the ear faces for a camera looking along `camera_forward`: only its heading (flat
## and of length 1); straight ahead for a camera looking straight down or up.
static func heading(camera_forward: Vector3) -> Vector3:
	var forward := camera_forward
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	return forward.normalized()


## How much softer a sound `distance` m from the ear is (dB, <= 0): full up to FULL_WITHIN,
## then DB_PER_METRE softer, at most SOFTEST_DB.
static func distance_db(distance: float) -> float:
	return -clampf((distance - FULL_WITHIN) * DB_PER_METRE, 0.0, SOFTEST_DB)


## Without a camera: whether something `distance` m from the ear may make a sound.
static func within_hearing(distance: float) -> bool:
	return distance <= HEARING_RANGE


## Whether the point `on_screen` is in `picture` or just outside it (VIEW_MARGIN of its size
## on every side).
static func in_picture(picture: Rect2, on_screen: Vector2) -> bool:
	return picture.grow_individual(picture.size.x * VIEW_MARGIN, picture.size.y * VIEW_MARGIN,
			picture.size.x * VIEW_MARGIN, picture.size.y * VIEW_MARGIN).has_point(on_screen)


## Which vehicles get a sound: of `entries` ([distance to the ear, id] each) the ids of the
## `most` nearest, the nearest first.
static func nearest_ids(entries: Array, most := MAX_EMITTERS) -> Array:
	var sorted_entries := entries.duplicate()
	sorted_entries.sort_custom(func(first, second): return first[0] < second[0])
	var ids := []
	for entry in sorted_entries.slice(0, most):
		ids.append(entry[1])
	return ids


# ------------------------------------------------------------------ the kinds

## The kind of sound of a vehicle whose `vehicle_kind` is that: the helicopter its own, a
## kind with an engine loop itself, "" for what is silent (bikes, what nobody knows).
static func kind_of(vehicle_kind: String, is_helicopter: bool) -> String:
	if is_helicopter:
		return HELICOPTER_KIND
	return vehicle_kind if MOTOR_SOUNDS.has(vehicle_kind) else ""


## Whether a script at `script_path` is the police helicopter's.
static func is_helicopter_script(script_path: String) -> bool:
	return script_path.ends_with(HELICOPTER_SCRIPT)


## The engine loop of `kind` (the helicopter: its rotor).
static func motor_sound(kind: String) -> String:
	return HELICOPTER_SOUND if kind == HELICOPTER_KIND else String(MOTOR_SOUNDS[kind])


## How loud (dB) the engine of `kind` is at its cruising speed.
static func motor_base_db(kind: String) -> float:
	return HELICOPTER_VOLUME_DB if kind == HELICOPTER_KIND else float(MOTOR_VOLUME_DB[kind])


## How near (m) the engine of `kind` is at full loudness.
static func motor_unit(kind: String) -> float:
	return HELICOPTER_UNIT_SIZE if kind == HELICOPTER_KIND else float(UNIT_SIZE[kind])


## The siren loop of a vehicle: none unless it is an emergency vehicle, then that of its
## `service` ("ambulance", "brandweer"; any other the police's).
static func siren_sound(emergency: bool, service: String) -> String:
	if not emergency:
		return ""
	return String(SIREN_SOUNDS.get(service, SIREN_SOUNDS["politie"]))


# ------------------------------------------------------------------ the engines

## Whether a vehicle at `speed` m/s stands still.
static func is_standing(speed: float) -> bool:
	return speed < STANDING_BELOW


## The pitch of an engine at `speed` with cruising speed `cruise`: IDLE_PITCH standing
## still, 1 at its cruising speed, above that higher still (at most MAX_PITCH).
static func engine_pitch(speed: float, cruise: float) -> float:
	if speed > cruise:
		return minf(MAX_PITCH, 1.0 + (speed - cruise) / cruise * 0.5)
	return lerpf(IDLE_PITCH, 1.0, clampf(speed / cruise, 0.0, 1.0))


## The pitch_scale of the engine loop of a vehicle: its engine's pitch, the Doppler shift
## and the pitch of its own (`pitch_factor`), within what still sounds like an engine.
static func motor_pitch(speed: float, cruise: float, doppler_factor: float, pitch_factor: float) -> float:
	return clampf(engine_pitch(speed, cruise) * doppler_factor * pitch_factor, 0.3, 2.5)


## The pitch_scale of the rotor loop of the helicopter (it has no speed of its own).
static func helicopter_pitch(doppler_factor: float, pitch_factor: float) -> float:
	return clampf(doppler_factor * pitch_factor, 0.5, 2.0)


## The pitch_scale of a siren: only the Doppler shift.
static func siren_pitch(doppler_factor: float) -> float:
	return clampf(doppler_factor, 0.5, 2.0)


## How much softer (dB, <= 0) the engine of `kind` is at `speed` than at its cruising speed
## `cruise`: IDLE_DB standing still; a tram or a train fades out under RAIL_SILENT_BELOW m/s.
static func engine_db(kind: String, speed: float, cruise: float) -> float:
	var idle_db := lerpf(IDLE_DB, 0.0, clampf(speed / cruise, 0.0, 1.0))
	if kind in RAIL_KINDS:
		idle_db += linear_to_db(maxf(clampf(speed / RAIL_SILENT_BELOW, 0.0, 1.0), 0.0001))
	return idle_db


## How far (dB, <= 0) the loops of a vehicle are down while `duck` (0..1) of the way ducked.
static func duck_db(duck: float) -> float:
	return PASS_BY_DUCK_DB * duck


## The volume (dB) of the engine loop of a vehicle of `kind` whose engine is `base_db` loud,
## at `speed`, ducked `ducked_db` and `distance_softer_db` softer for its distance; a wreck
## (`crashed`) is silent.
static func motor_volume_db(kind: String, base_db: float, speed: float, cruise: float, ducked_db: float,
		distance_softer_db: float, crashed: bool) -> float:
	if crashed:
		return CRASHED_DB
	return base_db + engine_db(kind, speed, cruise) + ducked_db + distance_softer_db


## The volume (dB) of the rotor loop of the helicopter: the distance does not soften it.
static func helicopter_volume_db(base_db: float, ducked_db: float) -> float:
	return base_db + ducked_db


## The volume (dB) of a siren, ducked `ducked_db` and `distance_softer_db` softer for its distance.
static func siren_volume_db(ducked_db: float, distance_softer_db: float) -> float:
	return SIREN_VOLUME_DB + ducked_db + distance_softer_db


## The pitch factor of a source moving at `velocity`, `to_ear` away from the ear (the vector
## from the source to the ear) that moves at `ear_velocity`: above 1 coming, below 1 going.
static func doppler(velocity: Vector3, ear_velocity: Vector3, to_ear: Vector3) -> float:
	var distance := to_ear.length()
	if distance < DOPPLER_FROM:
		return 1.0
	var direction := to_ear / distance
	var closing := (velocity.dot(direction) - ear_velocity.dot(direction)) * DOPPLER_BOOST
	closing = clampf(closing, -SPEED_OF_SOUND * 0.5, SPEED_OF_SOUND * 0.5)
	return SPEED_OF_SOUND / (SPEED_OF_SOUND - closing)


## Where (s) an engine loop of `length` s starts for a draw `share` (0..1): somewhere in the
## loop, so a street full of the same cars does not phase.
static func loop_start(share: float, length: float) -> float:
	return share * maxf(length - 0.05, 0.0)


## The most a one-shot at `volume_db` may be (max_db caps volume_db too: at 0 dB a horn or a
## cry above 0 would be cut back to the level of the engines and be lost under them).
static func one_shot_max_db(volume_db: float) -> float:
	return maxf(volume_db, 0.0)


# ------------------------------------------------------------------ crashes and signals

## The sound of a vehicle that crashes, having driven `speed_before` m/s.
static func crash_sound(speed_before: float) -> String:
	return HARD_CRASH_SOUND if speed_before > HARD_CRASH_SPEED else LIGHT_CRASH_SOUND


## Whether a vehicle that was not a wreck (`was_crashed`) has just become one.
static func just_crashed(crashed: bool, was_crashed: bool) -> bool:
	return crashed and not was_crashed


## Whether a bus hisses its brakes: it has just come to a stop from driving.
static func bus_brakes(kind: String, standing: bool, was_standing: bool, speed_before: float) -> bool:
	return kind == "bus" and standing and not was_standing and speed_before > 0.0


## Whether a tram rings its bell: it has just pulled away.
static func tram_rings(kind: String, standing: bool, was_standing: bool) -> bool:
	return kind == "tram" and not standing and was_standing


## Whether a train may sound its horn (with TRAIN_HORN_CHANCE): it has just pulled away.
static func train_may_hoot(kind: String, standing: bool, was_standing: bool) -> bool:
	return kind == "trein" and not standing and was_standing


## Whether a draw `roll` (0..1) with chance `chance` comes true.
static func chance_hits(roll: float, chance: float) -> bool:
	return roll < chance


# ------------------------------------------------------------------ the yelp

## Whether a siren yelps now: not while it is off, below YELP_BELOW of the cruising speed
## `cruise` it starts, above YELP_UNTIL it stops, in between it stays as it was (`yelping`).
static func yelps(yelping: bool, speed: float, cruise: float, siren_on: bool) -> bool:
	if not siren_on:
		return false
	if speed < cruise * YELP_BELOW:
		return true
	if speed > cruise * YELP_UNTIL:
		return false
	return yelping


## The loop a siren plays: the yelp, or its own (`siren_name`).
static func siren_loop(yelping: bool, siren_name: String) -> String:
	return YELP_SOUND if yelping else siren_name


## Whether a vehicle that starts to yelp may blow its air horn: a fire engine, and not
## within HORN_PAUSE s of the last time (`horn_ready_at`, on the clock `clock`).
static func horn_may_blow(yelping: bool, is_fire_engine: bool, clock: float, horn_ready_at: float) -> bool:
	return yelping and is_fire_engine and clock >= horn_ready_at


## The clock from which the air horn may blow again after it could at `clock`.
static func horn_ready_after(clock: float) -> float:
	return clock + HORN_PAUSE


# ------------------------------------------------------------------ passing by

## How near (m) `kind` must pass the ear for its pass-by clip.
static func pass_by_distance(kind: String) -> float:
	return HELICOPTER_PASS_BY_DISTANCE if kind == HELICOPTER_KIND else PASS_BY_DISTANCE


## How far (m) `kind` must get from the ear before it can pass by again.
static func rearm_distance(kind: String) -> float:
	return PASS_BY_REARM * (2.5 if kind == HELICOPTER_KIND else 1.0)


## How near (m) the pass-by clip of `kind` is at full loudness.
static func pass_by_unit(kind: String) -> float:
	return HELICOPTER_UNIT_SIZE if kind == HELICOPTER_KIND else PASS_BY_UNIT


## `vector` as it counts for passing by: the helicopter flies over, so only its flat part.
static func passing_part(kind: String, vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z) if kind == HELICOPTER_KIND else vector


## Whether a vehicle that gets its sound `distance` m from the ear can still pass by on this
## approach: not when it is right next to the ear already.
static func armed_at_start(kind: String, distance: float) -> bool:
	return distance > pass_by_distance(kind) * 2.0


## Whether a vehicle that passed by is far enough (`distance` m) to pass by again.
static func rearms(kind: String, distance: float) -> bool:
	return distance > rearm_distance(kind)


## Whether a car of `kind` driving `speed` m/s, `relative_speed` towards or past the ear,
## goes fast enough for a pass-by.
static func car_fast_enough(kind: String, speed: float, relative_speed: float) -> bool:
	return absf(speed) >= float(CRUISE_SPEED[kind]) * PASS_BY_MIN_SHARE and relative_speed > 1.0


## Whether the helicopter, at `relative_speed` to the ear, goes fast enough for a pass-by.
static func helicopter_fast_enough(relative_speed: float) -> bool:
	return relative_speed >= HELICOPTER_PASS_BY_MIN_SPEED


## The seconds until something `offset` from the ear moving at `relative` to it is nearest
## (zero or less: it is going away).
static func seconds_until_nearest(offset: Vector3, relative: Vector3) -> float:
	var relative_speed := relative.length()
	return -offset.dot(relative) / (relative_speed * relative_speed)


## How near (m) it comes to the ear at that moment.
static func miss_distance(offset: Vector3, relative: Vector3, until_nearest: float) -> float:
	return (offset + relative * until_nearest).length()


## Whether it passes: it still comes nearer and will come near enough for `kind`.
static func passes(kind: String, offset: Vector3, relative: Vector3) -> bool:
	var until_nearest := seconds_until_nearest(offset, relative)
	if until_nearest <= 0.0:
		return false
	return miss_distance(offset, relative, until_nearest) <= pass_by_distance(kind)


## Whether a clip of `length` s can start now for something nearest in `until_nearest` s:
## its loudest moment (halfway) must not come before the nearest point.
static func clip_in_reach(until_nearest: float, length: float) -> bool:
	return until_nearest <= length * 0.5


## Where (s) the clip of `length` s starts so its loudest moment (halfway) falls on the
## nearest point, `until_nearest` s away.
static func pass_by_start(length: float, until_nearest: float) -> float:
	return clampf(length * 0.5 - until_nearest, 0.0, length - 0.1)


## The pass-by clip of a vehicle of `kind`: the helicopter's, the one of its service while
## its siren (`siren_name`) is on, else the one of its kind.
static func pass_by_sound(kind: String, siren_name: String, siren_on: bool) -> String:
	if kind == HELICOPTER_KIND:
		return HELICOPTER_PASS_BY
	if siren_name != "" and siren_on:
		return siren_name.replace(SIREN_SUFFIX, PASS_BY_SUFFIX)
	return kind + PASS_BY_SUFFIX
