extends "res://tests/integration/support/town_test.gd"
## How often things are updated by where they are seen (scripts/world/town/sight.gd): every step
## in view, fewer just out of it, fewest far away. Without the town: only a camera.
##   tests/run_integration_tests.sh sight

const Sight = preload("res://scripts/world/town/sight.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")


static func world_options() -> Dictionary:
	return {"town": false}


## A camera in the iso view round the origin, 38 m in view; returned once it is the current one.
func _camera_at_origin() -> Camera3D:
	var camera := Camera3D.new()
	add_to_root(camera)
	await frames(1)
	Iso.place(camera, Vector3.ZERO, 38.0)
	camera.make_current()
	await frames(1)
	return camera


## What is in view is updated every step.
func test_in_view_every_step(test) -> void:
	await _camera_at_origin()
	test.check(Sight.steps_between(tree.root, Vector3.ZERO) == 1, "in beeld: elke stap")


## What is just out of view is updated every NEAR_STEPS steps.
func test_just_out_of_view_fewer_steps(test) -> void:
	var camera := await _camera_at_origin()
	var just_out := Sight.steps_between(tree.root, camera.global_basis.x * 70.0)
	test.check(just_out == Sight.NEAR_STEPS, "net buiten beeld: om de %d stappen (%d)" % [Sight.NEAR_STEPS, just_out])


## What is far out of view is updated every FAR_STEPS steps.
func test_far_away_fewest_steps(test) -> void:
	var camera := await _camera_at_origin()
	var far := Sight.steps_between(tree.root, camera.global_basis.x * 200.0)
	test.check(far == Sight.FAR_STEPS, "ver weg: om de %d stappen (%d)" % [Sight.FAR_STEPS, far])
