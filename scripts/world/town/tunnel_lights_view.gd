extends Node3D
## The lamps in the tunnels (graphics; docs/CODE_LAGEN.md): the node "Lampen" under the
## tunnel lights with a downward spot light per lamp, warm white, without shadows (so they
## cost little, and no light comes through the roof onto the street above). tunnel_lights.gd
## says where they hang and whether they are on (add_lamp, show_lit).
##   const TunnelLightsView = preload("res://scripts/world/town/tunnel_lights_view.gd")

const LAMP_COLOUR := Color(1.0, 0.96, 0.88)
const ATTENUATION := 0.6


func _init() -> void:
	name = "Lampen"


## A lamp at `at` (in this node's space) shining straight down: `energy` bright, reaching
## `reach` metres, its cone `angle` degrees either side.
func add_lamp(at: Vector3, energy: float, reach: float, angle: float) -> SpotLight3D:
	var lamp := SpotLight3D.new()
	lamp.light_color = LAMP_COLOUR
	lamp.light_energy = energy
	lamp.spot_range = reach
	lamp.spot_angle = angle
	lamp.spot_attenuation = ATTENUATION
	lamp.shadow_enabled = false
	lamp.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # straight down
	lamp.position = at
	add_child(lamp)
	return lamp


## All lamps on or off.
func show_lit(on: bool) -> void:
	visible = on


## How many lamps hang there.
func lamp_count() -> int:
	return get_child_count()
