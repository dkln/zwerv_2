extends RefCounted
## Unit tests of how often something is updated by where the camera sees it
## (scripts/world/town/sight.gd): every step without a camera and in sight, less often out
## of sight, least often far away. The arithmetic: test_sight_rules.gd.

const Sight = preload("res://scripts/world/town/sight.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A viewport of its own with a camera at 20 m height looking straight down at the origin.
func _viewport(perspective: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 400)
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective else Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	viewport.add_child(camera)
	camera.global_position = Vector3(0.0, 20.0, 0.0)
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.current = true
	return viewport


## Without a viewport or a camera (the tools): every step.
func test_every_step_without_a_camera(test) -> void:
	test.check(Sight.steps_between(null, Vector3.ZERO) == 1, "zonder viewport: elke stap")
	var viewport := SubViewport.new()
	tree.root.add_child(viewport)
	test.check(Sight.steps_between(viewport, Vector3.ZERO) == 1, "zonder camera: elke stap")
	viewport.free()


## In the picture every step, beside it less often, far from the focus least often.
func test_in_sight_near_and_far(test) -> void:
	var viewport := _viewport(false)
	test.check(Sight.steps_between(viewport, Vector3.ZERO) == 1, "in beeld: elke stap")
	var beside := Sight.steps_between(viewport, Vector3(60.0, 0.0, 0.0))
	test.check(beside == Sight.NEAR_STEPS, "naast het beeld: om de %d stappen (%d)" % [Sight.NEAR_STEPS, beside])
	var far := Sight.steps_between(viewport, Vector3(Sight.FAR_METRES + 50.0, 0.0, 0.0))
	test.check(far == Sight.FAR_STEPS, "ver weg: om de %d stappen (%d)" % [Sight.FAR_STEPS, far])
	viewport.free()


## A perspective camera: what is further than FARTHEST_METRES from it is far, even in the picture.
func test_too_far_from_a_perspective_camera(test) -> void:
	var viewport := _viewport(true)
	test.check(Sight.steps_between(viewport, Vector3.ZERO) == 1, "in beeld en dichtbij: elke stap")
	var deep := Sight.steps_between(viewport, Vector3(0.0, -Sight.FARTHEST_METRES, 0.0))
	test.check(deep == Sight.FAR_STEPS, "in beeld maar te ver: om de %d stappen (%d)" % [Sight.FAR_STEPS, deep])
	viewport.free()
