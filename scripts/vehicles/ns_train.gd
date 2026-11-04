class_name NsTrain
extends RailVehicle
## An NS train in yellow and blue of two train sets with two cars each, so with a cab at
## both ends and in the middle (props/voertuigen/ns_kop and ns_midden are its cars,
## tools/voxgen/tiles/rail_vehicles.py). Of kind "trein", so it only rides on the train
## rails; those have no traffic lights.


func _init() -> void:
	vehicle_kind = "trein"
	obeys_lights = false
	model = "voertuigen/ns_kop"
	car_models = ["voertuigen/ns_midden", "voertuigen/ns_midden", "voertuigen/ns_kop"]
	reversed_cars = [3]
	car_length = 13.0
	car_gap = 0.5
	platform_names = ["perron"]
	model_lift = 0.375
	headlight_positions = PackedVector3Array([Vector3(-1.0, 1.1, 6.55), Vector3(1.0, 1.1, 6.55)])
	headlight_size = Vector3(0.4, 0.2, 0.03)
	top_speed_kmh = 80.0
	corner_speed = 4.0
	tight_corner_speed = 1.5
	acceleration = 0.9
	braking = 1.1
	half_length = 6.8
	mass_kg = 200000.0
