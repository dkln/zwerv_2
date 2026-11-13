extends "res://tests/integration/support/town_test.gd"
## Being put out of a building (Interiors.offence, Eviction, Interiors.throw_out;
## data/gesprekken/uitzetten.json), in the town: the warnings first, then someone of the
## place shouts and comes for the player, and only once they are at them the throw (out of
## the door, tumbling, slow motion, hurt on landing, the narrator telling why, barred for a
## while); going out before they are there; and a BOA coming for you in Den Haag Centraal.
##   tests/run_integration_tests.sh throw_out

const Interiors = preload("res://scripts/world/interiors.gd")
## Metres within which who comes for the player has them (Eviction.CATCH_REACH and a little).
const AT_THE_PLAYER := 1.2


## How far `someone` is from the player along the floor (metres).
func _gap_to_player(someone: Node3D) -> float:
	return Vector2(someone.global_position.x - player.global_position.x, someone.global_position.z - player.global_position.z).length()


## Who is coming for the player now (Eviction.person), or null.
func _who_comes() -> Node3D:
	return interiors.eviction().person if interiors.eviction() else null


## Begging in a snack bar: two warnings, the third time the keeper shouts and comes out from
## behind the counter, and only once he is at you are you thrown out: flung out of the door
## in slow motion, hurt as you land, then the narrator says why and you are barred a while.
func test_begging_is_warned_then_the_keeper_comes_and_throws_you_out(test) -> void:
	var bar: Dictionary = await enter("snackbar")
	test.check(interiors.is_inside(), "in de snackbar")
	Interiors.note_offence(tree, "bedelen")
	Interiors.note_offence(tree, "bedelen")
	test.check(interiors.is_inside() and interiors.warnings_given == 2 and not interiors.is_evicting(),
		"twee keer bedelen: twee waarschuwingen (%d), nog binnen" % interiors.warnings_given)
	Interiors.note_offence(tree, "bedelen")
	test.check(interiors.is_inside() and interiors.is_evicting(), "de derde keer: niet meer welkom, maar nog binnen")
	await frames(5)
	var keeper := _who_comes()
	test.check(keeper != null and String(keeper.get("role")) == "snackbarhouder", "de snackbarhouder komt op je af")
	var keeper_start: Vector3 = keeper.global_position if keeper else Vector3.ZERO
	var shouted := keeper != null and keeper.has_meta("shout_balloon")
	var gap_at_grab := INF
	var last_gap := INF
	var slowest := 1.0
	var hidden_before_throw := false
	var shards_seen := false
	var rose_gradually := false
	var bang_before_flight := false
	var damage_number := ""
	var health_at_throw := -1.0
	var hurt_before_landing := false
	var flew := false
	var farthest := 0.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000 and not hud.is_showing_story():
		await tree.process_frame
		if keeper and is_instance_valid(keeper) and not interiors.get("_throwing"):
			last_gap = _gap_to_player(keeper)
			shouted = shouted or keeper.has_meta("shout_balloon")
		if interiors.get("_throwing") and gap_at_grab == INF:
			gap_at_grab = last_gap
		slowest = minf(slowest, Engine.time_scale)
		for number: Dictionary in hud._floating_numbers._numbers:
			var shown_text: String = (number.label as Label).text
			if shown_text.begins_with("-"):
				damage_number = "%s (zichtbaar %s)" % [shown_text, (number.label as Label).visible]
		var burst_there: bool = player.get_parent().get_children().any(func(child: Node) -> bool: return child is CrashBurst)
		if not interiors.is_inside() and not flew and player._ragdoll == null and burst_there:
			bang_before_flight = true
		# up again: the figure partly upright for a while (between lying and standing)
		if flew and player._ragdoll == null and player._rising_left > 0.0:
			var tilt: float = player._model.transform.basis.y.angle_to(Vector3.UP)
			if tilt > 0.2 and tilt < 1.4:
				rose_gradually = true
		if not interiors.is_inside() and player._ragdoll == null and not flew and not player.visible:
			hidden_before_throw = true
		if player._ragdoll != null and health_at_throw < 0.0:
			health_at_throw = player._stats.gezondheid.x
		if player._ragdoll != null and not shards_seen:
			shards_seen = burst_there
			# hurt before the first hard blow (no shards yet): too early
			if not shards_seen and player._stats.gezondheid.x < health_at_throw:
				hurt_before_landing = true
		if player._ragdoll != null:
			flew = true
			farthest = maxf(farthest, Vector2(player.global_position.x - bar.door.x, player.global_position.z - bar.door.z).length())
	test.check(shouted, "hij roept iets als hij eraan komt")
	test.check(keeper != null and gap_at_grab < AT_THE_PLAYER and keeper_start.distance_to(player.global_position) > AT_THE_PLAYER,
		"pas als hij bij je is, word je eruit gezet (%.2f m toen)" % gap_at_grab)
	test.check(not interiors.is_inside(), "eruit gegooid: weer buiten")
	test.check(flew, "de deur uit gesmeten (tuimelend)")
	test.check(slowest < 0.5, "in slow motion (%.2f)" % slowest)
	test.check(shards_seen, "hard neergekomen: scherven als bij een botsing")
	test.check(not hurt_before_landing and player._stats.gezondheid.x < health_at_throw,
		"pas bij het neerkomen gezondheid eraf (%.0f naar %.0f)" % [health_at_throw, player._stats.gezondheid.x])
	test.check(hidden_before_throw and player.visible, "voor de worp niet te zien voor de deur, daarna wel")
	test.check(farthest > 1.5, "een eind de straat op (%.1f m van de deur)" % farthest)
	test.check(bang_before_flight, "een knal bij de deur voordat je wegvliegt")
	test.check(damage_number.begins_with("-12"), "bij het neerkomen het schadegetal: %s" % damage_number)
	test.check(hud.is_showing_story(), "daarna wordt gezegd waarom")
	test.check(rose_gradually, "opstaan geanimeerd, van liggen naar rechtop")
	var camera: Node = scene.get_node("Volgcamera")
	test.check(is_equal_approx(Engine.time_scale, 1.0) and not camera._dramatic, "slow motion en close-up weer voorbij (%.2f)" % Engine.time_scale)
	var page: Dictionary = hud._story_box._pages[0] if hud.is_showing_story() else {}
	test.check(page.get("kind") == "verhaal" and not page.has("choices") and str(page.get("text", "")).contains("kleingeld"),
		"de verteller vertelt wat er gebeurde (het bedelen)")
	await close_screens()
	await interiors.enter(bar)
	await frames(30)
	test.check(not interiors.is_inside(), "even niet meer naar binnen")


## Out of the door yourself before the keeper is there: you are away, not thrown out, but
## not welcome back for a while either.
func test_out_of_the_door_before_he_is_there(test) -> void:
	var bar: Dictionary = await enter("snackbar")
	for times in 3:
		Interiors.note_offence(tree, "bedelen")
	await frames(30)
	test.check(interiors.is_evicting(), "niet meer welkom: hij komt eraan")
	await leave_interior(1)
	test.check(not interiors.is_inside() and not interiors.get("_throwing") and not hud.is_showing_story(),
		"zelf de deur uit voor hij er is: weg, niet eruit gegooid")
	await interiors.enter(bar)
	await frames(30)
	test.check(not interiors.is_inside(), "en ook dan even niet meer naar binnen")


## Den Haag Centraal, a fine you cannot pay: a BOA comes for you along the hall, and only
## once he is at you are you put out of the station; the narrator tells of the fine.
func test_at_the_station_a_boa_comes_for_you(test) -> void:
	await enter("centraal")
	test.check(interiors.is_inside(), "in het station")
	Interiors.note_offence(tree, "boete_onbetaald")
	await frames(30)
	var boa := _who_comes()
	test.check(interiors.is_inside() and boa != null and String(boa.get("role")) == "handhaver",
		"boete niet betaald: een handhaver komt je halen")
	var gap := INF
	var gap_at_grab := INF
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 60000 and not hud.is_showing_story():
		await tree.process_frame
		var coming := _who_comes()
		if coming and is_instance_valid(coming) and interiors.is_inside() and not interiors.get("_throwing"):
			gap = _gap_to_player(coming)
		if interiors.get("_throwing") and gap_at_grab == INF:
			gap_at_grab = gap
	test.check(not interiors.is_inside() and hud.is_showing_story() and gap_at_grab < AT_THE_PLAYER,
		"pas als de handhaver bij je is, het station uit (%.2f m toen)" % gap_at_grab)
	var page: Dictionary = hud._story_box._pages[0] if hud.is_showing_story() else {}
	test.check(page.get("kind") == "verhaal" and str(page.get("text", "")).contains("boete"), "de verteller vertelt het (de boete)")
