class_name TownsfolkFigure
extends Node3D
## An ordinary townsperson (a pedestrian, or the rider on a bicycle, moped, scooter or
## motorbike), built in code from voxels the way the player figures are (PlayerModel's
## VoxelFigure, its materials and colour grade), at VOXEL metres: about as big as a player
## figure in the town (PlayerModel at PlayerController.FIGURE_SCALE), 1.75 m tall, standing
## on y = 0, the face towards +z.
## A look (look_for(seed)) picks the skin, the hair (short, long, bald, a cap) or a helmet
## (open or full face, for riders), a coat, trousers or a skirt and shoes, from colours seen
## in the street. Kept simple, with few details: big areas of one colour, no zips, hems,
## soles or strands; nobody carries a rucksack.
## Parts: the body (pelvis, torso and head) and per side an upper leg, a lower leg (with the
## shoe) and an arm, each a node of its own turning round its joint (hip, knee,
## shoulder), so the walk (walk) and riding (aim_leg, aim_arm: pointing the limbs at the
## pedals and the grips) move them. The joints are not nested: every limb is placed in
## the figure's own space.
## For a close-up (PlayerPortrait: the conversations, the shop screen) add_face() gives it a
## mouth that opens (set_mouth: a dark opening over the mouth voxels, growing down into the
## chin) and eyelids that blink (set_blink), on the body so they move with the head; and
## copy_pose_from(other) puts its limbs and body as another figure's (the one in the world).

const PlayerModel = preload("res://scripts/player/player_model.gd")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")

## Metres per voxel (a player figure's 0.0625 m, a little smaller, as the town draws them).
const VOXEL := 0.05
## The limbs and their boxes of cells (x0, y0, z0, x1, y1, z1, both included); the rest is
## the body. Joints at the top of each limb, in its middle.
const RIG := {
	"thigh_left": [[2, 7, -1, 4, 14, 3]], "thigh_right": [[7, 7, -1, 9, 14, 3]],
	"shin_left": [[2, 0, -3, 4, 6, 4]], "shin_right": [[7, 0, -3, 9, 6, 4]],
	"arm_left": [[0, 12, -1, 1, 25, 4]], "arm_right": [[10, 12, -1, 11, 25, 4]],
}
const LIMBS := ["thigh_left", "thigh_right", "shin_left", "shin_right", "arm_left", "arm_right"]
## The walk: how far the legs and arms swing (degrees), how far the knee bends on the way
## forward, and how much the body bobs (metres); the stride (metres per step).
const LEG_SWING := 24.0
const KNEE_BEND := 38.0
const ARM_SWING := 18.0
const WALK_BOB := 0.02
const STRIDE := 0.62
## How much longer or shorter an arm may get to put the hand on a grip (a share of its length).
const ARM_GIVE := 0.15

const SKINS := [Color("#F0C9A8"), Color("#E2B08A"), Color("#C68A62"), Color("#9A6444"), Color("#6E4430"), Color("#4A2E22")]
const HAIRS := [Color("#2A1E16"), Color("#4A3020"), Color("#7A5432"), Color("#C8A060"), Color("#E0C890"),
		Color("#8A8680"), Color("#D8D4CC"), Color("#9A3A1E"), Color("#141210")]
## Coats and jackets with the darker colour of their collar, zip and cuffs.
const COATS := [
	[Color("#2E4A78"), Color("#1E3050")], [Color("#8A2A2A"), Color("#5A1A1A")], [Color("#3E5E3A"), Color("#283E26")],
	[Color("#C8B48A"), Color("#8A7A5A")], [Color("#22242A"), Color("#101114")], [Color("#D8D2C4"), Color("#9A948A")],
	[Color("#E0A030"), Color("#9A6A18")], [Color("#5A3A6A"), Color("#3A2448")], [Color("#6A6E74"), Color("#44474C")],
	[Color("#2A7A8A"), Color("#1A5058")], [Color("#B85A78"), Color("#7A3A50")], [Color("#7A4A2A"), Color("#4E2E18")],
]
const TROUSERS := [Color("#3E5A86"), Color("#2A3A5A"), Color("#22242A"), Color("#5A5E64"), Color("#8A7A5E"),
		Color("#4E3A2A"), Color("#3A4A3A")]
const SHOES := [Color("#1A1612"), Color("#5A3A22"), Color("#E8E6E0"), Color("#3A3A40"), Color("#8A2A2A")]
const EYE := Color("#1A1420")
const MOUTH := Color("#8A4A44")
## The face in voxels (see _build_voxels): the mouth (x 5..6, row 28) and the eyes (x 4 and 7,
## row 31) on the front of the head (z 0); the cell the figure is centred on (x, z).
const MOUTH_CELLS := Vector3i(5, 28, 0)
const EYE_CELLS := [Vector3i(4, 31, 0), Vector3i(7, 31, 0)]
const CENTRE_CELL := Vector2(6.0, 2.0)
## The inside of an open mouth, and how far the opening grows down into the chin (voxels,
## wide open).
const MOUTH_INSIDE := Color("#2A1216")
const MOUTH_DROP := 1.0
## Just in front of the face, so it is drawn over it (metres).
const FACE_FRONT := 0.003

static var _parts := {}   # look key -> parts (VoxelFigure.to_parts)
## Looks whose parts are kept at most (the pedestrians keep changing, Pedestrians): beyond this
## the oldest go (the figures built from them keep their meshes).
const PARTS_KEPT := 160

## The look this figure is built from (look_for).
var look := {}
var _joints := {}         # limb -> Node3D at its joint
var _rest := {}           # limb -> rest position of its joint (metres, in the figure)
var _body: Node3D         # the body, turning round the middle of the hips
var _walk_clock := 0.0
var _mouth: MeshInstance3D        # add_face: the opening of the mouth
var _eyelids: Array[MeshInstance3D] = []
var _mouth_opening := 0.0


## A figure of this look, its parts in place (standing).
static func create(figure_look: Dictionary) -> TownsfolkFigure:
	var figure := TownsfolkFigure.new()
	figure.look = figure_look
	figure._build()
	return figure


## A look from a seed: always the same for the same seed. `rider`: "" walks (hair, caps,
## skirts), "fiets" a cyclist (bare head or a cap, never a skirt over the
## saddle), "helm" a rider in an open helmet, "helm_dicht" in a full-face helmet.
static func look_for(look_seed: int, rider := "") -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = look_seed
	var coat: Array = COATS[random.randi() % COATS.size()]
	var hair_style := "kort"
	var roll := random.randf()
	if roll < 0.32:
		hair_style = "lang"
	elif roll < 0.42:
		hair_style = "kaal"
	elif roll < 0.55:
		hair_style = "pet"
	if rider == "helm" or rider == "helm_dicht":
		hair_style = rider
	var skirt := rider == "" and hair_style == "lang" and random.randf() < 0.4
	return {
		"skin": SKINS[random.randi() % SKINS.size()],
		"hair": HAIRS[random.randi() % HAIRS.size()],
		"hair_style": hair_style,
		"coat": coat[0], "trim": coat[1],
		"trousers": TROUSERS[random.randi() % TROUSERS.size()],
		"skirt": skirt,
		"shoes": SHOES[random.randi() % SHOES.size()],
		"cap": COATS[random.randi() % COATS.size()][0],
		"helmet": [Color("#E8E6E0"), Color("#22242A"), Color("#B82A2A"), Color("#2A4A8A")][random.randi() % 4],
	}


## Length of the upper and the lower leg (hip to knee, knee to the sole) and of the arm
## (shoulder to the hand), in metres.
static func thigh_length() -> float:
	return 8.0 * VOXEL


static func shin_length() -> float:
	return 6.5 * VOXEL


static func arm_length() -> float:
	return 12.5 * VOXEL


## Where the hips are (the middle between both hip joints), the left and the right hip,
## and each shoulder, standing (metres, in the figure).
func hip_middle() -> Vector3:
	return (_rest.thigh_left + _rest.thigh_right) * 0.5


func rest_joint(limb: String) -> Vector3:
	return _rest[limb]


## Swings the limbs in a walk, `phase` in radians (TAU a pair of steps), `amount` 0..1
## (standing .. walking).
func walk(phase: float, amount: float) -> void:
	var stride := sin(phase)
	for side: String in ["left", "right"]:
		var swing := stride if side == "left" else -stride
		# a leg swinging forward (swing growing) bends its knee, one pushing back keeps it straight
		var forward := cos(phase) if side == "left" else -cos(phase)
		var hip := deg_to_rad(-swing * LEG_SWING * amount)
		var knee := deg_to_rad(maxf(forward, 0.0) * KNEE_BEND * amount)
		var hip_spot: Vector3 = _rest["thigh_" + side]
		var thigh := Basis(Vector3.RIGHT, hip)
		_place("thigh_" + side, hip_spot, thigh)
		var knee_spot := hip_spot + thigh * Vector3(0.0, -thigh_length(), 0.0)
		_place("shin_" + side, knee_spot, thigh * Basis(Vector3.RIGHT, knee))
		_place("arm_" + side, _rest["arm_" + side], Basis(Vector3.RIGHT, deg_to_rad(swing * ARM_SWING * amount)))
	_body.position = Vector3(0.0, absf(cos(phase)) * WALK_BOB * amount, 0.0)


## Leans the body (pelvis, torso and head) forward round the hips (radians).
func lean_body(angle: float) -> void:
	_body.position = Vector3.ZERO
	var hips := hip_middle()
	_body.transform = Transform3D(Basis(Vector3.RIGHT, angle), hips) * Transform3D(Basis.IDENTITY, -hips)


## Where a shoulder is with the body leant forward by `angle` (metres, in the figure).
func shoulder_at(side: String, angle: float) -> Vector3:
	var hips := hip_middle()
	return hips + Basis(Vector3.RIGHT, angle) * (_rest["arm_" + side] - hips)


## Puts a leg's foot on `foot` (in the figure's space; a pedal, a footrest), the knee
## bending forward and out a little: two-bone IK from the hip.
func aim_leg(side: String, foot: Vector3) -> void:
	var hip: Vector3 = _rest["thigh_" + side]
	var upper := thigh_length()
	var lower := shin_length()
	var reach := foot - hip
	var distance := clampf(reach.length(), absf(upper - lower) + 0.01, upper + lower - 0.001)
	var direction := reach.normalized() if reach.length_squared() > 0.000001 else Vector3.DOWN
	# the knee goes forward (and a touch outwards), at right angles to the line hip-foot
	var outward := Vector3(signf(hip.x) * 0.15, 0.0, 0.0)
	var bend := Vector3(0.0, 0.0, 1.0) + outward
	bend = (bend - direction * bend.dot(direction)).normalized()
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	var knee := hip + direction * along + bend * height
	var side_axis := bend.cross(direction).normalized()
	_place("thigh_" + side, hip, _segment_basis(knee - hip, side_axis))
	_place("shin_" + side, knee, _segment_basis(hip + direction * distance - knee, side_axis))


## Points an arm from its shoulder (the body leant forward by `lean`) at `hand` (a grip),
## stretched or shortened up to ARM_GIVE so the hand is on it.
func aim_arm(side: String, hand: Vector3, lean := 0.0) -> void:
	var shoulder := shoulder_at(side, lean)
	var down := hand - shoulder
	if down.length_squared() < 0.000001:
		return
	var side_axis := Vector3.RIGHT
	if absf(down.normalized().dot(side_axis)) > 0.95:
		side_axis = Vector3.FORWARD
	side_axis = (side_axis - down.normalized() * side_axis.dot(down.normalized())).normalized()
	var stretch := clampf(down.length() / arm_length(), 1.0 - ARM_GIVE, 1.0 + ARM_GIVE)
	var turn := _segment_basis(down, side_axis)
	_place("arm_" + side, shoulder, Basis(turn.x, turn.y * stretch, turn.z))


## A basis whose -y runs along `down` (a limb from its joint), x along `side_axis`.
static func _segment_basis(down: Vector3, side_axis: Vector3) -> Basis:
	var y_axis := -down.normalized()
	var x_axis := (side_axis - y_axis * side_axis.dot(y_axis)).normalized()
	return Basis(x_axis, y_axis, x_axis.cross(y_axis))


func _place(limb: String, at: Vector3, turn: Basis) -> void:
	var joint: Node3D = _joints.get(limb)
	if joint:
		joint.transform = Transform3D(turn, at)


func _build() -> void:
	var parts := parts_of(look)
	_body = Node3D.new()
	_body.name = "Lijf"
	add_child(_body)
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = parts.meshes.body
	body_mesh.layers = GroundShadow.FIGURE_LAYER   # its ground shadow does not fall on it
	_body.add_child(body_mesh)
	for limb: String in LIMBS:
		if not parts.meshes.has(limb):
			continue
		var joint := Node3D.new()
		joint.name = limb
		joint.position = parts.pivots[limb]
		add_child(joint)
		var piece := MeshInstance3D.new()
		piece.mesh = parts.meshes[limb]
		piece.position = -parts.pivots[limb]
		piece.layers = GroundShadow.FIGURE_LAYER
		joint.add_child(piece)
		_joints[limb] = joint
		_rest[limb] = parts.pivots[limb]


## A voxel of the figure's grid (`cell`, its lower front corner) in the figure's space, as
## VoxelFigure.to_parts places it (centred on CENTRE_CELL, z flipped so the face looks +z).
static func cell_point(cell: Vector3) -> Vector3:
	return Vector3(cell.x - CENTRE_CELL.x, cell.y, -(cell.z - CENTRE_CELL.y)) * VOXEL


## The mouth and the eyelids of a close-up (see the top), shut and hidden till used. Nothing
## for a full-face helmet.
func add_face() -> void:
	if _mouth != null or str(look.get("hair_style", "")) == "helm_dicht":
		return
	var inside := StandardMaterial3D.new()
	inside.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inside.albedo_color = MOUTH_INSIDE
	_mouth = MeshInstance3D.new()
	_mouth.name = "Mond"
	var mouth_quad := QuadMesh.new()
	mouth_quad.size = Vector2(2.0 * VOXEL, VOXEL)
	_mouth.mesh = mouth_quad
	_mouth.material_override = inside
	_mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mouth.visible = false
	_body.add_child(_mouth)
	var lid := StandardMaterial3D.new()
	lid.albedo_color = PlayerModel.graded((look.get("skin", SKINS[0]) as Color).darkened(0.12))
	for eye: Vector3i in EYE_CELLS:
		var eyelid := MeshInstance3D.new()
		eyelid.name = "Ooglid"
		var lid_quad := QuadMesh.new()
		lid_quad.size = Vector2(VOXEL, VOXEL)
		eyelid.mesh = lid_quad
		eyelid.material_override = lid
		eyelid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyelid.position = cell_point(Vector3(eye) + Vector3(0.5, 0.5, 0.0)) + Vector3(0.0, 0.0, FACE_FRONT)
		eyelid.visible = false
		_body.add_child(eyelid)
		_eyelids.append(eyelid)
	set_mouth(0.0)


## How far the mouth is open: 0 shut (the mouth voxels as they are), up to 1 wide open (the
## dark opening over the mouth row and MOUTH_DROP voxels down into the chin).
func set_mouth(opening: float) -> void:
	_mouth_opening = clampf(opening, 0.0, 1.0)
	if _mouth == null:
		return
	_mouth.visible = _mouth_opening > 0.01
	var height := 1.0 + MOUTH_DROP * _mouth_opening    # voxels, from the top of the mouth row down
	var top := cell_point(Vector3(MOUTH_CELLS) + Vector3(1.0, 1.0, 0.0))
	_mouth.scale = Vector3(1.0, height, 1.0)
	_mouth.position = top + Vector3(0.0, -height * VOXEL * 0.5, FACE_FRONT)


func mouth_opening() -> float:
	return _mouth_opening


func has_face() -> bool:
	return _mouth != null


func set_blink(shut: bool) -> void:
	for eyelid in _eyelids:
		eyelid.visible = shut


func is_blinking() -> bool:
	return not _eyelids.is_empty() and _eyelids[0].visible


## Puts the limbs and the body (the walk, a lean, a seat) as those of `other`, a figure of
## the same build (the one in the world, for its close-up).
func copy_pose_from(other: TownsfolkFigure) -> void:
	if other == null:
		return
	for limb: String in _joints:
		var source: Node3D = other._joints.get(limb)
		if source:
			(_joints[limb] as Node3D).transform = source.transform
	if other._body and _body:
		_body.transform = other._body.transform


## The meshes and joints of a look, built once per look and shared.
static func parts_of(figure_look: Dictionary) -> Dictionary:
	var key := str(figure_look)
	if not _parts.has(key) and _parts.size() >= PARTS_KEPT:
		_parts.erase(_parts.keys()[0])   # the oldest (a Dictionary keeps the order things went in)
	if not _parts.has(key):
		var figure := PlayerModel.VoxelFigure.new()
		_build_voxels(figure, figure_look)
		figure.centre_cell = Vector2(6.0, 2.0)
		figure.simplify()   # seen from afar: fewer details
		var materials := {}
		for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
			materials[kind] = PlayerModel.material_for(kind, true)
		_parts[key] = figure.to_parts(VOXEL, RIG, materials, PlayerModel.graded)
	return _parts[key]


## The voxels of a townsperson: x 0..11 across (the middle between 5 and 6), y up from the
## soles, z from the front (0) backwards.
static func _build_voxels(figure: PlayerModel.VoxelFigure, figure_look: Dictionary) -> void:
	var skin: Color = figure_look.skin
	var hair: Color = figure_look.hair
	var coat: Color = figure_look.coat
	var trim: Color = figure_look.trim
	var trousers: Color = figure_look.trousers
	var shoes: Color = figure_look.shoes
	# shoes (sticking out forward) and legs, three voxels wide
	for leg_x: int in [2, 7]:
		figure.box(Vector3i(leg_x, 0, -2), Vector3i(leg_x + 2, 1, 2), shoes)
		figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 2, 14, 2), trousers)
	# the pelvis, the torso in the coat, the collar in the darker colour
	figure.box(Vector3i(2, 15, 0), Vector3i(9, 15, 3), trousers)
	figure.box(Vector3i(2, 16, 0), Vector3i(9, 25, 3), coat)
	figure.box(Vector3i(3, 25, 0), Vector3i(8, 25, 3), trim)                  # the collar
	if figure_look.skirt:
		figure.box(Vector3i(1, 9, -1), Vector3i(10, 15, 4), trousers)
		for leg_x: int in [2, 7]:
			figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 2, 8, 2), skin)   # bare legs
	# the arms beside the torso: the sleeves and the hands
	for arm_x: int in [0, 10]:
		figure.box(Vector3i(arm_x, 15, 0), Vector3i(arm_x + 1, 25, 2), coat)
		figure.box(Vector3i(arm_x, 12, 0), Vector3i(arm_x + 1, 14, 1), skin)
	# the neck and the head with eyes, brows and a mouth
	figure.box(Vector3i(5, 26, 1), Vector3i(6, 26, 2), skin)
	PlayerModel._head(figure, 3, 27, skin)
	figure.put(4, 31, 0, EYE)
	figure.put(7, 31, 0, EYE)
	figure.box(Vector3i(5, 28, 0), Vector3i(6, 28, 0), MOUTH)
	_hair(figure, figure_look, hair)
	figure.mark("skin", [skin, skin.darkened(0.05), skin.darkened(0.08)])
	figure.mark("eye", [EYE])
	figure.mark("hair", [hair])
	figure.mark("leather", [shoes])
	figure.mark("denim", [trousers])
	figure.mark("nylon", [coat, trim])
	figure.mark("cloth", [figure_look.cap])
	figure.mark("plastic", [figure_look.helmet])
	figure.mark("glass", [Color("#20242E")])


static func _hair(figure: PlayerModel.VoxelFigure, figure_look: Dictionary, hair: Color) -> void:
	var style: String = figure_look.hair_style
	match style:
		"helm", "helm_dicht":
			# a helmet over the head from the ears up, its brim over the brows, or a full-face
			# one with a dark visor
			var helmet: Color = figure_look.helmet
			figure.box(Vector3i(2, 30, -1), Vector3i(9, 35, 6), helmet)
			figure.box(Vector3i(3, 27, 3), Vector3i(8, 29, 6), helmet)
			if style == "helm_dicht":
				figure.box(Vector3i(2, 27, -1), Vector3i(9, 29, 2), helmet)
				figure.box(Vector3i(3, 30, -2), Vector3i(8, 32, -2), Color("#20242E"))
				figure.box(Vector3i(3, 33, -2), Vector3i(8, 33, -2), helmet)
				for x in range(3, 9):
					for y in range(30, 33):
						figure.clear(x, y, -1)
			else:
				for x in range(3, 9):
					for y in range(30, 33):
						figure.clear(x, y, -1)
				figure.box(Vector3i(3, 33, -2), Vector3i(8, 33, -2), helmet)   # the brim
		"kaal":
			figure.box(Vector3i(2, 29, 2), Vector3i(2, 31, 5), hair)
			figure.box(Vector3i(9, 29, 2), Vector3i(9, 31, 5), hair)
			figure.box(Vector3i(3, 29, 5), Vector3i(8, 31, 5), hair)
		_:
			# short hair: the top, a fringe, the back and above the ears
			figure.box(Vector3i(3, 33, 0), Vector3i(8, 34, 5), hair)
			figure.box(Vector3i(3, 33, -1), Vector3i(8, 33, -1), hair)
			figure.box(Vector3i(3, 29, 5), Vector3i(8, 33, 6), hair)
			figure.box(Vector3i(2, 31, 1), Vector3i(2, 33, 5), hair)
			figure.box(Vector3i(9, 31, 1), Vector3i(9, 33, 5), hair)
			if style == "lang":
				figure.box(Vector3i(2, 25, 3), Vector3i(9, 33, 6), hair)
				figure.box(Vector3i(2, 27, 1), Vector3i(2, 33, 5), hair)
				figure.box(Vector3i(9, 27, 1), Vector3i(9, 33, 5), hair)
			elif style == "pet":
				var cap: Color = figure_look.cap
				figure.box(Vector3i(2, 34, -1), Vector3i(9, 35, 6), cap)
				figure.box(Vector3i(3, 34, -3), Vector3i(8, 34, -2), cap)   # the peak
