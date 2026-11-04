class_name CityBus
extends Vehicle
## A city bus that drives round the town on its own: a Vehicle (vehicle.gd, all the
## driving) with the bus body (props/voertuigen/auto_stadsbus,
## tools/voxgen/tiles/props.py: 10.5 m long, 2.5 m wide) and the big wheels. Of kind "bus",
## so it may use the bus lanes as well as the ordinary roads.


func _init() -> void:
	model = "voertuigen/auto_stadsbus"
	model_lift = 0.25
	wheel_model = "voertuigen/auto_wiel_groot"
	vehicle_kind = "bus"
	# wheel centres from the tile (BUS_WHEEL_ALONG): 1.06 m out from the middle, 3.375 m
	# forwards and 2.5 m back, 0.5 m up
	wheel_positions = PackedVector3Array([
		Vector3(-1.0625, 0.5, 3.375), Vector3(1.0625, 0.5, 3.375),
		Vector3(-1.0625, 0.5, -2.5), Vector3(1.0625, 0.5, -2.5)])
	wheel_radius = 0.5
	# lamps over the lamp voxels of the tile: headlights across 1-4 and 15-18, height 5;
	# tail lights across 1-2 and 17-18, height 5-8; indicators in the empty corner columns
	headlight_positions = PackedVector3Array([Vector3(-0.875, 0.6875, 5.255), Vector3(0.875, 0.6875, 5.255)])
	headlight_size = Vector3(0.5, 0.125, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-1.0, 0.875, -5.255), Vector3(1.0, 0.875, -5.255)])
	tail_light_size = Vector3(0.25, 0.5, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-1.1875, 0.6875, 5.1875), Vector3(1.1875, 0.6875, 5.1875),
		Vector3(-1.1875, 0.875, -5.1875), Vector3(1.1875, 0.875, -5.1875)])
	indicator_size = Vector3(0.15, 0.13, 0.15)
	top_speed_kmh = 70.0
	corner_speed = 3.0
	tight_corner_speed = 1.8
	wheel_torque = 6600.0
	braking = 2.8
	half_length = 5.4
	mass_kg = 12000.0
