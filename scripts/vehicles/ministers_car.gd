class_name MinistersCar
extends Car
## The car of a member of the cabinet (props/voertuigen/auto_dienstauto: the sedan in
## black): a Car driven calmly, no siren; it keeps to the rules like everyone else.


func _init() -> void:
	super()
	model = "voertuigen/auto_dienstauto"
	straight_chance = 0.7
	mass_kg = 1900.0
	wheel_torque = 1700.0
