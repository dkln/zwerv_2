class_name NsTrain
extends RailVehicle
## An NS train in yellow and blue of three cars with a cab at both ends (props/voertuigen/ns_kop
## and ns_midden, tools/voxgen/tiles/rail_vehicles.py): 40 m, for the platforms of 11 cells
## (44 m). Of kind "trein", so it only rides on the train rails; those have no
## traffic lights.


func _init() -> void:
	vehicle_kind = "trein"
	obeys_lights = false
	model = "voertuigen/ns_kop"
	car_models = ["voertuigen/ns_midden", "voertuigen/ns_kop"]
	reversed_cars = [2]
	door_model = "voertuigen/ns_deur"
	car_length = 13.0
	car_gap = 0.5
	own_track = true   # the two trains each keep their own track
	model_lift = 0.375
	# over the lamp voxels of the tile (across 4-5 and 16-17, height 9, on the front)
	headlight_positions = PackedVector3Array([Vector3(-0.75, 1.5625, 6.505), Vector3(0.75, 1.5625, 6.505)])
	headlight_size = Vector3(0.25, 0.125, 0.03)
	# over the red voxels between them
	rear_lamp_positions = PackedVector3Array([Vector3(-0.375, 1.5625, -6.505), Vector3(0.375, 1.5625, -6.505)])
	tail_light_size = Vector3(0.25, 0.125, 0.03)
	top_speed_kmh = 80.0
	corner_speed = 4.0
	tight_corner_speed = 1.5
	acceleration = 0.9
	braking = 1.1
	half_length = 6.8
	mass_kg = 200000.0
