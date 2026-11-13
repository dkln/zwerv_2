extends RefCounted
## Unit tests of the models of the machines and finds (scripts/world/things/machine_models.gd):
## their size, and a collider as big as the mesh.

const MachineModels = preload("res://scripts/world/things/machine_models.gd")


## The cash machine is man-high and less than a metre wide.
func test_cash_machine_size(test) -> void:
	var cash := MachineModels.cash_machine_mesh().get_aabb()
	test.check(cash.size.y > 1.6 and cash.size.y < 1.9 and cash.size.x < 1.0, "geldautomaat %s" % cash.size)


## The deposit machine is exactly as big as the supermarket layout takes it to be.
func test_deposit_machine_size_as_in_the_layout(test) -> void:
	var deposit := MachineModels.deposit_machine_mesh().get_aabb()
	test.check((deposit.size - Vector3(0.875, 1.875, 0.625)).length() < 0.001, "statiegeldautomaat zo groot als in de indeling (%s)" % deposit.size)


## The can, the bottle and the bank card have a mesh of a sensible size; the can and the
## bottle fit through the deposit machine's hole lying down.
func test_can_and_bank_card_have_a_mesh(test) -> void:
	test.check(MachineModels.can_mesh().get_aabb().size.y > 0.1 and MachineModels.bank_card_mesh().get_aabb().size.x > 0.2, "blikje en pinpas")
	var hole := Vector2(MachineModels.HOLE_TO - MachineModels.HOLE_FROM + Vector2i.ONE) * MachineModels.MACHINE_VOXEL
	for mesh: Mesh in [MachineModels.can_mesh(), MachineModels.bottle_mesh()]:
		var box := mesh.get_aabb()
		test.check(box.size.x < hole.x and box.size.z < hole.y, "past door het gat (%s, gat %s)" % [box.size, hole])


## A machine made with MachineModels.instance gets a box collider of the size and place of its mesh.
func test_collider_as_big_as_the_mesh(test) -> void:
	var cash := MachineModels.cash_machine_mesh().get_aabb()
	var machine := MachineModels.instance(MachineModels.cash_machine_mesh(), "Test")
	var collider := machine.get_node("Botsvorm").get_child(0) as CollisionShape3D
	test.check(((collider.shape as BoxShape3D).size).is_equal_approx(cash.size) and collider.position.is_equal_approx(cash.get_center()),
		"botsvorm zo groot als de geldautomaat")
	machine.free()
