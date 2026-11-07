class_name RiotVan
extends Van
## An ME van of the police (props/voertuigen/auto_politie_busje: the van in police white
## with striping, POLITIE on the sides, grilles over the windows and a light bar): a Van
## with a siren and blue lights (vehicle.gd, `emergency`).


func _init() -> void:
	super()
	model = "voertuigen/auto_politie_busje"
	emergency = true
	# the blue halves of the light bar (tile: across 2-6 and 9-13, along 8-10, height 17)
	beacon_positions = PackedVector3Array([Vector3(-0.4375, 2.1875, 1.3125), Vector3(0.4375, 2.1875, 1.3125)])
	beacon_size = Vector3(0.65, 0.16, 0.4)
	top_speed_kmh = 130.0
	mass_kg = 3200.0
	wheel_torque = 2300.0
