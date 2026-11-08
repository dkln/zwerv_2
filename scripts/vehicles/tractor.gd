class_name Tractor
extends Vehicle
## A farm tractor ("trekker"): a Vehicle (vehicle.gd, all the driving) with the tractor body
## (props/voertuigen/trekker, also _rood; tools/voxgen/tiles/small_vehicles.py, 3.75 m long),
## big rear wheels (tractor_wiel, 1.25 m) and small steering front wheels (auto_wiel, 0.75
## m). Heavy and slow: 25 km/h, slow off the mark. Drives where cars drive ("auto").
## The front wheels are the smaller car wheel (front_wheel_model), rolling at their own rate.
## Some fly the upside-down Dutch flag of the protesting farmers (FLAG_CHANCE, by their seed;
## protest_flag.gd).

const ProtestFlag = preload("res://scripts/vehicles/protest_flag.gd")
## The share of tractors with the upside-down flag on the cab.
const FLAG_CHANCE := 0.5

func _init() -> void:
	model = "voertuigen/trekker"
	model_lift = 0.25
	wheel_model = "voertuigen/tractor_wiel"
	# hubs from the tile (TRACTOR_*_HUB): the front wheels 1.25 m forwards, 0.375 m up and
	# 0.56 m out; the rear wheels 0.875 m back, 0.625 m up and 0.75 m out
	wheel_positions = PackedVector3Array([
		Vector3(-0.5625, 0.375, 1.25), Vector3(0.5625, 0.375, 1.25),
		Vector3(-0.75, 0.625, -0.875), Vector3(0.75, 0.625, -0.875)])
	wheel_radius = 0.625
	front_wheel_model = "voertuigen/auto_wiel"
	front_wheel_radius = 0.375
	max_steering_degrees = 35.0
	headlight_positions = PackedVector3Array([Vector3(-0.375, 1.0625, 1.88), Vector3(0.375, 1.0625, 1.88)])
	headlight_size = Vector3(0.14, 0.14, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-0.75, 1.1875, -1.63), Vector3(0.75, 1.1875, -1.63)])
	tail_light_size = Vector3(0.14, 0.14, 0.03)
	top_speed_kmh = 25.0
	corner_speed = 3.0
	tight_corner_speed = 2.2
	wheel_torque = 2250.0
	braking = 3.0
	half_length = 1.9
	mass_kg = 4500.0


func _ready() -> void:
	super()
	if _body and posmod(route_seed * 7919 + 13, 100) < roundi(FLAG_CHANCE * 100.0):
		_body.add_child(ProtestFlag.new())
