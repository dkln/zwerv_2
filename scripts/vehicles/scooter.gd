class_name Scooter
extends TwoWheeler
## A 45 km/h scooter (props/voertuigen/scooter, also _zwart; tools/voxgen/tiles/two_wheelers.py,
## 1.75 m long, 6 cm voxels) on two small wheels (klein_wiel), its rider a townsperson in
## an open helmet (TwoWheeler: on the seat, feet on the floor, hands on the grips). A
## "brommer": on the road and on the cycle paths that allow mopeds.


func _init() -> void:
	# the rider: on the seat (cells up 11..12), feet on the floor, hands on the grips
	rider_kind = "helm"
	rider_hip = TwoWheeler.tile_point(20.5, 13.8, 0.0, 14.0)
	rider_foot = TwoWheeler.tile_point(13.5, 6.0, 2.5, 14.0)
	rider_grip = TwoWheeler.tile_point(8.5, 17.5, 4.5, 14.0)
	model = "voertuigen/scooter"
	model_lift = 0.125
	wheel_model = "voertuigen/klein_wiel"
	# hubs from the tile (SCOOTER_HUBS): 0.625 m forwards and back, 0.25 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.25, 0.625), Vector3(0.0, 0.25, -0.625)])
	wheel_radius = 0.25
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 1.0938, 0.5)])
	headlight_size = Vector3(0.19, 0.07, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.5625, -0.875)])
	tail_light_size = Vector3(0.19, 0.13, 0.03)
	vehicle_kind = "brommer"
	top_speed_kmh = 45.0
	leans = true
	max_lean_degrees = 22.0
	corner_speed = 4.0
	tight_corner_speed = 2.8
	wheel_torque = 76.0
	braking = 4.0
	half_length = 0.9
	mass_kg = 170.0
	wheelie_degrees = 50.0
	wheelie_kind = "brommer"
