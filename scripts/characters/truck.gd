class_name Truck
extends Vehicle
## A small truck with an open cargo bed that drives round the town on its own: a Vehicle
## (vehicle.gd, all the driving) with the truck body (props/voertuigen/auto_vrachtwagen,
## tools/voxgen/tiles/props.py: 7 m long, 2.25 m wide, a heap of sand in the bed) and the
## big wheels. Slow off the mark, slow round the corners, heavy.


func _init() -> void:
	model = "voertuigen/auto_vrachtwagen"
	model_lift = 0.25
	wheel_model = "voertuigen/auto_wiel_groot"
	# wheel centres from the tile (TRUCK_WHEEL_ALONG): 0.94 m out from the middle, 2.375 m
	# forwards and 2 m back, 0.5 m up
	wheel_positions = PackedVector3Array([
		Vector3(-0.9375, 0.5, 2.375), Vector3(0.9375, 0.5, 2.375),
		Vector3(-0.9375, 0.5, -2.0), Vector3(0.9375, 0.5, -2.0)])
	wheel_radius = 0.5
	# lamps over the lamp voxels of the tile: headlights across 1-3 and 14-16, height 5;
	# tail lights the same across on the bar at the back, height 6-7; indicators on the corners
	headlight_positions = PackedVector3Array([Vector3(-0.8125, 0.6875, 3.505), Vector3(0.8125, 0.6875, 3.505)])
	headlight_size = Vector3(0.375, 0.125, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-0.8125, 0.875, -3.505), Vector3(0.8125, 0.875, -3.505)])
	tail_light_size = Vector3(0.375, 0.25, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-1.0625, 0.6875, 3.44), Vector3(1.0625, 0.6875, 3.44),
		Vector3(-1.0625, 0.875, -3.44), Vector3(1.0625, 0.875, -3.44)])
	indicator_size = Vector3(0.15, 0.13, 0.15)
	top_speed_kmh = 85.0
	corner_speed = 3.2
	tight_corner_speed = 2.0
	wheel_torque = 4875.0
	braking = 3.2
	half_length = 3.6
	mass_kg = 7500.0
