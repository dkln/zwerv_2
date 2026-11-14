extends Node3D
## The upside-down Dutch flag of the protesting farmers (blue on top, red at the bottom) on
## a pole on the rear corner of a tractor's cab roof, waving gently. Built of boxes in the
## voxel style; placed in the vehicle's frame (+Z ahead, x = 0 in the middle, metres), as
## tractor.gd and the columns of the menu (main_menu.gd) use it.
## Behaviour (docs/CODE_LAGEN.md): the node on the tractor and its clock; how it waves is
## protest_flag_rules.gd's, where it stands protest_flag_layout.gd's, its model
## protest_flag_view.gd's.
##   const ProtestFlag = preload("res://scripts/vehicles/protest_flag.gd")

const ProtestFlagRules = preload("res://scripts/vehicles/protest_flag_rules.gd")
const ProtestFlagLayout = preload("res://scripts/vehicles/protest_flag_layout.gd")
const ProtestFlagView = preload("res://scripts/vehicles/protest_flag_view.gd")

## The sizes, the colours and the waving, under the names they had here.
const POLE_FOOT := ProtestFlagLayout.POLE_FOOT
const POLE_HEIGHT := ProtestFlagLayout.POLE_HEIGHT
const POLE_WIDTH := ProtestFlagLayout.POLE_WIDTH
const CLOTH_SIZE := ProtestFlagLayout.CLOTH_SIZE
const BANDS := ProtestFlagView.BANDS
const POLE_COLOUR := ProtestFlagView.POLE_COLOUR
const WAVE_DEGREES := ProtestFlagRules.WAVE_DEGREES
const WAVE_SPEED := ProtestFlagRules.WAVE_SPEED

## Its picture.
var view: ProtestFlagView

var _wave_offset := 0.0


func _init() -> void:
	name = "Protestvlag"
	position = POLE_FOOT
	view = ProtestFlagView.new()
	add_child(view)


func _ready() -> void:
	_wave_offset = ProtestFlagRules.wave_offset(get_instance_id())


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	view.show_wave(ProtestFlagRules.cloth_turn(Time.get_ticks_msec() / 1000.0 + _wave_offset))
