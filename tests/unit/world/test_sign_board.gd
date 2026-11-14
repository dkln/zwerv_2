extends RefCounted
## Unit tests of the boards with a text (scripts/world/things/sign_board.gd).
##   tests/run_unit_tests.sh sign_board

const SignBoard = preload("res://scripts/world/things/sign_board.gd")
const SignBoardLayout = preload("res://scripts/world/things/sign_board_layout.gd")


func test_create_builds_a_plate_with_the_text_on_both_sides(test) -> void:
	var board := SignBoard.create("DRANKEN", Color("#DE1828"), Color.WHITE)
	var plate := board.get_node("Plaat") as MeshInstance3D
	var front := board.get_node("Tekst") as Label3D
	var back := board.get_node("TekstAchter") as Label3D
	test.check(board.name == "Bord" and plate != null and front != null and back != null, "plaat, tekst voor en achter")
	test.check((plate.mesh as BoxMesh).size.is_equal_approx(SignBoardLayout.plate_size(7, SignBoardLayout.LETTER)), "de plaat zo groot als de tekst vraagt")
	test.check(((plate.mesh as BoxMesh).material as StandardMaterial3D).albedo_color == Color("#DE1828"), "in de kleur van de plaat")
	test.check(front.text == "DRANKEN" and back.text == "DRANKEN" and front.modulate == Color.WHITE, "de tekst in de inkt")
	test.check(front.position.z > 0.0 and back.position.z < 0.0 and is_equal_approx(back.rotation.y, PI), "voor en achter op de plaat")
	test.check(is_equal_approx(front.pixel_size, SignBoardLayout.LETTER / 64.0) and front.font_size == 64, "de letters op maat")
	board.free()


func test_create_one_sided_with_own_letter_and_width(test) -> void:
	var board := SignBoard.create("3", Color.BLACK, Color.YELLOW, 0.4, false, 1.5)
	test.check(board.get_node_or_null("TekstAchter") == null, "alleen de voorkant")
	test.check(is_equal_approx(((board.get_node("Plaat") as MeshInstance3D).mesh as BoxMesh).size.x, 1.5), "de vaste breedte")
	test.check(is_equal_approx((board.get_node("Tekst") as Label3D).pixel_size, 0.4 / 64.0), "de eigen lettermaat")
	board.free()


func test_set_text_changes_both_sides(test) -> void:
	var board := SignBoard.create("1", Color.BLACK, Color.WHITE)
	SignBoard.set_text(board, "2")
	test.check((board.get_node("Tekst") as Label3D).text == "2" and (board.get_node("TekstAchter") as Label3D).text == "2", "beide kanten")
	var one_sided := SignBoard.create("1", Color.BLACK, Color.WHITE, 0.0, false)
	SignBoard.set_text(one_sided, "5")
	test.check((one_sided.get_node("Tekst") as Label3D).text == "5", "ook met alleen een voorkant")
	board.free()
	one_sided.free()
