extends "res://scripts/world/interior.gd"
## Den Haag Centraal from the inside (scenes/binnen/centraal.tscn, built by
## tools/build/build_interiors.gd from StationLayout): an Interior with life in it.
## - Trains (StationTrain) on twelve tracks: each track has its departure (`_departures`):
##   a time, a destination and a kind (StationLayout.DESTINATIONS), two or three cars, now and
##   then a delay or a train that does not run; at random moments the train comes in through
##   the back wall, opens its doors, stands its time, the conductor whistles, the doors beep
##   shut, and it leaves the way it came. Then the next one is planned for that track.
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

const Layout = preload("res://scripts/world/station_layout.gd")
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
## People getting out of a train at the busiest hour (fewer when it is quiet).
const ALIGHTING_AT_FULL := 14
## A train stands this long at its platform (minutes), and a track is free this long between
## two trains (minutes).
const DWELL_MINUTES := Vector2(2.5, 4.5)
const GAP_MINUTES := Vector2(0.4, 2.5)
const DELAY_CHANCE := 0.15
const CANCEL_CHANCE := 0.03
## Seconds before leaving: the announcement, the whistle, the doors shutting.
const ANNOUNCE_SECONDS := 150.0
const WHISTLE_SECONDS := 17.0
const CLOSE_SECONDS := 12.0
## Rows on a departure board.
const BOARD_ROWS := 7
const BOARD_WHITE := Color("#F2F4F8")
const BOARD_YELLOW := Color("#FFD23A")
const BOARD_RED := Color("#FF5A4A")
const BOARD_BLUE := Color("#0A2A6A")
const ANNOUNCER_VOICE := "vrouw"
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
var _keepers: Array[InteriorPerson] = []
var _patrol_leaders: Array[StationPerson] = []
var _platform_patrol: StationPerson
var _props_library: MeshLibrary
var _binnen_library: MeshLibrary
var _boards: Array = []               # per board: Array of rows [time, destination, track, remark]
var _displays := {}                   # track -> {"number", "time", "destination"} Label3D
var _hands := {}                      # "hour", "minute", "second" -> Node3D
var _shop_fronts: Array[Node3D] = []
var _posts: Array[Vector3] = []
var _spawn_clock := 0.0
var _board_clock := 0.0
var _notice_clock := 90.0
var _announcements: Array[String] = []
var _announcing := false
var _subtitle_layer: CanvasLayer
var _subtitle: Label


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
	_ensure_setup()
	if _walkers.size() < _target_travellers() / 2:
		_populate()


func player_went_out() -> void:
	if _subtitle_layer:
		_subtitle_layer.visible = false


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
	StationAudio.ensure_buses()
	var furniture := get_node_or_null("Inrichting") as GridMap
	_binnen_library = furniture.mesh_library if furniture else load("res://assets/libraries/binnen.res")
	var props := get_node_or_null("Props") as GridMap
	_props_library = props.mesh_library if props and props.mesh_library else load(PROPS_LIBRARY)
	_sync_clock()
	_make_gates()
	_make_platform_edges()
	_make_shops()
	_make_machines()
	_make_posts(props)
	_make_boards()
	_make_displays()
	_make_clock()
	_make_subtitle()
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


## An invisible wall along every platform edge: no one falls onto the tracks.
func _make_platform_edges() -> void:
	var walls := StaticBody3D.new()
	walls.name = "Perronranden"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	for track in range(1, Layout.TRACK_COUNT + 1):
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.1, 2.2, Layout.BACK_WALL)
		shape.shape = box
		shape.position = Vector3(Layout.platform_edge_x(track) - Layout.platform_side(track) * 0.06, 1.1, Layout.BACK_WALL * 0.5)
		walls.add_child(shape)


func _make_shops() -> void:
	var number := 1
	while has_node("Verkoper_%d" % number):
		var keeper_marker := get_node("Verkoper_%d" % number) as Node3D
		var kind := String(keeper_marker.get_meta("kind", "kiosk"))
		var role := "snackbarhouder" if kind == "smikkels" else "verkoper"
		var keeper := InteriorPerson.create(role, 4000 + number * 17, false)
		keeper.name = "Verkoper"
		keeper.set_meta("shop_name", keeper_marker.get_meta("shop_name", ""))
		add_child(keeper)
		keeper.transform = keeper_marker.transform
		_keepers.append(keeper)
		var front := get_node_or_null("Winkel_%d" % number) as Node3D
		if front:
			_shop_fronts.append(front)
		var sign_marker := get_node_or_null("Uithangbord_%d" % number) as Node3D
		if sign_marker:
			var sign := _label(String(keeper_marker.get_meta("shop_name", "")).to_upper(), 40, 0.0045, Color.WHITE)
			sign.name = "Naam"
			sign.transform = sign_marker.transform
			add_child(sign)
		number += 1


## The OV-chipkaart machines: buy a card there.
class TicketMachine:
	extends Node3D
	var station: Node3D

	func action_text() -> String:
		var player: Node3D = station.call("player")
		if player and int((player.get("inventory") as Dictionary).get("ov_chipkaart", 0)) > 0:
			return "OV-chipkaart (heb je al)"
		return "OV-chipkaart kopen (€ 7,50)"

	func reach() -> float:
		return 1.2

	func go_through() -> void:
		var player: Node3D = station.call("player")
		if player == null:
			return
		var at := position + Vector3.UP * 1.9
		if int((player.get("inventory") as Dictionary).get("ov_chipkaart", 0)) > 0:
			station.call("say", at, "Je hebt al een OV-chipkaart", Color("#FFD23A"))
			return
		var result: String = player.call("buy", "ov_chipkaart", 7.5) if player.has_method("buy") else "geld"
		match result:
			"ok":
				StationAudio.play_at(station, "ov_inchecken", position + Vector3.UP, -6.0)
				station.call("say", at, "OV-chipkaart gekocht", Color("#3CE06A"))
			"vol":
				StationAudio.play_at(station, "ov_geweigerd", position + Vector3.UP, -6.0)
				station.call("say", at, "Je zakken zitten vol", Color("#FF5A4A"))
			_:
				StationAudio.play_at(station, "ov_geweigerd", position + Vector3.UP, -6.0)
				station.call("say", at, "Te weinig geld (€ 7,50)", Color("#FF5A4A"))


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
	extends Node3D
	var station: Node3D

	func action_text() -> String:
		var player: Node3D = station.call("player")
		return "Uitchecken" if player and player.get_meta("ov_ingecheckt", false) else "Inchecken"

	func reach() -> float:
		return 1.1

	func go_through() -> void:
		var player: Node3D = station.call("player")
		if player == null:
			return
		var at := position + Vector3.UP * 1.6
		if int((player.get("inventory") as Dictionary).get("ov_chipkaart", 0)) <= 0:
			StationAudio.play_at(station, "ov_geweigerd", position + Vector3.UP, -6.0)
			station.call("say", at, "Geen OV-chipkaart", Color("#FF5A4A"))
			return
		var checked_in: bool = player.get_meta("ov_ingecheckt", false)
		player.set_meta("ov_ingecheckt", not checked_in)
		StationAudio.play_at(station, "ov_uitchecken" if checked_in else "ov_inchecken", position + Vector3.UP, -6.0)
		station.call("say", at, "Uitgecheckt" if checked_in else "Ingecheckt", Color("#3CE06A"))


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
		for heading: Array in [["VERTREK", -2.75], ["NAAR", -1.95], ["SPOOR", 1.75]]:
			var header := _label(heading[0], 30, 0.0034, BOARD_BLUE, true)
			header.position = Vector3(heading[1], 0.69, 0.01)
			board.add_child(header)
		var rows := []
		for row_index in BOARD_ROWS:
			var y := 0.5 - row_index * 0.19
			var row := []
			for column: Array in [[-2.75, BOARD_WHITE], [-1.95, BOARD_WHITE], [1.95, BOARD_WHITE], [2.3, BOARD_YELLOW]]:
				var label := _label("", 40, 0.0034, column[1], true)
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
		var number := _label(str(track), 64, 0.006, BOARD_BLUE)
		number.position = Vector3(-0.81, 0.0, 0.01)
		marker.add_child(number)
		var time := _label("", 34, 0.0034, BOARD_WHITE, true)
		time.position = Vector3(-0.4, 0.14, 0.01)
		marker.add_child(time)
		var destination := _label("", 34, 0.0034, BOARD_WHITE, true)
		destination.position = Vector3(-0.4, -0.1, 0.01)
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


func _make_subtitle() -> void:
	_subtitle_layer = CanvasLayer.new()
	_subtitle_layer.name = "Omroeptekst"
	_subtitle_layer.layer = 4
	_subtitle_layer.visible = false
	add_child(_subtitle_layer)
	_subtitle = Label.new()
	_subtitle.add_theme_font_override("font", UiStyle.font(UiStyle.FONT_PIXEL_BOLD))
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.add_theme_color_override("font_color", Color("#FFE9B8"))
	_subtitle.add_theme_color_override("font_outline_color", Color("#101018"))
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.anchor_left = 0.15
	_subtitle.anchor_right = 0.85
	_subtitle.anchor_top = 0.82
	_subtitle.anchor_bottom = 0.92
	_subtitle_layer.add_child(_subtitle)


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
	return label


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


func _plan(track: int, earliest: float) -> Dictionary:
	var destination: Array = Layout.DESTINATIONS[_random.randi() % Layout.DESTINATIONS.size()]
	var intercity: bool = destination[1] == "Intercity"
	var departure := {
		"id": _next_id, "track": track, "time": ceilf(earliest), "delay": 0.0,
		"destination": destination[0], "kind": destination[1],
		"cars": 3 if (intercity and _random.randf() < 0.8) or (not intercity and _random.randf() < 0.4) else 2,
		"cancelled": _random.randf() < CANCEL_CHANCE,
		"dwell": _random.randf_range(DWELL_MINUTES.x, DWELL_MINUTES.y),
		"state": "gepland", "train": null, "announced": false, "cancel_announced": false,
		"whistled": false, "closing": false, "conductor": null,
	}
	if _random.randf() < DELAY_CHANCE:
		departure.delay = float(_random.randi_range(1, 8))
	_next_id += 1
	_departures.append(departure)
	_departures.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.time) < float(second.time))
	_track_departure[track] = departure
	return departure


## The station as you walk in: about half the tracks have a train standing.
func _plan_start() -> void:
	for track in range(1, Layout.TRACK_COUNT + 1):
		if _random.randf() < 0.45:
			var departure := _plan(track, _minutes + _random.randf_range(1.2, 3.5))
			departure.cancelled = false
			var train := _make_train(departure)
			train.stand()
			departure.state = "staat"
			_send_conductor(departure)
		else:
			_plan(track, _minutes + _random.randf_range(1.0, 8.0))


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
			_plan(track, _minutes + _random.randf_range(GAP_MINUTES.x, GAP_MINUTES.y) + DWELL_MINUTES.y)
			continue
		var left := _seconds_left(departure)
		if departure.cancelled:
			if not departure.cancel_announced and left < 300.0:
				departure.cancel_announced = true
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
			"staat":
				var train: StationTrain = departure.train
				if not departure.announced and left < ANNOUNCE_SECONDS:
					departure.announced = true
					var line := "Spoor %d: de %s naar %s, vertrekt om %s." % [track, departure.kind, departure.destination, _clock_text(_departs_at(departure))]
					if float(departure.delay) > 0.0:
						line += " Deze trein heeft ongeveer %d minuten vertraging." % int(departure.delay)
					_announce(line)
				if not departure.whistled and left < WHISTLE_SECONDS:
					departure.whistled = true
					var conductor: StationPerson = departure.conductor
					if conductor and is_instance_valid(conductor) and conductor.position.distance_to(train.front_door_spot()) < 2.0:
						conductor.blow_whistle()
					else:
						StationAudio.play_at(self, "conducteur_fluit", train.front_door_spot() + Vector3.UP * 1.6, -3.0)
				if not departure.closing and left < CLOSE_SECONDS:
					departure.closing = true
					StationAudio.play_at(self, "trein_deuren_dicht", train.position + Vector3(0.0, 1.5, train.nose_z + train.length() * 0.5), -3.0)
					train.close_doors()
					var conductor: StationPerson = departure.conductor
					if conductor and is_instance_valid(conductor):
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
		_spawn_clock = _random.randf_range(0.5, 1.4)
		if _travellers() < _target_travellers():
			_traveller_comes_in()
	_keep_staff()
	_notice_clock -= delta
	if _notice_clock <= 0.0:
		_notice_clock = _random.randf_range(100.0, 220.0)
		_announce(NOTICES[_random.randi() % NOTICES.size()])
	if not _announcing and not _announcements.is_empty():
		_speak(_announcements.pop_front())


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
			(row[0] as Label3D).text = _clock_text(float(departure.time))
			(row[1] as Label3D).text = "%s  %s" % [departure.destination, "IC" if departure.kind == "Intercity" else "SPR"]
			(row[2] as Label3D).text = str(departure.track)
			var remark := row[3] as Label3D
			if departure.cancelled:
				remark.text = "Rijdt niet"
				remark.modulate = BOARD_RED
			elif float(departure.delay) > 0.0:
				remark.text = "+%d" % int(departure.delay)
				remark.modulate = BOARD_YELLOW
			else:
				remark.text = ""
	for track: int in _displays:
		var labels: Dictionary = _displays[track]
		var departure: Dictionary = _track_departure.get(track, {})
		if departure.is_empty():
			(labels.time as Label3D).text = ""
			(labels.destination as Label3D).text = ""
			continue
		var when := _clock_text(float(departure.time))
		if departure.cancelled:
			when += "  rijdt niet"
		elif float(departure.delay) > 0.0:
			when += "  +%d" % int(departure.delay)
		(labels.time as Label3D).text = "%s  %s" % [when, departure.kind]
		(labels.destination as Label3D).text = String(departure.destination)


# ------------------------------------------------------------------ announcements

func _announce(text: String) -> void:
	if _announcements.size() < 4:
		_announcements.append(text)


## The chime, then the voice (the babble of the game, through the loudspeakers) with the
## words at the bottom of the screen.
func _speak(text: String) -> void:
	_announcing = true
	if _subtitle:
		_subtitle.text = text
		_subtitle_layer.visible = _player != null and is_visible_in_tree()
	StationAudio.play_everywhere(self, "omroep_gong", -4.0)
	await get_tree().create_timer(2.0, false).timeout
	var clips := clampi(text.length() / 16, 2, 7)
	for clip in clips:
		if not is_inside_tree():
			break
		var player := StationAudio.play_everywhere(self, "brabbel_%s_neutraal_%d" % [ANNOUNCER_VOICE, _random.randi_range(1, 3)], -3.0)
		if player:
			await player.finished
		else:
			await get_tree().create_timer(0.6, false).timeout
		await get_tree().create_timer(0.06, false).timeout
	await get_tree().create_timer(1.0, false).timeout
	if _subtitle_layer:
		_subtitle_layer.visible = false
	_announcing = false


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


## How many got into a train and how many went out through the doors (for the checks).
var boarded := 0
var went_out := 0


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
	nearest.z += _random.randf_range(-0.25, 0.25)
	var aboard: Array[Dictionary] = [{"type": "board", "spot": nearest, "inside": train.inside_of(nearest)}, {"type": "leave"}]
	person.replace_steps(aboard)


func _missed(person: StationPerson) -> void:
	var old_id := int(person.departure.get("id", -1))
	person.departure = {}
	if _random.randf() < 0.6:
		var departure := _pick_departure(1.5, 14.0, old_id)
		if not departure.is_empty():
			person.replace_steps(_to_train(person, person.position, departure))
			return
	person.replace_steps(_out_of_the_station(person, person.position))


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
	for leader in _patrol_leaders:
		if is_instance_valid(leader) and leader.steps.is_empty():
			leader.steps = _hall_round(leader)
	if _platform_patrol == null or not is_instance_valid(_platform_patrol):
		_platform_patrol = _spawn("handhaver", _staff_door())
	if _platform_patrol.steps.is_empty():
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
func _populate() -> void:
	var wanted := _target_travellers()
	for index in wanted:
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
				continue
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
	var points := _detour(Vector2(from.x, from.z), Vector2(to.x, to.z), 3)
	for point in points:
		steps.append({"type": "walk", "to": Vector3(point.x, 0.0, point.y)})


## The corners to go by from `from` to `to` (to included) so no obstacle is in the way.
func _detour(from: Vector2, to: Vector2, depth: int) -> Array[Vector2]:
	var blocking := _first_obstacle(from, to)
	if blocking == Rect2() or depth <= 0:
		return [to]
	var grown := blocking.grow(OBSTACLE_MARGIN + 0.1)
	var corners: Array[Vector2] = [grown.position, Vector2(grown.end.x, grown.position.y), grown.end, Vector2(grown.position.x, grown.end.y)]
	var best: Array[Vector2] = []
	var best_length := INF
	for first_index in 4:
		var corner := corners[first_index]
		if _hits(from, corner, blocking.grow(OBSTACLE_MARGIN)):
			continue
		if not _hits(corner, to, blocking.grow(OBSTACLE_MARGIN)):
			var length := from.distance_to(corner) + corner.distance_to(to)
			if length < best_length:
				best_length = length
				best = [corner]
			continue
		for step in [-1, 1]:
			var second := corners[(first_index + step + 4) % 4]
			if _hits(second, to, blocking.grow(OBSTACLE_MARGIN)):
				continue
			var length := from.distance_to(corner) + corner.distance_to(second) + second.distance_to(to)
			if length < best_length:
				best_length = length
				best = [corner, second]
	if best.is_empty():
		return [to]
	var points: Array[Vector2] = []
	var here := from
	for corner in best:
		points.append_array(_detour(here, corner, depth - 1))
		here = corner
	points.append_array(_detour(here, to, depth - 1))
	return points


func _first_obstacle(from: Vector2, to: Vector2) -> Rect2:
	var nearest := Rect2()
	var nearest_distance := INF
	for obstacle: Rect2 in HALL_OBSTACLES:
		var grown := obstacle.grow(OBSTACLE_MARGIN)
		if grown.has_point(from) or grown.has_point(to):
			continue
		if _hits(from, to, grown):
			var distance := from.distance_to(grown.get_center())
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = obstacle
	return nearest


func _inside_obstacle(at: Vector2) -> bool:
	for obstacle: Rect2 in HALL_OBSTACLES:
		if obstacle.grow(OBSTACLE_MARGIN).has_point(at):
			return true
	return false


static func _hits(from: Vector2, to: Vector2, area: Rect2) -> bool:
	if area.has_point(from) or area.has_point(to):
		return true
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for index in 4:
		if Geometry2D.segment_intersects_segment(from, to, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false
