class_name Cyclist
extends Vehicle
## A cyclist ("fietser"): a Vehicle (vehicle.gd, all the driving) with a Dutch bicycle and its
## rider in one model (props/voertuigen/fietser, also _rood; tools/voxgen/tiles/small_vehicles.py,
## 1.75 m long) on two thin bicycle wheels (fiets_wiel). A "fiets": it may also take the
## cycle paths (RoadNetwork.allows). 20 km/h, a front and a rear lamp, no brake light or
## indicators; the front wheel hardly steers.


func _init() -> void:
	model = "voertuigen/fietser"
	model_lift = 0.125
	wheel_model = "voertuigen/fiets_wiel"
	# hubs from the tile (BIKE_HUBS): 0.625 m forwards and 0.5 m back, 0.375 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.375, 0.625), Vector3(0.0, 0.375, -0.5)])
	wheel_radius = 0.375
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 0.8125, 0.64)])
	headlight_size = Vector3(0.14, 0.14, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.8125, -0.89)])
	tail_light_size = Vector3(0.14, 0.14, 0.03)
	brake_lights = false
	vehicle_kind = "fiets"
	top_speed_kmh = 20.0
	corner_speed = 3.5
	tight_corner_speed = 2.5
	wheel_torque = 36.0
	braking = 3.0
	half_length = 0.9
	mass_kg = 95.0
