extends RefCounted
## Impatient drivers: a vehicle that honks at someone in its way sometimes shouts a line too,
## in a speech balloon over its roof (SpeechBalloon, scripts/ui/widgets/speech_balloon.gd).
## The mood: "wachten" (it stands still for them: SHOUT_CHANCE), "waarschuwen" (it only warns
## them while driving: WARNING_CHANCE), "doordrukken" (it has waited long enough and drives
## on: always, see Vehicle IMPATIENT_AFTER), "wheelie" (a rider showing off on its rear wheel,
## Wheelie: always, its own WHEELIE_LINES and WHEELIE_KIND_LINES), "aanrijding" (it has just
## run the player over, Vehicle.shout_after_hit: always, HIT_LINES). Not at every honk: the same speaker at most every
## SPEAKER_PAUSE seconds, anyone at all at most every ANY_PAUSE seconds (but "doordrukken"),
## only near what the camera looks at (SHOUT_DISTANCE) and in view. The balloon types the line, holds
## HOLD_SECONDS and fades; a new line of the same speaker replaces the one in its balloon.
## With it the speaker babbles (Babble, at the speaker: BABBLE_MOOD, a question going up), in
## its voice (`voice()` of a pedestrian; a driver one from its instance).
## The balloons are on their own CanvasLayer (BALLOON_LAYER: under the HUD and its pause
## screen), made in the current scene the first time someone shouts.
##   DriverShout.shout(self, "auto", "wachten", 2.2)

const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const Babble = preload("res://scripts/audio/babble.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
## The mood of the babble of a shout (Babble) by its mood; a line ending in "?" asks ("vraag").
const BABBLE_MOOD := {"wachten": "boos", "waarschuwen": "boos", "doordrukken": "boos", "wheelie": "opgewonden",
	"aanrijding": "verdrietig", "zwartrijden": "boos", "beboeten": "boos", "spoor": "boos", "gevallen": "verdrietig"}

## Standing still for someone in its way.
const WAITING_LINES: Array[String] = [
	"Uit de weg!",
	"Doorlopen!",
	"Opzij, jonguh!",
	"Ga eens aan de kant!",
	"Kom op, schiet eens op!",
	"Ik heb niet de hele dag, hè!",
	"Wegwezûh!",
	"Is dit je huiskamer ofzo?",
	"Sta je hier te slapen?",
	"Hallo! Doorlopûh!",
	"Loop is deur, man!",
	"Doe effe normaal!",
	"Ga je nog of hoe zit het?",
	"Ophoepelen!",
	"Ik sta hier niet voor m'n lol!",
]
## Waited long enough: it drives on.
const PUSHING_LINES: Array[String] = [
	"Nou, dan rij ik er gewoon door!",
	"Jij je zin, hoor!",
	"Ik ga, of je nou wil of niet!",
	"Daar gaat ie dan!",
	"Eigen schuld, dikke bult!",
	"Ik heb lang genoeg gewacht!",
]
## Driving at someone who steps into its path.
const WARNING_LINES: Array[String] = [
	"Kijk uit!",
	"Pas op, sukkel!",
	"Kijk uit je doppen!",
	"Hé! Uitkijken!",
	"Wil je dood ofzo?",
]
## Just ran someone over (the player).
const HIT_LINES: Array[String] = [
	"Oeps!",
	"Hé, je stond in de weg!",
	"Eigen schuld, hoor!",
	"Kijk dan ook uit!",
	"Ik had voorrang!",
	"M'n lak! M'n lak!",
	"Sta niet zo te suffen!",
	"Dat was jouw schuld, niet de mijne!",
	"Ik heb niks gezien, hoor!",
	"Ga eens van de weg af, zwerver!",
	"Nou, sorry dan!",
	"Daar gaat m'n no-claim!",
]
## Showing off in a wheelie (Wheelie): mixed with WHEELIE_KIND_LINES.
const WHEELIE_LINES: Array[String] = [
	"Kèk mèn dan!",
	"Eén wiel is genoeg, hè!",
	"Wheelie, jonguh!",
	"Zo doe je dat in Den Haag!",
	"Niemand die me dit nadoet!",
	"Op één wiel naar Scheveningen!",
	"Dit is pas rijden!",
	"Maak maar een foto, hoor!",
	"Ollah, kèk dan!",
	"Hou je vast, ik ga los!",
	"Wie heeft er een voorwiel nodig?",
	"Ik ben de koning van de straat!",
]
const WHEELIE_KIND_LINES := {
	"fatbike": ["Fatbike gang!", "Dertig op één wiel!", "Trappen? Ik? Nooit!"],
	"brommer": ["Opgevoerd, wat dacht je!", "Hoor die tweetakt!", "Vijfenveertig? Ja hoor, tuurlijk!"],
	"motor": ["Honderd op één wiel!", "Dit is geen brommer, hè!", "Vol gas, schat!"],
	"rolstoel": ["Wie heeft er benen nodig?", "Rolstoelpower!", "Ik rij jullie er allemaal uit!", "Effe stoepie pakken!"],
}
## Of its own kind (the bell of a bicycle or a tram, the hooter of a mobility scooter): mixed
## in with the lines above.
const KIND_LINES := {
	"fiets": ["Tring tring! Opzij!", "Fietspad, hè!", "Aan de kant!"],
	"tram": ["De tram wacht niet!", "Van de rails af!"],
	"trein": ["Van het spoor af!"],
	"bus": ["Ik moet m'n dienstregeling halen!", "Lijn 24 wacht op niemand!"],
	"scootmobiel": ["Aan de kant, ik heb haast!", "Opzij, ik ben 87!", "Ik rij je zo omver, hoor!"],
}

## A conductor in Den Haag Centraal who saw the player jump the OV gates (scripts/world/
## station.gd): when he sets off after them ("zwartrijden") and when he has caught them
## ("beboeten"). Always shouted, as "doordrukken".
const FARE_DODGER_LINES: Array[String] = [
	"Hé! Even uw kaartje!",
	"Ho ho, staan blijven! Kaartje!",
	"Hé jij daar! Niet zwartrijden!",
	"Wacht eens even, vriend!",
	"Zo kom je er niet in, hoor!",
]
const FINE_LINES: Array[String] = [
	"Hebbes! Dat wordt een boete.",
	"Zwartrijden kost geld, meneer.",
	"Zo, en nu even afrekenen.",
	"Dat is dan vijftig euro, alstublieft.",
]

## The conductor at the platform edge while the player is down on the rails ("spoor"), and
## someone who fell off a platform by accident ("gevallen").
const OFF_THE_TRACK_LINES: Array[String] = [
	"Van het spoor af!",
	"Kom onmiddellijk van het spoor af!",
	"Ben je gek? Eraf daar!",
]
const FALLEN_LINES: Array[String] = [
	"Au! Mijn knie!",
	"Oei, uitgegleden!",
	"Wie heeft dat perron zo hoog gemaakt?",
	"Help me even omhoog, joh!",
]

const SHOUT_CHANCE := 0.9
const WARNING_CHANCE := 0.6
const SPEAKER_PAUSE := 6.0
const ANY_PAUSE := 1.5
const SHOUT_DISTANCE := 45.0
const HOLD_SECONDS := 2.2
const BALLOON_LAYER := 9
## The colour of a balloon in the street: the accent of the UI, as every balloon.
const DRIVER_ACCENT := UiStyle.ACCENT
const READY_META := "shout_ready_at"
const BALLOON_META := "shout_balloon"
const MOODS := ["wachten", "waarschuwen", "doordrukken", "wheelie", "aanrijding", "zwartrijden", "beboeten", "spoor", "gevallen"]

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
	var always := mood in ["doordrukken", "wheelie", "aanrijding", "zwartrijden", "beboeten", "spoor", "gevallen"]
	if not always:
		if now < _any_ready_at or now < float(speaker.get_meta(READY_META, 0.0)):
			return false
		if _random.randf() >= (SHOUT_CHANCE if mood == "wachten" else WARNING_CHANCE):
			return false
	var camera := speaker.get_viewport().get_camera_3d()
	if camera == null:
		return false
	var roof := speaker.global_position + Vector3.UP * roof_height
	# near what the camera looks at (the camera itself hangs far off, high above the town)
	# (a camera looking out level has no point on the ground: then from itself)
	var focus := Iso.ground_focus(camera) if -camera.global_basis.z.y < -0.2 else camera.global_position
	if Vector2(focus.x - roof.x, focus.z - roof.z).length() > SHOUT_DISTANCE or not camera.is_position_in_frustum(roof):
		return false
	_any_ready_at = now + ANY_PAUSE
	speaker.set_meta(READY_META, now + SPEAKER_PAUSE)
	# its balloon still talking takes the new line; else (none, or fading) a new one
	var balloon: SpeechBalloon = null
	var earlier: Variant = speaker.get_meta(BALLOON_META) if speaker.has_meta(BALLOON_META) else null
	if is_instance_valid(earlier) and not (earlier as Node).is_queued_for_deletion() and (earlier as SpeechBalloon).is_talking():
		balloon = earlier
	if balloon == null:
		balloon = SpeechBalloon.new()
		balloon.name = "Toeterballon"
		balloon.accent = DRIVER_ACCENT
		balloon.head_height = roof_height
		_layer_for(speaker).add_child(balloon)
		balloon.follow(speaker, camera)
		balloon.finished.connect(balloon.queue_free)
		# gone with the vehicle (the balloon would otherwise only hide itself)
		speaker.tree_exiting.connect(balloon.queue_free, CONNECT_ONE_SHOT)
		speaker.set_meta(BALLOON_META, balloon)
	var line := pick_line(kind, mood)
	balloon.say(line, HOLD_SECONDS)
	var babble_mood: String = "vraag" if line.strip_edges().ends_with("?") else str(BABBLE_MOOD.get(mood, "neutraal"))
	Babble.play_at(speaker.get_tree(), roof, voice_of(speaker), babble_mood)
	return true


## The voice of a speaker: a pedestrian's own (Pedestrian.voice), else one of Babble.VOICES
## that stays the same for that vehicle.
static func voice_of(speaker: Node) -> String:
	if speaker.has_method("voice"):
		return str(speaker.call("voice"))
	return Babble.VOICES[speaker.get_instance_id() % Babble.VOICES.size()]


## A line for `kind` in `mood` (MOODS), never the same twice in a row.
static func pick_line(kind: String, mood: String) -> String:
	var lines: Array[String] = []
	match mood:
		"wachten":
			lines.append_array(WAITING_LINES)
		"doordrukken":
			lines.append_array(PUSHING_LINES)
		"aanrijding":
			lines.append_array(HIT_LINES)
		"zwartrijden":
			lines.append_array(FARE_DODGER_LINES)
		"beboeten":
			lines.append_array(FINE_LINES)
		"spoor":
			lines.append_array(OFF_THE_TRACK_LINES)
		"gevallen":
			lines.append_array(FALLEN_LINES)
		"wheelie":
			lines.append_array(WHEELIE_LINES)
			for line in WHEELIE_KIND_LINES.get(kind, []):
				lines.append(String(line))
		_:
			lines.append_array(WARNING_LINES)
	if mood in ["wachten", "waarschuwen"]:
		for line in KIND_LINES.get(kind, []):
			lines.append(String(line))
	var line := lines[_random.randi_range(0, lines.size() - 1)]
	if line == _last_line and lines.size() > 1:
		line = lines[(lines.find(line) + 1) % lines.size()]
	_last_line = line
	return line


static func _layer_for(speaker: Node3D) -> CanvasLayer:
	if _balloon_layer == null or not is_instance_valid(_balloon_layer) or not _balloon_layer.is_inside_tree():
		_balloon_layer = CanvasLayer.new()
		_balloon_layer.name = "Toeterballonnen"
		_balloon_layer.layer = BALLOON_LAYER
		# with the scene, so a new game starts without the old one's layer
		var scene := speaker.get_tree().current_scene
		(scene if scene else speaker.get_tree().root).add_child(_balloon_layer)
	return _balloon_layer
