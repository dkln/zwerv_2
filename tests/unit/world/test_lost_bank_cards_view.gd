extends RefCounted
## Unit tests of the look of a lost bank card (scripts/world/things/lost_bank_cards_view.gd).
##   tests/run_unit_tests.sh lost_bank_cards_view

const LostBankCardsView = preload("res://scripts/world/things/lost_bank_cards_view.gd")
const MachineModels = preload("res://scripts/world/things/machine_models.gd")


func test_create_builds_a_card_with_its_outline(test) -> void:
	var card := LostBankCardsView.create()
	var model := card.get_node("Kaart") as MeshInstance3D
	test.check(card.name == "Pinpas" and model != null, "de pas met zijn model")
	test.check(model.mesh == MachineModels.bank_card_mesh(), "de pinpas van de automaatmodellen")
	test.check(model.material_overlay != null, "met de gloeiende rand")
	card.free()


func test_show_turn(test) -> void:
	var card := LostBankCardsView.create()
	card.show_turn(0.9)
	test.check(is_equal_approx(card.rotation.y, 0.9), "gedraaid")
	card.free()
