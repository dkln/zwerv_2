class_name Moped
extends Vehicle
## A moped ("brommer", like a Tomos) with its helmeted rider (props/voertuigen/brommer,
## tools/voxgen/tiles/small_vehicles.py, 1.75 m long) on two thin moped wheels
## (brommer_wiel). A "brommer": on the road and on the cycle paths that allow mopeds; 45 km/h.


func _init() -> void:
	model = "voertuigen/brommer"
	model_lift = 0.125
	wheel_model = "voertuigen/brommer_wiel"
	# hubs from the tile (MOPED_HUBS): 0.5625 m forwards and back, 0.3125 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.3125, 0.5625), Vector3(0.0, 0.3125, -0.5625)])
	wheel_radius = 0.3125
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 1.0625, 0.51)])
	headlight_size = Vector3(0.14, 0.14, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.8125, -0.89)])
	tail_light_size = Vector3(0.14, 0.14, 0.03)
	vehicle_kind = "brommer"
	top_speed_kmh = 45.0
	corner_speed = 4.0
	tight_corner_speed = 2.8
	wheel_torque = 90.0
	braking = 4.0
	half_length = 0.9
	mass_kg = 160.0
