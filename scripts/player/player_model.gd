extends Node3D
## The voxel figure of a player archetype (PlayerCharacter.ARCHETYPES), built in code from
## boxes of voxels of VOXEL metres (as the riders of the traffic, 0.0625 m), so it needs no
## imported tile: about 2 m tall, standing on y = 0, the face towards +z. All four are
## zwervers in worn clothes; their names are nicknames. Kept simple, with few details: big
## areas of one colour, no lone detail voxels (buttons, stitches, stains, strands). Nobody
## carries a rucksack (one picked up in the town is put on: set_backpack).
## - jos (alcohol): a battered cowboy hat, long matted grey hair and a scruffy beard, a red
##   drinker's nose, a long coat over a red shirt and a belly, rope for a belt, jeans,
##   fingerless gloves, boots;
## - martin (speed): once a top athlete (the 800 metres), now skin and bone (a chest no wider
##   than his head, the slimmest arms and legs of all) in a faded tracksuit whose jacket is
##   all one colour, grey trainers, a blond mullet, sunglasses on his forehead, wide eyes and
##   a small tight grin;
## - ufo_piloot (crack): an ordinary man, skinny: an old aviator jacket too big on him with a
##   fleece collar over a grey hoodie, faded jeans, worn shoes, a grey beard, short hair;
## - willem (gokkasten): an old man in a long coat, a red knitted scarf, corduroy trousers
##   and slippers, a flat cap over white hair, round glasses, bushy brows, a grey moustache.
## - sjaan (sigaretten): once a toilet attendant: big curly auburn hair under a green knitted
##   beanie, a denim jacket, a long patchwork skirt, boots.
## - gerrit (bier): an old fisherman from Scheveningen: a yellow oilskin coat and a
##   sou'wester, a navy roll-neck jumper under it, rubber boots, a full grey beard and a
##   weathered red face.
## Limbs: the arms and the legs are parts of their own (RIGS: the boxes of voxels of each),
## each turning round its own joint (shoulder, hip), the forearm and the shin hanging from
## them at the elbow and the knee, so they move independently of each other: `walking`
## (0..1) swings them in a walk cycle, above 1 in a run of its own (RUN_*: the knees driven
## up, the elbows bent, leaning forward, off the ground between the steps), pose_limb sets
## one by hand, and the
## idle moves use them too (Jos sways and swings his arms, Martin taps his feet and
## jitters, Sjaan rocks along, Willem and the pilot breathe).
## Shading: each face a little darker on the sides and below, and every corner darkened by
## the voxels round it (ambient occlusion), so folds, gaps and the parts under a brim read.
## Each voxel one flat colour, kept to few and clearly different colours per figure.
## Materials: every colour has a kind (VoxelFigure.mark; colours not marked take the kind
## of the nearest marked colour, else cloth). The fabrics (cloth, denim, knit, nylon) and
## hair have a shader of their own (figure.gdshader), each with its own pattern and gloss
## (CLOTH); skin, eyes, leather, plastic, metal and glass ordinary materials (MATERIALS). All colours are
## graded for more colour and contrast (SATURATION, CONTRAST). `spin` turns the whole
## figure slowly round.
## Gestures: play_gesture() makes the figure do its own move, facing the front (GESTURES:
## Jos holds out his hand, begging, and shrugs on the "-ro?", Martin sprints on the spot and hops to "Al zijn ze paars!", the
## ufo pilot floats up with his arms spread like wings, Willem bends over cackling, his
## shoulders shaking, Sjaan polishes ("Ff poetsen"), Gerrit points at you, jabbing on "SCHOL" and on "KOP"); `gesture_cue` fires
## at its moment for the shout (the start of "5 euro?", of "Al zijn ze paars!"), `gesture_finished` at the end;
## then it walks and turns on as before.
## `silhouette`: a colour with alpha draws the whole figure in that one flat colour (the
## narrator's portrait: only the outline of someone).

signal gesture_cue
signal gesture_finished

const VOXEL := 0.0625
const SHADER := preload("res://scripts/player/figure.gdshader")
const PLAIN_SHADER := preload("res://scripts/player/figure_plain.gdshader")
const OUTLINE_SHADER := preload("res://scripts/player/figure_outline.gdshader")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")
## Colours closer than this (RGB distance) are one colour in a simple figure.
const SIMPLE_COLOUR_DISTANCE := 0.12
## Voxels up to the middle of each face (eyes and nose), to zoom in on it.
const FACE_HEIGHT := {"jos": 28.5, "martin": 30.5, "ufo_piloot": 29.5, "willem": 26.0, "sjaan": 29.0, "gerrit": 29.0}
## The limbs of each figure: per limb the boxes of voxel cells (x0, y0, z0, x1, y1, z1,
## both corners included) that belong to it, what it holds included; the rest is the body.
## The joint is at the top of the limb, in its middle. A cell in the boxes of more than one
## limb belongs to the last one: the forearm and the shin are the lower part of the arm and
## the leg (PARENT_LIMB), with the elbow and the knee at their top.
const RIGS := {
	"jos": {
		"arm_left": [[-3, 3, -4, 0, 23, 6]], "arm_right": [[13, 3, -4, 15, 23, 6]],
		"leg_left": [[3, 0, -3, 5, 12, 4]], "leg_right": [[8, 0, -3, 10, 12, 4]],
		"forearm_left": [[-3, 3, -4, 0, 17, 6]], "forearm_right": [[13, 3, -4, 15, 17, 6]],
		"shin_left": [[3, 0, -3, 5, 6, 4]], "shin_right": [[8, 0, -3, 10, 6, 4]],
	},
	"martin": {
		"arm_left": [[1, 13, -6, 3, 23, 2]], "arm_right": [[10, 13, -6, 12, 23, 2]],
		"leg_left": [[3, 0, -4, 5, 12, 3]], "leg_right": [[8, 0, -4, 10, 12, 3]],
		"forearm_left": [[1, 13, -6, 3, 18, 2]], "forearm_right": [[10, 13, -6, 12, 18, 2]],
		"shin_left": [[3, 0, -4, 5, 6, 3]], "shin_right": [[8, 0, -4, 10, 6, 3]],
	},
	"ufo_piloot": {
		"arm_left": [[-1, 12, -2, 2, 23, 3]], "arm_right": [[11, 12, -2, 14, 23, 3]],
		"leg_left": [[4, 0, -2, 5, 13, 3]], "leg_right": [[8, 0, -2, 9, 13, 3]],
		"forearm_left": [[-1, 12, -2, 2, 18, 3]], "forearm_right": [[11, 12, -2, 14, 18, 3]],
		"shin_left": [[4, 0, -2, 5, 6, 3]], "shin_right": [[8, 0, -2, 9, 6, 3]],
	},
	"willem": {
		"arm_left": [[-1, 3, -2, 1, 20, 4], [2, 19, 0, 2, 20, 3]],
		"arm_right": [[12, 10, -2, 14, 20, 4], [11, 19, 0, 11, 20, 3]],
		"leg_left": [[3, 0, -2, 5, 7, 3]], "leg_right": [[8, 0, -2, 10, 7, 3]],
		"forearm_left": [[-1, 3, -2, 1, 15, 4]], "forearm_right": [[12, 10, -2, 14, 15, 4]],
		"shin_left": [[3, 0, -2, 5, 3, 3]], "shin_right": [[8, 0, -2, 10, 3, 3]],
	},
	"gerrit": {
		"arm_left": [[-3, 3, -2, 1, 24, 4], [2, 23, 0, 2, 24, 3]],
		"arm_right": [[12, 10, -2, 13, 24, 4], [11, 23, 0, 11, 24, 3]],
		"leg_left": [[3, 0, -2, 5, 10, 4]], "leg_right": [[8, 0, -2, 10, 10, 4]],
		"forearm_left": [[-3, 3, -2, 1, 18, 4]], "forearm_right": [[12, 10, -2, 13, 18, 4]],
		"shin_left": [[3, 0, -2, 5, 5, 4]], "shin_right": [[8, 0, -2, 10, 5, 4]],
	},
	"sjaan": {
		"arm_left": [[0, 13, -2, 1, 24, 3], [2, 23, 0, 2, 24, 2]],
		"arm_right": [[12, 13, -2, 13, 24, 3], [11, 23, 0, 11, 24, 2]],
		"leg_left": [[3, 0, -2, 5, 7, 4]], "leg_right": [[8, 0, -2, 10, 7, 4]],
		"forearm_left": [[0, 13, -2, 1, 18, 3]], "forearm_right": [[12, 13, -2, 13, 18, 3]],
		"shin_left": [[3, 0, -2, 5, 3, 4]], "shin_right": [[8, 0, -2, 10, 3, 4]],
	},
}
const LIMBS := ["arm_left", "arm_right", "leg_left", "leg_right", "forearm_left", "forearm_right", "shin_left", "shin_right"]
## The lower limbs hang from the upper ones (their joint nodes are children of these), so
## an elbow and a knee bend on top of the swing of the shoulder and the hip.
const PARENT_LIMB := {"forearm_left": "arm_left", "forearm_right": "arm_right", "shin_left": "leg_left", "shin_right": "leg_right"}
## The kinds of material. The fabrics (and hair, which is drawn the same way) have the
## fabric shader (figure.gdshader), each with its own pattern (1 weave, 2 twill, 3 knit,
## 4 strands), its strength and threads per voxel, how much the threads bump the normal
## (depth), how much lighter the weft shows than the warp (weft), how much each thread
## differs in shade (slub), roughness, specular and velvet edge:
const CLOTH := {
	# clothes: canvas / jute (a coarse basket weave, about a thread per voxel, so it reads as
	# real cloth also from the game's distance)
	"cloth": {"pattern": 5, "strength": 0.2, "scale": 1.0, "depth": 0.55, "weft": 0.06, "slub": 0.09,
			"roughness": 0.95, "specular": 0.25, "rim": 0.35},
	# all the fabrics coarse enough to read as cloth from the game's distance (about a thread
	# or a stitch per voxel): denim's twill ribs, the stitches of knitwear, a ripstop nylon
	"denim": {"pattern": 2, "strength": 0.18, "scale": 1.0, "depth": 0.5, "weft": 0.22, "slub": 0.07,
			"roughness": 0.85, "specular": 0.35, "rim": 0.25},
	"knit": {"pattern": 3, "strength": 0.22, "scale": 0.6, "depth": 0.6, "weft": 0.0, "slub": 0.0,
			"roughness": 0.97, "specular": 0.2, "rim": 0.5},
	"nylon": {"pattern": 1, "strength": 0.1, "scale": 1.5, "depth": 0.25, "weft": 0.03, "slub": 0.03,
			"roughness": 0.42, "specular": 0.6, "rim": 0.15},
	"hair": {"pattern": 4, "strength": 0.12, "scale": 1.0, "depth": 0.3, "weft": 0.0, "slub": 0.0,
			"roughness": 0.55, "specular": 0.5, "rim": 0.3},
}
## the others are ordinary materials with this roughness, metallic, specular and rim:
const MATERIALS := {
	"leather": {"roughness": 0.42, "metallic": 0.0, "specular": 0.55, "rim": 0.1},
	"plastic": {"roughness": 0.3, "metallic": 0.0, "specular": 0.6, "rim": 0.0},
	"metal": {"roughness": 0.25, "metallic": 0.9, "specular": 0.8, "rim": 0.0},
	"glass": {"roughness": 0.05, "metallic": 0.0, "specular": 0.9, "rim": 0.0},
	"skin": {"roughness": 0.6, "metallic": 0.0, "specular": 0.35, "rim": 0.3},
	"eye": {"roughness": 0.15, "metallic": 0.0, "specular": 0.7, "rim": 0.0},
}
## The grade of the colours (in sRGB, before shading): more colour and more contrast than
## the flat hex codes give, so nothing looks grey and washed out.
const SATURATION := 1.35
const CONTRAST := 1.15
## The gestures: how long (s), the moment the shout starts (s; its loud part, the "PAARS" or
## the "HOI", lands on the big move a little later), and the fade in and out (s).
const GESTURES := {
	"jos": {"seconds": 1.6, "cue": 0.25},
	"martin": {"seconds": 1.5, "cue": 0.12},
	"ufo_piloot": {"seconds": 2.3, "cue": 0.3},
	"willem": {"seconds": 1.3, "cue": 0.2},
	"sjaan": {"seconds": 1.3, "cue": 0.3},
	"gerrit": {"seconds": 1.5, "cue": 0.25},
}
const GESTURE_FADE := 0.25
## Seconds a spinning figure first stands facing the front when it is shown anew, before
## it turns (0: it turns at once, from the front).
const FRONT_HOLD := 0.0
## The walk: steps a second, how far the legs and the arms swing (degrees), how far the knee
## bends as the leg comes forward, how much the body bobs (metres).
const STEPS_PER_SECOND := 1.8
const LEG_SWING := 26.0
const ARM_SWING := 20.0
const WALK_KNEE := 22.0
const WALK_BOB := 0.025
## The run (`walking` above 1: from RUN_FROM it blends in, fully at RUN_FULL): not the walk
## sped up but a run of its own. The steps come RUN_CADENCE times as fast as a walk's; the
## thigh drives far forward (RUN_THIGH_FORWARD, the knee lifted high) and pushes back
## (RUN_THIGH_BACK); the knee bends deep as the leg swings through, the heel kicked up
## (RUN_KNEE), and never quite straightens (RUN_KNEE_MIN); the arms pump from the shoulder
## (RUN_ARM_FORWARD, RUN_ARM_BACK), the elbows bent at about a right angle (RUN_ELBOW),
## closing a little as the arm comes forward (RUN_ELBOW_PUMP); the body leans forward
## (RUN_LEAN, degrees) and its shoulders turn against the hips (RUN_TWIST); it is highest
## between the steps, both feet off the ground (RUN_BOB, metres), and lowest as a foot lands.
const RUN_FROM := 1.05
const RUN_FULL := 1.5
const RUN_CADENCE := 1.5
const RUN_THIGH_FORWARD := 62.0
const RUN_THIGH_BACK := 32.0
const RUN_KNEE := 105.0
const RUN_KNEE_MIN := 14.0
const RUN_ARM_FORWARD := 50.0
const RUN_ARM_BACK := 38.0
const RUN_ELBOW := 82.0
const RUN_ELBOW_PUMP := 18.0
const RUN_LEAN := 11.0
const RUN_TWIST := 5.0
const RUN_BOB := 0.09

@export var archetype_id := "jos":
	set(value):
		archetype_id = value
		if is_inside_tree():
			_rebuild()
## Size of the figure (1 = its voxels of VOXEL metres, as on the screens; the town draws it
## smaller, PlayerController.FIGURE_SCALE, so it stands in proportion to the townspeople,
## the bicycles and the cars).
## With fewer details (the town, seen from afar; VoxelFigure.simplify).
@export var simple := false:
	set(value):
		simple = value
		if is_inside_tree():
			_rebuild()
## With the rucksack on its back (BACKPACK), picked up in the town; nobody starts with one.
@export var backpack := false:
	set(value):
		if backpack == value:
			return
		backpack = value
		if is_inside_tree():
			_rebuild()
@export var figure_scale := 1.0:
	set(value):
		figure_scale = value
		if _figure:
			_figure.scale = Vector3.ONE * figure_scale
## Moves on its own (sway, jitter, tapping, playing).
@export var idle := true
## Degrees a second it turns round (0 = stands still facing +z).
@export var spin := 0.0
## How much it walks (0 = stands, 1 = a full walk cycle on the spot; above 1 it runs, from
## RUN_FROM to RUN_FULL, the player's run); tween it.
@export_range(0.0, 2.0) var walking := 0.0
## With alpha: the whole figure in this one flat colour (a silhouette).
var silhouette := Color(0, 0, 0, 0):
	set(value):
		silhouette = value
		if is_inside_tree():
			_rebuild()

static var _cache := {}
static var _materials := {}

var _figure: Node3D           # turns, sways and bobs; the body and the joints under it
var _joints := {}             # limb -> Node3D at its joint
var _poses := {}              # limb -> Vector3 (degrees) set with pose_limb
var _height := 2.0
var _clock := 0.0
var _walk_clock := 0.0
var _turn := 0.0
var _hold := FRONT_HOLD   # seconds left facing the front before turning
var _gesture_clock := -1.0  # seconds into the gesture under way; below 0 when there is none
var _gesture_cued := false


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if _figure:
		_figure.queue_free()
	_figure = Node3D.new()
	_figure.name = "Figuur"
	_figure.scale = Vector3.ONE * figure_scale
	add_child(_figure)
	_joints.clear()
	var parts := parts_for(archetype_id, simple, backpack)
	_height = parts.height
	var body := MeshInstance3D.new()
	body.name = "Lijf"
	body.mesh = parts.meshes.body
	body.layers = GroundShadow.FIGURE_LAYER   # its own ground shadow does not fall on it
	_figure.add_child(body)
	for limb: String in LIMBS:
		if not parts.meshes.has(limb):
			continue
		var joint := Node3D.new()
		joint.name = limb
		var parent_limb: String = PARENT_LIMB.get(limb, "")
		if _joints.has(parent_limb):
			# the elbow or the knee: placed from the shoulder or the hip, turning with it
			joint.position = parts.pivots[limb] - parts.pivots[parent_limb]
			(_joints[parent_limb] as Node3D).add_child(joint)
		else:
			joint.position = parts.pivots[limb]
			_figure.add_child(joint)
		var piece := MeshInstance3D.new()
		piece.mesh = parts.meshes[limb]
		piece.position = -parts.pivots[limb]
		piece.layers = GroundShadow.FIGURE_LAYER
		joint.add_child(piece)
		_joints[limb] = joint
	if silhouette.a > 0.0:
		var flat := StandardMaterial3D.new()
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.albedo_color = silhouette
		flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mesh_instance in _figure.find_children("*", "MeshInstance3D", true, false):
			(mesh_instance as MeshInstance3D).material_override = flat
			(mesh_instance as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Sets a limb ("arm_left", "arm_right", "leg_left", "leg_right") to this turn round its
## joint (degrees; x swings it forward and back, z out to the side), on top of the walk and
## the idle moves.
func pose_limb(limb: String, degrees: Vector3) -> void:
	_poses[limb] = degrees


## Does the figure's own move (GESTURES), facing the front; `gesture_cue` fires at the moment
## for its shout, `gesture_finished` at the end. Starting it again starts it over.
func play_gesture() -> void:
	_gesture_clock = 0.0
	_gesture_cued = false
	_turn = 0.0
	_hold = float(GESTURES.get(archetype_id, GESTURES.jos).seconds)


func is_gesturing() -> bool:
	return _gesture_clock >= 0.0


## Faces the front at once (and holds there FRONT_HOLD seconds) and turns on from there.
func face_front_now() -> void:
	_turn = 0.0
	_hold = FRONT_HOLD


## Turns back to face +z, the shortest way round, over a moment.
func face_front() -> void:
	var from := wrapf(_turn, -180.0, 180.0)
	_turn = from
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(self, "_turn", 0.0, 0.5)


## Metres from the ground to the middle of the face of an archetype.
static func face_height(id: String) -> float:
	return FACE_HEIGHT.get(id, 29.0) * VOXEL


## The box round the whole figure standing still (its limbs at rest), in its own space at its
## figure_scale: feet at y = 0, facing +z.
func rest_bounds() -> AABB:
	var parts := parts_for(archetype_id, simple, backpack)
	var bounds := AABB()
	var first := true
	for part: String in parts.meshes:
		var box: AABB = (parts.meshes[part] as ArrayMesh).get_aabb()
		if box.size == Vector3.ZERO:
			continue
		bounds = box if first else bounds.merge(box)
		first = false
	return AABB(bounds.position * figure_scale, bounds.size * figure_scale)


## The height of the figure in metres (to frame it), at its figure_scale.
func height() -> float:
	return _height * figure_scale


func _process(delta: float) -> void:
	if _figure == null:
		return
	_clock += delta
	if _hold > 0.0:
		_hold -= delta
	else:
		_turn += spin * delta
	var walk_amount := minf(walking, 1.0)
	var run := smoothstep(RUN_FROM, RUN_FULL, walking)
	_walk_clock += delta * STEPS_PER_SECOND * PI * lerpf(walking, RUN_CADENCE, run)
	var stride := sin(_walk_clock)
	var sway := 0.0
	var offset := Vector3(0.0, absf(cos(_walk_clock)) * WALK_BOB * walk_amount * (1.0 - run), 0.0)
	var angles := {}
	for limb: String in LIMBS:
		angles[limb] = Vector3.ZERO
	# the walk: legs opposite, each arm against its leg, the knee bending as the leg comes forward
	var walk_weight := walk_amount * (1.0 - run)
	angles.leg_left.x += stride * LEG_SWING * walk_weight
	angles.leg_right.x -= stride * LEG_SWING * walk_weight
	angles.shin_left.x += maxf(0.0, -cos(_walk_clock)) * WALK_KNEE * walk_weight
	angles.shin_right.x += maxf(0.0, cos(_walk_clock)) * WALK_KNEE * walk_weight
	angles.arm_left.x -= stride * ARM_SWING * walk_weight
	angles.arm_right.x += stride * ARM_SWING * walk_weight
	var lean := 0.0
	var twist := 0.0
	if run > 0.0:
		var run_pose := _run_pose(_walk_clock)
		for limb: String in run_pose:
			angles[limb] += (run_pose[limb] as Vector3) * run
		# highest between the steps (both feet off the ground), lowest as a foot lands
		offset.y += absf(stride) * RUN_BOB * run
		lean = RUN_LEAN * run
		twist = -stride * RUN_TWIST * run
	if idle:
		var still := 1.0 - walk_amount
		match archetype_id:
			"jos":
				# drunk: a slow sway from the boots up, the arms swinging loose
				sway = sin(_clock * 1.3) * 3.5 * still
				angles.arm_left.x += sin(_clock * 1.3) * 5.0 * still
				angles.arm_right.x -= sin(_clock * 1.3 + 0.6) * 5.0 * still
			"martin":
				# speed: a fast jitter, tapping one foot, the free arm twitching
				offset += Vector3(sin(_clock * 37.0), 0.0, cos(_clock * 29.0)) * 0.005
				angles.leg_right.x -= maxf(0.0, sin(_clock * 9.0)) * 8.0 * still
				angles.arm_left.z += sin(_clock * 23.0) * 3.0 * still
			"sjaan":
				# humming a tune: rocking along, the arms swinging a little with it
				sway = sin(_clock * 2.4) * 2.0 * still
				angles.arm_left.x += sin(_clock * 2.4) * 4.0 * still
				angles.arm_right.x -= sin(_clock * 2.4) * 4.0 * still
			_:
				# a slow breath, the arms hanging and moving with it
				offset.y += sin(_clock * 1.4) * 0.006 * still
				angles.arm_left.z -= (0.5 + 0.5 * sin(_clock * 1.4)) * 2.0 * still
				angles.arm_right.z += (0.5 + 0.5 * sin(_clock * 1.4)) * 2.0 * still
	if _gesture_clock >= 0.0:
		var gesture: Dictionary = GESTURES.get(archetype_id, GESTURES.jos)
		var seconds := float(gesture.seconds)
		_gesture_clock += delta
		if not _gesture_cued and _gesture_clock >= float(gesture.cue):
			_gesture_cued = true
			gesture_cue.emit()
		if _gesture_clock >= seconds:
			_gesture_clock = -1.0
			gesture_finished.emit()
		else:
			# fade from the walk into the gesture and back out of it
			var weight := clampf(minf(_gesture_clock, seconds - _gesture_clock) / GESTURE_FADE, 0.0, 1.0)
			weight = weight * weight * (3.0 - 2.0 * weight)
			var move := _gesture_pose(_gesture_clock, seconds)
			for limb: String in LIMBS:
				angles[limb] = angles[limb].lerp(move.get(limb, Vector3.ZERO), weight)
			offset = offset.lerp(move.get("offset", Vector3.ZERO), weight)
			sway = lerpf(sway, float(move.get("sway", 0.0)), weight)
			lean = lerpf(lean, float(move.get("lean", 0.0)), weight)
			twist = lerpf(twist, 0.0, weight)
	for limb: String in _joints:
		(_joints[limb] as Node3D).rotation_degrees = angles[limb] + _poses.get(limb, Vector3.ZERO)
	_figure.position = offset * figure_scale
	_figure.rotation_degrees = Vector3(lean, _turn + twist, sway)
	if walking > 0.01:
		_keep_feet_up()


## Lifts the figure so no foot goes through the ground (y = 0): a bent knee and the lean of
## the run swing the toes down.
func _keep_feet_up() -> void:
	var lowest := 0.0
	var to_model := global_transform.affine_inverse()
	for limb: String in ["shin_left", "shin_right"]:
		var joint: Node3D = _joints.get(limb)
		if joint == null or joint.get_child_count() == 0:
			continue
		var piece := joint.get_child(0) as MeshInstance3D
		lowest = minf(lowest, ((to_model * piece.global_transform) * piece.mesh.get_aabb()).position.y)
	_figure.position.y -= lowest


## The run at `phase` (radians, TAU a pair of steps; the left leg pushes back while
## sin(phase) > 0): limb -> degrees (x: negative swings forward, for the elbow forward and
## up, for the knee positive bends it, the foot going back). Each thigh drives far forward
## and pushes back less far; the knee folds deepest as the leg swings through under the
## body (the heel kicked up) and is nearly straight as the foot lands; each arm pumps
## against its leg, bent at the elbow, the hand coming up as it swings forward.
static func _run_pose(phase: float) -> Dictionary:
	var pose := {}
	for side: String in ["left", "right"]:
		var swing := sin(phase) if side == "left" else -sin(phase)            # > 0: the leg back
		var coming_forward := maxf(0.0, -cos(phase) if side == "left" else cos(phase))
		var thigh := swing * (RUN_THIGH_BACK if swing > 0.0 else RUN_THIGH_FORWARD)
		pose["leg_" + side] = Vector3(thigh, 0.0, 0.0)
		pose["shin_" + side] = Vector3(RUN_KNEE_MIN + coming_forward * (RUN_KNEE - RUN_KNEE_MIN), 0.0, 0.0)
		# the arm against the leg of its side: forward (negative) while that leg is back
		var arm := -swing * (RUN_ARM_FORWARD if swing > 0.0 else RUN_ARM_BACK)
		pose["arm_" + side] = Vector3(arm, 0.0, -4.0 if side == "left" else 4.0)
		pose["forearm_" + side] = Vector3(-RUN_ELBOW - maxf(0.0, swing) * RUN_ELBOW_PUMP, 0.0, 0.0)
	return pose


## The pose of the gesture `time` seconds in (of `seconds`): limb -> degrees (x: negative
## swings forward and up, z: positive takes the right arm (+x) out and up, negative the
## left), "offset" (metres), "sway" and "lean" (degrees: lean positive bends forward).
func _gesture_pose(time: float, seconds: float) -> Dictionary:
	var share := time / seconds
	match archetype_id:
		"jos":
			# begging: the right hand held out, palm up, leaning in a little; on the "-ro?"
			# (0.7 s) a shrug, both arms a little out, the head to one side
			var reach := clampf(time / 0.25, 0.0, 1.0)
			var shrug := sin(clampf((time - 0.7) / 0.45, 0.0, 1.0) * PI)
			return {
				"arm_right": Vector3(-70.0 * reach, 0.0, 8.0 + 22.0 * shrug),
				"arm_left": Vector3(-8.0, 0.0, -10.0 - 22.0 * shrug),
				"offset": Vector3(0.0, 0.025 * shrug, 0.0), "lean": 8.0 * reach - 4.0 * shrug,
				"sway": 5.0 * shrug + sin(time * 3.0) * 1.5,
			}
		"martin":
			# the old athlete, wired: sprinting on the spot, the arms pumping, a hop on "AL" and
			# on "ZIJN" (0.14, 0.33 s), both fists up and a big hop on "PAARS!" (0.68 s)
			var pump := sin(time * 26.0)
			var hop := 0.0
			for hop_at: float in [0.14, 0.33, 0.68]:
				var hop_seconds := 0.26 if hop_at > 0.6 else 0.15
				if time > hop_at and time < hop_at + hop_seconds:
					hop = maxf(hop, sin((time - hop_at) * PI / hop_seconds) * (1.5 if hop_at > 0.6 else 1.0))
			var cheer := clampf((time - 0.64) / 0.1, 0.0, 1.0)
			return {
				"leg_left": Vector3(pump * 45.0, 0.0, 0.0), "leg_right": Vector3(-pump * 45.0, 0.0, 0.0),
				"arm_left": Vector3(-pump * 55.0 * (1.0 - cheer), 0.0, -165.0 * cheer),
				"arm_right": Vector3(pump * 55.0 * (1.0 - cheer), 0.0, 165.0 * cheer),
				# the elbows bent while pumping, straight as the fists go up; the knees kicking up
				"forearm_left": Vector3(-80.0 * (1.0 - cheer), 0.0, 0.0), "forearm_right": Vector3(-80.0 * (1.0 - cheer), 0.0, 0.0),
				"shin_left": Vector3(15.0 + maxf(0.0, -pump) * 70.0, 0.0, 0.0), "shin_right": Vector3(15.0 + maxf(0.0, pump) * 70.0, 0.0, 0.0),
				"offset": Vector3(0.0, 0.1 * hop, 0.0), "lean": 8.0 * (1.0 - cheer),
			}
		"ufo_piloot":
			# taken up again: floating off the ground, the arms spread like wings, tilting from
			# side to side like a saucer, the legs dangling
			var rise := sin(share * PI)
			return {
				"arm_left": Vector3(0.0, 0.0, -85.0 + sin(time * 5.0) * 10.0),
				"arm_right": Vector3(0.0, 0.0, 85.0 - sin(time * 5.0) * 10.0),
				"leg_left": Vector3(sin(time * 4.0) * 12.0, 0.0, -6.0), "leg_right": Vector3(-sin(time * 4.0) * 12.0, 0.0, 6.0),
				"offset": Vector3(0.0, 0.22 * rise, 0.0), "sway": sin(time * 4.5) * 9.0,
			}
		"willem":
			# the old rat: bent over, rubbing his hands, his shoulders shaking with each "heh"
			var shake := absf(sin((time - 0.2) * PI / 0.16)) if time > 0.2 and time < 0.75 else 0.0
			return {
				"arm_left": Vector3(-45.0, 0.0, 18.0 + sin(time * 22.0) * 6.0),
				"arm_right": Vector3(-45.0, 0.0, -18.0 - sin(time * 22.0) * 6.0),
				"offset": Vector3(0.0, -0.02 - 0.025 * shake, 0.0), "lean": 14.0,
			}
		"sjaan":
			# the toilet attendant: "Ff poetsen", the right hand polishing in quick circles in
			# front of her, the left on her hip, bobbing along
			var reach := clampf(time / 0.25, 0.0, 1.0)
			return {
				"arm_right": Vector3(-65.0 * reach + sin(time * 16.0) * 12.0, 0.0, 12.0 + cos(time * 16.0) * 14.0),
				"arm_left": Vector3(-10.0, 0.0, -35.0),
				"offset": Vector3(0.0, absf(sin(time * 8.0)) * 0.02, 0.0), "sway": sin(time * 8.0) * 3.0,
			}
		_:
			# the fisherman, teasing: the right arm pointing at you, jabbing on "SCHOL" (0.4 s)
			# and on "KOP" (0.77 s), the left hand on his belly, leaning back with a laugh
			var reach := clampf(time / 0.3, 0.0, 1.0)
			var jab := 0.0
			for jab_at: float in [0.4, 0.77]:
				if time > jab_at and time < jab_at + 0.16:
					jab = maxf(jab, sin((time - jab_at) * PI / 0.16))
			var laugh := clampf((time - 0.9) / 0.2, 0.0, 1.0) * (1.0 - clampf((time - 1.3) / 0.2, 0.0, 1.0))
			return {
				"arm_right": Vector3(-80.0 * reach - 15.0 * jab, 0.0, 6.0),
				"arm_left": Vector3(-35.0, 0.0, 22.0),
				"offset": Vector3(0.0, absf(sin(time * 16.0)) * 0.02 * laugh, 0.0),
				"lean": 5.0 * jab * reach - 7.0 * laugh,
			}


# ------------------------------------------------------------------ building

## The figure of an archetype, built once: {"meshes": {"body", limbs...: ArrayMesh},
## "pivots": {limb: Vector3 joint in metres}, "height": metres}.
## `simple`: with fewer details (VoxelFigure.simplify), for the town, where it is seen from afar.
## `with_backpack`: with the rucksack on its back (BACKPACK; one picked up in the town).
static func parts_for(id: String, simple := false, with_backpack := false) -> Dictionary:
	var key := id + ("/eenvoudig" if simple else "") + ("/rugzak" if with_backpack else "")
	if not _cache.has(key):
		var figure := voxels_for(id, with_backpack)
		if simple:
			figure.simplify()
		var materials := {}
		for kind: String in CLOTH.keys() + MATERIALS.keys() + ["glow"]:
			materials[kind] = material_for(kind, true)
		_cache[key] = figure.to_parts(VOXEL, RIGS.get(id, {}), materials, graded)
	return _cache[key]


## The voxels of an archetype (its look), before they become meshes; `with_backpack`: with
## the rucksack on its back.
static func voxels_for(id: String, with_backpack := false) -> VoxelFigure:
	var figure := VoxelFigure.new()
	figure.mark("skin", [SKIN_TAN, SKIN_PALE, SKIN_GREY, SKIN_OLD])
	figure.mark("eye", [EYE_DARK, EYE_WHITE, TEETH])
	match id:
		"martin":
			_build_martin(figure)
		"ufo_piloot":
			_build_pilot(figure)
		"willem":
			_build_willem(figure)
		"sjaan":
			_build_sjaan(figure)
		"gerrit":
			_build_gerrit(figure)
		_:
			_build_jos(figure)
	if with_backpack:
		_add_backpack(figure, BACKPACK.get(id, BACKPACK.jos))
	if is_nan(figure.centre_cell.x):
		# every head is x 4..9: turn round it and frame it in the middle
		figure.centre_cell = Vector2(7.0, 3.0)
	return figure


## The material of a kind, made once and shared: the fabrics and hair the fabric shader
## with their own settings (CLOTH), the rest an ordinary material (MATERIALS), glowing parts
## unshaded.
## The material of a kind of voxel; `outlined` (the characters: the player and the
## townspeople) with the hard outline as its next pass (figure_outline.gdshader).
static func material_for(kind: String, outlined := false) -> Material:
	if outlined:
		var outlined_key := kind + "/omlijnd"
		if not _materials.has(outlined_key):
			var with_outline := material_for(kind).duplicate() as Material
			with_outline.next_pass = outline_material()
			_materials[outlined_key] = with_outline
		return _materials[outlined_key]
	if not _materials.has(kind):
		if CLOTH.has(kind):
			var settings: Dictionary = CLOTH[kind]
			var fabric := ShaderMaterial.new()
			fabric.shader = SHADER
			fabric.set_shader_parameter("pattern", settings.pattern)
			fabric.set_shader_parameter("pattern_strength", settings.strength)
			fabric.set_shader_parameter("pattern_scale", settings.scale)
			fabric.set_shader_parameter("voxel_size", VOXEL)
			fabric.set_shader_parameter("relief_depth", settings.depth)
			fabric.set_shader_parameter("weft_lightness", settings.weft)
			fabric.set_shader_parameter("slub_strength", settings.slub)
			fabric.set_shader_parameter("roughness_value", settings.roughness)
			fabric.set_shader_parameter("specular_value", settings.specular)
			fabric.set_shader_parameter("rim_value", settings.rim)
			_materials[kind] = fabric
		else:
			if kind == "glow":
				var glow := StandardMaterial3D.new()
				glow.vertex_color_use_as_albedo = true
				glow.vertex_color_is_srgb = true
				glow.cull_mode = BaseMaterial3D.CULL_DISABLED
				glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_materials[kind] = glow
			else:
				var settings: Dictionary = MATERIALS.get(kind, MATERIALS.leather)
				var plain := ShaderMaterial.new()
				plain.shader = PLAIN_SHADER
				plain.set_shader_parameter("roughness_value", settings.roughness)
				plain.set_shader_parameter("metallic_value", settings.metallic)
				plain.set_shader_parameter("specular_value", settings.specular)
				plain.set_shader_parameter("rim_value", settings.rim)
				_materials[kind] = plain
	return _materials[kind]


static var _outline: ShaderMaterial


## The hard outline round the characters (shared).
static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	return _outline


## A colour graded: SATURATION and CONTRAST (in sRGB).
static func graded(colour: Color) -> Color:
	var grey := colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722
	var result := Color(grey, grey, grey).lerp(colour, SATURATION)
	result = Color((result.r - 0.5) * CONTRAST + 0.5, (result.g - 0.5) * CONTRAST + 0.5, (result.b - 0.5) * CONTRAST + 0.5)
	return Color(clampf(result.r, 0.0, 1.0), clampf(result.g, 0.0, 1.0), clampf(result.b, 0.0, 1.0))


## Voxels by cell (x across, y up, z from the front backwards), each a colour, which of
## them glow, and the kind of material of each colour.
class VoxelFigure:
	var cells := {}
	var glowing := {}
	var kinds := {}               # Color -> kind of material
	## The cell (x, z) the figure turns round and is centred on; unset (NAN) = the middle of
	## all its voxels (parts_for sets the middle of the head for every figure).
	var centre_cell := Vector2(NAN, NAN)
	## Without the shading of the faces (darker sides and below, ambient occlusion): every
	## face its colour as it is, so white stays white (the Zebraklok); the light of the
	## scene still shades it.
	var flat_shading := false
	## Faces side by side in one plane, of one colour and material and an even shade (no
	## ambient occlusion across them), drawn as one rectangle (greedy meshing): far fewer
	## triangles, the same look. Off: a face per voxel side (to compare).
	var merge_faces := true

	func put(x: int, y: int, z: int, colour: Color, glow := false) -> void:
		var cell := Vector3i(x, y, z)
		cells[cell] = colour
		if glow:
			glowing[cell] = true
		else:
			glowing.erase(cell)

	## Fills the box between both corners (included).
	func box(from: Vector3i, to: Vector3i, colour: Color, glow := false) -> void:
		for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
			for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
				for z in range(mini(from.z, to.z), maxi(from.z, to.z) + 1):
					put(x, y, z, colour, glow)

	func clear(x: int, y: int, z: int) -> void:
		cells.erase(Vector3i(x, y, z))
		glowing.erase(Vector3i(x, y, z))

	func has(x: int, y: int, z: int) -> bool:
		return cells.has(Vector3i(x, y, z))

	## These colours are of this kind of material (MATERIALS).
	func mark(kind: String, colours: Array) -> void:
		for colour: Color in colours:
			kinds[colour] = kind

	## The kind of a colour: as marked, else that of the nearest marked colour (a darker or
	## lighter shade of it), else cloth.
	func kind_of(colour: Color) -> String:
		if kinds.has(colour):
			return kinds[colour]
		var nearest := "cloth"
		var nearest_distance := 0.16
		for marked: Color in kinds:
			var distance := Vector3(marked.r - colour.r, marked.g - colour.g, marked.b - colour.b).length()
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = kinds[marked]
		return nearest

	## Fewer details, for a figure seen from afar (the town): colours that are nearly the same
	## (shades of one fabric, dirt, slubs) become the one used most, and a lone voxel of
	## another colour among its neighbours (a button, a stitch, a speck) takes theirs, `passes`
	## times; the eyes and glowing voxels stay. The shape stays as it is.
	func simplify(passes := 2) -> void:
		# nearly equal colours -> the most used of them
		var counts := {}
		for cell: Vector3i in cells:
			counts[cells[cell]] = counts.get(cells[cell], 0) + 1
		var by_use: Array = counts.keys()
		by_use.sort_custom(func(first: Color, second: Color) -> bool: return counts[first] > counts[second])
		var merged := {}
		for colour: Color in by_use:
			merged[colour] = colour
			if kind_of(colour) == "eye":
				continue
			for main: Color in by_use:
				if counts[main] <= counts[colour]:
					break
				if merged[main] == main and kind_of(main) == kind_of(colour) \
						and Vector3(main.r - colour.r, main.g - colour.g, main.b - colour.b).length() < SIMPLE_COLOUR_DISTANCE:
					merged[colour] = main
					break
		for cell: Vector3i in cells:
			cells[cell] = merged[cells[cell]]
		# lone voxels take the colour round them
		var sides := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
		for pass_index in passes:
			var changes := {}
			for cell: Vector3i in cells:
				var colour: Color = cells[cell]
				if glowing.has(cell) or kind_of(colour) == "eye":
					continue
				var round_it := {}
				var same := 0
				for side: Vector3i in sides:
					if cells.has(cell + side):
						var other: Color = cells[cell + side]
						if other == colour:
							same += 1
						elif kind_of(other) != "eye":
							round_it[other] = round_it.get(other, 0) + 1
				if same > 1:
					continue
				for other: Color in round_it:
					if round_it[other] >= 3:
						changes[cell] = other
			for cell: Vector3i in changes:
				cells[cell] = changes[cell]

	## The body and the limbs (`rig`: limb -> boxes of cells, RIGS) as meshes: only the
	## faces between a voxel and air (of any part, so a limb's faces against the body are
	## drawn and it can move away from it), a surface per kind of material, centred on x
	## and z, standing on y = 0, the front (z = 0) towards +z; the joint of each limb at
	## the top of it, in its middle.
	## `materials`: kind -> Material; `grade`: a Callable(Color) -> Color for every colour.
	func to_parts(voxel: float, rig: Dictionary, materials: Dictionary, grade: Callable) -> Dictionary:
		return VoxelFigure.parts_from(to_faces(voxel, rig, grade), materials)

	## The meshes of `faces` (to_faces), each surface in its material from `materials` (kind ->
	## Material; cloth where the kind has none): {"meshes", "pivots", "height"} as to_parts.
	static func parts_from(faces: Dictionary, materials: Dictionary) -> Dictionary:
		var meshes := {}
		for key: String in faces.surfaces:
			var part := key.get_slice("/", 0)
			var kind := key.get_slice("/", 1)
			if not meshes.has(part):
				meshes[part] = ArrayMesh.new()
			(faces.surfaces[key] as FaceArrays).commit(meshes[part], materials.get(kind, materials.cloth))
		if not meshes.has("body"):
			meshes["body"] = ArrayMesh.new()
		return {"meshes": meshes, "pivots": faces.pivots, "height": faces.height}

	## The work of to_parts without making any meshes or materials (so it can run on a thread
	## of its own, TownsfolkFigure.prepare): {"surfaces": "part/kind" -> FaceArrays, "pivots",
	## "height"}; parts_from makes the meshes of it.
	func to_faces(voxel: float, rig: Dictionary, grade: Callable) -> Dictionary:
		var lowest := Vector3i(1 << 20, 1 << 20, 1 << 20)
		var highest := -lowest
		for cell: Vector3i in cells:
			lowest = Vector3i(mini(lowest.x, cell.x), mini(lowest.y, cell.y), mini(lowest.z, cell.z))
			highest = Vector3i(maxi(highest.x, cell.x), maxi(highest.y, cell.y), maxi(highest.z, cell.z))
		var centre := Vector3((lowest.x + highest.x + 1) * 0.5, lowest.y, (lowest.z + highest.z + 1) * 0.5)
		if not is_nan(centre_cell.x):
			centre = Vector3(centre_cell.x, lowest.y, centre_cell.y)
		# which part each cell is in
		var part_of := {}
		var part_cells := {"body": []}
		for limb: String in rig:
			part_cells[limb] = []
		for cell: Vector3i in cells:
			var part := "body"
			for limb: String in rig:
				for bounds: Array in rig[limb]:
					if cell.x >= bounds[0] and cell.x <= bounds[3] and cell.y >= bounds[1] and cell.y <= bounds[4] \
							and cell.z >= bounds[2] and cell.z <= bounds[5]:
						part = limb
			part_of[cell] = part
			part_cells[part].append(cell)
		# the cells of each part as a set (for the outward direction of the corners)
		var part_sets := {}
		for part_name: String in part_cells:
			var cell_set := {}
			for part_cell: Vector3i in part_cells[part_name]:
				cell_set[part_cell] = true
			part_sets[part_name] = cell_set
		# the faces, by part and kind
		var kind_cache := {}          # Color -> kind
		var grade_cache := {}         # Color -> graded Color
		var surfaces := {}            # "part/kind" -> FaceArrays
		var outward_caches := {}      # part -> {grid corner -> outward direction}
		var part_rects := {}          # part -> its faces as rectangles (FaceRect)
		for part_name: String in part_sets:
			outward_caches[part_name] = {}
			part_rects[part_name] = []
		# faces of one colour and an even shade, by surface, side and layer (merge_faces)
		var to_merge := {}            # [key, side, layer] -> {Vector2i (u, v) -> [cell, colour, level]}
		for cell: Vector3i in cells:
			var colour: Color = cells[cell]
			if not kind_cache.has(colour):
				kind_cache[colour] = kind_of(colour)
				grade_cache[colour] = grade.call(colour)
			var kind: String = "glow" if glowing.has(cell) else kind_cache[colour]
			var part: String = part_of[cell]
			var key := part + "/" + kind
			if not surfaces.has(key):
				surfaces[key] = FaceArrays.new()
			for side: Vector3i in SIDES:
				var next := cell + side
				if cells.has(next) and part_of[next] == part:
					continue
				var levels := _corner_levels(cell, side, cells, flat_shading)
				var even := levels[0] == levels[1] and levels[1] == levels[2] and levels[2] == levels[3]
				if merge_faces and even:
					var table: Dictionary = _face_table(side)
					var plane_key := [key, side, cell[table.axis]]
					if not to_merge.has(plane_key):
						to_merge[plane_key] = {}
					to_merge[plane_key][Vector2i(cell[table.u_axis], cell[table.v_axis])] = [cell, grade_cache[colour], levels[0]]
				else:
					part_rects[part].append(FaceRect.new(key, side, cell, Vector3i.ONE, grade_cache[colour], levels))
		for plane_key: Array in to_merge:
			var part: String = (plane_key[0] as String).get_slice("/", 0)
			_merge_plane(to_merge[plane_key], plane_key[0], plane_key[1], part_rects[part])
		for part_name: String in part_rects:
			var rects: Array = part_rects[part_name]
			for rect: FaceRect in rects:
				rect.find_outwards(outward_caches[part_name], part_sets[part_name])
			_close_outline(rects)
			for rect: FaceRect in rects:
				rect.add_to(surfaces[rect.key], centre, voxel, flat_shading)
		# the joints: the middle of the top of each limb
		var pivots := {}
		for limb: String in rig:
			var limb_cells: Array = part_cells[limb]
			if limb_cells.is_empty():
				continue
			var top := -(1 << 20)
			for cell: Vector3i in limb_cells:
				top = maxi(top, cell.y)
			var low := Vector3(INF, 0, INF)
			var high := Vector3(-INF, 0, -INF)
			for cell: Vector3i in limb_cells:
				if cell.y >= top - 1:
					low = Vector3(minf(low.x, cell.x), 0, minf(low.z, cell.z))
					high = Vector3(maxf(high.x, cell.x + 1), 0, maxf(high.z, cell.z + 1))
			var joint := Vector3((low.x + high.x) * 0.5, top + 0.5, (low.z + high.z) * 0.5) - centre
			pivots[limb] = Vector3(joint.x, joint.y, -joint.z) * voxel
		return {"surfaces": surfaces, "pivots": pivots, "height": (highest.y + 1 - lowest.y) * voxel}

	## The six sides of a voxel, in the order its faces are added.
	const SIDES: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]

	## The light on each kind of face: the top full, the front and back less, the left and
	## right sides less again, the bottom least (strong steps: blocks of one colour stay apart).
	const FACE_LIGHT := {Vector3i.UP: 1.0, Vector3i.BACK: 0.76, Vector3i.FORWARD: 0.76,
		Vector3i.RIGHT: 0.64, Vector3i.LEFT: 0.64, Vector3i.DOWN: 0.48}

	## How much each level of corner occlusion darkens a vertex (0 = open .. 3 = shut in).
	const OCCLUSION := [1.0, 0.8, 0.66, 0.52]

	## The ambient occlusion level (0 open .. 3 shut in) of each corner of the face of `cell` on
	## `side`, in the order of its table (_face_table); all 0 for flat shading.
	static func _corner_levels(cell: Vector3i, side: Vector3i, cells: Dictionary, flat: bool) -> PackedInt32Array:
		var levels := PackedInt32Array([0, 0, 0, 0])
		if flat:
			return levels
		var table: Dictionary = _face_table(side)
		var outside := cell + side
		for corner_index in 4:
			var along: Vector3i = table.along[corner_index]
			var across: Vector3i = table.across[corner_index]
			var first := cells.has(outside + along)
			var second := cells.has(outside + across)
			levels[corner_index] = 3 if first and second else int(first) + int(second) + int(cells.has(outside + along + across))
		return levels

	## Greedy meshing of the even faces in one plane (`faces`: (u, v) -> [cell, colour, level]):
	## runs of the same colour and level along u, then grown along v while every row matches,
	## each a FaceRect in `rects`.
	static func _merge_plane(faces: Dictionary, key: String, side: Vector3i, rects: Array) -> void:
		var table: Dictionary = _face_table(side)
		var spots: Array = faces.keys()
		spots.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
			return first.y < second.y or (first.y == second.y and first.x < second.x))
		var used := {}
		for spot: Vector2i in spots:
			if used.has(spot):
				continue
			var face: Array = faces[spot]
			var same := func(other: Vector2i) -> bool:
				if used.has(other) or not faces.has(other):
					return false
				var other_face: Array = faces[other]
				return other_face[1] == face[1] and other_face[2] == face[2]
			var width := 1
			while same.call(spot + Vector2i(width, 0)):
				width += 1
			var height := 1
			var growing := true
			while growing:
				for step in width:
					if not same.call(spot + Vector2i(step, height)):
						growing = false
						break
				if growing:
					height += 1
			for row in height:
				for step in width:
					used[spot + Vector2i(step, row)] = true
			var extent := Vector3i.ONE
			extent[table.u_axis] = width
			extent[table.v_axis] = height
			var level: int = face[2]
			rects.append(FaceRect.new(key, side, face[0], extent, face[1], PackedInt32Array([level, level, level, level])))

	## Where a corner of one rectangle lies on the edge of another (a T-junction, now that
	## faces are merged), its outward direction becomes the one of that edge there, so the
	## outline's shell (figure_outline.gdshader pushes every corner out along it) stays closed
	## without cracks. Pass after pass till nothing changes (at most 12), as such corners can
	## lie on such edges in turn.
	static func _close_outline(rects: Array) -> void:
		# the edges by the line they lie on: [axis, the two other coordinates]
		var lines := {}
		for rect: FaceRect in rects:
			for corner_index in 4:
				var next_index := (corner_index + 1) % 4
				var start: Vector3i = rect.corners[corner_index]
				var end: Vector3i = rect.corners[next_index]
				var axis := 0 if start.x != end.x else (1 if start.y != end.y else 2)
				var line_key := _line_key(start, axis)
				if not lines.has(line_key):
					lines[line_key] = []
				if start[axis] < end[axis]:
					lines[line_key].append([start[axis], end[axis], rect, corner_index, next_index])
				else:
					lines[line_key].append([end[axis], start[axis], rect, next_index, corner_index])
		# the corners in a T, once: [rect, corner, the edge's rect, its first and last corner, how far along]
		var junctions := []
		for rect: FaceRect in rects:
			for corner_index in 4:
				var point: Vector3i = rect.corners[corner_index]
				for axis in 3:
					for edge: Array in lines.get(_line_key(point, axis), []):
						if point[axis] > edge[0] and point[axis] < edge[1]:
							junctions.append([rect, corner_index, edge[2], edge[3], edge[4],
								float(point[axis] - edge[0]) / float(edge[1] - edge[0])])
		for pass_index in 12:
			var changed := false
			for junction: Array in junctions:
				var rect: FaceRect = junction[0]
				var edge_rect: FaceRect = junction[2]
				var way: Vector3 = edge_rect.outwards[junction[3]].lerp(edge_rect.outwards[junction[4]], junction[5])
				if not way.is_equal_approx(rect.outwards[junction[1]]):
					rect.outwards[junction[1]] = way
					changed = true
			if not changed:
				return

	static func _line_key(point: Vector3i, axis: int) -> Vector3i:
		var line_key := point
		line_key[axis] = -(1 << 20) + axis   # the same for every point on the line
		return line_key


	## One face of the voxel `cell` (placed at `corner`, in voxels, z running backwards) on
	## `side`, each of its corners darkened by the voxels round it (ambient occlusion: in a
	## corner or a gap it gets less light), as voxel art does.
	static func _add_face(faces: FaceArrays, cell: Vector3i, corner: Vector3, side: Vector3i, colour: Color,
			voxel: float, cells: Dictionary, flat := false, part_set := {}, outward_cache := {}) -> void:
		var table: Dictionary = _face_table(side)
		var normal: Vector3 = table.normal
		# light from above, each kind of face its own level (FACE_LIGHT), so faces of one colour
		# that meet at an edge still read apart
		var light := 1.0 if flat else float(table.light)
		var points: Array = table.points
		var grid: Array = table.grid
		var alongs: Array = table.along
		var acrosses: Array = table.across
		var placed: Array[Vector3] = []
		var shades: Array[Color] = []
		var outwards: Array[Color] = []
		var outside := cell + side
		for corner_index in 4:
			var at: Vector3 = corner + points[corner_index]
			placed.append(Vector3(at.x, at.y, -at.z) * voxel)
			# the two neighbours along the face at this corner and the one diagonal to it
			var level := 0
			if not flat:
				var along: Vector3i = alongs[corner_index]
				var across: Vector3i = acrosses[corner_index]
				var first := cells.has(outside + along)
				var second := cells.has(outside + across)
				level = 3 if first and second else int(first) + int(second) + int(cells.has(outside + along + across))
			var shade: float = light * OCCLUSION[level]
			shades.append(Color(colour.r * shade, colour.g * shade, colour.b * shade))
			# each corner's outward direction, for the outline (figure_outline.gdshader); a
			# grid corner is shared by several faces, so it is worked out once
			var grid_point: Vector3i = cell + grid[corner_index]
			if not outward_cache.has(grid_point):
				outward_cache[grid_point] = _outward_way(grid_point, part_set)
			var way: Vector3 = outward_cache[grid_point]
			if way.length_squared() < 0.0001:
				way = normal   # not clear here: the face's own normal
			way = way.normalized()
			outwards.append(Color(way.x, way.y, way.z))
		# the mirror flips the winding: draw the triangles the other way round; split the
		# quad along the diagonal that keeps the occlusion smooth
		var order: Array = FACE_ORDER
		if shades[0].v + shades[2].v < shades[1].v + shades[3].v:
			order = FACE_ORDER_TURNED
		faces.add_face(order, placed, normal, shades, table.uvs, outwards)


	## The two ways of cutting a face into triangles (see _add_face).
	const FACE_ORDER := [0, 2, 1, 0, 3, 2]
	const FACE_ORDER_TURNED := [1, 3, 2, 1, 0, 3]
	static var _face_tables := {}

	## Fills the tables of all six sides (_face_table) at once: a thread building faces
	## (TownsfolkFigure.prepare) then only reads them.
	static func fill_face_tables() -> void:
		for side: Vector3i in SIDES:
			_face_table(side)

	## What stays the same for every face on `side`: its four corners in the voxel (0..1), the
	## grid corners, per corner the neighbours along and across the face (ambient occlusion),
	## where in the face each corner is (uv: 0..1, v up the sides), the normal (z mirrored, so
	## the front, z = 0, faces +z) and its light (FACE_LIGHT).
	static func _face_table(side: Vector3i) -> Dictionary:
		if _face_tables.has(side):
			return _face_tables[side]
		var points: Array
		match side:
			Vector3i.RIGHT:
				points = [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)]
			Vector3i.LEFT:
				points = [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)]
			Vector3i.UP:
				points = [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)]
			Vector3i.DOWN:
				points = [Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)]
			Vector3i.BACK:
				points = [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)]
			_:
				points = [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)]
		# the axis across the face (its layer) and the two along it
		var axis := 0 if side.x != 0 else (1 if side.y != 0 else 2)
		var table := {"points": points, "grid": [], "along": [], "across": [], "uvs": PackedVector2Array(),
			"normal": Vector3(side.x, side.y, -side.z), "light": float(FACE_LIGHT.get(side, 0.8)),
			"axis": axis, "u_axis": (axis + 1) % 3, "v_axis": (axis + 2) % 3}
		for point: Vector3 in points:
			table.grid.append(Vector3i(point))
			if side.x != 0:
				table.along.append(Vector3i(0, int(point.y) * 2 - 1, 0))
				table.across.append(Vector3i(0, 0, int(point.z) * 2 - 1))
				table.uvs.append(Vector2(point.z, point.y))
			elif side.y != 0:
				table.along.append(Vector3i(int(point.x) * 2 - 1, 0, 0))
				table.across.append(Vector3i(0, 0, int(point.z) * 2 - 1))
				table.uvs.append(Vector2(point.x, point.z))
			else:
				table.along.append(Vector3i(int(point.x) * 2 - 1, 0, 0))
				table.across.append(Vector3i(0, int(point.y) * 2 - 1, 0))
				table.uvs.append(Vector2(point.x, point.y))
		_face_tables[side] = table
		return table


	## The outward direction at the grid corner `grid_point` (the corner between the eight
	## voxels round it): towards the empty ones of its part, mirrored in z as the faces are,
	## not normalised; zero when it is not clear (then the face's normal is used).
	static func _outward_way(grid_point: Vector3i, part_set: Dictionary) -> Vector3:
		var way := Vector3.ZERO
		if not part_set.is_empty():
			for dx in [-1, 0]:
				for dy in [-1, 0]:
					for dz in [-1, 0]:
						var around := grid_point + Vector3i(dx, dy, dz)
						if not part_set.has(around):
							way += Vector3(dx + 0.5, dy + 0.5, dz + 0.5)
		return Vector3(way.x, way.y, -way.z)


## One face of a figure as a rectangle of `extent` voxel faces (1 x 1: a single one) from
## the voxel `cell` on `side`: its four grid corners (in the order of VoxelFigure._face_table),
## the shade level of each and their outward directions for the outline.
class FaceRect:
	var key: String
	var side: Vector3i
	var colour: Color
	var levels: PackedInt32Array
	var corners: Array[Vector3i] = []
	var outwards: Array[Vector3] = []
	var extent: Vector3i

	func _init(surface_key: String, face_side: Vector3i, cell: Vector3i, face_extent: Vector3i, face_colour: Color,
			corner_levels: PackedInt32Array) -> void:
		key = surface_key
		side = face_side
		colour = face_colour
		levels = corner_levels
		extent = face_extent
		var table: Dictionary = VoxelFigure._face_table(side)
		for corner_index in 4:
			var grid: Vector3i = table.grid[corner_index]
			corners.append(cell + Vector3i(grid.x * extent.x, grid.y * extent.y, grid.z * extent.z))

	## Each corner's outward direction (VoxelFigure._outward_way, worked out once per grid
	## corner in `cache`), the face's normal where it is not clear; of length 1.
	func find_outwards(cache: Dictionary, part_set: Dictionary) -> void:
		var normal: Vector3 = VoxelFigure._face_table(side).normal
		outwards.clear()
		for corner: Vector3i in corners:
			if not cache.has(corner):
				cache[corner] = VoxelFigure._outward_way(corner, part_set)
			var way: Vector3 = cache[corner]
			if way.length_squared() < 0.0001:
				way = normal
			outwards.append(way.normalized())

	## Its two triangles into `faces`, placed round `centre` (in voxels, z mirrored so the
	## front faces +z), shaded per corner (FACE_LIGHT, OCCLUSION).
	func add_to(faces: FaceArrays, centre: Vector3, voxel: float, flat: bool) -> void:
		var table: Dictionary = VoxelFigure._face_table(side)
		var light := 1.0 if flat else float(table.light)
		var placed: Array[Vector3] = []
		var shades: Array[Color] = []
		var corner_outwards: Array[Color] = []
		var uvs := PackedVector2Array()
		for corner_index in 4:
			var at := Vector3(corners[corner_index]) - centre
			placed.append(Vector3(at.x, at.y, -at.z) * voxel)
			var shade: float = light * VoxelFigure.OCCLUSION[levels[corner_index]]
			shades.append(Color(colour.r * shade, colour.g * shade, colour.b * shade))
			var way: Vector3 = outwards[corner_index]
			corner_outwards.append(Color(way.x, way.y, way.z))
			# where in the face this corner is (as for one voxel: u, v up the sides), in voxels
			var face_size := Vector2(extent.x, extent.y)
			if side.x != 0:
				face_size = Vector2(extent.z, extent.y)
			elif side.y != 0:
				face_size = Vector2(extent.x, extent.z)
			uvs.append((table.uvs[corner_index] as Vector2) * face_size)
		# the mirror flips the winding: the triangles the other way round; cut along the
		# diagonal that keeps the occlusion smooth
		var order: Array = VoxelFigure.FACE_ORDER
		if shades[0].v + shades[2].v < shades[1].v + shades[3].v:
			order = VoxelFigure.FACE_ORDER_TURNED
		faces.add_face(order, placed, table.normal, shades, uvs, corner_outwards)


## The faces of one surface of a figure (a part in one kind of material) as they are added
## (VoxelFigure._add_face), in plain arrays: much quicker than a SurfaceTool vertex by vertex.
## CUSTOM0 holds each corner's outward direction (figure_outline.gdshader).
class FaceArrays:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var outwards := PackedFloat32Array()

	## One face: its two triangles, the corners (0..3) in `order`.
	func add_face(order: Array, corners: Array[Vector3], normal: Vector3, shades: Array[Color],
			corner_uvs: PackedVector2Array, corner_outwards: Array[Color]) -> void:
		for index: int in order:
			vertices.append(corners[index])
			normals.append(normal)
			colours.append(shades[index])
			uvs.append(corner_uvs[index])
			var outward: Color = corner_outwards[index]
			outwards.append(outward.r)
			outwards.append(outward.g)
			outwards.append(outward.b)

	## Adds these faces to `mesh` as a surface with `material`.
	func commit(mesh: ArrayMesh, material: Material) -> void:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_CUSTOM0] = outwards
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
			Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)


# ------------------------------------------------------------------ the figures

const SKIN_TAN := Color("#C68A62")
const SKIN_PALE := Color("#E4BE9C")
const SKIN_GREY := Color("#B7A68E")
const SKIN_OLD := Color("#E2B79A")
const EYE_DARK := Color("#1A1420")
const EYE_WHITE := Color("#EEEAE0")
const TEETH := Color("#E6DDBE")
## The rucksack: its canvas and flap, how deep it is (voxels) and per figure where it sits
## (z of the first voxel behind its back, lowest and highest y: clear of the hair, the hat
## and the arms).
const BACKPACK_CANVAS := Color("#5E6440")
const BACKPACK_FLAP := Color("#3E4228")
const BACKPACK_DEPTH := 3
const BACKPACK := {
	"jos": Vector3i(6, 13, 22),
	"martin": Vector3i(3, 15, 23),
	"ufo_piloot": Vector3i(4, 15, 23),
	"willem": Vector3i(5, 11, 19),
	"sjaan": Vector3i(4, 14, 21),
	"gerrit": Vector3i(4, 15, 23),
}


## The rucksack (picked up in the town: PlayerController.pick_up_backpack): a plain canvas
## block on the back, x 4..9 (between the arms), from just behind the back `depth` voxels
## deep, its flap on top in a darker shade.
## `place`: Vector3i(z of the first voxel behind the back, lowest y, highest y).
static func _add_backpack(figure: VoxelFigure, place: Vector3i) -> void:
	var back_z := place.x
	figure.box(Vector3i(4, place.y, back_z), Vector3i(9, place.z, back_z + BACKPACK_DEPTH - 1), BACKPACK_CANVAS)
	figure.box(Vector3i(4, place.z - 1, back_z), Vector3i(9, place.z, back_z + BACKPACK_DEPTH - 1), BACKPACK_FLAP)
	figure.mark("cloth", [BACKPACK_CANVAS, BACKPACK_FLAP])


## A head of x left_x..left_x+5 from y bottom to bottom+6, `depth` deep: rounded corners,
## the chin in, ears and a nose that sticks out. The caller adds the face and hair.
static func _head(figure: VoxelFigure, left_x: int, bottom: int, skin: Color, depth := 6) -> void:
	figure.box(Vector3i(left_x, bottom, 0), Vector3i(left_x + 5, bottom + 6, depth - 1), skin)
	for corner_x in [left_x, left_x + 5]:
		for corner_z in [0, depth - 1]:
			figure.clear(corner_x, bottom, corner_z)
			figure.clear(corner_x, bottom + 6, corner_z)
	for x in [left_x, left_x + 5]:
		figure.clear(x, bottom, 1)
	figure.box(Vector3i(left_x - 1, bottom + 2, 2), Vector3i(left_x - 1, bottom + 3, 3), skin.darkened(0.08))
	figure.box(Vector3i(left_x + 6, bottom + 2, 2), Vector3i(left_x + 6, bottom + 3, 3), skin.darkened(0.08))
	figure.box(Vector3i(left_x + 2, bottom + 2, -1), Vector3i(left_x + 3, bottom + 3, -1), skin.darkened(0.05))


## Jos: sturdy, a belly, a long coat. Few details: plain colours, no small voxels.
static func _build_jos(figure: VoxelFigure) -> void:
	var boot := Color("#5E3A22")
	var boot_dark := Color("#30200F")
	var jeans := Color("#43587A")
	var shirt := Color("#9A3A36")
	var coat := Color("#6B5236")
	var coat_dark := Color("#4A3824")
	var rope := Color("#B9A27A")
	var hat := Color("#7A6448")
	var hat_band := Color("#3A3028")
	var hair := Color("#9C968C")
	var glove := Color("#4E4A48")
	var nose := Color("#C8463E")
	# boots with a dark sole
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 3, 3), boot)
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 0, 3), boot_dark)
	# jeans, a gap between the legs
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 4, 0), Vector3i(leg_x + 2, 12, 3), jeans)
	# rope for a belt
	figure.box(Vector3i(2, 13, -1), Vector3i(11, 13, 4), rope)
	# a red shirt over a belly
	figure.box(Vector3i(2, 14, 0), Vector3i(11, 22, 4), shirt)
	figure.box(Vector3i(3, 14, -1), Vector3i(10, 18, -1), shirt)
	figure.box(Vector3i(4, 15, -2), Vector3i(9, 17, -2), shirt)
	# the long coat: open in front, down to the knees, the collar up
	for y in range(6, 24):
		for z in range(0, 6):
			for x in [1, 2, 11, 12]:
				if y >= 14 or z >= 1:
					figure.put(x, y, z, coat)
		for x in range(1, 13):
			figure.put(x, y, 5, coat)
	figure.box(Vector3i(2, 14, -1), Vector3i(3, 22, -1), coat)
	figure.box(Vector3i(10, 14, -1), Vector3i(11, 22, -1), coat)
	figure.box(Vector3i(2, 23, -1), Vector3i(3, 24, 5), coat_dark)        # collar up
	figure.box(Vector3i(10, 23, -1), Vector3i(11, 24, 5), coat_dark)
	figure.box(Vector3i(3, 23, 5), Vector3i(10, 24, 5), coat_dark)
	# sleeves of the coat (a gap to the body, joined at the shoulder), fingerless gloves
	figure.box(Vector3i(-1, 22, 1), Vector3i(0, 23, 4), coat)
	figure.box(Vector3i(13, 22, 1), Vector3i(14, 23, 4), coat)
	for arm_x in [-2, 14]:
		figure.box(Vector3i(arm_x, 14, 1), Vector3i(arm_x + 1, 23, 4), coat)
		figure.box(Vector3i(arm_x, 11, 1), Vector3i(arm_x + 1, 13, 3), glove)
	# neck and head: weathered, a red nose
	figure.box(Vector3i(6, 24, 2), Vector3i(7, 24, 3), SKIN_TAN)
	_head(figure, 4, 25, SKIN_TAN)
	figure.box(Vector3i(6, 27, -1), Vector3i(7, 28, -1), nose)
	figure.put(5, 29, 0, EYE_DARK)
	figure.put(8, 29, 0, EYE_DARK)
	# a scruffy grey beard over the jaw and down the neck
	figure.box(Vector3i(4, 25, -1), Vector3i(9, 26, -1), hair)
	figure.box(Vector3i(4, 25, 0), Vector3i(9, 27, 0), hair)
	figure.box(Vector3i(5, 23, -1), Vector3i(8, 24, -1), hair)
	# long matted grey hair
	figure.box(Vector3i(3, 24, 5), Vector3i(10, 31, 6), hair)
	figure.box(Vector3i(3, 27, 3), Vector3i(3, 31, 4), hair)
	figure.box(Vector3i(10, 27, 3), Vector3i(10, 31, 4), hair)
	# the battered cowboy hat: the brim drooping at the front, a dark band
	for x in range(0, 14):
		for z in range(-3, 9):
			var corner := (x <= 1 or x >= 12) and (z <= -2 or z >= 7)
			if not corner:
				figure.put(x, 31 if z <= -2 else 32, z, hat)
	figure.box(Vector3i(3, 33, 0), Vector3i(10, 33, 5), hat_band)
	figure.box(Vector3i(3, 34, 0), Vector3i(10, 36, 5), hat)
	figure.box(Vector3i(4, 37, 1), Vector3i(9, 37, 4), hat)
	figure.mark("cloth", [shirt, coat, coat_dark, rope, hat, hat_band])
	figure.mark("denim", [jeans])
	figure.mark("knit", [glove])
	figure.mark("leather", [boot, boot_dark])
	figure.mark("hair", [hair])
	figure.mark("skin", [nose])


## Martin: once a top athlete, now skin and bone, restless in his faded old tracksuit.
## Few details: the jacket one colour (sleeves and collar the same), plain trousers.
static func _build_martin(figure: VoxelFigure) -> void:
	var suit := Color("#4E8C84")
	var pants := Color("#4E4068")
	var trainer := Color("#A8A498")
	var sole := Color("#5A5650")
	var hair := Color("#E8D47A")
	var shades := Color("#1A1A20")
	# grey trainers
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 1, 3), trainer)
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 0, 3), sole)
	# legs three voxels wide like the others', the trousers hanging off them
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 2, 13, 1), pants)
	figure.box(Vector3i(3, 13, 0), Vector3i(10, 14, 1), pants)
	# a narrow chest (no wider than his head) in the tracksuit jacket, the collar up: all one colour
	figure.box(Vector3i(4, 15, 0), Vector3i(9, 23, 2), suit)
	figure.box(Vector3i(4, 24, 0), Vector3i(9, 25, 2), suit)
	# thin arms, two voxels like the others' slimmest, a gap to the body (joined at the
	# shoulder), the hands bare
	figure.box(Vector3i(3, 21, 0), Vector3i(3, 23, 1), suit)
	figure.box(Vector3i(10, 21, 0), Vector3i(10, 23, 1), suit)
	for arm_x: int in [1, 11]:
		figure.box(Vector3i(arm_x, 15, 0), Vector3i(arm_x + 1, 23, 1), suit)
	figure.box(Vector3i(1, 13, 0), Vector3i(2, 14, 1), SKIN_PALE)
	figure.box(Vector3i(11, 13, 0), Vector3i(12, 14, 1), SKIN_PALE)
	# a thin neck and a gaunt, clean-shaven face: wide eyes, a small tight grin
	figure.box(Vector3i(6, 26, 1), Vector3i(7, 26, 2), SKIN_PALE)
	_head(figure, 4, 27, SKIN_PALE)
	for eye_x in [4, 8]:
		figure.box(Vector3i(eye_x, 30, 0), Vector3i(eye_x + 1, 31, 0), EYE_WHITE)
	figure.box(Vector3i(5, 30, 0), Vector3i(5, 31, 0), EYE_DARK)
	figure.box(Vector3i(8, 30, 0), Vector3i(8, 31, 0), EYE_DARK)
	figure.box(Vector3i(6, 28, 0), Vector3i(7, 28, 0), TEETH)                   # the grin
	# sunglasses on the forehead
	figure.box(Vector3i(3, 34, -1), Vector3i(10, 34, -1), shades)
	# a blond mullet: short and flat on top, short at the sides above the ears, long down
	# the back of the neck to the collar
	figure.box(Vector3i(4, 34, 0), Vector3i(9, 34, 5), hair)
	figure.box(Vector3i(4, 35, 1), Vector3i(9, 35, 5), hair)
	figure.box(Vector3i(3, 31, 1), Vector3i(3, 33, 5), hair)
	figure.box(Vector3i(10, 31, 1), Vector3i(10, 33, 5), hair)
	figure.box(Vector3i(3, 27, 4), Vector3i(3, 30, 5), hair)                    # long behind the ears
	figure.box(Vector3i(10, 27, 4), Vector3i(10, 30, 5), hair)
	figure.box(Vector3i(4, 26, 6), Vector3i(9, 34, 6), hair)                    # the back, down the neck
	figure.box(Vector3i(3, 26, 6), Vector3i(10, 28, 7), hair)
	figure.mark("nylon", [suit, pants])
	figure.mark("plastic", [trainer, sole, shades])
	figure.mark("hair", [hair])


## The ufo pilot: an ordinary man, skinny, in an old aviator jacket (where his nickname
## partly comes from) over a grey hoodie. Few details: plain colours, no small voxels.
static func _build_pilot(figure: VoxelFigure) -> void:
	var leather := Color("#6A4428")
	var fleece := Color("#DCCFB2")
	var hoodie := Color("#707074")
	var jeans := Color("#3E4A5E")
	var shoe := Color("#3A3634")
	var hair := Color("#4A403A")
	var beard := Color("#A8A49C")
	# worn dark shoes
	for leg_x in [4, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 1, 1, 3), shoe)
	# thin legs in faded jeans with a gap between them
	for leg_x in [4, 8]:
		figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 1, 13, 2), jeans)
	figure.box(Vector3i(4, 12, 0), Vector3i(9, 14, 2), jeans)
	# a narrow chest in the grey hoodie
	figure.box(Vector3i(4, 15, 0), Vector3i(9, 23, 2), hoodie)
	# the aviator jacket, open, too big on him: the fleece collar and lapels
	for y in range(15, 24):
		for z in range(-1, 4):
			for x in [3, 4, 9, 10]:
				figure.put(x, y, z, leather)
		for x in range(3, 11):
			figure.put(x, y, 3, leather)
	figure.box(Vector3i(5, 20, -1), Vector3i(5, 23, -1), fleece)
	figure.box(Vector3i(8, 20, -1), Vector3i(8, 23, -1), fleece)
	figure.box(Vector3i(3, 24, -1), Vector3i(10, 25, 4), fleece)
	# thin arms in the sleeves with a gap to the body (joined at the shoulder), the hands bare
	figure.box(Vector3i(2, 22, 0), Vector3i(2, 23, 2), leather)
	figure.box(Vector3i(11, 22, 0), Vector3i(11, 23, 2), leather)
	for arm_x in [0, 12]:
		figure.box(Vector3i(arm_x, 15, 0), Vector3i(arm_x + 1, 23, 2), leather)
		figure.box(Vector3i(arm_x, 13, 0), Vector3i(arm_x + 1, 14, 1), SKIN_GREY)
	# a thin neck and a hollow face: tired eyes, a grey beard, short hair
	figure.box(Vector3i(6, 26, 1), Vector3i(7, 26, 2), SKIN_GREY)
	_head(figure, 4, 27, SKIN_GREY)
	for eye_x in [5, 8]:
		figure.put(eye_x, 30, 0, EYE_DARK)
	# a full grey beard over the jaw and the cheeks, sideburns up to the hair
	figure.box(Vector3i(4, 27, 0), Vector3i(9, 28, 0), beard)
	figure.box(Vector3i(4, 26, -1), Vector3i(9, 28, -1), beard)
	figure.box(Vector3i(3, 27, 0), Vector3i(3, 30, 1), beard)
	figure.box(Vector3i(10, 27, 0), Vector3i(10, 30, 1), beard)
	figure.box(Vector3i(5, 24, -2), Vector3i(8, 25, -2), beard)
	figure.box(Vector3i(4, 34, 0), Vector3i(9, 34, 5), hair)
	figure.box(Vector3i(3, 30, 2), Vector3i(3, 33, 5), hair)
	figure.box(Vector3i(10, 30, 2), Vector3i(10, 33, 5), hair)
	figure.box(Vector3i(4, 28, 6), Vector3i(9, 33, 6), hair)
	figure.box(Vector3i(4, 33, -1), Vector3i(6, 33, -1), hair)                  # a fringe to one side
	figure.mark("leather", [leather, shoe])
	figure.mark("knit", [fleece])
	figure.mark("cloth", [hoodie])
	figure.mark("denim", [jeans])
	figure.mark("hair", [hair, beard])


## Sjaan: once a toilet attendant. Few details: a skirt in four big patches, plain colours.
static func _build_sjaan(figure: VoxelFigure) -> void:
	var denim := Color("#4A6A9A")
	var boot := Color("#3A2A22")
	var hair := Color("#A8482A")
	var beanie := Color("#3E7A4A")
	var patches := [Color("#8A3A5A"), Color("#C8963A"), Color("#3A6A6A"), Color("#6A4A8A")]
	var tights := Color("#2E2A30")
	var top := Color("#D8D0C0")
	var smile := Color("#A83A3A")
	# boots, dark tights over the knees (the legs show below the skirt, so her walk does)
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 3, 3), boot)
		figure.box(Vector3i(leg_x, 4, 0), Vector3i(leg_x + 2, 7, 2), tights)
	# a patchwork skirt to the knees, wider at the hem: a big patch of a colour per quarter
	figure.box(Vector3i(2, 8, -1), Vector3i(11, 10, 4), patches[0])
	figure.box(Vector3i(3, 11, 0), Vector3i(10, 14, 3), patches[0])
	for cell: Vector3i in figure.cells.keys():
		if figure.cells[cell] == patches[0]:
			figure.cells[cell] = patches[int(cell.x >= 7) + 2 * int(cell.z >= 2)]
	# the denim jacket open over a light top
	figure.box(Vector3i(3, 15, 0), Vector3i(10, 24, 3), denim)
	figure.box(Vector3i(6, 16, -1), Vector3i(7, 24, -1), top)
	# the arms hanging by her sides (a gap to the body, joined at the shoulder), the hands
	figure.box(Vector3i(2, 23, 0), Vector3i(2, 24, 2), denim)
	figure.box(Vector3i(11, 23, 0), Vector3i(11, 24, 2), denim)
	for arm_x in [0, 12]:
		figure.box(Vector3i(arm_x, 15, 0), Vector3i(arm_x + 1, 24, 2), denim)
		figure.box(Vector3i(arm_x, 13, 1), Vector3i(arm_x + 1, 14, 2), SKIN_PALE)
	# the head: a smile
	figure.box(Vector3i(6, 25, 1), Vector3i(7, 25, 2), SKIN_PALE)
	_head(figure, 4, 26, SKIN_PALE)
	figure.put(5, 29, 0, EYE_DARK)
	figure.put(8, 29, 0, EYE_DARK)
	figure.box(Vector3i(5, 27, 0), Vector3i(8, 27, 0), smile)
	# big curly hair round the face and down the back, under a green beanie
	figure.box(Vector3i(2, 25, 1), Vector3i(3, 31, 6), hair)
	figure.box(Vector3i(10, 25, 1), Vector3i(11, 31, 6), hair)
	figure.box(Vector3i(3, 22, 6), Vector3i(10, 31, 7), hair)
	figure.box(Vector3i(3, 32, -1), Vector3i(10, 33, 6), beanie)
	figure.box(Vector3i(4, 34, 0), Vector3i(9, 34, 5), beanie)
	figure.mark("denim", [denim])
	figure.mark("cloth", patches + [top])
	figure.mark("knit", [beanie, tights])
	figure.mark("leather", [boot])
	figure.mark("hair", [hair])
	figure.mark("skin", [smile])


## Willem: an old man in a long coat and a flat cap. Few details: plain colours, no small voxels.
static func _build_willem(figure: VoxelFigure) -> void:
	var coat := Color("#56604A")
	var trousers := Color("#7A5A3A")
	var slipper := Color("#4A3A30")
	var scarf := Color("#A8382E")
	var cap := Color("#5A4A3C")
	var cap_dark := Color("#3E3229")
	var grey := Color("#D4D0CA")
	var glasses := Color("#3A3A3E")
	# worn brown slippers, corduroy trousers
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 1, 3), slipper)
		figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 2, 9, 2), trousers)
	# the long coat, wider at the hem
	figure.box(Vector3i(2, 8, -1), Vector3i(11, 11, 4), coat)
	figure.box(Vector3i(3, 12, 0), Vector3i(10, 21, 4), coat)
	# a red knitted scarf, one end down the front
	figure.box(Vector3i(3, 20, -1), Vector3i(10, 21, 5), scarf)
	figure.box(Vector3i(4, 15, -2), Vector3i(5, 19, -2), scarf)
	# arms with a gap to the body (joined at the shoulder), hanging by his sides
	figure.box(Vector3i(2, 19, 0), Vector3i(2, 20, 3), coat)
	figure.box(Vector3i(11, 19, 0), Vector3i(11, 20, 3), coat)
	figure.box(Vector3i(0, 12, 0), Vector3i(1, 20, 3), coat)
	figure.box(Vector3i(0, 10, 1), Vector3i(1, 11, 2), SKIN_OLD)
	figure.box(Vector3i(12, 12, 0), Vector3i(13, 20, 3), coat)
	figure.box(Vector3i(12, 10, 1), Vector3i(13, 11, 2), SKIN_OLD)
	# the head: round glasses, bushy white brows, a grey moustache
	figure.box(Vector3i(6, 22, 2), Vector3i(7, 22, 3), SKIN_OLD)
	_head(figure, 4, 23, SKIN_OLD)
	for lens_x in [4, 7]:
		figure.box(Vector3i(lens_x, 26, -1), Vector3i(lens_x + 2, 27, -1), glasses)
	figure.box(Vector3i(4, 28, -1), Vector3i(5, 28, -1), grey)                 # brows
	figure.box(Vector3i(8, 28, -1), Vector3i(9, 28, -1), grey)
	figure.box(Vector3i(5, 24, -1), Vector3i(8, 24, -1), grey)                 # the moustache
	# white hair round the back, under a flat cap with its peak forward
	figure.box(Vector3i(3, 24, 3), Vector3i(3, 28, 5), grey)
	figure.box(Vector3i(10, 24, 3), Vector3i(10, 28, 5), grey)
	figure.box(Vector3i(4, 24, 6), Vector3i(9, 28, 6), grey)
	figure.box(Vector3i(3, 29, -1), Vector3i(10, 30, 6), cap)
	figure.box(Vector3i(4, 31, 0), Vector3i(9, 31, 6), cap)
	figure.box(Vector3i(3, 29, -3), Vector3i(10, 29, -1), cap_dark)            # the peak
	figure.mark("cloth", [coat, trousers, slipper, cap, cap_dark])
	figure.mark("knit", [scarf])
	figure.mark("hair", [grey])
	figure.mark("plastic", [glasses])


## Gerrit: an old fisherman in oilskins. Few details: plain colours, no small voxels.
static func _build_gerrit(figure: VoxelFigure) -> void:
	var oilskin := Color("#E8B820")
	var oilskin_dark := Color("#B88A10")
	var rubber := Color("#2E4632")
	var trousers := Color("#2A3450")
	var jumper := Color("#22305A")
	var beard := Color("#BCB8B0")
	var skin := Color("#D08A6A")
	var nose := Color("#C0604A")
	# rubber boots up to the knee
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 6, 3), rubber)
		figure.box(Vector3i(leg_x, 7, 0), Vector3i(leg_x + 2, 10, 3), trousers)
	figure.box(Vector3i(3, 11, 0), Vector3i(10, 11, 3), trousers)
	# the oilskin coat, flared at the hem
	figure.box(Vector3i(2, 12, -1), Vector3i(11, 14, 4), oilskin)
	figure.box(Vector3i(3, 15, 0), Vector3i(10, 24, 3), oilskin)
	# the roll-neck jumper showing at the collar
	figure.box(Vector3i(4, 25, 0), Vector3i(9, 25, 4), jumper)
	figure.box(Vector3i(5, 24, -1), Vector3i(8, 24, -1), jumper)
	# arms in the oilskin sleeves (a gap to the body, joined at the shoulder), the hands
	figure.box(Vector3i(2, 23, 0), Vector3i(2, 24, 3), oilskin)
	figure.box(Vector3i(11, 23, 0), Vector3i(11, 24, 3), oilskin)
	for arm_x in [0, 12]:
		figure.box(Vector3i(arm_x, 14, 0), Vector3i(arm_x + 1, 24, 3), oilskin)
		figure.box(Vector3i(arm_x, 12, 1), Vector3i(arm_x + 1, 13, 2), skin)
	# the head: weathered and red, a full grey beard
	_head(figure, 4, 26, skin)
	figure.put(5, 29, 0, EYE_DARK)
	figure.put(8, 29, 0, EYE_DARK)
	figure.box(Vector3i(6, 28, -1), Vector3i(7, 29, -1), nose)
	figure.box(Vector3i(4, 26, -1), Vector3i(9, 27, -1), beard)
	figure.box(Vector3i(3, 26, 0), Vector3i(3, 28, 3), beard)
	figure.box(Vector3i(10, 26, 0), Vector3i(10, 28, 3), beard)
	figure.box(Vector3i(5, 25, -1), Vector3i(8, 25, -1), beard)
	figure.box(Vector3i(3, 29, 2), Vector3i(3, 31, 5), beard)                      # grey hair at the sides
	figure.box(Vector3i(10, 29, 2), Vector3i(10, 31, 5), beard)
	# the sou'wester: a yellow crown, a brim all round, long at the back over the neck
	figure.box(Vector3i(2, 32, -2), Vector3i(11, 32, 7), oilskin_dark)
	figure.box(Vector3i(3, 33, -1), Vector3i(10, 35, 6), oilskin)
	figure.box(Vector3i(4, 36, 0), Vector3i(9, 36, 5), oilskin)
	figure.box(Vector3i(3, 27, 7), Vector3i(10, 31, 7), oilskin)
	figure.mark("nylon", [oilskin, oilskin_dark])
	figure.mark("plastic", [rubber])
	figure.mark("cloth", [trousers])
	figure.mark("knit", [jumper])
	figure.mark("hair", [beard])
	figure.mark("skin", [skin, nose])
