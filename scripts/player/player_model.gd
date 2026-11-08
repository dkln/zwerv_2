extends Node3D
## The voxel figure of a player archetype (PlayerCharacter.ARCHETYPES), built in code from
## boxes of voxels of VOXEL metres (as the riders of the traffic, 0.0625 m), so it needs no
## imported tile: about 2 m tall, standing on y = 0, the face towards +z. All four are
## zwervers: worn and dirty clothes, holes and patches, what they own on them; their names
## are nicknames.
## - jos (alcohol): a battered cowboy hat (a hole in the brim, string for a band), long
##   matted grey hair and a scruffy beard, a red drinker's nose and heavy eyelids, a long
##   frayed coat with a patch over a checked shirt and a belly, rope for a belt,
##   jeans with a torn knee, fingerless gloves, boots with a sole coming loose, a stone
##   kruik of jenever in one hand and a plastic bag with bread in the other;
## - martin (speed): skinny in a faded shell suit (a hole at the elbow, the zip half open
##   over a grey t-shirt), a cheap chain, trousers with a torn knee, grey trainers with
##   a lace undone, a worn rucksack with a sleeping bag rolled on top, grown-out bleached
##   hair, sunglasses with one lens gone on his forehead, wide eyes, hollow cheeks, a grin with a tooth missing, sweat, and an energy drink;
## - ufo_piloot (crack): an ordinary man, skinny: an old aviator jacket too big on him
##   with a fleece collar over a grey hoodie, faded jeans held up by the last hole of his
##   belt, worn shoes, a hollow face with tired eyes and stubble, short messy hair;
## - willem (gokkasten): an old man in a long faded coat with big buttons and a safety pin
##   for a lost one, a red knitted scarf, corduroy trousers and worn slippers, a flat cap
##   over white hair, round glasses, bushy brows, a grey moustache and white stubble, a
##   plastic bag in one hand.
## - sjaan (sigaretten): a street musician: big curly auburn hair under a green knitted
##   beanie, a denim jacket with pins, a long patchwork skirt, boots, an accordion at her
##   chest (red ends, keys, the bellows in stripes), her cap on the ground with coins in it,
##   and her dog Bobbie (a small brown and white terrier) sitting beside her.
## Limbs: the arms and the legs are parts of their own (RIGS: the boxes of voxels of each),
## each turning round its own joint (shoulder, hip), so they move independently of each
## other: `walking` (0..1) swings them in a walk cycle, pose_limb sets one by hand, and the
## idle moves use them too (Jos sways and swings his arms, Martin taps his feet and
## jitters, Sjaan pumps her accordion, Willem and the pilot breathe).
## Shading: each face a little darker on the sides and below, and every corner darkened by
## the voxels round it (ambient occlusion), so folds, gaps and the parts under a brim read.
## Each voxel one flat colour, kept to few and clearly different colours per figure.
## Materials: every colour has a kind (VoxelFigure.mark; colours not marked take the kind
## of the nearest marked colour, else cloth). The fabrics (cloth, denim, knit, nylon) and
## hair have a shader of their own (figure.gdshader), each with its own pattern and gloss
## (CLOTH); skin, eyes, leather, plastic, metal and glass ordinary materials (MATERIALS). All colours are
## graded for more colour and contrast (SATURATION, CONTRAST). `spin` turns the whole
## figure slowly round.

const VOXEL := 0.0625
const SHADER := preload("res://scripts/player/figure.gdshader")
## Voxels up to the middle of each face (eyes and nose), to zoom in on it.
const FACE_HEIGHT := {"jos": 28.5, "martin": 30.5, "ufo_piloot": 29.5, "willem": 26.0, "sjaan": 29.0}
## The limbs of each figure: per limb the boxes of voxel cells (x0, y0, z0, x1, y1, z1,
## both corners included) that belong to it, what it holds included; the rest is the body.
## The joint is at the top of the limb, in its middle.
const RIGS := {
	"jos": {
		"arm_left": [[-3, 3, -4, 0, 23, 6]], "arm_right": [[13, 3, -4, 15, 23, 6]],
		"leg_left": [[3, 0, -3, 5, 12, 4]], "leg_right": [[8, 0, -3, 10, 12, 4]],
	},
	"martin": {
		"arm_left": [[0, 13, -6, 3, 23, 3]], "arm_right": [[10, 13, -6, 13, 23, 3]],
		"leg_left": [[4, 0, -4, 5, 13, 3]], "leg_right": [[8, 0, -4, 9, 13, 3]],
	},
	"ufo_piloot": {
		"arm_left": [[-1, 12, -2, 2, 23, 3]], "arm_right": [[11, 12, -2, 14, 23, 3]],
		"leg_left": [[4, 0, -2, 5, 13, 3]], "leg_right": [[8, 0, -2, 9, 13, 3]],
	},
	"willem": {
		"arm_left": [[-1, 3, -2, 1, 20, 4], [2, 19, 0, 2, 20, 3]],
		"arm_right": [[12, 10, -2, 14, 20, 4], [11, 19, 0, 11, 20, 3]],
		"leg_left": [[3, 0, -2, 5, 7, 3]], "leg_right": [[8, 0, -2, 10, 7, 3]],
	},
	"sjaan": {
		"arm_left": [[0, 15, -5, 1, 24, 3], [2, 23, 0, 2, 24, 2]],
		"arm_right": [[12, 15, -5, 13, 24, 3], [11, 23, 0, 11, 24, 2]],
		"leg_left": [[3, 0, -2, 5, 3, 4]], "leg_right": [[8, 0, -2, 10, 3, 4]],
	},
}
const LIMBS := ["arm_left", "arm_right", "leg_left", "leg_right"]
## The kinds of material. The fabrics (and hair, which is drawn the same way) have the
## fabric shader (figure.gdshader), each with its own pattern (1 weave, 2 twill, 3 knit,
## 4 strands), its strength and repeats per voxel, roughness, specular and velvet edge:
const CLOTH := {
	"cloth": {"pattern": 1, "strength": 0.09, "scale": 2.0, "roughness": 0.92, "specular": 0.3, "rim": 0.35},
	"denim": {"pattern": 2, "strength": 0.11, "scale": 1.5, "roughness": 0.85, "specular": 0.35, "rim": 0.25},
	"knit": {"pattern": 3, "strength": 0.15, "scale": 1.0, "roughness": 0.97, "specular": 0.2, "rim": 0.5},
	"nylon": {"pattern": 1, "strength": 0.04, "scale": 3.0, "roughness": 0.42, "specular": 0.6, "rim": 0.15},
	"hair": {"pattern": 4, "strength": 0.12, "scale": 1.0, "roughness": 0.55, "specular": 0.5, "rim": 0.3},
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
## Seconds a spinning figure first stands facing the front (its face to be seen) when it
## is shown anew, before it turns.
const FRONT_HOLD := 1.5
## The walk: steps a second, how far the legs and the arms swing (degrees), how much the
## body bobs (metres).
const STEPS_PER_SECOND := 1.8
const LEG_SWING := 26.0
const ARM_SWING := 20.0
const WALK_BOB := 0.025

@export var archetype_id := "jos":
	set(value):
		archetype_id = value
		if is_inside_tree():
			_rebuild()
## Moves on its own (sway, jitter, tapping, playing).
@export var idle := true
## Degrees a second it turns round (0 = stands still facing +z).
@export var spin := 0.0
## How much it walks (0 = stands, 1 = a full walk cycle on the spot); tween it.
@export_range(0.0, 1.0) var walking := 0.0

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


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if _figure:
		_figure.queue_free()
	_figure = Node3D.new()
	_figure.name = "Figuur"
	add_child(_figure)
	_joints.clear()
	var parts := parts_for(archetype_id)
	_height = parts.height
	var body := MeshInstance3D.new()
	body.name = "Lijf"
	body.mesh = parts.meshes.body
	_figure.add_child(body)
	for limb: String in LIMBS:
		if not parts.meshes.has(limb):
			continue
		var joint := Node3D.new()
		joint.name = limb
		joint.position = parts.pivots[limb]
		_figure.add_child(joint)
		var piece := MeshInstance3D.new()
		piece.mesh = parts.meshes[limb]
		piece.position = -parts.pivots[limb]
		joint.add_child(piece)
		_joints[limb] = joint


## Sets a limb ("arm_left", "arm_right", "leg_left", "leg_right") to this turn round its
## joint (degrees; x swings it forward and back, z out to the side), on top of the walk and
## the idle moves.
func pose_limb(limb: String, degrees: Vector3) -> void:
	_poses[limb] = degrees


## Faces the front at once and holds there FRONT_HOLD seconds before it turns on.
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


## The height of the figure in metres (to frame it).
func height() -> float:
	return _height


func _process(delta: float) -> void:
	if _figure == null:
		return
	_clock += delta
	if _hold > 0.0:
		_hold -= delta
	else:
		_turn += spin * delta
	_walk_clock += delta * STEPS_PER_SECOND * PI * walking
	var stride := sin(_walk_clock)
	var sway := 0.0
	var offset := Vector3(0.0, absf(cos(_walk_clock)) * WALK_BOB * walking, 0.0)
	var angles := {}
	for limb: String in LIMBS:
		angles[limb] = Vector3.ZERO
	# the walk: legs opposite, each arm against its leg
	angles.leg_left.x += stride * LEG_SWING * walking
	angles.leg_right.x -= stride * LEG_SWING * walking
	angles.arm_left.x -= stride * ARM_SWING * walking
	angles.arm_right.x += stride * ARM_SWING * walking
	if idle:
		var still := 1.0 - walking
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
				# playing: rocking with the music, the arms pumping the bellows
				sway = sin(_clock * 2.4) * 2.0 * still
				angles.arm_left.z -= (0.5 + 0.5 * sin(_clock * 2.4)) * 7.0 * still
				angles.arm_right.z += (0.5 + 0.5 * sin(_clock * 2.4)) * 7.0 * still
			_:
				# a slow breath, the arms hanging and moving with it
				offset.y += sin(_clock * 1.4) * 0.006 * still
				angles.arm_left.z -= (0.5 + 0.5 * sin(_clock * 1.4)) * 2.0 * still
				angles.arm_right.z += (0.5 + 0.5 * sin(_clock * 1.4)) * 2.0 * still
	for limb: String in _joints:
		(_joints[limb] as Node3D).rotation_degrees = angles[limb] + _poses.get(limb, Vector3.ZERO)
	_figure.position = offset
	_figure.rotation_degrees = Vector3(0.0, _turn, sway)


# ------------------------------------------------------------------ building

## The figure of an archetype, built once: {"meshes": {"body", limbs...: ArrayMesh},
## "pivots": {limb: Vector3 joint in metres}, "height": metres}.
static func parts_for(id: String) -> Dictionary:
	if not _cache.has(id):
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
			_:
				_build_jos(figure)
		if is_nan(figure.centre_cell.x):
			# every head is x 4..9: turn round it and frame it in the middle
			figure.centre_cell = Vector2(7.0, 3.0)
		var materials := {}
		for kind: String in CLOTH.keys() + MATERIALS.keys() + ["glow"]:
			materials[kind] = material_for(kind)
		_cache[id] = figure.to_parts(VOXEL, RIGS.get(id, {}), materials, graded)
	return _cache[id]


## The material of a kind, made once and shared: the fabrics and hair the fabric shader
## with their own settings (CLOTH), the rest an ordinary material (MATERIALS), glowing parts
## unshaded.
static func material_for(kind: String) -> Material:
	if not _materials.has(kind):
		if CLOTH.has(kind):
			var settings: Dictionary = CLOTH[kind]
			var fabric := ShaderMaterial.new()
			fabric.shader = SHADER
			fabric.set_shader_parameter("pattern", settings.pattern)
			fabric.set_shader_parameter("pattern_strength", settings.strength)
			fabric.set_shader_parameter("pattern_scale", settings.scale)
			fabric.set_shader_parameter("voxel_size", VOXEL)
			fabric.set_shader_parameter("roughness_value", settings.roughness)
			fabric.set_shader_parameter("specular_value", settings.specular)
			fabric.set_shader_parameter("rim_value", settings.rim)
			_materials[kind] = fabric
		else:
			var plain := StandardMaterial3D.new()
			plain.vertex_color_use_as_albedo = true
			plain.vertex_color_is_srgb = true
			plain.cull_mode = BaseMaterial3D.CULL_DISABLED
			if kind == "glow":
				plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			else:
				var settings: Dictionary = MATERIALS.get(kind, MATERIALS.leather)
				plain.roughness = settings.roughness
				plain.metallic = settings.metallic
				plain.metallic_specular = settings.specular
				if settings.rim > 0.0:
					plain.rim_enabled = true
					plain.rim = settings.rim
					plain.rim_tint = 0.6
			_materials[kind] = plain
	return _materials[kind]


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

	## The body and the limbs (`rig`: limb -> boxes of cells, RIGS) as meshes: only the
	## faces between a voxel and air (of any part, so a limb's faces against the body are
	## drawn and it can move away from it), a surface per kind of material, centred on x
	## and z, standing on y = 0, the front (z = 0) towards +z; the joint of each limb at
	## the top of it, in its middle.
	## `materials`: kind -> Material; `grade`: a Callable(Color) -> Color for every colour.
	func to_parts(voxel: float, rig: Dictionary, materials: Dictionary, grade: Callable) -> Dictionary:
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
		# the faces, by part and kind
		var kind_cache := {}          # Color -> kind
		var grade_cache := {}         # Color -> graded Color
		var tools := {}               # "part/kind" -> SurfaceTool
		for cell: Vector3i in cells:
			var colour: Color = cells[cell]
			if not kind_cache.has(colour):
				kind_cache[colour] = kind_of(colour)
				grade_cache[colour] = grade.call(colour)
			var kind: String = "glow" if glowing.has(cell) else kind_cache[colour]
			var part: String = part_of[cell]
			var key := part + "/" + kind
			if not tools.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = tool
			for side: Vector3i in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]:
				var next := cell + side
				if cells.has(next) and part_of[next] == part:
					continue
				_add_face(tools[key], cell, Vector3(cell) - centre, side, grade_cache[colour], voxel, cells)
		var meshes := {}
		for key: String in tools:
			var part := key.get_slice("/", 0)
			var kind := key.get_slice("/", 1)
			if not meshes.has(part):
				meshes[part] = ArrayMesh.new()
			var tool: SurfaceTool = tools[key]
			tool.set_material(materials.get(kind, materials.cloth))
			tool.commit(meshes[part])
		if not meshes.has("body"):
			meshes["body"] = ArrayMesh.new()
		# the joints: the middle of the top of each limb
		var pivots := {}
		for limb: String in rig:
			var limb_cells: Array = part_cells[limb]
			if limb_cells.is_empty():
				continue
			var top := -1 << 20
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
		return {"meshes": meshes, "pivots": pivots, "height": (highest.y + 1 - lowest.y) * voxel}

	## How much each level of corner occlusion darkens a vertex (0 = open .. 3 = shut in).
	const OCCLUSION := [1.0, 0.8, 0.66, 0.52]

	## One face of the voxel `cell` (placed at `corner`, in voxels, z running backwards) on
	## `side`, each of its corners darkened by the voxels round it (ambient occlusion: in a
	## corner or a gap it gets less light), as voxel art does.
	static func _add_face(tool: SurfaceTool, cell: Vector3i, corner: Vector3, side: Vector3i, colour: Color,
			voxel: float, cells: Dictionary) -> void:
		# the face's four corners in the voxel (0..1)
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
		# z runs backwards in the figure: mirror it so the front (z = 0) faces +z
		var normal := Vector3(side.x, side.y, -side.z)
		# a little darker on the sides and below, as light from above
		var light := 1.0 if side == Vector3i.UP else (0.7 if side == Vector3i.DOWN else 0.88)
		var placed: Array[Vector3] = []
		var shades: Array[Color] = []
		var outside := cell + side
		for point: Vector3 in points:
			var at := corner + point
			placed.append(Vector3(at.x, at.y, -at.z) * voxel)
			# the two neighbours along the face at this corner and the one diagonal to it
			var along := Vector3i.ZERO
			var across := Vector3i.ZERO
			if side.x != 0:
				along = Vector3i(0, int(point.y) * 2 - 1, 0)
				across = Vector3i(0, 0, int(point.z) * 2 - 1)
			elif side.y != 0:
				along = Vector3i(int(point.x) * 2 - 1, 0, 0)
				across = Vector3i(0, 0, int(point.z) * 2 - 1)
			else:
				along = Vector3i(int(point.x) * 2 - 1, 0, 0)
				across = Vector3i(0, int(point.y) * 2 - 1, 0)
			var first := cells.has(outside + along)
			var second := cells.has(outside + across)
			var level := 3 if first and second else int(first) + int(second) + int(cells.has(outside + along + across))
			var shade: float = light * OCCLUSION[level]
			shades.append(Color(colour.r * shade, colour.g * shade, colour.b * shade))
		# the mirror flips the winding: draw the triangles the other way round; split the
		# quad along the diagonal that keeps the occlusion smooth
		var order: Array = [0, 2, 1, 0, 3, 2]
		if shades[0].v + shades[2].v < shades[1].v + shades[3].v:
			order = [1, 3, 2, 1, 0, 3]
		for index: int in order:
			tool.set_normal(normal)
			tool.set_color(shades[index])
			tool.add_vertex(placed[index])


# ------------------------------------------------------------------ the figures

const SKIN_TAN := Color("#C68A62")
const SKIN_PALE := Color("#E4BE9C")
const SKIN_GREY := Color("#B7A68E")
const SKIN_OLD := Color("#E2B79A")
const EYE_DARK := Color("#1A1420")
const EYE_WHITE := Color("#EEEAE0")
const TEETH := Color("#E6DDBE")


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


## Jos: sturdy, a belly, a long coat; the kruik in his right hand, a bag in his left.
static func _build_jos(figure: VoxelFigure) -> void:
	var boot := Color("#5E3A22")
	var boot_dark := Color("#30200F")
	var jeans := Color("#43587A")
	var jeans_worn := Color("#7186A6")
	var shirt := Color("#9A3A36")
	var shirt_dark := Color("#5E2224")
	var coat := Color("#6B5236")
	var coat_dark := Color("#4A3824")
	var patch := Color("#5E6B4A")
	var rope := Color("#B9A27A")
	var hat := Color("#7A6448")
	var hair := Color("#9C968C")
	var beard := Color("#8A8478")
	# boots, the left sole coming loose at the toe (a grey sock showing)
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 3, 3), boot)
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 0, 3), boot_dark)
		figure.box(Vector3i(leg_x, 0, 3), Vector3i(leg_x + 2, 1, 4), boot_dark)
		figure.box(Vector3i(leg_x, 3, 0), Vector3i(leg_x + 2, 3, 3), boot_dark)
	figure.box(Vector3i(3, 0, -2), Vector3i(5, 0, -2), boot_dark)                  # the loose sole
	# jeans, a torn knee with skin through it, a patch on the thigh; a gap between the legs
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 4, 0), Vector3i(leg_x + 2, 12, 3), jeans)
	figure.box(Vector3i(4, 7, 0), Vector3i(5, 8, 0), jeans_worn)
	figure.box(Vector3i(8, 7, -1), Vector3i(10, 8, -1), jeans_worn)
	figure.box(Vector3i(8, 7, -1), Vector3i(9, 7, -1), SKIN_TAN)                   # the torn knee
	figure.box(Vector3i(4, 10, -1), Vector3i(5, 11, -1), Color("#6A4A30"))
	# rope for a belt, tied with the ends hanging
	figure.box(Vector3i(2, 13, -1), Vector3i(11, 13, 4), rope)
	figure.put(6, 12, -2, rope)
	figure.put(6, 11, -2, rope)
	# a checked shirt over a belly, stained
	figure.box(Vector3i(2, 14, 0), Vector3i(11, 22, 4), shirt)
	figure.box(Vector3i(3, 14, -1), Vector3i(10, 18, -1), shirt)
	figure.box(Vector3i(4, 15, -2), Vector3i(9, 17, -2), shirt)
	for cell: Vector3i in figure.cells.keys():
		if figure.cells[cell] == shirt and (posmod(cell.x, 4) < 2) != (posmod(cell.y, 4) < 2):
			figure.cells[cell] = shirt_dark
	figure.box(Vector3i(6, 16, -2), Vector3i(7, 17, -2), Color("#8A6A3A"))   # a stain on the belly
	# the long coat: open in front, down to the knees, frayed at the hem, a patch, the collar up
	for y in range(6, 24):
		for z in range(0, 6):
			for x in [1, 2, 11, 12]:
				if y >= 14 or z >= 1:
					figure.put(x, y, z, coat)
		for x in range(1, 13):
			figure.put(x, y, 5, coat)
	figure.box(Vector3i(3, 14, -1), Vector3i(3, 22, -1), coat)
	figure.box(Vector3i(10, 14, -1), Vector3i(10, 22, -1), coat)
	figure.box(Vector3i(2, 14, -1), Vector3i(2, 22, -1), coat_dark)
	figure.box(Vector3i(11, 14, -1), Vector3i(11, 22, -1), coat_dark)
	for x in range(1, 13):
		if x % 3 == 0:
			figure.clear(x, 6, 5)
	figure.clear(1, 6, 1)
	figure.clear(12, 7, 2)
	figure.box(Vector3i(1, 17, -1), Vector3i(2, 19, -1), patch)           # the patch, sewn on
	figure.box(Vector3i(2, 23, -1), Vector3i(3, 24, 5), coat_dark)        # collar up
	figure.box(Vector3i(10, 23, -1), Vector3i(11, 24, 5), coat_dark)
	figure.box(Vector3i(3, 23, 5), Vector3i(10, 24, 5), coat_dark)
	# sleeves of the coat (a gap to the body, joined at the shoulder), frayed cuffs,
	# fingerless gloves
	figure.box(Vector3i(-1, 22, 1), Vector3i(0, 23, 4), coat)
	figure.box(Vector3i(13, 22, 1), Vector3i(14, 23, 4), coat)
	for arm_x in [-2, 14]:
		figure.box(Vector3i(arm_x, 14, 1), Vector3i(arm_x + 1, 23, 4), coat)
		figure.box(Vector3i(arm_x, 14, 1), Vector3i(arm_x + 1, 14, 4), coat_dark)
		figure.box(Vector3i(arm_x, 12, 1), Vector3i(arm_x + 1, 13, 3), Color("#4E4A48"))   # the glove
		figure.box(Vector3i(arm_x, 11, 1), Vector3i(arm_x + 1, 11, 2), SKIN_TAN)            # the fingers
	# the stone kruik of jenever in the right hand
	figure.box(Vector3i(14, 5, 0), Vector3i(15, 9, 1), Color("#B8A170"))
	figure.box(Vector3i(14, 6, -1), Vector3i(15, 7, -1), Color("#E8E0C8"))         # the label
	figure.box(Vector3i(14, 10, 0), Vector3i(15, 10, 0), Color("#9A845A"))
	figure.put(14, 11, 0, Color("#4A2E1C"))
	# a plastic bag in the left hand, a loaf sticking out
	figure.box(Vector3i(-3, 3, 0), Vector3i(-1, 9, 3), Color("#E2E0D6"))
	figure.box(Vector3i(-3, 6, -1), Vector3i(-1, 6, -1), Color("#3A6AB8"))
	figure.box(Vector3i(-2, 10, 1), Vector3i(-2, 10, 2), Color("#E2E0D6"))    # the handles
	figure.box(Vector3i(-3, 10, 2), Vector3i(-3, 11, 3), Color("#C89A5A"))    # the loaf
	# neck and head: weathered and dirty, a red nose, heavy eyelids
	figure.box(Vector3i(6, 24, 2), Vector3i(7, 24, 3), SKIN_TAN)
	_head(figure, 4, 25, SKIN_TAN)
	figure.box(Vector3i(6, 27, -1), Vector3i(7, 28, -1), Color("#C8463E"))
	figure.put(5, 29, 0, EYE_DARK)
	figure.put(8, 29, 0, EYE_DARK)
	figure.put(5, 30, 0, SKIN_TAN.darkened(0.3))
	figure.put(8, 30, 0, SKIN_TAN.darkened(0.3))
	figure.box(Vector3i(4, 31, -1), Vector3i(5, 31, -1), hair.darkened(0.25))
	figure.box(Vector3i(8, 31, -1), Vector3i(9, 31, -1), hair.darkened(0.25))
	figure.put(4, 28, -1, Color("#C87A6A"))
	figure.put(9, 28, -1, Color("#C87A6A"))
	# a scruffy beard over the jaw and down the neck, the mouth in it
	figure.box(Vector3i(4, 25, -1), Vector3i(9, 26, -1), beard)
	figure.box(Vector3i(4, 25, 0), Vector3i(9, 27, 0), beard)
	figure.box(Vector3i(5, 23, -1), Vector3i(8, 24, -1), beard)
	figure.box(Vector3i(5, 26, -2), Vector3i(8, 26, -2), beard.darkened(0.1))   # the moustache
	figure.box(Vector3i(6, 25, -1), Vector3i(7, 25, -1), Color("#5A2A28"))
	# long matted grey hair
	figure.box(Vector3i(3, 24, 5), Vector3i(10, 31, 6), hair)
	figure.box(Vector3i(3, 27, 3), Vector3i(3, 31, 4), hair)
	figure.box(Vector3i(10, 27, 3), Vector3i(10, 31, 4), hair)
	# the battered hat: the brim drooping at the front, a hole in it, string for a band
	for x in range(0, 14):
		for z in range(-3, 9):
			var corner := (x <= 1 or x >= 12) and (z <= -2 or z >= 7)
			if not corner:
				figure.put(x, 31 if z <= -2 else 32, z, hat)
	figure.clear(11, 32, 6)
	figure.clear(10, 32, 7)
	figure.box(Vector3i(3, 33, 0), Vector3i(10, 33, 5), Color("#3A3028"))
	figure.box(Vector3i(3, 34, 0), Vector3i(10, 36, 5), hat)
	figure.box(Vector3i(4, 37, 1), Vector3i(9, 37, 4), hat)
	figure.box(Vector3i(6, 37, 1), Vector3i(7, 37, 4), hat.darkened(0.3))
	figure.clear(9, 36, 0)
	figure.mark("cloth", [shirt, shirt_dark, coat, coat_dark, patch, rope, hat, Color("#3A3028")])
	figure.mark("denim", [jeans, jeans_worn])
	figure.mark("knit", [Color("#4E4A48")])
	figure.mark("leather", [boot, boot_dark])
	figure.mark("hair", [hair, beard])
	figure.mark("plastic", [Color("#B8A170"), Color("#E8E0C8"), Color("#9A845A"), Color("#E2E0D6"), Color("#3A6AB8")])
	figure.mark("skin", [Color("#C8463E"), Color("#C87A6A"), Color("#5A2A28")])


## Martin: skinny and restless in a faded shell suit, his house on his back.
static func _build_martin(figure: VoxelFigure) -> void:
	var suit := Color("#4E8C84")
	var suit_dark := Color("#335E58")
	var panel := Color("#6A4E8A")
	var stripe := Color("#C8C8C0")
	var pants := Color("#4E4068")
	var trainer := Color("#A8A498")
	var sole := Color("#5A5650")
	var hair := Color("#D8C680")
	var hair_root := Color("#6A5034")
	var pack := Color("#5E6440")
	var pack_dark := Color("#3E4228")
	# grey, dirty trainers, a lace undone
	for leg_x in [4, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 1, 1, 3), trainer)
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 1, 0, 3), sole)
		figure.put(leg_x, 1, -1, Color("#3A3830"))
	figure.put(5, 0, -2, Color("#D8D4C8"))
	figure.put(5, 0, -3, Color("#D8D4C8"))
	# thin legs with a gap between them, a faded stripe, a torn knee
	for leg_x in [4, 8]:
		figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 1, 13, 2), pants)
	figure.box(Vector3i(4, 3, 1), Vector3i(4, 13, 1), stripe)
	figure.box(Vector3i(9, 3, 1), Vector3i(9, 13, 1), stripe)
	figure.box(Vector3i(4, 7, 0), Vector3i(5, 8, 0), SKIN_PALE.darkened(0.1))
	figure.box(Vector3i(4, 12, 0), Vector3i(9, 14, 2), pants)
	# the jacket: faded, the zip half open over a grey t-shirt, stains, the collar up
	figure.box(Vector3i(4, 15, 0), Vector3i(9, 23, 2), suit)
	for y in range(18, 23):
		for x in range(4, 10):
			if x + y >= 25 and x + y <= 28:
				figure.put(x, y, 0, panel)
	figure.box(Vector3i(6, 15, -1), Vector3i(6, 18, -1), stripe)
	figure.box(Vector3i(6, 19, 0), Vector3i(7, 23, 0), Color("#8A8A86"))   # the t-shirt
	figure.box(Vector3i(4, 15, 0), Vector3i(9, 15, 2), suit_dark)
	figure.box(Vector3i(4, 24, 0), Vector3i(4, 25, 2), suit_dark)
	figure.box(Vector3i(9, 24, 0), Vector3i(9, 25, 2), suit_dark)
	figure.box(Vector3i(5, 24, 2), Vector3i(8, 25, 2), suit_dark)
	for x in range(5, 9):
		figure.put(x, 23 - (1 if x == 6 or x == 7 else 0), -1, Color("#A8A8A0"))   # a cheap chain
	# the rucksack: worn, straps over the shoulders, a sleeping bag rolled on top
	figure.box(Vector3i(4, 15, 3), Vector3i(9, 23, 5), pack)
	figure.box(Vector3i(5, 16, 6), Vector3i(8, 20, 6), pack_dark)           # its pocket
	figure.box(Vector3i(3, 24, 3), Vector3i(10, 25, 5), Color("#3A5A8A"))   # the sleeping bag
	figure.box(Vector3i(3, 24, 4), Vector3i(10, 24, 4), Color("#2A4068"))
	figure.box(Vector3i(4, 16, -1), Vector3i(4, 23, -1), pack_dark)         # the straps
	figure.box(Vector3i(9, 16, -1), Vector3i(9, 23, -1), pack_dark)
	# thin arms with a gap to the body (joined at the shoulder), a hole at the left elbow;
	# the right hand holds the can up
	figure.box(Vector3i(3, 22, 0), Vector3i(3, 23, 1), suit)
	figure.box(Vector3i(10, 22, 0), Vector3i(10, 23, 1), suit)
	for arm_x in [1, 11]:
		figure.box(Vector3i(arm_x, 16, 0), Vector3i(arm_x + 1, 23, 1), suit)
		figure.box(Vector3i(arm_x if arm_x == 1 else arm_x + 1, 16, 0), Vector3i(arm_x if arm_x == 1 else arm_x + 1, 23, 0), stripe)
		figure.box(Vector3i(arm_x, 15, 0), Vector3i(arm_x + 1, 15, 1), suit_dark)
	figure.put(1, 19, 1, SKIN_PALE)
	figure.box(Vector3i(1, 13, 0), Vector3i(2, 14, 1), SKIN_PALE)
	figure.box(Vector3i(11, 15, -2), Vector3i(12, 16, -1), suit)
	figure.box(Vector3i(11, 15, -3), Vector3i(12, 16, -3), SKIN_PALE)
	figure.box(Vector3i(11, 14, -5), Vector3i(12, 18, -4), Color("#2E52B8"))
	figure.box(Vector3i(11, 16, -5), Vector3i(12, 16, -5), Color("#B8E030"))
	figure.box(Vector3i(11, 18, -5), Vector3i(12, 18, -4), Color("#B8BCC4"))
	figure.box(Vector3i(11, 14, -5), Vector3i(12, 14, -4), Color("#B8BCC4"))
	# a thin neck and a pale face: hollow cheeks, wide eyes, dark rings, a grin with a gap,
	# patchy stubble, sweat
	figure.box(Vector3i(6, 26, 1), Vector3i(7, 26, 2), SKIN_PALE)
	_head(figure, 4, 27, SKIN_PALE)
	for eye_x in [4, 8]:
		figure.box(Vector3i(eye_x, 30, 0), Vector3i(eye_x + 1, 31, 0), EYE_WHITE)       # in the face, not on it
		figure.box(Vector3i(eye_x, 29, 0), Vector3i(eye_x + 1, 29, 0), Color("#A08A90"))
	figure.put(5, 30, 0, EYE_DARK)
	figure.put(8, 30, 0, EYE_DARK)
	figure.put(5, 31, 0, EYE_DARK)
	figure.put(8, 31, 0, EYE_DARK)
	figure.put(4, 28, 0, SKIN_PALE.darkened(0.18))                          # hollow cheeks
	figure.put(9, 28, 0, SKIN_PALE.darkened(0.18))
	figure.box(Vector3i(4, 33, -1), Vector3i(5, 33, -1), hair_root)
	figure.box(Vector3i(8, 33, -1), Vector3i(9, 33, -1), hair_root)
	figure.box(Vector3i(5, 28, -1), Vector3i(8, 28, -1), TEETH)
	figure.put(7, 28, -1, Color("#3A1A1A"))                                 # the missing tooth
	figure.put(10, 31, 0, Color("#9FD0F0"))
	figure.put(10, 30, 0, Color("#9FD0F0"))
	# sunglasses on the forehead, one lens gone
	figure.box(Vector3i(3, 34, -1), Vector3i(10, 34, -1), Color("#1A1A20"))
	figure.box(Vector3i(4, 34, -2), Vector3i(5, 34, -2), Color("#2A2240"))
	# grown-out bleached hair: dark roots, light ends, greasy spikes, long at the back
	figure.box(Vector3i(4, 34, 0), Vector3i(9, 34, 5), hair_root)
	figure.box(Vector3i(3, 30, 1), Vector3i(3, 33, 5), hair_root)
	figure.box(Vector3i(10, 30, 1), Vector3i(10, 33, 5), hair_root)
	figure.box(Vector3i(4, 35, 0), Vector3i(9, 35, 5), hair_root)
	for x in range(4, 10):
		for z in range(0, 6):
			if (x + z) % 2 == 0:
				figure.put(x, 36, z, hair)
	figure.box(Vector3i(4, 26, 6), Vector3i(9, 33, 6), hair_root)
	figure.box(Vector3i(5, 26, 6), Vector3i(8, 28, 6), hair)
	figure.mark("nylon", [suit, suit_dark, panel, stripe, pants, Color("#3A5A8A"), Color("#2A4068")])
	figure.mark("cloth", [pack, pack_dark, Color("#8A8A86")])
	figure.mark("plastic", [trainer, sole, Color("#3A3830"), Color("#D8D4C8"), Color("#1A1A20")])
	figure.mark("hair", [hair, hair_root])
	figure.mark("metal", [Color("#A8A8A0"), Color("#2E52B8"), Color("#B8E030"), Color("#B8BCC4")])
	figure.mark("glass", [Color("#2A2240"), Color("#9FD0F0")])


## The ufo pilot: an ordinary man, skinny, in an old aviator jacket (where his nickname
## partly comes from) over a grey hoodie.
static func _build_pilot(figure: VoxelFigure) -> void:
	var leather := Color("#6A4428")
	var leather_dark := Color("#46301C")
	var fleece := Color("#DCCFB2")
	var hoodie := Color("#707074")
	var jeans := Color("#3E4A5E")
	var shoe := Color("#3A3634")
	var hair := Color("#4A403A")
	var stubble := Color("#7A6E64")
	# worn dark shoes, white soles
	for leg_x in [4, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 1, 1, 3), shoe)
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 1, 0, 3), Color("#B8B4AA"))
	# thin legs in faded jeans with a gap between them, loose at the knees
	for leg_x in [4, 8]:
		figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 1, 13, 2), jeans)
		figure.box(Vector3i(leg_x, 7, -1), Vector3i(leg_x + 1, 8, -1), jeans.lightened(0.18))
	figure.box(Vector3i(4, 12, 0), Vector3i(9, 14, 2), jeans)
	figure.box(Vector3i(4, 14, -1), Vector3i(9, 14, 3), Color("#2A2420"))      # the belt, last hole
	# a narrow chest in the grey hoodie
	figure.box(Vector3i(4, 15, 0), Vector3i(9, 23, 2), hoodie)
	figure.box(Vector3i(5, 16, -1), Vector3i(8, 18, -1), hoodie.darkened(0.15))   # the pouch
	# the aviator jacket, open, too big on him: the fleece collar and lapels
	for y in range(15, 24):
		for z in range(-1, 4):
			for x in [3, 4, 9, 10]:
				figure.put(x, y, z, leather)
		for x in range(3, 11):
			figure.put(x, y, 3, leather)
	figure.box(Vector3i(3, 15, -1), Vector3i(10, 15, 3), leather_dark)        # the waistband
	figure.box(Vector3i(5, 20, -1), Vector3i(5, 23, -1), fleece)
	figure.box(Vector3i(8, 20, -1), Vector3i(8, 23, -1), fleece)
	figure.box(Vector3i(3, 24, -1), Vector3i(10, 25, 4), fleece)
	figure.box(Vector3i(5, 24, 0), Vector3i(8, 25, 2), hoodie.darkened(0.2))
	# thin arms in the sleeves with a gap to the body (joined at the shoulder), the hands bare
	figure.box(Vector3i(2, 22, 0), Vector3i(2, 23, 2), leather)
	figure.box(Vector3i(11, 22, 0), Vector3i(11, 23, 2), leather)
	for arm_x in [0, 12]:
		figure.box(Vector3i(arm_x, 15, 0), Vector3i(arm_x + 1, 23, 2), leather)
		figure.box(Vector3i(arm_x, 15, 0), Vector3i(arm_x + 1, 15, 2), leather_dark)
		figure.box(Vector3i(arm_x, 13, 0), Vector3i(arm_x + 1, 14, 1), SKIN_GREY)
	# a thin neck and a hollow face: tired eyes, stubble, short messy hair
	figure.box(Vector3i(6, 26, 1), Vector3i(7, 26, 2), SKIN_GREY)
	_head(figure, 4, 27, SKIN_GREY)
	for eye_x in [5, 8]:
		figure.put(eye_x, 30, 0, EYE_DARK)
		figure.put(eye_x, 29, 0, SKIN_GREY.darkened(0.22))                      # rings under the eyes
	figure.box(Vector3i(4, 31, -1), Vector3i(5, 31, -1), hair)                  # brows
	figure.box(Vector3i(8, 31, -1), Vector3i(9, 31, -1), hair)
	figure.put(4, 28, 0, SKIN_GREY.darkened(0.15))                              # hollow cheeks
	figure.put(9, 28, 0, SKIN_GREY.darkened(0.15))
	figure.box(Vector3i(4, 27, 0), Vector3i(9, 27, 0), stubble)                 # the stubble
	figure.box(Vector3i(6, 28, -1), Vector3i(7, 28, -1), Color("#6A3A34"))      # the mouth
	figure.box(Vector3i(4, 34, 0), Vector3i(9, 34, 5), hair)
	figure.box(Vector3i(3, 30, 2), Vector3i(3, 33, 5), hair)
	figure.box(Vector3i(10, 30, 2), Vector3i(10, 33, 5), hair)
	figure.box(Vector3i(4, 28, 6), Vector3i(9, 33, 6), hair)
	figure.box(Vector3i(4, 33, -1), Vector3i(6, 33, -1), hair)                  # a fringe to one side
	for x in [4, 6, 8]:
		figure.put(x, 35, 2 + (x % 3), hair)                                    # messy on top
	figure.mark("leather", [leather, leather_dark, shoe, Color("#2A2420")])
	figure.mark("knit", [fleece])
	figure.mark("cloth", [hoodie])
	figure.mark("denim", [jeans])
	figure.mark("plastic", [Color("#B8B4AA")])
	figure.mark("hair", [hair, stubble])


## Sjaan: a street musician with her accordion, her cap with coins and her dog.
static func _build_sjaan(figure: VoxelFigure) -> void:
	var denim := Color("#4A6A9A")
	var denim_dark := Color("#33496A")
	var boot := Color("#3A2A22")
	var hair := Color("#A8482A")
	var beanie := Color("#3E7A4A")
	var red := Color("#B82A2A")
	var bellows := Color("#2A2A30")
	var dog := Color("#8A5A32")
	var dog_white := Color("#E8E2D6")
	var patches := [Color("#8A3A5A"), Color("#C8963A"), Color("#3A6A6A"), Color("#6A4A8A")]
	# boots
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 3, 3), boot)
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 0, 3), Color("#1E1610"))
	# a long patchwork skirt, wider at the hem, in squares of four colours
	figure.box(Vector3i(2, 4, -1), Vector3i(11, 8, 4), patches[0])
	figure.box(Vector3i(3, 9, 0), Vector3i(10, 14, 3), patches[0])
	for cell: Vector3i in figure.cells.keys():
		if figure.cells[cell] == patches[0]:
			figure.cells[cell] = patches[posmod(cell.x / 3 + cell.y / 3 + cell.z / 3, 4)]
	# the denim jacket, pins on it, the cuffs turned up
	figure.box(Vector3i(3, 15, 0), Vector3i(10, 24, 3), denim)
	figure.box(Vector3i(3, 15, 0), Vector3i(10, 15, 3), denim_dark)
	figure.box(Vector3i(6, 16, -1), Vector3i(7, 24, -1), Color("#D8D0C0"))   # a light top under it
	figure.box(Vector3i(5, 23, -1), Vector3i(5, 24, -1), denim_dark)          # the collar
	figure.box(Vector3i(8, 23, -1), Vector3i(8, 24, -1), denim_dark)
	figure.put(4, 22, -1, Color("#E8C840"))                                   # pins
	figure.put(9, 21, -1, red)
	# the arms round the accordion (a gap to the body, joined at the shoulder), the hands
	# on its ends
	figure.box(Vector3i(2, 23, 0), Vector3i(2, 24, 2), denim)
	figure.box(Vector3i(11, 23, 0), Vector3i(11, 24, 2), denim)
	for arm_x in [0, 12]:
		figure.box(Vector3i(arm_x, 17, 0), Vector3i(arm_x + 1, 24, 2), denim)
		figure.box(Vector3i(arm_x, 15, -2), Vector3i(arm_x + 1, 17, 0), denim)
		figure.box(Vector3i(arm_x, 15, -2), Vector3i(arm_x + 1, 15, -2), denim_dark)
	figure.box(Vector3i(1, 16, -4), Vector3i(1, 18, -3), SKIN_PALE)
	figure.box(Vector3i(12, 16, -4), Vector3i(12, 18, -3), SKIN_PALE)
	# the accordion: red ends with the keys, the bellows between them in stripes
	figure.box(Vector3i(2, 14, -5), Vector3i(3, 21, -1), red)
	figure.box(Vector3i(10, 14, -5), Vector3i(11, 21, -1), red)
	for x in range(4, 10):
		figure.box(Vector3i(x, 14, -5), Vector3i(x, 21, -1), bellows if x % 2 == 0 else Color("#E8E2D6"))
	for y in range(15, 21):
		figure.put(2, y, -6, Color("#F4F0E6") if y % 2 == 0 else Color("#1A1A1E"))   # the keys
	figure.box(Vector3i(11, 16, -6), Vector3i(11, 19, -6), Color("#E8C840"))   # the buttons
	# the head: freckles, a smile, a cigarette behind the ear
	figure.box(Vector3i(6, 25, 1), Vector3i(7, 25, 2), SKIN_PALE)
	_head(figure, 4, 26, SKIN_PALE)
	figure.put(5, 29, 0, EYE_DARK)
	figure.put(8, 29, 0, EYE_DARK)
	figure.box(Vector3i(5, 27, 0), Vector3i(8, 27, 0), Color("#A83A3A"))      # the smile
	figure.put(4, 28, 0, Color("#C8865A"))                                    # freckles
	figure.put(9, 28, 0, Color("#C8865A"))
	figure.box(Vector3i(4, 30, -1), Vector3i(5, 30, -1), hair.darkened(0.3))  # brows
	figure.box(Vector3i(8, 30, -1), Vector3i(9, 30, -1), hair.darkened(0.3))
	# big curly hair round the face and down the back, under a green beanie
	figure.box(Vector3i(2, 25, 1), Vector3i(3, 31, 6), hair)
	figure.box(Vector3i(10, 25, 1), Vector3i(11, 31, 6), hair)
	figure.box(Vector3i(3, 22, 6), Vector3i(10, 31, 7), hair)
	for cell: Vector3i in figure.cells.keys():
		if figure.cells[cell] == hair and posmod(cell.x + cell.y + cell.z, 3) == 0:
			figure.cells[cell] = hair.darkened(0.2)
	figure.box(Vector3i(3, 32, -1), Vector3i(10, 33, 6), beanie)
	figure.box(Vector3i(4, 34, 0), Vector3i(9, 34, 5), beanie)
	figure.box(Vector3i(3, 32, -1), Vector3i(10, 32, -1), beanie.darkened(0.25))   # the turned-up rim
	figure.box(Vector3i(6, 35, 2), Vector3i(7, 35, 3), beanie.lightened(0.2))      # the bobble
	figure.box(Vector3i(11, 30, 1), Vector3i(11, 30, 3), Color("#F0ECE4"))         # the cigarette
	# her cap on the ground in front, coins in it
	figure.box(Vector3i(-4, 0, -7), Vector3i(-1, 1, -4), Color("#4A4A50"))
	figure.box(Vector3i(-3, 1, -6), Vector3i(-2, 1, -5), Color("#2A2A30"))
	figure.put(-3, 2, -6, Color("#E8C840"))
	figure.put(-2, 2, -5, Color("#C8C8CC"))
	# Bobbie, sitting at her left: a small brown and white terrier
	figure.box(Vector3i(-5, 0, 0), Vector3i(-2, 1, 4), dog)                    # haunches and paws
	figure.box(Vector3i(-5, 0, -1), Vector3i(-4, 0, -1), dog_white)
	figure.box(Vector3i(-3, 0, -1), Vector3i(-2, 0, -1), dog_white)
	figure.box(Vector3i(-5, 2, 0), Vector3i(-2, 5, 3), dog)                    # the body, upright
	figure.box(Vector3i(-4, 2, -1), Vector3i(-3, 5, -1), dog_white)            # the chest
	figure.box(Vector3i(-5, 6, -1), Vector3i(-2, 8, 2), dog)                   # the head
	figure.box(Vector3i(-4, 6, -2), Vector3i(-3, 7, -2), dog_white)            # the snout
	figure.put(-4, 7, -3, Color("#1A1414"))                                    # the nose
	figure.put(-3, 7, -3, Color("#1A1414"))
	figure.put(-5, 8, -2, EYE_DARK)
	figure.put(-2, 8, -2, EYE_DARK)
	figure.box(Vector3i(-5, 9, 0), Vector3i(-5, 10, 1), dog.darkened(0.3))     # the ears
	figure.box(Vector3i(-2, 9, 0), Vector3i(-2, 10, 1), dog.darkened(0.3))
	figure.box(Vector3i(-4, 5, -2), Vector3i(-3, 5, -2), red)                  # a red collar
	figure.box(Vector3i(-4, 1, 5), Vector3i(-4, 3, 6), dog)                    # the tail
	figure.mark("denim", [denim, denim_dark])
	figure.mark("cloth", patches + [Color("#D8D0C0"), Color("#E8E2D6"), bellows, Color("#4A4A50"), Color("#2A2A30"), Color("#F0ECE4")])
	figure.mark("knit", [beanie])
	figure.mark("leather", [boot])
	figure.mark("hair", [hair, dog, dog_white])
	figure.mark("plastic", [red, Color("#F4F0E6"), Color("#1A1A1E"), Color("#1A1414")])
	figure.mark("metal", [Color("#E8C840"), Color("#C8C8CC")])


## Willem: an old man in a long coat and a flat cap.
static func _build_willem(figure: VoxelFigure) -> void:
	var coat := Color("#56604A")
	var coat_dark := Color("#3A4232")
	var trousers := Color("#7A5A3A")
	var slipper := Color("#4A3A30")
	var scarf := Color("#A8382E")
	var cap := Color("#6A6058")
	var cap_dark := Color("#4A423C")
	var grey := Color("#D4D0CA")
	# worn brown slippers, corduroy trousers (ribs down the front)
	for leg_x in [3, 8]:
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 1, 3), slipper)
		figure.box(Vector3i(leg_x, 0, -1), Vector3i(leg_x + 2, 0, 3), Color("#2A201A"))
		figure.box(Vector3i(leg_x, 2, 0), Vector3i(leg_x + 2, 9, 2), trousers)
		figure.box(Vector3i(leg_x + 1, 2, -1), Vector3i(leg_x + 1, 5, -1), trousers.darkened(0.2))
	# the long coat, wider at the hem, big buttons, a pocket, a safety pin for a lost button
	figure.box(Vector3i(2, 8, -1), Vector3i(11, 11, 4), coat)
	figure.box(Vector3i(3, 12, 0), Vector3i(10, 21, 4), coat)
	figure.box(Vector3i(2, 8, -1), Vector3i(11, 8, 4), coat_dark)
	figure.box(Vector3i(6, 9, -1), Vector3i(6, 21, -1), coat_dark)             # where it closes
	for y in [10, 14, 18]:
		figure.put(7, y, -1, Color("#2A1E1A"))
	figure.box(Vector3i(7, 16, -1), Vector3i(7, 16, -1), Color("#C8CCD0"))     # the safety pin
	figure.box(Vector3i(8, 10, -2), Vector3i(10, 11, -2), coat_dark)           # the pocket
	# a red knitted scarf, one end down the front
	figure.box(Vector3i(3, 20, -1), Vector3i(10, 21, 5), scarf)
	figure.box(Vector3i(4, 15, -2), Vector3i(5, 19, -2), scarf)
	figure.box(Vector3i(4, 15, -2), Vector3i(5, 15, -2), scarf.darkened(0.25))
	# arms with a gap to the body (joined at the shoulder); the left by his side with a
	# plastic bag, the right hanging
	figure.box(Vector3i(2, 19, 0), Vector3i(2, 20, 3), coat)
	figure.box(Vector3i(11, 19, 0), Vector3i(11, 20, 3), coat)
	figure.box(Vector3i(0, 12, 0), Vector3i(1, 20, 3), coat)
	figure.box(Vector3i(0, 10, 1), Vector3i(1, 11, 2), SKIN_OLD)
	figure.box(Vector3i(-1, 3, 0), Vector3i(1, 8, 2), Color("#E2E0D6"))        # the bag
	figure.box(Vector3i(-1, 6, -1), Vector3i(1, 6, -1), Color("#C83A32"))
	figure.put(0, 9, 1, Color("#E2E0D6"))
	figure.box(Vector3i(12, 12, 0), Vector3i(13, 20, 3), coat)
	figure.box(Vector3i(12, 12, 0), Vector3i(13, 12, 3), coat_dark)
	figure.box(Vector3i(12, 10, 1), Vector3i(13, 11, 2), SKIN_OLD)
	# the head: round glasses, bushy white brows, a grey moustache, white stubble
	figure.box(Vector3i(6, 22, 2), Vector3i(7, 22, 3), SKIN_OLD)
	_head(figure, 4, 23, SKIN_OLD)
	for lens_x in [4, 7]:
		figure.box(Vector3i(lens_x, 26, -1), Vector3i(lens_x + 2, 27, -1), Color("#3A3A3E"))
		figure.put(lens_x + 1, 26, -1, Color("#D8E0E8"))
		figure.put(lens_x + 1, 27, -1, Color("#D8E0E8"))
	figure.put(5, 26, 0, EYE_DARK)
	figure.put(8, 26, 0, EYE_DARK)
	figure.box(Vector3i(4, 28, -1), Vector3i(5, 28, -1), grey)                 # brows
	figure.box(Vector3i(8, 28, -1), Vector3i(9, 28, -1), grey)
	figure.box(Vector3i(6, 25, -1), Vector3i(7, 25, -1), SKIN_OLD.darkened(0.08))   # the nose
	figure.box(Vector3i(5, 24, -1), Vector3i(8, 24, -1), Color("#A8A49E"))     # the moustache
	figure.box(Vector3i(4, 23, 0), Vector3i(9, 23, 0), grey)                   # stubble on the chin
	figure.box(Vector3i(6, 23, -1), Vector3i(7, 23, -1), Color("#7A3A34"))     # the mouth
	# white hair round the back, under a flat cap with its peak forward
	figure.box(Vector3i(3, 24, 3), Vector3i(3, 28, 5), grey)
	figure.box(Vector3i(10, 24, 3), Vector3i(10, 28, 5), grey)
	figure.box(Vector3i(4, 24, 6), Vector3i(9, 28, 6), grey)
	figure.box(Vector3i(3, 29, -1), Vector3i(10, 30, 6), cap)
	figure.box(Vector3i(4, 31, 0), Vector3i(9, 31, 6), cap)
	figure.box(Vector3i(3, 29, -3), Vector3i(10, 29, -2), cap_dark)            # the peak
	figure.box(Vector3i(3, 29, -1), Vector3i(10, 29, -1), cap_dark)
	figure.mark("cloth", [coat, coat_dark, trousers, slipper, cap, cap_dark])
	figure.mark("knit", [scarf])
	figure.mark("hair", [grey, Color("#A8A49E")])
	figure.mark("plastic", [Color("#3A3A3E"), Color("#2A1E1A"), Color("#E2E0D6"), Color("#C83A32")])
	figure.mark("glass", [Color("#D8E0E8")])
	figure.mark("metal", [Color("#C8CCD0")])
