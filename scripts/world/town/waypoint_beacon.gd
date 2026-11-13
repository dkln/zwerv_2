extends Node3D
## The beacon of the marker you set on the map (GameHud.set_waypoint, from the game menu's
## KAART): a tall beam of light standing on the place, seen from far over the roofs, fading
## out upwards, and a ring on the ground at its foot that pulses. In the colour of the marker
## on the minimap (COLOUR). Hidden while the player is inside a building (`visible`).
##   var beacon := WaypointBeacon.new()   # GameHud makes one, in the town
##   beacon.place(Vector3(410, 0, 439))

const COLOUR := Color("#FF5ACD")
## The beam: how high (metres), how wide, how see-through at its foot.
const BEAM_HEIGHT := 60.0
const BEAM_RADIUS := 0.35
const BEAM_ALPHA := 0.55
## The ring on the ground: its radius and how fast it pulses (once in PULSE_SECONDS).
const RING_RADIUS := 1.6
const PULSE_SECONDS := 1.4

var _beam: MeshInstance3D
var _ring: MeshInstance3D
var _clock := 0.0


func _ready() -> void:
	name = "Markerbaken"
	_beam = MeshInstance3D.new()
	_beam.name = "Straal"
	var beam := CylinderMesh.new()
	beam.top_radius = BEAM_RADIUS * 0.6
	beam.bottom_radius = BEAM_RADIUS
	beam.height = BEAM_HEIGHT
	beam.radial_segments = 8
	beam.rings = 1
	beam.cap_top = false
	beam.cap_bottom = false
	beam.material = _glow(BEAM_ALPHA, true)
	_beam.mesh = beam
	_beam.position.y = BEAM_HEIGHT * 0.5
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var ring := TorusMesh.new()
	ring.inner_radius = RING_RADIUS - 0.12
	ring.outer_radius = RING_RADIUS
	ring.rings = 24
	ring.ring_segments = 4
	ring.material = _glow(0.9, false)
	_ring.mesh = ring
	_ring.position.y = 0.08
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


## On the ground at `at` (world).
func place(at: Vector3) -> void:
	global_position = at


func _process(delta: float) -> void:
	_clock += delta
	var pulse := 0.5 + 0.5 * sin(_clock / PULSE_SECONDS * TAU)
	if _ring:
		_ring.scale = Vector3.ONE * (0.85 + 0.3 * pulse)


## Unshaded light in COLOUR, see-through; `fade_up`: fading out to the top of the beam (by
## its UV: the cylinder's v runs from its top to its foot).
static func _glow(alpha: float, fade_up: bool) -> Material:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 colour : source_color;
uniform float alpha = 0.5;
uniform bool fade_up = false;
void fragment() {
	float strength = fade_up ? pow(UV.y, 1.6) : 1.0;
	ALBEDO = colour.rgb;
	ALPHA = alpha * strength;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("colour", COLOUR)
	material.set_shader_parameter("alpha", alpha)
	material.set_shader_parameter("fade_up", fade_up)
	return material
