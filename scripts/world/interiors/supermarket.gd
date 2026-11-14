extends "res://scripts/world/interiors/interior.gd"
## A supermarket, DERREK or ALFRED STEYHN (scenes/binnen/supermarkt.tscn: one scene for both
## chains; Interiors makes one for each, KINDS "derrek" and "alfred_steyhn"). Every branch is
## laid out anew as you walk in (dress_way_in): its size, entrance, aisles and checkouts from
## SupermarketLayout (scripts/world/interiors/supermarket_layout.gd), built here into the GridMaps
## Vloer, Inrichting (the library binnen) and Props, in the node "Indeling" (plan_root: the
## minimap's floor plan), in the house style of the chain (its tiles, the signs over the
## aisles in its colour, its staff in its colours: data/gesprekken/supermarkten.json).
##
## Shopping (not a shop screen as at a snack bar):
## - by the entrance [E] "Karretje pakken" or "Mandje pakken" (the trolley pushed before you,
##   the basket on your arm; once more: put it back);
## - at a shelf [E] "Pakken: <product> € <price>": one of what that shelf sells goes in
##   (per kind of shelf one product; ALFRED STEYHN has BONUS on a few kinds per branch, a
##   quarter off); without a trolley or basket, or with a full one, nothing (it says so);
## - at a checkout [E] "Afrekenen": the one at the till (or the self-scan pillar) beeps it
##   through and says what it comes to; pay (PlayerController.buy, so a mission "kopen"
##   counts) or let it be. Too little money: the dearest things go back until it fits;
##   nothing at all: "geen_geld" (uitzetten.json). What does not fit in your pockets goes back;
## - out of the door with unpaid goods: the security gates go off and stay shut, a cashier
##   gets up and comes for you, and you are thrown out (leave_offence: "winkeldiefstal").
## Shoppers walk in through the door, go along a few shelves (stopping, reaching in, their
## basket or trolley filling up), queue at a checkout, pay and walk out again; some only look
## and leave; new ones come in now and then (SHOPPER_EVERY), as many as the branch is big.
## They walk on a grid of the free floor (AStarGrid2D, cells of NAV_CELL m) round the
## shelves, and wait for the player when they stand in the way.

const Layout = preload("res://scripts/world/interiors/supermarket_layout.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
const Interiors = preload("res://scripts/world/interiors/interiors.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const InteriorSpot = preload("res://scripts/world/interiors/interior_spot.gd")
const SignBoard = preload("res://scripts/world/things/sign_board.gd")
## The name and the emblem of the chain on the back wall: just before it, not half in it.
const WallMount = preload("res://scripts/world/interiors/wall_mount.gd")
## The loudspeakers: the chain's jingle and an offer or a notice now and then (omroep_supermarkt.json).
const Announcer = preload("res://scripts/world/interiors/supermarket_announcer.gd")
## The deposit machine by the entrance (statiegeld): its model and its close-up screen.
const MachineModels = preload("res://scripts/world/things/machine_models.gd")
const DepositMachineScreen = preload("res://scripts/ui/machines/deposit_machine_screen.gd")
const DATA_FILE := "res://data/gesprekken/supermarkten.json"
const LIBRARY := "res://assets/libraries/binnen.res"
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const PREFIX := "supermarkt/"
const SOUND_FOLDER := "res://assets/audio/geluiden/"
const BEEP_SOUND := "kassa_piep"
const ALARM_SOUND := "winkel_alarm"
## The colour of the packs in a trolley or basket, per kind of shelf.
const GOODS_COLOURS := {
	"droog": Color("#E2AA28"), "ontbijt": Color("#E07A20"), "snoep": Color("#E05A9A"), "drank": Color("#3A8A4A"),
	"verzorging": Color("#4A8AD0"), "conserven": Color("#A8302A"), "zuivel": Color("#F0F0EC"), "diepvries": Color("#3A6AD0"),
	"brood": Color("#C08A4A"), "bakkerij": Color("#D8A050"), "groente": Color("#F0D040"), "bloemen": Color("#E03040"),
	"actie": Color("#C88A3A"),
}
## The orange plate of ALFRED STEYHN's bonus.
const BONUS_PLATE := Color("#F28C28")
## How the player pushes a trolley (its handle this far before the feet) and carries a
## basket (in the right hand: beside the body, at hip height); the arms for each.
const CART_AHEAD := 0.75
const BASKET_AT := Vector3(-0.3, 0.42, 0.08)
const CART_ARMS := Vector3(-62.0, 0.0, 0.0)
const BASKET_ARM := Vector3(0.0, 0.0, 10.0)
## The shoppers: the floor grid they walk on, how fast, how long at a shelf, at the till.
const NAV_CELL := 0.5
## How far round a blocked cell a free one is looked for (FloorGrid.free_cell), in cells.
const FREE_CELL_REACH := 5
const WALK_SPEED := Vector2(1.0, 1.35)
const LOOK_SECONDS := Vector2(1.5, 4.0)
const PAY_SECONDS := Vector2(4.0, 7.0)
const QUEUE_GAP := 0.9
const SHOPPER_EVERY := Vector2(6.0, 15.0)
const ONLY_LOOKING := 0.25
const WITH_CART := 0.35
const PLAYER_GAP := 0.75
const PLAYER_PATIENCE := 2.0
## In the way in from the door (the plan's "entrance_lane") they wait for the player only this
## long: they do not stand about in the entrance, with or without a trolley.
const PLAYER_PATIENCE_IN_ENTRANCE := 0.5
## Metres into the shop from the door where a player warned for not paying is put back.
const WAY_BACK_IN := 3.0
const TURN_SPEED := 8.0

var brand := "derrek"
var plan := {}
var _layout: Node3D
## The doors of the branch this is now (dress_way_in: Interiors, world), INF for the base.
var _door := Vector3.INF
var _data := {}
var _bonus: Array[String] = []
var _random := RandomNumberGenerator.new()
var _player: Node3D
var _carrier := ""                      # "", "karretje" or "mandje"
var _goods: Array[Dictionary] = []      # in the trolley or basket: {"item", "price", "name", "category"}
var _carried: Node3D                    # the trolley or basket with the player
var _cashiers := {}                     # checkout number -> InteriorPerson
var _shoppers: Array[Dictionary] = []   # see _new_shopper
var _queues := {}                       # checkout number -> Array of shoppers (Dictionaries)
var _grid: AStarGrid2D
var _spawn_clock := 0.0
var _next_look := {}                    # the look of the next shopper, built on a thread first
var _next_seed := 0
## What the shoppers of this branch did since it was laid out: came in, paid at a checkout,
## went out (the checks).
var stats := {"binnen": 0, "betaald": 0, "weg": 0}
var _announcer: Node


func _ready() -> void:
	brand = String(get_meta("kind", brand))
	_data = _read_data()
	_build(Layout.plan(brand, 0, 6), 0)
	_announcer = Announcer.new(self)
	add_child(_announcer)


## What the chain says, sells and wears (data/gesprekken/supermarkten.json).
func chain() -> Dictionary:
	return ((_data.get("ketens", {}) as Dictionary).get(brand, {}) as Dictionary)


static func _read_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
	return parsed if parsed is Dictionary else {}


# ------------------------------------------------------------------ Interiors

func doors() -> Array[Transform3D]:
	var door_place: Transform3D = plan.get("door", Transform3D())
	var found: Array[Transform3D] = [global_transform * door_place]
	return found


func plan_root() -> Node3D:
	return _layout


## Laid out for the branch of `way_in` (Interiors: its "kind", "seed", "width" and "name").
func dress_way_in(way_in: Dictionary) -> void:
	_door = way_in.get("door", Vector3.INF)
	brand = String(way_in.get("kind", brand))
	snack_bar_name = String(way_in.get("name", chain().get("naam", brand)))
	var seed := int(way_in.get("seed", 0))
	_build(Layout.plan(brand, seed, int(way_in.get("width", 6))), seed)


## As the base: the branch of this chain with `seed`, a front of 6 cells.
func dress(bar_name: String, seed: int) -> void:
	dress_way_in({"kind": brand, "name": bar_name, "seed": seed, "width": 6})


func player_came_in(player: Node3D) -> void:
	_player = player
	_announcer.start()


func player_went_out() -> void:
	_drop_carrier()
	_announcer.stop()


## Putting the player out (Eviction: the cashier gets up from the till) goes over the floor
## grid of the branch, as the shoppers do.
func floor_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	for point in _path(to_local(from), to_local(to)):
		points.append(to_global(point))
	return points


func evictor_outfit(_role: String) -> Dictionary:
	return chain().get("kleding", {})


## Warned at the gates for not paying (Interiors.leave): where the player is put back, a few
## metres into the shop from the door, facing in (WAY_BACK_IN).
func way_back_in() -> Transform3D:
	var door: Transform3D = doors()[0]
	var spot := door.origin + door.basis.z * WAY_BACK_IN
	if _grid:
		# on free floor (not in a trolley row or the deposit machine)
		var cell := free_cell(_grid, cell_of(plan, to_local(spot)))
		spot = to_global(cell_middle(plan, cell))
	return Transform3D(door.basis, spot)


## No one at a till (all self-scan): who puts the player out comes from the door.
func evictor_entry() -> Node3D:
	if _layout == null:
		return null
	var entry := _layout.get_node_or_null("Uitzetterdeur") as Marker3D
	if entry == null:
		entry = Marker3D.new()
		entry.name = "Uitzetterdeur"
		_layout.add_child(entry)
	entry.transform = plan.get("door", Transform3D())
	return entry


## Out of the door with goods not paid for: the gates go off ("winkeldiefstal").
func leave_offence() -> String:
	if _goods.is_empty():
		return ""
	_play_at(plan.get("door_gap", Vector3.ZERO), ALARM_SOUND)
	return "winkeldiefstal"


# ------------------------------------------------------------------ building the branch

func _build(new_plan: Dictionary, seed: int) -> void:
	plan = new_plan
	_random.seed = hash([brand, seed, "mensen"])
	_drop_carrier()
	for person in _people:
		if is_instance_valid(person):
			person.queue_free()
	_people.clear()
	_shoppers.clear()
	_queues.clear()
	stats = {"binnen": 0, "betaald": 0, "weg": 0}
	_cashiers.clear()
	if _layout:
		# out of the way at once (its name free for the new layout), freed at the end of the frame
		_layout.name = "OudeIndeling"
		remove_child(_layout)
		_layout.queue_free()
	_layout = Node3D.new()
	_layout.name = "Indeling"
	add_child(_layout)
	var library: MeshLibrary = load(LIBRARY)
	var props_library: MeshLibrary = load(PROPS_LIBRARY)
	var floor_map := _grid_map("Vloer", library, Vector3(0.0, -0.125, 0.0))
	var furniture := _grid_map("Inrichting", library, Vector3.ZERO)
	var props := _grid_map("Props", props_library, Vector3.ZERO)
	for entry: Array in plan.floor:
		_put(floor_map, PREFIX + String(entry[0]), entry[1], 0.0)
	for entry: Array in plan.tiles:
		_put(furniture, PREFIX + String(entry[0]), entry[1], float(entry[2]))
	for entry: Array in plan.get("wall_tiles", []):
		if not WallMount.put(_layout, library, PREFIX + String(entry[0]), entry[1], float(entry[2])):
			push_warning("supermarkt: geen tile %s" % String(entry[0]))
	for entry: Array in plan.props:
		_put(props, String(entry[0]), entry[1], float(entry[2]))
	_choose_bonus(seed)
	_make_signs()
	_make_lamps()
	_make_spots()
	_make_deposit_machine()
	_make_staff(seed)
	_make_floor_grid(library, props_library)
	_spawn_clock = _random.randf_range(SHOPPER_EVERY.x, SHOPPER_EVERY.y) * 0.5
	# a few shoppers in the shop already, mid-way through their round
	var already := mini(int(plan.people.size()), 2 + int(plan.width / 8.0))
	for index in already:
		var spot: Transform3D = plan.people[index]
		_new_shopper(seed * 31 + index * 7 + 3, spot.origin, true)
	_next_seed = seed * 31 + 101
	_prepare_next_look()


func _grid_map(map_name: String, library: MeshLibrary, at: Vector3) -> GridMap:
	var grid := GridMap.new()
	grid.name = map_name
	grid.mesh_library = library
	grid.cell_size = Vector3(0.5, 0.5, 0.5)
	grid.cell_center_x = false
	grid.cell_center_y = false
	grid.cell_center_z = false
	grid.position = at
	_layout.add_child(grid)
	return grid


func _put(grid: GridMap, item_name: String, at: Vector3, turn: float) -> void:
	var item := grid.mesh_library.find_item_by_name(item_name)
	if item < 0:
		push_warning("supermarkt: geen tile %s" % item_name)
		return
	var cell := Vector3i(roundi(at.x * 2.0), roundi(at.y * 2.0), roundi(at.z * 2.0))
	grid.set_cell_item(cell, item, grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))


## ALFRED STEYHN: in this branch a few kinds of shelf have a bonus (a quarter off).
func _choose_bonus(seed: int) -> void:
	_bonus.clear()
	var bonus: Dictionary = chain().get("bonus", {})
	if bonus.is_empty():
		return
	var kinds: Array = []
	for shelf: Dictionary in plan.shelves:
		var category := String(shelf.category)
		if not kinds.has(category) and (chain().get("producten", {}) as Dictionary).has(category):
			kinds.append(category)
	var random := RandomNumberGenerator.new()
	random.seed = hash([brand, seed, "bonus"])
	for index in range(kinds.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var kept: Variant = kinds[index]
		kinds[index] = kinds[other]
		kinds[other] = kept
	for index in mini(int(bonus.get("aantal", 2)), kinds.size()):
		_bonus.append(String(kinds[index]))


func _house_colour() -> Color:
	return Color(String(chain().get("kleur", "#DE1828")))


func _ink() -> Color:
	return Color(String(chain().get("tekstkleur", "#FFFFFF")))


## The signs over the aisles, the bonus plates, the price boards of the pallets and the
## lane numbers over the checkouts.
func _make_signs() -> void:
	var bonus_texts := {}
	for category in _bonus:
		bonus_texts[String(Layout.SIGN_TEXTS.get(category, ""))] = true
	for sign: Dictionary in plan.signs:
		var board: Node3D = SignBoard.create(String(sign.text), _house_colour(), _ink())
		board.position = sign.at
		board.rotation.y = float(sign.turn)
		_layout.add_child(board)
		if bonus_texts.has(String(sign.text)):
			var bonus: Node3D = SignBoard.create(String((chain().get("bonus", {}) as Dictionary).get("tekst", "BONUS")), BONUS_PLATE, Color.WHITE, 0.15)
			bonus.position = Vector3(0.0, -0.42, 0.0)
			board.add_child(bonus)
	var promotion: Dictionary = (chain().get("producten", {}) as Dictionary).get("actie", {})
	for board_place: Dictionary in plan.promotions:
		var price: Node3D = SignBoard.create(_euros(float(promotion.get("prijs", 0.99))), _house_colour(), _ink(), 0.16, false)
		price.position = board_place.at
		price.rotation.y = float(board_place.turn)
		_layout.add_child(price)
	for checkout: Dictionary in plan.checkouts:
		if checkout.self_scan:
			continue
		var number: Node3D = SignBoard.create(str(checkout.number), _house_colour(), _ink(), 0.16, false)
		number.position = checkout.sign_at
		number.rotation.y = PI
		_layout.add_child(number)


func _make_lamps() -> void:
	for index in plan.lamps.size():
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%d" % (index + 1)
		lamp.position = plan.lamps[index]
		lamp.light_color = Color("#F4F6FF")
		lamp.light_energy = 1.1
		lamp.omni_range = 9.0
		_layout.add_child(lamp)


## The spots of [E]: the trolleys, the baskets, every shelf with something to take, every
## checkout.
func _make_spots() -> void:
	_layout.add_child(_spot("Karretjes", plan.cart_at, _carrier_text.bind("karretje"), _carrier_use.bind("karretje")))
	_layout.add_child(_spot("Mandjes", plan.basket_at, _carrier_text.bind("mandje"), _carrier_use.bind("mandje")))
	var products: Dictionary = chain().get("producten", {})
	for index in plan.shelves.size():
		var shelf: Dictionary = plan.shelves[index]
		if not products.has(String(shelf.category)):
			continue
		_layout.add_child(_spot("Schap%d" % (index + 1), shelf.at, _shelf_text.bind(String(shelf.category)),
			_take.bind(String(shelf.category), shelf.at)))
	for checkout: Dictionary in plan.checkouts:
		_layout.add_child(_spot("Kassa%d" % int(checkout.number), checkout.pay_at, func() -> String: return "Afrekenen",
			_pay.bind(checkout)))


func _spot(spot_name: String, at: Vector3, text_of: Callable, use: Callable) -> Node3D:
	var spot: Node3D = InteriorSpot.create(spot_name, at, "", use)
	spot.set("text_of", text_of)
	return spot


## The ones at the tills (sitting, in the chain's colours; you talk to them through the
## checkout), and staff filling the shelves (they can be talked to: personeel.json).
func _make_staff(seed: int) -> void:
	var outfit: Dictionary = chain().get("kleding", {})
	for checkout: Dictionary in plan.checkouts:
		if checkout.self_scan:
			continue
		var cashier := InteriorPerson.create("kassamedewerker", seed * 5 + int(checkout.number) * 11, true,
			float(checkout.seat), outfit)
		cashier.name = "Kassa%d" % int(checkout.number)
		cashier.remove_from_group(InteriorPerson.TALKABLE_GROUP)
		_layout.add_child(cashier)
		cashier.transform = checkout.cashier
		_people.append(cashier)
		_cashiers[int(checkout.number)] = cashier
	for index in plan.staff.size():
		var worker := InteriorPerson.create("medewerker_" + brand, seed * 13 + index * 17 + 2, false, InteriorPerson.SEAT_HEIGHT, outfit)
		worker.name = "Medewerker%d" % (index + 1)
		worker.role = "medewerker_" + brand
		_layout.add_child(worker)
		worker.transform = plan.staff[index]
		_people.append(worker)


# ------------------------------------------------------------------ the player shopping

func _carrier_text(kind: String) -> String:
	if _carrier == kind:
		return "Karretje terugzetten" if kind == "karretje" else "Mandje terugzetten"
	return "Karretje pakken" if kind == "karretje" else "Mandje pakken"


func _carrier_use(kind: String) -> void:
	if _carrier == kind:
		if not _goods.is_empty():
			_say_over_player("Alles terug in het schap")
		_drop_carrier()
		return
	_drop_carrier()
	_take_carrier(kind)


## The trolley before the player or the basket in their hand, the arms to go with it.
func _take_carrier(kind: String) -> void:
	if _player == null:
		return
	_carrier = kind
	_carried = Node3D.new()
	_carried.name = "Winkelkarretje" if kind == "karretje" else "Winkelmandje"
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Model"
	if kind == "karretje":
		var props_library: MeshLibrary = load(PROPS_LIBRARY)
		var item := props_library.find_item_by_name("winkel/winkelwagen_" + String(Layout.CART_COLOURS[brand]))
		if item >= 0:
			mesh_node.mesh = props_library.get_item_mesh(item)
			mesh_node.transform = props_library.get_item_mesh_transform(item)
		_carried.position = Vector3(0.0, 0.0, CART_AHEAD)
	else:
		var library: MeshLibrary = load(LIBRARY)
		var item := library.find_item_by_name(PREFIX + "mandje_" + brand)
		if item >= 0:
			mesh_node.mesh = library.get_item_mesh(item)
			mesh_node.transform = library.get_item_mesh_transform(item)
		_carried.position = BASKET_AT
	_carried.add_child(mesh_node)
	_player.add_child(_carried)
	# the trolley bumps into the shelves and the people as the player does
	if kind == "karretje" and mesh_node.mesh and _player.has_method("set_pushed_box"):
		_player.set_pushed_box(_carried.transform * mesh_node.transform * mesh_node.mesh.get_aabb())
	_pose_player_arms()
	UiSounds.play(self, "kies", -6.0)


func _drop_carrier() -> void:
	_goods.clear()
	_carrier = ""
	if _carried and is_instance_valid(_carried):
		_carried.queue_free()
	_carried = null
	if _player and is_instance_valid(_player) and _player.has_method("set_pushed_box"):
		_player.set_pushed_box(AABB())
	_pose_player_arms()


func _pose_player_arms() -> void:
	var model: Node = _player.get("_model") if _player and is_instance_valid(_player) else null
	if model == null or not model.has_method("pose_limb"):
		return
	model.pose_limb("arm_left", CART_ARMS if _carrier == "karretje" else Vector3.ZERO)
	model.pose_limb("arm_right", CART_ARMS if _carrier == "karretje" else (BASKET_ARM if _carrier == "mandje" else Vector3.ZERO))


## How many things go in what the player has (supermarkten.json "karretje", "mandje").
func capacity() -> int:
	if _carrier == "":
		return 0
	return int(chain().get(_carrier, 12 if _carrier == "karretje" else 6))


func goods() -> Array[Dictionary]:
	return _goods


func carrier() -> String:
	return _carrier


## The product of a kind of shelf in this chain, with this branch's price (the bonus off).
func product(category: String) -> Dictionary:
	var entry: Dictionary = (chain().get("producten", {}) as Dictionary).get(category, {})
	if entry.is_empty():
		return {}
	var price := float(entry.get("prijs", 1.0))
	if _bonus.has(category):
		var off := float((chain().get("bonus", {}) as Dictionary).get("korting", 0.25))
		price = snappedf(price * (1.0 - off), 0.01)
	return {"item": String(entry.get("item", "")), "price": price, "name": String(entry.get("naam", "")),
		"category": category, "bonus": _bonus.has(category)}


func _shelf_text(category: String) -> String:
	var found := product(category)
	return "Pakken: %s %s%s" % [found.name, "BONUS " if found.bonus else "", _euros(found.price)]


## One of this shelf's product in the trolley or basket (if there is one, and room in it).
func _take(category: String, at: Vector3) -> void:
	var found := product(category)
	if found.is_empty():
		return
	if _carrier == "":
		_say_over_player("Pak eerst een karretje of mandje")
		return
	if _goods.size() >= capacity():
		_say_over_player("Je karretje is vol" if _carrier == "karretje" else "Je mandje is vol")
		return
	_goods.append(found)
	_show_goods()
	var hud := _hud()
	if hud and hud.has_method("show_floating_number"):
		hud.show_floating_number(global_transform * at + Vector3.UP * 1.9, "+ " + String(found.name), Color("#FFE9B8"), 13)
	UiSounds.play(self, "kies", -8.0)


## The packs in the trolley or basket: a little block each, in the colour of its shelf.
func _show_goods() -> void:
	if _carried == null:
		return
	var holder := _carried.get_node_or_null("Spullen")
	if holder:
		holder.free()
	holder = Node3D.new()
	holder.name = "Spullen"
	_carried.add_child(holder)
	var in_cart := _carrier == "karretje"
	var per_row := 3 if in_cart else 2
	for index in _goods.size():
		var pack := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * (0.16 if in_cart else 0.1)
		var material := StandardMaterial3D.new()
		material.albedo_color = GOODS_COLOURS.get(String(_goods[index].category), Color("#C8C4BA"))
		box.material = material
		pack.mesh = box
		var column := index % per_row
		var row := (index / per_row) % (4 if in_cart else 3)
		var layer := index / (per_row * (4 if in_cart else 3))
		if in_cart:
			pack.position = Vector3(-0.2 + column * 0.2, 0.5 + layer * 0.17, -0.2 + row * 0.18)
		else:
			pack.position = Vector3(-0.08 + column * 0.13, 0.14 + layer * 0.1, -0.06 + row * 0.08)
		holder.add_child(pack)


# ------------------------------------------------------------------ paying

## At a checkout: what it comes to, pay or let it be (see the top).
func _pay(checkout: Dictionary) -> void:
	var hud := _hud()
	if hud == null or not hud.has_method("show_story") or _player == null:
		return
	var self_scan := bool(checkout.self_scan)
	var lines: Dictionary = chain().get("zelfscan" if self_scan else "kassa", {})
	var cashier: InteriorPerson = _cashiers.get(int(checkout.number))
	if _goods.is_empty():
		hud.show_story([_line(lines, String(lines.get("leeg", "...")), "leeg", cashier, self_scan)])
		return
	var total := _total(_goods)
	var greetings: Array = lines.get("begroetingen", [])
	var text := String(lines.get("totaal", "{prijs}")).replace("{prijs}", _euros(total)).replace("{aantal}", str(_goods.size()))
	if not greetings.is_empty():
		text = String(greetings[_random.randi() % greetings.size()]) + " " + text
	var page := _line(lines, text, "totaal", cashier, self_scan)
	page["choices"] = ["Betalen", "Laat maar, ik leg het terug"]
	page["on_choice"] = func(choice: int) -> Array:
		if choice == 1:
			_drop_goods()
			return [_line(lines, String(lines.get("laat_maar", "Goed.")), "laat_maar", cashier, self_scan)]
		return settle(lines, cashier, self_scan)
	var beeps := mini(_goods.size(), 8)
	page["on_show"] = func() -> void:
		_beep_through(checkout.pay_at, beeps)
	hud.show_story([page])


## Pays for what is in the trolley or basket: the dearest things go back until it is no more
## than the player has, then each thing is bought (into the pockets; what has no room goes
## back, not paid). The pages of what the one at the till says.
func settle(lines: Dictionary, cashier: InteriorPerson = null, self_scan := false) -> Array:
	var pages: Array = []
	var basket: Array[Dictionary] = _goods.duplicate()
	basket.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first.price) > float(second.price))
	var put_back: Array[String] = []
	while not basket.is_empty() and _total(basket) > float(_player.money) + 0.001:
		put_back.append(String(basket.pop_front().name))
	if basket.is_empty():
		_drop_goods()
		Interiors.note_offence(get_tree(), "geen_geld")
		return [_line(lines, String(lines.get("niets", "Dat is niet genoeg.")), "niets", cashier, self_scan)]
	if not put_back.is_empty():
		pages.append(_line(lines, String(lines.get("terugleggen", "{wat}")).replace("{wat}", ", ".join(put_back)), "terugleggen", cashier, self_scan))
	var no_room: Array[String] = []
	for thing in basket:
		match String(_player.call("buy", String(thing.item), float(thing.price))):
			"vol":
				no_room.append(String(thing.name))
	_drop_goods()
	if not no_room.is_empty():
		pages.append(_line(lines, String(lines.get("zakken_vol", "{wat}")).replace("{wat}", ", ".join(no_room)), "terugleggen", cashier, self_scan))
	var thanks: Variant = lines.get("betaald", "Dank je wel!")
	var thanks_text := String(thanks[_random.randi() % thanks.size()]) if thanks is Array else String(thanks)
	pages.append(_line(lines, thanks_text, "betaald", cashier, self_scan))
	return pages


func _drop_goods() -> void:
	_goods.clear()
	_show_goods()


static func _total(things: Array) -> float:
	var sum := 0.0
	for thing: Dictionary in things:
		sum += float(thing.price)
	return snappedf(sum, 0.01)


## A page of what the till says: a conversation with the cashier (their portrait, their
## voice, the name plate in the chain's colours), or the self-scan pillar (the narrator's way).
func _line(lines: Dictionary, text: String, line_kind: String, cashier: InteriorPerson, self_scan: bool) -> Dictionary:
	var page := {"kind": "verhaal" if self_scan or cashier == null else "gesprek", "text": text,
		"speaker": String(lines.get("spreker", "KASSA"))}
	if cashier and not self_scan:
		page["voice"] = cashier.voice()
		page["mood"] = String((lines.get("stemmingen", {}) as Dictionary).get(line_kind, "neutraal"))
		page["portrait_look"] = cashier.figure.look
		page["portrait_figure"] = cashier.figure
		page["official"] = {"emblem": "D" if brand == "derrek" else "AS", "colour": _house_colour(),
			"plate": _house_colour(), "plate_text": _ink(), "pitch": 1.05}
	return page


func _beep_through(at: Vector3, count: int) -> void:
	for beep in count:
		_play_at(at, BEEP_SOUND)
		await get_tree().create_timer(0.32, true, false, true).timeout


# ------------------------------------------------------------------ the shoppers

## Someone shopping, from `look_seed`: coming in at the door (or, `already`, standing at
## `at` mid-way through their round). {"person", "steps" (see _plan_round), "path",
## "speed", "phase", "walking", "clock", "waited", "cart"}.
func _new_shopper(look_seed: int, at: Vector3, already := false) -> void:
	var person := InteriorPerson.create("klant", look_seed, false)
	person.name = "Klant"
	_layout.add_child(person)
	_people.append(person)
	var shopper := {"person": person, "steps": [], "path": PackedVector3Array(), "speed": _random.randf_range(WALK_SPEED.x, WALK_SPEED.y),
		"phase": 0.0, "walking": 0.0, "clock": 0.0, "waited": 0.0, "queue": -1, "goods": 0}
	var with_cart := _random.randf() < WITH_CART
	shopper["cart"] = _shopper_carrier(person, with_cart)
	if already:
		person.position = at
	else:
		var door_place: Transform3D = plan.door
		person.position = Vector3(door_place.origin.x, 0.0, float(plan.depth) * -0.5 + 0.2)
		person.rotation.y = 0.0
	shopper["steps"] = _plan_round(already)
	_shoppers.append(shopper)


## A basket on the arm or a trolley before them, in the chain's colour.
func _shopper_carrier(person: InteriorPerson, with_cart: bool) -> bool:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Winkelkarretje" if with_cart else "Winkelmandje"
	if with_cart:
		var props_library: MeshLibrary = load(PROPS_LIBRARY)
		var item := props_library.find_item_by_name("winkel/winkelwagen_" + String(Layout.CART_COLOURS[brand]))
		if item >= 0:
			mesh_node.mesh = props_library.get_item_mesh(item)
			mesh_node.transform = props_library.get_item_mesh_transform(item)
		mesh_node.position += Vector3(0.0, 0.0, 0.8)
	else:
		var library: MeshLibrary = load(LIBRARY)
		var item := library.find_item_by_name(PREFIX + "mandje_" + brand)
		if item >= 0:
			mesh_node.mesh = library.get_item_mesh(item)
			mesh_node.transform = library.get_item_mesh_transform(item)
		mesh_node.position += Vector3(-0.32, 0.5, 0.05)
	person.add_child(mesh_node)
	person.fit_collider()   # the trolley or basket is part of what bumps
	return with_cart


## The round of a shopper: a few shelves (walk there, look), then a checkout and out; or,
## only looking, straight out after the shelves. Steps: {"walk": Vector3}, {"look": seconds,
## "face": Vector3}, {"queue": checkout number}, {"leave": true}.
func _plan_round(already: bool) -> Array:
	var steps: Array = []
	var shelves: Array = plan.shelves
	var stops := _random.randi_range(1 if already else 2, 4)
	for index in stops:
		var shelf: Dictionary = shelves[_random.randi() % shelves.size()]
		if not (already and index == 0):
			# beside the spot of the shelf (on it the player would talk to them, not take)
			var place := Layout.beside(shelf, -1.0 if _random.randf() < 0.5 else 1.0)
			if _grid and _grid.is_point_solid(cell_of(plan, place)):
				place = shelf.at
			steps.append({"walk": place})
		steps.append({"look": _random.randf_range(LOOK_SECONDS.x, LOOK_SECONDS.y), "face": shelf.facing})
	if _random.randf() >= ONLY_LOOKING and not plan.checkouts.is_empty():
		var checkout: Dictionary = plan.checkouts[_random.randi() % plan.checkouts.size()]
		steps.append({"queue": int(checkout.number)})
	steps.append({"walk": (plan.door as Transform3D).origin})
	steps.append({"leave": true})
	return steps


func _process(delta: float) -> void:
	if plan.is_empty():
		return
	_spawn_clock -= delta
	if _spawn_clock <= 0.0:
		_spawn_clock = _random.randf_range(SHOPPER_EVERY.x, SHOPPER_EVERY.y)
		if _shoppers.size() < most_shoppers() and TownsfolkFigure.is_prepared(_next_look):
			_new_shopper(_next_seed, Vector3.ZERO)
			stats.binnen += 1
			_next_seed += 1
			_prepare_next_look()
	for shopper in _shoppers.duplicate():
		_update_shopper(shopper, delta)


## As many shoppers at once as the branch is big.
func most_shoppers() -> int:
	return 3 + int(float(plan.width) / 4.0)


func shoppers() -> Array[Dictionary]:
	return _shoppers


func _prepare_next_look() -> void:
	_next_look = TownsfolkFigure.look_for(_next_seed)
	TownsfolkFigure.prepare(_next_look)


func _update_shopper(shopper: Dictionary, delta: float) -> void:
	var person: InteriorPerson = shopper.person
	if not is_instance_valid(person):
		_shoppers.erase(shopper)
		return
	var steps: Array = shopper.steps
	if steps.is_empty():
		_remove_shopper(shopper)
		return
	var step: Dictionary = steps[0]
	var moved := 0.0
	if step.has("walk"):
		moved = _walk_along(shopper, step.walk, delta)
		if moved < 0.0:
			steps.pop_front()
			shopper.path = PackedVector3Array()
			moved = 0.0
	elif step.has("look"):
		shopper.clock = float(shopper.clock) + delta
		_turn_to(person, step.face, delta)
		# reaching into the shelf halfway, a pack into the basket or trolley
		if float(shopper.clock) >= float(step.look):
			shopper.clock = 0.0
			shopper.goods = int(shopper.goods) + 1
			steps.pop_front()
	elif step.has("queue"):
		moved = _queue_at(shopper, int(step.queue), delta)
	elif step.has("leave"):
		_remove_shopper(shopper)
		return
	_animate(shopper, moved, delta)


## Walks `shopper` towards `target` along the floor grid; returns how far it moved, or -1
## once it is there.
func _walk_along(shopper: Dictionary, target: Vector3, delta: float) -> float:
	var person: InteriorPerson = shopper.person
	var path: PackedVector3Array = shopper.path
	if path.is_empty():
		path = _path(person.position, target)
		shopper.path = path
	if path.is_empty():
		return -1.0
	var next := path[0]
	var offset := next - person.position
	offset.y = 0.0
	if offset.length() < 0.08:
		path.remove_at(0)
		shopper.path = path
		return -1.0 if path.is_empty() else 0.0
	var direction := offset.normalized()
	if _player_in_the_way(person.position, direction):
		shopper.waited = float(shopper.waited) + delta
		var patience := PLAYER_PATIENCE_IN_ENTRANCE if in_entrance_lane(person.position) else PLAYER_PATIENCE
		if float(shopper.waited) < patience:
			return 0.0
	else:
		shopper.waited = 0.0
	var step := minf(float(shopper.speed) * delta, offset.length())
	person.position += direction * step
	_turn_to(person, direction, delta)
	return step


## In the queue of checkout `number`: to the place in it, the first pays (beeps), then on.
func _queue_at(shopper: Dictionary, number: int, delta: float) -> float:
	var queue: Array = _queues.get(number, [])
	if not queue.has(shopper):
		queue.append(shopper)
		_queues[number] = queue
		shopper.path = PackedVector3Array()
	var checkout := _checkout(number)
	var place := queue.find(shopper)
	if int(shopper.get("place", -1)) != place:
		shopper["place"] = place
		shopper.path = PackedVector3Array()   # moved up: a new way to the new place
	# the queue goes back into the shop along the lane (+z)
	var spot: Vector3 = checkout.pay_at + Vector3(0.0, 0.0, QUEUE_GAP * place)
	var person: InteriorPerson = shopper.person
	var offset := spot - person.position
	offset.y = 0.0
	if offset.length() > 1.2:
		return maxf(_walk_along(shopper, spot, delta), 0.0)
	if offset.length() > 0.12:
		var direction := offset.normalized()
		var step := minf(float(shopper.speed) * delta, offset.length())
		person.position += direction * step
		_turn_to(person, direction, delta)
		return step
	_turn_to(person, Vector3(0.0, 0.0, -1.0), delta)
	if place != 0:
		return 0.0
	if float(shopper.clock) == 0.0:
		shopper.clock = 0.001
		shopper["pay_for"] = _random.randf_range(PAY_SECONDS.x, PAY_SECONDS.y)
		_beep_through(checkout.pay_at, clampi(int(shopper.goods) * 2, 2, 8))
	shopper.clock = float(shopper.clock) + delta
	if float(shopper.clock) >= float(shopper.get("pay_for", 5.0)):
		shopper.clock = 0.0
		stats.betaald += 1
		queue.erase(shopper)
		(shopper.steps as Array).pop_front()
		shopper.path = PackedVector3Array()
	return 0.0


func _checkout(number: int) -> Dictionary:
	for checkout: Dictionary in plan.checkouts:
		if int(checkout.number) == number:
			return checkout
	return plan.checkouts[0]


func _remove_shopper(shopper: Dictionary) -> void:
	if _shoppers.has(shopper):
		stats.weg += 1
	_shoppers.erase(shopper)
	for number in _queues:
		(_queues[number] as Array).erase(shopper)
	var person: InteriorPerson = shopper.person
	if is_instance_valid(person):
		_people.erase(person)
		person.queue_free()


func _animate(shopper: Dictionary, moved: float, delta: float) -> void:
	var person: InteriorPerson = shopper.person
	if person.figure == null:
		return
	if moved > 0.0:
		shopper.phase = float(shopper.phase) + moved / TownsfolkFigure.STRIDE * PI
		shopper.walking = move_toward(float(shopper.walking), 1.0, delta * 5.0)
	else:
		shopper.walking = move_toward(float(shopper.walking), 0.0, delta * 5.0)
	person.figure.walk(float(shopper.phase), float(shopper.walking))
	if bool(shopper.cart):
		# both hands on the handle of the trolley
		for side: String in ["left", "right"]:
			var shoulder := person.figure.rest_joint("arm_" + side)
			person.figure.aim_arm(side, Vector3(shoulder.x * 0.7, shoulder.y - 0.3, 0.42))


func _turn_to(person: Node3D, direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var goal := atan2(direction.x, direction.z)
	person.rotation.y = lerp_angle(person.rotation.y, goal, 1.0 - exp(-TURN_SPEED * delta))


## Whether `point` (in the shop's space) lies in the way in from the door (plan "entrance_lane").
func in_entrance_lane(point: Vector3) -> bool:
	var lane: Rect2 = plan.get("entrance_lane", Rect2())
	return lane.has_point(Vector2(point.x, point.z))


func _player_in_the_way(from: Vector3, direction: Vector3) -> bool:
	if _player == null or not is_instance_valid(_player) or not _player.is_visible_in_tree():
		return false
	var towards := to_local(_player.global_position) - from
	towards.y = 0.0
	return towards.length() < PLAYER_GAP + 0.4 and towards.normalized().dot(direction) > 0.6


# ------------------------------------------------------------------ the floor grid

## The free floor of `a_plan` as a grid of NAV_CELL m (AStarGrid2D): every tile and prop below
## head height blocks the cells under it (and a little round it).
static func make_floor_grid(a_plan: Dictionary, library: MeshLibrary, props_library: MeshLibrary) -> AStarGrid2D:
	var grid := FloorGrid.make(int(float(a_plan.width) / NAV_CELL), int(float(a_plan.depth) / NAV_CELL))
	for box in footprints(a_plan, library, props_library):
		FloorGrid.block(grid, cell_of(a_plan, box.position - Vector3(0.15, 0.0, 0.15)), cell_of(a_plan, box.end + Vector3(0.15, 0.0, 0.15)))
	return grid


## The boxes the tiles and props of `a_plan` take up (in the shop's space), all but the ones
## high on a wall (signs).
static func footprints(a_plan: Dictionary, library: MeshLibrary, props_library: MeshLibrary) -> Array[AABB]:
	var boxes: Array[AABB] = []
	var placed: Array = []
	for entry: Array in a_plan.tiles:
		placed.append([library, PREFIX + String(entry[0]), entry[1], float(entry[2])])
	for entry: Array in a_plan.props:
		placed.append([props_library, String(entry[0]), entry[1], float(entry[2])])
	for entry: Array in placed:
		var source: MeshLibrary = entry[0]
		var item := source.find_item_by_name(String(entry[1]))
		if item < 0 or source.get_item_mesh(item) == null:
			continue
		var box: AABB = Transform3D(Basis(Vector3.UP, float(entry[3])), entry[2]) * source.get_item_mesh_transform(item) * source.get_item_mesh(item).get_aabb()
		if box.position.y > 1.6:
			continue
		boxes.append(box)
	boxes.append_array(deposit_footprint(a_plan))
	return boxes


## The box of the deposit machine of `a_plan` (its "deposit"), or none.
static func deposit_footprint(a_plan: Dictionary) -> Array[AABB]:
	var found: Array[AABB] = []
	var deposit: Dictionary = a_plan.get("deposit", {})
	if not deposit.is_empty():
		var size: Vector3 = deposit.size
		var turned := Basis(Vector3.UP, float(deposit.turn)) * size
		var extent := Vector3(absf(turned.x), size.y, absf(turned.z))
		found.append(AABB((deposit.at as Vector3) - Vector3(extent.x, 0.0, extent.z) * 0.5, extent))
	return found


## The deposit machine (statiegeld) by the entrance: its model, a collider, and "[E]
## Statiegeld inleveren" before it (DepositMachineScreen).
func _make_deposit_machine() -> void:
	var deposit: Dictionary = plan.get("deposit", {})
	if deposit.is_empty():
		return
	var machine: Node3D = MachineModels.instance(MachineModels.deposit_machine_mesh(), "Statiegeldautomaat")
	machine.position = deposit.at
	machine.rotation.y = float(deposit.turn)
	_layout.add_child(machine)
	var deposit_spot := _spot("Statiegeld", deposit.use_at, func() -> String: return "Statiegeld inleveren",
		_use_deposit_machine)
	deposit_spot.set("kind", "automaat")   # Interactable.KIND_MACHINE
	_layout.add_child(deposit_spot)


func _use_deposit_machine() -> void:
	if _player == null:
		return
	# the story may have this one out of order (the first mission: Story.machine_out_of_order)
	var broken := ""
	var story := get_tree().get_first_node_in_group("verhaal")
	if story and story.has_method("machine_out_of_order") and _door != Vector3.INF:
		broken = story.machine_out_of_order(Vector2(_door.x, _door.z))
	DepositMachineScreen.show_for(_player, String(chain().get("naam", brand)).to_upper(), true, broken)


static func cell_of(a_plan: Dictionary, at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x + float(a_plan.width) * 0.5) / NAV_CELL), floori((at.z + float(a_plan.depth) * 0.5) / NAV_CELL))


static func cell_middle(a_plan: Dictionary, cell: Vector2i) -> Vector3:
	return Vector3(-float(a_plan.width) * 0.5 + (cell.x + 0.5) * NAV_CELL, 0.0, -float(a_plan.depth) * 0.5 + (cell.y + 0.5) * NAV_CELL)


## The nearest free cell of `grid` to `cell` (itself when free).
static func free_cell(grid: AStarGrid2D, cell: Vector2i) -> Vector2i:
	return FloorGrid.free_cell(grid, cell, FREE_CELL_REACH)


func _make_floor_grid(library: MeshLibrary, props_library: MeshLibrary) -> void:
	_grid = make_floor_grid(plan, library, props_library)


## The way from `from` to `to` over the free floor (in this node's space), ending at `to`.
func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	if _grid == null:
		points.append(to)
		return points
	for cell in FloorGrid.cell_path(_grid, cell_of(plan, from), cell_of(plan, to), FREE_CELL_REACH):
		points.append(cell_middle(plan, cell))
	if points.size() > 1:
		points.remove_at(0)
	points.append(to)
	return points


## True if one can walk from `from` to `to` over the free floor of `grid` (the checks).
static func reachable_on(grid: AStarGrid2D, a_plan: Dictionary, from: Vector3, to: Vector3) -> bool:
	return FloorGrid.reachable(grid, cell_of(a_plan, from), cell_of(a_plan, to), FREE_CELL_REACH)


# ------------------------------------------------------------------ helpers

func _hud() -> Node:
	var interiors := get_parent()
	var hud_path: Variant = interiors.get("hud_path") if interiors else null
	return interiors.get_node_or_null(hud_path) if hud_path is NodePath else null


func _say_over_player(text: String) -> void:
	var hud := _hud()
	if hud and hud.has_method("show_floating_number") and _player:
		hud.show_floating_number(_player.global_position + Vector3.UP * 2.0, text, Color("#FF9A5A"), 13)


func _play_at(at: Vector3, sound_name: String) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event"):
		audio.play_event(global_transform * at, sound_name)


static func _euros(amount: float) -> String:
	return "€ " + ("%.2f" % amount).replace(".", ",")
