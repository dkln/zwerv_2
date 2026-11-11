extends SceneTree
## Run over and killed (PlayerController._slow_motion_death): the game slows down to
## DEATH_SLOW_MOTION (the physics stepping as often in real time), the follow camera zooms in
## on the player, and after DEATH_SLOW_SECONDS the speed comes back and the death screen is up.
## Another death (hunger) is not slowed down.
## usage: tools/godot.sh --headless --script tools/check/death_slowmo_test.gd

const Common = preload("res://tools/tool_common.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")

var _problems: Array[String] = []


func _init() -> void:
	Common.watchdog(self, 200)
	PlayerCharacter.choose("jos")
	var scene := Common.instantiate(Common.CITY, false)
	for node_name in ["DetailNiveau", "Rook", "Verhaal"]:
		if scene.has_node(node_name):
			scene.get_node(node_name).free()
	scene.get_node("Verkeer").vehicle_count = 0
	get_root().add_child(scene)
	var player: Node3D = scene.get_node("Speler")
	var camera: Node = scene.get_node("Volgcamera")
	var hud: Node = scene.get_node("HUD")
	for frame_index in 240:
		await physics_frame
		if player._placed:
			break
	while camera.is_arriving():   # first down from the sky
		await process_frame
	var ticks_before := Engine.physics_ticks_per_second
	var zoom_before: float = camera._zoom
	player._hurt(10000.0, "aangereden")
	await process_frame
	_check(player.is_dead(), "dood na de aanrijding")
	_check(absf(Engine.time_scale - PlayerControllerScript.DEATH_SLOW_MOTION) < 0.01, "slow motion (%.2f)" % Engine.time_scale)
	_check(Engine.physics_ticks_per_second > ticks_before * 5, "physics stapt even vaak in echte tijd (%d per spelseconde)" % Engine.physics_ticks_per_second)
	_check(camera.is_dramatic(), "de camera zoomt in")
	_check(not hud._death_layer.visible, "nog geen doodsscherm tijdens de slow motion")
	# the figure does not blink while it dies: always visible through the slow motion
	var blinked := false
	for wait in 24:
		await create_timer(0.05, true, false, true).timeout
		if not player._model.visible or player._blink_left > 0.0:
			blinked = true
	_check(not blinked, "geen geknipper tijdens het dramatisch doodgaan")
	_check(camera._zoom < zoom_before * 0.5, "ingezoomd op de speler (%.1f m in beeld, was %.1f)" % [camera._zoom, zoom_before])
	await create_timer(PlayerControllerScript.DEATH_SLOW_SECONDS + PlayerControllerScript.DEATH_SPEED_UP, true, false, true).timeout
	await process_frame
	_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == ticks_before, "daarna weer op normale snelheid")
	_check(hud._death_layer.visible, "dan het doodsscherm")
	print("slow motion ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
