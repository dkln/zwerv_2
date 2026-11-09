extends Node3D
## The Zebraklok on the Koningin Julianaplein before Centraal Station (Jaap Karman, 1977):
## a street clock 8 m tall with three matching sides, each with a face of black and white
## stripes marking the hours, lit from inside. Built here in code: a slender three-sided
## column on a low plinth, the face on each side near the top (FACE_PIXELS across, pixel-
## sharp as the voxels of the town), and its hands show the real time (the computer's
## clock), the second hand sweeping.
## Placed by tools/build/build_city.gd (_zebra_clock); its node only holds this script.

## The column: its height, the width of each of its three sides, the plinth under it.
const HEIGHT := 8.0
const SIDE_WIDTH := 1.6
const PLINTH_HEIGHT := 0.375
const PLINTH_GROW := 0.25   # metres wider than the column on each side
## The faces: their size (square, metres), the height of their middle, how far before the
## side they stand (so the column does not draw over them: with the camera's near plane at 2 m
## and far plane at 6 km a smaller gap z-fights, the face flickering), and their pixels across.
const FACE_SIZE := 1.45
const FACE_MIDDLE := HEIGHT - 1.05
const FACE_OUT := 0.08
const FACE_PIXELS := 28
const COLUMN_COLOUR := Color("#e4e2dc")
const PLINTH_COLOUR := Color("#5b5e66")

const FACE_SHADER := """shader_type spatial;
// one face of the Zebraklok: a white dial with black stripes at the hours (the quarters
// longer and broader), on black, and the hands at the angles given (radians, 0 = twelve,
// clockwise); the white lit from inside (glow)
uniform float hour_angle = 0.0;
uniform float minute_angle = 0.0;
uniform float second_angle = 0.0;
uniform float pixels = 28.0;
uniform float glow = 0.35;

float hand(vec2 spot, float angle, float reach, float half_width, float back) {
	vec2 direction = vec2(sin(angle), cos(angle));
	float along = dot(spot, direction);
	float across = abs(dot(spot, vec2(direction.y, -direction.x)));
	return step(-back, along) * step(along, reach) * step(across, half_width);
}

void fragment() {
	vec2 pixel_uv = (floor(UV * pixels) + 0.5) / pixels;
	vec2 spot = (pixel_uv - 0.5) * 2.0;
	spot.y = -spot.y;
	float radius = length(spot);
	vec3 colour = vec3(0.05);
	float lit = 0.0;
	if (radius < 0.93) {
		colour = vec3(0.95);
		lit = 1.0;
		float hour_place = atan(spot.x, spot.y) / 6.2831853 * 12.0;
		float from_hour = abs(fract(hour_place + 0.5) - 0.5);
		float quarter = step(mod(floor(hour_place + 0.5) + 12.0, 3.0), 0.5);
		float stripe_width = mix(0.11, 0.19, quarter);
		float stripe_from = mix(0.5, 0.28, quarter);
		if (from_hour < stripe_width && radius > stripe_from) {
			colour = vec3(0.05);
		}
		float hands = max(hand(spot, hour_angle, 0.5, 0.085, 0.08), hand(spot, minute_angle, 0.8, 0.06, 0.08));
		if (hands > 0.5 || radius < 0.09) {
			colour = vec3(0.05);
		}
		if (hand(spot, second_angle, 0.84, 0.04, 0.18) > 0.5) {
			colour = vec3(0.85, 0.12, 0.1);
		}
	}
	ALBEDO = colour;
	ROUGHNESS = 0.55;
	EMISSION = colour * glow * lit;
}
"""

var _face_material: ShaderMaterial


func _ready() -> void:
	_build_column()
	_face_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FACE_SHADER
	_face_material.shader = shader
	_face_material.set_shader_parameter("pixels", float(FACE_PIXELS))
	for side_index in 3:
		_add_face(side_index)
	_show_time()


func _process(_delta: float) -> void:
	_show_time()


## The hands at the time of the computer's clock (the seconds with their fraction, so the
## second hand sweeps).
func _show_time() -> void:
	var now := Time.get_time_dict_from_system()
	var fraction := fmod(Time.get_unix_time_from_system(), 1.0)
	var seconds := float(now.second) + fraction
	var minutes := float(now.minute) + seconds / 60.0
	var hours := float(int(now.hour) % 12) + minutes / 60.0
	_face_material.set_shader_parameter("second_angle", TAU * seconds / 60.0)
	_face_material.set_shader_parameter("minute_angle", TAU * minutes / 60.0)
	_face_material.set_shader_parameter("hour_angle", TAU * hours / 12.0)


## The corners of the column's three-sided cross-section (`grow` metres out on each side),
## the first towards -z.
static func _corners(grow: float) -> Array[Vector2]:
	var circumradius := (SIDE_WIDTH + 2.0 * grow * sqrt(3.0)) / sqrt(3.0)
	var corners: Array[Vector2] = []
	for corner_index in 3:
		var angle := deg_to_rad(-90.0 + 120.0 * corner_index)
		corners.append(Vector2(cos(angle), sin(angle)) * circumradius)
	return corners


## The plinth and the column: three-sided prisms with a top.
func _build_column() -> void:
	add_child(_prism("Sokkel", _corners(PLINTH_GROW), 0.0, PLINTH_HEIGHT, PLINTH_COLOUR))
	add_child(_prism("Zuil", _corners(0.0), PLINTH_HEIGHT, HEIGHT, COLUMN_COLOUR))


static func _prism(node_name: String, corners: Array[Vector2], bottom: float, top: float, colour: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_index in 3:
		var from := corners[side_index]
		var to := corners[(side_index + 1) % 3]
		var middle := (from + to) * 0.5
		surface.set_normal(Vector3(middle.x, 0.0, middle.y).normalized())
		var low_from := Vector3(from.x, bottom, from.y)
		var low_to := Vector3(to.x, bottom, to.y)
		var high_from := Vector3(from.x, top, from.y)
		var high_to := Vector3(to.x, top, to.y)
		for corner: Vector3 in [low_from, high_from, high_to, low_from, high_to, low_to]:
			surface.add_vertex(corner)
	surface.set_normal(Vector3.UP)
	for corner_index in [0, 2, 1]:
		surface.add_vertex(Vector3(corners[corner_index].x, top, corners[corner_index].y))
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance


## The face on side `side_index`, in the middle of that side, looking out.
func _add_face(side_index: int) -> void:
	var corners := _corners(0.0)
	var middle := (corners[side_index] + corners[(side_index + 1) % 3]) * 0.5
	var outwards := Vector3(middle.x, 0.0, middle.y).normalized()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * FACE_SIZE
	var face := MeshInstance3D.new()
	face.name = "Wijzerplaat%d" % (side_index + 1)
	face.mesh = quad
	face.material_override = _face_material
	# a quad looks along its +z: turn that outwards
	face.basis = Basis.looking_at(-outwards, Vector3.UP)
	face.position = Vector3(middle.x, FACE_MIDDLE, middle.y) + outwards * FACE_OUT
	add_child(face)
