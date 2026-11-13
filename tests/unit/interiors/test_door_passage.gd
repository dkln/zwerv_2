extends RefCounted
## Unit tests of walking in and out of a building seen from close by
## (scripts/world/interiors/door_passage.gd): a stand-in of the player walks through the door while
## the real one is hidden and stands still, a camera of its own, the door of the place
## opening for them (sliding, swinging or revolving), and all as it was afterwards.

const DoorPassage = preload("res://scripts/world/interiors/door_passage.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A passage begun by hand (not awaited), so the test can step it.
func _passage(player: Node3D, kind: String, going_in: bool) -> Node3D:
	var passage: Node3D = DoorPassage.new()
	tree.root.add_child(passage)
	passage._begin(player, Vector3(10.0, 0.0, 5.0), Vector3(0.0, 0.0, 1.0), kind, going_in)
	return passage


## Going in: the stand-in walks from the street through the door, which opens on the way
## and shuts behind; the real player hidden and still meanwhile, back after, the camera too.
func test_walking_in_through_a_sliding_door(test) -> void:
	var player := Node3D.new()
	tree.root.add_child(player)
	player.set_physics_process(true)   # as the real player: moving until the passage holds it
	var game_camera := Camera3D.new()
	tree.root.add_child(game_camera)
	game_camera.make_current()
	var passage := _passage(player, "schuif", true)
	var parts: Dictionary = passage.parts()
	test.check(not player.visible and not player.is_physics_processing(), "de echte speler is weg en staat stil")
	test.check((parts.camera as Camera3D).is_current() and (parts.leaves as Array).size() == 2, "een eigen camera, twee schuifdeuren")
	var start_z: float = (parts.stand_in as Node3D).position.z
	var widest := 0.0
	var ended := [false]
	passage.finished.connect(func() -> void: ended[0] = true)
	for step in 200:
		if ended[0]:
			break
		passage._process(0.05)
		widest = maxf(widest, float(passage.parts().open))
	test.check(start_z > 2.0, "begint op de stoep voor de deur (%.1f m)" % start_z)
	test.check(widest >= 0.99, "de deur gaat helemaal open (%.2f)" % widest)
	test.check(ended[0], "door de deur: klaar")
	test.check(player.visible and player.is_physics_processing() and game_camera.is_current(), "daarna alles als voorheen")
	passage.free()
	player.free()
	game_camera.free()


## Every kind of door, in and out: a swinging door turns on its hinge, a revolving one
## turns with the walker, and going out starts inside and ends on the pavement.
func test_every_kind_of_door_both_ways(test) -> void:
	for kind: String in DoorPassage.KINDS:
		var player := Node3D.new()
		tree.root.add_child(player)
		var passage := _passage(player, kind, false)
		var stand_in: Node3D = passage.parts().stand_in
		test.check(stand_in.position.z < 0.0, "%s, naar buiten: begint binnen" % kind)
		var turned := 0.0
		for step in 200:
			passage._process(0.05)
			turned = maxf(turned, absf((passage.parts().leaves[0] as Node3D).rotation.y))
			if not is_instance_valid(stand_in) or stand_in.is_queued_for_deletion():
				break
		test.check(player.visible, "%s: de speler staat weer buiten" % kind)
		if kind != "schuif":
			test.check(turned > 0.5, "%s: de deur draait (%.1f rad)" % [kind, turned])
		passage.free()
		player.free()
	test.check(DoorPassage.seconds_of() < 2.0, "het duurt kort (%.1f s)" % DoorPassage.seconds_of())
