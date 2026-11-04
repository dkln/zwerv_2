class_name Suv
extends Vehicle
## An SUV that drives round the town on its own (the "SUV" node of scenes/stad.tscn): a
## Vehicle (vehicle.gd, all the driving) with the SUV body (props/voertuigen/auto_suv,
## tools/voxgen/tiles/props.py: taller and longer than the sedan, dark green), the same
## wheels as the car, a little slower off the mark and heavier.


func _init() -> void:
	model = "voertuigen/auto_suv"
	model_lift = 0.125
	wheel_model = "voertuigen/auto_wiel"
	# wheel centres from the SUV tile (SUV_WHEEL_*): 0.75 m out from the middle,
	# 1.44 m forwards and back (the body is 4.75 m long), 0.375 m up
	wheel_positions = PackedVector3Array([
		Vector3(-0.75, 0.375, 1.4375), Vector3(0.75, 0.375, 1.4375),
		Vector3(-0.75, 0.375, -1.4375), Vector3(0.75, 0.375, -1.4375)])
	wheel_radius = 0.375
	# lamps over the lamp voxels of the SUV tile: headlights across 1-3 and 10-12 at the
	# front, height 6; tail lights the same across at the back, height 5-7; indicators in
	# the empty corner voxels, height 6
	headlight_positions = PackedVector3Array([Vector3(-0.5625, 0.8125, 2.38), Vector3(0.5625, 0.8125, 2.38)])
	headlight_size = Vector3(0.375, 0.125, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-0.5625, 0.8125, -2.38), Vector3(0.5625, 0.8125, -2.38)])
	tail_light_size = Vector3(0.375, 0.375, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-0.8125, 0.8125, 2.3125), Vector3(0.8125, 0.8125, 2.3125),
		Vector3(-0.8125, 0.8125, -2.3125), Vector3(0.8125, 0.8125, -2.3125)])
	indicator_size = Vector3(0.15, 0.13, 0.15)
	top_speed_kmh = 120.0
	corner_speed = 4.0
	tight_corner_speed = 2.5
	wheel_torque = 1575.0
	braking = 4.0
	half_length = 2.5
	mass_kg = 2100.0
