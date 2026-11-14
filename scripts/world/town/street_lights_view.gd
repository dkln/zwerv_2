extends RefCounted
## The lights of the street lamps (graphics; docs/CODE_LAGEN.md): a pool of real lights
## without shadows, warm and yellow-white by the kind of lamp (colour_of), built into the
## node of street_lights.gd (build), which says where each one burns and how strongly
## (show_light, hide_light, show_strength).
##   const StreetLightsView = preload("res://scripts/world/town/street_lights_view.gd")

## The colour of the light per lamp; DEFAULT_COLOUR for any other.
const LAMP_COLOURS := {
	"verlichting/lantaarn_modern": Color("#FFF1DA"),
	"verlichting/lantaarn_klassiek": Color("#FFD79A"),
	"verlichting/lantaarn_wand_klassiek": Color("#FFD79A"),
	"verlichting/lantaarn_klassiek_dubbel": Color("#FFD79A"),
	"verlichting/lantaarn_gietijzer": Color("#FFD79A"),
	"verlichting/lantaarn_park": Color("#FFE2B0"),
	"verlichting/lantaarn_middenberm": Color("#FFF1DA"),
}
const DEFAULT_COLOUR := Color("#FFE2B0")
## How bright a light is at full strength, and how its light falls off.
const ENERGY := 1.8
const ATTENUATION := 1.3
const SPECULAR := 0.25

var lights: Array[OmniLight3D] = []


## The colour of the light of lamp `item_name`.
static func colour_of(item_name: String) -> Color:
	return LAMP_COLOURS.get(item_name, DEFAULT_COLOUR)


## Builds `count` lights as children of `host`, all off.
func build(host: Node3D, count: int) -> void:
	for light_index in count:
		var light := OmniLight3D.new()
		light.shadow_enabled = false
		light.omni_attenuation = ATTENUATION
		light.light_specular = SPECULAR
		light.visible = false
		host.add_child(light)
		lights.append(light)


## Light `index` burning at `at` (world), reaching `reach` metres, in `colour`.
func show_light(index: int, at: Vector3, reach: float, colour: Color) -> void:
	var light := lights[index]
	light.global_position = at
	light.omni_range = reach
	light.light_color = colour
	light.visible = true


## Light `index` off.
func hide_light(index: int) -> void:
	lights[index].visible = false


## All lights off.
func hide_all() -> void:
	for light in lights:
		light.visible = false


## All lights `strength` (0..1) of their full brightness.
func show_strength(strength: float) -> void:
	for light in lights:
		light.light_energy = ENERGY * strength


## How many lights burn now.
func lit_count() -> int:
	var lit := 0
	for light in lights:
		if light.visible:
			lit += 1
	return lit
