class_name FireEngine
extends Truck
## A fire engine (props/voertuigen/auto_brandweer: the truck in red with a closed body of
## lockers, a ladder on the roof and a light bar on the cab): a Truck with a siren and blue
## lights (vehicle.gd, `emergency`), heavier and with more power.


func _init() -> void:
	super()
	model = "voertuigen/auto_brandweer"
	emergency = true
	# the blue halves of the light bar (tile: across 3-7 and 10-14, along 3-5, height 22)
	beacon_positions = PackedVector3Array([Vector3(-0.4375, 2.8125, 2.9375), Vector3(0.4375, 2.8125, 2.9375)])
	beacon_size = Vector3(0.65, 0.16, 0.4)
	top_speed_kmh = 110.0
	mass_kg = 14000.0
	horn_sound = "brandweer_hoorn"
	wheel_torque = 11000.0
