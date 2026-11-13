class_name InteriorPerson
extends "res://scripts/world/people/person.gd"
## Someone in an interior (scripts/world/interiors/interior.gd): the man or woman behind the counter
## (`role` "snackbarhouder") or someone at a table (`role` "klant", sitting on its chair); and
## the people on the terraces in the town (scripts/world/people/terraces.gd), sitting as well.
## A seller in a shop of Den Haag Centraal is one too (`role` "verkoper", scripts/world/station/station.gd).
## Who sells (MERCHANT_ROLES) gets the arrow of the ways in over their head (InteractionMark).
## A townsperson (TownsfolkFigure, its look from `look_seed`), in the group of who can be
## talked to (TALKABLE_GROUP, PlayerController), with what a conversation needs of it
## (Conversations: `figure`, `mobility`, voice()).
##   var person := InteriorPerson.create("klant", 17, true)

## Everyone the player can talk to (pedestrians too): PlayerController looks in it.
## Seat height (metres: the top of the chair, binnen/snackbar/stoel) and how far forward the
## feet stand from the hips (sitting).
const SEAT_HEIGHT := 0.625
const KNEE_REACH := 0.45

## How far off you can talk to someone (metres, PlayerController: as its talk_reach), and to
## who sells (MERCHANT_ROLES, Conversations: the shop screen) across their counter.
const TALK_REACH := 2.2
const COUNTER_REACH := 3.4
const MERCHANT_ROLES := ["snackbarhouder", "verkoper"]
## The arrow over who sells (InteractionMark, as over a way in): its point between these
## heights over the floor (metres), over the head.
const MARK_BOTTOM := 2.3
const MARK_TOP := 2.9
## Who sells is talked to only from before them: the player within this cos of their facing.
const FRONT_SIDE := 0.2
## The group of the player (PlayerController.PLAYER_GROUP).
const PLAYER_GROUP := "speler"
const InteractionMark = preload("res://scripts/world/things/interaction_mark.gd")

var seat_height := SEAT_HEIGHT
var _mark: InteractionMark
var _body: AnimatableBody3D
## The physics layer of the town (PlayerController.TOWN_LAYER).
const TOWN_LAYER := 1


## Someone of `person_role` with the look of `look_seed`; `sit`: on a chair at its origin
## (facing +z), else standing.
## `outfit`: what a seller wears for their shop (winkels.json "kleding": "jas", "rand",
## "broek", "pet" as colours), over the look and the role's own clothes.
static func create(person_role: String, look_seed: int, sit: bool, on_seat_at := SEAT_HEIGHT,
		outfit := {}) -> InteriorPerson:
	var person := InteriorPerson.new()
	person.seat_height = on_seat_at
	person.name = "Snackbarhouder" if person_role == "snackbarhouder" else "Klant"
	person.role = person_role
	person.sitting = sit
	var look := TownsfolkFigure.look_for(look_seed)
	if person_role == "snackbarhouder":
		# the white coat of the snack bar and a white cap
		look["coat"] = Color("#E8E6E0")
		look["trim"] = Color("#C8C4BA")
		look["hair_style"] = "pet"
		look["cap"] = Color("#E8E6E0")
		look["skirt"] = false
	_dress_for_work(look, outfit)
	person.figure = TownsfolkFigure.create(look)
	person.figure.name = "Figuur"
	person.add_child(person.figure)
	person.add_to_group(TALKABLE_GROUP)
	if sit:
		person._sit()
	if person_role in MERCHANT_ROLES:
		# who sells can be used like a way in: the same arrow over them
		person._mark = InteractionMark.create(MARK_BOTTOM, MARK_TOP, false)
		person.add_child(person._mark)
	person.set_process(person._mark != null)
	person.fit_collider()
	return person


## The collider (Botsvorm, on the town's layer, so the player bumps into them as into the
## pedestrians outside): a box round the figure, and one round each thing it has with it
## (a trolley, a basket: the meshes hung on the person itself). Again after adding one.
func fit_collider() -> void:
	if _body == null:
		_body = AnimatableBody3D.new()
		_body.name = "Botsvorm"
		_body.sync_to_physics = false
		_body.collision_layer = TOWN_LAYER
		_body.collision_mask = 0
		add_child(_body)
	for old_shape in _body.get_children():
		old_shape.free()
	var parts: Array[AABB] = []
	if figure:
		var figure_bounds := Vehicle._mesh_bounds(figure, figure.transform)
		# the figure stands round its own axis: as wide as its widest side, no thinner than a person
		figure_bounds = figure_bounds.grow(0.02)
		parts.append(figure_bounds)
	for child in get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh:
			parts.append(child.transform * (child as MeshInstance3D).mesh.get_aabb())
	for part_index in parts.size():
		var part: AABB = parts[part_index]
		var shape := CollisionShape3D.new()
		shape.name = "Doos%d" % part_index
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(part.size.x, 0.1), maxf(part.size.y, 0.1), maxf(part.size.z, 0.1))
		shape.shape = box
		shape.position = part.get_center()
		_body.add_child(shape)


func _process(_delta: float) -> void:
	if _mark:
		var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
		_mark.follow(player, player != null and can_talk_from(player.global_position))


## The arrow `forward` metres before them (the side they face) between `low` and `high`, in
## place of over their head: in front of a shop where its roof would cover it (Den Haag Centraal).
func place_mark_ahead(forward: float, low: float, high: float) -> void:
	if _mark == null:
		return
	_mark.position = Vector3(0.0, 0.0, forward)
	_mark.bottom = low
	_mark.top = high


## Whether the player at `at` can talk to them: anyone from all sides, who sells only from
## before the counter (the side they face: their back is a wall, PlayerController asks this).
func can_talk_from(at: Vector3) -> bool:
	if not role in MERCHANT_ROLES:
		return true
	var towards := at - global_position
	towards.y = 0.0
	return towards.length_squared() < 0.0001 or towards.normalized().dot(global_basis.z) > FRONT_SIDE


## The clothes of a shop (`outfit`, see create) over `look`: the coat with its trim (collar,
## apron, cuffs), the trousers, a cap or bonnet; no skirt behind the counter.
static func _dress_for_work(look: Dictionary, outfit: Dictionary) -> void:
	if outfit.is_empty():
		return
	var keys := {"jas": "coat", "rand": "trim", "broek": "trousers"}
	for key: String in keys:
		if outfit.has(key):
			look[keys[key]] = Color(str(outfit[key]))
	if outfit.has("pet"):
		look["hair_style"] = "pet"
		look["cap"] = Color(str(outfit.pet))
	elif look.get("hair_style", "") in ["pet", "hoed"]:
		look["hair_style"] = "kort"
	look["skirt"] = false


## Sitting on the chair: the hips on the seat, the feet on the floor before it, the hands on
## the table.
func _sit() -> void:
	figure.position = Vector3(0.0, seat_height, 0.0) - figure.hip_middle()
	for side: String in ["left", "right"]:
		var rest := figure.rest_joint("thigh_" + side)
		var foot := Vector3(rest.x, 0.0, KNEE_REACH) - figure.position
		figure.aim_leg(side, foot)
		var shoulder := figure.rest_joint("arm_" + side)
		figure.aim_arm(side, Vector3(shoulder.x * 0.8, seat_height + 0.15, 0.4) - figure.position)


## How far off the player can talk to them: across the counter for who sells.
func reach() -> float:
	return COUNTER_REACH if role in MERCHANT_ROLES else TALK_REACH


## The action shown near them ("[E] ...", PlayerController): who sells opens the shop screen,
## so not "Praten": "Bestellen" at a snack bar's counter, "Winkelen" at a shop of the station.
func action_text() -> String:
	match role:
		"snackbarhouder":
			return "Bestellen"
		"verkoper":
			return "Winkelen"
	return "Praten"


func actor_kind() -> String:
	return ACTOR_INTERIOR


## Whether they sell (MERCHANT_ROLES): talking to them opens the shop screen.
func is_merchant() -> bool:
	return role in MERCHANT_ROLES
