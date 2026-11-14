extends RefCounted
## Unit tests of the sizes of a board with a text (scripts/world/things/sign_board_layout.gd).
##   tests/run_unit_tests.sh sign_board_layout

const SignBoardLayout = preload("res://scripts/world/things/sign_board_layout.gd")


func test_letter_size(test) -> void:
	test.check(SignBoardLayout.letter_size(0.0) == SignBoardLayout.LETTER, "0: de standaardletter")
	test.check(SignBoardLayout.letter_size(-1.0) == SignBoardLayout.LETTER, "negatief: ook de standaard")
	test.check(SignBoardLayout.letter_size(0.3) == 0.3, "een eigen maat")


func test_plate_size_follows_the_text(test) -> void:
	var plate := SignBoardLayout.plate_size(7, 0.19)
	test.check(is_equal_approx(plate.x, 7 * 0.19 + SignBoardLayout.MARGIN * 2.0), "zo breed als de tekst plus de marges")
	test.check(is_equal_approx(plate.y, 0.19 * 1.2 + SignBoardLayout.MARGIN) and plate.z == SignBoardLayout.THICKNESS, "hoogte en dikte")
	test.check(SignBoardLayout.plate_size(7, 0.19, 3.0).x == 3.0, "een vaste breedte")
	test.check(is_equal_approx(SignBoardLayout.plate_size(0, 0.19).x, SignBoardLayout.MARGIN * 2.0), "geen tekst: alleen de marges")
	test.check(SignBoardLayout.plate_size(20, 0.19).x > SignBoardLayout.plate_size(5, 0.19).x, "meer letters: breder")


func test_sides(test) -> void:
	test.check(SignBoardLayout.sides(true) == [SignBoardLayout.FRONT, SignBoardLayout.BACK], "voor en achter")
	test.check(SignBoardLayout.sides(false) == [SignBoardLayout.FRONT], "alleen voor")


func test_text_stands_just_before_the_plate_on_each_side(test) -> void:
	var front := SignBoardLayout.text_place(SignBoardLayout.FRONT)
	var back := SignBoardLayout.text_place(SignBoardLayout.BACK)
	test.check(front.z > SignBoardLayout.THICKNESS * 0.5 and is_equal_approx(back.z, -front.z), "net voor de plaat, achter gespiegeld")
	test.check(SignBoardLayout.text_turn(SignBoardLayout.FRONT) == 0.0 and is_equal_approx(SignBoardLayout.text_turn(SignBoardLayout.BACK), PI), "de achterkant omgedraaid")
	test.check(is_equal_approx(SignBoardLayout.pixel_size(0.32), 0.005), "een pixel van de tekst")
