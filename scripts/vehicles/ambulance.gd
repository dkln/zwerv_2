class_name Ambulance
extends Van
## An ambulance (props/voertuigen/auto_ambulance: the van in yellow with red and blue
## striping, AMBULANCE on the sides and a light bar): a Van with a siren and blue lights
## (vehicle.gd, `emergency`).


func _init() -> void:
	super()
	model = "voertuigen/auto_ambulance"
	emergency = true
	# the blue halves of the light bar (tile: across 2-6 and 9-13, along 8-10, height 17)
	beacon_positions = PackedVector3Array([Vector3(-0.4375, 2.1875, 1.3125), Vector3(0.4375, 2.1875, 1.3125)])
	beacon_size = Vector3(0.65, 0.16, 0.4)
	top_speed_kmh = 140.0
	mass_kg = 3500.0
	wheel_torque = 2500.0
