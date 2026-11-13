class_name MobilityAid
extends Node3D
## What a townsperson who does not walk rides (Pedestrian `mobility`): a wheelchair
## ("rolstoel") or a mobility scooter ("scootmobiel"), built in code in voxels (VOXEL, as the
## bicycles: PlayerModel.VoxelFigure), with the townsperson (TownsfolkFigure) sitting on it.
## In the space of its Pedestrian: the front towards +z, +x to the left, the ground at y = 0.
##
## The wheels are the vehicles' wheel models (the props items voertuigen/fiets_wiel and
## voertuigen/klein_wiel, made smaller) with the wheel shader (voxel_wheel.gdshader): the
## model never turns, the shader turns its spokes by the instance parameter `roll` (roll()).
## - Wheelchair: two big wheels at the back the hands push (the arms swing with them), two
##   small casters at the front that swivel round their upright axle to trail the way that
##   point of the chair moves (swivel()), and roll.
## - Mobility scooter: three wheels; the front one steers with the tiller (its column, the
##   handlebar, the basket; the hands on the grips go with it), steer().
## Everything sits in one node ("Kantel") that a wheelchair's wheelie (tilt()) turns back on
## its big wheels.

const PlayerModel = preload("res://scripts/player/player_model.gd")
const WHEEL_SHADER = preload("res://addons/vox_tiles/materials/voxel_wheel.gdshader")
const VOXEL := 0.0625
## Radius of the props wheel models (metres) the wheels are made from.
const BIKE_WHEEL_RADIUS := 0.375
const SMALL_WHEEL_RADIUS := 0.25
## Wheelchair: the big wheels, the casters (and how far behind their swivel axle they trail).
const CHAIR_WHEEL_RADIUS := 0.3
const CHAIR_WHEEL_X := 0.31
const CHAIR_WHEEL_Z := -0.16
const CASTER_RADIUS := 0.08
const CASTER_X := 0.2
const CASTER_Z := 0.34
const CASTER_TRAIL := 0.05
## Mobility scooter: the rear wheels, the steering front wheel, how far it steers at most.
const SCOOTER_WHEEL_RADIUS := 0.15
const SCOOTER_REAR_X := 0.27
const SCOOTER_REAR_Z := -0.42
const SCOOTER_FRONT_Z := 0.56
const MOST_STEER := 0.6
## How fast a caster swivels round to its way (1/s).
const SWIVEL_RATE := 8.0
## Paints of the scooters (one per seed) and of the wheelchair frames.
const SCOOTER_PAINTS := [Color("#D8262E"), Color("#2A62D0"), Color("#F0C020")]   # bright red, blue, yellow
const CHAIR_PAINTS := [Color("#2A2E36"), Color("#3A5AA0"), Color("#9A2A2A"), Color("#B8BCC4")]

var kind := "rolstoel"
var rider: TownsfolkFigure
## Hips, feet (left, +x) and hands (left) of the rider, in this node's space.
var hip := Vector3.ZERO
var foot := Vector3.ZERO
var hand := Vector3.ZERO
var _wheels: Array = []           # [MeshInstance3D, radius, rolled angle]
var _casters: Array = []          # [swivel Node3D, wheel MeshInstance3D, place (Vector3)]
var _steering: Node3D             # the scooter's front wheel, tiller and grips turn in it
var _grips_on_steering := {}      # "left"/"right" -> grip in the steering's space
var _lean := 0.0
var _push := 0.0                  # how far round the hands are on the push rims (radians)
var _tilt: Node3D                 # holds everything; turned back in a wheelie


## A wheelchair or a scooter of `kind`, its paint and its rider's look from `seed`, the
## wheels from the props library `library` (none without one).
static func create(aid_kind: String, seed: int, library: MeshLibrary, rider_look := {}) -> MobilityAid:
	var aid := MobilityAid.new()
	aid.kind = aid_kind
	aid.name = "Rolstoel" if aid_kind == "rolstoel" else "Scootmobiel"
	var random := RandomNumberGenerator.new()
	random.seed = seed
	if aid_kind == "rolstoel":
		aid._build_wheelchair(CHAIR_PAINTS[random.randi() % CHAIR_PAINTS.size()], library)
	else:
		aid._build_scooter(SCOOTER_PAINTS[random.randi() % SCOOTER_PAINTS.size()], library)
	# the rider's own look (Pedestrian.wanted_look), else one of the seed
	aid.rider = TownsfolkFigure.create(rider_look if not rider_look.is_empty() else TownsfolkFigure.look_for(seed * 13 + 7))
	aid.rider.name = "Berijder"
	aid.add_child(aid.rider)
	aid.rider.position = aid.hip - aid.rider.hip_middle()
	aid._lean = aid._lean_to_reach()
	aid.rider.lean_body(aid._lean)
	aid.pose()
	# all of it into the tilt node (local transforms kept: it is not in the tree yet)
	aid._tilt = Node3D.new()
	aid._tilt.name = "Kantel"
	for child in aid.get_children():
		aid.remove_child(child)
		aid._tilt.add_child(child)
	aid.add_child(aid._tilt)
	# the hard outline on the chair or the scooter (the rider has its own)
	(load("res://scripts/effects/outline.gd") as GDScript).apply(aid)
	return aid


## A wheelchair's wheelie: the front `angle` radians up, turned about where its big wheels
## touch the ground (the casters off it).
func tilt(transform_about: Transform3D) -> void:
	if _tilt:
		_tilt.transform = transform_about


## Where the big wheels touch the ground, in this node's space (the pivot of a wheelie).
static func chair_rear_contact() -> Vector3:
	return Vector3(0.0, 0.0, CHAIR_WHEEL_Z)


# ------------------------------------------------------------------ moving

## Rolls the wheels over `distance` metres (backwards when negative): the big or rear wheels
## and the scooter's front wheel; the hands on a wheelchair's rims go round with them.
func roll(distance: float) -> void:
	for wheel: Array in _wheels:
		wheel[2] = fmod(wheel[2] + distance / wheel[1], TAU)
		(wheel[0] as GeometryInstance3D).set_instance_shader_parameter("roll", -wheel[2])
	_push = fmod(_push + distance / CHAIR_WHEEL_RADIUS, TAU)


## Turns each caster round its upright axle to trail the way its point of the chair moves
## (`velocity` metres a second and `turning` radians a second, both of the chair, in its own
## space), and rolls it that far.
func swivel(velocity: Vector3, turning: float, delta: float) -> void:
	for caster: Array in _casters:
		var swivel_node: Node3D = caster[0]
		var place: Vector3 = caster[2]
		# the speed of that point: the chair's own plus its turning about its middle
		var moving := Vector3(velocity.x + turning * place.z, 0.0, velocity.z - turning * place.x)
		if moving.length() > 0.05:
			var wanted := atan2(moving.x, moving.z)
			swivel_node.rotation.y = lerp_angle(swivel_node.rotation.y, wanted, 1.0 - exp(-SWIVEL_RATE * delta))
		var rolled: float = caster[3] + moving.length() * delta / CASTER_RADIUS
		caster[3] = fmod(rolled, TAU)
		(caster[1] as GeometryInstance3D).set_instance_shader_parameter("roll", -caster[3])


## Turns the scooter's front wheel and tiller to `angle` (radians, + to the left), its rider's
## hands with the grips.
func steer(angle: float) -> void:
	if _steering:
		_steering.rotation.y = clampf(angle, -MOST_STEER, MOST_STEER)


## The rider's legs on the footrests and hands on the push rims or the grips.
func pose() -> void:
	for side: String in ["left", "right"]:
		var on_left := rider.rest_joint("thigh_" + side).x > 0.0
		var foot_here := Vector3(foot.x if on_left else -foot.x, foot.y, foot.z)
		rider.aim_leg(side, foot_here - rider.position)
		var hand_here := _hand(rider.rest_joint("arm_" + side).x > 0.0)
		rider.aim_arm(side, hand_here - rider.position, _lean)


func _hand(on_left: bool) -> Vector3:
	var side := "left" if on_left else "right"
	if _grips_on_steering.has(side):
		return _steering.transform * (_grips_on_steering[side] as Vector3)
	# on the push rim: a little round it from the top front, going with the wheels
	var reach := 0.45 + 0.35 * sin(_push * 0.5)
	var on_rim := Vector3(0.0, cos(reach) * CHAIR_WHEEL_RADIUS * 0.9, sin(reach) * CHAIR_WHEEL_RADIUS * 0.9)
	var centre := Vector3(CHAIR_WHEEL_X - 0.03, CHAIR_WHEEL_RADIUS, CHAIR_WHEEL_Z)
	var here := centre + on_rim
	return Vector3(here.x if on_left else -here.x, here.y, here.z)


## How far the body leans forward so the arms reach the hands' places.
func _lean_to_reach() -> float:
	var best := 0.0
	var best_miss := INF
	var lean := 0.0
	while lean <= 0.6:
		var miss := 0.0
		for side: String in ["left", "right"]:
			var hand_here := _hand(rider.rest_joint("arm_" + side).x > 0.0) - rider.position
			miss += absf(rider.shoulder_at(side, lean).distance_to(hand_here) - TownsfolkFigure.arm_length())
		if miss < best_miss:
			best_miss = miss
			best = lean
		lean += 0.02
	return best


# ------------------------------------------------------------------ building

func _build_wheelchair(paint: Color, library: MeshLibrary) -> void:
	hip = Vector3(0.0, 0.56, -0.02)
	foot = Vector3(0.1, 0.13, 0.42)
	var frame := PlayerModel.VoxelFigure.new()
	var cloth := Color("#1E1F24")
	var steel := Color("#B8BCC4")
	# the side frames: from the back post down along the seat to the caster forks, the footrests
	for side: float in [-1.0, 1.0]:
		var x := 0.24 * side
		_box(frame, Vector3(x, 0.2, -0.3), Vector3(x, 0.96, -0.26), paint)       # back post
		_box(frame, Vector3(x, 0.46, -0.26), Vector3(x, 0.5, CASTER_Z), paint)  # under the seat
		_box(frame, Vector3(x, 0.22, CASTER_Z - 0.02), Vector3(x, 0.5, CASTER_Z + 0.02), paint)
		_box(frame, Vector3(x * 0.6, 0.1, 0.36), Vector3(x * 0.6, 0.48, 0.4), paint)  # leg rest
		_box(frame, Vector3(x * 0.85, 0.1, 0.38), Vector3(x * 0.25, 0.12, 0.5), steel)  # footplate
		_box(frame, Vector3(x * 1.02, 0.62, -0.24), Vector3(x * 1.02, 0.64, 0.12), cloth)   # armrest
		_box(frame, Vector3(x * 1.02, 0.5, 0.08), Vector3(x * 1.02, 0.62, 0.1), paint)
		_box(frame, Vector3(x, 0.96, -0.36), Vector3(x, 0.98, -0.28), Color("#2A2A2A"))  # push handle
	_box(frame, Vector3(-0.22, 0.5, -0.24), Vector3(0.22, 0.52, 0.22), cloth)       # the seat
	_box(frame, Vector3(-0.22, 0.52, -0.3), Vector3(0.22, 0.92, -0.27), cloth)      # the back
	_box(frame, Vector3(-0.24, 0.3, -0.18), Vector3(0.24, 0.32, -0.14), paint)      # the axle tube
	frame.mark("plastic", [paint])
	frame.mark("metal", [steel])
	frame.mark("leather", [cloth, Color("#2A2A2A")])
	_add_mesh(frame, "Frame")
	if library == null:
		return
	var big := _wheel_kind(library, "voertuigen/fiets_wiel", BIKE_WHEEL_RADIUS)
	var small := _wheel_kind(library, "voertuigen/klein_wiel", SMALL_WHEEL_RADIUS)
	for side: float in [-1.0, 1.0]:
		_wheels.append([_add_wheel(self, big, Vector3(CHAIR_WHEEL_X * side, CHAIR_WHEEL_RADIUS, CHAIR_WHEEL_Z),
				CHAIR_WHEEL_RADIUS / BIKE_WHEEL_RADIUS), CHAIR_WHEEL_RADIUS, 0.0])
		var swivel_node := Node3D.new()
		swivel_node.name = "Zwenkwiel"
		swivel_node.position = Vector3(CASTER_X * side, CASTER_RADIUS * 2.6, CASTER_Z)
		add_child(swivel_node)
		var fork := MeshInstance3D.new()
		var fork_box := BoxMesh.new()
		fork_box.size = Vector3(0.05, CASTER_RADIUS * 1.6, 0.03)
		fork.mesh = fork_box
		fork.material_override = _paint_material(paint)
		fork.position = Vector3(0.0, -CASTER_RADIUS * 0.7, -CASTER_TRAIL * 0.5)
		swivel_node.add_child(fork)
		var place := Vector3(0.0, CASTER_RADIUS - swivel_node.position.y, -CASTER_TRAIL)
		var wheel := _add_wheel(swivel_node, small, place, CASTER_RADIUS / SMALL_WHEEL_RADIUS)
		_casters.append([swivel_node, wheel, swivel_node.position, 0.0])


func _build_scooter(paint: Color, library: MeshLibrary) -> void:
	hip = Vector3(0.0, 0.64, -0.16)
	foot = Vector3(0.12, 0.24, 0.3)
	var body := PlayerModel.VoxelFigure.new()
	var dark := Color("#26282E")
	var seat := Color("#30343C")
	var chrome := Color("#C8CCD4")
	# the floor, the rear body over its wheels, the front cowl
	_box(body, Vector3(-0.24, 0.14, -0.3), Vector3(0.24, 0.2, 0.42), dark)
	_box(body, Vector3(-0.3, 0.16, -0.66), Vector3(0.3, 0.36, -0.28), paint)
	_box(body, Vector3(-0.3, 0.36, -0.66), Vector3(0.3, 0.38, -0.3), dark)
	_box(body, Vector3(-0.12, 0.2, -0.68), Vector3(0.12, 0.26, -0.66), Color("#C82A2A"))  # rear lights
	_box(body, Vector3(-0.2, 0.2, 0.42), Vector3(0.2, 0.44, 0.5), paint)
	# the seat on its post, the backrest and the armrests
	_box(body, Vector3(-0.04, 0.36, -0.2), Vector3(0.04, 0.56, -0.12), chrome)
	_box(body, Vector3(-0.22, 0.56, -0.36), Vector3(0.22, 0.62, 0.06), seat)
	_box(body, Vector3(-0.22, 0.62, -0.38), Vector3(0.22, 1.0, -0.32), seat)
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(0.24 * side, 0.7, -0.3), Vector3(0.24 * side, 0.72, 0.02), seat)
		_box(body, Vector3(0.24 * side, 0.6, 0.0), Vector3(0.24 * side, 0.7, 0.02), chrome)
	body.mark("plastic", [paint, Color("#C82A2A")])
	body.mark("leather", [seat, dark])
	body.mark("metal", [chrome])
	_add_mesh(body, "Romp")
	# the steering: front wheel, the cowl over it, the tiller with its handlebar and basket
	_steering = Node3D.new()
	_steering.name = "Stuur"
	_steering.position = Vector3(0.0, 0.0, SCOOTER_FRONT_Z)
	add_child(_steering)
	var tiller := PlayerModel.VoxelFigure.new()
	var origin := Vector3(0.0, 0.0, SCOOTER_FRONT_Z)
	_box(tiller, Vector3(-0.14, 0.2, 0.5), Vector3(0.14, 0.4, 0.72), paint)            # cowl
	_box(tiller, Vector3(-0.03, 0.4, 0.46), Vector3(0.03, 0.9, 0.52), dark)            # column
	_box(tiller, Vector3(-0.03, 0.86, 0.36), Vector3(0.03, 0.92, 0.46), dark)
	_box(tiller, Vector3(-0.26, 0.9, 0.34), Vector3(0.26, 0.94, 0.38), chrome)         # handlebar
	_box(tiller, Vector3(-0.08, 0.92, 0.38), Vector3(0.08, 0.98, 0.44), Color("#1E1F24"))  # display
	# the basket on the front: light wire walls and bottom, the shopping in it
	var wire := Color("#D8DCE2")
	_box(tiller, Vector3(-0.2, 0.58, 0.54), Vector3(0.2, 0.6, 0.8), wire)              # bottom
	_box(tiller, Vector3(-0.2, 0.6, 0.78), Vector3(0.2, 0.84, 0.8), wire)              # front
	for side: float in [-1.0, 1.0]:
		_box(tiller, Vector3(0.18 * side, 0.6, 0.54), Vector3(0.2 * side, 0.84, 0.8), wire)   # the sides
	_box(tiller, Vector3(-0.16, 0.6, 0.6), Vector3(-0.04, 0.96, 0.66), Color("#D8A050"))  # a French loaf
	_box(tiller, Vector3(0.04, 0.6, 0.62), Vector3(0.12, 0.9, 0.7), Color("#4E9A3A"))     # a leek
	_box(tiller, Vector3(0.05, 0.6, 0.63), Vector3(0.11, 0.7, 0.69), Color("#E8E4D0"))    # its white end
	tiller.mark("plastic", [paint])
	tiller.mark("metal", [chrome, wire])
	tiller.mark("leather", [dark, Color("#1E1F24")])
	var tiller_mesh := _add_mesh(tiller, "Stuurkolom")
	tiller_mesh.position -= origin
	tiller_mesh.reparent(_steering, false)
	for side: String in ["left", "right"]:
		var x := 0.23 if side == "left" else -0.23
		_grips_on_steering[side] = Vector3(x, 0.92, 0.36) - origin
	if library == null:
		return
	var small := _wheel_kind(library, "voertuigen/klein_wiel", SMALL_WHEEL_RADIUS)
	var ratio := SCOOTER_WHEEL_RADIUS / SMALL_WHEEL_RADIUS
	for side: float in [-1.0, 1.0]:
		_wheels.append([_add_wheel(self, small, Vector3(SCOOTER_REAR_X * side, SCOOTER_WHEEL_RADIUS, SCOOTER_REAR_Z), ratio),
				SCOOTER_WHEEL_RADIUS, 0.0])
	_wheels.append([_add_wheel(_steering, small, Vector3(0.0, SCOOTER_WHEEL_RADIUS, 0.0), ratio), SCOOTER_WHEEL_RADIUS, 0.0])


## Fills the voxels of the box between two corners (metres; front +z, left +x).
static func _box(figure: PlayerModel.VoxelFigure, from: Vector3, to: Vector3, colour: Color) -> void:
	var low := Vector3(minf(from.x, to.x), minf(from.y, to.y), minf(from.z, to.z))
	var high := Vector3(maxf(from.x, to.x), maxf(from.y, to.y), maxf(from.z, to.z))
	for x in range(floori(low.x / VOXEL + 0.5), maxi(floori(high.x / VOXEL + 0.5), floori(low.x / VOXEL + 0.5) + 1)):
		for y in range(floori(low.y / VOXEL), maxi(floori(high.y / VOXEL), floori(low.y / VOXEL) + 1)):
			# the cells' z runs backwards (VoxelFigure.to_parts)
			for z in range(floori(-high.z / VOXEL + 0.5), maxi(floori(-low.z / VOXEL + 0.5), floori(-high.z / VOXEL + 0.5) + 1)):
				if colour.a == 0.0:
					figure.clear(x, y, z)
				else:
					figure.put(x, y, z, colour)


## The figure's voxels as a mesh on this node, where they were drawn.
func _add_mesh(figure: PlayerModel.VoxelFigure, node_name: String) -> MeshInstance3D:
	figure.centre_cell = Vector2.ZERO
	var lowest := 1 << 20
	for cell: Vector3i in figure.cells:
		lowest = mini(lowest, cell.y)
	var materials := {}
	for material_kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[material_kind] = PlayerModel.material_for(material_kind)
	var parts: Dictionary = figure.to_parts(VOXEL, {}, materials, PlayerModel.graded)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = parts.meshes.body
	# to_parts stands the lowest voxel on y = 0 and puts the cells' x and z boundaries 0 on 0
	instance.position = Vector3(0.0, lowest * VOXEL, 0.0)
	add_child(instance)
	return instance


static func _paint_material(paint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = PlayerModel.graded(paint)
	material.roughness = 0.4
	return material


## The mesh and wheel material of a props wheel model (as Vehicle._wheel_kind); empty without it.
static func _wheel_kind(library: MeshLibrary, item_name: String, radius: float) -> Dictionary:
	var item := library.find_item_by_name(item_name)
	if item < 0:
		return {}
	var mesh := library.get_item_mesh(item)
	var mesh_transform := library.get_item_mesh_transform(item)
	var middle := (mesh_transform * mesh.get_aabb()).get_center()
	var material := ShaderMaterial.new()
	material.shader = WHEEL_SHADER
	var box := mesh.get_aabb()
	material.set_shader_parameter("centre", box.get_center())
	var axle := Vector3.ZERO
	axle[box.size.min_axis_index()] = 1.0
	material.set_shader_parameter("axle", axle)
	var scale_of_wheel := radius / 0.375
	material.set_shader_parameter("rim_radius", 0.24 * scale_of_wheel)
	material.set_shader_parameter("hub_radius", 0.07 * scale_of_wheel)
	material.set_shader_parameter("spoke_half_width", 0.05 * scale_of_wheel)
	return {"mesh": mesh, "material": material, "transform": Transform3D(mesh_transform.basis, mesh_transform.origin - middle)}


## A wheel of `kind` at `at` on `parent`, made `size` times as big as its model.
func _add_wheel(parent: Node3D, kind: Dictionary, at: Vector3, size: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "Wiel"
	if kind.is_empty():
		return instance
	instance.mesh = kind.mesh
	instance.material_override = kind.material
	var placed: Transform3D = kind.transform
	instance.transform = Transform3D(Basis.from_scale(Vector3.ONE * size), at) * placed
	parent.add_child(instance)
	return instance
