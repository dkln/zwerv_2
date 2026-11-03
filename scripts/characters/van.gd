class_name Van
extends Vehicle
## A white delivery van that drives round the town on its own: a Vehicle (vehicle.gd, all
## the driving) with the van body (props/voertuigen/auto_busje,
## tools/voxgen/tiles/props.py: 5 m long, 2 m wide, windows in the cab only) and the wheels
## of the car, further apart.


func _init() -> void:
	model = "voertuigen/auto_busje"
	model_lift = 0.125
	wheel_model = "voertuigen/auto_wiel"
	# wheel centres from the tile (VAN_WHEEL_ALONG): 0.875 m out from the middle, 1.5 m
	# forwards and 1.375 m back, 0.375 m up
	wheel_positions = PackedVector3Array([
		Vector3(-0.875, 0.375, 1.5), Vector3(0.875, 0.375, 1.5),
		Vector3(-0.875, 0.375, -1.375), Vector3(0.875, 0.375, -1.375)])
	wheel_radius = 0.375
	# lamps over the lamp voxels of the tile: headlights across 1-3 and 12-14, height 6;
	# tail lights across 1-2 and 13-14, height 6-9; indicators in the empty corner voxels
	headlight_positions = PackedVector3Array([Vector3(-0.6875, 0.8125, 2.505), Vector3(0.6875, 0.8125, 2.505)])
	headlight_size = Vector3(0.375, 0.125, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-0.75, 1.0, -2.505), Vector3(0.75, 1.0, -2.505)])
	tail_light_size = Vector3(0.25, 0.5, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-0.9375, 0.8125, 2.4375), Vector3(0.9375, 0.8125, 2.4375),
		Vector3(-0.9375, 0.8125, -2.4375), Vector3(0.9375, 0.8125, -2.4375)])
	indicator_size = Vector3(0.15, 0.13, 0.15)
	top_speed_kmh = 110.0
	corner_speed = 4.0
	tight_corner_speed = 2.5
	wheel_torque = 1800.0
	braking = 3.8
	half_length = 2.6
	mass_kg = 2400.0
