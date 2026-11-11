extends SceneTree
## The Zebraklok (scripts/world/zebra_clock.gd): a black pole with the head on it (its size),
## a flat square stood on its point (45 degrees), with straight black and white stripes and a white dial
## round the hands on both faces, its white really white (no grey shading), the hands
## turning clockwise as seen from in front of a face, pointing at the time, and its collider
## round the pole, the foot and the head.
## usage: tools/godot.sh --headless --script tools/check/zebra_clock_test.gd

const Common = preload("res://tools/tool_common.gd")
const ZebraClock = preload("res://scripts/world/zebra_clock.gd")

var _problems := []


func _init() -> void:
	Common.watchdog(self, 60)
	var clock := Node3D.new()
	clock.set_script(ZebraClock)
	get_root().add_child(clock)
	await process_frame
	var head: MeshInstance3D = clock.get_node("Kop")
	var box: AABB = head.transform * head.get_aabb()
	print("kop ", box)
	_check(absf(box.size.y - ZebraClock.HEAD_HEIGHT) < 0.25, "kop %.2f m hoog" % box.size.y)
	_check(absf(box.size.x - ZebraClock.HEAD_HEIGHT) < 0.25 and absf(box.size.z - ZebraClock.HEAD_DEPTH) < 0.2, "kop %.2f m breed, %.2f m dik" % [box.size.x, box.size.z])
	_check(box.end.y > 8.0 and box.end.y < 9.5, "klok %.2f m hoog" % box.end.y)
	# a square on its point: the corners top, bottom, left and right, not in the corners of its box
	var half := ZebraClock.HEAD_HEIGHT * 0.5
	_check(ZebraClock._in_head(0.0, half * 0.95) and ZebraClock._in_head(half * 0.95, 0.0) and not ZebraClock._in_head(half * 0.6, half * 0.6),
			"een vierkant op zijn punt (45 graden gedraaid)")
	# stripes: black and white, straight across, white on the dial
	var black := 0
	var white := 0
	var straight := true
	for step in 40:
		var up := -half + step * half / 20.0
		var row_black := ZebraClock._is_stripe(-0.9, up, false)
		if row_black != ZebraClock._is_stripe(0.9, up, false):
			straight = false
		if row_black:
			black += 1
		else:
			white += 1
	_check(black > 5 and white > 5, "zwart en wit (%d / %d)" % [black, white])
	_check(straight, "rechte strepen")
	_check(not ZebraClock._is_stripe(0.0, 0.0) and not ZebraClock._is_stripe(0.3, 0.3), "witte wijzerplaat om de wijzers")
	# white, not grey: every corner of the head pure white or the black
	var greys := 0
	var whites := 0
	var blacks := 0
	for surface in head.mesh.get_surface_count():
		for colour: Color in head.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]:
			if colour.is_equal_approx(Color.WHITE):
				whites += 1
			elif colour.v < 0.15:
				blacks += 1
			else:
				greys += 1
	print("kop: %d wit, %d zwart, %d grijs" % [whites, blacks, greys])
	_check(greys == 0 and whites > blacks and blacks > 0, "wit (niet grijs) en zwart")
	# the hands: the minute hand's tip in the direction of the minutes, on both faces
	var now := Time.get_time_dict_from_system()
	var minutes := float(now.minute) + float(now.second) / 60.0
	for face_index in 2:
		var outwards := ZebraClock.face_direction(face_index)
		var right := Vector3(outwards.z, 0.0, -outwards.x)
		var pivot: Node3D = clock._hand_pivots[face_index][1]
		var tip := pivot.global_transform * Vector3.UP - pivot.global_position
		var angle := TAU * minutes / 60.0
		var expected := right * sin(angle) + Vector3.UP * cos(angle)
		_check(tip.normalized().dot(expected) > 0.98, "grote wijzer van wijzerplaat %d wijst naar de minuten" % (face_index + 1))
		var face_middle := pivot.global_position - clock.global_position
		_check(face_middle.dot(outwards) > 0.0, "wijzers voor wijzerplaat %d" % (face_index + 1))
		# the hands stand just out of the face, not inside the head and not floating off it
		var face_at := box.get_center().z + outwards.z * box.size.z * 0.5
		var hand_front := face_middle.z + outwards.z * ZebraClock.HAND_OUT
		_check(absf(hand_front - face_at) < ZebraClock.HAND_OUT + 0.05 and (hand_front - face_at) * outwards.z > 0.0,
				"wijzers van wijzerplaat %d net voor de kop" % (face_index + 1))
	# the collider: the pole and the head
	var space := clock.get_world_3d().direct_space_state
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(2.0, 1.5, 0.0), Vector3(0.0, 1.5, 0.0))
	var hit := space.intersect_ray(ray)
	_check(not hit.is_empty() and absf(hit.position.x - ZebraClock.POLE_WIDTH * 0.5) < 0.02, "botsvorm om de paal (%s)" % hit.get("position"))
	ray = PhysicsRayQueryParameters3D.create(Vector3(2.0, 0.45, 0.0), Vector3(0.0, 0.45, 0.0))
	hit = space.intersect_ray(ray)
	_check(not hit.is_empty() and absf(hit.position.x - ZebraClock.PLINTH_WIDTH * 0.5) < 0.02, "botsvorm om de sokkel (%s)" % hit.get("position"))
	var pole_material: StandardMaterial3D = clock.get_node("Paal").material_override
	_check(pole_material.metallic > 0.5 and (clock.get_node("Sokkel").material_override as StandardMaterial3D).metallic > 0.5, "paal en sokkel van metaal")
	ray = PhysicsRayQueryParameters3D.create(Vector3(0.0, box.position.y + box.size.y * 0.52, -4.0), Vector3(0.0, box.position.y + box.size.y * 0.52, 0.0))
	hit = space.intersect_ray(ray)
	_check(not hit.is_empty() and hit.position.z < -ZebraClock.HEAD_DEPTH * 0.4, "botsvorm om de kop (%s)" % hit.get("position"))
	print("zebraklok ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
