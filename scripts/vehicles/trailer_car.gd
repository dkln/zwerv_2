class_name TrailerCar
extends Hatchback
## A silver hatchback with a tow bar, pulling a trailer (props/voertuigen/auto_aanhanger,
## vehicle.gd under "trailer"): the trailer pivots on the ball of the tow bar. The same
## engine as the car alone pulling 500 kg more, and a trailer takes corners and braking calmly.


func _init() -> void:
	super()
	model = "voertuigen/auto_hatchback_zilver"
	hitch_model = "voertuigen/auto_trekhaak"
	# the ball, 0.4 m behind the back of the body (1.94 m), level with the coupling
	hitch_position = Vector3(0.0, 0.5, -2.34)
	trailer_model = "voertuigen/auto_aanhanger"
	trailer_lift = 0.375
	trailer_axle_distance = 2.125
	trailer_mass_kg = 500.0
	# on the trailer (tile: the axle 18 voxels behind the front, wheels 0.75 m out)
	trailer_wheel_positions = PackedVector3Array([Vector3(-0.75, 0.375, -2.125), Vector3(0.75, 0.375, -2.125)])
	# the tail lights across 3-4 and 9-10 of the back (25 voxels behind the front), height 4;
	# the indicators just outside them
	trailer_tail_light_positions = PackedVector3Array([Vector3(-0.375, 0.5625, -3.13), Vector3(0.375, 0.5625, -3.13)])
	trailer_indicator_positions = PackedVector3Array([Vector3(-0.5625, 0.5625, -3.13), Vector3(0.5625, 0.5625, -3.13)])
	top_speed_kmh = 90.0
	corner_speed = 3.5
	tight_corner_speed = 2.3
	braking = 3.0
