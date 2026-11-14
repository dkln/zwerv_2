extends RefCounted
## Unit tests of the body someone knocked over becomes (scripts/world/people/knock_down.gd).
##   tests/run_unit_tests.sh test_knock_down

const KnockDown = preload("res://scripts/world/people/knock_down.gd")
const KnockDownRules = preload("res://scripts/world/people/knock_down_rules.gd")

var tree: SceneTree


func _thrown(push: Vector3, impact: float, dive := false, mask := -1) -> RigidBody3D:
	var parent := Node3D.new()
	tree.root.add_child(parent)
	var shape := BoxShape3D.new()
	var random := RandomNumberGenerator.new()
	random.seed = 4
	return KnockDown.throw(parent, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 2.0)), shape, Vector3(0.0, 0.9, 0.0), 70.0,
		push, impact, random, 1.0, 2.0, mask, dive)


func test_throw_makes_a_body_with_the_shape(test) -> void:
	var body := _thrown(Vector3(4.0, 0.0, 0.0), 10.0)
	test.check(body.name == "Valpartij" and body.mass == 70.0 and body.continuous_cd, "een lichaam van die massa")
	var collision := body.get_child(0) as CollisionShape3D
	test.check(collision != null and collision.shape is BoxShape3D and collision.position == Vector3(0.0, 0.9, 0.0), "met de botsvorm op zijn plek")
	test.check(body.physics_material_override.friction == KnockDown.FRICTION and body.physics_material_override.bounce == KnockDown.BOUNCE, "stroef en een beetje verend")
	test.check(body.global_position.is_equal_approx(Vector3(1.0, KnockDownRules.START_LIFT, 2.0)), "net boven de grond")
	test.check(body.linear_velocity.is_equal_approx(KnockDownRules.thrown_velocity(Vector3(4.0, 0.0, 0.0), 1.0, 10.0)), "weggegooid met de duw")
	test.check(absf(body.angular_velocity.z) > 5.0 and absf(body.angular_velocity.y) <= KnockDownRules.MOST_TWIST, "tuimelend, en wat om zijn as")
	body.get_parent().free()


func test_the_same_seed_throws_the_same(test) -> void:
	var first := _thrown(Vector3(0.0, 0.0, 3.0), 6.0)
	var second := _thrown(Vector3(0.0, 0.0, 3.0), 6.0)
	test.check(first.angular_velocity == second.angular_velocity, "hetzelfde zaadje: dezelfde tuimeling")
	first.get_parent().free()
	second.get_parent().free()


func test_a_mask_and_a_dive(test) -> void:
	var masked := _thrown(Vector3(2.0, 0.0, 0.0), 5.0, false, 1)
	test.check(masked.collision_layer == 0 and masked.collision_mask == 1, "met een masker: alleen tegen die laag")
	masked.get_parent().free()
	var diver := _thrown(Vector3(0.0, 0.0, 5.0), 5.0, true)
	test.check(is_equal_approx(diver.global_position.y, KnockDownRules.DIVE_LIFT), "een duik begint hoog")
	test.check(is_equal_approx(diver.linear_velocity.y, KnockDownRules.DIVE_UP) and is_equal_approx(diver.linear_velocity.z, 5.0), "en vliegt vooruit")
	test.check((diver.global_basis * Vector3.UP).dot(Vector3.BACK) > 0.9, "plat, hoofd vooruit")
	diver.get_parent().free()
