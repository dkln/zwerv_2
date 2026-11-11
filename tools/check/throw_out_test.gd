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
	for node_name in ["DetailNiveau", "Rook", "Grassprieten"]:
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
	var flew := false
	var farthest := 0.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000 and not hud.is_showing_story():
		await process_frame
		slowest = minf(slowest, Engine.time_scale)
		if player._ragdoll != null:
			flew = true
			farthest = maxf(farthest, Vector2(player.global_position.x - bar.door.x, player.global_position.z - bar.door.z).length())
	_check(not interiors.is_inside(), "eruit gegooid: weer buiten")
	_check(flew, "de deur uit gesmeten (tuimelend)")
	_check(slowest < 0.5, "in slow motion (%.2f)" % slowest)
	_check(farthest > 1.5, "een eind de straat op (%.1f m van de deur)" % farthest)
	_check(hud.is_showing_story(), "daarna wordt gezegd waarom")
	var camera: Node = scene.get_node("Volgcamera")
	_check(is_equal_approx(Engine.time_scale, 1.0) and not camera._dramatic, "slow motion en close-up weer voorbij (%.2f)" % Engine.time_scale)
	var page: Dictionary = hud._story_box._pages[0] if hud.is_showing_story() else {}
	print("  %s: %s" % [page.get("speaker", ""), page.get("text", "")])
	_check(page.get("kind") == "gesprek" and not page.has("choices") and str(page.get("text", "")).contains("kleingeld"),
			"een gesprek zonder keuzes, over het bedelen")
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
	_check(page.has("official") and str(page.get("speaker", "")) != "", "de conducteur zegt het, in dienst")
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
