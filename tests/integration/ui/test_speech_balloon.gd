extends "res://tests/integration/support/town_test.gd"
## The speech balloon (scripts/ui/widgets/speech_balloon.gd) in the world, as on the street:
## it follows a node seen through a camera (the tip of its tail over the head, on the screen),
## types its line out word by word (no cursor, unlike the story box), holds, fades and fires `finished`;
## behind the camera it does not show. Without the town: a camera, a speaker and the balloon.
##   tests/run_integration_tests.sh speech_balloon

const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")

## The camera, who speaks and the balloon over them, built by _build_street.
var camera: Camera3D
var speaker: Node3D
var balloon: SpeechBalloon


static func world_options() -> Dictionary:
	return {"town": false}


## A camera looking at a speaker 8 m away, with a balloon that follows the speaker.
func _build_street() -> void:
	var world := Node3D.new()
	add_to_root(world)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.0, 2.0, 8.0)
	speaker = Node3D.new()
	world.add_child(speaker)
	var layer := CanvasLayer.new()
	add_to_root(layer)
	balloon = SpeechBalloon.new()
	layer.add_child(balloon)
	balloon.follow(speaker, camera)
	await frames(1)


## A line is typed out word by word, without the cursor of the story box.
func test_types_word_by_word_without_a_cursor(test) -> void:
	await _build_street()
	balloon.say("Hé zwerver, heb je een euro voor me?", 0.3)
	await seconds(0.2)
	var typewriter: RefCounted = balloon._typewriter
	test.check(not typewriter.is_done() and typewriter._words_shown > 0, "typt woord voor woord")
	test.check(not balloon._text.text.contains("[bgcolor="), "geen cursor in de ballon")


## The tip of the tail stands over the speaker's head on the screen, the balloon above it.
func test_stands_over_the_head(test) -> void:
	await _build_street()
	balloon.say("Hé zwerver, heb je een euro voor me?", 0.3)
	await seconds(0.2)
	var expected := camera.unproject_position(speaker.global_position + Vector3.UP * balloon.head_height)
	test.check(balloon.position.distance_to(expected.round()) < 1.0, "staat boven het hoofd (%s)" % balloon.position)
	test.check(balloon._panel.position.y + balloon._panel.size.y <= 0.0, "ballon boven de punt")


## After the line and its hold the balloon fades, hides and fires `finished`.
func test_disappears_after_the_hold(test) -> void:
	await _build_street()
	var done := [false]
	balloon.finished.connect(func() -> void: done[0] = true)
	balloon.say("Hé zwerver, heb je een euro voor me?", 0.3)
	await wait_until(func() -> bool: return done[0], 10.0)
	test.check(done[0] and not balloon.visible, "verdwijnt na het vasthouden")


## With the speaker behind the camera the balloon is not to be seen.
func test_not_shown_behind_the_camera(test) -> void:
	await _build_street()
	camera.position = Vector3(0.0, 2.0, -8.0)
	camera.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	balloon.say("Achter je!", 0.3)
	await frames(2)
	camera.rotation_degrees = Vector3.ZERO
	await frames(1)
	test.check(balloon.modulate.a == 0.0, "niet te zien achter de camera")
