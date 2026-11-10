extends Node3D
## An interior (scenes/binnen/*.tscn, built by tools/build/build_interiors.gd, then edited by
## hand in Godot): the GridMaps Vloer and Inrichting with the tiles of the library binnen, the
## markers Deur (in and out; Deur1, Deur2, ... for more doors: doors()), Snackbarhouder (behind
## the counter) and Plek* (the chairs), and its lamps. This is the base of every interior: one
## with more life in it extends this script (Den Haag Centraal: scripts/world/station.gd) and
## overrides dress(); Interiors calls dress(), doors(), and player_came_in(player) and
## player_went_out() when it has them. Interiors (scripts/world/interiors.gd) puts it far off the map and dresses it
## for the snack bar you walk into (dress): the colour variant of its tiles (VARIANTS: every
## tile named "<something>_<variant>" becomes the one of the snack bar's variant, when there
## is one), its name on the wall, the person behind the counter, and a few people at the
## tables, all from the snack bar's seed, so each one is the same every time you come in but
## differs a little from the next.

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const VARIANTS := ["zwartwit", "roodwit", "geel", "blauw"]
## How many of the seats are taken (fewest, most).
const GUESTS := Vector2i(1, 3)

var snack_bar_name := ""
var _name_label: Label3D
var _people: Array[InteriorPerson] = []


## Where you come in and go out (the marker Deur, or else Deur1): its place and the way
## into the room.
func door() -> Transform3D:
	var all := doors()
	return all[0] if not all.is_empty() else global_transform


## Every door (the markers Deur, Deur1, Deur2, ... in that order): an interior with more
## ways in (Den Haag Centraal) has one for each, matching the ways in on the map from west
## to east (Interiors).
func doors() -> Array[Transform3D]:
	var found: Array[Transform3D] = []
	var single := get_node_or_null("Deur") as Node3D
	if single:
		found.append(single.global_transform)
	var number := 1
	while has_node("Deur%d" % number):
		found.append((get_node("Deur%d" % number) as Node3D).global_transform)
		number += 1
	return found


## Dresses the room for a snack bar: `bar_name` on the wall, the rest from `seed`.
func dress(bar_name: String, seed: int) -> void:
	snack_bar_name = bar_name
	var random := RandomNumberGenerator.new()
	random.seed = seed
	_swap_variant(VARIANTS[random.randi() % VARIANTS.size()])
	_show_name(bar_name)
	for person in _people:
		person.queue_free()
	_people.clear()
	var keeper_marker := get_node_or_null("Snackbarhouder") as Node3D
	if keeper_marker:
		_place(InteriorPerson.create("snackbarhouder", seed * 3 + 1, false), keeper_marker)
	var seats: Array = get_children().filter(func(node: Node) -> bool: return node is Marker3D and node.name.begins_with("Plek"))
	# the seats in an order of the seed, the first few taken
	for index in range(seats.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var kept: Node = seats[index]
		seats[index] = seats[other]
		seats[other] = kept
	var guests := mini(random.randi_range(GUESTS.x, GUESTS.y), seats.size())
	for index in guests:
		_place(InteriorPerson.create("klant", seed * 7 + index * 13 + 5, true), seats[index])


func people() -> Array[InteriorPerson]:
	return _people


func _place(person: InteriorPerson, marker: Node3D) -> void:
	add_child(person)
	person.transform = marker.transform
	_people.append(person)


## Every tile of another variant becomes the one of `variant` (if the library has it).
func _swap_variant(variant: String) -> void:
	for grid_name in ["Vloer", "Inrichting"]:
		var grid := get_node_or_null(grid_name) as GridMap
		if grid == null or grid.mesh_library == null:
			continue
		var library := grid.mesh_library
		for cell in grid.get_used_cells():
			var item := grid.get_cell_item(cell)
			var item_name := library.get_item_name(item)
			for other in VARIANTS:
				if other != variant and item_name.ends_with("_" + other):
					var wanted := library.find_item_by_name(item_name.trim_suffix(other) + variant)
					if wanted >= 0:
						grid.set_cell_item(cell, wanted, grid.get_cell_item_orientation(cell))
					break


## The snack bar's name on the back wall, over the menu board, in the pixel font, lit.
func _show_name(bar_name: String) -> void:
	if _name_label == null:
		_name_label = Label3D.new()
		_name_label.name = "Naam"
		_name_label.font = UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
		_name_label.font_size = 64
		_name_label.pixel_size = 0.006
		_name_label.modulate = Color("#FFE2B0")
		_name_label.outline_size = 0
		_name_label.shaded = false
		_name_label.double_sided = false
		_name_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_name_label.position = Vector3(-1.5, 2.65, 3.6)
		_name_label.rotation.y = PI
		add_child(_name_label)
	_name_label.text = bar_name.to_upper()
