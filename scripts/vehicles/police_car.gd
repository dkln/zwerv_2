class_name PoliceCar
extends Car
## A police car (props/voertuigen/auto_politie: the white sedan with the Dutch striping and
## a light bar): a Car with a siren and blue lights (vehicle.gd, `emergency`), a little
## quicker off the mark.


func _init() -> void:
	super()
	model = "voertuigen/auto_politie"
	emergency = true
	# the blue halves of the light bar (tile: across 2-5 and 8-11, along 17-18, height 11)
	beacon_positions = PackedVector3Array([Vector3(-0.375, 1.4375, 0.0), Vector3(0.375, 1.4375, 0.0)])
	beacon_size = Vector3(0.52, 0.16, 0.28)
	top_speed_kmh = 160.0
	wheel_torque = 1500.0
