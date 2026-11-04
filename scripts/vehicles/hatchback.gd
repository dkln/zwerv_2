class_name Hatchback
extends Vehicle
## A hatchback that drives round the town on its own: a Vehicle (vehicle.gd, all the
## driving) with the short hatchback body (props/voertuigen/auto_hatchback,
## tools/voxgen/tiles/props.py: 3.88 m long, red; also _zilver and _groen), the wheels of
## the car, quick off the mark and light.


func _init() -> void:
	model = "voertuigen/auto_hatchback"
	model_lift = 0.125
	wheel_model = "voertuigen/auto_wiel"
	# wheel centres from the tile (HATCHBACK_WHEEL_ALONG): 0.75 m out from the middle,
	# 1.125 m forwards and back, 0.375 m up
	wheel_positions = PackedVector3Array([
		Vector3(-0.75, 0.375, 1.125), Vector3(0.75, 0.375, 1.125),
		Vector3(-0.75, 0.375, -1.125), Vector3(0.75, 0.375, -1.125)])
	wheel_radius = 0.375
	# lamps over the lamp voxels of the tile: headlights across 1-3 and 10-12, height 4;
	# tail lights across 1-2 and 11-12, height 4-6; indicators in the empty corner voxels
	headlight_positions = PackedVector3Array([Vector3(-0.5625, 0.5625, 1.9425), Vector3(0.5625, 0.5625, 1.9425)])
	headlight_size = Vector3(0.375, 0.125, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-0.625, 0.6875, -1.9425), Vector3(0.625, 0.6875, -1.9425)])
	tail_light_size = Vector3(0.25, 0.375, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-0.8125, 0.5625, 1.875), Vector3(0.8125, 0.5625, 1.875),
		Vector3(-0.8125, 0.5625, -1.875), Vector3(0.8125, 0.5625, -1.875)])
	indicator_size = Vector3(0.15, 0.13, 0.15)
	top_speed_kmh = 120.0
	corner_speed = 4.5
	tight_corner_speed = 3.0
	wheel_torque = 1155.0
	braking = 4.0
	half_length = 2.0
	mass_kg = 1100.0
