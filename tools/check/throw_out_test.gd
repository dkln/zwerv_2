extends SceneTree
## Thrown out of a building (Interiors.throw_out, data/gesprekken/uitzetten.json): begging
## too much in a snack bar (Interiors.note_offence "bedelen", three times) throws the player
## out: back on the pavement, flung out of the door (tumbling: a ragdoll that lands further
## out), up again, and then the keeper says why (a conversation without choices); for a while
## the way back in stays shut. In Den Haag Centraal a fare dodger who cannot pay the fine is
## thrown out at once, told by the conductor (on duty: their style).
## usage: tools/godot.sh --headless --script tools/check/throw_out_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const Interiors = preload("res://scripts/world/interiors.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 300)
	PlayerCharacter.choose("martin")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var hud: Node = scene.get_node("HUD")
	scene.get_node("Volgcamera")._end_arrival()
	for frame_index in 600:
		await physics_frame
		if player._placed and not player._sleeping:
			break
	player._wake_up()
	for attempt in 40:
		if not player._sleeping:
			break
		await create_timer(0.1, true).timeout
	await _close_story(hud)
	var interiors: Node = scene.get_node("Binnenruimtes")
	var bar: Dictionary = interiors.snack_bars()[0]
	# the snack bar: begging, three times
	await interiors.enter(bar)
	await _settle()
	_check(interiors.is_inside(), "in de snackbar")
	Interiors.note_offence(self, "bedelen")
	Interiors.note_offence(self, "bedelen")
	_check(interiors.is_inside(), "twee keer bedelen mag nog")
	Interiors.note_offence(self, "bedelen")
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
	var arrest_seen := {}   # what the scene of being carried off showed (ThrowOutScene)
	var arrest_camera: Camera3D = null
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000 and not hud.is_showing_story():
		await process_frame
		var arrest: Node = interiors.get("_arrest")
		if arrest and is_instance_valid(arrest):
			arrest_seen["scène"] = true
			arrest_seen["fase_" + String(arrest.phase())] = true
			if get_root().get_viewport().get_camera_3d() == arrest.get("_camera"):
				arrest_seen["camera"] = true
				arrest_camera = arrest.get("_camera")
			var thrower: Node = arrest.get("_bouncer")
			if thrower:
				arrest_seen["wie_" + String(thrower.role)] = true
			var stand_in: Node3D = arrest.get("_stand_in")
			if stand_in and stand_in.position.y > 0.3:
				arrest_seen["opgetild"] = true
		slowest = minf(slowest, Engine.time_scale)
		for number: Dictionary in hud._floating_numbers._numbers:
			var shown_text: String = (number.label as Label).text
			if shown_text.begins_with("-"):
				damage_number = "%s (zichtbaar %s)" % [shown_text, (number.label as Label).visible]
		if not interiors.is_inside() and not flew and player._ragdoll == null \
				and player.get_parent().get_children().any(func(child: Node) -> bool: return child is CrashBurst):
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
			shards_seen = player.get_parent().get_children().any(func(child: Node) -> bool: return child is CrashBurst)
			# hurt before the first hard blow (no shards yet): too early
			if not shards_seen and player._stats.gezondheid.x < health_at_throw:
				hurt_before_landing = true
		if player._ragdoll != null:
			flew = true
			farthest = maxf(farthest, Vector2(player.global_position.x - bar.door.x, player.global_position.z - bar.door.z).length())
	print("  meegenomen: ", arrest_seen.keys())
	_check(arrest_seen.has("scène") and arrest_seen.has("camera"), "eerst een eigen scène met een eigen camera")
	_check(arrest_seen.has("wie_snackbarhouder"), "de snackbarhouder komt je halen")
	_check(arrest_seen.has("fase_pakken") and arrest_seen.has("fase_dragen") and arrest_seen.has("opgetild"),
		"die pakt je bij je kraag, tilt je op en draagt je naar de deur")
	_check(interiors.get("_arrest") == null and get_root().get_viewport().get_camera_3d() != arrest_camera,
		"daarna weer de gewone camera, de scène weg")
	_check(not interiors.is_inside(), "eruit gegooid: weer buiten")
	_check(flew, "de deur uit gesmeten (tuimelend)")
	_check(slowest < 0.5, "in slow motion (%.2f)" % slowest)
	_check(shards_seen, "hard neergekomen: scherven als bij een botsing")
	_check(not hurt_before_landing and player._stats.gezondheid.x < health_at_throw,
			"pas bij het neerkomen gezondheid eraf (%.0f naar %.0f)" % [health_at_throw, player._stats.gezondheid.x])
	_check(hidden_before_throw and player.visible, "voor de worp niet te zien voor de deur, daarna wel")
	_check(farthest > 1.5, "een eind de straat op (%.1f m van de deur)" % farthest)
	_check(bang_before_flight, "een knal bij de deur voordat je wegvliegt")
	_check(damage_number.begins_with("-12"), "bij het neerkomen het schadegetal: %s" % damage_number)
	_check(hud.is_showing_story(), "daarna wordt gezegd waarom")
	_check(rose_gradually, "opstaan geanimeerd, van liggen naar rechtop")
	var camera: Node = scene.get_node("Volgcamera")
	_check(is_equal_approx(Engine.time_scale, 1.0) and not camera._dramatic, "slow motion en close-up weer voorbij (%.2f)" % Engine.time_scale)
	var page: Dictionary = hud._story_box._pages[0] if hud.is_showing_story() else {}
	print("  %s: %s" % [page.get("speaker", ""), page.get("text", "")])
	_check(page.get("kind") == "verhaal" and not page.has("choices") and str(page.get("text", "")).contains("kleingeld"),
			"de verteller vertelt wat er gebeurde (het bedelen)")
	await _close_story(hud)
	await interiors.enter(bar)
	await _settle()
	_check(not interiors.is_inside(), "even niet meer naar binnen")
	# Den Haag Centraal: caught fare dodging without the money for the fine: out at once
	interiors._barred_until.clear()
	var station_bar: Dictionary = interiors.ways_in().filter(func(way: Dictionary) -> bool: return way.kind == "centraal")[0]
	await interiors.enter(station_bar)
	await _settle()
	_check(interiors.is_inside(), "in het station")
	Interiors.note_offence(self, "boete_onbetaald")
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000 and not hud.is_showing_story():
		await process_frame
	_check(not interiors.is_inside() and hud.is_showing_story(), "boete niet betaald: meteen het station uit")
	page = hud._story_box._pages[0] if hud.is_showing_story() else {}
	print("  %s: %s" % [page.get("speaker", ""), page.get("text", "")])
	_check(page.get("kind") == "verhaal" and str(page.get("text", "")).contains("boete"), "de verteller vertelt het (de boete)")
	print("uitzetten ok" if _problems.is_empty() else "%d problemen: %s" % [_problems.size(), _problems])
	quit(0 if _problems.is_empty() else 1)


func _settle() -> void:
	for frame_index in 30:
		await process_frame


func _close_story(hud: Node) -> void:
	for frame_index in 120:
		await process_frame
		if hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
	for frame_index in 30:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FOUT ") + what)
	if not ok:
		_problems.append(what)
