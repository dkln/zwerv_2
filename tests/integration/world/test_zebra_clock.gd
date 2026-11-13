extends "res://tests/integration/support/town_test.gd"
## The Zebraklok (scripts/world/town/zebra_clock.gd): a black pole with the head on it (its size),
## a flat square stood on its point (45 degrees), with straight black and white stripes and a white dial
## round the hands on both faces, its white really white (no grey shading), the hands
## turning clockwise as seen from in front of a face, pointing at the time, and its collider
## round the pole, the foot and the head. Without the town: only the clock.
##   tests/run_integration_tests.sh zebra_clock

const ZebraClock = preload("res://scripts/world/town/zebra_clock.gd")


static func world_options() -> Dictionary:
	return {"town": false}


## A Zebraklok at the origin, built (a frame on).
func _clock() -> Node3D:
	var clock := Node3D.new()
	clock.set_script(ZebraClock)
	add_to_root(clock)
	await frames(1)
	return clock


## The box round the head of `clock`, in the clock's space.
func _head_box(clock: Node3D) -> AABB:
	var head: MeshInstance3D = clock.get_node("Kop")
	return head.transform * head.get_aabb()


## Where a ray from `from` to `to` hits the collider of the clock ({} if it does not).
func _ray_hit(clock: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await tree.physics_frame
	return clock.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))


## The head is as high, wide and thick as the constants say, its top 8 to 9.5 m up.
func test_head_has_its_size_and_height(test) -> void:
	var box := _head_box(await _clock())
	print("kop ", box)
	test.check(absf(box.size.y - ZebraClock.HEAD_HEIGHT) < 0.25, "kop %.2f m hoog" % box.size.y)
	test.check(absf(box.size.x - ZebraClock.HEAD_HEIGHT) < 0.25 and absf(box.size.z - ZebraClock.HEAD_DEPTH) < 0.2, "kop %.2f m breed, %.2f m dik" % [box.size.x, box.size.z])
	test.check(box.end.y > 8.0 and box.end.y < 9.5, "klok %.2f m hoog" % box.end.y)


## The head is a square on its point: its corners top, bottom, left and right, not in the
## corners of its box.
func test_head_is_a_square_on_its_point(test) -> void:
	var half := ZebraClock.HEAD_HEIGHT * 0.5
	test.check(ZebraClock._in_head(0.0, half * 0.95) and ZebraClock._in_head(half * 0.95, 0.0) and not ZebraClock._in_head(half * 0.6, half * 0.6),
		"een vierkant op zijn punt (45 graden gedraaid)")


## The stripes are black and white and run straight across; round the hands the dial is white.
func test_straight_stripes_and_a_white_dial(test) -> void:
	var half := ZebraClock.HEAD_HEIGHT * 0.5
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
	test.check(black > 5 and white > 5, "zwart en wit (%d / %d)" % [black, white])
	test.check(straight, "rechte strepen")
	test.check(not ZebraClock._is_stripe(0.0, 0.0) and not ZebraClock._is_stripe(0.3, 0.3), "witte wijzerplaat om de wijzers")


## White, not grey: every corner of the head's mesh is pure white or black.
func test_white_is_white_not_grey(test) -> void:
	var clock := await _clock()
	var head: MeshInstance3D = clock.get_node("Kop")
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
	test.check(greys == 0 and whites > blacks and blacks > 0, "wit (niet grijs) en zwart")


## On both faces the minute hand points at the minutes of the system's time (clockwise
## seen from in front), and the hands stand just out of the face.
func test_hands_point_at_the_time_on_both_faces(test) -> void:
	var clock := await _clock()
	var box := _head_box(clock)
	var now := Time.get_time_dict_from_system()
	var minutes := float(now.minute) + float(now.second) / 60.0
	for face_index in 2:
		var outwards := ZebraClock.face_direction(face_index)
		var right := Vector3(outwards.z, 0.0, -outwards.x)
		var pivot: Node3D = clock._hand_pivots[face_index][1]
		var tip := pivot.global_transform * Vector3.UP - pivot.global_position
		var angle := TAU * minutes / 60.0
		var expected := right * sin(angle) + Vector3.UP * cos(angle)
		test.check(tip.normalized().dot(expected) > 0.98, "grote wijzer van wijzerplaat %d wijst naar de minuten" % (face_index + 1))
		var face_middle := pivot.global_position - clock.global_position
		test.check(face_middle.dot(outwards) > 0.0, "wijzers voor wijzerplaat %d" % (face_index + 1))
		# the hands stand just out of the face, not inside the head and not floating off it
		var face_at := box.get_center().z + outwards.z * box.size.z * 0.5
		var hand_front := face_middle.z + outwards.z * ZebraClock.HAND_OUT
		test.check(absf(hand_front - face_at) < ZebraClock.HAND_OUT + 0.05 and (hand_front - face_at) * outwards.z > 0.0,
			"wijzers van wijzerplaat %d net voor de kop" % (face_index + 1))


## The collider: round the pole, round the foot and round the head.
func test_collider_round_pole_foot_and_head(test) -> void:
	var clock := await _clock()
	var box := _head_box(clock)
	var hit := await _ray_hit(clock, Vector3(2.0, 1.5, 0.0), Vector3(0.0, 1.5, 0.0))
	test.check(not hit.is_empty() and absf(hit.position.x - ZebraClock.POLE_WIDTH * 0.5) < 0.02, "botsvorm om de paal (%s)" % hit.get("position"))
	hit = await _ray_hit(clock, Vector3(2.0, 0.45, 0.0), Vector3(0.0, 0.45, 0.0))
	test.check(not hit.is_empty() and absf(hit.position.x - ZebraClock.PLINTH_WIDTH * 0.5) < 0.02, "botsvorm om de sokkel (%s)" % hit.get("position"))
	var head_height := box.position.y + box.size.y * 0.52
	hit = await _ray_hit(clock, Vector3(0.0, head_height, -4.0), Vector3(0.0, head_height, 0.0))
	test.check(not hit.is_empty() and hit.position.z < -ZebraClock.HEAD_DEPTH * 0.4, "botsvorm om de kop (%s)" % hit.get("position"))


## The pole and the foot are of metal.
func test_pole_and_foot_are_metal(test) -> void:
	var clock := await _clock()
	var pole_material: StandardMaterial3D = clock.get_node("Paal").material_override
	test.check(pole_material.metallic > 0.5 and (clock.get_node("Sokkel").material_override as StandardMaterial3D).metallic > 0.5, "paal en sokkel van metaal")
