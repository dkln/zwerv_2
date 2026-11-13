extends Node3D
## A Dutch police helicopter: blue, with the white and orange stripes of the police along
## its flanks and POLITIE on them, built of boxes in the voxel style (metres, +Z ahead, the
## skids on y = 0). Its rotors are flat squares whose blades the rotor shader draws and
## turns (addons/vox_tiles/materials/voxel_rotor.gdshader, by `turn` and `spin_blur`, as
## the wheels of the vehicles). Glowing lamps that light up the body round them (LAMP_GLOW,
## each with a small light of its own): red and green on its sides, white on the tail, a
## white strobe on the fin and a red beacon under the belly flashing in turn, two landing
## lamps under the nose; once it gets dark (the Dagcyclus' "night") a search light shines
## ahead and down. The lamps are big enough to be seen from far off (the menu's camera is a
## few hundred metres away: a pixel is about 0.1 m there).
## It circles by itself round `circle_centre` (circle_radius metres, circle_height up, at
## circle_speed m/s, banking into the turn), unless `circling` is off; the main menu sets
## the centre where the camera looks (main_menu.gd).

const ROTOR_SHADER = preload("res://addons/vox_tiles/materials/voxel_rotor.gdshader")
const FONT := "res://assets/fonts/PixelifySans.ttf"

## The police's blue, the stripes, the glass, the dark metal.
const BLUE := Color("#1C3C8E")
const WHITE := Color("#F2F2EE")
const ORANGE := Color("#E8541C")
const GLASS := Color("#1A2230")
const METAL := Color("#3A3D44")
## Turns per second of the main rotor and the tail rotor, and from how many radians per
## second their blades blur into a disc (fully at twice that).
const MAIN_ROTOR_TURNS := 5.0
const TAIL_ROTOR_TURNS := 22.0
const BLUR_FROM := 6.0
## The main rotor: radius and height of its middle; the tail rotor: radius and middle.
const MAIN_ROTOR_RADIUS := 5.6
const MAIN_ROTOR_AT := Vector3(0.0, 3.3, 0.1)
const TAIL_ROTOR_RADIUS := 1.0
const TAIL_ROTOR_AT := Vector3(0.2, 2.9, -7.35)
## Seconds of one flash of the strobe and the beacon, and the share of it they are lit.
const FLASH_CYCLE := 1.1
const FLASH_LIT := 0.12
## Degrees it banks into the turn while circling, and how far its nose dips.
const BANK_DEGREES := 14.0
const NOSE_DOWN_DEGREES := 6.0
## The lamps: how much brighter than lit they glow (unshaded, past the bloom of the
## environment), and the energy and reach (m) of the light each throws round it.
const LAMP_GLOW := 12.0
const LAMP_LIGHT_ENERGY := 1.6
const LAMP_LIGHT_RANGE := 4.0
const FLASH_LIGHT_ENERGY := 5.0
const FLASH_LIGHT_RANGE := 9.0
const RED := Color(1.0, 0.1, 0.08)
const GREEN := Color(0.15, 1.0, 0.3)
const LAMP_WHITE := Color(1.0, 0.97, 0.9)
## From this darkness (the Dagcyclus' "night", 0 .. 1) the search light is on.
const SEARCHLIGHT_FROM := 0.35

## Circling by itself (else something else moves it).
@export var circling := true
@export var circle_centre := Vector3.ZERO
@export var circle_radius := 50.0
@export var circle_height := 40.0
@export var circle_speed := 22.0
## Anticlockwise seen from above (else clockwise).
@export var anticlockwise := true
## The node with the time of day (scripts/world/town/day_cycle.gd), for the search light.
@export var day_cycle: Node

var _main_rotor: MeshInstance3D
var _tail_rotor: MeshInstance3D
var _strobe: MeshInstance3D
var _beacon: MeshInstance3D
var _searchlight: SpotLight3D
var _rotor_angle := 0.0
var _tail_angle := 0.0
var _circle_angle := 0.0


func _init() -> void:
	name = "Politiehelikopter"


func _ready() -> void:
	_build_body()
	_main_rotor = _rotor(MAIN_ROTOR_RADIUS, 4, Basis.IDENTITY, MAIN_ROTOR_AT)
	# the tail rotor stands upright on the side of the fin, its axle across
	_tail_rotor = _rotor(TAIL_ROTOR_RADIUS, 2, Basis(Vector3.BACK, PI / 2.0), TAIL_ROTOR_AT)
	_build_lights()
	(load("res://scripts/effects/outline.gd") as GDScript).apply(self)


func _process(delta: float) -> void:
	_rotor_angle = fmod(_rotor_angle + TAU * MAIN_ROTOR_TURNS * delta, TAU)
	_tail_angle = fmod(_tail_angle + TAU * TAIL_ROTOR_TURNS * delta, TAU)
	_spin(_main_rotor, _rotor_angle, TAU * MAIN_ROTOR_TURNS)
	_spin(_tail_rotor, _tail_angle, TAU * TAIL_ROTOR_TURNS)
	var flash := fmod(Time.get_ticks_msec() / 1000.0, FLASH_CYCLE) / FLASH_CYCLE
	_strobe.visible = flash < FLASH_LIT
	_beacon.visible = fmod(flash + 0.5, 1.0) < FLASH_LIT
	var night: float = day_cycle.get("night") if day_cycle else 0.0
	_searchlight.visible = night >= SEARCHLIGHT_FROM
	if circling:
		_fly_circle(delta)


## On round the circle: the nose along it, banked into the turn, the nose a little down.
func _fly_circle(delta: float) -> void:
	# a growing angle on (cos, 0, sin) goes from x to z: clockwise seen from above
	var turning := -1.0 if anticlockwise else 1.0
	_circle_angle = fmod(_circle_angle + turning * circle_speed / maxf(circle_radius, 1.0) * delta, TAU)
	var out := Vector3(cos(_circle_angle), 0.0, sin(_circle_angle))
	position = circle_centre + out * circle_radius + Vector3.UP * circle_height
	# ahead: along the circle the way it goes
	var ahead := Vector3(-out.z, 0.0, out.x) * turning
	var facing := Basis.looking_at(-ahead, Vector3.UP)   # its front is +Z
	# banked into the turn: its top towards the middle of the circle
	var bank := Basis(ahead, deg_to_rad(BANK_DEGREES) * turning)
	var nose_down := Basis(Vector3.RIGHT, deg_to_rad(NOSE_DOWN_DEGREES))
	basis = bank * facing * nose_down


func _spin(rotor: MeshInstance3D, angle: float, radians_per_second: float) -> void:
	rotor.set_instance_shader_parameter("turn", angle)
	rotor.set_instance_shader_parameter("spin_blur", clampf((radians_per_second - BLUR_FROM) / BLUR_FROM, 0.0, 1.0))


# ------------------------------------------------------------------ the model

func _build_body() -> void:
	# skids on struts
	for side in [-1.0, 1.0]:
		_box(Vector3(0.1, 0.1, 3.6), Vector3(side * 0.95, 0.05, 0.3), METAL)
		_box(Vector3(0.1, 0.1, 0.3), Vector3(side * 0.95, 0.12, 2.15), METAL)   # the turned-up toe
		for along in [-0.5, 1.1]:
			_box(Vector3(0.08, 0.5, 0.08), Vector3(side * 0.9, 0.35, along), METAL)
	# the cabin, the nose and the engine on top
	_box(Vector3(1.9, 1.0, 4.2), Vector3(0.0, 1.0, 0.3), BLUE)
	_box(Vector3(1.8, 0.9, 3.4), Vector3(0.0, 1.95, 0.1), BLUE)
	_box(Vector3(1.6, 0.9, 0.8), Vector3(0.0, 1.15, 2.75), BLUE)
	_box(Vector3(1.1, 0.55, 0.4), Vector3(0.0, 1.05, 3.3), BLUE)
	_box(Vector3(1.2, 0.5, 2.2), Vector3(0.0, 2.65, -0.2), BLUE)
	_box(Vector3(0.22, 0.45, 0.22), Vector3(0.0, 3.1, 0.1), METAL)   # the rotor mast
	# glass: the windscreen in front, the side windows of the cabin
	_box(Vector3(1.66, 0.7, 0.8), Vector3(0.0, 1.85, 2.2), GLASS)
	_box(Vector3(1.94, 0.5, 2.0), Vector3(0.0, 1.95, 0.7), GLASS)
	# the police stripes along the flanks: a white band with an orange one under it
	_box(Vector3(1.94, 0.26, 4.24), Vector3(0.0, 1.32, 0.3), WHITE)
	_box(Vector3(1.95, 0.1, 4.25), Vector3(0.0, 1.12, 0.3), ORANGE)
	_box(Vector3(1.64, 0.26, 0.82), Vector3(0.0, 1.32, 2.75), WHITE)
	_box(Vector3(1.65, 0.1, 0.83), Vector3(0.0, 1.12, 2.75), ORANGE)
	# the tail: the boom, thinner at the end, the fin, the stabiliser
	_box(Vector3(0.6, 0.6, 5.0), Vector3(0.0, 1.95, -4.2), BLUE)
	_box(Vector3(0.62, 0.14, 5.0), Vector3(0.0, 1.95, -4.2), WHITE)
	_box(Vector3(0.45, 0.45, 1.4), Vector3(0.0, 2.0, -7.1), BLUE)
	_box(Vector3(0.16, 1.7, 1.0), Vector3(0.0, 2.85, -7.45), BLUE)
	_box(Vector3(2.1, 0.1, 0.55), Vector3(0.0, 2.05, -6.5), BLUE)
	# POLITIE on both flanks, white on the blue under the stripes
	for side in [-1.0, 1.0]:
		var word := Label3D.new()
		word.text = "POLITIE"
		word.font = load(FONT)
		word.font_size = 64
		word.pixel_size = 0.0075
		word.modulate = WHITE
		word.outline_size = 0
		word.double_sided = false
		word.position = Vector3(side * 0.96, 0.78, 0.4)
		word.rotation.y = side * PI / 2.0
		add_child(word)


func _build_lights() -> void:
	# red on its left (x > 0, as it faces +Z), green on its right, white on the tail
	_lamp(Vector3(0.3, 0.3, 0.3), Vector3(1.05, 1.55, 1.6), RED, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	_lamp(Vector3(0.3, 0.3, 0.3), Vector3(-1.05, 1.55, 1.6), GREEN, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	_lamp(Vector3(0.25, 0.25, 0.25), Vector3(0.0, 2.0, -7.95), LAMP_WHITE, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	# the strobe on top of the fin and the beacon under the belly, flashing in turn
	_strobe = _lamp(Vector3(0.35, 0.35, 0.35), Vector3(0.0, 3.85, -7.6), Color.WHITE, FLASH_LIGHT_ENERGY, FLASH_LIGHT_RANGE)
	_beacon = _lamp(Vector3(0.45, 0.25, 0.45), Vector3(0.0, 0.42, 0.2), RED, FLASH_LIGHT_ENERGY, FLASH_LIGHT_RANGE)
	# two landing lamps under the nose, and the search lamp between them
	for side in [-1.0, 1.0]:
		_lamp(Vector3(0.3, 0.18, 0.3), Vector3(side * 0.45, 0.52, 3.0), LAMP_WHITE, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	_lamp(Vector3(0.4, 0.25, 0.4), Vector3(0.0, 0.5, 2.6), LAMP_WHITE, 0.0, 0.0)
	_searchlight = SpotLight3D.new()
	_searchlight.name = "Zoeklicht"
	_searchlight.light_color = Color(1.0, 0.97, 0.88)
	_searchlight.light_energy = 12.0
	_searchlight.spot_range = 90.0
	_searchlight.spot_angle = 9.0
	_searchlight.shadow_enabled = false
	_searchlight.position = Vector3(0.0, 0.5, 2.6)
	_searchlight.basis = Basis.looking_at(Vector3(0.0, -1.0, 0.7))   # ahead and down
	_searchlight.visible = false
	add_child(_searchlight)


func _rotor(radius: float, blade_count: int, turned: Basis, at: Vector3) -> MeshInstance3D:
	var square := PlaneMesh.new()
	square.size = Vector2.ONE * radius * 2.0
	var material := ShaderMaterial.new()
	material.shader = ROTOR_SHADER
	material.set_shader_parameter("blades", blade_count)
	square.material = material
	var rotor := MeshInstance3D.new()
	rotor.name = "Rotor"
	rotor.mesh = square
	rotor.transform = Transform3D(turned, at)
	rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rotor)
	return rotor


func _box(size: Vector3, centre: Vector3, colour: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.35 if colour == GLASS else 0.7
	material.metallic = 0.4 if colour == GLASS or colour == METAL else 0.05
	box.material = material
	var part := MeshInstance3D.new()
	part.mesh = box
	part.position = centre
	add_child(part)
	return part


## A glowing lamp: a box past bright (unshaded, LAMP_GLOW) and, if `light_energy` > 0, a
## small light round it that goes on and off with it.
func _lamp(size: Vector3, centre: Vector3, colour: Color, light_energy: float, light_range: float) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = LAMP_GLOW
	box.material = material
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	lamp.mesh = box
	lamp.position = centre
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamp)
	if light_energy > 0.0:
		var glow := OmniLight3D.new()
		glow.light_color = colour
		glow.light_energy = light_energy
		glow.omni_range = light_range
		glow.shadow_enabled = false
		lamp.add_child(glow)
	return lamp
