extends Node3D
## The Zebraklok on the Koningin Julianaplein before Centraal Station (Jaap Karman, 1977):
## a big white head striped in black, like a zebra, on a slender black pole, about 8.5 m
## tall. The head is a diamond: three flat faces round it, one clock each, meeting in sharp
## ridges, widest in the middle and running in straight lines up to a point on top and down
## to one on the pole. Kept simple for the iso view: broad black and white stripes across
## the whole head (STRIPE_HEIGHT), and on each face a plain white dial (DIAL_RADIUS) with the
## black hands sticking out of its middle, showing the real time (the computer's clock).
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
## The head: its height, at its widest the distance from its axis to the flat of a face
## (`FACE_REACH`), and at which share of its height it is widest (the middle of the clocks).
const HEAD_HEIGHT := 2.9
const FACE_REACH := 0.8
const WIDEST_AT := 0.5
## The stripes: the height of each band (metres, two voxels), black and white in turn; the
## white dial round the hands: its radius (metres) on the face.
const STRIPE_HEIGHT := 0.3
const DIAL_RADIUS := 0.75
## The hands: length, width and depth (metres), and how far their front stands out of the
## face; they reach deep into the head, so they stay on the face where it slopes back.
const HOUR_HAND := Vector3(0.42, 0.12, 0.6)
const MINUTE_HAND := Vector3(0.64, 0.09, 0.6)
const HAND_OUT := 0.15
const WHITE := Color("#FFFFFF")
const BLACK := Color("#16161A")

var _hand_pivots: Array = []   # per face: [hour pivot, minute pivot]


func _ready() -> void:
	_build_pole()
	_build_head()
	for face_index in 3:
		_add_hands(face_index)
	_build_collider()
	_show_time()


func _process(_delta: float) -> void:
	_show_time()


## The direction (on the ground) face `face_index` looks out to; the first towards -z.
static func face_direction(face_index: int) -> Vector3:
	var angle := deg_to_rad(-90.0 + 120.0 * face_index)
	return Vector3(cos(angle), 0.0, sin(angle))


## How wide the head is at height share `share` (0 bottom .. 1 top): 0 at both points,
## 1 at WIDEST_AT, in straight lines between (a diamond).
static func _profile(share: float) -> float:
	if share <= 0.0 or share >= 1.0:
		return 0.0
	if share < WIDEST_AT:
		return share / WIDEST_AT
	return (1.0 - share) / (1.0 - WIDEST_AT)


## Where on its face a point of the head lies: [face index, across (metres, + to the right as
## seen from in front of it), up from the middle of the dial (metres), how far inside the
## face (metres, < 0 outside)].
static func _on_face(point: Vector3) -> Array:
	var reach := FACE_REACH * _profile(point.y / HEAD_HEIGHT)
	var best := [0, 0.0, 0.0, -INF]
	var nearest := INF
	for face_index in 3:
		var outwards := face_direction(face_index)
		var right := Vector3(outwards.z, 0.0, -outwards.x)
		var inside := reach - point.dot(outwards)
		if inside < nearest:
			nearest = inside
			best = [face_index, point.dot(right), point.y - WIDEST_AT * HEAD_HEIGHT, inside]
	return best


## Black where a stripe lies: every other band of STRIPE_HEIGHT up the head (`height`: metres
## above its bottom point), except on the white dial (`across`, `up`: from its middle).
static func _is_stripe(across: float, up: float, height: float) -> bool:
	if Vector2(across, up).length() < DIAL_RADIUS:
		return false
	return posmod(floori(height / STRIPE_HEIGHT), 2) == 1


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
	var reach := int(ceil((FACE_REACH * 2.0 + 0.2) / VOXEL))
	var rows := int(ceil(HEAD_HEIGHT / VOXEL))
	for row in rows:
		for column_x in range(-reach, reach):
			for column_z in range(-reach, reach):
				# z of the cells runs backwards (VoxelFigure.to_parts)
				var point := Vector3((column_x + 0.5) * VOXEL, (row + 0.5) * VOXEL, -(column_z + 0.5) * VOXEL)
				var place: Array = _on_face(point)
				# the four voxels round the axis always: the points, narrower than a voxel
				var on_axis := column_x in [-1, 0] and column_z in [-1, 0]
				if place[3] < 0.0 and not on_axis:
					continue
				var colour := BLACK if _is_stripe(place[1], place[2], point.y) else WHITE
				figure.put(column_x, row, column_z, colour)
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
	head.position = Vector3(0.0, GROUND_TOP + HEAD_BOTTOM, 0.0)
	add_child(head)


## The hour and the minute hand of face `face_index`, sticking out of the middle of its dial.
func _add_hands(face_index: int) -> void:
	var outwards := face_direction(face_index)
	var middle := outwards * FACE_REACH + Vector3.UP * (GROUND_TOP + HEAD_BOTTOM + WIDEST_AT * HEAD_HEIGHT)
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
	head_shape.position = Vector3(0.0, GROUND_TOP + HEAD_BOTTOM, 0.0)
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
