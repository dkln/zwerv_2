extends Node3D
## What the police helicopter looks like (graphics; docs/CODE_LAGEN.md): blue, with the
## white and orange stripes of the police along its flanks and POLITIE on them, built of
## boxes in the voxel style. Its rotors are flat squares whose blades the rotor shader draws
## and turns (addons/vox_tiles/materials/voxel_rotor.gdshader, by `turn` and `spin_blur`, as
## the wheels of the vehicles). Glowing lamps that light up the body round them (LAMP_GLOW,
## each with a small light of its own): red and green on its sides, white on the tail, a
## white strobe on the fin and a red beacon under the belly, two landing lamps under the
## nose, and a search light ahead and down. The lamps are big enough to be seen from far off
## (the menu's camera is a few hundred metres away: a pixel is about 0.1 m there).
## Sizes and places: police_helicopter_layout.gd; police_helicopter.gd tells it how far the
## rotors are turned and which lamps are lit (show_rotors, show_flash, show_searchlight).
##   const PoliceHelicopterView = preload("res://scripts/vehicles/police_helicopter_view.gd")

const PoliceHelicopterLayout = preload("res://scripts/vehicles/police_helicopter_layout.gd")
const Outline = preload("res://scripts/effects/outline.gd")
const ROTOR_SHADER = preload("res://addons/vox_tiles/materials/voxel_rotor.gdshader")
const FONT := "res://assets/fonts/PixelifySans.ttf"

## The police's blue, the stripes, the glass, the dark metal.
const BLUE := Color("#1C3C8E")
const WHITE := Color("#F2F2EE")
const ORANGE := Color("#E8541C")
const GLASS := Color("#1A2230")
const METAL := Color("#3A3D44")
## The colour of each part of the body (PoliceHelicopterLayout.body_boxes).
const PART_COLOURS := {"blue": BLUE, "white": WHITE, "orange": ORANGE, "glass": GLASS, "metal": METAL}
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
const SEARCHLIGHT_COLOUR := Color(1.0, 0.97, 0.88)
const SEARCHLIGHT_ENERGY := 12.0
## The blades of the main rotor and of the tail rotor.
const MAIN_ROTOR_BLADES := 4
const TAIL_ROTOR_BLADES := 2
const WORD := "POLITIE"
const WORD_FONT_SIZE := 64

var _main_rotor: MeshInstance3D
var _tail_rotor: MeshInstance3D
var _strobe: MeshInstance3D
var _beacon: MeshInstance3D
var _searchlight: SpotLight3D


func _init() -> void:
	name = "Beeld"
	_build_body()
	_main_rotor = _rotor(PoliceHelicopterLayout.MAIN_ROTOR_RADIUS, MAIN_ROTOR_BLADES,
			PoliceHelicopterLayout.main_rotor_basis(), PoliceHelicopterLayout.MAIN_ROTOR_AT)
	_tail_rotor = _rotor(PoliceHelicopterLayout.TAIL_ROTOR_RADIUS, TAIL_ROTOR_BLADES,
			PoliceHelicopterLayout.tail_rotor_basis(), PoliceHelicopterLayout.TAIL_ROTOR_AT)
	_build_lights()
	Outline.apply(self)


## The rotors turned to these angles (radians), their blades blurred this much (0 .. 1).
func show_rotors(main_angle: float, main_blur: float, tail_angle: float, tail_blur: float) -> void:
	_show_spin(_main_rotor, main_angle, main_blur)
	_show_spin(_tail_rotor, tail_angle, tail_blur)


## The strobe on the fin and the beacon under the belly lit or not (each with its light).
func show_flash(strobe_lit: bool, beacon_lit: bool) -> void:
	_strobe.visible = strobe_lit
	_beacon.visible = beacon_lit


## The search light on or off.
func show_searchlight(on: bool) -> void:
	_searchlight.visible = on


func main_rotor() -> MeshInstance3D:
	return _main_rotor


func tail_rotor() -> MeshInstance3D:
	return _tail_rotor


func strobe() -> MeshInstance3D:
	return _strobe


func beacon() -> MeshInstance3D:
	return _beacon


func searchlight() -> SpotLight3D:
	return _searchlight


func _show_spin(rotor: MeshInstance3D, angle: float, blur: float) -> void:
	rotor.set_instance_shader_parameter("turn", angle)
	rotor.set_instance_shader_parameter("spin_blur", blur)


# ------------------------------------------------------------------ the model

func _build_body() -> void:
	for body_box: Dictionary in PoliceHelicopterLayout.body_boxes():
		_box(body_box.size, body_box.centre, PART_COLOURS[body_box.part])
	# POLITIE on both flanks, white on the blue under the stripes
	for side: float in PoliceHelicopterLayout.SIDES:
		var word := Label3D.new()
		word.text = WORD
		word.font = load(FONT)
		word.font_size = WORD_FONT_SIZE
		word.pixel_size = PoliceHelicopterLayout.WORD_PIXEL_SIZE
		word.modulate = WHITE
		word.outline_size = 0
		word.double_sided = false
		word.position = PoliceHelicopterLayout.word_position(side)
		word.rotation.y = PoliceHelicopterLayout.word_turn(side)
		add_child(word)


func _build_lights() -> void:
	# red on its left (x > 0, as it faces +Z), green on its right, white on the tail
	_lamp(PoliceHelicopterLayout.LEFT_LAMP, RED, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	_lamp(PoliceHelicopterLayout.RIGHT_LAMP, GREEN, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	_lamp(PoliceHelicopterLayout.TAIL_LAMP, LAMP_WHITE, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	# the strobe on top of the fin and the beacon under the belly, flashing in turn
	_strobe = _lamp(PoliceHelicopterLayout.STROBE, Color.WHITE, FLASH_LIGHT_ENERGY, FLASH_LIGHT_RANGE)
	_beacon = _lamp(PoliceHelicopterLayout.BEACON, RED, FLASH_LIGHT_ENERGY, FLASH_LIGHT_RANGE)
	# two landing lamps under the nose, and the search lamp between them
	for side: float in PoliceHelicopterLayout.SIDES:
		_lamp([PoliceHelicopterLayout.LANDING_LAMP_SIZE, PoliceHelicopterLayout.landing_lamp_centre(side)],
				LAMP_WHITE, LAMP_LIGHT_ENERGY, LAMP_LIGHT_RANGE)
	_lamp(PoliceHelicopterLayout.SEARCH_LAMP, LAMP_WHITE, 0.0, 0.0)
	_searchlight = SpotLight3D.new()
	_searchlight.name = "Zoeklicht"
	_searchlight.light_color = SEARCHLIGHT_COLOUR
	_searchlight.light_energy = SEARCHLIGHT_ENERGY
	_searchlight.spot_range = PoliceHelicopterLayout.SEARCHLIGHT_RANGE
	_searchlight.spot_angle = PoliceHelicopterLayout.SEARCHLIGHT_ANGLE
	_searchlight.shadow_enabled = false
	_searchlight.position = PoliceHelicopterLayout.SEARCHLIGHT_AT
	_searchlight.basis = PoliceHelicopterLayout.searchlight_basis()
	_searchlight.visible = false
	add_child(_searchlight)


func _rotor(radius: float, blade_count: int, turned: Basis, at: Vector3) -> MeshInstance3D:
	var square := PlaneMesh.new()
	square.size = PoliceHelicopterLayout.rotor_size(radius)
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


## A glowing lamp of `size_and_centre` ([size, middle]): a box past bright (unshaded,
## LAMP_GLOW) and, if `light_energy` > 0, a small light round it that goes on and off with it.
func _lamp(size_and_centre: Array, colour: Color, light_energy: float, light_range: float) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size_and_centre[0]
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
	lamp.position = size_and_centre[1]
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
