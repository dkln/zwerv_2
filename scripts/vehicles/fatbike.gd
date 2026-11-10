class_name Fatbike
extends TwoWheeler
## A fatbike: an electric bicycle on fat tyres (BicycleParts with fat tubes and a battery,
## no mudguards or carrier, on the car wheel auto_wiel, as wide as a fat tyre), its rider
## pedalling. A "fiets" (cycle paths too), but 30 km/h and quick off the mark; a front and
## a rear lamp, no brake light or indicators.


func _init() -> void:
	bicycle = true
	fat_tyres = true
	bicycle_paints = [Color("#1E1F24"), Color("#5A5E64"), Color("#E8E6E0")]
	rider_kind = "fiets"
	wheel_model = "voertuigen/auto_wiel"
	wheel_positions = PackedVector3Array([BicycleParts.point(BicycleParts.FRONT_HUB.x, BicycleParts.FRONT_HUB.y),
		BicycleParts.point(BicycleParts.REAR_HUB.x, BicycleParts.REAR_HUB.y)])
	wheel_radius = 0.375
	max_steering_degrees = 25.0
	headlight_positions = PackedVector3Array([BicycleParts.front_lamp() + Vector3(0.0, 0.0, 0.035)])
	headlight_size = Vector3(0.07, 0.07, 0.03)
	tail_light_positions = PackedVector3Array([BicycleParts.point(22.5, 9.5) + Vector3(0.0, 0.0, -0.035)])
	tail_light_size = Vector3(0.07, 0.07, 0.03)
	brake_lights = false
	vehicle_kind = "fiets"
	top_speed_kmh = 30.0
	leans = true
	max_lean_degrees = 18.0
	countersteer = 0.14
	corner_speed = 4.0
	tight_corner_speed = 2.8
	wheel_torque = 62.0
	braking = 3.5
	half_length = 0.9
	mass_kg = 110.0
	wheelie_degrees = 22.0
	wheelie_kind = "fatbike"
