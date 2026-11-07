class_name Scooter
extends Vehicle
## A 45 km/h scooter with its rider (props/voertuigen/scooter, also _zwart;
## tools/voxgen/tiles/small_vehicles.py, 1.75 m long) on two small wheels (klein_wiel). A
## "brommer": on the road and on the cycle paths that allow mopeds.


func _init() -> void:
	model = "voertuigen/scooter"
	model_lift = 0.125
	wheel_model = "voertuigen/klein_wiel"
	# hubs from the tile (SCOOTER_HUBS): 0.625 m forwards and back, 0.25 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.25, 0.625), Vector3(0.0, 0.25, -0.625)])
	wheel_radius = 0.25
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 1.0625, 0.64)])
	headlight_size = Vector3(0.14, 0.14, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.6875, -0.89)])
	tail_light_size = Vector3(0.14, 0.14, 0.03)
	vehicle_kind = "brommer"
	top_speed_kmh = 45.0
	corner_speed = 4.0
	tight_corner_speed = 2.8
	wheel_torque = 76.0
	braking = 4.0
	half_length = 0.9
	mass_kg = 170.0
