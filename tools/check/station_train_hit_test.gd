extends SceneTree
## A train in Den Haag Centraal runs into who is on its track (StationTrain._hit_who_is_in_the_way),
## as a vehicle in the town does (hit_by_moving): the player on the rails is knocked over and
## hurt, a traveller fallen onto the rails too (a ragdoll, then taken away); someone on the
## platform beside it is left alone.
## usage: tools/godot.sh --headless --script tools/check/station_train_hit_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

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
	for frame_index in 600:
		await physics_frame
		if player._placed and not player._sleeping:
			break
	player._wake_up()
	# the prologue in the story box out of the way (it pauses the game)
	var hud: Node = scene.get_node("HUD")
	for frame_index in 120:
		await process_frame
		if hud._story_box.is_showing():
			hud._story_box._pages = hud._story_box._pages.slice(-1)
			hud._story_box._page_index = 0
			hud._story_box._next_page()
	for frame_index in 30:
		await process_frame
	var interiors: Node = scene.get_node("Binnenruimtes")
	var way: Dictionary = interiors.ways_in().filter(func(w: Dictionary) -> bool: return w.kind == "centraal")[0]
	await interiors.enter(way)
	for frame_index in 60:
		await process_frame
	var station: Node3D = interiors.interior_of("centraal")
	# a train made to come in on its track
	var train: StationTrain = null
	for frame_index in 300:
		await process_frame
		if not station.trains().is_empty():
			break
	if not station.trains().is_empty():
		train = station.trains()[0]
		train.state = "weg"
		train.come_in()
	_check(train != null, "een trein komt binnen")
	if train == null:
		_finish()
		return
	# the player and a traveller on the rails before its nose, someone on the platform beside it
	var ahead := StationTrain.Layout.STOP_NOSE_Z + 6.0
	player.teleport(train.to_global(Vector3(0.0, 0.0, ahead)), 0.0)
	var on_rails: StationPerson = station.call("_spawn", "reiziger", station.to_local(train.to_global(Vector3(0.4, 0.0, ahead - 3.0))))
	on_rails.steps.clear()
	var on_platform: StationPerson = station.call("_spawn", "reiziger", station.to_local(train.to_global(Vector3(train._width * 0.5 + 1.2, 1.375, ahead))))
	on_platform.steps.clear()
	var health_before: float = player._stats.gezondheid.x
	var player_hit := false
	var traveller_hit := false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000 and not (player_hit and traveller_hit):
		await physics_frame
		player_hit = player_hit or player._ragdoll != null
		traveller_hit = traveller_hit or (is_instance_valid(on_rails) and on_rails._ragdoll != null)
	_check(player_hit, "de speler op het spoor wordt aangereden")
	var health_after: float = player._stats.gezondheid.x
	_check(health_after < health_before, "en raakt gewond (%.0f naar %.0f)" % [health_before, health_after])
	_check(traveller_hit, "een reiziger op het spoor ook")
	_check(is_instance_valid(on_platform) and on_platform._ragdoll == null, "wie op het perron staat niet")
	_finish()


func _finish() -> void:
	print("trein in het station ok" if _problems.is_empty() else "%d problemen: %s" % [_problems.size(), _problems])
	quit(0 if _problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FOUT ") + what)
	if not ok:
		_problems.append(what)
