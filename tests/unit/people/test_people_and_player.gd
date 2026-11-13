extends RefCounted
## Unit tests of small rules of the people (scripts/world/pedestrian.gd) and the player
## (scripts/player/player_controller.gd): the look of a pedestrian's figure (its own, or one of
## its seed, as MobilityAid picks one for a rider), and the player's collider with room for the
## idle movement of the figure.


## A pedestrian given a look of its own keeps it, on foot and in a wheelchair.
func test_a_wanted_look_is_kept(test) -> void:
	var look := {"skin": Color.WHITE, "coat": Color.RED}
	test.check(Pedestrian._look_for(5, look, "") == look, "de eigen look, te voet")
	test.check(Pedestrian._look_for(5, look, "rolstoel") == look, "en in een rolstoel")


## Without a wanted look it follows from the seed (on a mobility aid: the seed as
## MobilityAid picks the rider), the same every time.
func test_a_look_from_the_seed(test) -> void:
	test.check(Pedestrian._look_for(7, {}, "") == TownsfolkFigure.look_for(7), "te voet: de look van het zaadje")
	test.check(Pedestrian._look_for(7, {}, "scootmobiel") == TownsfolkFigure.look_for(7 * 13 + 7),
		"op een hulpmiddel: zoals MobilityAid de berijder kiest")
	test.check(Pedestrian._look_for(7, {}, "") == Pedestrian._look_for(7, {}, ""), "altijd dezelfde")


## The player's collider lies round the idle figure, feet on the ground, with room in
## front for the arms, and is not much bigger than that.
func test_the_player_collider_has_room_to_move(test) -> void:
	var rest := AABB(Vector3(-0.3, 0.0, -0.25), Vector3(0.6, 1.75, 0.45))
	var collider := PlayerController._with_pose_room(rest)
	test.check(collider.encloses(rest), "om de figuur in rust heen")
	test.check(is_equal_approx(collider.position.y, 0.0), "de voeten op de grond")
	test.check(collider.end.z - rest.end.z >= 0.08, "naar voren ruimte voor de armen (%.2f m)" % (collider.end.z - rest.end.z))
	test.check(collider.size.x - rest.size.x <= 0.1 and collider.size.z - rest.size.z <= 0.15, "niet veel groter")
