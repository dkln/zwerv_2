class_name Motorbike
extends Vehicle
## A motorbike ("motorfiets") with its rider in leathers (props/voertuigen/motorfiets,
## tools/voxgen/tiles/two_wheelers.py, 2.1 m long, 6 cm voxels) on the car wheels (auto_wiel). Drives
## where cars drive ("auto"), up to 130 km/h, quick off the mark; a headlight, a tail light
## and four indicators.


func _init() -> void:
	model = "voertuigen/motorfiets"
	model_lift = 0.25
	wheel_model = "voertuigen/auto_wiel"
	# hubs from the tile (MOTORBIKE_HUBS): 0.69 m forwards and back, 0.375 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.375, 0.6875), Vector3(0.0, 0.375, -0.6875)])
	wheel_radius = 0.375
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 1.0312, 0.56)])
	headlight_size = Vector3(0.19, 0.07, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.9688, -1.06)])
	tail_light_size = Vector3(0.07, 0.07, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-0.25, 1.0312, 0.4688), Vector3(0.25, 1.0312, 0.4688),
		Vector3(-0.1875, 0.9062, -0.9688), Vector3(0.1875, 0.9062, -0.9688)])
	indicator_size = Vector3(0.08, 0.08, 0.08)
	top_speed_kmh = 130.0
	leans = true
	max_lean_degrees = 28.0
	corner_speed = 5.0
	tight_corner_speed = 3.0
	wheel_torque = 450.0
	braking = 5.0
	half_length = 1.05
	mass_kg = 300.0
