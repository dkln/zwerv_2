extends RefCounted
## What someone in the street shouts (logic; docs/CODE_LAGEN.md): the lines per mood and per
## kind of vehicle, which moods are always shouted and the chance of the others, the pauses
## between shouts, how near the camera's focus a speaker must be, the mood of the babble
## with a line and which voice a vehicle keeps. Pure: the draws and the clock are
## driver_shout.gd's (behaviour), the balloon and the babble driver_shout_view.gd's.
##   const DriverShoutRules = preload("res://scripts/vehicles/driver_shout_rules.gd")

## The mood of the babble of a shout (Babble) by its mood; a line ending in "?" asks ("vraag").
const BABBLE_MOOD := {"wachten": "boos", "waarschuwen": "boos", "doordrukken": "boos", "wheelie": "opgewonden",
	"aanrijding": "verdrietig", "zwartrijden": "boos", "uitchecken": "boos", "beboeten": "boos", "spoor": "boos", "gevallen": "verdrietig",
	"dronken": "opgewonden", "agressief": "boos"}

## An idiot at the wheel (Vehicle.maniac), now and then and when it honks: drunk...
const DRUNK_LINES: Array[String] = [
	"Hik! Welke baan was ook alweer van mij?",
	"Ik zie twee wegen... ik neem de middelste!",
	"Ik ben nog hartstikke nuchter, hoor! Hik!",
	"Wie heeft die stoep hier neergezet?",
	"Wat staan die lantaarnpalen scheef vandaag.",
	"Nog eentje voor onderweg!",
	"Rood of groen? Allebei mooi!",
	"Ik rij hartstikke rechtdoor, kijk dan!",
	"Waarom draait de stad zo?",
	"Effe naar huis. Waar woon ik ook alweer?",
	"Proost, Den Haag!",
	"Ik heb er maar twee op. Of twaalf.",
	"Is dit de Lange Poten of de lange weg?",
	"Lekker liedje! Lalala... hik!",
]
## ...or aggressive.
const AGGRESSIVE_LINES: Array[String] = [
	"Aan de kant, slakken!",
	"Rechts voorrang? Nooit van gehoord!",
	"Groen, oranje, wat maakt het uit!",
	"Ik heb haast, jonguh!",
	"Rijbewijs bij de Hema gehaald ofzo?",
	"Gas erop!",
	"Wie remt, verliest!",
	"Dit is geen zondagsritje, hè!",
	"Pak toch de fiets, man!",
	"Ik moet er nú langs!",
	"Maximumsnelheid? Dat is een advies, toch?",
	"Rijden jullie allemaal met de handrem erop?",
	"Opzij, opzij, opzij!",
	"Kom op, die ouwe kar kan wel harder!",
]
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
## ("beboeten"); "uitchecken" when they went out over the gates still checked in. Always
## shouted, as "doordrukken".
const FARE_DODGER_LINES: Array[String] = [
	"Hé! Even uw kaartje!",
	"Ho ho, staan blijven! Kaartje!",
	"Hé jij daar! Niet zwartrijden!",
	"Wacht eens even, vriend!",
	"Zo kom je er niet in, hoor!",
]
## ...and one who saw them go out over the gates without checking out ("uitchecken").
const CHECK_OUT_LINES: Array[String] = [
	"Hé! U bent vergeten uit te checken!",
	"Ho! Eerst uitchecken, meneer!",
	"Niet uitgecheckt? Staan blijven!",
	"Zo ga je er niet uit, hoor!",
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
const MOODS := ["wachten", "waarschuwen", "doordrukken", "wheelie", "aanrijding", "zwartrijden", "uitchecken", "beboeten", "spoor", "gevallen",
	"dronken", "agressief"]
## The moods that are always shouted: no chance, no pause.
const ALWAYS_MOODS := ["doordrukken", "wheelie", "aanrijding", "zwartrijden", "uitchecken", "beboeten", "spoor", "gevallen"]
## The babble of a mood that is not in BABBLE_MOOD, and that of a line that asks.
const PLAIN_BABBLE := "neutraal"
const ASKING_BABBLE := "vraag"
## A camera whose forward points less far down than this (its y) has no point on the ground.
const LEVEL_FORWARD := -0.2


## Whether `mood` is always shouted (else by chance_of, and not within the pauses).
static func is_always(mood: String) -> bool:
	return mood in ALWAYS_MOODS


## The chance that a honk in `mood` comes with a shout.
static func chance_of(mood: String) -> float:
	return SHOUT_CHANCE if mood == "wachten" else WARNING_CHANCE


## Whether a speaker may shout at `now` (seconds): past the pause of everyone
## (`any_ready_at`) and past its own (`speaker_ready_at`).
static func may_speak(now: float, any_ready_at: float, speaker_ready_at: float) -> bool:
	return not (now < any_ready_at or now < speaker_ready_at)


## The point over a speaker at `origin` where its balloon hangs and its babble sounds.
static func roof_of(origin: Vector3, roof_height: float) -> Vector3:
	return origin + Vector3.UP * roof_height


## Whether a camera looking along `forward` looks down at the ground (else it looks out
## level: the distance of a shout is then measured from the camera itself).
static func looks_at_ground(forward: Vector3) -> bool:
	return forward.y < LEVEL_FORWARD


## Whether `roof` is near enough to `focus` (what the camera looks at), over the ground.
static func within_reach(focus: Vector3, roof: Vector3) -> bool:
	return not Vector2(focus.x - roof.x, focus.z - roof.z).length() > SHOUT_DISTANCE


## The lines to pick from for `kind` in `mood` (MOODS; an unknown mood warns).
static func lines_for(kind: String, mood: String) -> Array[String]:
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
		"uitchecken":
			lines.append_array(CHECK_OUT_LINES)
		"beboeten":
			lines.append_array(FINE_LINES)
		"spoor":
			lines.append_array(OFF_THE_TRACK_LINES)
		"gevallen":
			lines.append_array(FALLEN_LINES)
		"dronken":
			lines.append_array(DRUNK_LINES)
		"agressief":
			lines.append_array(AGGRESSIVE_LINES)
		"wheelie":
			lines.append_array(WHEELIE_LINES)
			for line in WHEELIE_KIND_LINES.get(kind, []):
				lines.append(String(line))
		_:
			lines.append_array(WARNING_LINES)
	if mood in ["wachten", "waarschuwen"]:
		for line in KIND_LINES.get(kind, []):
			lines.append(String(line))
	return lines


## The line of `lines` at `drawn_index`, or the one after it when that is `last_line` (never
## the same twice in a row, unless there is only one).
static func line_at(lines: Array[String], drawn_index: int, last_line: String) -> String:
	var line := lines[drawn_index]
	if line == last_line and lines.size() > 1:
		line = lines[(lines.find(line) + 1) % lines.size()]
	return line


## The mood of the babble of a shout in `mood`.
static func babble_mood_for(mood: String) -> String:
	return str(BABBLE_MOOD.get(mood, PLAIN_BABBLE))


## The mood the babble of `line` gets: a line ending in "?" asks, else `mood_of_babble`.
static func babble_mood_of(line: String, mood_of_babble: String) -> String:
	return ASKING_BABBLE if line.strip_edges().ends_with("?") else mood_of_babble


## The voice of `voices` that the speaker with `instance_id` keeps.
static func voice_at(instance_id: int, voices: Array) -> String:
	return voices[instance_id % voices.size()]
