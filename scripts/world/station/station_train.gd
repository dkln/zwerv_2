class_name StationTrain
extends Node3D
## A train in Den Haag Centraal (scripts/world/station/station.gd): two or three cars of the NS train
## of the town (props/voertuigen/ns_kop and ns_midden, the door leaves ns_deur), on one track
## of the hall. A head station: it comes in through its opening in the back wall nose first
## (-z), brakes to a stop just before the buffer stop (StationLayout.STOP_NOSE_Z), opens the
## doors on the side of its platform, and when it leaves it goes back out the way it came
## (the driver changed ends). It does not follow the road network of the town: it only goes
## to and fro along z, which is all a track in a head station does. A car whose middle is
## more than HIDE_BEYOND behind the back wall is not drawn (the camera would see it over the
## wall), so it comes out of the dark of the opening.
## The node stands at the middle of its track at the height of the rails (-PLATFORM_DROP);
## `nose_z` is where the front of the first car is.

signal arrived
signal gone

const Layout = preload("res://scripts/world/station/station_layout.gd")
const CAR_LENGTH := 13.0
const CAR_GAP := 0.5
const MODEL_LIFT := 0.375
const VOXEL := 0.125
## Door leaves (as RailVehicle): voxels under the floor, of a leaf along the car, the voxel
## of each door along the car (from its front end), how far a leaf steps out and slides.
const DOOR_SILL_VOXELS := 4
const DOOR_LEAF_VOXELS := 5
const DOOR_VOXELS := [26, 78]
const DOOR_STEP_OUT := 0.125
const DOOR_STEP_SHARE := 0.25
const DOOR_TIME := 1.4
## Moving: the speed coming in and going out (m/s), braking and pulling away (m/s²).
const TOP_SPEED := 11.0
const BRAKING := 0.85
const ACCELERATION := 0.6
const HIDE_BEYOND := 6.0
## Where it starts coming in: this far behind the back wall (its nose).
const START_BEHIND := 8.0
## Running into someone on the track (_hit_who_is_in_the_way): this much room beside and
## before it (m), and up to what height over the rails someone counts as on the track (above
## it they stand on the platform).
const HIT_SIDE_ROOM := 0.15
const HIT_HIGHEST := 1.0
## The group of the player (PlayerController.PLAYER_GROUP).
const PLAYER_GROUP := "speler"
## The engine: its loop and level, and the brakes near the stop.
const MOTOR_SOUND := "trein_motor_loop"
const MOTOR_DB := -9.0

var _motor_pitch := 1.0
var track := 1
var car_count := 3
var nose_z := 0.0
var speed := 0.0
## "binnenkomend" (coming in), "staat" (standing at the platform), "vertrekkend", "weg".
var state := "weg"
## The width of the train (from its cars' model), for who it runs into (_hit_who_is_in_the_way).
var _width := 2.9

var _cars: Array[Node3D] = []
var _leaves: Array[Dictionary] = []    # {node, closed: Vector3, slide: Vector3, outward: Vector3}
var _door_amount := 0.0
var _doors_wanted := false
var _motor: AudioStreamPlayer3D
var _braked := false


## A train of `cars` cars on `track`, built from the props library.
static func create(props: MeshLibrary, on_track: int, cars: int) -> StationTrain:
	var train := StationTrain.new()
	train.name = "Trein_spoor%d" % on_track
	train.track = on_track
	train.car_count = clampi(cars, 2, 3)
	train.position = Vector3(Layout.track_x(on_track), -Layout.PLATFORM_DROP, 0.0)
	for index in train.car_count:
		var model := "voertuigen/ns_midden"
		var turned := false
		if index == 0:
			model = "voertuigen/ns_kop"
			turned = true            # its cab looks to the buffer stop (-z)
		elif index == train.car_count - 1:
			model = "voertuigen/ns_kop"
		train._add_car(props, model, turned)
	return train


func _ready() -> void:
	_motor = StationAudio.loop_on(self, MOTOR_SOUND, MOTOR_DB)
	# every train its own engine (loop_on gave it a pitch of its own; the speed goes on top)
	_motor_pitch = _motor.pitch_scale if _motor else 1.0


## Its length from the nose to the back of the last car (metres).
func length() -> float:
	return car_count * CAR_LENGTH + (car_count - 1) * CAR_GAP


## Starts coming in from behind the back wall.
func come_in() -> void:
	nose_z = Layout.BACK_WALL + START_BEHIND
	speed = TOP_SPEED
	state = "binnenkomend"
	_braked = false
	_place_cars()
	if _motor:
		_motor.play()


## Puts it standing at its platform at once (the station as you walk in), doors open.
func stand() -> void:
	nose_z = Layout.STOP_NOSE_Z
	speed = 0.0
	state = "staat"
	_place_cars()
	_door_amount = 1.0
	_doors_wanted = true
	_set_doors()


func open_doors() -> void:
	if not _doors_wanted:
		_doors_wanted = true
		StationAudio.play_at(get_parent() as Node3D, "trein_deuren_open", position + Vector3(0.0, 1.5, nose_z + length() * 0.5), -4.0)


func close_doors() -> void:
	_doors_wanted = false


func doors_open() -> bool:
	return _doors_wanted and _door_amount >= 0.99


func doors_shut() -> bool:
	return not _doors_wanted and _door_amount <= 0.0


## Leaves: back out the way it came.
func leave() -> void:
	state = "vertrekkend"
	speed = 0.0
	if _motor:
		_motor.play()


## The spots on the platform before each of its doors on the platform side (in the space of
## the station): where people wait to get in and where they step out.
func door_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var side := Layout.platform_side(track)
	var x := Layout.platform_edge_x(track) + side * 0.55
	for index in car_count:
		var middle := _car_middle_z(index)
		for door_voxel: int in DOOR_VOXELS:
			spots.append(Vector3(x, 0.0, middle - CAR_LENGTH * 0.5 + door_voxel * VOXEL))
	return spots


## Inside the train behind a door spot (where someone getting in walks to, and where someone
## getting out starts): over the floor of the car.
func inside_of(door_spot: Vector3) -> Vector3:
	var side := Layout.platform_side(track)
	return Vector3(Layout.track_x(track) + side * 0.5, -0.45, door_spot.z)


## The first door of the first car (where the conductor stands).
func front_door_spot() -> Vector3:
	return door_spots()[0]


func _physics_process(delta: float) -> void:
	match state:
		"binnenkomend":
			var left := nose_z - Layout.STOP_NOSE_Z
			# as fast as it can still stop in what is left, and at most TOP_SPEED
			speed = minf(TOP_SPEED, sqrt(maxf(2.0 * BRAKING * left, 0.0)) + 0.15)
			nose_z -= speed * delta
			if left < 6.0 and not _braked:
				_braked = true
				StationAudio.play_at(get_parent() as Node3D, "bus_remmen", position + Vector3(0.0, 1.0, nose_z + 6.0), -8.0, 0.8)
			if nose_z <= Layout.STOP_NOSE_Z + 0.02:
				nose_z = Layout.STOP_NOSE_Z
				speed = 0.0
				state = "staat"
				if _motor:
					_motor.stop()
				arrived.emit()
			_place_cars()
		"vertrekkend":
			if doors_shut():
				speed = minf(TOP_SPEED, speed + ACCELERATION * delta)
				nose_z += speed * delta
				_place_cars()
				if nose_z - CAR_LENGTH * 0.5 > Layout.BACK_WALL + HIDE_BEYOND:
					state = "weg"
					if _motor:
						_motor.stop()
					gone.emit()
	if speed > 0.0 and (state == "binnenkomend" or state == "vertrekkend"):
		_hit_who_is_in_the_way()
	if _motor and _motor.playing:
		_motor.volume_db = MOTOR_DB - 10.0 * (1.0 - speed / TOP_SPEED)
		_motor.pitch_scale = (0.55 + 0.6 * speed / TOP_SPEED) * _motor_pitch
		_motor.position = Vector3(0.0, 1.5, nose_z + 4.0)
	var wanted := 1.0 if _doors_wanted and state == "staat" else 0.0
	var amount := move_toward(_door_amount, wanted, delta / DOOR_TIME)
	if amount != _door_amount:
		_door_amount = amount
		_set_doors()


## Who is on the track where the train is while it moves (the player, someone fallen off
## the platform) is hit, as by any vehicle in the town (hit_by_moving on the player and on a
## StationPerson: knocked over along the way it goes).
func _hit_who_is_in_the_way() -> void:
	var going := Vector3(0.0, 0.0, -speed if state == "binnenkomend" else speed)
	var train_velocity := global_basis * going
	var people: Array = get_tree().get_nodes_in_group(PLAYER_GROUP) + get_tree().get_nodes_in_group(StationPerson.TALKABLE_GROUP)
	for someone in people:
		var person := someone as Node3D
		if person == null or not person.has_method("hit_by_moving") or not person.is_visible_in_tree():
			continue
		var at := to_local(person.global_position)
		if absf(at.x) > _width * 0.5 + HIT_SIDE_ROOM or at.y < -0.6 or at.y > HIT_HIGHEST:
			continue
		if at.z < nose_z - HIT_SIDE_ROOM or at.z > nose_z + length() + HIT_SIDE_ROOM:
			continue
		person.call("hit_by_moving", train_velocity, person.global_position - going.normalized())


func _car_middle_z(index: int) -> float:
	return nose_z + CAR_LENGTH * 0.5 + index * (CAR_LENGTH + CAR_GAP)


func _place_cars() -> void:
	for index in _cars.size():
		var middle := _car_middle_z(index)
		_cars[index].position = Vector3(0.0, 0.0, middle)
		_cars[index].visible = middle < Layout.BACK_WALL + HIDE_BEYOND


func _add_car(props: MeshLibrary, item_name: String, turned_round: bool) -> void:
	var item := props.find_item_by_name(item_name) if props else -1
	if item < 0:
		push_warning("station train: no item '%s' in the props library" % item_name)
		return
	var mesh := props.get_item_mesh(item)
	var mesh_transform := props.get_item_mesh_transform(item)
	var box := mesh_transform * mesh.get_aabb()
	var middle := box.get_center()
	var car := Node3D.new()
	car.name = "Wagon%d" % (_cars.size() + 1)
	add_child(car)
	var instance := MeshInstance3D.new()
	instance.name = "Model"
	instance.mesh = mesh
	instance.transform = Transform3D(mesh_transform.basis, mesh_transform.origin - Vector3(middle.x, box.position.y - MODEL_LIFT, middle.z))
	if turned_round:
		instance.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * instance.transform
	car.add_child(instance)
	_cars.append(car)
	_add_doors(props, car, box.size.x)
	_width = box.size.x


## The leaves of the doors on the platform side of a car (two doors, two leaves each).
func _add_doors(props: MeshLibrary, car: Node3D, car_width: float) -> void:
	var item := props.find_item_by_name("voertuigen/ns_deur")
	if item < 0:
		return
	var mesh := props.get_item_mesh(item)
	var mesh_transform := props.get_item_mesh_transform(item)
	var leaf_box := mesh_transform * mesh.get_aabb()
	var side := float(Layout.platform_side(track))
	var leaf_height := MODEL_LIFT + DOOR_SILL_VOXELS * VOXEL + leaf_box.size.y * 0.5
	for door_voxel: int in DOOR_VOXELS:
		for slide_direction: float in [-1.0, 1.0]:
			var along := -CAR_LENGTH * 0.5 + (door_voxel + slide_direction * DOOR_LEAF_VOXELS * 0.5) * VOXEL
			var instance := MeshInstance3D.new()
			instance.name = "Deurblad"
			instance.mesh = mesh
			var wanted := Vector3(side * (car_width - VOXEL) * 0.5, leaf_height, along)
			var closed := mesh_transform.origin + wanted - leaf_box.get_center()
			instance.transform = Transform3D(mesh_transform.basis, closed)
			car.add_child(instance)
			_leaves.append({"node": instance, "closed": closed, "slide": Vector3(0.0, 0.0, slide_direction),
				"outward": Vector3(side, 0.0, 0.0)})


func _set_doors() -> void:
	var step := clampf(_door_amount / DOOR_STEP_SHARE, 0.0, 1.0)
	var slide := clampf((_door_amount - DOOR_STEP_SHARE) / (1.0 - DOOR_STEP_SHARE), 0.0, 1.0)
	for leaf in _leaves:
		var node := leaf.node as MeshInstance3D
		node.position = (leaf.closed as Vector3) + (leaf.outward as Vector3) * DOOR_STEP_OUT * step \
				+ (leaf.slide as Vector3) * DOOR_LEAF_VOXELS * VOXEL * slide
