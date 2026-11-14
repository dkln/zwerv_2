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
## Behaviour (docs/CODE_LAGEN.md): the node in the sky, its clock and its angles; the sums
## are police_helicopter_rules.gd's, the sizes police_helicopter_layout.gd's, the model and
## its lamps police_helicopter_view.gd's.
##   const PoliceHelicopter = preload("res://scripts/vehicles/police_helicopter.gd")

const PoliceHelicopterRules = preload("res://scripts/vehicles/police_helicopter_rules.gd")
const PoliceHelicopterLayout = preload("res://scripts/vehicles/police_helicopter_layout.gd")
const PoliceHelicopterView = preload("res://scripts/vehicles/police_helicopter_view.gd")

## The numbers of the rules, the layout and the view, under the names they had here.
const MAIN_ROTOR_TURNS := PoliceHelicopterRules.MAIN_ROTOR_TURNS
const TAIL_ROTOR_TURNS := PoliceHelicopterRules.TAIL_ROTOR_TURNS
const BLUR_FROM := PoliceHelicopterRules.BLUR_FROM
const FLASH_CYCLE := PoliceHelicopterRules.FLASH_CYCLE
const FLASH_LIT := PoliceHelicopterRules.FLASH_LIT
const BANK_DEGREES := PoliceHelicopterRules.BANK_DEGREES
const NOSE_DOWN_DEGREES := PoliceHelicopterRules.NOSE_DOWN_DEGREES
const SEARCHLIGHT_FROM := PoliceHelicopterRules.SEARCHLIGHT_FROM
const MAIN_ROTOR_RADIUS := PoliceHelicopterLayout.MAIN_ROTOR_RADIUS
const MAIN_ROTOR_AT := PoliceHelicopterLayout.MAIN_ROTOR_AT
const TAIL_ROTOR_RADIUS := PoliceHelicopterLayout.TAIL_ROTOR_RADIUS
const TAIL_ROTOR_AT := PoliceHelicopterLayout.TAIL_ROTOR_AT
const ROTOR_SHADER = PoliceHelicopterView.ROTOR_SHADER
const FONT := PoliceHelicopterView.FONT
const BLUE := PoliceHelicopterView.BLUE
const WHITE := PoliceHelicopterView.WHITE
const ORANGE := PoliceHelicopterView.ORANGE
const GLASS := PoliceHelicopterView.GLASS
const METAL := PoliceHelicopterView.METAL
const LAMP_GLOW := PoliceHelicopterView.LAMP_GLOW
const LAMP_LIGHT_ENERGY := PoliceHelicopterView.LAMP_LIGHT_ENERGY
const LAMP_LIGHT_RANGE := PoliceHelicopterView.LAMP_LIGHT_RANGE
const FLASH_LIGHT_ENERGY := PoliceHelicopterView.FLASH_LIGHT_ENERGY
const FLASH_LIGHT_RANGE := PoliceHelicopterView.FLASH_LIGHT_RANGE
const RED := PoliceHelicopterView.RED
const GREEN := PoliceHelicopterView.GREEN
const LAMP_WHITE := PoliceHelicopterView.LAMP_WHITE

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

## Its picture (made when it comes into the tree).
var view: PoliceHelicopterView

var _rotor_angle := 0.0
var _tail_angle := 0.0
var _circle_angle := 0.0


func _init() -> void:
	name = "Politiehelikopter"


func _ready() -> void:
	view = PoliceHelicopterView.new()
	add_child(view)


func _process(delta: float) -> void:
	_rotor_angle = PoliceHelicopterRules.rotor_angle(_rotor_angle, MAIN_ROTOR_TURNS, delta)
	_tail_angle = PoliceHelicopterRules.rotor_angle(_tail_angle, TAIL_ROTOR_TURNS, delta)
	view.show_rotors(_rotor_angle, PoliceHelicopterRules.spin_blur(PoliceHelicopterRules.rotor_speed(MAIN_ROTOR_TURNS)),
			_tail_angle, PoliceHelicopterRules.spin_blur(PoliceHelicopterRules.rotor_speed(TAIL_ROTOR_TURNS)))
	var flash := PoliceHelicopterRules.flash_phase(Time.get_ticks_msec() / 1000.0)
	view.show_flash(PoliceHelicopterRules.strobe_lit(flash), PoliceHelicopterRules.beacon_lit(flash))
	var night: float = day_cycle.get("night") if day_cycle else 0.0
	view.show_searchlight(PoliceHelicopterRules.searchlight_on(night))
	if circling:
		_fly_circle(delta)


## On round the circle: the nose along it, banked into the turn, the nose a little down.
func _fly_circle(delta: float) -> void:
	_circle_angle = PoliceHelicopterRules.circle_angle(_circle_angle, anticlockwise, circle_speed, circle_radius, delta)
	position = PoliceHelicopterRules.circle_position(circle_centre, circle_radius, circle_height, _circle_angle)
	basis = PoliceHelicopterRules.circle_basis(_circle_angle, anticlockwise)
