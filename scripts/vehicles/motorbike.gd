class_name Motorbike
extends Vehicle
## A motorbike ("motorfiets") with its rider in leathers (props/voertuigen/motorfiets,
## tools/voxgen/tiles/small_vehicles.py, 2 m long) on the car wheels (auto_wiel). Drives
## where cars drive ("auto"), up to 130 km/h, quick off the mark; a headlight, a tail light
## and four indicators.


func _init() -> void:
	model = "voertuigen/motorfiets"
	model_lift = 0.25
	wheel_model = "voertuigen/auto_wiel"
	# hubs from the tile (MOTORBIKE_HUBS): 0.75 m forwards and 0.625 m back, 0.375 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.375, 0.75), Vector3(0.0, 0.375, -0.625)])
	wheel_radius = 0.375
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 1.1875, 0.64)])
	headlight_size = Vector3(0.14, 0.14, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.8125, -1.015)])
	tail_light_size = Vector3(0.14, 0.14, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-0.25, 1.1875, 0.5625), Vector3(0.25, 1.1875, 0.5625),
		Vector3(-0.25, 0.9375, -0.9375), Vector3(0.25, 0.9375, -0.9375)])
	indicator_size = Vector3(0.14, 0.14, 0.14)
	top_speed_kmh = 130.0
	corner_speed = 5.0
	tight_corner_speed = 3.0
	wheel_torque = 450.0
	braking = 5.0
	half_length = 1.0
	mass_kg = 300.0
