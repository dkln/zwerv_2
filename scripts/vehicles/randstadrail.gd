class_name RandstadRail
extends RailVehicle
## A RandstadRail tram of three articulated cars (props/voertuigen/randstadrail_kop at both
## ends, a cab each, randstadrail_midden between them; tools/voxgen/tiles/rail_vehicles.py):
## 33.5 m, longer than the stops of 6 cells (24 m). Of kind "tram", so it only rides on the tram rails, and it obeys the
## traffic lights it shares with the cars.


func _init() -> void:
	vehicle_kind = "tram"
	model = "voertuigen/randstadrail_kop"
	car_models = ["voertuigen/randstadrail_midden", "voertuigen/randstadrail_kop"]
	reversed_cars = [2]
	door_model = "voertuigen/randstadrail_deur"
	car_length = 11.0
	car_gap = 0.25
	model_lift = 0.0
	# over the lamp voxels of the tile (across 4-5 and 15-16, height 9, on the front)
	headlight_positions = PackedVector3Array([Vector3(-0.6875, 1.1875, 5.505), Vector3(0.6875, 1.1875, 5.505)])
	headlight_size = Vector3(0.25, 0.125, 0.03)
	# over the red voxels between them
	rear_lamp_positions = PackedVector3Array([Vector3(-0.3125, 1.1875, -5.505), Vector3(0.3125, 1.1875, -5.505)])
	tail_light_size = Vector3(0.25, 0.125, 0.03)
	# where a line branches off it takes the branch: from the street to the viaduct
	straight_chance = 0.0
	variety = 0.0
	top_speed_kmh = 60.0
	corner_speed = 3.0
	tight_corner_speed = 1.5
	wheel_torque = 0.0
	acceleration = 1.1
	braking = 1.4
	half_length = 5.8
	mass_kg = 50000.0
