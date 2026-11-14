extends "res://scripts/world/interiors/interior.gd"
## Den Haag Centraal from the inside (scenes/binnen/centraal.tscn, built by
## tools/build/build_interiors.gd from StationLayout): an Interior with life in it.
## - Trains (StationTrain) on twelve tracks: each track has its departure (`_departures`):
##   a time, a destination and a kind (StationLayout.DESTINATIONS), two or three cars, now and
##   then a delay or a train that does not run; the train comes in through the back wall
##   (from its "origin"), people get out, it stands its time, the conductor whistles, the
##   doors beep shut, and it leaves the way it came; soon after (GAP_MINUTES) the next one
##   comes in on that track, so arrivals and departures take turns on every track.
## - The departure boards over the hall, a display at the head of every track and the station
##   clock (with the red seconds hand) show the station's own clock (`_minutes`): set from the
##   town's day the first time you come in, then running at the pace of real time.
## - Announcements over the loudspeakers (StationAudio "Omroep": the band of a speaker, the
##   echo down the hall and the reverb of the hall): the chime, then the babble of the voices
##   of the game, the words as a line at the bottom of the screen.
## - People (StationPerson): travellers coming in at the doors, through the OV gates
##   (StationGates) to their platform, waiting, getting in when the doors open; others getting
##   out and going home or into a shop; how many and who (business people in the rush hours,
##   tourists by day) by the hour. Conductors to every train, enforcement officers on patrol
##   (in pairs in the hall, one on the platforms), the people behind the shop counters.
## - For the player: OV-chipkaart machines (buy one: "ov_chipkaart", CARD_PRICE), the gates
##   (they only open with a card) and the OV posts (check in or out with a beep).
## Markers it reads: Deur1..3, Dienstdeur, Poortjes_<n>, Vertrekbord_<n>, Perronscherm_<track>,
## Klok, Winkel_<n>, Verkoper_<n> (metadata "kind", "shop_name"), Uithangbord_<n>, Automaat_<n>;
## the OV posts are the props/ov/ov_incheckpaal in the GridMap Props.

const Conversations = preload("res://scripts/story/conversations.gd")
const Detour = preload("res://scripts/pathfinding/detour.gd")
const Interiors = preload("res://scripts/world/interiors/interiors.gd")
const Layout = preload("res://scripts/world/station/station_layout.gd")
const OverheadLines = preload("res://scripts/world/town/overhead_lines.gd")
const Announcer = preload("res://scripts/world/interiors/announcer.gd")
const DriverShout = preload("res://scripts/vehicles/driver_shout.gd")
## The rules of a chase (caught, given up): the same for whoever puts the player out of any
## interior (scripts/world/interiors/eviction.gd), here a BOA (handhaver) along the same routes.
const Pursuit = preload("res://scripts/world/interiors/pursuit.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")
const OvCard = preload("res://scripts/world/station/ov_card.gd")
const OvMachineScreen = preload("res://scripts/ui/machines/ov_machine_screen.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const QuestOutline = preload("res://scripts/effects/quest_outline.gd")
const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
## The bins on the platforms (props straat/prullenbak_paal past the gate line): a mission may
## want an empty can in two of them (Story.station_cans_wanted: the first
## mission's last two, behind the gates; MISSION_CAN_KINDS), put there as the player comes in
## (put_mission_can).
const PLATFORM_BIN := "straat/prullenbak_paal"
const CAN_REACH := 1.3
const MISSION_CAN_KINDS := ["perron_1", "perron_2"]
## How far apart (m) the two bins of the story's cans are at least when no other platform has one.
const MISSION_CANS_APART := 12.0
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const DOORS_GROUP := "deuren"
const CARD_ITEM := "ov_chipkaart"
const CARD_PRICE := 7.5
## Travellers in the station at the busiest hour, and the share of that by the hour.
const TRAVELLERS_AT_FULL := 70
const BUSY_BY_HOUR := [[0.0, 0.25], [4.0, 0.1], [6.0, 0.5], [7.5, 1.0], [9.5, 0.7], [12.5, 0.8],
	[16.0, 0.8], [17.5, 1.0], [19.0, 0.7], [22.0, 0.45], [24.0, 0.25]]
## Who travels by the hour: [from hour, {role: weight}].
const WHO_BY_HOUR := [
	[0.0, {"reiziger": 0.75, "student": 0.25}],
	[6.5, {"zakenman": 0.35, "student": 0.2, "reiziger": 0.35, "toerist": 0.1}],
	[9.5, {"zakenman": 0.12, "student": 0.1, "reiziger": 0.48, "toerist": 0.3}],
	[16.0, {"zakenman": 0.35, "student": 0.2, "reiziger": 0.35, "toerist": 0.1}],
	[19.0, {"zakenman": 0.05, "student": 0.2, "reiziger": 0.6, "toerist": 0.15}],
]
## People getting out of a train at the busiest hour (fewer when it is quiet; trains come
## often, so not too many each time).
const ALIGHTING_AT_FULL := 10
## The crowd comes and goes: new travellers walk in at the doors now and then (a random
## DOOR_ARRIVAL_SECONDS apart at the busiest hour, further apart when it is quiet; quicker,
## CATCH_UP_SECONDS, while there are far fewer than the hour wants) and get off the trains;
## they leave through the doors or get into a train. Both kinds of coming in stop at
## TRAVELLER_CAP_SHARE times the travellers the hour wants (_target_travellers), so the
## two balance out; a train still lets at least one person off when it is busy.
const DOOR_ARRIVAL_SECONDS := Vector2(1.5, 5.0)
const CATCH_UP_SECONDS := Vector2(0.5, 1.4)
const TRAVELLER_CAP_SHARE := 1.2
## Someone off a train who stays a while: a look at the departure boards first.
const LINGER_CHANCE := 0.15
## Fare dodging: the player crossing the gate line from the hall onto a platform without a
## check-in (StationGates.PASS_META; jumping over the paddles or slipping through behind
## someone) is seen with this chance (quiet .. busiest hour, more staff about); a conductor
## (the nearest one, else one at those gates) shouts (DriverShout "zwartrijden") and runs
## after them at CHASE_SPEED (the player walks 3, runs 6.5 m/s). Within CATCH_REACH: a fine
## of FINE_EUROS (all they have when it is less), a line over the player, and he goes back.
## He gives up when the player leaves the station, stays more than GIVE_UP_DISTANCE away for
## GIVE_UP_SECONDS, or after CHASE_SECONDS.
## The same the other way: from a platform into the hall without checking out (still checked
## in: the chase is for "niet uitgecheckt", DriverShout "uitchecken"; caught, the fine and he
## checks them out; not checked in at all: zwartrijden). Who leaves the station still checked
## in owes the boarding fare (OvCard.leave_open_trip).
## On the platforms a conductor checks: the player within INSPECTION_REACH of one (not one
## getting into a train or already after them) is asked for their card with INSPECTION_CHANCE
## (once per conductor: INSPECTED_META); without a check-in (slipped through unseen, checked
## out at a post) he is after them as at the gates. Fined on the platforms: no more checks
## until they are back in the hall.
const FARE_CHECK_CHANCE := Vector2(0.35, 0.5)
const INSPECTION_REACH := 3.0
const INSPECTION_CHANCE := 0.5
const INSPECTED_META := "kaart_gecontroleerd"
const FINE_EUROS := 50.0
const CHASE_SPEED := 4.6
const CATCH_REACH := 1.0
const GIVE_UP_DISTANCE := 15.0
const GIVE_UP_SECONDS := 3.0
const CHASE_SECONDS := 30.0
const CONDUCTOR_NOTICE_RANGE := 35.0
const FINE_COLOUR := Color("#FF5A4A")
## The arrow over a shop (InteriorPerson.place_mark_ahead): this far before its front (m),
## its point between these heights (under the shop sign at 3 m).
const SHOP_MARK_AHEAD := 0.6
## Travellers added per frame when the hall is topped up (_top_up).
const POPULATE_PER_FRAME := 3
## The board over a stall (_shop_board): its size (m) and how tall the logo on it is.
const SHOP_BOARD_SIZE := Vector3(2.4, 0.6, 0.06)
const SHOP_LOGO_HEIGHT := 0.42
const SHOP_MARK_BOTTOM := 1.9
const SHOP_MARK_TOP := 2.4
## The chase goes along the floor: on the player's platform (or in the hall with them)
## straight at them, else along the travellers' route (through the gates); with the player
## down on the rails he waits at the edge above them and shouts (never onto the rails).
## Every CHASE_REPLAN seconds he looks again which way to go. Whoever is after the player
## (the conductor, or a BOA putting them out: evictor_for) keeps the way it is going in
## CHASE_PLAN_META, when it looks again in CHASE_CLOCK_META and how fast in CHASE_SPEED_META.
const CHASE_REPLAN := 0.5
const CHASE_PLAN_META := "achtervolging_plan"
const CHASE_CLOCK_META := "achtervolging_klok"
const CHASE_SPEED_META := "achtervolging_vaart"
## How far off (m) a BOA still sees what the player does and warns them (warner_for).
const WARN_REACH := 40.0
## Falling off a platform by accident (StationPerson at an edge: station.stumbles): the
## chance at an edge, for someone walking and for a conductor in a chase; never onto a
## track with a train. Then he climbs back up (StationPerson "climb") and goes on.
const STUMBLE_CHANCE := 0.03
const CHASE_STUMBLE_CHANCE := 0.2
## Someone waiting for a train gives up after this many seconds (and goes on to something else).
const WAIT_TRAIN_LIMIT := 300.0
## Every track goes round: a train arrives (from its "origin"), stands DWELL_MINUTES at the
## platform (people get out and in), leaves the way it came, and GAP_MINUTES after it has
## gone the next one comes in. With the time to come in and go out (about 15 s each) a
## track has a train every 2.5 to 4.5 minutes, the twelve together one about every 20 s.
const DWELL_MINUTES := Vector2(1.6, 3.0)
const GAP_MINUTES := Vector2(0.2, 1.0)
const DELAY_CHANCE := 0.12
const DELAY_MINUTES := Vector2i(1, 5)
const CANCEL_CHANCE := 0.03
## Arrivals are announced as rarely as departures (DEPARTURE_ANNOUNCE_CHANCE).
const ARRIVAL_ANNOUNCE_CHANCE := 0.15
## Seconds before leaving: the announcement, the whistle, the doors shutting.
const ANNOUNCE_SECONDS := 150.0
const WHISTLE_SECONDS := 17.0
const CLOSE_SECONDS := 12.0
## Rows on a departure board.
const BOARD_ROWS := 7
## The blue face of a departure board (binnen/station/vertrekbord: 6 m wide, a frame of
## 0.125 m) reaches this far either side of its middle, the columns start (x, metres) at:
## the time, the destination, the track (centred) and the remark; each text is made smaller
## when it would reach past the next column or the edge (_fit_text).
const BOARD_EDGE := 2.8
const BOARD_COLUMNS := [-2.75, -1.95, 1.65, 2.0]
## The face of a platform display (binnen/station/perronscherm: 2.5 m wide): the white square
## for the track number (centre and width) and where its text starts and ends.
const DISPLAY_NUMBER_X := -0.81
const DISPLAY_NUMBER_WIDTH := 0.5
const DISPLAY_TEXT_LEFT := -0.4
const DISPLAY_EDGE := 1.08
const BOARD_WHITE := Color("#F2F4F8")
const BOARD_YELLOW := Color("#FFD23A")
const BOARD_RED := Color("#FF5A4A")
const BOARD_BLUE := Color("#0A2A6A")
const ANNOUNCER_VOICE := "vrouw"
## How often the loudspeakers speak: after an announcement it stays quiet a random number of
## seconds between these two; only this share of the departures is announced (with twelve
## tracks every one would be far too much), and a general notice (NOTICES) comes after a
## random wait between NOTICE_SECONDS, never the same one twice in a row. An announcement
## that had to wait longer than ANNOUNCEMENT_STALE_SECONDS is dropped (its train is gone).
const ANNOUNCEMENT_PAUSE_SECONDS := Vector2(60.0, 150.0)
const DEPARTURE_ANNOUNCE_CHANCE := 0.15
const NOTICE_SECONDS := Vector2(360.0, 900.0)
const ANNOUNCEMENT_STALE_SECONDS := 60.0
## The words of an announcement type out (Typewriter, with its cursor) at this share of the
## speed of the story box, as fast as the voice babbles on (the babble goes on until the
## last word is there); then the whole line stays ANNOUNCEMENT_HOLD_SECONDS.
const ANNOUNCEMENT_TYPE_SPEED := 0.4
const ANNOUNCEMENT_HOLD_SECONDS := 2.5
const NOTICES := [
	"Let op: laat uw bagage niet onbeheerd achter.",
	"Roken is op het hele station niet toegestaan.",
	"Pas op voor zakkenrollers. Houd uw spullen bij u.",
	"Laat bij het instappen eerst de reizigers uitstappen.",
	"Vergeet niet in en uit te checken met uw OV-chipkaart.",
	"De lift naar perron 3 is tijdelijk buiten gebruik.",
	"Wilt u de eigenaar van een blauwe rolkoffer bij spoor 6 zich melden bij de servicebalie?",
	"Fietsen zijn in de stationshal niet toegestaan.",
]
## Obstacles in the hall people walk round (x, z, width, depth).
const HALL_OBSTACLES := [
	Rect2(-48.0, -30.5, 4.0, 21.0),       # the shops along the left wall
	Rect2(-8.0, -21.5, 16.0, 6.0),        # the block of shops in the middle
	Rect2(46.0, -25.6, 2.0, 4.2),         # the ticket machines on the right
	Rect2(46.0, -14.6, 2.0, 3.2),
	Rect2(-37.6, -6.5, 2.2, 1.0), Rect2(35.4, -6.5, 2.2, 1.0),
	Rect2(-31.2, -26.6, 4.8, 1.2), Rect2(-21.2, -26.6, 4.8, 1.2), Rect2(18.8, -26.6, 4.8, 1.2), Rect2(28.8, -26.6, 4.8, 1.2),
	Rect2(-40.3, -24.3, 0.6, 0.6), Rect2(-16.3, -24.3, 0.6, 0.6), Rect2(15.7, -24.3, 0.6, 0.6), Rect2(39.7, -24.3, 0.6, 0.6),
	Rect2(-40.3, -12.3, 0.6, 0.6), Rect2(-16.3, -12.3, 0.6, 0.6), Rect2(15.7, -12.3, 0.6, 0.6), Rect2(39.7, -12.3, 0.6, 0.6),
]
const OBSTACLE_MARGIN := 0.7
## The overhead lines over the twelve tracks (_make_overhead_lines): the contact wire this
## high over the rails (as outside, OverheadLines.train_wire_height, so the pantographs touch
## it), the carrier wire CARRIER_RISE over it at a support, sagging CARRIER_SAG halfway. The
## supports are cantilevers from the white roof columns down the middle of every island
## (binnen/station/pilaar, at SUPPORT_Z) and from slim masts at the walls beside the two
## outer tracks; the wires run from just past the buffer stops (WIRE_FRONT_Z) through the
## openings in the back wall.
const CONTACT_WIRE_HEIGHT := 5.6
const CARRIER_RISE := 1.0
const CARRIER_SAG := 0.35
const SUPPORT_Z := [8.0, 20.0, 32.0, 44.0]
const WIRE_FRONT_Z := 1.5
const DROPPER_STEP := 3.0
const COLUMN_HALF_WIDTH := 0.25
## The masts at the walls: how far from the wall, their thickness and height (metres).
const WALL_MAST_INSET := 0.9
const WALL_MAST_WIDTH := 0.25
const WALL_MAST_HEIGHT := 6.0
const MAST_COLOUR := Color(0.6, 0.62, 0.64)

var _player: Node3D
var _setup := false
var _random := RandomNumberGenerator.new()
var _minutes := 13.0 * 60.0
var _clock_set := false
var _departures: Array[Dictionary] = []
var _track_departure := {}           # track -> its departure
var _next_id := 0
var _gates: Array[StationGates] = []
var _walkers: Array[StationPerson] = []
var _topping_up := false            # _top_up under way
var _keepers: Array[InteriorPerson] = []
var _patrol_leaders: Array[StationPerson] = []
var _platform_patrol: StationPerson
var _mission_cans := {}                # kind ("perron_1", "perron_2") -> the can a mission wants there (put_mission_can)
var _mission_cans_taken := {}          # the kinds whose can the player has taken
var _props_library: MeshLibrary
var _binnen_library: MeshLibrary
var _boards: Array = []               # per board: Array of rows [time, destination, track, remark]
var _displays := {}                   # track -> {"number", "time", "destination"} Label3D
var _hands := {}                      # "hour", "minute", "second" -> Node3D
var _shop_fronts: Array[Node3D] = []
var _posts: Array[Vector3] = []
var _spawn_clock := 0.0
var _board_clock := 0.0
var _notice_clock := 180.0
## Its own random numbers for the announcements, different every game (the station's
## _random has a fixed seed, so the same notices would come in the same order every time).
var _announcement_random := RandomNumberGenerator.new()
var _last_notice := -1
var _announcement_pause := 0.0       # seconds the loudspeakers stay quiet still
var _announcements: Array[Dictionary] = []   # {"text", "queued_at"} (minutes of the station clock)
var _announcer: Announcer             # the loudspeakers (the shared Announcer)
## Fare dodging (FARE_CHECK_CHANCE): which side of the gate line the player was on (-1 the
## hall, 1 the platforms, 0 not known yet), the conductor after them and for how long.
var _player_side := 0
var _chaser: StationPerson
var _pursuit: Pursuit                # the rules of his chase (caught, given up)
## Why he is after them: "zwartrijden" or "uitchecken" (not checked out).
var _chase_reason := "zwartrijden"
## Fined on the platforms: no more checks until they are back in the hall (the fine is
## their ticket).
var _fined_on_the_platforms := false
## Which way the conductor is going now (CHASE_REPLAN; for the checks).
var _chase_plan: String:
	get:
		return String(_chaser.get_meta(CHASE_PLAN_META, "")) if _chaser != null and is_instance_valid(_chaser) else ""
## For the checks: how many fell onto the rails and climbed back up, and who was given
## another way because they got stuck.
var falls := 0
var climbs := 0
var unstuck := 0
var _fare_random := RandomNumberGenerator.new()
## For the checks: the chance of being seen (< 0: FARE_CHECK_CHANCE), and what happened.
var fare_check_chance_override := -1.0
## The chance of a check on the platform (< 0: INSPECTION_CHANCE), and how many there were.
var inspection_chance_override := -1.0
var inspections := 0
var chases_started := 0
var fines := 0
var chases_given_up := 0


## The player, while inside (the gates, machines and posts ask for them).
func player() -> Node3D:
	return _player


func dress(bar_name: String, _seed: int) -> void:
	snack_bar_name = bar_name
	_ensure_setup()


func people() -> Array[InteriorPerson]:
	return _keepers


## Everyone walking about (travellers and staff).
func station_people() -> Array[StationPerson]:
	return _walkers


func departures() -> Array[Dictionary]:
	return _departures


func trains() -> Array:
	return _departures.filter(func(departure: Dictionary) -> bool: return departure.train != null).map(
			func(departure: Dictionary) -> StationTrain: return departure.train)


func player_came_in(who: Node3D) -> void:
	_player = who
	_player_side = 0
	_fined_on_the_platforms = false
	_ensure_setup()
	put_mission_can()
	# topped up a few at a time (each figure is built of voxels: all at once stalls the game)
	if _walkers.size() < _target_travellers() / 2 and not _topping_up:
		_top_up()


## Fills the hall up to the travellers the hour wants, POPULATE_PER_FRAME a frame.
func _top_up() -> void:
	_topping_up = true
	var wanted := _target_travellers()
	while is_inside_tree() and _travellers() < wanted:
		for index in POPULATE_PER_FRAME:
			_spawn_one_traveller()
		await get_tree().process_frame
	_topping_up = false


func player_went_out() -> void:
	if _announcer:
		_announcer.hide_subtitle()
	_tell_story_cans(false)   # the cans no longer marked: the town's map again
	# out of the station: the conductor has lost them
	_end_chase()
	# still checked in: not checked out, the boarding fare is owed (OvCard)
	if _player != null and is_instance_valid(_player):
		OvCard.leave_open_trip(_player)


## The station's clock (minutes since midnight, running on past 24 h).
func minutes() -> float:
	return _minutes


func hour() -> float:
	return fposmod(_minutes / 60.0, 24.0)


# ------------------------------------------------------------------ setting up

func _ensure_setup() -> void:
	if _setup:
		return
	_setup = true
	_random.seed = 20261110
	_announcement_random.randomize()
	_fare_random.randomize()
	_notice_clock = _announcement_random.randf_range(120.0, 360.0)
	StationAudio.ensure_buses()
	var furniture := get_node_or_null("Inrichting") as GridMap
	_binnen_library = furniture.mesh_library if furniture else load("res://assets/libraries/binnen.res")
	var props := get_node_or_null("Props") as GridMap
	_props_library = props.mesh_library if props and props.mesh_library else load(PROPS_LIBRARY)
	_sync_clock()
	_make_gates()
	_make_shops()
	_make_machines()
	_make_posts(props)
	_make_boards()
	_make_displays()
	_make_clock()
	_make_overhead_lines()
	_make_announcer()
	_plan_start()
	_spawn_staff()


func _sync_clock() -> void:
	if _clock_set:
		return
	var town := get_parent().get_parent() if get_parent() else null
	var day := town.get_node_or_null("Dagcyclus") if town else null
	if day and day.get("time_of_day") != null:
		_minutes = float(day.time_of_day) * 60.0
		_clock_set = true


func _make_gates() -> void:
	var number := 1
	while has_node("Poortjes_%d" % number):
		var marker := get_node("Poortjes_%d" % number) as Node3D
		var gates := StationGates.new()
		gates.name = "Poortjes%d" % number
		add_child(gates)
		gates.position = marker.position
		gates.build(number - 1, _binnen_library, self)
		_gates.append(gates)
		number += 1


func _make_shops() -> void:
	var number := 1
	while has_node("Verkoper_%d" % number):
		var keeper_marker := get_node("Verkoper_%d" % number) as Node3D
		var kind := String(keeper_marker.get_meta("kind", "kiosk"))
		var role := "snackbarhouder" if kind == "smikkels" else "verkoper"
		# dressed for the shop (winkels.json "kleding": the barista in black, the florist in green)
		var outfit: Dictionary = ((Conversations.shops().get("winkels", {}) as Dictionary).get(kind, {}) as Dictionary).get("kleding", {})
		var keeper := InteriorPerson.create(role, 4000 + number * 17, false, InteriorPerson.SEAT_HEIGHT, outfit)
		keeper.name = "Verkoper"
		keeper.set_meta("shop_name", keeper_marker.get_meta("shop_name", ""))
		# what it sells: the shop of this kind in data/gesprekken/winkels.json (the shop screen)
		keeper.set_meta("kind", kind)
		add_child(keeper)
		keeper.transform = keeper_marker.transform
		_keepers.append(keeper)
		var front := get_node_or_null("Winkel_%d" % number) as Node3D
		if front:
			_shop_fronts.append(front)
			# the arrow out in front of the shop, where you stand to buy (over the seller it
			# would stick out of the shop's roof)
			keeper.place_mark_ahead(keeper_marker.position.distance_to(front.position) + SHOP_MARK_AHEAD, SHOP_MARK_BOTTOM, SHOP_MARK_TOP)
		var sign_marker := get_node_or_null("Uithangbord_%d" % number) as Node3D
		if sign_marker:
			var logo: Dictionary = ((Conversations.shops().get("winkels", {}) as Dictionary).get(kind, {}) as Dictionary).get("logo", {})
			var board := _shop_board(String(keeper_marker.get_meta("shop_name", "")), logo)
			board.transform = sign_marker.transform
			add_child(board)
		number += 1


## The board over a stall (winkels.json "logo"): a plate in the shop's colour ("kleur"), on
## it the logo (the pixel icon "icoon" of the game's menus, GameMenu.ITEM_ICONS, in the text
## colour) and the shop's name ("tekst" colour); its front to the node's +z.
func _shop_board(shop_name: String, logo: Dictionary) -> Node3D:
	var board := Node3D.new()
	board.name = "Uithangbord"
	var plate := MeshInstance3D.new()
	plate.name = "Bord"
	var box := BoxMesh.new()
	box.size = SHOP_BOARD_SIZE
	plate.mesh = box
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color(str(logo.get("kleur", "#22304A")))
	plate_material.roughness = 0.7
	plate.material_override = plate_material
	plate.position = Vector3(0.0, 0.0, -SHOP_BOARD_SIZE.z * 0.5 - 0.01)
	board.add_child(plate)
	var text_colour := Color(str(logo.get("tekst", "#FFFFFF")))
	var icon_name := str(logo.get("icoon", ""))
	var has_icon := GameMenu.ITEM_ICONS.has(icon_name)
	if has_icon:
		var sprite := Sprite3D.new()
		sprite.name = "Logo"
		sprite.texture = _icon_texture(GameMenu.ITEM_ICONS[icon_name].rows, text_colour)
		sprite.pixel_size = SHOP_LOGO_HEIGHT / float(sprite.texture.get_height())
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.position = Vector3(-SHOP_BOARD_SIZE.x * 0.5 + SHOP_LOGO_HEIGHT * 0.5 + 0.12, 0.0, 0.005)
		board.add_child(sprite)
	var name_label := _label(shop_name.to_upper(), 40, 0.0045, text_colour)
	name_label.name = "Naam"
	var name_room := SHOP_BOARD_SIZE.x - (SHOP_LOGO_HEIGHT + 0.3 if has_icon else 0.2)
	name_label.text = ""   # _fit_text does nothing for the text it already has
	_fit_text(name_label, shop_name.to_upper(), name_room)
	name_label.position = Vector3((SHOP_LOGO_HEIGHT + 0.2) * 0.5 if has_icon else 0.0, 0.0, 0.006)
	board.add_child(name_label)
	return board


## A pixel icon ("#" coloured, anything else clear) as a small texture.
static func _icon_texture(rows: Array, colour: Color) -> ImageTexture:
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	var image := Image.create(width + 2, rows.size() + 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for row_index in rows.size():
		var row: String = rows[row_index]
		for column in row.length():
			if row[column] == "#":
				image.set_pixel(column + 1, row_index + 1, colour)
	return ImageTexture.create_from_image(image)


## The OV-chipkaart machines: [E] opens the machine's own screen (OvMachineScreen,
## scripts/ui/machines/ov_machine_screen.gd: buy a card, see the balance, top up, a single
## ticket; OvCard keeps the card's balance).
class TicketMachine:
	extends "res://scripts/world/things/interactable.gd"
	var station: Node3D

	func _init() -> void:
		kind = KIND_MACHINE

	func action_text() -> String:
		return "OV-chipkaartautomaat"

	func reach() -> float:
		return 1.2

	func go_through() -> void:
		var player: Node3D = station.call("player")
		if player == null:
			return
		OvMachineScreen.show_for(player, "DEN HAAG CENTRAAL")

	## A card straight away, as the screen's "kaart kopen" (the checks): "ok", "heb_al", "geld", "vol".
	func buy_card() -> String:
		return OvCard.buy_card(station.call("player"))


func _make_machines() -> void:
	var number := 1
	while has_node("Automaat_%d" % number):
		var marker := get_node("Automaat_%d" % number) as Node3D
		var machine := TicketMachine.new()
		machine.name = "Kaartautomaat"
		machine.station = self
		add_child(machine, true)
		machine.position = marker.position
		machine.add_to_group(DOORS_GROUP)
		number += 1


## An OV post: check in or out with the card.
class OvPost:
	extends "res://scripts/world/things/interactable.gd"
	var station: Node3D

	func _init() -> void:
		kind = KIND_GATE

	func action_text() -> String:
		var player: Node3D = station.call("player")
		return OvCard.post_action(player) if player else "Inchecken"

	func reach() -> float:
		return 1.1

	func go_through() -> void:
		var player: Node3D = station.call("player")
		if player == null:
			return
		var at := position + Vector3.UP * 1.6
		# a card with the fare on it or a single ticket (OvCard.tap); a trip not checked out
		# before: the boarding fare is kept now
		var result := OvCard.tap(player)
		StationAudio.play_at(station, String(result.sound), position + Vector3.UP, -6.0)
		var red: bool = not result.ok or float(result.charge) > 0.0
		station.call("say", at, String(result.text), Color("#FF5A4A") if red else Color("#3CE06A"))


func _make_posts(props: GridMap) -> void:
	if props == null or props.mesh_library == null:
		return
	var item := props.mesh_library.find_item_by_name("ov/ov_incheckpaal")
	if item < 0:
		return
	for cell in props.get_used_cells_by_item(item):
		var at := props.position + props.map_to_local(cell)
		at.y = 0.0
		_posts.append(at)
		var post := OvPost.new()
		post.name = "Incheckpaal"
		post.station = self
		add_child(post, true)
		post.position = at
		post.add_to_group(DOORS_GROUP)


func _make_boards() -> void:
	var number := 1
	while has_node("Vertrekbord_%d" % number):
		var marker := get_node("Vertrekbord_%d" % number) as Node3D
		var board := Node3D.new()
		board.name = "Tekst"
		marker.add_child(board)
		for heading: Array in [["VERTREK", BOARD_COLUMNS[0], true], ["NAAR", BOARD_COLUMNS[1], true], ["SPOOR", BOARD_COLUMNS[2], false]]:
			var header := _label(heading[0], 30, 0.0034, BOARD_BLUE, heading[2])
			header.position = Vector3(heading[1], 0.69, 0.01)
			board.add_child(header)
		var rows := []
		for row_index in BOARD_ROWS:
			var y := 0.5 - row_index * 0.19
			var row := []
			# [time, destination, track, remark]: the order of the row (_update_boards)
			for column: Array in [[BOARD_COLUMNS[0], BOARD_WHITE, true], [BOARD_COLUMNS[1], BOARD_WHITE, true],
					[BOARD_COLUMNS[2], BOARD_WHITE, false], [BOARD_COLUMNS[3], BOARD_YELLOW, true]]:
				var label := _label("", 40, 0.0034, column[1], column[2])
				label.position = Vector3(column[0], y, 0.01)
				board.add_child(label)
				row.append(label)
			rows.append(row)
		_boards.append(rows)
		number += 1


func _make_displays() -> void:
	for track in range(1, Layout.TRACK_COUNT + 1):
		var marker := get_node_or_null("Perronscherm_%d" % track) as Node3D
		if marker == null:
			continue
		var number := _label("", 64, 0.006, BOARD_BLUE)
		number.position = Vector3(DISPLAY_NUMBER_X, 0.0, 0.01)
		marker.add_child(number)
		_fit_text(number, str(track), DISPLAY_NUMBER_WIDTH)
		var time := _label("", 34, 0.0034, BOARD_WHITE, true)
		time.position = Vector3(DISPLAY_TEXT_LEFT, 0.12, 0.01)
		marker.add_child(time)
		var destination := _label("", 34, 0.0034, BOARD_WHITE, true)
		destination.position = Vector3(DISPLAY_TEXT_LEFT, -0.11, 0.01)
		marker.add_child(destination)
		_displays[track] = {"number": number, "time": time, "destination": destination}


func _make_clock() -> void:
	var marker := get_node_or_null("Klok") as Node3D
	if marker == null:
		return
	var face := Node3D.new()
	face.name = "Wijzers"
	face.position = Vector3(0.0, 0.0, 0.14)
	marker.add_child(face)
	for hand: Array in [["hour", 0.26, 0.07, Color("#141414")], ["minute", 0.4, 0.05, Color("#141414")], ["second", 0.38, 0.018, Color("#D8231C")]]:
		var pivot := Node3D.new()
		pivot.name = hand[0]
		face.add_child(pivot)
		var piece := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(hand[2], hand[1], 0.02)
		piece.mesh = bar
		piece.position = Vector3(0.0, float(hand[1]) * 0.5 - 0.04, float(_hands.size()) * 0.01)
		var material := StandardMaterial3D.new()
		material.albedo_color = hand[3]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		piece.material_override = material
		pivot.add_child(piece)
		if hand[0] == "second":
			# the red disc at the end of the seconds hand (the Swiss railway clock)
			var disc := MeshInstance3D.new()
			var round_end := CylinderMesh.new()
			round_end.top_radius = 0.05
			round_end.bottom_radius = 0.05
			round_end.height = 0.02
			disc.mesh = round_end
			disc.rotation.x = PI * 0.5
			disc.position = Vector3(0.0, float(hand[1]) - 0.1, 0.03)
			disc.material_override = material
			pivot.add_child(disc)
		_hands[hand[0]] = pivot


## The overhead lines over every track (see CONTACT_WIRE_HEIGHT): contact and carrier wire
## with droppers, a cantilever to each track from its support, and the masts at the walls
## (each with a slim collider; the wires and arms hang out of reach and have none).
func _make_overhead_lines() -> void:
	var contact_y := -Layout.PLATFORM_DROP + CONTACT_WIRE_HEIGHT
	var carrier_y := contact_y + CARRIER_RISE
	var pieces: Array[PackedVector3Array] = []
	for track in range(1, Layout.TRACK_COUNT + 1):
		var track_x := Layout.track_x(track)
		_add_track_wires(pieces, track_x, contact_y, carrier_y)
		# the support on the platform side of the track: a roof column in the middle of an
		# island, or a mast at the wall beside an outer track
		var platform: Array = Layout.platforms()[Layout.platform_of_track(track)]
		var span := Layout.platform_span(platform)
		var support_x := (span.x + span.y) * 0.5
		var outer := int(platform[0]) == int(platform[1])
		if outer:
			support_x = Layout.HALL_LEFT + WALL_MAST_INSET if support_x < 0.0 else Layout.HALL_RIGHT - WALL_MAST_INSET
		var towards := signf(track_x - support_x)
		var arm_start := support_x + towards * (WALL_MAST_WIDTH * 0.5 if outer else COLUMN_HALF_WIDTH)
		for support_z: float in SUPPORT_Z:
			_add_cantilever(pieces, arm_start, track_x, towards, support_z, contact_y, carrier_y)
	var helper := OverheadLines.new()
	var wires := MeshInstance3D.new()
	wires.name = "Bovenleiding"
	wires.mesh = helper._wire_mesh(pieces)
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	helper.free()
	add_child(wires)
	var mast_number := 0
	for wall_x: float in [Layout.HALL_LEFT + WALL_MAST_INSET, Layout.HALL_RIGHT - WALL_MAST_INSET]:
		for support_z: float in SUPPORT_Z:
			mast_number += 1
			_add_wall_mast(Vector3(wall_x, 0.0, support_z), mast_number)


## The wires over one track: the level contact wire from the buffer stop through the back
## wall; above it the carrier wire, sagging between the supports, coming down to the
## contact wire at its front end (where it is anchored); droppers between the two.
func _add_track_wires(pieces: Array[PackedVector3Array], track_x: float, contact_y: float, carrier_y: float) -> void:
	pieces.append(PackedVector3Array([Vector3(track_x, contact_y, WIRE_FRONT_Z), Vector3(track_x, contact_y, Layout.BACK_WALL + 1.0)]))
	var stops: Array[float] = [WIRE_FRONT_Z]
	stops.append_array(SUPPORT_Z)
	stops.append(Layout.BACK_WALL + 1.0)
	for stop_index in stops.size() - 1:
		var from_z: float = stops[stop_index]
		var to_z: float = stops[stop_index + 1]
		var segment_count := maxi(ceili((to_z - from_z) / 1.0), 1)
		var previous := Vector3.ZERO
		for segment_index in segment_count + 1:
			var share := float(segment_index) / segment_count
			var along_z := lerpf(from_z, to_z, share)
			var height: float
			if stop_index == 0:
				# the anchored front end: from the contact wire up to the first support
				height = lerpf(contact_y + 0.15, carrier_y, share)
			else:
				var sag_here := CARRIER_SAG * 4.0 * share * (1.0 - share)
				height = carrier_y - sag_here
			var point := Vector3(track_x, height, along_z)
			if segment_index > 0:
				pieces.append(PackedVector3Array([previous, point]))
			previous = point
		# droppers from the carrier wire down to the contact wire
		var dropper_z := from_z + DROPPER_STEP
		while dropper_z < to_z - 1.0:
			var share := (dropper_z - from_z) / (to_z - from_z)
			var top := lerpf(contact_y + 0.15, carrier_y, share) if stop_index == 0 \
				else carrier_y - CARRIER_SAG * 4.0 * share * (1.0 - share)
			if top - contact_y > 0.2:
				pieces.append(PackedVector3Array([Vector3(track_x, top, dropper_z), Vector3(track_x, contact_y, dropper_z)]))
			dropper_z += DROPPER_STEP


## A cantilever from a support (`arm_start`, on the side of the track `towards` points away
## from) to the wires over `track_x` at `support_z`: the top tube holding the carrier wire,
## the diagonal brace under it, the registration arm holding the contact wire.
func _add_cantilever(pieces: Array[PackedVector3Array], arm_start: float, track_x: float, towards: float,
		support_z: float, contact_y: float, carrier_y: float) -> void:
	var beyond := track_x + towards * 0.3
	pieces.append(PackedVector3Array([Vector3(arm_start, carrier_y + 0.1, support_z), Vector3(beyond, carrier_y + 0.1, support_z)]))
	pieces.append(PackedVector3Array([Vector3(arm_start, contact_y - 0.3, support_z), Vector3(track_x - towards * 0.5, carrier_y + 0.1, support_z)]))
	pieces.append(PackedVector3Array([Vector3(track_x - towards * 1.0, contact_y + 0.45, support_z), Vector3(track_x, contact_y, support_z)]))
	pieces.append(PackedVector3Array([Vector3(track_x, carrier_y + 0.1, support_z), Vector3(track_x, contact_y, support_z)]))


## A slim galvanised mast at the wall (its foot at `foot`, on the platform), with a collider
## just as slim.
func _add_wall_mast(foot: Vector3, number: int) -> void:
	var mast := StaticBody3D.new()
	mast.name = "Bovenleidingmast_%d" % number
	mast.collision_layer = 1
	mast.collision_mask = 0
	mast.position = foot + Vector3.UP * WALL_MAST_HEIGHT * 0.5
	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(WALL_MAST_WIDTH, WALL_MAST_HEIGHT, WALL_MAST_WIDTH)
	var material := StandardMaterial3D.new()
	material.albedo_color = MAST_COLOUR
	material.metallic = 0.5
	material.roughness = 0.5
	pole_mesh.material = material
	pole.mesh = pole_mesh
	mast.add_child(pole)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WALL_MAST_WIDTH, WALL_MAST_HEIGHT, WALL_MAST_WIDTH)
	shape.shape = box
	mast.add_child(shape)
	add_child(mast)


## The loudspeakers (Announcer): the gong, two seconds, the voice while the words type out,
## the line shown only while the player is inside; no music to duck.
func _make_announcer() -> void:
	_announcer = Announcer.new()
	_announcer.voice = ANNOUNCER_VOICE
	_announcer.voice_clips = 3
	_announcer.intro_seconds = 2.0
	_announcer.clip_gap = 0.06
	_announcer.missing_clip_seconds = 0.6
	_announcer.most_clips = 12
	_announcer.type_speed = ANNOUNCEMENT_TYPE_SPEED
	_announcer.hold_seconds = ANNOUNCEMENT_HOLD_SECONDS
	_announcer.subtitle_wanted = func() -> bool: return _player != null and is_visible_in_tree()
	_announcer.finished.connect(func(_text: String) -> void:
		_announcement_pause = _announcement_random.randf_range(ANNOUNCEMENT_PAUSE_SECONDS.x, ANNOUNCEMENT_PAUSE_SECONDS.y))
	add_child(_announcer)


func _label(text: String, font_size: int, pixel_size: float, colour: Color, left := false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = colour
	label.outline_size = 0
	label.shaded = false
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if left:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.set_meta("full_pixel_size", pixel_size)
	return label


## Puts `text` on `label`, made smaller (its pixel_size) when it would be wider than
## `max_width` metres, so it stays on its board.
func _fit_text(label: Label3D, text: String, max_width: float) -> void:
	if label.text == text:
		return
	label.text = text
	var full_size := float(label.get_meta("full_pixel_size", label.pixel_size))
	label.pixel_size = full_size
	if text.is_empty() or label.font == null:
		return
	var text_width := label.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * full_size
	if text_width > max_width:
		label.pixel_size = full_size * max_width / text_width


## A line rising over a spot (in the space of the station): the HUD's floating text.
func say(at: Vector3, text: String, colour: Color) -> void:
	var town := get_parent().get_parent() if get_parent() else null
	var hud := town.get_node_or_null("HUD") if town else null
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(to_global(at), text, colour, 14)


# ------------------------------------------------------------------ the timetable

func _departs_at(departure: Dictionary) -> float:
	return float(departure.time) + float(departure.delay)


func _seconds_left(departure: Dictionary) -> float:
	return (_departs_at(departure) - _minutes) * 60.0


## The next train on `track`: it comes in at `arrive_at` (station minutes) or a little
## after (its departure time is a whole minute, its dwell before that), from somewhere of its
## kind, and leaves for its destination.
func _plan(track: int, arrive_at: float) -> Dictionary:
	var destination: Array = Layout.DESTINATIONS[_random.randi() % Layout.DESTINATIONS.size()]
	var intercity: bool = destination[1] == "Intercity"
	var dwell := _random.randf_range(DWELL_MINUTES.x, DWELL_MINUTES.y)
	var origin := String(destination[0])
	for attempt in 4:
		var candidate: Array = Layout.DESTINATIONS[_random.randi() % Layout.DESTINATIONS.size()]
		if candidate[1] == destination[1] and candidate[0] != destination[0]:
			origin = String(candidate[0])
			break
	var departure := {
		"id": _next_id, "track": track, "time": ceilf(arrive_at + dwell), "delay": 0.0,
		"destination": destination[0], "kind": destination[1], "origin": origin,
		"cars": 3 if (intercity and _random.randf() < 0.8) or (not intercity and _random.randf() < 0.4) else 2,
		"cancelled": _random.randf() < CANCEL_CHANCE,
		"dwell": dwell,
		"state": "gepland", "train": null, "announced": false, "cancel_announced": false,
		"whistled": false, "closing": false, "conductor": null,
	}
	if _random.randf() < DELAY_CHANCE:
		departure.delay = float(_random.randi_range(DELAY_MINUTES.x, DELAY_MINUTES.y))
	_next_id += 1
	_departures.append(departure)
	_departures.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.time) < float(second.time))
	_track_departure[track] = departure
	return departure


## The station as you walk in: about half the tracks have a train standing.
func _plan_start() -> void:
	for track in range(1, Layout.TRACK_COUNT + 1):
		if _random.randf() < 0.45:
			var departure := _plan(track, _minutes)
			departure.time = ceilf(_minutes + _random.randf_range(0.8, 2.5))
			departure.cancelled = false
			var train := _make_train(departure)
			train.stand()
			departure.state = "staat"
			_send_conductor(departure)
		else:
			# the first ones come in soon after you walk in
			_plan(track, _minutes + _random.randf_range(0.1, 2.5))


func _make_train(departure: Dictionary) -> StationTrain:
	var train := StationTrain.create(_props_library, int(departure.track), int(departure.cars))
	add_child(train)
	departure.train = train
	train.arrived.connect(_on_arrived.bind(departure))
	train.gone.connect(_on_gone.bind(departure))
	return train


func _update_tracks() -> void:
	for track in range(1, Layout.TRACK_COUNT + 1):
		var departure: Dictionary = _track_departure.get(track, {})
		if departure.is_empty():
			_plan(track, _minutes + _random.randf_range(GAP_MINUTES.x, GAP_MINUTES.y))
			continue
		var left := _seconds_left(departure)
		if departure.cancelled:
			if not departure.cancel_announced and left < 300.0:
				departure.cancel_announced = true
				if _announcement_random.randf() < DEPARTURE_ANNOUNCE_CHANCE * 2.0:
					_announce("De %s naar %s van %s rijdt vandaag niet. Excuses voor het ongemak." % [
						departure.kind, departure.destination, _clock_text(float(departure.time))])
			if left <= 0.0:
				_finish(departure)
			continue
		match String(departure.state):
			"gepland":
				if _minutes >= _departs_at(departure) - float(departure.dwell):
					_make_train(departure).come_in()
					departure.state = "binnenkomend"
					if _announcement_random.randf() < ARRIVAL_ANNOUNCE_CHANCE:
						_announce("Op spoor %d komt binnen: de %s uit %s." % [track, departure.kind, departure.origin])
			"staat":
				var train: StationTrain = departure.train
				if not departure.announced and left < ANNOUNCE_SECONDS:
					departure.announced = true
					var line := "Spoor %d: de %s naar %s, vertrekt om %s." % [track, departure.kind, departure.destination, _clock_text(_departs_at(departure))]
					if float(departure.delay) > 0.0:
						line += " Deze trein heeft ongeveer %d minuten vertraging." % int(departure.delay)
					if _announcement_random.randf() < DEPARTURE_ANNOUNCE_CHANCE:
						_announce(line)
				if not departure.whistled and left < WHISTLE_SECONDS:
					departure.whistled = true
					var conductor: StationPerson = departure.conductor if is_instance_valid(departure.conductor) else null
					if conductor and conductor.position.distance_to(train.front_door_spot()) < 2.0:
						conductor.blow_whistle()
					else:
						StationAudio.play_at(self, "conducteur_fluit", train.front_door_spot() + Vector3.UP * 1.6, -3.0)
				if not departure.closing and left < CLOSE_SECONDS:
					departure.closing = true
					StationAudio.play_at(self, "trein_deuren_dicht", train.position + Vector3(0.0, 1.5, train.nose_z + train.length() * 0.5), -3.0)
					train.close_doors()
					var conductor: StationPerson = departure.conductor if is_instance_valid(departure.conductor) else null
					if conductor:
						var spot := train.front_door_spot()
						var aboard: Array[Dictionary] = [{"type": "board", "spot": spot, "inside": train.inside_of(spot)}, {"type": "leave"}]
						conductor.replace_steps(aboard)
				if departure.closing and left <= 0.0 and train.doors_shut():
					train.leave()
					departure.state = "vertrekkend"
					if _random.randf() < 0.3:
						StationAudio.play_at(self, "trein_hoorn", train.position + Vector3(0.0, 2.0, train.nose_z), -10.0)


func _on_arrived(departure: Dictionary) -> void:
	departure.state = "staat"
	var train: StationTrain = departure.train
	train.open_doors()
	var busy := _busy_share()
	var count := roundi(ALIGHTING_AT_FULL * busy * _random.randf_range(0.5, 1.2))
	# within the cap of the crowd (but one gets off a train when it is busy)
	count = clampi(count, 0, maxi(_traveller_cap() - _travellers(), 1 if busy > 0.3 else 0))
	came_by_train += count
	var spots := train.door_spots()
	for index in count:
		var spot: Vector3 = spots[_random.randi() % spots.size()] + Vector3(0.0, 0.0, _random.randf_range(-0.3, 0.3))
		var person := _spawn(_pick_role(), train.inside_of(spot))
		person.position.z += _random.randf_range(-0.3, 0.3)
		var out: Array[Dictionary] = [{"type": "board", "spot": train.inside_of(spot), "inside": spot}]
		out.append_array(_off_the_platform(person, spot, int(departure.track)))
		person.steps = out
	# a conductor gets out and goes off duty; another comes for the way back
	if _random.randf() < 0.5:
		var spot := train.front_door_spot()
		var off_duty := _spawn("conducteur", train.inside_of(spot))
		var steps: Array[Dictionary] = [{"type": "board", "spot": train.inside_of(spot), "inside": spot}]
		steps.append_array(_route(off_duty, spot, _staff_door()))
		steps.append({"type": "leave"})
		off_duty.steps = steps
	_send_conductor(departure)


func _send_conductor(departure: Dictionary) -> void:
	if _seconds_left(departure) < 75.0:
		return
	var train: StationTrain = departure.train
	var conductor := _spawn("conducteur", _staff_door())
	var steps := _route(conductor, _staff_door(), train.front_door_spot())
	steps.append({"type": "stand", "face": Vector3(0.0, 0.0, 1.0)})
	conductor.steps = steps
	departure.conductor = conductor


func _on_gone(departure: Dictionary) -> void:
	_finish(departure)


func _finish(departure: Dictionary) -> void:
	departure.state = "vertrokken"
	_departures.erase(departure)
	if _track_departure.get(int(departure.track), {}) == departure:
		_track_departure.erase(int(departure.track))
	var train: StationTrain = departure.train
	if train and is_instance_valid(train):
		train.queue_free()
	departure.train = null


func _clock_text(at_minutes: float) -> String:
	var whole := int(floorf(fposmod(at_minutes, 24.0 * 60.0)))
	return "%02d:%02d" % [whole / 60, whole % 60]


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	if not _setup:
		return
	_minutes += delta / 60.0
	_update_tracks()
	_update_clock()
	_board_clock -= delta
	if _board_clock <= 0.0:
		_board_clock = 1.0
		_update_boards()
	_spawn_clock -= delta
	if _spawn_clock <= 0.0:
		var travellers := _travellers()
		var wanted := _target_travellers()
		if travellers < wanted * 0.6:
			_spawn_clock = _random.randf_range(CATCH_UP_SECONDS.x, CATCH_UP_SECONDS.y)
		else:
			_spawn_clock = _random.randf_range(DOOR_ARRIVAL_SECONDS.x, DOOR_ARRIVAL_SECONDS.y) / maxf(_busy_share(), 0.2)
		if travellers < _traveller_cap():
			_traveller_comes_in()
	_keep_staff()
	_watch_the_gates()
	_update_chase(delta)
	_notice_clock -= delta
	if _notice_clock <= 0.0:
		_notice_clock = _announcement_random.randf_range(NOTICE_SECONDS.x, NOTICE_SECONDS.y)
		_announce(NOTICES[_pick_notice()])
	var announcing := _announcer != null and _announcer.is_speaking()
	if not announcing:
		_announcement_pause -= delta
	if not announcing and _announcement_pause <= 0.0 and not _announcements.is_empty():
		var next: Dictionary = _announcements.pop_front()
		if (_minutes - float(next.queued_at)) * 60.0 <= ANNOUNCEMENT_STALE_SECONDS:
			_speak(String(next.text))


func _update_clock() -> void:
	if _hands.is_empty():
		return
	var seconds := fposmod(_minutes * 60.0, 60.0)
	var minute := fposmod(_minutes, 60.0)
	var hours := fposmod(_minutes / 60.0, 12.0)
	(_hands.second as Node3D).rotation.z = -seconds / 60.0 * TAU
	(_hands.minute as Node3D).rotation.z = -minute / 60.0 * TAU
	(_hands.hour as Node3D).rotation.z = -hours / 12.0 * TAU


func _update_boards() -> void:
	var shown := _departures.filter(func(departure: Dictionary) -> bool: return departure.state != "vertrokken")
	for rows: Array in _boards:
		for row_index in rows.size():
			var row: Array = rows[row_index]
			if row_index >= shown.size():
				for label: Label3D in row:
					label.text = ""
				continue
			var departure: Dictionary = shown[row_index]
			var gap := 0.1
			_fit_text(row[0], _clock_text(float(departure.time)), BOARD_COLUMNS[1] - BOARD_COLUMNS[0] - gap)
			_fit_text(row[1], "%s  %s" % [departure.destination, "IC" if departure.kind == "Intercity" else "SPR"],
				BOARD_COLUMNS[2] - 0.25 - BOARD_COLUMNS[1] - gap)
			_fit_text(row[2], str(departure.track), 2.0 * (BOARD_COLUMNS[3] - BOARD_COLUMNS[2]) - gap)
			var remark := row[3] as Label3D
			var remark_width := BOARD_EDGE - BOARD_COLUMNS[3]
			if departure.cancelled:
				_fit_text(remark, "Rijdt niet", remark_width)
				remark.modulate = BOARD_RED
			elif float(departure.delay) > 0.0:
				_fit_text(remark, "+%d" % int(departure.delay), remark_width)
				remark.modulate = BOARD_YELLOW
			else:
				_fit_text(remark, "", remark_width)
	for track: int in _displays:
		var labels: Dictionary = _displays[track]
		var departure: Dictionary = _track_departure.get(track, {})
		if departure.is_empty():
			(labels.time as Label3D).text = ""
			(labels.destination as Label3D).text = ""
			continue
		var when := _clock_text(float(departure.time))
		var display_width := DISPLAY_EDGE - DISPLAY_TEXT_LEFT
		if departure.cancelled:
			_fit_text(labels.time, "%s  Rijdt niet" % when, display_width)
		elif float(departure.delay) > 0.0:
			_fit_text(labels.time, "%s +%d  %s" % [when, int(departure.delay), departure.kind], display_width)
		else:
			_fit_text(labels.time, "%s  %s" % [when, departure.kind], display_width)
		_fit_text(labels.destination, String(departure.destination), display_width)


# ------------------------------------------------------------------ announcements

func _announce(text: String) -> void:
	if _announcements.size() < 2:
		_announcements.append({"text": text, "queued_at": _minutes})


## A random notice, another one than the last.
func _pick_notice() -> int:
	var notice_index := _announcement_random.randi() % NOTICES.size()
	if notice_index == _last_notice:
		notice_index = (notice_index + 1 + _announcement_random.randi() % (NOTICES.size() - 1)) % NOTICES.size()
	_last_notice = notice_index
	return notice_index


## The chime, then the voice (the babble of the game, through the loudspeakers) talking
## while its words type out at the bottom of the screen, with the cursor (Announcer).
func _speak(text: String) -> void:
	if _announcer:
		_announcer.say(text)


# ------------------------------------------------------------------ people

func _busy_share() -> float:
	var at := hour()
	for index in BUSY_BY_HOUR.size() - 1:
		var from: Array = BUSY_BY_HOUR[index]
		var to: Array = BUSY_BY_HOUR[index + 1]
		if at >= float(from[0]) and at <= float(to[0]):
			return lerpf(float(from[1]), float(to[1]), (at - float(from[0])) / maxf(float(to[0]) - float(from[0]), 0.01))
	return 0.5


func _target_travellers() -> int:
	return roundi(TRAVELLERS_AT_FULL * _busy_share())


## The most travellers there may be in the station now (both kinds of coming in stop there).
func _traveller_cap() -> int:
	return ceili(_target_travellers() * TRAVELLER_CAP_SHARE)


func _travellers() -> int:
	var count := 0
	for person in _walkers:
		if not person.is_staff():
			count += 1
	return count


func _pick_role() -> String:
	var mix: Dictionary = WHO_BY_HOUR[0][1]
	for entry: Array in WHO_BY_HOUR:
		if hour() >= float(entry[0]):
			mix = entry[1]
	var roll := _random.randf()
	for role: String in mix:
		roll -= float(mix[role])
		if roll <= 0.0:
			return role
	return "reiziger"


func _spawn(role: String, at: Vector3) -> StationPerson:
	var person := StationPerson.create(role, _random.randi(), self)
	add_child(person)
	person.position = at
	_walkers.append(person)
	return person


## How many got into a train and how many went out through the doors, and how many came
## in at the doors and off the trains (for the checks).
var boarded := 0
var went_out := 0
var came_in_at_doors := 0
var came_by_train := 0


func person_left(person: StationPerson) -> void:
	if person.position.y < -0.2:
		boarded += 1
	else:
		went_out += 1
	_walkers.erase(person)
	_patrol_leaders.erase(person)


func _door_spot(index: int) -> Vector3:
	var marker := get_node_or_null("Deur%d" % (index + 1)) as Node3D
	var at := marker.position if marker else Vector3(Layout.ENTRANCE_X[index], 0.0, Layout.HALL_FRONT + 1.0)
	return Vector3(at.x + _random.randf_range(-1.4, 1.4), 0.0, Layout.HALL_FRONT + 0.4)


func _staff_door() -> Vector3:
	var marker := get_node_or_null("Dienstdeur") as Node3D
	return marker.position if marker else Vector3(Layout.HALL_LEFT + 0.8, 0.0, -8.0)


## Someone walks in at one of the doors: most to a train, some to the shops or a look at the
## boards first.
func _traveller_comes_in() -> void:
	var start := _door_spot(_random.randi() % Layout.ENTRANCE_X.size())
	var person := _spawn(_pick_role(), start)
	came_in_at_doors += 1
	var steps: Array[Dictionary] = [{"type": "walk", "to": start + Vector3(0.0, 0.0, 1.6)}]
	var here := start + Vector3(0.0, 0.0, 1.6)
	# off the tram outside: check out at the post by the door
	if _random.randf() < 0.2:
		var post := _nearest_post(here, -1)
		if post != Vector3.INF and post.distance_to(here) < 6.0:
			var tap_at := post + Vector3(0.0, 0.0, -0.55)
			steps.append_array(_route(person, here, tap_at))
			steps.append({"type": "tap", "at": tap_at, "face": Vector3(0.0, 0.0, 1.0), "sound": "ov_uitchecken"})
			here = tap_at
	var roll := _random.randf()
	if roll < 0.15 and not _shop_fronts.is_empty():
		var shop := _shop_fronts[_random.randi() % _shop_fronts.size()]
		steps.append_array(_route(person, here, shop.position))
		steps.append({"type": "wait", "seconds": _random.randf_range(4.0, 12.0), "face": shop.transform.basis.z})
		here = shop.position
	elif roll < 0.25:
		var at := Vector3([-24.0, 0.0, 24.0][_random.randi() % 3] + _random.randf_range(-2.0, 2.0), 0.0, -11.0 - _random.randf_range(0.0, 2.0))
		steps.append_array(_route(person, here, at))
		steps.append({"type": "wait", "seconds": _random.randf_range(5.0, 15.0), "face": Vector3(0.0, 0.0, 1.0)})
		here = at
	if _random.randf() < 0.85:
		var departure := _pick_departure(1.4, 12.0)
		if not departure.is_empty():
			steps.append_array(_to_train(person, here, departure))
			person.steps = steps
			return
	# only the shops, and out again
	if not _shop_fronts.is_empty():
		var shop := _shop_fronts[_random.randi() % _shop_fronts.size()]
		steps.append_array(_route(person, here, shop.position))
		steps.append({"type": "wait", "seconds": _random.randf_range(6.0, 16.0), "face": shop.transform.basis.z})
		here = shop.position
	steps.append_array(_out_of_the_station(person, here))
	person.steps = steps


## A departure that leaves between `soonest` and `latest` minutes from now (sooner ones more
## likely), or {}.
func _pick_departure(soonest: float, latest: float, except_id := -1) -> Dictionary:
	var choices := _departures.filter(func(departure: Dictionary) -> bool:
		var left := _departs_at(departure) - _minutes
		return not departure.cancelled and left >= soonest and left <= latest and int(departure.id) != except_id)
	if choices.is_empty():
		return {}
	choices.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return _departs_at(first) < _departs_at(second))
	var index := mini(int(floorf(pow(_random.randf(), 1.6) * choices.size())), choices.size() - 1)
	return choices[index]


## From `from` to a spot on the platform of the train of `departure`, waiting there.
func _to_train(person: StationPerson, from: Vector3, departure: Dictionary) -> Array[Dictionary]:
	person.departure = departure
	var track := int(departure.track)
	var side := float(Layout.platform_side(track))
	var spot := Vector3(Layout.platform_edge_x(track) + side * _random.randf_range(1.0, 2.4), 0.0,
			_random.randf_range(5.0, Layout.STOP_NOSE_Z + int(departure.cars) * 13.5 - 3.0))
	var steps := _route(person, from, spot)
	steps.append({"type": "wait_train", "face": Vector3(-side, 0.0, 0.0)})
	return steps


## Off a platform after getting out of a train: into the hall, now and then a shop, out.
func _off_the_platform(person: StationPerson, from: Vector3, track: int) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var along := Vector3(Layout.platform_walk_x(track) + _random.randf_range(-0.5, 0.5), 0.0, from.z)
	steps.append({"type": "walk", "to": along})
	var here := along
	if _random.randf() < 0.12:
		var departure := _pick_departure(2.0, 10.0)
		if not departure.is_empty():
			steps.append_array(_to_train(person, here, departure))
			return steps
	if _random.randf() < 0.15 and not _shop_fronts.is_empty():
		var shop := _shop_fronts[_random.randi() % _shop_fronts.size()]
		steps.append_array(_route(person, here, shop.position))
		steps.append({"type": "wait", "seconds": _random.randf_range(4.0, 10.0), "face": shop.transform.basis.z})
		here = shop.position
	elif _random.randf() < LINGER_CHANCE:
		# stays a while: a look at a departure board in the hall
		var at := Vector3([-24.0, 0.0, 24.0][_random.randi() % 3] + _random.randf_range(-2.0, 2.0), 0.0, -11.0 - _random.randf_range(0.0, 2.0))
		steps.append_array(_route(person, here, at))
		steps.append({"type": "wait", "seconds": _random.randf_range(6.0, 18.0), "face": Vector3(0.0, 0.0, 1.0)})
		here = at
	steps.append_array(_out_of_the_station(person, here))
	return steps


func _out_of_the_station(person: StationPerson, from: Vector3) -> Array[Dictionary]:
	var door := _door_spot(_random.randi() % Layout.ENTRANCE_X.size())
	var steps := _route(person, from, door + Vector3(0.0, 0.0, 1.2))
	steps.append({"type": "walk", "to": door})
	steps.append({"type": "leave"})
	return steps


## Someone waiting on a platform (StationPerson "wait_train"): in when the doors are open,
## or on when the train has gone without them.
func waiting_check(person: StationPerson) -> void:
	var departure := person.departure
	var now := Time.get_ticks_msec() / 1000.0
	if not person.has_meta("waiting_since"):
		person.set_meta("waiting_since", now)
	if now - float(person.get_meta("waiting_since")) > WAIT_TRAIN_LIMIT:
		person.remove_meta("waiting_since")
		_missed(person)
		return
	if departure.is_empty() or departure.state == "vertrokken" or (departure.cancelled and _seconds_left(departure) <= 0.0):
		_missed(person)
		return
	if departure.state != "staat" or departure.closing:
		return
	var train: StationTrain = departure.train
	if train == null or not train.doors_open():
		return
	var nearest := Vector3.INF
	for spot in train.door_spots():
		if nearest == Vector3.INF or absf(spot.z - person.position.z) < absf(nearest.z - person.position.z):
			nearest = spot
	# spread over the width of the door (not all to one point)
	nearest.z += _random.randf_range(-0.4, 0.4)
	person.remove_meta("waiting_since")
	var aboard: Array[Dictionary] = [{"type": "board", "spot": nearest, "inside": train.inside_of(nearest)}, {"type": "leave"}]
	person.replace_steps(aboard)


func _missed(person: StationPerson) -> void:
	person.remove_meta("waiting_since")
	var old_id := int(person.departure.get("id", -1))
	person.departure = {}
	if _random.randf() < 0.6:
		var departure := _pick_departure(1.5, 14.0, old_id)
		if not departure.is_empty():
			person.replace_steps(_to_train(person, person.position, departure))
			return
	person.replace_steps(_out_of_the_station(person, person.position))


# ------------------------------------------------------------------ fare dodging

## Whether the player crossed the gate line without a check-in or check-out (see
## FARE_CHECK_CHANCE); maybe a conductor saw it. On the platforms: maybe a check
## (_inspect_the_player).
func _watch_the_gates() -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var at := to_local(_player.global_position)
	var margin := Layout.GATE_LENGTH * 0.5 + 0.3
	var side := -1 if at.z < Layout.GATE_Z - margin else (1 if at.z > Layout.GATE_Z + margin else 0)
	if side == 0:
		return
	var crossed := _player_side != 0 and side != _player_side
	_player_side = side
	if not crossed:
		if side == 1 and _chaser == null and not _fined_on_the_platforms:
			_inspect_the_player(at)
		return
	if side == -1:
		_fined_on_the_platforms = false
	if _chaser != null:
		return
	var passed := Time.get_ticks_msec() / 1000.0 < float(_player.get_meta(StationGates.PASS_META, 0.0))
	if passed:
		_player.remove_meta(StationGates.PASS_META)   # one check-in, one way through
		return
	var chance := fare_check_chance_override if fare_check_chance_override >= 0.0 \
		else lerpf(FARE_CHECK_CHANCE.x, FARE_CHECK_CHANCE.y, _busy_share())
	if _fare_random.randf() < chance:
		# out into the hall still checked in: not checked out; else (either way) zwartrijden
		_start_chase(at, "uitchecken" if side == -1 and OvCard.is_checked_in(_player) else "zwartrijden")


## A conductor on the platforms near the player (INSPECTION_REACH, not one boarding or
## leaving) asks for their card, once, with INSPECTION_CHANCE: without a check-in he is
## after them (zwartrijden).
func _inspect_the_player(at: Vector3) -> void:
	for walker in _walkers:
		if not is_instance_valid(walker):
			continue
		var person: StationPerson = walker
		if person.role != "conducteur" or person.position.y < -0.2 or person.has_meta(INSPECTED_META):
			continue
		if person.position.z < Layout.GATE_Z or person.position.distance_to(at) > INSPECTION_REACH:
			continue
		var step := person.current_step()
		if not step.is_empty() and String(step.type) in ["board", "leave"]:
			continue
		person.set_meta(INSPECTED_META, true)
		var chance := inspection_chance_override if inspection_chance_override >= 0.0 else INSPECTION_CHANCE
		if _fare_random.randf() >= chance:
			continue
		inspections += 1
		if not OvCard.is_checked_in(_player):
			_start_chase(at, "zwartrijden", person)
		return


## Why the conductor after the player is after them: "zwartrijden" or "uitchecken"
## (Conversations: what he says when caught, "betrapt" / "betrapt_uitchecken").
func chase_reason() -> String:
	return _chase_reason


## A conductor sets off after the player (at `at`, in the space of the station) for `reason`
## ("zwartrijden", "uitchecken"): `who`, else the nearest one about (not one getting into a
## train), else one from the gates they jumped.
func _start_chase(at: Vector3, reason := "zwartrijden", who: StationPerson = null) -> void:
	_chase_reason = reason
	var chaser: StationPerson = who
	var nearest := CONDUCTOR_NOTICE_RANGE
	for walker in (_walkers if who == null else [] as Array[StationPerson]):
		if not is_instance_valid(walker):
			continue
		var person: StationPerson = walker
		if person.role != "conducteur" or person.position.y < -0.2:
			continue
		var step := person.current_step()
		if not step.is_empty() and String(step.type) in ["board", "leave"]:
			continue
		var distance := person.position.distance_to(at)
		if distance < nearest:
			nearest = distance
			chaser = person
	if chaser == null:
		var platform := _area(at)
		var span := Layout.platform_span(Layout.platforms()[maxi(platform, 0)])
		var beside := span.y - 0.6 if at.x < (span.x + span.y) * 0.5 else span.x + 0.6
		chaser = _spawn("conducteur", Vector3(beside, 0.0, Layout.GATE_Z + 1.6))
	# taken off the train he was waiting at (it leaves without him: the whistle sounds anyway)
	for departure in _departures:
		if is_instance_valid(departure.conductor) and departure.conductor == chaser:
			departure.conductor = null
	_chaser = chaser
	chaser.set_meta(INSPECTED_META, true)   # after the chase no check of his own straight away
	_pursuit = Pursuit.new(chaser, CATCH_REACH)
	_pursuit.give_up_distance = GIVE_UP_DISTANCE
	_pursuit.give_up_seconds = GIVE_UP_SECONDS
	_pursuit.longest = CHASE_SECONDS
	chases_started += 1
	var to_player: Array[Dictionary] = []
	chaser.replace_steps(to_player)
	_begin_chasing(chaser, CHASE_SPEED)
	DriverShout.shout(chaser, "conducteur", reason, 2.1)


func _update_chase(delta: float) -> void:
	if _chaser == null:
		return
	if not is_instance_valid(_chaser) or _player == null or not _player.is_inside_tree():
		_end_chase()
		return
	match _pursuit.update(delta, _player.global_position):
		Pursuit.CAUGHT:
			_fine_the_player()
			return
		Pursuit.GAVE_UP:
			_end_chase()
			return
	_steer_chase(_chaser, delta)


## `chaser` sets off after the player at `chase_speed` (m/s): the first way at once.
func _begin_chasing(chaser: StationPerson, chase_speed: float) -> void:
	chaser.follow = null
	chaser.set_meta(CHASE_PLAN_META, "")
	chaser.set_meta(CHASE_SPEED_META, chase_speed)
	chaser.set_meta(CHASE_CLOCK_META, CHASE_REPLAN)
	_plan_chase_of(chaser)


## Every CHASE_REPLAN seconds `chaser` looks again which way to go after the player.
func _steer_chase(chaser: StationPerson, delta: float) -> void:
	var clock := float(chaser.get_meta(CHASE_CLOCK_META, 0.0)) - delta
	if clock <= 0.0:
		clock = CHASE_REPLAN
		_plan_chase_of(chaser)
	chaser.set_meta(CHASE_CLOCK_META, clock)


## Whether `person` is after the player (the conductor, or a BOA putting them out).
static func _is_chasing_player(person: StationPerson) -> bool:
	return person.has_meta(CHASE_PLAN_META)


## `person` no longer after the player.
static func _stop_chasing(person: StationPerson) -> void:
	for meta_name in [CHASE_PLAN_META, CHASE_CLOCK_META, CHASE_SPEED_META]:
		person.remove_meta(meta_name)


## The floor at `at` (in the space of the station): the hall and the platforms at 0, the
## tracks PLATFORM_DROP lower (from the head of the platforms to the back wall).
func floor_height(at: Vector3) -> float:
	if at.z < 0.0 or at.z > Layout.BACK_WALL:
		return 0.0
	var column := clampi(floori((at.x - Layout.HALL_LEFT) / Layout.CELL), 0, Layout.COLUMN_COUNT - 1)
	return -Layout.PLATFORM_DROP if Layout.column_kind(column) == "T" else 0.0


## The track under `at` (1..), or 0 when it is not over a track.
func _track_at(at: Vector3) -> int:
	if at.z < 0.0 or at.z > Layout.BACK_WALL:
		return 0
	for track in range(1, Layout.TRACK_COUNT + 1):
		if absf(at.x - Layout.track_x(track)) <= Layout.CELL * 0.5:
			return track
	return 0


## Whether `person` at a platform edge goes over it by accident (once per edge it meets):
## rarely, more often for a conductor in a hurry; never onto a track with a train on it.
func stumbles(person: StationPerson, chasing: bool) -> bool:
	if person.is_staff() and not chasing:
		return false
	# one chance in a while, not at every frame along an edge
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(person.get_meta("stumble_chance_at", -100.0)) < 5.0:
		return false
	person.set_meta("stumble_chance_at", now)
	var ahead := person.position + person.transform.basis.z * 0.6
	var track := _track_at(ahead)
	if track == 0:
		return false
	var departure: Dictionary = _track_departure.get(track, {})
	if not departure.is_empty() and departure.get("train") != null:
		return false
	return _fare_random.randf() < (CHASE_STUMBLE_CHANCE if chasing else STUMBLE_CHANCE)


## Someone landed on the rails (StationPerson fell): a cry, a moment, up the edge it fell
## from, and on with what it was doing (a conductor with the chase).
func person_fell(person: StationPerson) -> void:
	falls += 1
	DriverShout.shout(person, "", "gevallen", 2.1)
	var track := _track_at(person.position)
	var climb_to := _platform_spot_above(person.position, track)
	var steps: Array[Dictionary] = [
		{"type": "wait", "seconds": 0.9},
		{"type": "walk", "to": Vector3(climb_to.x - signf(climb_to.x - person.position.x) * 0.45, person.position.y, person.position.z)},
		{"type": "climb", "to": climb_to},
		{"type": "climbed"},
	]
	person.replace_steps(steps)


## Back on the platform after a climb (the step "climbed" asks): on with the day.
func person_climbed(person: StationPerson) -> void:
	climbs += 1
	if _is_chasing_player(person):
		person.set_meta(CHASE_PLAN_META, "")
		return
	_send_on(person)


## The spot on the platform of `track`, just past its edge, level with `at`.
func _platform_spot_above(at: Vector3, track: int) -> Vector3:
	var on_track := maxi(track, 1)
	var side := float(Layout.platform_side(on_track))
	return Vector3(Layout.platform_edge_x(on_track) + side * 0.5, 0.0, clampf(at.z, 1.0, Layout.BACK_WALL - 1.0))


## On with what `person` was doing, from where it is: to its train, or out of the station.
func _send_on(person: StationPerson) -> void:
	if person.is_staff():
		var back := _route(person, person.position, _staff_door())
		back.append({"type": "leave"})
		person.replace_steps(back)
		return
	var departure := person.departure
	if not departure.is_empty() and departure.state != "vertrokken" and not departure.cancelled and _seconds_left(departure) > 40.0:
		person.replace_steps(_to_train(person, person.position, departure))
	else:
		person.departure = {}
		person.replace_steps(_out_of_the_station(person, person.position))


## `person` has made no headway for a while (StationPerson.STUCK_SECONDS, `times` in a
## row): a step aside and another way (another lane, or out); the third time it goes (out of
## the station: it is simply gone, which in a crowd no one notices).
func person_stuck(person: StationPerson, times: int) -> void:
	if person == _chaser and times >= 3:
		_end_chase()
		return
	if _is_chasing_player(person):
		# one putting the player out does not give up: a step aside and another way
		if times >= 3:
			var aside_of_chaser := person.position + Vector3(_random.randf_range(-0.5, 0.5), 0.0, _random.randf_range(-0.5, 0.5))
			if absf(floor_height(aside_of_chaser) - person.position.y) < 0.1 and not _inside_obstacle(Vector2(aside_of_chaser.x, aside_of_chaser.z)):
				person.position = aside_of_chaser
		person.set_meta(CHASE_PLAN_META, "")
		return
	unstuck += 1
	if person.position.y < -0.5:
		var track := _track_at(person.position)
		var steps: Array[Dictionary] = [{"type": "climb", "to": _platform_spot_above(person.position, track)}, {"type": "climbed"}]
		person.replace_steps(steps)
		return
	if times >= 3:
		var gone: Array[Dictionary] = [{"type": "leave"}]
		person.replace_steps(gone)
		return
	# a step aside, where the floor is level
	var aside := person.position + Vector3(_random.randf_range(-0.5, 0.5), 0.0, _random.randf_range(-0.5, 0.5))
	if absf(floor_height(aside) - person.position.y) < 0.1 and not _inside_obstacle(Vector2(aside.x, aside.z)):
		person.position = aside
	if times >= 2:
		person.departure = {}
	_send_on(person)


## Which way `chaser` (the conductor, or a BOA putting the player out) goes after the player
## now (see CHASE_REPLAN).
func _plan_chase_of(chaser: StationPerson) -> void:
	if chaser == null or not is_instance_valid(chaser) or _player == null:
		return
	var chase_speed := float(chaser.get_meta(CHASE_SPEED_META, CHASE_SPEED))
	var chase_plan := String(chaser.get_meta(CHASE_PLAN_META, ""))
	var speaker_kind := chaser.role
	var step := chaser.current_step()
	var kind := String(step.get("type", ""))
	if chaser.position.y < -0.3 or kind in ["climb", "climbed"] or chaser._falling:
		return   # down on the rails himself: first back up
	var at := to_local(_player.global_position)
	var chaser_area := _area(chaser.position)
	if at.y < -0.6 and _track_at(at) > 0:
		# the player down on the rails: to the edge above them, and shout
		var spot := _platform_spot_above(at, _track_at(at))
		var plan := "spoor %d %d" % [roundi(spot.x), roundi(spot.z / 3.0)]
		if plan == chase_plan:
			return
		var shout := not chase_plan.begins_with("spoor")
		chaser.set_meta(CHASE_PLAN_META, plan)
		var steps: Array[Dictionary] = []
		if _area(spot) == chaser_area:
			steps.append({"type": "walk", "to": spot, "speed": chase_speed})
		else:
			steps = _route(chaser, chaser.position, spot)
			for route_step in steps:
				if String(route_step.type) == "walk":
					route_step["speed"] = chase_speed
		steps.append({"type": "stand", "face": Vector3(at.x - spot.x, 0.0, 0.0)})
		chaser.replace_steps(steps)
		if shout:
			DriverShout.shout(chaser, speaker_kind, "spoor", 2.1)
		return
	var player_area := _area(at)
	if player_area == chaser_area:
		if chase_plan != "zelfde" or kind != "chase":
			chaser.set_meta(CHASE_PLAN_META, "zelfde")
			var chase: Array[Dictionary] = [{"type": "chase", "speed": chase_speed}]
			chaser.replace_steps(chase)
		return
	var plan := "route %d %d" % [chaser_area, player_area]
	if plan == chase_plan:
		return
	chaser.set_meta(CHASE_PLAN_META, plan)
	var route := _route(chaser, chaser.position, at)
	for route_step in route:
		if String(route_step.type) == "walk":
			route_step["speed"] = chase_speed
	route.append({"type": "chase", "speed": chase_speed})
	chaser.replace_steps(route)


## The player talks to `conductor` (Conversations): is he the one chasing them?
func is_chasing(conductor: Node) -> bool:
	return _chaser != null and _chaser == conductor


## Caught by talking to the conductor chasing them (Conversations): the fine, as when he
## catches up; returns the fine (FINE_EUROS).
func fine_the_player() -> float:
	if _chaser != null and _player != null:
		_fine_the_player()
	return FINE_EUROS


## Caught: FINE_EUROS off the player's money (what they have, when it is less).
func _fine_the_player() -> void:
	var money := float(_player.get("money")) if _player.get("money") != null else 0.0
	var paid := minf(FINE_EUROS, money)
	if _player.has_method("add_money"):
		_player.call("add_money", -paid)
	fines += 1
	_fined_on_the_platforms = _player_side == 1
	DriverShout.shout(_chaser, "conducteur", "beboeten", 2.1)
	var line := "Beboet voor zwartrijden: € %d" % int(FINE_EUROS)
	if _chase_reason == "uitchecken":
		# he checks them out himself: no boarding fare on top of the fine
		OvCard.check_out(_player)
		_player.set_meta(OvCard.CHECKED_IN_META, false)
		line = "Beboet, niet uitgecheckt: € %d" % int(FINE_EUROS)
	if paid < FINE_EUROS:
		line += " (je had maar %s)" % MoneyText.euros(paid)
	say(to_local(_player.global_position) + Vector3.UP * 2.2, line, FINE_COLOUR)
	var conductor := _chaser
	_chaser_goes_back()
	# who cannot pay the fine is put out of the station (Interiors: uitzetten.json): by the
	# conductor, who is with them already
	if paid < FINE_EUROS:
		Interiors.note_offence(get_tree(), "boete_onbetaald", conductor)


## The chase is over (the player got away): the conductor goes back.
func _end_chase() -> void:
	if _chaser != null:
		chases_given_up += 1
	_chaser_goes_back()


func _chaser_goes_back() -> void:
	if _chaser != null and is_instance_valid(_chaser) and _chaser.is_inside_tree():
		var back := _route(_chaser, _chaser.position, _staff_door())
		back.append({"type": "leave"})
		_chaser.replace_steps(back)
	if _chaser != null and is_instance_valid(_chaser):
		_stop_chasing(_chaser)
	_chaser = null
	_pursuit = null
	_chase_reason = "zwartrijden"


# ------------------------------------------------------------------ putting the player out

## Who warns the player in the station (Interiors.offence: a BOA): the nearest of `role`
## about on the floor, not one after the player already; null when none is near.
func warner_for(role: String, player: Node3D) -> Node3D:
	var at := to_local(player.global_position)
	var nearest: StationPerson = null
	var nearest_distance := WARN_REACH
	for walker in _walkers:
		if not is_instance_valid(walker):
			continue
		var person: StationPerson = walker
		if person.role != role or person == _chaser or person.position.y < -0.2 or _is_chasing_player(person):
			continue
		var distance := person.position.distance_to(at)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = person
	return nearest


## Who comes to put the player out of the station (Eviction: uitzetten.json "wie", a BOA):
## the nearest of that role about on the floor (not one leaving), else one from the staff
## door. Not the conductor after a fare dodger: he has his own chase.
func evictor_for(role: String, player: Node3D) -> Node3D:
	var at := to_local(player.global_position)
	var nearest: StationPerson = null
	var nearest_distance := INF
	for walker in _walkers:
		if not is_instance_valid(walker):
			continue
		var person: StationPerson = walker
		if person.role != role or person == _chaser or person.position.y < -0.2 or person._falling:
			continue
		var step := person.current_step()
		if not step.is_empty() and String(step.type) in ["board", "leave"]:
			continue
		var distance := person.position.distance_to(at)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = person
	if nearest == null:
		nearest = _spawn(role, _staff_door())
	# off its round (and its partner, when it was following one: walk_evictor sets it off)
	nearest.follow = null
	var none_yet: Array[Dictionary] = []
	nearest.replace_steps(none_yet)
	return nearest


## After the player along the routes of the station (as the conductor: _plan_chase_of);
## `person` walks by itself (StationPerson), at `speed`.
func walk_evictor(person: Node3D, _target: Vector3, speed: float, delta: float) -> float:
	var walker := person as StationPerson
	if walker == null:
		return 0.0
	if not _is_chasing_player(walker):
		_begin_chasing(walker, speed)
	walker.set_meta(CHASE_SPEED_META, speed)
	_steer_chase(walker, delta)
	return 0.0


## `person` has the player: stands where they are.
func evictor_stops(person: Node3D) -> void:
	var walker := person as StationPerson
	if walker == null:
		return
	_stop_chasing(walker)
	var stand: Array[Dictionary] = [{"type": "wait", "seconds": 60.0}]
	walker.replace_steps(stand)


## Over: back through the staff door.
func evictor_done(person: Node3D) -> void:
	var walker := person as StationPerson
	if walker == null or not walker.is_inside_tree():
		return
	_stop_chasing(walker)
	var back := _route(walker, walker.position, _staff_door())
	back.append({"type": "leave"})
	walker.replace_steps(back)


# ------------------------------------------------------------------ the staff

func _spawn_staff() -> void:
	for pair in 2:
		var leader := _spawn("handhaver", _staff_door() + Vector3(0.6, 0.0, pair * 1.5))
		var partner := _spawn("handhaver", _staff_door() + Vector3(1.4, 0.0, pair * 1.5))
		partner.follow = leader
		partner.follow_offset = Vector3(-0.9, 0.0, 0.0)
		_patrol_leaders.append(leader)
	_platform_patrol = null


## The enforcement officers keep walking: a new round when one is done.
func _keep_staff() -> void:
	# (not one after the player: putting them out, evictor_for)
	for leader in _patrol_leaders:
		if is_instance_valid(leader) and leader.steps.is_empty() and not _is_chasing_player(leader):
			leader.steps = _hall_round(leader)
	if _platform_patrol == null or not is_instance_valid(_platform_patrol):
		_platform_patrol = _spawn("handhaver", _staff_door())
	if _platform_patrol.steps.is_empty() and not _is_chasing_player(_platform_patrol):
		_platform_patrol.steps = _platform_round(_platform_patrol)


func _hall_round(leader: StationPerson) -> Array[Dictionary]:
	var points := [Vector3(-24.0, 0.0, -27.0), Vector3(0.0, 0.0, -10.0), Vector3(24.0, 0.0, -27.0),
		Vector3(36.0, 0.0, -9.0), Vector3(0.0, 0.0, -26.0), Vector3(-36.0, 0.0, -9.0), Vector3(-12.0, 0.0, -5.0), Vector3(12.0, 0.0, -5.0)]
	var steps: Array[Dictionary] = []
	var here := leader.position
	for index in 3:
		var to: Vector3 = points[_random.randi() % points.size()] + Vector3(_random.randf_range(-2.0, 2.0), 0.0, 0.0)
		steps.append_array(_route(leader, here, to))
		steps.append({"type": "wait", "seconds": _random.randf_range(3.0, 9.0), "face": Vector3(_random.randf_range(-1.0, 1.0), 0.0, _random.randf_range(-1.0, 1.0))})
		here = to
	return steps


func _platform_round(officer: StationPerson) -> Array[Dictionary]:
	var track := _random.randi_range(1, Layout.TRACK_COUNT)
	var head := Vector3(Layout.platform_walk_x(track), 0.0, 4.0)
	var far := Vector3(Layout.platform_walk_x(track), 0.0, _random.randf_range(30.0, 46.0))
	var steps := _route(officer, officer.position, head)
	steps.append({"type": "walk", "to": far})
	steps.append({"type": "wait", "seconds": _random.randf_range(4.0, 10.0), "face": Vector3(-Layout.platform_side(track), 0.0, 0.0)})
	steps.append({"type": "walk", "to": head})
	steps.append_array(_route(officer, head, Vector3(_random.randf_range(-30.0, 30.0), 0.0, -6.0)))
	return steps


# ------------------------------------------------------------------ filling the station

## When the player comes in to a quiet station: people already about (waiting on the
## platforms, walking in the hall).
## One traveller somewhere in the station, on its way: half waiting at a platform for a train,
## the others in the hall going to a train or out.
func _spawn_one_traveller() -> void:
	if _random.randf() < 0.5:
		var departure := _pick_departure(1.0, 12.0)
		if not departure.is_empty():
			var person := _spawn(_pick_role(), Vector3.ZERO)
			var steps := _to_train(person, Vector3.ZERO, departure)
			# straight onto the spot it would wait at
			var waiting: Dictionary = steps[-1]
			var spot := Vector3.ZERO
			for step in steps:
				if String(step.type) == "walk":
					spot = step.to
			person.position = spot
			var only_waiting: Array[Dictionary] = [waiting]
			person.steps = only_waiting
			return
	var at := _free_hall_point()
	var person := _spawn(_pick_role(), at)
	var steps: Array[Dictionary] = []
	if _random.randf() < 0.6:
		var departure := _pick_departure(1.5, 12.0)
		if not departure.is_empty():
			steps = _to_train(person, at, departure)
	if steps.is_empty():
		steps = _out_of_the_station(person, at)
	person.steps = steps


func _free_hall_point() -> Vector3:
	for attempt in 30:
		var at := Vector3(_random.randf_range(Layout.HALL_LEFT + 5.0, Layout.HALL_RIGHT - 3.0), 0.0, _random.randf_range(Layout.HALL_FRONT + 3.0, -4.0))
		if not _inside_obstacle(Vector2(at.x, at.z)):
			return at
	return Vector3(0.0, 0.0, -10.0)


func _nearest_post(near: Vector3, hall_or_platform: int) -> Vector3:
	var best := Vector3.INF
	for post in _posts:
		if hall_or_platform == -1 and post.z > Layout.GATE_Z:
			continue
		if best == Vector3.INF or post.distance_to(near) < best.distance_to(near):
			best = post
	return best


# ------------------------------------------------------------------ finding the way

## Where a spot is: -1 the hall, else the index of the platform it is on.
func _area(at: Vector3) -> int:
	if at.z < Layout.GATE_Z:
		return -1
	var platforms := Layout.platforms()
	for index in platforms.size():
		var span := Layout.platform_span(platforms[index])
		if at.x >= span.x - 0.01 and at.x <= span.y + 0.01:
			return index
	# beside a platform (getting out of a train): the platform of the nearest edge
	var best := 0
	var best_distance := INF
	for index in platforms.size():
		var span := Layout.platform_span(platforms[index])
		var distance := minf(absf(at.x - span.x), absf(at.x - span.y))
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


## The steps from `from` to `to`: round the obstacles of the hall, through the gates between
## the hall and a platform (in or out), along the platforms.
func _route(person: StationPerson, from: Vector3, to: Vector3) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var from_area := _area(from)
	var to_area := _area(to)
	if from_area == -1 and to_area == -1:
		_hall_walk(steps, from, to)
		return steps
	if from_area == to_area:
		# on one platform: near its head first across, then along
		if from.z < 6.0:
			steps.append({"type": "walk", "to": Vector3(to.x, 0.0, maxf(from.z, 3.0))})
		steps.append({"type": "walk", "to": to})
		return steps
	var here := from
	if from_area >= 0:
		# off this platform through a lane going out
		var out_lane := _gates[from_area].lane_for(-1, person) if from_area < _gates.size() else null
		if out_lane:
			steps.append({"type": "walk", "to": Vector3(here.x, 0.0, 3.0)})
			steps.append({"type": "walk", "to": out_lane.entry_point() + Vector3(_random.randf_range(-0.1, 0.1), 0.0, 0.0)})
			steps.append({"type": "gate", "lane": out_lane})
			here = out_lane.exit_point()
	if to_area >= 0:
		var in_lane := _gates[to_area].lane_for(1, person) if to_area < _gates.size() else null
		if in_lane:
			_hall_walk(steps, here, in_lane.entry_point() - Vector3(0.0, 0.0, 1.2))
			steps.append({"type": "walk", "to": in_lane.entry_point()})
			steps.append({"type": "gate", "lane": in_lane})
			steps.append({"type": "walk", "to": Vector3(to.x, 0.0, 3.0)})
			steps.append({"type": "walk", "to": to})
		return steps
	_hall_walk(steps, here, to)
	return steps


## Walking steps through the hall from `from` to `to`, round the obstacles.
func _hall_walk(steps: Array[Dictionary], from: Vector3, to: Vector3) -> void:
	var points := Detour.around(Vector2(from.x, from.z), Vector2(to.x, to.z), HALL_OBSTACLES, OBSTACLE_MARGIN, 3)
	for point in points:
		steps.append({"type": "walk", "to": Vector3(point.x, 0.0, point.y)})


func _inside_obstacle(at: Vector2) -> bool:
	return Detour.inside_any(at, HALL_OBSTACLES, OBSTACLE_MARGIN)


# ------------------------------------------------------------------ cans for the story

## Cans the story wants in the station (Story.station_cans_wanted: the first mission's last
## two, behind the gates), put there as the player comes in, in the order of MISSION_CAN_KINDS,
## each sticking out of a bin on a platform (_platform_bins): "perron_1" in the bin nearest the
## middle of the gate line, "perron_2" in the nearest bin on another platform (or, with none
## there, the nearest one at least MISSION_CANS_APART m from the first). Glowing like the cans
## in the town's bins; "[E] Blikje pakken" puts one in the pockets. One taken stays gone
## (_mission_cans_taken). True if one lies there now.
func put_mission_can() -> bool:
	var story := get_tree().get_first_node_in_group("verhaal") if is_inside_tree() else null
	var wanted := 0
	if story and story.has_method("station_cans_wanted"):
		wanted = int(story.station_cans_wanted())
	elif story and story.has_method("wants_station_can") and story.wants_station_can():
		wanted = 1
	var bins := _platform_bins()
	for index in MISSION_CAN_KINDS.size():
		var kind: String = MISSION_CAN_KINDS[index]
		if wanted <= 0:
			break
		if _mission_cans.has(kind) and is_instance_valid(_mission_cans[kind]):
			wanted -= 1
			continue
		if _mission_cans_taken.has(kind) or index >= bins.size():
			continue
		_mission_cans[kind] = _make_mission_can(kind, bins[index])
		wanted -= 1
	_tell_story_cans(_player != null)
	return not mission_cans().is_empty()


## The cans of the story lying in the station now: kind ("perron_1", "perron_2") -> its spot.
func mission_cans() -> Dictionary:
	var lying := {}
	for kind: String in _mission_cans:
		if is_instance_valid(_mission_cans[kind]):
			lying[kind] = _mission_cans[kind]
	return lying


func _make_mission_can(kind: String, at: Vector3) -> Node3D:
	var spot: Node3D = InteriorSpot.create("BlikjeOpPerron" + kind.trim_prefix("perron"), Vector3.ZERO,
			"Blikje pakken", _take_mission_can.bind(kind), CAN_REACH)
	spot.set("kind", "oppakken")   # Interactable.KIND_PICKUP
	add_child(spot)
	spot.position = at
	var can := MeshInstance3D.new()
	can.name = "Blikje"
	can.mesh = MachineModels.can_mesh()
	spot.add_child(can)
	can.position = Vector3(0.0, 1.0, 0.0)   # sticking out of the top of the bin
	can.rotation = Vector3(0.35, 1.1, 0.2)
	QuestOutline.add(can, 0.02)
	return spot


## "[E] Blikje pakken" at the can of `kind`: gone from the station (and from the story's
## marks) before it goes in the pockets: add_item signals inventory_changed, on which the
## story aims again, and this can must no longer be among the places then.
func _take_mission_can(kind := "perron_1") -> void:
	var spot: Node3D = _mission_cans.get(kind)
	if spot == null or not is_instance_valid(spot) or _player == null:
		return
	_mission_cans.erase(kind)
	_mission_cans_taken[kind] = true
	_tell_story_cans(true)
	if not bool(_player.call("add_item", "blikje")):
		_mission_cans[kind] = spot
		_mission_cans_taken.erase(kind)
		_tell_story_cans(true)
		return
	spot.queue_free()


## Tells the story where the cans it wants lie in the station (Story.set_station_cans: world
## x, z, marked on the minimap while the player is in here), or none (`inside` false: out).
func _tell_story_cans(inside: bool) -> void:
	var story := get_tree().get_first_node_in_group("verhaal") if is_inside_tree() else null
	if story == null or not story.has_method("set_station_cans"):
		return
	var spots: Array = []
	if inside:
		for kind: String in MISSION_CAN_KINDS:
			var spot: Node3D = mission_cans().get(kind)
			if spot:
				spots.append(Vector2(spot.global_position.x, spot.global_position.z))
	story.set_station_cans(spots)


## The bins for the story's cans (in the station's space), up to two: the bin on a platform
## (past the gate line) nearest the middle of the gates, then the nearest bin on another
## platform, else the nearest one at least MISSION_CANS_APART m from the first.
func _platform_bins() -> Array:
	var props := get_node_or_null("Props") as GridMap
	if props == null or props.mesh_library == null:
		return []
	var item := props.mesh_library.find_item_by_name(PLATFORM_BIN)
	if item < 0:
		return []
	var found: Array = []
	for cell in props.get_used_cells_by_item(item):
		var at := props.position + props.map_to_local(cell)
		at.y = 0.0
		if at.z > Layout.GATE_Z + 2.0:   # not in the hall, before the gates
			found.append(at)
	if found.is_empty():
		return []
	found.sort_custom(func(first: Vector3, second: Vector3) -> bool:
		return Vector2(first.x, first.z).length() < Vector2(second.x, second.z).length())
	var first: Vector3 = found[0]
	for other: Vector3 in found:
		if _platform_at(other) != _platform_at(first):
			return [first, other]
	for other: Vector3 in found:
		if Vector2(other.x - first.x, other.z - first.z).length() >= MISSION_CANS_APART:
			return [first, other]
	return [first]


## The platform (index in Layout.platforms()) under `at` (the station's space), or -1.
func _platform_at(at: Vector3) -> int:
	var column := floori((at.x - Layout.HALL_LEFT) / Layout.CELL)
	var platforms: Array = Layout.platforms()
	for index in platforms.size():
		if column >= int(platforms[index][0]) and column <= int(platforms[index][1]):
			return index
	return -1
