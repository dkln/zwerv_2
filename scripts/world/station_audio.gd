class_name StationAudio
extends RefCounted
## The sound of the station hall (scripts/world/station.gd): two buses of their own, made
## when the station first opens, and the sounds (assets/audio/geluiden/, made by
## tools/megadrive/geluiden.py) played on them.
## - HALL_BUS "Stationshal": everything heard in the hall (trains, doors, whistles, gates,
##   readers, people): a big reverb (a high glass hall of stone and steel: long, bright,
##   with a pre-delay) on its way to Master.
## - ANNOUNCER_BUS "Omroep": the announcements (the chime and the babbling voice): the
##   band of a public-address loudspeaker (no lows, no highs) and the echo of the speakers
##   further down the hall (two delayed taps), on into the hall bus, so it gets the reverb
##   as well.

const SoundVariation = preload("res://scripts/audio/sound_variation.gd")
const HALL_BUS := "Stationshal"
const ANNOUNCER_BUS := "Omroep"
const SOUND_FOLDER := "res://assets/audio/geluiden/"
## The reverb of the hall.
const HALL_ROOM_SIZE := 0.9
const HALL_DAMPING := 0.3
const HALL_WET := 0.34
const HALL_DRY := 0.9
const HALL_PREDELAY_MS := 65.0
## The loudspeakers: the band they let through (Hz) and the echoes of the far speakers (ms, dB).
const SPEAKER_LOW_HZ := 380.0
const SPEAKER_HIGH_HZ := 3600.0
const ECHO_TAPS := [[210.0, -9.0], [480.0, -15.0]]
## How far a sound in the hall carries (AudioStreamPlayer3D).
const HALL_UNIT_SIZE := 9.0
const HALL_MAX_DISTANCE := 90.0

static var _streams := {}


## Makes the two buses if they are not there yet.
static func ensure_buses() -> void:
	if AudioServer.get_bus_index(HALL_BUS) < 0:
		AudioServer.add_bus()
		var hall := AudioServer.bus_count - 1
		AudioServer.set_bus_name(hall, HALL_BUS)
		AudioServer.set_bus_send(hall, "Master")
		var reverb := AudioEffectReverb.new()
		reverb.room_size = HALL_ROOM_SIZE
		reverb.damping = HALL_DAMPING
		reverb.spread = 1.0
		reverb.hipass = 0.12
		reverb.dry = HALL_DRY
		reverb.wet = HALL_WET
		reverb.predelay_msec = HALL_PREDELAY_MS
		reverb.predelay_feedback = 0.3
		AudioServer.add_bus_effect(hall, reverb)
	if AudioServer.get_bus_index(ANNOUNCER_BUS) < 0:
		AudioServer.add_bus()
		var speaker := AudioServer.bus_count - 1
		AudioServer.set_bus_name(speaker, ANNOUNCER_BUS)
		AudioServer.set_bus_send(speaker, HALL_BUS)
		var low_cut := AudioEffectHighPassFilter.new()
		low_cut.cutoff_hz = SPEAKER_LOW_HZ
		AudioServer.add_bus_effect(speaker, low_cut)
		var high_cut := AudioEffectLowPassFilter.new()
		high_cut.cutoff_hz = SPEAKER_HIGH_HZ
		AudioServer.add_bus_effect(speaker, high_cut)
		var echo := AudioEffectDelay.new()
		echo.dry = 1.0
		echo.tap1_active = true
		echo.tap1_delay_ms = ECHO_TAPS[0][0]
		echo.tap1_level_db = ECHO_TAPS[0][1]
		echo.tap2_active = true
		echo.tap2_delay_ms = ECHO_TAPS[1][0]
		echo.tap2_level_db = ECHO_TAPS[1][1]
		echo.feedback_active = false
		AudioServer.add_bus_effect(speaker, echo)


## A sound by its name (without .ogg), also when it is not imported yet; null if missing.
static func stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var path := SOUND_FOLDER + sound_name + ".ogg"
	var found: AudioStream = null
	if ResourceLoader.exists(path):
		found = load(path)
	elif FileAccess.file_exists(path):
		found = AudioStreamOggVorbis.load_from_file(path)
	_streams[sound_name] = found
	return found


## Plays a sound once at `at` (in the space of `parent`), in the hall; the player frees
## itself when done. Null if the sound is missing.
static func play_at(parent: Node3D, sound_name: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var sound := stream(sound_name)
	if sound == null or parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.bus = HALL_BUS
	player.volume_db = volume_db
	player.pitch_scale = pitch * SoundVariation.pitch()
	player.unit_size = HALL_UNIT_SIZE
	player.max_distance = HALL_MAX_DISTANCE
	parent.add_child(player)
	player.position = at
	player.finished.connect(player.queue_free)
	player.play()
	return player


## A looping sound on `parent` (an engine), not yet playing.
static func loop_on(parent: Node3D, sound_name: String, volume_db := 0.0) -> AudioStreamPlayer3D:
	var sound := stream(sound_name)
	if sound == null:
		return null
	if sound is AudioStreamOggVorbis:
		sound = (sound as AudioStreamOggVorbis).duplicate()
		(sound as AudioStreamOggVorbis).loop = true
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.bus = HALL_BUS
	player.volume_db = volume_db
	player.pitch_scale = SoundVariation.pitch(SoundVariation.LOOP_SPREAD)
	player.unit_size = HALL_UNIT_SIZE
	player.max_distance = HALL_MAX_DISTANCE
	parent.add_child(player)
	return player


## A sound everywhere in the hall at once (an announcement: the loudspeakers), on `bus`.
static func play_everywhere(parent: Node, sound_name: String, volume_db := 0.0, bus := ANNOUNCER_BUS) -> AudioStreamPlayer:
	var sound := stream(sound_name)
	if sound == null or parent == null or not parent.is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = sound
	player.bus = bus
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
