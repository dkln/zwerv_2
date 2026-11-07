class_name Microcar
extends Vehicle
## A microcar for the disabled ("gehandicaptenauto", a 45 km/h brommobiel like a Canta;
## props/voertuigen/gehandicaptenauto, also _blauw; tools/voxgen/tiles/small_vehicles.py,
## 2.5 x 1.13 m) on four small wheels (klein_wiel). Drives where cars drive ("auto"), slowly.


func _init() -> void:
	model = "voertuigen/gehandicaptenauto"
	model_lift = 0.125
	wheel_model = "voertuigen/klein_wiel"
	# hubs from the tile (MICROCAR_HUBS): 0.81 m forwards and back, 0.25 m up, 0.44 m out
	wheel_positions = PackedVector3Array([
		Vector3(-0.44, 0.25, 0.8125), Vector3(0.44, 0.25, 0.8125),
		Vector3(-0.44, 0.25, -0.8125), Vector3(0.44, 0.25, -0.8125)])
	wheel_radius = 0.25
	headlight_positions = PackedVector3Array([Vector3(-0.375, 0.5625, 1.255), Vector3(0.375, 0.5625, 1.255)])
	headlight_size = Vector3(0.14, 0.14, 0.03)
	tail_light_positions = PackedVector3Array([Vector3(-0.375, 0.625, -1.255), Vector3(0.375, 0.625, -1.255)])
	tail_light_size = Vector3(0.14, 0.26, 0.03)
	top_speed_kmh = 45.0
	corner_speed = 3.5
	tight_corner_speed = 2.5
	wheel_torque = 135.0
	braking = 3.5
	half_length = 1.3
	mass_kg = 450.0
