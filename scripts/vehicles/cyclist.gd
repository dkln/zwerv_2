class_name Cyclist
extends TwoWheeler
## A cyclist ("fietser"): a TwoWheeler on a Dutch bicycle built in code (BicycleParts: black,
## dark blue, green, red or cream, a third with a low step-through frame) on two thin
## bicycle wheels (fiets_wiel), its rider pedalling. A "fiets": it may also take the cycle
## paths (RoadNetwork.allows). 20 km/h, a front and a rear lamp, no brake light or
## indicators; it leans into corners and countersteers into them.


func _init() -> void:
	bicycle = true
	bicycle_paints = [Color("#1E1F24"), Color("#1E2E4A"), Color("#2E4A34"), Color("#A82A2A"), Color("#D8CFB4")]
	step_through_share = 35
	rider_kind = "fiets"
	wheel_model = "voertuigen/fiets_wiel"
	wheel_positions = PackedVector3Array([BicycleParts.point(BicycleParts.FRONT_HUB.x, BicycleParts.FRONT_HUB.y),
		BicycleParts.point(BicycleParts.REAR_HUB.x, BicycleParts.REAR_HUB.y)])
	wheel_radius = 0.375
	max_steering_degrees = 25.0
	headlight_positions = PackedVector3Array([BicycleParts.front_lamp() + Vector3(0.0, 0.0, 0.035)])
	headlight_size = Vector3(0.07, 0.07, 0.03)
	tail_light_positions = PackedVector3Array([BicycleParts.rear_lamp() + Vector3(0.0, 0.0, -0.035)])
	tail_light_size = Vector3(0.07, 0.07, 0.03)
	brake_lights = false
	vehicle_kind = "fiets"
	top_speed_kmh = 20.0
	leans = true
	max_lean_degrees = 18.0
	countersteer = 0.14
	corner_speed = 3.5
	tight_corner_speed = 2.5
	wheel_torque = 36.0
	braking = 3.0
	half_length = 0.9
	mass_kg = 95.0
