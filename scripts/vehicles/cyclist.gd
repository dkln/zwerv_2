class_name Cyclist
extends Vehicle
## A cyclist ("fietser"): a Vehicle (vehicle.gd, all the driving) with a Dutch bicycle and its
## rider in one model (props/voertuigen/fietser, also _rood; tools/voxgen/tiles/two_wheelers.py,
## 1.75 m long, 6 cm voxels) on two thin bicycle wheels (fiets_wiel). A "fiets": it may also take the
## cycle paths (RoadNetwork.allows). 20 km/h, a front and a rear lamp, no brake light or
## indicators; the front wheel hardly steers.


func _init() -> void:
	model = "voertuigen/fietser"
	model_lift = 0.125
	wheel_model = "voertuigen/fiets_wiel"
	# hubs from the tile (BIKE_HUBS): 0.5625 m forwards and back, 0.375 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.375, 0.5625), Vector3(0.0, 0.375, -0.5625)])
	wheel_radius = 0.375
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 0.6875, 0.5)])
	headlight_size = Vector3(0.07, 0.13, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.8438, -0.875)])
	tail_light_size = Vector3(0.07, 0.07, 0.03)
	brake_lights = false
	vehicle_kind = "fiets"
	top_speed_kmh = 20.0
	leans = true
	max_lean_degrees = 15.0
	corner_speed = 3.5
	tight_corner_speed = 2.5
	wheel_torque = 36.0
	braking = 3.0
	half_length = 0.9
	mass_kg = 95.0
