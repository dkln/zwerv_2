class_name RandstadRail
extends RailVehicle
## A RandstadRail tram of three articulated cars (props/voertuigen/randstadrail_kop and
## _midden, tools/voxgen/tiles/rail_vehicles.py) with a cab at both ends. Of kind "tram", so
## it only rides on the tram rails, and it obeys the traffic lights it shares with the cars.


func _init() -> void:
	vehicle_kind = "tram"
	model = "voertuigen/randstadrail_kop"
	car_models = ["voertuigen/randstadrail_midden", "voertuigen/randstadrail_kop"]
	reversed_cars = [2]
	car_length = 11.0
	car_gap = 0.25
	platform_names = ["perron"]
	model_lift = 0.0
	headlight_positions = PackedVector3Array([Vector3(-0.875, 0.75, 5.55), Vector3(0.875, 0.75, 5.55)])
	headlight_size = Vector3(0.4, 0.2, 0.03)
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
