extends RefCounted
## Unit tests of the things used with [E] (scripts/world/things/interactable.gd).
##   tests/run_unit_tests.sh interactable

const Interactable = preload("res://scripts/world/things/interactable.gd")

var tree: SceneTree
var _used := 0


func _use() -> void:
	_used += 1


func test_make_sets_what_it_is_and_does(test) -> void:
	var spot := Interactable.make("Kassa1", Vector3(1.0, 0.0, 2.0), Interactable.KIND_SPOT, "Afrekenen", _use, 2.0)
	test.check(spot.name == "Kassa1" and spot.position == Vector3(1.0, 0.0, 2.0) and spot.kind == Interactable.KIND_SPOT, "naam, plek en soort")
	test.check(spot.action_text() == "Afrekenen" and spot.reach() == 2.0, "tekst en bereik")
	test.check(spot.is_in_group(Interactable.USE_GROUP), "in de groep waar de speler in zoekt")
	spot.go_through()
	test.check(_used == 1, "E doet wat is opgegeven")
	spot.free()


func test_defaults_and_changing_text(test) -> void:
	var spot := Interactable.make("Plek", Vector3.ZERO, Interactable.KIND_GATE, "Inchecken", Callable())
	test.check(spot.reach() == Interactable.REACH, "het standaardbereik")
	spot.go_through()
	test.check(_used == 0, "zonder actie gebeurt er niets")
	spot.text_of = func() -> String: return "Uitchecken"
	test.check(spot.action_text() == "Uitchecken", "een tekst die meeverandert gaat voor")
	spot.free()


func test_make_usable_adds_to_the_group(test) -> void:
	var loose: Node3D = Interactable.new()
	test.check(not loose.is_in_group(Interactable.USE_GROUP), "eerst niet")
	loose.make_usable()
	test.check(loose.is_in_group(Interactable.USE_GROUP), "daarna wel")
	test.check(Interactable.KINDS.size() == 5 and Interactable.KINDS.has(Interactable.KIND_PICKUP), "vijf soorten")
	loose.free()


func test_all_by_kind_sorts_what_is_in_the_tree(test) -> void:
	var holder := Node3D.new()
	tree.root.add_child(holder)
	holder.add_child(Interactable.make("Deur", Vector3.ZERO, Interactable.KIND_DOOR, "Naar binnen", Callable()))
	holder.add_child(Interactable.make("Pin", Vector3.ZERO, Interactable.KIND_MACHINE, "Pinnen", Callable()))
	holder.add_child(Interactable.make("Pin2", Vector3.ZERO, Interactable.KIND_MACHINE, "Pinnen", Callable()))
	var plain := Node3D.new()   # not an Interactable: counts as a spot
	plain.name = "DingenTestLos"
	plain.add_to_group(Interactable.USE_GROUP)
	holder.add_child(plain)
	var found := Interactable.all_by_kind(tree)
	test.check((found.get(Interactable.KIND_MACHINE, []) as Array).filter(func(node: Node) -> bool: return holder.is_ancestor_of(node)).size() == 2, "twee automaten")
	test.check((found.get(Interactable.KIND_DOOR, []) as Array).any(func(node: Node) -> bool: return node.name == "Deur"), "een deur")
	test.check((found.get(Interactable.KIND_SPOT, []) as Array).has(plain), "iets zonder soort telt als plek")
	holder.free()
