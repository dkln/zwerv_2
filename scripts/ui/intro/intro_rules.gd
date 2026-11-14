extends RefCounted
## The logic of the intro (the rules layer of scripts/ui/intro.gd, which is the behaviour;
## intro_layout.gd has the sizes, intro_view.gd builds and shows it): its texts, its
## moments on the music (scripts/ui/intro_timing.gd) and what is to be seen at each
## moment: how much the opening line shows, how big the logo is and how far gone, where
## the story stands and how much it shows, how bright the twinkle and the stars are, and
## which key breaks it off. Plain functions, without nodes.
##   const IntroRules = preload("res://scripts/ui/intro/intro_rules.gd")

## The moments of the intro come from the music (scripts/ui/intro_timing.gd, written by
## tools/muziek/build.py from the MOMENTEN of the active composition, so they follow any new
## music): the logo on the first big entry (LOGO_AT), the story rolling from CRAWL_AT,
## paragraphs on the climax, the duel and the crash (CRAWL_CUES), the last one coming to rest on
## the final hit (REST_AT), and the end (END_AT) once that has rung out, where the menu takes
## over. The opening line fades in and out before the logo.
const IntroTiming = preload("res://scripts/ui/intro_timing.gd")

const OPENING_LINE := "Niet zo lang geleden, in een stad hier niet ver vandaan…"
## The story that rolls away after the logo, a paragraph per entry (an optional "\n"
## splits a paragraph into lines; a line too long for the picture wraps by itself).
## The count and order matter: CRAWL_CUES points at paragraphs by index.
const STORY := [
	"Den Haag. Hofstad, regeringsstad,\nstad van vrede en recht.",
	"Hier worden de grote besluiten genomen.\nMeestal na de lunch, en altijd pas na een tweede overleg.",
	"Ambtenaren fietsen van vergadering naar vergadering.\nLobbyisten kennen de weg naar binnen beter dan de bodes.",
	"Op het Malieveld staan de trekkers alweer te toeteren.\nWaartegen weet niemand precies, maar het klinkt boos.",
	"En op Scheveningen heersen de meeuwen.\nGeen patatje is er veilig.",
	"Midden in die stad woont een zwerver.\nGeen vast adres, wel een vaste bank aan het Lange Voorhout.",
	"Hij leeft van statiegeld. Twintig blikjes is een broodje bal,\ndertig is een broodje bal met mosterd.",
	"Als het regent zit hij in de bibliotheek\nen leest hij heel langzaam de krant van gisteren.",
	"Hij kent de rondes van elke handhaver,\nontwijkt elke fatbike en kijkt meeuwen nooit recht aan.",
	"Maar vandaag is alles anders. Zijn bank is weg.\nEr staat een hek omheen, met een bordje: Hier komt iets moois.",
	"Hij pakt zijn winkelwagen, trekt zijn jas recht\nen duwt de regen in.",
	"Zo begint zijn zwerftocht door Den Haag.",
]
## Bottom left the context action (ActionPrompts): SPATIE skips. Bottom right the
## secondary action, once the story rolls.
const SKIP_ACTION := ["SPATIE", "Overslaan"]
const FAST_TEXT := "[ENTER] SNELLER"

const LINE_IN_AT := 0.4
const LINE_OUT_AT := 3.6    # gone at 4.8, before the logo fades in
const LINE_FADE := 1.2
## The logo and the stars fade in from LOGO_FADE_IN_AT, stand there whole from LOGO_AT, and
## the logo stands big (LOGO_HOLD) until the exploration theme of the music (CRAWL_AT): there it starts
## to go away and the story comes in.
const LOGO_AT := IntroTiming.LOGO_AT
const LOGO_FADE_IN_AT := LOGO_AT - 1.0
const CRAWL_AT := IntroTiming.CRAWL_AT
## The story rolls to REST_AT (the final hit of the music): the last paragraph does not roll
## off the top but comes to rest there far off, and fades out while the hit rings out, to
## END_AT; no travel wasted, so it rolls as slowly as the music allows.
const REST_AT := IntroTiming.REST_AT
const END_AT := IntroTiming.END_AT
## Holding Enter (or the down arrow) rolls the story this many times as fast; it then
## reaches its end, and the intro the main menu, sooner (the music goes on into the menu).
const CRAWL_FAST := 12.0
const FAST_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER, KEY_DOWN]
## The keys that break the intro off.
const SKIP_KEYS: Array[Key] = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
## Paragraphs of STORY and the moment each comes in at the bottom of the screen: the civil
## servants on the chorus, the tramp himself on the breakdown, the way out into the rain on the
## finale (the last sentence then comes to rest on the final hit). Chosen so that between them
## the story rolls evenly, at much the same pace throughout (about 3.1 s a paragraph).
const CRAWL_CUES := {2: IntroTiming.CLIMAX_AT, 6: IntroTiming.DUEL_AT, 10: IntroTiming.CRASH_AT}
## Seconds the logo stands big before it goes (to the first big entry, CRAWL_AT), and that
## it takes to go away.
const LOGO_HOLD := CRAWL_AT - LOGO_AT
const LOGO_SECONDS := 2.5
## The logo: its size at the start (1.3: big, about nine tenths of the width of the screen)
## and at the end, far off.
const LOGO_START_SCALE := 1.3
## Its size as it comes in (nearly past the edges of the screen), shrinking slowly to
## LOGO_START_SCALE until it starts to go.
const LOGO_HUGE_SCALE := 5.0
const LOGO_END_SCALE := 0.02
## Where the logo vanishes in the distance a star twinkles, flaring up and dying out: from
## SPARKLE_AT for SPARKLE_SECONDS.
const SPARKLE_AT := LOGO_AT + LOGO_HOLD + LOGO_SECONDS * 0.92
const SPARKLE_SECONDS := 0.9
const SPARKLE_FLARE := 0.18   # share of it in which it flares up
## How sharp the dip of a twinkling star is (the wave to this power: mostly bright, now and
## then a short dip).
const TWINKLE_SHARPNESS := 6.0


## Whether `event` breaks the intro off: the space bar or Enter pressed (not held, no other key).
static func is_skip_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode in SKIP_KEYS


## How much the opening line shows at `time` (0 .. 1): fading in from LINE_IN_AT, out from
## LINE_OUT_AT (each over LINE_FADE).
static func line_alpha(time: float) -> float:
	var line_in := clampf((time - LINE_IN_AT) / LINE_FADE, 0.0, 1.0)
	var line_out := clampf((time - LINE_OUT_AT) / LINE_FADE, 0.0, 1.0)
	return line_in * (1.0 - line_out)


## Whether the stars are there at `time` (from LOGO_FADE_IN_AT on).
static func stars_shown(time: float) -> bool:
	return time >= LOGO_FADE_IN_AT


## How much the stars (and the logo with them) have come up at `time` (0 .. 1): fading in
## from LOGO_FADE_IN_AT to LOGO_AT.
static func fade_in(time: float) -> float:
	return clampf((time - LOGO_FADE_IN_AT) / (LOGO_AT - LOGO_FADE_IN_AT), 0.0, 1.0)


## Whether the logo is there at `time`: from LOGO_FADE_IN_AT until it has gone.
static func logo_shown(time: float) -> bool:
	return time >= LOGO_FADE_IN_AT and time - LOGO_AT < LOGO_HOLD + LOGO_SECONDS


## How far the logo is on its way off at `time` (0: standing, 1: gone), over LOGO_SECONDS
## after it stood LOGO_HOLD from LOGO_AT.
static func logo_going(time: float) -> float:
	return clampf((time - LOGO_AT - LOGO_HOLD) / LOGO_SECONDS, 0.0, 1.0)


## The scale of the logo at `time`: from huge (LOGO_HUGE_SCALE), easing out, down to its
## normal size (LOGO_START_SCALE) by the time it starts to go, then away as a thing that
## flies off ever faster (its distance grows with the square of the time, its size is one
## over the distance) down to LOGO_END_SCALE.
static func logo_scale(time: float) -> float:
	var going := logo_going(time)
	var distance := 1.0 + (LOGO_START_SCALE / LOGO_END_SCALE - 1.0) * going * going
	# before it goes: from huge, nearly past the edges, slowly down to its normal size
	# (easing out) by the time it starts to go
	var settling := clampf((time - LOGO_FADE_IN_AT) / (LOGO_AT + LOGO_HOLD - LOGO_FADE_IN_AT), 0.0, 1.0)
	var size := lerpf(LOGO_HUGE_SCALE, LOGO_START_SCALE, 1.0 - pow(1.0 - settling, 2.0))
	return size / distance


## How much the logo shows at `time` (0 .. 1): coming up with the stars, fading out the
## whole way as it goes.
static func logo_alpha(time: float) -> float:
	return fade_in(time) * (1.0 - logo_going(time))


## Whether the story rolls at `time` of the music (from CRAWL_AT).
static func crawl_started(time: float) -> bool:
	return time >= CRAWL_AT


## Whether the story has come to its end at `crawl_time` (the time of the music plus what
## the story is ahead of it): the intro is over.
static func crawl_ended(crawl_time: float) -> bool:
	return crawl_time >= END_AT


## The seconds the story gets further ahead of the music in `delta` seconds of Enter held.
static func crawl_gain(delta: float) -> float:
	return delta * (CRAWL_FAST - 1.0)


## How much the story shows at `crawl_time` (0 .. 1): whole until REST_AT, fading out to END_AT.
static func crawl_alpha(crawl_time: float) -> float:
	return clampf((END_AT - crawl_time) / maxf(END_AT - REST_AT, 0.1), 0.0, 1.0)


## Where the story stands at `crawl_time` (the top of its text in its picture, pixels):
## rolled evenly between the cues, each cue a paragraph of STORY coming in at the bottom
## of the picture (its top there: `paragraph_tops`, per paragraph its top in the text),
## from the whole text under the picture (`picture_height` high) at CRAWL_AT to the last
## paragraph at rest far off (`rest_share` of the picture's height from the top;
## `text_height`: how high the whole text is) at REST_AT, where it stays.
static func crawl_position(crawl_time: float, paragraph_tops: Array, text_height: float, picture_height: float, rest_share: float) -> float:
	var stops: Array = [[CRAWL_AT, picture_height]]
	var cue_paragraphs := CRAWL_CUES.keys()
	cue_paragraphs.sort()
	for paragraph_index: int in cue_paragraphs:
		if paragraph_index < paragraph_tops.size():
			stops.append([CRAWL_CUES[paragraph_index], picture_height - float(paragraph_tops[paragraph_index])])
	stops.append([REST_AT, picture_height * rest_share - text_height])
	return value_between(stops, crawl_time)


## The value at `time` on the way along `stops` ([time, value] each, in order of time): even
## between two stops, the first value before the first, the last after the last.
static func value_between(stops: Array, time: float) -> float:
	for stop_index in range(1, stops.size()):
		var earlier: Array = stops[stop_index - 1]
		var later: Array = stops[stop_index]
		if time <= later[0]:
			return lerpf(earlier[1], later[1], clampf((time - earlier[0]) / (later[0] - earlier[0]), 0.0, 1.0))
	return stops[-1][1]


## How far the twinkle where the logo vanishes is at `time` (0 .. 1 of its time; outside
## that it is not there).
static func sparkle_share(time: float) -> float:
	return (time - SPARKLE_AT) / SPARKLE_SECONDS


## Whether the twinkle is there at `twinkling` of its time.
static func sparkle_shown(twinkling: float) -> bool:
	return twinkling >= 0.0 and twinkling < 1.0


## How bright the twinkle is at `twinkling` (0 .. 1 of its time): flaring up over the first
## SPARKLE_FLARE of it, then dying out.
static func sparkle_flare(twinkling: float) -> float:
	return twinkling / SPARKLE_FLARE if twinkling < SPARKLE_FLARE \
			else 1.0 - (twinkling - SPARKLE_FLARE) / (1.0 - SPARKLE_FLARE)


## How bright a star is at `clock` (seconds): mostly bright, now and then a short dip, at
## its own `pace` (radians a second) and `phase`, `depth` deep.
static func twinkle_alpha(clock: float, pace: float, phase: float, depth: float) -> float:
	var wave := 0.5 + 0.5 * sin(clock * pace + phase)
	return 1.0 - depth * pow(wave, TWINKLE_SHARPNESS)


## Whether the secondary action ("sneller") shows at `time` of the music: while the story rolls.
static func fast_offered(time: float) -> bool:
	return time >= CRAWL_AT and time < END_AT
