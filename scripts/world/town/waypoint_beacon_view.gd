extends RefCounted
## What the beacon of the marker looks like (graphics; docs/CODE_LAGEN.md): a tall beam of
## light ("Straal"), fading out upwards, and a ring on the ground at its foot ("Ring"), in
## the colour of the marker on the minimap (COLOUR). Built into the beacon's node (build);
## waypoint_beacon.gd says how big the ring is (show_ring_scale). Sizes: waypoint_beacon_layout.gd.
##   const WaypointBeaconView = preload("res://scripts/world/town/waypoint_beacon_view.gd")

const Layout = preload("res://scripts/world/town/waypoint_beacon_layout.gd")

const COLOUR := Color("#FF5ACD")
## How see-through the beam is at its foot, and the ring.
const BEAM_ALPHA := 0.55
const RING_ALPHA := 0.9

var beam: MeshInstance3D
var ring: MeshInstance3D


## Builds the beam and the ring as children of `host`.
func build(host: Node3D) -> void:
	beam = MeshInstance3D.new()
	beam.name = "Straal"
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = Layout.BEAM_RADIUS * Layout.BEAM_TOP_SHARE
	beam_mesh.bottom_radius = Layout.BEAM_RADIUS
	beam_mesh.height = Layout.BEAM_HEIGHT
	beam_mesh.radial_segments = 8
	beam_mesh.rings = 1
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	beam_mesh.material = glow(BEAM_ALPHA, true)
	beam.mesh = beam_mesh
	beam.position = Layout.beam_centre()
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(beam)
	ring = MeshInstance3D.new()
	ring.name = "Ring"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = Layout.RING_RADIUS - Layout.RING_THICKNESS
	ring_mesh.outer_radius = Layout.RING_RADIUS
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 4
	ring_mesh.material = glow(RING_ALPHA, false)
	ring.mesh = ring_mesh
	ring.position = Layout.ring_centre()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(ring)


## The ring `ring_scale` times its own size (nothing before it is built).
func show_ring_scale(ring_scale: float) -> void:
	if ring:
		ring.scale = Vector3.ONE * ring_scale


## Unshaded light in COLOUR, see-through; `fade_up`: fading out to the top of the beam (by
## its UV: the cylinder's v runs from its top to its foot).
static func glow(alpha: float, fade_up: bool) -> Material:
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
