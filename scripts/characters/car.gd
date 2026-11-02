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
	max_steering_degrees = 35.0
	top_speed_kmh = 130.0
	corner_speed = 4.5
	tight_corner_speed = 2.8
	acceleration = 2.5
	braking = 4.0
	half_length = 2.4
