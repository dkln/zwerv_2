extends RefCounted
## Unit tests of the rules of the follow camera (scripts/camera/follow_camera_rules.gd).
##   tests/run_unit_tests.sh follow_camera_rules

const Rules = preload("res://scripts/camera/follow_camera_rules.gd")
const IsoRules = preload("res://scripts/camera/iso_camera_rules.gd")
const CameraTurning = preload("res://scripts/camera/camera_turning.gd")


## A street map as the rules ask it: the cells (dx, dz from the player) that are built.
class Blocks:
	var built_cells := {}

	func _init(cells: Array) -> void:
		for cell: Vector2i in cells:
			built_cells[cell] = true

	func built(dx: int, dz: int) -> bool:
		return built_cells.has(Vector2i(dx, dz))


## A row of built cells: every dz (or dx) from -3 to 3 at the given dx (or dz).
static func _row(fixed: int, along_z: bool) -> Array:
	var cells := []
	for along in range(-3, 4):
		cells.append(Vector2i(fixed, along) if along_z else Vector2i(along, fixed))
	return cells


# ------------------------------------------------------------------ gliding

func test_glide_settles_on_the_goal_without_overshoot(test) -> void:
	var value := 0.0
	var velocity := 0.0
	var highest := 0.0
	for frame in 600:
		var glided := Rules.glide(value, 10.0, velocity, 0.6, 1.0 / 60.0)
		value = glided.x
		velocity = glided.y
		highest = maxf(highest, value)
	test.check(absf(value - 10.0) < 0.001 and absf(velocity) < 0.001, "na tien seconden op het doel (%.4f)" % value)
	test.check(highest <= 10.0001, "zonder eroverheen te schieten (%.4f)" % highest)
	var first := Rules.glide(0.0, 10.0, 0.0, 0.6, 1.0 / 60.0)
	test.check(first.x > 0.0 and first.x < 0.1 and first.y > 0.0, "het begint zacht (%.4f)" % first.x)
	test.check(Rules.glide(4.0, 4.0, 0.0, 0.6, 0.1) == Vector2(4.0, 0.0), "op het doel en stil: blijft staan")
	test.check(Rules.glide(3.0, 9.0, 2.0, 0.5, 0.0) == Vector2(3.0, 2.0), "geen tijd: niets verandert")
	test.check(is_finite(Rules.glide(0.0, 1.0, 0.0, 0.0, 0.016).x), "een tijd van 0 deelt niet door nul")


func test_jumped_tells_a_respawn_from_moving(test) -> void:
	test.check(not Rules.jumped(Vector3.ZERO, Vector3(1.0, 0.0, 0.0), 1.0 / 60.0), "60 m/s: gereden")
	test.check(Rules.jumped(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), 1.0 / 60.0), "120 m/s: gesprongen")
	test.check(not Rules.jumped(Vector3.ZERO, Vector3(500.0, 0.0, 0.0), 0.0), "geen tijd verstreken: geen sprong")
	test.check(not Rules.jumped(Vector3.ONE, Vector3.ONE, 0.016), "stilstaand niet")


func test_smoothed_velocity_follows_gradually(test) -> void:
	var velocity := Rules.smoothed_velocity(Vector3.ZERO, Vector3.ZERO, Vector3(0.1, 0.0, 0.0), 0.6, 1.0 / 60.0)
	test.check(velocity.x > 0.0 and velocity.x < 6.0, "een eerste frame van 6 m/s telt maar een beetje (%.2f)" % velocity.x)
	var spot := Vector3.ZERO
	for frame in 600:
		var next := spot + Vector3(0.1, 0.0, 0.0)
		velocity = Rules.smoothed_velocity(velocity, spot, next, 0.6, 1.0 / 60.0)
		spot = next
	test.check(absf(velocity.x - 6.0) < 0.01, "na een tijd de echte snelheid (%.2f)" % velocity.x)
	test.check(Rules.smoothed_velocity(Vector3(1, 2, 3), Vector3.ZERO, Vector3.ONE, 0.6, 0.0) == Vector3(1, 2, 3), "geen tijd: de oude snelheid")


func test_lead_stays_within_a_share_of_the_view(test) -> void:
	test.check(Rules.lead(Vector3(2.0, 0.0, 0.0), 0.8, 40.0, 0.12).is_equal_approx(Vector3(1.6, 0.0, 0.0)), "0,8 s vooruit")
	var far := Rules.lead(Vector3(30.0, 0.0, 0.0), 0.8, 40.0, 0.12)
	test.check(is_equal_approx(far.length(), 4.8), "hooguit 12 %% van het beeld (%.2f)" % far.length())
	test.check(Rules.lead(Vector3.ZERO, 0.8, 40.0, 0.12) == Vector3.ZERO, "stil: niets vooruit")


func test_focus_goal_lies_ahead_and_follows_ramps(test) -> void:
	var target := Vector3(10.0, 1.0, 5.0)
	var velocity := Vector3(4.0, -2.0, 0.0)
	var goal := Rules.focus_goal(target, velocity, Vector3(3.0, 0.5, 0.0), 0.0, 0.6)
	test.check(is_equal_approx(goal.x, 10.0 + 3.0 + 2.4) and is_equal_approx(goal.z, 5.0), "het punt vooruit en de achterstand van de veer (%s)" % goal)
	test.check(is_equal_approx(goal.y, 1.0 - 1.2), "omhoog en omlaag alleen het doel en zijn snelheid (%.2f)" % goal.y)
	var close := Rules.focus_goal(target, velocity, Vector3(3.0, 0.0, 0.0), 1.0, 0.6)
	test.check(is_equal_approx(close.x, 12.4), "in een close-up geen punt vooruit")


func test_zoom_for_speed(test) -> void:
	test.check(is_equal_approx(Rules.zoom_for_speed(0.0, 18.0, 26.0, 44.0, 3.0, 7.0), 18.0), "stil: dichtbij")
	test.check(is_equal_approx(Rules.zoom_for_speed(1.5, 18.0, 26.0, 44.0, 3.0, 7.0), 22.0), "half looptempo: halverwege")
	test.check(is_equal_approx(Rules.zoom_for_speed(3.0, 18.0, 26.0, 44.0, 3.0, 7.0), 26.0), "lopen")
	test.check(is_equal_approx(Rules.zoom_for_speed(5.0, 18.0, 26.0, 44.0, 3.0, 7.0), 35.0), "tussen lopen en rennen")
	test.check(is_equal_approx(Rules.zoom_for_speed(7.0, 18.0, 26.0, 44.0, 3.0, 7.0), 44.0), "rennen")
	test.check(is_equal_approx(Rules.zoom_for_speed(30.0, 18.0, 26.0, 44.0, 3.0, 7.0), 44.0), "harder dan rennen: niet verder uit")
	test.check(is_equal_approx(Rules.zoom_for_speed(3.0, 18.0, 26.0, 44.0, 3.0, 3.0), 26.0), "rennen even snel als lopen deelt niet door nul")


func test_gliding_over_zooms_out_and_eases(test) -> void:
	test.check(is_equal_approx(Rules.glide_over_zoom(Vector3(30.0, 0.0, 40.0), 0.5, 150.0), 25.0), "een halve meter per meter te gaan")
	test.check(is_equal_approx(Rules.glide_over_zoom(Vector3(1000.0, 0.0, 0.0), 0.5, 150.0), 150.0), "hooguit 150 m")
	var from := Vector3(20.0, 0.0, 0.0)
	test.check(Rules.way_to_go(from, 2.0, 2.0).is_equal_approx(from), "aan het begin: de hele weg")
	test.check(Rules.way_to_go(from, 1.0, 2.0).is_equal_approx(from * 0.5), "halverwege: de helft")
	test.check(Rules.way_to_go(from, 0.0, 2.0) == Vector3.ZERO, "aan het eind: er")
	test.check(Rules.way_to_go(from, 0.0, 0.0) == Vector3.ZERO, "een overgang van 0 s deelt niet door nul")


# ------------------------------------------------------------------ the arrival

func test_arrival_progress(test) -> void:
	test.check(Rules.arrival_progress(0.0, 5.5) == 0.0 and is_equal_approx(Rules.arrival_progress(2.75, 5.5), 0.5), "begin en halverwege")
	test.check(Rules.arrival_progress(9.0, 5.5) == 1.0, "niet verder dan het eind")
	test.check(Rules.arrival_progress(0.05, 0.0) == 0.5, "een aankomst van 0 s telt als 0,1 s")


func test_arrival_descent_drifts_through_the_clouds_and_settles(test) -> void:
	test.check(Rules.arrival_descent(0.0) == 0.0, "begin: nog bovenaan")
	test.check(is_equal_approx(Rules.arrival_descent(1.0), 1.0), "eind: beneden")
	var last := 0.0
	var rising := true
	for step in range(1, 21):
		var now := Rules.arrival_descent(step / 20.0)
		rising = rising and now >= last
		last = now
	test.check(rising, "het gaat alleen omlaag")
	var in_clouds := Rules.arrival_descent(0.2) - Rules.arrival_descent(0.1)
	var below := Rules.arrival_descent(0.65) - Rules.arrival_descent(0.55)
	var settling := Rules.arrival_descent(1.0) - Rules.arrival_descent(0.9)
	test.check(in_clouds < below, "in de wolken langzamer dan eronder (%.3f < %.3f)" % [in_clouds, below])
	test.check(settling < in_clouds, "aan het eind loopt de snelheid uit (%.4f)" % settling)


func test_arrival_view_size_and_the_clouds(test) -> void:
	test.check(is_equal_approx(Rules.arrival_view_size(95.0, 18.0, 0.0), 95.0), "begin: hoog in de lucht")
	test.check(absf(Rules.arrival_view_size(95.0, 18.0, 1.0) - 18.0) < 0.001, "eind: op de speler")
	var halfway := Rules.arrival_view_size(95.0, 18.0, 0.5)
	test.check(halfway < 95.0 and halfway > 18.0, "onderweg ertussen (%.1f)" % halfway)
	test.check(Rules.cloud_cover(0.0) == 1.0 and Rules.cloud_cover(0.62) == 1.0, "de wolken blijven lang dicht")
	test.check(Rules.cloud_cover(0.77) > 0.0 and Rules.cloud_cover(0.77) < 1.0, "dan dunnen ze uit")
	test.check(Rules.cloud_cover(0.92) == 0.0 and Rules.cloud_cover(1.0) == 0.0, "beneden zijn ze weg")
	test.check(is_equal_approx(Rules.cloud_magnify(95.0, 95.0), 1.0) and is_equal_approx(Rules.cloud_magnify(95.0, 19.0), 5.0), "de wolken groeien mee met het inzoomen")
	test.check(is_finite(Rules.cloud_magnify(95.0, 0.0)), "een beeld van 0 m deelt niet door nul")


# ------------------------------------------------------------------ the player's zoom and turn

func test_user_zoom(test) -> void:
	test.check(is_equal_approx(Rules.user_zoom_after(1.0, 1), Rules.ZOOM_STEP), "een druk uit")
	test.check(is_equal_approx(Rules.user_zoom_after(1.0, -1), 1.0 / Rules.ZOOM_STEP), "een druk in")
	test.check(is_equal_approx(Rules.user_zoom_after(1.9, 3), Rules.ZOOM_MOST.y), "niet verder uit dan de grens")
	test.check(is_equal_approx(Rules.user_zoom_after(0.52, -3), Rules.ZOOM_MOST.x), "niet verder in dan de grens")
	test.check(Rules.user_zoom_after(1.3, 0) == 1.3, "geen druk: gelijk")
	var shown := Rules.user_zoom_now(1.0, 2.0, 1.0 / 60.0)
	test.check(shown > 1.0 and shown < 1.2, "het glijdt erheen (%.3f)" % shown)
	test.check(absf(Rules.user_zoom_now(1.0, 2.0, 5.0) - 2.0) < 0.001, "en komt er")
	test.check(Rules.user_zoom_now(1.4, 2.0, 0.0) == 1.4, "geen tijd: gelijk")


func test_turning_back_and_whole_turns(test) -> void:
	test.check(Rules.turn_back_goal(90.0) == 0.0 and Rules.turn_back_goal(-90.0) == 0.0, "een kwartslag: terug naar 0")
	test.check(Rules.turn_back_goal(270.0) == 360.0, "driekwart: de korte kant op verder")
	test.check(Rules.turn_back_goal(-270.0) == -360.0, "ook linksom")
	test.check(Rules.whole_turns_done(360.0, 360.0) == 360.0, "een hele slag gedraaid: eraf")
	test.check(Rules.whole_turns_done(-720.0, -720.0) == -720.0, "twee slagen linksom")
	test.check(Rules.whole_turns_done(350.0, 360.0) == 0.0, "nog onderweg: niet")
	test.check(Rules.whole_turns_done(270.0, 270.0) == 0.0, "minder dan een slag: niet")
	test.check(Rules.whole_turns_done(450.0, 450.0) == 360.0, "een slag en een kwart: de hele slag eraf")


func test_key_action_and_the_wheel(test) -> void:
	test.check(Rules.key_action(CameraTurning.KEY_LEFT_TURN) == {"turn": -1}, "Z: een kwartslag naar links")
	test.check(Rules.key_action(CameraTurning.KEY_RIGHT_TURN) == {"turn": 1}, "X: naar rechts")
	test.check(Rules.key_action(CameraTurning.KEY_TURN_BACK) == {"back": true}, "C: terug")
	for keycode: Key in CameraTurning.KEYS_ZOOM_IN:
		test.check(Rules.key_action(keycode) == {"zoom": -1}, "%s: inzoomen" % OS.get_keycode_string(keycode))
	for keycode: Key in CameraTurning.KEYS_ZOOM_OUT:
		test.check(Rules.key_action(keycode) == {"zoom": 1}, "%s: uitzoomen" % OS.get_keycode_string(keycode))
	test.check(Rules.key_action(KEY_W).is_empty() and Rules.key_action(KEY_F8).is_empty(), "andere toetsen niets")
	test.check(Rules.wheel_zoom(MOUSE_BUTTON_WHEEL_UP) == -1 and Rules.wheel_zoom(MOUSE_BUTTON_WHEEL_DOWN) == 1, "het wiel: omhoog in, omlaag uit")
	test.check(Rules.wheel_zoom(MOUSE_BUTTON_LEFT) == 0 and Rules.wheel_zoom(MOUSE_BUTTON_RIGHT) == 0, "een klik zoomt niet")


# ------------------------------------------------------------------ turning to the street

func test_towards_camera(test) -> void:
	test.check(Rules.towards_camera(0.0, IsoRules.ROTATION.x).distance_to(IsoRules.DIRECTION) < 0.001, "de gewone blik: de iso-richting")
	var quarter := Rules.towards_camera(90.0, IsoRules.ROTATION.x)
	test.check(quarter.distance_to(IsoRules.direction(IsoRules.ROTATION.y + 90.0)) < 0.001, "een kwartslag gedraaid")
	test.check(Rules.towards_camera(0.0, -90.0).distance_to(Vector3.UP) < 0.001, "recht van boven: omhoog")


func test_choosing_when_to_turn(test) -> void:
	test.check(Rules.is_other_view(90.0, NAN), "nog niets gevraagd: een andere blik")
	test.check(not Rules.is_other_view(90.0, 90.5) and not Rules.is_other_view(0.0, 359.5), "binnen een graad (ook over de 360): dezelfde")
	test.check(Rules.is_other_view(90.0, 180.0), "een kwartslag verder: een andere")
	test.check(is_equal_approx(Rules.turn_ahead(270.0, 0.0), 90.0), "270 ligt rechtsom een kwartslag verder")
	test.check(is_equal_approx(Rules.turn_ahead(90.0, 0.0), 270.0), "90 ligt rechtsom driekwart verder: nooit de korte kant terug")
	test.check(is_equal_approx(Rules.turn_ahead(90.0, -270.0), 0.0), "dezelfde blik in andere getallen: niets")
	test.check(Rules.is_a_turn(90.0) and Rules.is_a_turn(270.0), "een kwart en driekwart zijn een draai")
	test.check(not Rules.is_a_turn(0.5) and not Rules.is_a_turn(359.5) and not Rules.is_a_turn(0.0), "bijna niets of bijna rond niet")
	test.check(Rules.steep_after(false, 1.2, 0.5) == 0.5, "zonder draaien: na top_down_after van boven")
	test.check(Rules.steep_after(true, 1.2, 0.5) == 2.4, "met draaien: pas na twee keer turn_after")


func test_street_turn_looks_from_the_open_side(test) -> void:
	var open := Blocks.new([])
	test.check(is_nan(Rules.street_turn(open.built, 0.0)), "een plein: geen blik gevraagd")
	test.check(Rules.open_side(open.built).length() < 0.001, "rondom open: geen kant")
	# buildings to the north and the west: the street lies south-east, where the usual camera
	# does not stand (it stands north-east)
	var corner := Blocks.new(_row(-1, false) + _row(-2, false) + _row(-1, true) + _row(-2, true))
	var side := Rules.open_side(corner.built)
	test.check(side.x > 0.0 and side.y > 0.0 and side.length() >= Rules.STREET_CLEAR, "de open kant is het zuidoosten (%s)" % side)
	var turn := Rules.street_turn(corner.built, 0.0)
	var to_camera := Rules.towards_camera(turn, IsoRules.ROTATION.x)
	test.check(turn in Rules.ISO_TURNS, "een iso-blik (%.0f)" % turn)
	test.check(to_camera.x > 0.0 and to_camera.z > 0.0, "de camera staat aan de straatkant (%s)" % to_camera)
	# enclosed evenly: a court
	var court := Blocks.new(_row(-3, false) + _row(3, false) + _row(-3, true) + _row(3, true))
	test.check(is_nan(Rules.street_turn(court.built, 0.0)), "een hof: geen blik gevraagd")


func test_street_turn_looks_along_a_narrow_street(test) -> void:
	# buildings east and west: a street running north-south
	var street := Blocks.new(_row(1, true) + _row(-1, true))
	var turn := Rules.street_turn(street.built, 0.0)
	test.check(turn in Rules.STRAIGHT_TURNS, "recht langs de straat (%.0f)" % turn)
	var to_camera := Rules.towards_camera(turn, IsoRules.ROTATION.x)
	test.check(absf(to_camera.x) < 0.01, "de camera staat in de straat, niet erboven (%s)" % to_camera)
	test.check(is_equal_approx(turn, 315.0), "van de twee einden het eerste rechtsom vanaf 0 (%.0f)" % turn)
	test.check(is_equal_approx(Rules.street_turn(street.built, 315.0), 315.0), "staat het er al, dan blijft het")
	test.check(is_equal_approx(Rules.street_turn(street.built, 200.0), 135.0), "vanaf 200 komt rechtsom eerst 135")
	var across := Blocks.new(_row(1, false) + _row(-1, false))
	var across_camera := Rules.towards_camera(Rules.street_turn(across.built, 0.0), IsoRules.ROTATION.x)
	test.check(absf(across_camera.z) < 0.01, "een straat oost-west: de camera langs x (%s)" % across_camera)


func test_first_turn_round_takes_the_best_then_the_first(test) -> void:
	var east := func(from: Vector2) -> float: return from.x
	var best := Rules.first_turn_round(Rules.STRAIGHT_TURNS, east, 0.0)
	test.check(Rules.towards_camera(best, IsoRules.ROTATION.x).x > 0.99 * cos(deg_to_rad(35.264)), "de blik met de camera het meest in het oosten (%.0f)" % best)
	var all_equal := func(_from: Vector2) -> float: return 1.0
	test.check(is_equal_approx(Rules.first_turn_round(Rules.ISO_TURNS, all_equal, 0.0), 0.0), "allemaal even goed: de blik die het al heeft")
	test.check(is_equal_approx(Rules.first_turn_round(Rules.ISO_TURNS, all_equal, 100.0), 90.0), "anders de eerste rechtsom (90 vanaf 100)")
	test.check(is_nan(Rules.first_turn_round([], all_equal, 0.0)), "geen blikken: geen")


# ------------------------------------------------------------------ what hides the player

func test_sight_points_stand_round_the_target(test) -> void:
	var to_camera := Vector3(0.0, 0.5, 1.0).normalized()
	var points := Rules.sight_points(Vector3(5.0, 0.0, 5.0), to_camera, PackedFloat32Array([0.4, 1.7]), 0.4)
	test.check(points.size() == 6, "per hoogte drie punten (%d)" % points.size())
	test.check(points[1].is_equal_approx(Vector3(5.0, 0.4, 5.0)) and points[4].is_equal_approx(Vector3(5.0, 1.7, 5.0)), "het midden op elke hoogte")
	test.check(is_equal_approx(absf(points[0].x - 5.0), 0.4) and is_equal_approx(points[0].z, 5.0), "en 0,4 m opzij, dwars op de blik (%s)" % points[0])
	test.check(is_equal_approx(points[0].x + points[2].x, 10.0), "aan weerskanten")
	test.check(Rules.sight_points(Vector3.ZERO, to_camera, PackedFloat32Array(), 0.4).is_empty(), "geen hoogtes: geen punten")


func test_hidden_points_walks_to_the_camera(test) -> void:
	var to_camera := Vector3(0.0, 0.0, 1.0)
	var points: Array[Vector3] = [Vector3(0.0, 1.0, 0.0), Vector3(3.0, 1.0, 0.0)]
	var wall := func(point: Vector3) -> bool: return point.z > 4.5 and point.z < 5.5 and absf(point.x) < 1.0
	test.check(Rules.hidden_points(points, to_camera, 20.0, wall) == 1, "een muur voor het ene punt, niet voor het andere")
	test.check(Rules.hidden_points(points, to_camera, 5.0, wall) == 0, "de camera staat voor de muur: niets verborgen")
	var everywhere := func(_point: Vector3) -> bool: return true
	test.check(Rules.hidden_points(points, to_camera, 20.0, everywhere) == 2, "elk punt telt een keer")
	test.check(Rules.hidden_points(points, to_camera, 1.0, everywhere) == 0, "een camera op een meter: geen stappen")
	var empty: Array[Vector3] = []
	test.check(Rules.hidden_points(empty, to_camera, 20.0, everywhere) == 0, "geen punten: niets")


func test_on_camera_side(test) -> void:
	var to_camera := IsoRules.DIRECTION
	test.check(Rules.on_camera_side(Vector3(4.0, 0.0, -4.0), Vector3.ZERO, to_camera), "een gebouw tussen de speler en de camera")
	test.check(not Rules.on_camera_side(Vector3(-4.0, 0.0, 4.0), Vector3.ZERO, to_camera), "een gebouw in de rug niet")
	test.check(not Rules.on_camera_side(Vector3(0.0, 30.0, 0.0), Vector3.ZERO, to_camera), "recht erboven niet (plat gemeten)")


# ------------------------------------------------------------------ close-up and shake

func test_closeness_eases_in_and_out(test) -> void:
	test.check(Rules.closeness(0.0) == 0.0 and Rules.closeness(1.0) == 0.0, "begin en eind: de gewone blik")
	test.check(Rules.closeness(0.5) == 1.0 and Rules.closeness(0.3) == 1.0, "ertussen het dichtst")
	test.check(Rules.closeness(0.125) > 0.0 and Rules.closeness(0.125) < 1.0, "erin glijdend")
	test.check(is_equal_approx(Rules.closeness(0.125), Rules.closeness(0.875)), "en er even zacht weer uit")


func test_closeup_swing(test) -> void:
	test.check(is_equal_approx(Rules.closeup_swing(70.0, 0.0, 1.0, 1.0), -35.0), "begint een halve boog aan de ene kant")
	test.check(is_equal_approx(Rules.closeup_swing(70.0, 1.0, 1.0, 1.0), 35.0), "eindigt een halve boog aan de andere")
	test.check(Rules.closeup_swing(70.0, 0.5, 1.0, 1.0) == 0.0, "halverwege recht")
	test.check(is_equal_approx(Rules.closeup_swing(70.0, 1.0, -1.0, 0.5), -17.5), "de andere kant op, en maar zo ver als het dichtbij is")


func test_the_shake_of_a_crash(test) -> void:
	test.check(Rules.is_shaking(0.0, 0.7) and Rules.is_shaking(0.7, 0.7), "van de klap tot het uitsterven")
	test.check(not Rules.is_shaking(-0.1, 0.7) and not Rules.is_shaking(0.71, 0.7), "ervoor en erna niet")
	test.check(is_equal_approx(Rules.shake_amount(0.6, 1.0, 0.0, 0.7, 40.0), 0.6), "de hardste klap, net gebeurd, bij 40 m in beeld")
	test.check(is_equal_approx(Rules.shake_amount(0.6, 0.5, 0.0, 0.7, 40.0), 0.3), "een halve klap half zo hard")
	test.check(is_equal_approx(Rules.shake_amount(0.6, 1.0, 0.35, 0.7, 40.0), 0.15), "halverwege nog een kwart (kwadratisch uitstervend)")
	test.check(Rules.shake_amount(0.6, 1.0, 0.7, 0.7, 40.0) == 0.0, "aan het eind niets")
	test.check(is_equal_approx(Rules.shake_amount(0.6, 1.0, 0.0, 0.7, 8.0), 0.6 * 0.4), "ver ingezoomd: minstens 0,4 keer")
	test.check(is_equal_approx(Rules.shake_amount(0.6, 1.0, 0.0, 0.7, 400.0), 0.6 * 1.5), "ver uitgezoomd: hooguit 1,5 keer")
