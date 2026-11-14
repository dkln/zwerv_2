extends RefCounted
## Unit tests of the body of someone knocked over (scripts/world/people/knock_down_body.gd): a
## hard blow throws shards and tells, a soft one or one right after another does not.
##   tests/run_unit_tests.sh knock_down_body

const KnockDownBody = preload("res://scripts/world/people/knock_down_body.gd")

var tree: SceneTree


func test_only_hard_blows_count(test) -> void:
	var parent := Node3D.new()
	tree.root.add_child(parent)
	var body: RigidBody3D = KnockDownBody.new()
	body.freeze = true
	parent.add_child(body)
	test.check(body.contact_monitor and body.max_contacts_reported == 4, "het meldt wat het raakt")
	var blows: Array[float] = []
	body.hit_hard.connect(func(speed: float) -> void: blows.append(speed))
	body._speed_before = 1.0
	body._on_hit(null)
	test.check(blows.is_empty() and parent.get_child_count() == 1, "een zachte tik: niets")
	body._speed_before = 8.0
	body._on_hit(null)
	test.check(blows == [8.0] and parent.get_child_count() == 2, "een harde klap: scherven en een signaal")
	body._on_hit(null)
	test.check(blows.size() == 1, "niet twee keer vlak na elkaar")
	body._physics_process(KnockDownBody.QUIET_SECONDS + 0.01)
	test.check(body._speed_before == 0.0, "het onthoudt de snelheid van vlak ervoor")
	body._speed_before = 5.0
	body._on_hit(null)
	test.check(blows.size() == 2, "na de pauze telt een klap weer")
	parent.free()
