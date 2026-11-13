extends Node3D
## The Zebraklok on the Koningin Julianaplein before Centraal Station (Jaap Karman, 1977), kept
## simple: on a slender black pole a flat square head stood on its point (turned 45 degrees: a
## diamond), white with straight black stripes across it, as a zebra crossing (_is_stripe),
## and on both sides of it a plain white dial (DIAL_RADIUS) with the black
## hands sticking out of its middle, showing the real time (the computer's clock).
## Built here in code: the head in voxels (VOXEL) as the rest of the town
## (PlayerModel.VoxelFigure), of white and black plastic without the voxel shading (so the
## white is white, not grey); the pole and its foot of metal.
## Placed by tools/build/build_city.gd (_zebra_clock); its node only holds this script.

## Top of the square's tiles (plein/, 0.375 m above the clock's node): the pole stands on it,
## starting a little below it so no face of it lies in the square's surface (two faces at
## one height z-fight: the foot flickered).
const PlayerModel = preload("res://scripts/player/player_model.gd")
const GROUND_TOP := 0.375
const SINK := 0.05
## The voxels of the head (metres).
const VOXEL := 0.15
## The pole: its width (square) and where the head starts above the square.
const POLE_WIDTH := 0.3
const HEAD_BOTTOM := 5.6
## The metal foot the pole stands in: its width (square) and height above the square.
const PLINTH_WIDTH := 0.6
const PLINTH_HEIGHT := 0.25
## The head: a square stood on its point, HEAD_HEIGHT from point to point (so as wide), and
## HEAD_DEPTH thick; its two faces look out along the node's -z and +z.
const HEAD_HEIGHT := 2.9
const HEAD_DEPTH := 0.45
## The stripes: straight across, one black and one white band every STRIPE_SPACING metres.
const STRIPE_SPACING := 0.6
## The white dial round the hands on each face: its radius (metres).
const DIAL_RADIUS := 0.6
## The hands: length, width and depth (metres), and how far their front stands out of the face.
const HOUR_HAND := Vector3(0.36, 0.11, 0.3)
const MINUTE_HAND := Vector3(0.54, 0.08, 0.3)
const HAND_OUT := 0.06
const WHITE := Color("#FFFFFF")
const BLACK := Color("#16161A")

var _hand_pivots: Array = []   # per face: [hour pivot, minute pivot]


func _ready() -> void:
	_build_pole()
	_build_head()
	for face_index in 2:
		_add_hands(face_index)
	_build_collider()
	_show_time()


func _process(_delta: float) -> void:
	_show_time()


## The direction face `face_index` (0 or 1) looks out to: -z and +z.
static func face_direction(face_index: int) -> Vector3:
	return Vector3(0.0, 0.0, -1.0 if face_index == 0 else 1.0)


## Inside the head: a square on its point, |across| + |up| at most half its height (`across`,
## `up` in metres from its middle).
static func _in_head(across: float, up: float) -> bool:
	return absf(across) + absf(up) <= HEAD_HEIGHT * 0.5


## Black where a zebra stripe lies (`across`, `up`: metres from the middle of the head), white
## on the dial (`on_face`: the voxel is on one of the two faces, where the dial is).
static func _is_stripe(across: float, up: float, on_face := true) -> bool:
	if on_face and Vector2(across, up).length() < DIAL_RADIUS:
		return false
	# straight bands across, black and white in turn
	return fposmod(up / STRIPE_SPACING, 1.0) < 0.5


func _build_pole() -> void:
	var pole := MeshInstance3D.new()
	pole.name = "Paal"
	var box := BoxMesh.new()
	var height := HEAD_BOTTOM + 0.5 + SINK
	box.size = Vector3(POLE_WIDTH, height, POLE_WIDTH)
	pole.mesh = box
	pole.position = Vector3(0.0, GROUND_TOP - SINK + height * 0.5, 0.0)
	pole.material_override = _plain(BLACK, 0.35, 0.85)
	add_child(pole)
	var plinth := MeshInstance3D.new()
	plinth.name = "Sokkel"
	var foot := BoxMesh.new()
	foot.size = Vector3(PLINTH_WIDTH, PLINTH_HEIGHT + SINK, PLINTH_WIDTH)
	plinth.mesh = foot
	plinth.position = Vector3(0.0, GROUND_TOP - SINK + foot.size.y * 0.5, 0.0)
	plinth.material_override = _plain(BLACK.lightened(0.12), 0.45, 0.85)
	add_child(plinth)


func _build_head() -> void:
	var figure := PlayerModel.VoxelFigure.new()
	var half := int(ceil(HEAD_HEIGHT * 0.5 / VOXEL))
	var depth := maxi(int(round(HEAD_DEPTH / VOXEL)), 2)
	for row in range(-half, half):
		for column in range(-half, half):
			var across := (column + 0.5) * VOXEL
			var up := (row + 0.5) * VOXEL
			if not _in_head(across, up):
				continue
			for layer in depth:
				var on_face := layer == 0 or layer == depth - 1
				var colour := BLACK if _is_stripe(across, up, on_face) else WHITE
				# z of the cells runs backwards (VoxelFigure.to_parts): centred on the pole
				figure.put(column, row + half, layer - depth / 2, colour)
	figure.centre_cell = Vector2.ZERO
	figure.flat_shading = true
	figure.mark("plastic", [WHITE, BLACK])
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind)
	var parts: Dictionary = figure.to_parts(VOXEL, {}, materials, PlayerModel.graded)
	var head := MeshInstance3D.new()
	head.name = "Kop"
	head.mesh = parts.meshes.body
	# centred on the pole front to back, so both faces lie at HEAD_DEPTH / 2 (the hands' place)
	var off_centre := head.mesh.get_aabb().get_center().z
	head.position = Vector3(0.0, GROUND_TOP + HEAD_BOTTOM, -off_centre)
	add_child(head)


## The hour and the minute hand of face `face_index`, sticking out of the middle of its dial.
func _add_hands(face_index: int) -> void:
	var outwards := face_direction(face_index)
	var middle := outwards * HEAD_DEPTH * 0.5 + Vector3.UP * (GROUND_TOP + HEAD_BOTTOM + HEAD_HEIGHT * 0.5)
	var face := Node3D.new()
	face.name = "Wijzers%d" % (face_index + 1)
	# its +z out of the face, +y up, +x to the right as seen from in front
	face.basis = Basis.looking_at(-outwards, Vector3.UP)
	face.position = middle
	add_child(face)
	var pivots: Array = []
	for size: Vector3 in [HOUR_HAND, MINUTE_HAND]:
		var pivot := Node3D.new()
		face.add_child(pivot)
		var hand := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(size.y, size.x, size.z)
		hand.mesh = box
		hand.material_override = _plain(BLACK, 0.3)
		# the minute hand a little in front of the hour hand, so their fronts never overlap
		var front := HAND_OUT + (0.04 if size == MINUTE_HAND else 0.0)
		hand.position = Vector3(0.0, size.x * 0.5 - size.y * 0.5, front - size.z * 0.5)
		pivot.add_child(hand)
		pivots.append(pivot)
	_hand_pivots.append(pivots)


## What one bumps into: the pole, its foot and the head.
func _build_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "Botsvorm"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(POLE_WIDTH, HEAD_BOTTOM + SINK, POLE_WIDTH)
	shape.shape = box
	shape.position = Vector3(0.0, GROUND_TOP - SINK + box.size.y * 0.5, 0.0)
	body.add_child(shape)
	var foot_shape := CollisionShape3D.new()
	var foot_box := BoxShape3D.new()
	foot_box.size = Vector3(PLINTH_WIDTH, PLINTH_HEIGHT + SINK, PLINTH_WIDTH)
	foot_shape.shape = foot_box
	foot_shape.position = Vector3(0.0, GROUND_TOP - SINK + foot_box.size.y * 0.5, 0.0)
	body.add_child(foot_shape)
	var head_shape := CollisionShape3D.new()
	head_shape.shape = (get_node("Kop") as MeshInstance3D).mesh.create_convex_shape(true, true)
	head_shape.position = (get_node("Kop") as MeshInstance3D).position
	body.add_child(head_shape)
	add_child(body)


## A plain material: plastic (the hands) or metal (`metallic` 0.85: the pole and its foot).
static func _plain(colour: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = PlayerModel.graded(colour)
	material.roughness = roughness
	material.metallic = metallic
	return material


## The hands at the time of the computer's clock (turning clockwise as seen from in front).
func _show_time() -> void:
	var now := Time.get_time_dict_from_system()
	var minutes := float(now.minute) + float(now.second) / 60.0
	var hours := float(int(now.hour) % 12) + minutes / 60.0
	for pivots: Array in _hand_pivots:
		(pivots[0] as Node3D).rotation.z = -TAU * hours / 12.0
		(pivots[1] as Node3D).rotation.z = -TAU * minutes / 60.0
