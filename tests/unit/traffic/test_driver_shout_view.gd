extends RefCounted
## Unit tests of the balloon and the babble of a shout in the street
## (scripts/vehicles/driver_shout_view.gd).
##   tests/run_unit_tests.sh driver_shout_view

const DriverShoutView = preload("res://scripts/vehicles/driver_shout_view.gd")
const SpeechBalloon = preload("res://scripts/ui/widgets/speech_balloon.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Stands in for the sound of the world (RuimtelijkGeluid): keeps what it was asked to play.
class FakeSound:
	extends Node
	var played: Array = []

	func play_signal(at: Vector3, sound_name: String, reach: float) -> void:
		played.append([at, sound_name, reach])


## A small world: a camera and a speaker in view.
func _world() -> Node3D:
	var world := Node3D.new()
	tree.root.add_child(world)
	var camera := Camera3D.new()
	camera.name = "Camera"
	world.add_child(camera)
	camera.position = Vector3(0.0, 4.0, 14.0)
	var speaker := Node3D.new()
	speaker.name = "Spreker"
	world.add_child(speaker)
	return world


func test_the_layer_of_the_balloons(test) -> void:
	var world := _world()
	var layer := DriverShoutView.build_layer(world)
	test.check(layer.get_parent() == world and layer.name == "Toeterballonnen", "de laag hangt onder wat hem krijgt")
	test.check(layer.layer == DriverShoutView.BALLOON_LAYER and layer.get_child_count() == 0, "onder de HUD, nog leeg")
	world.free()


func test_a_balloon_over_the_speaker(test) -> void:
	var world := _world()
	var speaker: Node3D = world.get_node("Spreker")
	var layer := DriverShoutView.build_layer(world)
	var balloon := DriverShoutView.build_balloon(layer, speaker, world.get_node("Camera"), 1.9)
	test.check(balloon.get_parent() == layer and balloon.name == "Toeterballon", "de ballon staat op de laag")
	test.check(balloon.accent == DriverShoutView.DRIVER_ACCENT and DriverShoutView.DRIVER_ACCENT == UiStyle.ACCENT, "in de accentkleur van de UI")
	test.check(balloon.head_height == 1.9 and not balloon.is_talking(), "boven het dak, nog stil")
	DriverShoutView.show_line(balloon, "Uit de weg!")
	test.check(balloon.is_talking() and balloon.visible, "hij zegt de regel")
	test.check(balloon._hold == DriverShoutView.HOLD_SECONDS, "en houdt hem zo lang vast")
	balloon.finished.emit()
	test.check(balloon.is_queued_for_deletion(), "uitgepraat: weg")
	world.free()


func test_the_balloon_goes_with_the_speaker(test) -> void:
	var world := _world()
	var speaker: Node3D = world.get_node("Spreker")
	var layer := DriverShoutView.build_layer(world)
	var balloon := DriverShoutView.build_balloon(layer, speaker, world.get_node("Camera"), 2.2)
	DriverShoutView.show_line(balloon, "Doorlopen!")
	world.remove_child(speaker)
	test.check(balloon.is_queued_for_deletion(), "de spreker weg: de ballon ook")
	speaker.free()
	world.free()


func test_the_babble_sounds_at_the_speaker(test) -> void:
	var sound := FakeSound.new()
	sound.name = "RuimtelijkGeluid"
	var had_sound := tree.root.get_node_or_null("RuimtelijkGeluid") != null
	if had_sound:
		test.check(true, "het geluid van de wereld is er al: niet nagespeeld")
		sound.free()
		return
	tree.root.add_child(sound)
	DriverShoutView.play_babble(tree, Vector3(1.0, 2.0, 3.0), "vrouw", "boos", "Uit de weg!")
	test.check(sound.played.size() == 1, "één keer gebrabbeld")
	test.check(sound.played[0][0] == Vector3(1.0, 2.0, 3.0), "op de plek van de spreker")
	test.check(String(sound.played[0][1]).contains("vrouw"), "in haar stem (%s)" % sound.played[0][1])
	tree.root.remove_child(sound)
	sound.free()
	DriverShoutView.play_babble(tree, Vector3.ZERO, "man", "boos", "Hé!")
	test.check(tree.root.get_node_or_null("RuimtelijkGeluid") == null, "zonder geluid van de wereld gebeurt er niets")
