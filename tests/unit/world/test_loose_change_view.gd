extends RefCounted
## Unit tests of the look of a coin (scripts/world/things/loose_change_view.gd): the coin on
## its edge with its rim, the big one larger, turning, and where its value rises from.
##   tests/run_unit_tests.sh loose_change_view

const LooseChangeView = preload("res://scripts/world/things/loose_change_view.gd")

var tree: SceneTree


func test_create_builds_a_coin_on_its_edge(test) -> void:
	var coin := LooseChangeView.create(false)
	var disc := coin.get_node("Schijf") as MeshInstance3D
	test.check(coin.name == "Munt" and disc != null, "de munt met zijn schijf")
	test.check(disc.mesh == LooseChangeView.mesh() and is_equal_approx(disc.rotation_degrees.x, 90.0), "op zijn kant")
	test.check(disc.material_overlay != null, "met de gloeiende rand van iets om op te pakken")
	test.check(disc.scale.is_equal_approx(Vector3.ONE), "een gewone munt op ware grootte")
	var big := LooseChangeView.create(true)
	test.check((big.get_node("Schijf") as Node3D).scale.is_equal_approx(Vector3.ONE * LooseChangeView.BIG_SCALE), "een euro groter")
	coin.free()
	big.free()


func test_mesh_is_one_shared_gold_coin(test) -> void:
	var mesh := LooseChangeView.mesh()
	test.check(mesh == LooseChangeView.mesh(), "één keer gemaakt")
	test.check(is_equal_approx(mesh.top_radius, LooseChangeView.RADIUS) and is_equal_approx(mesh.height, LooseChangeView.THICKNESS), "een platte schijf")
	test.check((mesh.material as StandardMaterial3D).albedo_color == LooseChangeView.COIN_GOLD, "goud")


func test_show_turn_turns_and_lifts(test) -> void:
	var coin := LooseChangeView.create(false)
	coin.show_turn(1.2, 0.4)
	test.check(is_equal_approx(coin.rotation.y, 1.2) and is_equal_approx(coin.position.y, 0.4), "gedraaid en op hoogte")
	coin.free()


func test_number_place_is_above_the_coin(test) -> void:
	test.check(LooseChangeView.number_place(Vector3(1.0, 2.0, 3.0)).is_equal_approx(Vector3(1.0, 2.0 + LooseChangeView.NUMBER_ABOVE, 3.0)), "het bedrag stijgt boven de munt op")


func test_play_chime_needs_a_node_in_the_tree(test) -> void:
	var loose := Node.new()
	var before := tree.root.get_child_count()
	LooseChangeView.play_chime(loose)
	test.check(tree.root.get_child_count() == before, "niet in de boom: geen geluid")
	loose.free()
