extends RefCounted
## Where the parts of the police helicopter are and how big (layout; docs/CODE_LAGEN.md), in
## metres with +Z ahead and the skids on y = 0: the boxes of its body (each with the part it
## is: "blue", "white", "orange", "glass", "metal"), POLITIE on its flanks, the rotors, the
## lamps and the search light. Its model: police_helicopter_view.gd.
##   const PoliceHelicopterLayout = preload("res://scripts/vehicles/police_helicopter_layout.gd")

## The main rotor: radius and height of its middle; the tail rotor: radius and middle.
const MAIN_ROTOR_RADIUS := 5.6
const MAIN_ROTOR_AT := Vector3(0.0, 3.3, 0.1)
const TAIL_ROTOR_RADIUS := 1.0
const TAIL_ROTOR_AT := Vector3(0.2, 2.9, -7.35)
## The two sides: its right (x < 0, as it faces +Z) and its left.
const SIDES := [-1.0, 1.0]
## Where the struts of a skid stand along it.
const STRUTS_ALONG := [-0.5, 1.1]
## The cabin, the nose, the engine, the glass, the stripes and the tail: [size, middle, part].
const HULL_BOXES := [
	# the cabin, the nose and the engine on top
	[Vector3(1.9, 1.0, 4.2), Vector3(0.0, 1.0, 0.3), "blue"],
	[Vector3(1.8, 0.9, 3.4), Vector3(0.0, 1.95, 0.1), "blue"],
	[Vector3(1.6, 0.9, 0.8), Vector3(0.0, 1.15, 2.75), "blue"],
	[Vector3(1.1, 0.55, 0.4), Vector3(0.0, 1.05, 3.3), "blue"],
	[Vector3(1.2, 0.5, 2.2), Vector3(0.0, 2.65, -0.2), "blue"],
	[Vector3(0.22, 0.45, 0.22), Vector3(0.0, 3.1, 0.1), "metal"],   # the rotor mast
	# glass: the windscreen in front, the side windows of the cabin
	[Vector3(1.66, 0.7, 0.8), Vector3(0.0, 1.85, 2.2), "glass"],
	[Vector3(1.94, 0.5, 2.0), Vector3(0.0, 1.95, 0.7), "glass"],
	# the police stripes along the flanks: a white band with an orange one under it
	[Vector3(1.94, 0.26, 4.24), Vector3(0.0, 1.32, 0.3), "white"],
	[Vector3(1.95, 0.1, 4.25), Vector3(0.0, 1.12, 0.3), "orange"],
	[Vector3(1.64, 0.26, 0.82), Vector3(0.0, 1.32, 2.75), "white"],
	[Vector3(1.65, 0.1, 0.83), Vector3(0.0, 1.12, 2.75), "orange"],
	# the tail: the boom, thinner at the end, the fin, the stabiliser
	[Vector3(0.6, 0.6, 5.0), Vector3(0.0, 1.95, -4.2), "blue"],
	[Vector3(0.62, 0.14, 5.0), Vector3(0.0, 1.95, -4.2), "white"],
	[Vector3(0.45, 0.45, 1.4), Vector3(0.0, 2.0, -7.1), "blue"],
	[Vector3(0.16, 1.7, 1.0), Vector3(0.0, 2.85, -7.45), "blue"],
	[Vector3(2.1, 0.1, 0.55), Vector3(0.0, 2.05, -6.5), "blue"],
]
## POLITIE on a flank: how far out, how high and how far along; how big a pixel of it is (m).
const WORD_AT := Vector3(0.96, 0.78, 0.4)
const WORD_PIXEL_SIZE := 0.0075
## The lamps: [size, middle]. Red on its left (x > 0), green on its right, white on the
## tail; the strobe on top of the fin and the beacon under the belly; the landing lamps
## under the nose (LANDING_LAMP_AT: across on each side) and the search lamp between them.
const LEFT_LAMP := [Vector3(0.3, 0.3, 0.3), Vector3(1.05, 1.55, 1.6)]
const RIGHT_LAMP := [Vector3(0.3, 0.3, 0.3), Vector3(-1.05, 1.55, 1.6)]
const TAIL_LAMP := [Vector3(0.25, 0.25, 0.25), Vector3(0.0, 2.0, -7.95)]
const STROBE := [Vector3(0.35, 0.35, 0.35), Vector3(0.0, 3.85, -7.6)]
const BEACON := [Vector3(0.45, 0.25, 0.45), Vector3(0.0, 0.42, 0.2)]
const LANDING_LAMP_SIZE := Vector3(0.3, 0.18, 0.3)
const LANDING_LAMP_AT := Vector3(0.45, 0.52, 3.0)
const SEARCH_LAMP := [Vector3(0.4, 0.25, 0.4), Vector3(0.0, 0.5, 2.6)]
## The search light: where it shines from, the way it shines (ahead and down), how far (m)
## and how wide (degrees).
const SEARCHLIGHT_AT := Vector3(0.0, 0.5, 2.6)
const SEARCHLIGHT_AIM := Vector3(0.0, -1.0, 0.7)
const SEARCHLIGHT_RANGE := 90.0
const SEARCHLIGHT_ANGLE := 9.0


## The boxes of the body, in the order they are built: {"size", "centre", "part"} each. The
## skids on their struts first (right, then left), then HULL_BOXES.
static func body_boxes() -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	for side: float in SIDES:
		boxes.append(_box(Vector3(0.1, 0.1, 3.6), Vector3(side * 0.95, 0.05, 0.3), "metal"))
		boxes.append(_box(Vector3(0.1, 0.1, 0.3), Vector3(side * 0.95, 0.12, 2.15), "metal"))   # the turned-up toe
		for along: float in STRUTS_ALONG:
			boxes.append(_box(Vector3(0.08, 0.5, 0.08), Vector3(side * 0.9, 0.35, along), "metal"))
	for hull_box: Array in HULL_BOXES:
		boxes.append(_box(hull_box[0], hull_box[1], hull_box[2]))
	return boxes


## How the main rotor lies (flat) and how the tail rotor stands: upright on the side of the
## fin, its axle across.
static func main_rotor_basis() -> Basis:
	return Basis.IDENTITY


static func tail_rotor_basis() -> Basis:
	return Basis(Vector3.BACK, PI / 2.0)


## The side of a square a rotor of `radius` is drawn on.
static func rotor_size(radius: float) -> Vector2:
	return Vector2.ONE * radius * 2.0


## Where POLITIE stands on the flank at `side` (SIDES), and how it is turned to face out.
static func word_position(side: float) -> Vector3:
	return Vector3(side * WORD_AT.x, WORD_AT.y, WORD_AT.z)


static func word_turn(side: float) -> float:
	return side * PI / 2.0


## The middle of the landing lamp at `side` (SIDES).
static func landing_lamp_centre(side: float) -> Vector3:
	return Vector3(side * LANDING_LAMP_AT.x, LANDING_LAMP_AT.y, LANDING_LAMP_AT.z)


## How the search light is turned: ahead and down.
static func searchlight_basis() -> Basis:
	return Basis.looking_at(SEARCHLIGHT_AIM)


static func _box(size: Vector3, centre: Vector3, part: String) -> Dictionary:
	return {"size": size, "centre": centre, "part": part}
