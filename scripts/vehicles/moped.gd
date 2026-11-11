class_name Moped
extends TwoWheeler
## A moped ("brommer", like a Tomos; props/voertuigen/brommer, tools/voxgen/tiles/two_wheelers.py,
## 1.75 m long, 6 cm voxels) on two thin moped wheels (brommer_wiel), its rider a
## townsperson in an open helmet (TwoWheeler: on the seat, feet on the footrests, hands on
## the grips). A "brommer": on the road and on the cycle paths that allow mopeds; 45 km/h.


func _init() -> void:
	# the rider: on the seat (cells up 12..13), feet on the footrests, hands on the grips
	rider_kind = "helm"
	rider_hip = TwoWheeler.tile_point(20.5, 14.8, 0.0, 14.0)
	rider_foot = TwoWheeler.tile_point(17.0, 4.0, 3.5, 14.0)
	rider_grip = TwoWheeler.tile_point(10.5, 18.5, 4.5, 14.0)
	model = "voertuigen/brommer"
	model_lift = 0.125
	wheel_model = "voertuigen/brommer_wiel"
	# hubs from the tile (MOPED_HUBS): 0.5625 m forwards and back, 0.3125 m up
	wheel_positions = PackedVector3Array([Vector3(0.0, 0.3125, 0.5625), Vector3(0.0, 0.3125, -0.5625)])
	wheel_radius = 0.3125
	max_steering_degrees = 15.0
	headlight_positions = PackedVector3Array([Vector3(0.0, 1.0312, 0.44)])
	headlight_size = Vector3(0.07, 0.07, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(0.0, 0.7812, -0.875)])
	tail_light_size = Vector3(0.07, 0.07, 0.03)
	vehicle_kind = "brommer"
	top_speed_kmh = 45.0
	leans = true
	max_lean_degrees = 22.0
	corner_speed = 4.0
	tight_corner_speed = 2.8
	wheel_torque = 90.0
	braking = 4.0
	half_length = 0.9
	mass_kg = 160.0
	wheelie_degrees = 55.0
	wheelie_kind = "brommer"
