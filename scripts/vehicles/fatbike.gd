class_name Fatbike
extends Vehicle
## A fatbike: an electric bicycle on fat tyres with its rider (props/voertuigen/fatbike,
## tools/voxgen/tiles/two_wheelers.py, 6 cm voxels) on the car wheel (auto_wiel, as wide as a fat
## tyre). A "fiets" (cycle paths too), but 30 km/h and quick off the mark; a front and a rear
## lamp, no brake light or indicators.


func _init() -> void:
	model = "voertuigen/fatbike"
	model_lift = 0.125
	wheel_model = "voertuigen/auto_wiel"
	# hubs from the tile (BIKE_HUBS): 0.59 m forwards and 0.53 m back, 0.375 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.375, 0.5938), Vector3(0.0, 0.375, -0.5312)])
	wheel_radius = 0.375
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 0.6875, 0.53)])
	headlight_size = Vector3(0.07, 0.13, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.7188, -0.53)])
	tail_light_size = Vector3(0.07, 0.07, 0.03)
	brake_lights = false
	vehicle_kind = "fiets"
	top_speed_kmh = 30.0
	leans = true
	max_lean_degrees = 15.0
	corner_speed = 4.0
	tight_corner_speed = 2.8
	wheel_torque = 62.0
	braking = 3.5
	half_length = 0.9
	mass_kg = 110.0
