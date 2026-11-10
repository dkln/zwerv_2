extends SceneTree
## The Zebraklok (scripts/world/zebra_clock.gd): a black pole with the head on it (its size),
## a diamond (widest in the middle, straight to the points), striped black and white across
## with a white dial round the hands, its white really white (no grey shading), the hands
## turning clockwise as seen from in front of a face, pointing at the time and staying on
## the face, and its collider round the pole, the foot and the head.
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
	_check(box.size.x > 2.2 and box.size.x < 3.2 and box.size.z > 2.2 and box.size.z < 3.2, "kop %.2f x %.2f m breed" % [box.size.x, box.size.z])
	_check(box.end.y > 8.0 and box.end.y < 9.5, "klok %.2f m hoog" % box.end.y)
	# a diamond: widest in the middle, straight lines to both points
	_check(is_equal_approx(ZebraClock._profile(ZebraClock.WIDEST_AT), 1.0) and is_equal_approx(ZebraClock._profile(0.25), 0.5)
			and is_equal_approx(ZebraClock._profile(0.75), 0.5), "ruitvorm (breedst in het midden, recht naar de punten)")
	# striped: black and white bands in turn, white on the dial
	var band := ZebraClock.STRIPE_HEIGHT
	_check(ZebraClock._is_stripe(1.0, 0.0, band * 1.5) and not ZebraClock._is_stripe(1.0, 0.0, band * 2.5)
			and ZebraClock._is_stripe(1.0, 0.0, band * 3.5), "zwart-wit gestreept")
	_check(not ZebraClock._is_stripe(0.0, 0.0, band * 1.5) and not ZebraClock._is_stripe(0.5, 0.3, band * 5.5), "witte wijzerplaat om de wijzers")
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
	# the hands: the minute hand's tip in the direction of the minutes on face 1
	var now := Time.get_time_dict_from_system()
	var minutes := float(now.minute) + float(now.second) / 60.0
	for face_index in 3:
		var outwards := ZebraClock.face_direction(face_index)
		var right := Vector3(outwards.z, 0.0, -outwards.x)
		var pivot: Node3D = clock._hand_pivots[face_index][1]
		var tip := pivot.global_transform * Vector3.UP - pivot.global_position
		var angle := TAU * minutes / 60.0
		var expected := right * sin(angle) + Vector3.UP * cos(angle)
		_check(tip.normalized().dot(expected) > 0.98, "grote wijzer van wijzerplaat %d wijst naar de minuten" % (face_index + 1))
		var face_middle := pivot.global_position - clock.global_position
		_check(face_middle.normalized().dot((outwards + Vector3.UP * face_middle.y / face_middle.length()).normalized()) > 0.0, "wijzers voor wijzerplaat %d" % (face_index + 1))
		# the hands stay on the face where it slopes back: the back of each tip inside the head,
		# at every hour round the dial
		var face_node: Node3D = pivot.get_parent()
		for hand_pivot: Node3D in clock._hand_pivots[face_index]:
			var hand: MeshInstance3D = hand_pivot.get_child(0)
			var hand_box := hand.mesh as BoxMesh
			var shallowest := INF
			for hour in 12:
				var turned := Basis(Vector3.BACK, -TAU * hour / 12.0)
				var tip_back := face_node.global_transform * (turned * Vector3(0.0, hand_box.size.y - hand_box.size.x * 0.5, hand.position.z - hand_box.size.z * 0.5))
				var local := tip_back - clock.global_position - Vector3.UP * (ZebraClock.GROUND_TOP + ZebraClock.HEAD_BOTTOM)
				shallowest = minf(shallowest, float(ZebraClock._on_face(local)[3]))
			_check(shallowest > 0.0, "wijzer van wijzerplaat %d blijft op de kop (punt minstens %.2f m erin)" % [face_index + 1, shallowest])
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
	_check(not hit.is_empty() and hit.position.z < -ZebraClock.FACE_REACH * 0.85, "botsvorm om de kop (%s)" % hit.get("position"))
	print("zebraklok ok" if _problems.is_empty() else "FOUT: %s" % [_problems])
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FOUT  ") + what)
	if not ok:
		_problems.append(what)
