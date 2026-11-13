extends Node3D
## Walking into or out of a building, seen from close by (Interiors.enter and leave): a
## little scene at the way in on the street. A stand-in of the player (PlayerModel, as in
## the lift) walks to the door and through it (in) or comes out of it onto the pavement
## (out), a camera of its own close behind them (in: from the street, over the shoulder,
## looking at the door) or before them (out: they walk towards it), and the door of the
## place moves: sliding leaves that part ("schuif": the supermarkets, the station), a door
## that swings in on its hinge ("klap": a snack bar) or a revolving door turning with them
## ("draai": the city hall). The real player is hidden meanwhile and the camera of the game
## comes back after. The door stands flush before the facade (FACADE_BACK behind the door
## point of the way in) and is gone when the scene ends.
##   await DoorPassage.play(town, player, way_in.door, way_in.outward, "schuif", true)

signal finished

const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const KINDS := ["schuif", "klap", "draai"]
## The door: how far behind the door point of the way in the facade is (m), its size, the
## colours of its frame and glass.
const FACADE_BACK := 0.9
const DOOR_WIDTH := 1.8
const DOOR_HEIGHT := 2.3
const FRAME := Color("#2A2E38")
const GLASS := Color(0.55, 0.75, 0.85, 0.45)
## The walk: from this far before the facade (m) to this far through it, at this speed (m/s);
## the door starts to move this long before they are at it (s).
const WALK_FROM := 2.6
const WALK_THROUGH := 0.7
const WALK_SPEED := 2.2
const DOOR_SECONDS := 0.45
## The camera: behind the walker going in (back, up, aside in metres from the door, looking
## at the door at LOOK_HEIGHT), its field of view.
const CAMERA_BACK := 5.2
const CAMERA_UP := 2.1
const CAMERA_ASIDE := 1.1
const LOOK_HEIGHT := 1.2
const CAMERA_FOV := 38.0

var _kind := "schuif"
var _going_in := true
var _stand_in: Node3D
var _camera: Camera3D
var _camera_before: Camera3D
var _player: Node3D
var _leaves: Array[Node3D] = []
var _walked := 0.0
var _length := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _door_moved := 0.0
var _done := false
var _player_moved_before := true


## Plays the passage under `parent` for `player` at the way in whose door point is `door`
## and whose street side is `outward`, with a door of `kind`; `going_in`: into the building,
## else out of it. Await it: it returns when the walk is over (the real player shown again,
## the game's camera back). Returns at once without a camera to give back or a player.
static func play(parent: Node, player: Node3D, door: Vector3, outward: Vector3, kind: String, going_in: bool) -> void:
	if parent == null or player == null or not parent.is_inside_tree():
		return
	var passage: Node3D = (load("res://scripts/world/door_passage.gd") as GDScript).new()
	passage.name = "Deurscène"
	parent.add_child(passage)
	passage.call("_begin", player, door, outward.normalized() if outward.length() > 0.01 else Vector3.BACK, kind, going_in)
	if not bool(passage.get("_done")):
		await passage.finished
	passage.queue_free()


## How long the whole passage takes (s), for whoever waits beside it.
static func seconds_of() -> float:
	return (WALK_FROM + WALK_THROUGH) / WALK_SPEED


func _begin(player: Node3D, door: Vector3, outward: Vector3, kind: String, going_in: bool) -> void:
	_player = player
	_kind = kind if kind in KINDS else "schuif"
	_going_in = going_in
	# this node at the foot of the door in the facade, its +z out onto the street
	var facade := door - outward * FACADE_BACK
	global_transform = Transform3D(Basis.looking_at(-outward, Vector3.UP), facade)
	_build_door()
	var street := Vector3(0.0, 0.0, WALK_FROM)
	var inside := Vector3(0.0, 0.0, -WALK_THROUGH)
	_from = street if going_in else inside
	_to = inside if going_in else street
	_length = _from.distance_to(_to)
	_make_stand_in()
	_camera_before = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_camera.position = Vector3(CAMERA_ASIDE, CAMERA_UP, CAMERA_BACK)
	_camera.look_at(global_transform * Vector3(0.0, LOOK_HEIGHT, 0.0), Vector3.UP)
	_camera.make_current()
	_player.visible = false
	# the real player stands still meanwhile (the keys do nothing)
	_player_moved_before = _player.is_physics_processing()
	_player.set_physics_process(false)


func _process(delta: float) -> void:
	if _done or _stand_in == null:
		return
	_walked = minf(_walked + WALK_SPEED * delta, _length)
	var share := _walked / maxf(_length, 0.01)
	_stand_in.position = _from.lerp(_to, share)
	# the door: open by the time they are at it, shut again behind them
	var at_door := absf(_stand_in.position.z)
	var wanted := 1.0 if at_door < WALK_SPEED * DOOR_SECONDS + 0.9 else 0.0
	_door_moved = move_toward(_door_moved, wanted, delta / DOOR_SECONDS)
	_move_door(_door_moved, share)
	if _walked >= _length:
		_end()


func _end() -> void:
	_done = true
	if _stand_in and is_instance_valid(_stand_in):
		_stand_in.queue_free()
	if _camera_before and is_instance_valid(_camera_before):
		_camera_before.make_current()
	if _player and is_instance_valid(_player):
		_player.visible = true
		_player.set_physics_process(_player_moved_before)
	finished.emit()


## The door in its frame: two leaves that slide apart, one that swings in, or four wings
## round a post.
func _build_door() -> void:
	var half := DOOR_WIDTH * 0.5
	_add_box(Vector3(0.12, DOOR_HEIGHT + 0.12, 0.14), Vector3(-half - 0.06, (DOOR_HEIGHT + 0.12) * 0.5, 0.0), FRAME)
	_add_box(Vector3(0.12, DOOR_HEIGHT + 0.12, 0.14), Vector3(half + 0.06, (DOOR_HEIGHT + 0.12) * 0.5, 0.0), FRAME)
	_add_box(Vector3(DOOR_WIDTH + 0.24, 0.12, 0.14), Vector3(0.0, DOOR_HEIGHT + 0.06, 0.0), FRAME)
	match _kind:
		"schuif":
			for side: float in [-1.0, 1.0]:
				var leaf := Node3D.new()
				leaf.position = Vector3(side * half * 0.5, 0.0, 0.0)
				leaf.set_meta("side", side)
				add_child(leaf)
				leaf.add_child(_pane(Vector3(half, DOOR_HEIGHT, 0.05), Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0)))
				_leaves.append(leaf)
		"klap":
			var hinge := Node3D.new()
			hinge.position = Vector3(-half, 0.0, 0.0)
			add_child(hinge)
			hinge.add_child(_pane(Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.06), Vector3(half, DOOR_HEIGHT * 0.5, 0.0)))
			_leaves.append(hinge)
		"draai":
			var post := Node3D.new()
			add_child(post)
			post.add_child(_box_of(Vector3(0.1, DOOR_HEIGHT, 0.1), Vector3(0.0, DOOR_HEIGHT * 0.5, 0.0), FRAME))
			for wing in 4:
				var arm := Node3D.new()
				arm.rotation.y = wing * PI * 0.5
				post.add_child(arm)
				arm.add_child(_pane(Vector3(half - 0.05, DOOR_HEIGHT, 0.04), Vector3((half - 0.05) * 0.5 + 0.05, DOOR_HEIGHT * 0.5, 0.0)))
			_leaves.append(post)


## The door `open` (0 shut .. 1 open); `share`: how far the walk is (the revolving door
## turns with it).
func _move_door(open: float, share: float) -> void:
	var half := DOOR_WIDTH * 0.5
	match _kind:
		"schuif":
			for leaf in _leaves:
				var side := float(leaf.get_meta("side", 1.0))
				leaf.position.x = side * (half * 0.5 + open * half)
		"klap":
			_leaves[0].rotation.y = open * deg_to_rad(88.0)   # swinging in, away from the street
		"draai":
			_leaves[0].rotation.y = share * PI * (1.0 if _going_in else -1.0)


func _add_box(box_size: Vector3, at: Vector3, colour: Color) -> void:
	add_child(_box_of(box_size, at, colour))


static func _box_of(box_size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = material
	instance.position = at
	return instance


## A leaf: glass in a dark rim.
static func _pane(leaf_size: Vector3, at: Vector3) -> Node3D:
	var leaf := Node3D.new()
	leaf.position = at
	leaf.add_child(_box_of(leaf_size - Vector3(0.12, 0.12, 0.0), Vector3.ZERO, GLASS))
	for edge: float in [-1.0, 1.0]:
		leaf.add_child(_box_of(Vector3(0.06, leaf_size.y, leaf_size.z), Vector3(edge * (leaf_size.x * 0.5 - 0.03), 0.0, 0.0), FRAME))
		leaf.add_child(_box_of(Vector3(leaf_size.x, 0.06, leaf_size.z), Vector3(0.0, edge * (leaf_size.y * 0.5 - 0.03), 0.0), FRAME))
	return leaf


## The player's stand-in, walking (as the lift's: the character, its size, its rucksack).
func _make_stand_in() -> void:
	var model := PlayerModel.new()
	model.name = "Speler"
	model.archetype_id = PlayerCharacter.current_id()
	model.figure_scale = float(_player.get("FIGURE_SCALE")) if _player.get("FIGURE_SCALE") != null else 0.78
	model.backpack = bool(_player.get("has_backpack")) if _player.get("has_backpack") != null else false
	add_child(model)
	model.position = _from
	# facing the way it walks: in is -z (the model's front is +z)
	model.rotation.y = PI if _going_in else 0.0
	model.walking = 1.0
	_stand_in = model


## What the scene shows (for the checks).
func parts() -> Dictionary:
	return {"stand_in": _stand_in, "camera": _camera, "leaves": _leaves, "kind": _kind, "open": _door_moved}
