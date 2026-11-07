extends AudioStreamPlayer3D
## The siren of an emergency vehicle (vehicle.gd, `emergency`): the Dutch two-tone, a low
## and a high tone taking turns, made while it plays (an AudioStreamGenerator, no sound
## file). A tone is a horn-like mix of the fundamental and its odd harmonics that glides
## into the next tone over a few milliseconds instead of clicking. As a 3D sound it is loud
## close by, fades with distance and shifts in pitch as it drives past (Doppler).

## The two tones (Hz) and how long each sounds (s).
const LOW_TONE := 435.0
const HIGH_TONE := 580.0
const TONE_SECONDS := 0.6
## Seconds over which the pitch glides from one tone to the other.
const GLIDE_SECONDS := 0.04
const MIX_RATE := 22050.0

var _phase := 0.0
var _time := 0.0
var _playback: AudioStreamGeneratorPlayback


func _init() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.25
	stream = generator
	unit_size = 18.0
	max_distance = 260.0
	volume_db = -4.0
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	# its own time: two sirens never wail in step
	_time = randf() * TONE_SECONDS * 2.0


## Starts or stops the sound.
func sound(on: bool) -> void:
	if on and not playing:
		play()
		_playback = get_stream_playback() as AudioStreamGeneratorPlayback
		_fill()
	elif not on and playing:
		stop()
		_playback = null


func _process(_delta: float) -> void:
	if playing:
		_fill()


## Pushes as many frames of the two-tone as the buffer has room for.
func _fill() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var step := 1.0 / MIX_RATE
	for frame_index in frames:
		var place := fmod(_time, TONE_SECONDS * 2.0)
		var high := place >= TONE_SECONDS
		var since_change := place - (TONE_SECONDS if high else 0.0)
		var from := LOW_TONE if high else HIGH_TONE
		var to := HIGH_TONE if high else LOW_TONE
		var frequency := lerpf(from, to, clampf(since_change / GLIDE_SECONDS, 0.0, 1.0))
		_phase = fmod(_phase + frequency * step, 1.0)
		var angle := _phase * TAU
		var sample := sin(angle) * 0.62 + sin(angle * 3.0) * 0.22 + sin(angle * 5.0) * 0.1 + sin(angle * 7.0) * 0.05
		_playback.push_frame(Vector2(sample, sample) * 0.8)
		_time += step
