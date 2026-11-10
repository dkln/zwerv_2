extends SceneTree
## How often things are updated by where they are seen (scripts/world/sight.gd): every step
## in view, fewer just out of it, fewest far away; and a vehicle and a pedestrian out of
## sight do take fewer steps (vehicle.gd, pedestrian.gd).
## usage: tools/godot.sh --headless --script tools/check/sight_test.gd

const Sight = preload("res://scripts/world/sight.gd")
const Common = preload("res://tools/tool_common.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 60)
	var camera := Camera3D.new()
	get_root().add_child(camera)
	await process_frame
	Iso.place(camera, Vector3.ZERO, 38.0)
	camera.make_current()
	await process_frame
	var viewport := get_root()
	_check(Sight.steps_between(viewport, Vector3.ZERO) == 1, "in beeld: elke stap")
	var right := camera.global_basis.x
	var just_out := Sight.steps_between(viewport, right * 70.0)
	_check(just_out == Sight.NEAR_STEPS, "net buiten beeld: om de %d stappen (%d)" % [Sight.NEAR_STEPS, just_out])
	var far := Sight.steps_between(viewport, right * 200.0)
	_check(far == Sight.FAR_STEPS, "ver weg: om de %d stappen (%d)" % [Sight.FAR_STEPS, far])
	print("zicht ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
