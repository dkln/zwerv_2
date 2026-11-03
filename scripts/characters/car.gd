class_name Car
extends Vehicle
## A car that drives round the town on its own (the "Auto" node of scenes/stad.tscn): a
## Vehicle (vehicle.gd, all the driving) with the sedan body, its four wheels and the
## speeds of a car.


func _init() -> void:
	model = "voertuigen/auto_sedan"
	model_lift = 0.125            # the floor of the body, the wheels below it
	wheel_model = "voertuigen/auto_wiel"
	# wheel centres from the sedan tile (tools/voxgen/tiles/props.py, SEDAN_WHEEL_*):
	# 0.75 m out from the middle, 1.31 m forwards and 1.25 m back, 0.375 m up
	wheel_positions = PackedVector3Array([
		Vector3(-0.75, 0.375, 1.3125), Vector3(0.75, 0.375, 1.3125),
		Vector3(-0.75, 0.375, -1.25), Vector3(0.75, 0.375, -1.25)])
	wheel_radius = 0.375
	# lamps over the lamp voxels of the sedan tile (props.py: headlights across 1-3 and
	# 10-12 at the front, height 4; tail lights the same across at the back, height
	# 4-5; the indicators in the empty voxel of each rounded corner, height 4, so they
	# show from the front or back and from the side), in metres on the vehicle
	headlight_positions = PackedVector3Array([Vector3(-0.5625, 0.5625, 2.255), Vector3(0.5625, 0.5625, 2.255)])
	headlight_size = Vector3(0.375, 0.125, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-0.5625, 0.625, -2.255), Vector3(0.5625, 0.625, -2.255)])
	tail_light_size = Vector3(0.375, 0.25, 0.03)
	indicator_positions = PackedVector3Array([Vector3(-0.8125, 0.5625, 2.1875), Vector3(0.8125, 0.5625, 2.1875),
		Vector3(-0.8125, 0.5625, -2.1875), Vector3(0.8125, 0.5625, -2.1875)])
	indicator_size = Vector3(0.15, 0.13, 0.15)
	max_steering_degrees = 35.0
	top_speed_kmh = 130.0
	corner_speed = 4.5
	tight_corner_speed = 2.8
	acceleration = 2.5
	braking = 4.0
	half_length = 2.4
