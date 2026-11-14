extends RefCounted
## Impatient drivers: a vehicle that honks at someone in its way sometimes shouts a line too,
## in a speech balloon over its roof (SpeechBalloon, scripts/ui/widgets/speech_balloon.gd).
## The mood: "wachten" (it stands still for them: SHOUT_CHANCE), "waarschuwen" (it only warns
## them while driving: WARNING_CHANCE), "doordrukken" (it has waited long enough and drives
## on: always, see Vehicle IMPATIENT_AFTER), "wheelie" (a rider showing off on its rear wheel,
## Wheelie: always, its own WHEELIE_LINES and WHEELIE_KIND_LINES), "aanrijding" (it has just
## run the player over, Vehicle.shout_after_hit: always, HIT_LINES), "dronken" / "agressief" (an
## idiot at the wheel, Vehicle.maniac: now and then and when it honks, DRUNK_LINES /
## AGGRESSIVE_LINES). Not at every honk: the same speaker at most every
## SPEAKER_PAUSE seconds, anyone at all at most every ANY_PAUSE seconds (but "doordrukken"),
## only near what the camera looks at (SHOUT_DISTANCE) and in view. The balloon types the line, holds
## HOLD_SECONDS and fades; a new line of the same speaker replaces the one in its balloon.
## With it the speaker babbles (Babble, at the speaker: BABBLE_MOOD, a question going up), in
## its voice (`voice()` of a pedestrian; a driver one from its instance).
## The balloons are on their own CanvasLayer (BALLOON_LAYER: under the HUD and its pause
## screen), made in the current scene the first time someone shouts.
## Behaviour (docs/CODE_LAGEN.md): the pauses, the draws and who has which balloon are kept
## here; the lines and the choices are driver_shout_rules.gd's, the balloon and the babble
## driver_shout_view.gd's.
##   const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
##   DriverShout.shout(self, "auto", "wachten", 2.2)

const DriverShoutRules = preload("res://scripts/vehicles/driver_shout_rules.gd")
const DriverShoutView = preload("res://scripts/vehicles/driver_shout_view.gd")
const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
const Babble = preload("res://scripts/audio/babble.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")

## The lines and the numbers of the rules, under the names they had here.
const BABBLE_MOOD := DriverShoutRules.BABBLE_MOOD
const DRUNK_LINES := DriverShoutRules.DRUNK_LINES
const AGGRESSIVE_LINES := DriverShoutRules.AGGRESSIVE_LINES
const WAITING_LINES := DriverShoutRules.WAITING_LINES
const PUSHING_LINES := DriverShoutRules.PUSHING_LINES
const WARNING_LINES := DriverShoutRules.WARNING_LINES
const HIT_LINES := DriverShoutRules.HIT_LINES
const WHEELIE_LINES := DriverShoutRules.WHEELIE_LINES
const WHEELIE_KIND_LINES := DriverShoutRules.WHEELIE_KIND_LINES
const KIND_LINES := DriverShoutRules.KIND_LINES
const FARE_DODGER_LINES := DriverShoutRules.FARE_DODGER_LINES
const CHECK_OUT_LINES := DriverShoutRules.CHECK_OUT_LINES
const FINE_LINES := DriverShoutRules.FINE_LINES
const OFF_THE_TRACK_LINES := DriverShoutRules.OFF_THE_TRACK_LINES
const FALLEN_LINES := DriverShoutRules.FALLEN_LINES
const SHOUT_CHANCE := DriverShoutRules.SHOUT_CHANCE
const WARNING_CHANCE := DriverShoutRules.WARNING_CHANCE
const SPEAKER_PAUSE := DriverShoutRules.SPEAKER_PAUSE
const ANY_PAUSE := DriverShoutRules.ANY_PAUSE
const SHOUT_DISTANCE := DriverShoutRules.SHOUT_DISTANCE
const MOODS := DriverShoutRules.MOODS
## ...and what the balloon looks like, of the view.
const HOLD_SECONDS := DriverShoutView.HOLD_SECONDS
const BALLOON_LAYER := DriverShoutView.BALLOON_LAYER
const DRIVER_ACCENT := DriverShoutView.DRIVER_ACCENT
const READY_META := "shout_ready_at"
const BALLOON_META := "shout_balloon"

static var _balloon_layer: CanvasLayer
static var _any_ready_at := 0.0
static var _last_line := ""
static var _random := RandomNumberGenerator.new()


## Maybe shouts a line over `speaker` (`roof_height` m above its origin): `kind` its vehicle
## kind (for KIND_LINES), `mood` one of MOODS (see the top). Returns whether it shouted.
static func shout(speaker: Node3D, kind: String, mood: String, roof_height: float) -> bool:
	if speaker == null or not speaker.is_inside_tree():
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if not DriverShoutRules.is_always(mood):
		if not DriverShoutRules.may_speak(now, _any_ready_at, float(speaker.get_meta(READY_META, 0.0))):
			return false
		if _random.randf() >= DriverShoutRules.chance_of(mood):
			return false
	var camera := speaker.get_viewport().get_camera_3d()
	if camera == null:
		return false
	var roof := DriverShoutRules.roof_of(speaker.global_position, roof_height)
	# near what the camera looks at (the camera itself hangs far off, high above the town)
	# (a camera looking out level has no point on the ground: then from itself)
	var focus := Iso.ground_focus(camera) if DriverShoutRules.looks_at_ground(-camera.global_basis.z) else camera.global_position
	if not DriverShoutRules.within_reach(focus, roof) or not camera.is_position_in_frustum(roof):
		return false
	_any_ready_at = now + ANY_PAUSE
	speaker.set_meta(READY_META, now + SPEAKER_PAUSE)
	var line := pick_line(kind, mood)
	_say(speaker, camera, line, roof_height, DriverShoutRules.babble_mood_for(mood))
	return true


## Always shouts `line` over `speaker` (`head_height` m above its origin), babbling in
## `babble_mood` (a line ending in "?" asks): someone of a place who comes to put the player
## out (scripts/world/interiors/eviction.gd). Returns whether it could (in the tree, with a camera).
static func shout_line(speaker: Node3D, line: String, head_height: float, babble_mood := "boos") -> bool:
	if speaker == null or not speaker.is_inside_tree() or line == "":
		return false
	var camera := speaker.get_viewport().get_camera_3d()
	if camera == null:
		return false
	speaker.set_meta(READY_META, Time.get_ticks_msec() / 1000.0 + SPEAKER_PAUSE)
	_say(speaker, camera, line, head_height, babble_mood)
	return true


## `line` in the balloon over `speaker`, and its babble.
static func _say(speaker: Node3D, camera: Camera3D, line: String, roof_height: float, mood_of_babble: String) -> void:
	var roof := DriverShoutRules.roof_of(speaker.global_position, roof_height)
	# its balloon still talking takes the new line; else (none, or fading) a new one
	var balloon: SpeechBalloon = null
	var earlier: Variant = speaker.get_meta(BALLOON_META) if speaker.has_meta(BALLOON_META) else null
	if is_instance_valid(earlier) and not (earlier as Node).is_queued_for_deletion() and (earlier as SpeechBalloon).is_talking():
		balloon = earlier
	if balloon == null:
		balloon = DriverShoutView.build_balloon(_layer_for(speaker), speaker, camera, roof_height)
		speaker.set_meta(BALLOON_META, balloon)
	DriverShoutView.show_line(balloon, line)
	DriverShoutView.play_babble(speaker.get_tree(), roof, voice_of(speaker), DriverShoutRules.babble_mood_of(line, mood_of_babble), line)


## The voice of a speaker: a pedestrian's own (Pedestrian.voice), else one of Babble.VOICES
## that stays the same for that vehicle.
static func voice_of(speaker: Node) -> String:
	if speaker.has_method("voice"):
		return str(speaker.call("voice"))
	return DriverShoutRules.voice_at(speaker.get_instance_id(), Babble.VOICES)


## A line for `kind` in `mood` (MOODS), never the same twice in a row.
static func pick_line(kind: String, mood: String) -> String:
	var lines := DriverShoutRules.lines_for(kind, mood)
	var line := DriverShoutRules.line_at(lines, _random.randi_range(0, lines.size() - 1), _last_line)
	_last_line = line
	return line


## The layer of the balloons: made the first time someone shouts, and again when the scene
## it was in has gone.
static func _layer_for(speaker: Node3D) -> CanvasLayer:
	if _balloon_layer == null or not is_instance_valid(_balloon_layer) or not _balloon_layer.is_inside_tree():
		# with the scene, so a new game starts without the old one's layer
		var scene := speaker.get_tree().current_scene
		_balloon_layer = DriverShoutView.build_layer(scene if scene else speaker.get_tree().root)
	return _balloon_layer
