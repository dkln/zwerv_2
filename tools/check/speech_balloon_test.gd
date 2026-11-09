extends SceneTree
## The speech balloon (scripts/ui/widgets/speech_balloon.gd) in the world, as on the street:
## it follows a node seen through a camera (the tip of its tail over the head, on the screen),
## types its line out word by word (no cursor, unlike the story box), holds, fades and fires `finished`;
## behind the camera it does not show.
## usage: tools/godot.sh --headless --script tools/check/speech_balloon_test.gd

const Common = preload("res://tools/tool_common.gd")
const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 60)
	var world := Node3D.new()
	get_root().add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 2.0, 8.0)
	var speaker := Node3D.new()
	world.add_child(speaker)
	var layer := CanvasLayer.new()
	get_root().add_child(layer)
	var balloon := SpeechBalloon.new()
	layer.add_child(balloon)
	balloon.follow(speaker, camera)
	var done := [false]
	balloon.finished.connect(func() -> void: done[0] = true)
	await process_frame
	balloon.say("Hé zwerver, heb je een euro voor me?", 0.3)
	await create_timer(0.2).timeout
	var typewriter: RefCounted = balloon._typewriter
	_check(not typewriter.is_done() and typewriter._words_shown > 0, "typt woord voor woord")
	_check(not balloon._text.text.contains("[bgcolor="), "geen cursor in de ballon")
	var expected := camera.unproject_position(speaker.global_position + Vector3.UP * balloon.head_height)
	_check(balloon.position.distance_to(expected.round()) < 1.0, "staat boven het hoofd (%s)" % balloon.position)
	_check(balloon._panel.position.y + balloon._panel.size.y <= 0.0, "ballon boven de punt")
	for frame_index in 600:
		await process_frame
		if done[0]:
			break
	_check(done[0] and not balloon.visible, "verdwijnt na het vasthouden")
	camera.position = Vector3(0.0, 2.0, -8.0)
	camera.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	balloon.say("Achter je!", 0.3)
	await process_frame
	await process_frame
	camera.rotation_degrees = Vector3.ZERO
	await process_frame
	_check(balloon.modulate.a == 0.0, "niet te zien achter de camera")
	print("tekstballon ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
