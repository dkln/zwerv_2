extends Node3D
## What a branch of a supermarket looks and sounds like (graphics, docs/CODE_LAGEN.md): the
## node "Indeling" (the minimap's floor plan) with the GridMaps Vloer, Inrichting (the
## library binnen) and Props of the plan (SupermarketLayout.plan), what hangs on its walls,
## the signs over the aisles in the chain's colour with the bonus plates, the price boards
## of the pallets, the lane numbers over the checkouts, the lamps, the deposit machine, and
## the sounds of the till and the gates. It decides nothing: the supermarket
## (supermarket.gd) hands it the plan and the texts, and puts its spots and people in it.
##   const SupermarketView = preload("res://scripts/world/interiors/supermarket_view.gd")

const SignBoard = preload("res://scripts/world/things/sign_board.gd")
## The name and the emblem of the chain on the back wall: just before it, not half in it.
const WallMount = preload("res://scripts/world/interiors/wall_mount.gd")
## The deposit machine by the entrance (statiegeld): its model.
const MachineModels = preload("res://scripts/world/things/machine_models.gd")

const NODE_NAME := "Indeling"
const OLD_NODE_NAME := "OudeIndeling"
const LIBRARY := "res://assets/libraries/binnen.res"
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const PREFIX := "supermarkt/"
const BEEP_SOUND := "kassa_piep"
const ALARM_SOUND := "winkel_alarm"
## The autoload that plays a sound at a place in the world.
const SPATIAL_AUDIO := "/root/RuimtelijkGeluid"
const DEFAULT_COLOUR := "#DE1828"
const DEFAULT_INK := "#FFFFFF"
## The orange plate of ALFRED STEYHN's bonus.
const BONUS_PLATE := Color("#F28C28")
const BONUS_INK := Color.WHITE
const LAMP_COLOUR := Color("#F4F6FF")
## What floats up over a shelf when something is taken, and over the player when it cannot.
const TAKEN_COLOUR := Color("#FFE9B8")
const WARNING_COLOUR := Color("#FF9A5A")
const FLOAT_FONT_SIZE := 13
const DEPOSIT_MACHINE_NAME := "Statiegeldautomaat"

var _library: MeshLibrary
var _props_library: MeshLibrary


func _init() -> void:
	name = NODE_NAME
	_library = load(LIBRARY)
	_props_library = load(PROPS_LIBRARY)


## The colour of the chain's house style and of the text on it (`chain`: its entry of
## supermarkten.json).
static func house_colour(chain: Dictionary) -> Color:
	return Color(String(chain.get("kleur", DEFAULT_COLOUR)))


static func ink(chain: Dictionary) -> Color:
	return Color(String(chain.get("tekstkleur", DEFAULT_INK)))


## The name plate of the one at the till in a conversation (StoryBox "official"), with
## `emblem` on it, in the chain's colours.
static func name_plate(chain: Dictionary, emblem: String) -> Dictionary:
	return {"emblem": emblem, "colour": house_colour(chain), "plate": house_colour(chain), "plate_text": ink(chain), "pitch": 1.05}


## The libraries of the tiles (binnen) and of the props.
func library() -> MeshLibrary:
	return _library


func props_library() -> MeshLibrary:
	return _props_library


## Out of the way at once (its name free for the next one), freed at the end of the frame.
func retire() -> void:
	name = OLD_NODE_NAME
	if get_parent():
		get_parent().remove_child(self)
	queue_free()


## Builds the branch of `plan`: floor, furniture, what hangs on the walls, props, lamps.
func show_plan(plan: Dictionary) -> void:
	var floor_map := _grid_map("Vloer", _library, Vector3(0.0, -0.125, 0.0))
	var furniture := _grid_map("Inrichting", _library, Vector3.ZERO)
	var props := _grid_map("Props", _props_library, Vector3.ZERO)
	for entry: Array in plan.floor:
		_put(floor_map, PREFIX + String(entry[0]), entry[1], 0.0)
	for entry: Array in plan.tiles:
		_put(furniture, PREFIX + String(entry[0]), entry[1], float(entry[2]))
	for entry: Array in plan.get("wall_tiles", []):
		if not WallMount.put(self, _library, PREFIX + String(entry[0]), entry[1], float(entry[2])):
			push_warning("supermarkt: geen tile %s" % String(entry[0]))
	for entry: Array in plan.props:
		_put(props, String(entry[0]), entry[1], float(entry[2]))


## The signs over the aisles (a bonus plate with `bonus_text` under the ones whose text is
## a key of `bonus_signs`), the price boards of the pallets (`promotion_text`) and the lane
## numbers over the checkouts with someone at the till, in the colours of `chain`.
func show_signs(plan: Dictionary, chain: Dictionary, bonus_signs: Dictionary, bonus_text: String, promotion_text: String) -> void:
	var colour := house_colour(chain)
	var text_colour := ink(chain)
	for sign: Dictionary in plan.signs:
		var board: Node3D = SignBoard.create(String(sign.text), colour, text_colour)
		board.position = sign.at
		board.rotation.y = float(sign.turn)
		add_child(board)
		if bonus_signs.has(String(sign.text)):
			var bonus: Node3D = SignBoard.create(bonus_text, BONUS_PLATE, BONUS_INK, 0.15)
			bonus.position = Vector3(0.0, -0.42, 0.0)
			board.add_child(bonus)
	for board_place: Dictionary in plan.promotions:
		var price: Node3D = SignBoard.create(promotion_text, colour, text_colour, 0.16, false)
		price.position = board_place.at
		price.rotation.y = float(board_place.turn)
		add_child(price)
	for checkout: Dictionary in plan.checkouts:
		if checkout.self_scan:
			continue
		var number: Node3D = SignBoard.create(str(checkout.number), colour, text_colour, 0.16, false)
		number.position = checkout.sign_at
		number.rotation.y = PI
		add_child(number)


## The lamps of the plan ("Lamp1", ...).
func show_lamps(plan: Dictionary) -> void:
	for index in plan.lamps.size():
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%d" % (index + 1)
		lamp.position = plan.lamps[index]
		lamp.light_color = LAMP_COLOUR
		lamp.light_energy = 1.1
		lamp.omni_range = 9.0
		add_child(lamp)


## The deposit machine (statiegeld) of the plan's "deposit" ({"at", "turn"}).
func show_deposit_machine(deposit: Dictionary) -> void:
	var machine: Node3D = MachineModels.instance(MachineModels.deposit_machine_mesh(), DEPOSIT_MACHINE_NAME)
	machine.position = deposit.at
	machine.rotation.y = float(deposit.turn)
	add_child(machine)


## Plays `sound_name` at `at` (global) in the world; nothing without the game's audio.
func play_sound(at: Vector3, sound_name: String) -> void:
	var audio := get_node_or_null(SPATIAL_AUDIO)
	if audio and audio.has_method("play_event"):
		audio.play_event(at, sound_name)


func _grid_map(map_name: String, of_library: MeshLibrary, at: Vector3) -> GridMap:
	var grid := GridMap.new()
	grid.name = map_name
	grid.mesh_library = of_library
	grid.cell_size = Vector3(0.5, 0.5, 0.5)
	grid.cell_center_x = false
	grid.cell_center_y = false
	grid.cell_center_z = false
	grid.position = at
	add_child(grid)
	return grid


func _put(grid: GridMap, item_name: String, at: Vector3, turn: float) -> void:
	var item := grid.mesh_library.find_item_by_name(item_name)
	if item < 0:
		push_warning("supermarkt: geen tile %s" % item_name)
		return
	var cell := Vector3i(roundi(at.x * 2.0), roundi(at.y * 2.0), roundi(at.z * 2.0))
	grid.set_cell_item(cell, item, grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, turn)))
