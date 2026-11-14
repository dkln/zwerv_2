extends RefCounted
## Unit tests of the arrow over something you can use (scripts/world/things/interaction_mark.gd):
## it shows only with a player near and bobs between its bottom and top.
##   tests/run_unit_tests.sh interaction_mark

const InteractionMark = preload("res://scripts/world/things/interaction_mark.gd")

var tree: SceneTree


func test_create_sets_the_heights_and_the_picture(test) -> void:
	var mark := InteractionMark.create(1.5, 2.5, false)
	test.check(mark.name == "Aanwijzer" and mark.bottom == 1.5 and mark.top == 2.5, "naam en hoogtes")
	test.check(mark.view != null and mark.view.get_parent() == mark and not mark.view.is_shown(), "met zijn beeld, nog niet te zien")
	test.check(InteractionMark.MARK_FROM == 22.0, "vanaf 22 meter")
	mark.free()


func test_follow_shows_it_only_near_the_player(test) -> void:
	var mark := InteractionMark.create(1.5, 2.5)
	var player := Node3D.new()
	tree.root.add_child(mark)
	tree.root.add_child(player)
	player.global_position = Vector3(5.0, 0.0, 0.0)
	mark.follow(player)
	test.check(mark.view.is_shown(), "de speler dichtbij: te zien")
	test.check(mark.view.height() >= 1.5 - 0.001 and mark.view.height() <= 2.5 + 0.001, "tussen onder en boven (%s)" % mark.view.height())
	mark.follow(player, false)
	test.check(not mark.view.is_shown(), "niet toegestaan: weg")
	player.global_position = Vector3(40.0, 0.0, 0.0)
	mark.follow(player)
	test.check(not mark.view.is_shown(), "te ver: weg")
	mark.follow(null)
	test.check(not mark.view.is_shown(), "geen speler: weg")
	mark.free()
	player.free()


func test_follow_outside_the_tree_hides_it(test) -> void:
	var mark := InteractionMark.create(1.5, 2.5)
	var player := Node3D.new()
	mark.follow(player)
	test.check(not mark.view.is_shown(), "niet in de wereld: niet te zien")
	mark.free()
	player.free()
