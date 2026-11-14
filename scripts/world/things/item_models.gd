extends RefCounted
## The voxel models of the items a zwerver can carry (Items.ITEMS, scripts/player/items.gd),
## made in code from voxels (PlayerModel.VoxelFigure, as the machines and the small things of
## scripts/world/things/machine_models.gd), for the reward screen: the item that was just given turns
## slowly, big in view. The models are icons more than scale models: an apple and a sleeping
## bag both fill the screen (about 10 to 24 voxels in their longest direction), each with a
## few colours and the details that make it what it is (the crust of the kroket, the mayo on
## the patat, the grid of the stroopwafel). Each mesh is made once and shared; it stands on
## y = 0, centred in x and z, its front facing +z (the front of a figure is its lowest z, see
## VoxelFigure.to_parts). An id without a model gets a plain paper bag.
##   const ItemModels = preload("res://scripts/world/things/item_models.gd")
##   model.mesh = ItemModels.mesh_for("kroket")

const PlayerModel = preload("res://scripts/player/player_model.gd")
## Metres per voxel of the items.
const ITEM_VOXEL := 0.025
## The cache key of the fallback model.
const FALLBACK := "?"

const STEEL := Color("#8C939E")
const STEEL_DARK := Color("#5E646E")
const DARK := Color("#14161C")
const WHITE := Color("#F2F0EA")
const PAPER := Color("#EDE6D2")
const CRUST := Color("#B5672A")
const BREAD_CRUMB := Color("#E8C890")
const LEAF_GREEN := Color("#3E8A34")
const STEM_GREEN := Color("#2E6A2A")
const WAFFLE := Color("#D8A050")
const WAFFLE_GROOVE := Color("#A86A28")
const SYRUP := Color("#8A4A10")
const GLASS_WATER := Color("#6FB0D8")
const CARDBOARD := Color("#C8A060")

static var _meshes := {}
static var _modelled := {}


## The mesh of an item (every id of Items.ITEMS has its own; another id: a plain paper bag).
static func mesh_for(item_id: String) -> ArrayMesh:
	if _meshes.has(item_id):
		return _meshes[item_id]
	var figure := PlayerModel.VoxelFigure.new()
	var mesh: ArrayMesh
	if _build(item_id, figure):
		mesh = _mesh_of(figure, ITEM_VOXEL)
		_modelled[item_id] = true
	else:
		mesh = _fallback_mesh()
	_meshes[item_id] = mesh
	return mesh


## Whether the item has a model of its own (not the fallback bag).
static func has_model(item_id: String) -> bool:
	if not _meshes.has(item_id):
		mesh_for(item_id)
	return _modelled.has(item_id)


static func _build(item_id: String, figure: PlayerModel.VoxelFigure) -> bool:
	match item_id:
		"brood": _build_bag_of_crusts(figure)
		"frikandel": _build_frikandel(figure)
		"kroket": _build_kroket(figure)
		"patat": _build_patat(figure)
		"appel": _build_apple(figure)
		"vis": _build_fish(figure)
		"water": _build_tap_water(figure)
		"energiedrank": _build_energy_drink(figure)
		"jenever": _build_jenever(figure)
		"bier": _build_beer(figure)
		"sigaretten": _build_tobacco(figure)
		"slaapzak": _build_sleeping_bag(figure)
		"emmer": _build_bucket(figure)
		"hengel": _build_fishing_rod(figure)
		"pleister": _build_plasters(figure)
		"statiegeld": _build_deposit_bottles(figure)
		"hoed": _build_cowboy_hat(figure)
		"foto": _build_photo(figure)
		"koffie": _build_coffee(figure)
		"cappuccino": _build_cappuccino(figure)
		"gevulde_koek": _build_filled_cookie(figure)
		"broodje_kaas": _build_cheese_roll(figure)
		"broodje_kroket": _build_kroket_roll(figure)
		"krentenbol": _build_currant_bun(figure)
		"mineraalwater": _build_mineral_water(figure)
		"krant": _build_newspaper(figure)
		"kauwgom": _build_chewing_gum(figure)
		"tulpen": _build_tulips(figure)
		"roos": _build_rose(figure)
		"puzzelboek": _build_puzzle_book(figure)
		"stadskaart": _build_town_map(figure)
		"pocketboek": _build_paperback(figure)
		"stroopwafel": _build_stroopwafel(figure)
		"pak_stroopwafels": _build_stroopwafel_pack(figure)
		"drop": _build_liquorice_bag(figure)
		"winegums": _build_winegum_bag(figure)
		"chocoladereep": _build_chocolate_bar(figure)
		"crackers": _build_crackers(figure)
		"ontbijtkoek": _build_spice_cake(figure)
		"zak_chips": _build_crisps_bag(figure)
		"blik_soep": _build_soup_can(figure)
		"pak_melk": _build_milk_carton(figure)
		"ijsje": _build_ice_lolly(figure)
		"vers_brood": _build_fresh_loaf(figure)
		"croissant": _build_croissant(figure)
		"banaan": _build_banana(figure)
		"ov_chipkaart": _build_transit_card(figure)
		"los_kaartje": _build_paper_ticket(figure)
		"wachtnummer": _build_queue_ticket(figure)
		"blikje": _build_empty_can(figure)
		"pinpas": _build_bank_card(figure)
		"id_kaart": _build_id_card(figure)
		"oude_jas": _build_old_coat(figure)
		_:
			return false
	return true


# --- food ----------------------------------------------------------------------------------

## A see-through bag of old crusts, tied at the top with a red tie.
static func _build_bag_of_crusts(figure: PlayerModel.VoxelFigure) -> void:
	var bag := Color("#DCE2E6")
	_box(figure, Vector3i(0, 0, 0), Vector3i(11, 13, 7), bag, "plastic")
	for level in 14:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(11, 0), Vector2i(0, 7), Vector2i(11, 7)]:
			figure.clear(corner.x, level, corner.y)
	# the crusts against the plastic
	var crust_tones := [CRUST, Color("#8E4E1E"), Color("#D49A58")]
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == bag and cell.y <= 10 and _speckle(cell) < 45,
		crust_tones, "skin")
	_box(figure, Vector3i(4, 14, 3), Vector3i(7, 15, 4), bag, "plastic")
	_box(figure, Vector3i(3, 14, 2), Vector3i(8, 14, 5), Color("#D23A2A"), "plastic")
	_box(figure, Vector3i(3, 16, 2), Vector3i(8, 17, 5), bag, "plastic")
	figure.clear(3, 17, 2)
	figure.clear(8, 17, 5)


## A long dark frikandel on a paper napkin, a bite out of one end.
static func _build_frikandel(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(21, 0, 8), PAPER, "skin")
	var sausage := Color("#7A3B22")
	_cylinder_x(figure, Vector2(3.0, 4.5), 2.1, 1, 20, sausage, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == sausage and _speckle(cell) < 35,
		[Color("#5E2B18"), Color("#8C4A2C")], "skin")
	for level in range(1, 6):
		for depth in range(2, 8):
			if absf(level - 2.5) > 1.0 or absf(depth - 4.0) > 1.0:
				figure.clear(1, level, depth)
				figure.clear(20, level, depth)
	_clear_box(figure, Vector3i(18, 3, 0), Vector3i(20, 5, 8))
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x == 17 and cell.y >= 1, [Color("#A86448")], "skin")


## A kroket: a fat cylinder with round ends in crisp crust tones, the ragout showing at the
## broken end.
static func _build_kroket(figure: PlayerModel.VoxelFigure) -> void:
	_cylinder_x(figure, Vector2(3.5, 3.5), 3.5, 2, 13, CRUST, "skin")
	_cylinder_x(figure, Vector2(3.5, 3.5), 2.6, 1, 1, CRUST, "skin")
	_cylinder_x(figure, Vector2(3.5, 3.5), 2.6, 14, 14, CRUST, "skin")
	_cylinder_x(figure, Vector2(3.5, 3.5), 1.5, 0, 0, CRUST, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == CRUST and _speckle(cell) < 60,
		[Color("#C9823A"), Color("#9A5220"), Color("#D89A4A"), Color("#8A4818")], "skin")
	_box(figure, Vector3i(14, 2, 2), Vector3i(14, 4, 4), Color("#E2BE84"), "skin")
	_box(figure, Vector3i(14, 3, 3), Vector3i(14, 3, 3), Color("#F0D4A0"), "skin")


## A paper cone with a red band, chips sticking out, a dollop of mayo and a little fork.
static func _build_patat(figure: PlayerModel.VoxelFigure) -> void:
	var cone := Color("#F4F0E4")
	var band := Color("#D23A2A")
	for level in 13:
		_cylinder_y(figure, Vector2(6.0, 6.0), 1.4 + level * 0.33, level, level, cone, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 8 and cell.y <= 9, [band], "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y <= 6 and (cell.x + cell.y) % 4 == 0, [band], "skin")
	var chip := Color("#F2C14E")
	var chip_tip := Color("#D89A30")
	for column in range(2, 10):
		for depth in range(2, 10):
			if Vector2(column + 0.5 - 6.0, depth + 0.5 - 6.0).length() > 4.0:
				continue
			var speckle := _speckle(Vector3i(column, 0, depth))
			if speckle < 25:
				continue
			var top := 13 + speckle % 5
			_box(figure, Vector3i(column, 12, depth), Vector3i(column, top - 1, depth), chip, "skin")
			_box(figure, Vector3i(column, top, depth), Vector3i(column, top, depth), chip_tip, "skin")
	_ellipsoid(figure, Vector3(5.5, 16.0, 4.5), Vector3(2.6, 1.8, 2.3), Color("#FFF4C8"), "plastic")
	_box(figure, Vector3i(8, 14, 6), Vector3i(8, 19, 6), Color("#E0302A"), "plastic")
	_box(figure, Vector3i(8, 19, 5), Vector3i(8, 19, 7), Color("#E0302A"), "plastic")


## A red apple with a yellow blush, a bruise on its front, a stem and a leaf.
static func _build_apple(figure: PlayerModel.VoxelFigure) -> void:
	var red := Color("#C8242C")
	_ellipsoid(figure, Vector3(7.0, 6.5, 7.0), Vector3(7.0, 6.5, 7.0), red, "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x >= 9 and cell.y >= 5 and _speckle(cell) < 55,
		[Color("#E8A030"), Color("#D86A2A")], "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == red and _speckle(cell) < 20, [Color("#A81820")], "plastic")
	for column in range(3, 7):
		for level in range(3, 7):
			_paint_front(figure, column, level, Color("#6A2A1A"), "skin")
	_clear_box(figure, Vector3i(6, 12, 6), Vector3i(7, 12, 7))
	_box(figure, Vector3i(7, 11, 7), Vector3i(7, 15, 7), Color("#5A3A1A"), "skin")
	_box(figure, Vector3i(8, 14, 7), Vector3i(10, 14, 8), LEAF_GREEN, "plastic")
	_box(figure, Vector3i(9, 15, 8), Vector3i(10, 15, 8), LEAF_GREEN, "plastic")


## A fish seen from its side: a dark back, silver flanks, a white belly, fins and an eye.
static func _build_fish(figure: PlayerModel.VoxelFigure) -> void:
	var silver := Color("#A8B4BC")
	var back := Color("#5C6A78")
	var belly := Color("#E4E8EA")
	_ellipsoid(figure, Vector3(9.0, 5.0, 2.0), Vector3(9.0, 4.5, 2.0), silver, "metal")
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y >= 7, [back], "metal")
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y <= 2, [belly], "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 3 and cell.y <= 6 and _speckle(cell) < 20, [Color("#C8D2D8")], "metal")
	for tail_column in range(17, 22):
		var spread := tail_column - 16
		_box(figure, Vector3i(tail_column, 5 - spread, 1), Vector3i(tail_column, 5 + spread, 2), back, "metal")
	_box(figure, Vector3i(7, 10, 1), Vector3i(12, 10, 2), back, "metal")
	_box(figure, Vector3i(8, 11, 1), Vector3i(10, 11, 2), back, "metal")
	_box(figure, Vector3i(9, 0, 1), Vector3i(11, 0, 2), back, "metal")
	for level in range(3, 8):
		_paint_front(figure, 5, level, Color("#7A8894"), "metal")
		_paint_back(figure, 5, level, Color("#7A8894"), "metal")
	_paint_front(figure, 2, 6, Color("#F4F4F0"), "eye")
	_paint_back(figure, 2, 6, Color("#F4F4F0"), "eye")
	_paint_front(figure, 2, 5, DARK, "eye")
	_paint_back(figure, 2, 5, DARK, "eye")
	_paint_front(figure, 0, 4, Color("#C86A6A"), "plastic")


## A bottle of tap water, refilled: no cap's seal, a torn bit of label.
static func _build_tap_water(figure: PlayerModel.VoxelFigure) -> void:
	_bottle(figure, 3.5, 13, 8, GLASS_WATER, Color("#C8E6F2"), Color("#2E6FD0"))
	for column in range(1, 4):
		for level in range(5, 8):
			if column + level != 9:
				_paint_front(figure, column, level, Color("#E8E8E0"), "plastic")


## A small bottle of spring water from the kiosk: full, a blue label with a white wave.
static func _build_mineral_water(figure: PlayerModel.VoxelFigure) -> void:
	_bottle(figure, 3.0, 10, 13, Color("#7FC0E4"), Color("#C8E6F2"), Color("#1C4FA0"))
	var label := Color("#2F7FD8")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 4 and cell.y <= 8, [label], "plastic")
	for column in range(0, 8):
		_paint_front(figure, column, 6 + int(column % 3 == 1), Color("#F4F8FC"), "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == Color("#7FC0E4") and _speckle(cell) < 12, [Color("#E4F4FC")], "glass")


## A tall slim energy can: dark with a green lightning bolt that glows.
static func _build_energy_drink(figure: PlayerModel.VoxelFigure) -> void:
	_can(figure, 2.6, 17, Color("#1C1C2A"))
	var green := Color("#8CFF3A")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 15 or cell.y == 3, [green], "plastic")
	var bolt := [Vector2i(4, 13), Vector2i(3, 13), Vector2i(3, 12), Vector2i(3, 11), Vector2i(2, 11),
			Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10), Vector2i(3, 9), Vector2i(3, 8),
			Vector2i(2, 7), Vector2i(2, 6), Vector2i(1, 5)]
	for point: Vector2i in bolt:
		_paint_front(figure, point.x, point.y, green, "glow", true)


## A can of beer: gold, a white label with a red stripe and green leaves of hops.
static func _build_beer(figure: PlayerModel.VoxelFigure) -> void:
	_can(figure, 3.2, 11, Color("#D8A63A"))
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 5 and cell.y <= 8, [Color("#F2EEE2")], "plastic")
	for column in range(1, 6):
		_paint_front(figure, column, 7, Color("#C8242C"), "plastic")
	_paint_front(figure, 3, 5, LEAF_GREEN, "plastic")
	_paint_front(figure, 2, 6, LEAF_GREEN, "plastic")
	_paint_front(figure, 4, 6, LEAF_GREEN, "plastic")


## An empty can out of a bin: red with a white wave, dented, no ring.
static func _build_empty_can(figure: PlayerModel.VoxelFigure) -> void:
	_can(figure, 2.6, 10, Color("#C8242C"), false)
	for column in range(0, 6):
		_paint_front(figure, column, 5 + int(column % 4 >= 2), Color("#F4F4F0"), "plastic")
	# the dents
	for cell: Vector3i in [Vector3i(5, 7, 2), Vector3i(5, 7, 3), Vector3i(5, 8, 2), Vector3i(0, 3, 3),
			Vector3i(1, 3, 0), Vector3i(2, 9, 0)]:
		figure.clear(cell.x, cell.y, cell.z)
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == Color("#C8242C") and _speckle(cell) < 18, [Color("#8A1A1E")], "metal")


## A stone kruik of jenever: brown below, cream above, a cork, an ear and a label.
static func _build_jenever(figure: PlayerModel.VoxelFigure) -> void:
	var lower := Color("#8A5A30")
	var upper := Color("#C8A060")
	var centre := Vector2(5.0, 5.0)
	_cylinder_y(figure, centre, 4.5, 0, 4, lower, "leather")
	_cylinder_y(figure, centre, 4.5, 5, 9, upper, "leather")
	_cylinder_y(figure, centre, 3.8, 10, 10, upper, "leather")
	_cylinder_y(figure, centre, 3.0, 11, 11, upper, "leather")
	_cylinder_y(figure, centre, 2.0, 12, 12, upper, "leather")
	_cylinder_y(figure, centre, 1.2, 13, 14, upper, "leather")
	_cylinder_y(figure, centre, 1.6, 15, 15, upper, "leather")
	_cylinder_y(figure, centre, 1.0, 16, 17, Color("#B08A5A"), "skin")
	# the ear
	_box(figure, Vector3i(6, 13, 4), Vector3i(10, 13, 5), upper, "leather")
	_box(figure, Vector3i(10, 9, 4), Vector3i(10, 12, 5), upper, "leather")
	_box(figure, Vector3i(9, 9, 4), Vector3i(9, 9, 5), upper, "leather")
	# the label
	for column in range(3, 7):
		for level in range(5, 9):
			_paint_front(figure, column, level, Color("#EDE4CC"), "skin")
	for column in range(4, 6):
		_paint_front(figure, column, 7, Color("#3A2A1A"), "skin")
		_paint_front(figure, column, 6, Color("#3A2A1A"), "skin")


## A paper coffee cup with a cardboard sleeve, black coffee inside and a wisp of steam.
static func _build_coffee(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(4.0, 4.0)
	for level in 12:
		var cup_colour := Color("#A8743E") if level >= 4 and level <= 7 else WHITE
		_cylinder_y(figure, centre, 2.6 + level * 0.09, level, level, cup_colour, "skin")
	var top_radius := 2.6 + 11 * 0.09
	_clear_cylinder_y(figure, centre, top_radius - 1.0, 11, 11)
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 10 and Vector2(cell.x + 0.5, cell.z + 0.5).distance_to(centre) <= top_radius - 1.0,
		[Color("#2A1810")], "glass")
	for point: Vector3i in [Vector3i(4, 13, 4), Vector3i(3, 14, 4), Vector3i(3, 15, 4), Vector3i(4, 16, 4),
			Vector3i(5, 17, 4)]:
		_box(figure, point, point, Color("#E4EAEE"), "plastic")


## A cappuccino in a white cup on a saucer: a dome of foam with cacao and a spoon.
static func _build_cappuccino(figure: PlayerModel.VoxelFigure) -> void:
	var porcelain := Color("#F4F2EE")
	var centre := Vector2(6.0, 6.0)
	_cylinder_y(figure, centre, 5.8, 0, 0, porcelain, "plastic")
	_cylinder_y(figure, centre, 5.8, 1, 1, porcelain, "plastic")
	_clear_cylinder_y(figure, centre, 4.6, 1, 1)
	for level in range(1, 8):
		_cylinder_y(figure, centre, 3.0 + (level - 1) * 0.15, level, level, porcelain, "plastic")
	var foam := Color("#F0E2C4")
	_cylinder_y(figure, centre, 2.9, 7, 7, foam, "cloth")
	_cylinder_y(figure, centre, 2.0, 8, 8, foam, "cloth")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == foam and _speckle(cell) < 30, [Color("#6A3A1A")], "cloth")
	# the handle
	_box(figure, Vector3i(10, 3, 6), Vector3i(11, 3, 6), porcelain, "plastic")
	_box(figure, Vector3i(11, 4, 6), Vector3i(11, 5, 6), porcelain, "plastic")
	_box(figure, Vector3i(10, 6, 6), Vector3i(11, 6, 6), porcelain, "plastic")
	# the spoon on the saucer
	_box(figure, Vector3i(7, 2, 1), Vector3i(10, 2, 1), STEEL, "metal")
	_box(figure, Vector3i(5, 2, 1), Vector3i(6, 2, 2), STEEL, "metal")


## A round gevulde koek, upright: glazed, half an almond on top, a bite showing the spijs.
static func _build_filled_cookie(figure: PlayerModel.VoxelFigure) -> void:
	var cookie := Color("#D89A48")
	var centre := Vector2(7.0, 7.0)
	_cylinder_z(figure, centre, 7.0, 0, 2, cookie, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(centre) > 6.0, [Color("#B87830")], "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == cookie and cell.z == 0, [Color("#E2A452")], "leather")
	var bite := Vector2(12.5, 12.0)
	for cell: Vector3i in figure.cells.keys():
		if Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(bite) < 3.2:
			figure.clear(cell.x, cell.y, cell.z)
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.z == 1 and Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(bite) < 4.4,
		[Color("#E8D49A")], "skin")
	_ellipsoid(figure, Vector3(6.5, 6.5, -0.2), Vector3(2.4, 1.5, 1.0), Color("#F0DCB0"), "skin")


## A white roll cut open with a slice of young cheese, its corners sticking out.
static func _build_cheese_roll(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(7.0, 7.0)
	_cylinder_y(figure, centre, 6.0, 0, 0, Color("#C8964E"), "skin")
	_cylinder_y(figure, centre, 6.5, 1, 2, Color("#E2BC80"), "skin")
	_box(figure, Vector3i(2, 3, 2), Vector3i(11, 3, 11), Color("#F2C84A"), "skin")
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(12, 1), Vector2i(1, 12), Vector2i(12, 12)]:
		_box(figure, Vector3i(corner.x, 2, corner.y), Vector3i(corner.x, 2, corner.y), Color("#F2C84A"), "skin")
	var top := Color("#D8A860")
	_ellipsoid(figure, Vector3(7.0, 3.5, 7.0), Vector3(6.6, 5.0, 6.6), top, "skin", 4)
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == top and cell.y >= 7, [Color("#C8904A")], "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 5 and _speckle(cell) < 10 and figure.cells[cell] != Color("#F2C84A"),
		[Color("#F4EEE0")], "skin")


## A soft roll with a kroket sticking out at both ends and mustard on it.
static func _build_kroket_roll(figure: PlayerModel.VoxelFigure) -> void:
	var bun := Color("#F0D8A8")
	_ellipsoid(figure, Vector3(8.0, 3.0, 6.0), Vector3(6.0, 3.0, 5.5), Color("#E4C48C"), "skin")
	_clear_box(figure, Vector3i(0, 3, 0), Vector3i(16, 8, 12))
	_cylinder_x(figure, Vector2(3.5, 6.0), 2.2, 0, 15, CRUST, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == CRUST and _speckle(cell) < 50, [Color("#C9823A"), Color("#9A5220")], "skin")
	_ellipsoid(figure, Vector3(8.0, 3.5, 6.0), Vector3(6.0, 5.0, 5.5), bun, "skin", 4)
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == bun and _speckle(cell) < 22, [Color("#FBF4E6")], "skin")
	var mustard := Color("#E0B020")
	for column in [0, 1, 2, 13, 14, 15]:
		for depth in range(5, 7):
			_paint_top(figure, column, depth, mustard, "plastic")
	for column in range(4, 12):
		if column % 3 != 0:
			_paint_front(figure, column, 3, mustard, "plastic")


## A round currant bun, shiny brown, full of dark currants.
static func _build_currant_bun(figure: PlayerModel.VoxelFigure) -> void:
	var bun := Color("#B8702E")
	_ellipsoid(figure, Vector3(7.0, 0.0, 7.0), Vector3(7.0, 7.5, 7.0), bun, "leather", 0)
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 0, [Color("#D8A060")], "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == bun and _speckle(cell) < 22,
		[Color("#3A1A1A"), Color("#2A1010"), Color("#C8902E")], "leather")


## A whole wholemeal loaf, fresh: dark crust, light score cuts and oats on top.
static func _build_fresh_loaf(figure: PlayerModel.VoxelFigure) -> void:
	var crust := Color("#8A5428")
	_ellipsoid(figure, Vector3(10.0, 0.0, 6.0), Vector3(10.0, 7.0, 6.0), crust, "skin", 0)
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 0, [Color("#B07A44")], "skin")
	for column in range(0, 20):
		for depth in range(0, 12):
			if (column + floori(depth / 2.0)) % 5 == 0 and column > 2 and column < 18:
				_paint_top(figure, column, depth, Color("#C89A60"), "skin")
			elif _speckle(Vector3i(column, 1, depth)) < 10:
				_paint_top(figure, column, depth, Color("#E8D8B0"), "skin")


## A loaf of ontbijtkoek: shiny dark top, cut open at one end.
static func _build_spice_cake(figure: PlayerModel.VoxelFigure) -> void:
	var side := Color("#8A4A20")
	_box(figure, Vector3i(0, 0, 0), Vector3i(17, 6, 7), side, "skin")
	_box(figure, Vector3i(0, 7, 1), Vector3i(17, 7, 6), Color("#6A3414"), "leather")
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 6, [Color("#6A3414")], "leather")
	var crumb := Color("#B8743A")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x == 17 and cell.y >= 1 and cell.y <= 5 and cell.z >= 1 and cell.z <= 6,
		[crumb, crumb, Color("#A86430")], "skin")
	# a slice, cut off and leaning against it
	_box(figure, Vector3i(19, 0, 1), Vector3i(19, 5, 6), crumb, "skin")
	_box(figure, Vector3i(19, 6, 2), Vector3i(19, 6, 5), Color("#6A3414"), "leather")


## A croissant: a crescent of puffed segments, light and dark golden layers.
static func _build_croissant(figure: PlayerModel.VoxelFigure) -> void:
	var tones := [Color("#D8902E"), Color("#EAB050")]
	var segments := 9
	for segment in segments:
		var angle := deg_to_rad(-72.0 + 144.0 * segment / (segments - 1))
		var from_middle := absf(segment - (segments - 1) / 2.0) / ((segments - 1) / 2.0)
		var radius := 3.8 * (1.0 - 0.55 * from_middle)
		var at := Vector3(11.5 + 9.0 * sin(angle), radius * 0.85, 1.0 + 9.0 * cos(angle))
		_ellipsoid(figure, at, Vector3(radius, radius * 0.85, radius), tones[segment % 2], "leather")


## A banana, curved like a smile: yellow with brown spots and brown tips.
static func _build_banana(figure: PlayerModel.VoxelFigure) -> void:
	var yellow := Color("#F2D040")
	for step in 31:
		var angle := deg_to_rad(208.0 + step * 4.0)
		var from_middle := absf(step - 15.0) / 15.0
		var radius := 2.4 * (1.0 - 0.55 * from_middle * from_middle)
		var at := Vector3(11.5 + 11.0 * cos(angle), 14.0 + 11.0 * sin(angle), 3.0)
		_ellipsoid(figure, at, Vector3(radius, radius, radius), yellow, "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == yellow and _speckle(cell) < 9, [Color("#6A4A1A")], "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == yellow and cell.y > 6 and cell.y <= 7 and _speckle(cell) < 50,
		[Color("#C8D040")], "plastic")
	var stem := Color("#6A5A2A")
	_box(figure, Vector3i(21, 8, 3), Vector3i(22, 9, 3), stem, "skin")
	_box(figure, Vector3i(22, 10, 3), Vector3i(22, 10, 3), stem, "skin")
	_box(figure, Vector3i(1, 8, 3), Vector3i(1, 8, 3), Color("#3A2A12"), "skin")


## A stroopwafel, upright: two thin waffles with a diamond grid, syrup between them.
static func _build_stroopwafel(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(7.0, 7.0)
	_cylinder_z(figure, centre, 7.0, 0, 2, WAFFLE, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.z == 1, [SYRUP], "leather")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.z != 1 and ((cell.x + cell.y) % 3 == 0 or (cell.x - cell.y + 30) % 3 == 0),
		[WAFFLE_GROOVE], "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.z != 1 and Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(centre) > 6.2,
		[Color("#C08840")], "skin")
	_box(figure, Vector3i(10, 3, -1), Vector3i(10, 5, -1), SYRUP, "leather")
	_box(figure, Vector3i(10, 2, 0), Vector3i(10, 2, 0), SYRUP, "leather")


## A pack of stroopwafels: a stack of waffles with syrup lines and a red label.
static func _build_stroopwafel_pack(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(6.5, 6.5)
	for level in 12:
		_cylinder_y(figure, centre, 6.3, level, level, WAFFLE if level % 2 == 0 else SYRUP,
				"skin" if level % 2 == 0 else "leather")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 11 and ((cell.x + cell.z) % 3 == 0 or (cell.x - cell.z + 30) % 3 == 0),
		[WAFFLE_GROOVE], "skin")
	_cylinder_y(figure, centre, 6.3, 11, 11, WAFFLE, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 11 and ((cell.x + cell.z) % 3 == 0 or (cell.x - cell.z + 30) % 3 == 0),
		[WAFFLE_GROOVE], "skin")
	var label := Color("#C8242C")
	for column in range(3, 10):
		for level in range(3, 9):
			_paint_front(figure, column, level, label, "plastic")
	for column in range(4, 9):
		_paint_front(figure, column, 6, Color("#F2C230"), "plastic")
	_paint_front(figure, 6, 4, Color("#F2C230"), "plastic")


## A chocolate bar, upright: a red wrapper with a gold band, torn open, a bite out of it.
static func _build_chocolate_bar(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(9, 11, 1), Color("#B0242C"), "plastic")
	_box(figure, Vector3i(0, 5, 0), Vector3i(9, 6, 0), Color("#E0B040"), "metal")
	_box(figure, Vector3i(0, 12, 0), Vector3i(9, 12, 1), Color("#C8CCD2"), "metal")
	var chocolate := Color("#5A3218")
	_box(figure, Vector3i(0, 13, 0), Vector3i(9, 17, 1), chocolate, "leather")
	var groove := Color("#3E200E")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 13 and cell.z == 0 and (cell.x == 3 or cell.x == 6 or cell.y == 15),
		[groove], "leather")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == chocolate and _speckle(cell) < 12, [Color("#A8703A")], "skin")
	_clear_box(figure, Vector3i(7, 17, 0), Vector3i(9, 17, 1))
	_clear_box(figure, Vector3i(8, 16, 0), Vector3i(9, 16, 1))
	figure.clear(0, 12, 0)
	figure.clear(4, 12, 0)


## A stack of square crackers with holes, half in a blue paper sleeve.
static func _build_crackers(figure: PlayerModel.VoxelFigure) -> void:
	var cracker := Color("#E8C27A")
	var shifts := [0, 1, 0, -1, 0, 1, 0]
	for layer in shifts.size():
		var shift: int = shifts[layer]
		_box(figure, Vector3i(1 + shift, layer, 1), Vector3i(10 + shift, layer, 10), cracker, "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == shifts.size() - 1 and posmod(cell.x, 3) == 1 and cell.z % 3 == 1,
		[Color("#B88A40")], "skin")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y < shifts.size() - 1 and figure.cells[cell] == cracker and _speckle(cell) < 40,
		[Color("#D4A860")], "skin")
	var sleeve := Color("#3A6AC0")
	_box(figure, Vector3i(0, 0, 0), Vector3i(11, 3, 0), sleeve, "plastic")
	_box(figure, Vector3i(0, 0, 11), Vector3i(11, 3, 11), sleeve, "plastic")
	_box(figure, Vector3i(0, 0, 0), Vector3i(0, 3, 11), sleeve, "plastic")
	_box(figure, Vector3i(11, 0, 0), Vector3i(11, 3, 11), sleeve, "plastic")
	_box(figure, Vector3i(3, 1, 0), Vector3i(8, 2, 0), Color("#F2F0EA"), "plastic")
	_box(figure, Vector3i(4, 1, 0), Vector3i(4, 2, 0), Color("#E8C27A"), "plastic")


## A bag of salty liquorice: black, a window full of black drops, white seals.
static func _build_liquorice_bag(figure: PlayerModel.VoxelFigure) -> void:
	_candy_bag(figure, Vector3i(12, 17, 5), Color("#222226"), Color("#E8E8E8"), Color("#D8D8DC"),
			[Color("#101010"), Color("#2E2E30"), Color("#4A4A4E")], 82)


## A bag of winegums: pink, a window of red, green, yellow, orange and black gums.
static func _build_winegum_bag(figure: PlayerModel.VoxelFigure) -> void:
	_candy_bag(figure, Vector3i(12, 17, 5), Color("#E84A8A"), Color("#F2C230"), Color("#F4F0F4"),
			[Color("#D8242C"), Color("#3AA83A"), Color("#F2C230"), Color("#F07A20"), Color("#1A1A1A")], 72)


## The big bag of crisps: yellow, puffed out, chips on its front.
static func _build_crisps_bag(figure: PlayerModel.VoxelFigure) -> void:
	var bag := Color("#F2C230")
	_candy_bag(figure, Vector3i(14, 20, 6), bag, Color("#D23A2A"), bag,
			[Color("#F2D88A"), Color("#E8B850"), Color("#F8E4A8")], 45)
	_box(figure, Vector3i(2, 4, -1), Vector3i(11, 13, -1), bag, "plastic")
	for cell: Vector3i in figure.cells.keys():
		if cell.z == -1 and _speckle(cell) < 40:
			figure.cells[cell] = Color("#E8B850")
	_box(figure, Vector3i(3, 15, 0), Vector3i(10, 16, 0), Color("#D23A2A"), "plastic")


## A pack of chewing gum: white with a green band, a stick in foil pulled out.
static func _build_chewing_gum(figure: PlayerModel.VoxelFigure) -> void:
	var pack := Color("#EEF6F0")
	var band := Color("#2EB060")
	_box(figure, Vector3i(0, 0, 0), Vector3i(11, 6, 2), pack, "plastic")
	_box(figure, Vector3i(0, 2, 0), Vector3i(11, 4, 2), band, "plastic")
	for column in range(1, 11, 3):
		_box(figure, Vector3i(column, 3, 0), Vector3i(column, 3, 0), pack, "plastic")
	_box(figure, Vector3i(4, 7, 1), Vector3i(6, 9, 1), Color("#C8CCD2"), "metal")
	_box(figure, Vector3i(5, 10, 1), Vector3i(5, 10, 1), Color("#C8CCD2"), "metal")
	_box(figure, Vector3i(7, 7, 1), Vector3i(8, 8, 1), Color("#B8E8C8"), "plastic")


## A raketje: a lolly in three colours, green, yellow and red, fins and a wooden stick.
static func _build_ice_lolly(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(6.0, 6.0)
	_box(figure, Vector3i(5, 0, 5), Vector3i(6, 4, 5), Color("#E0C08A"), "skin")
	var green := Color("#3AC04A")
	_cylinder_y(figure, centre, 3.0, 5, 9, green, "plastic")
	_cylinder_y(figure, centre, 2.6, 10, 14, Color("#F2D23A"), "plastic")
	_cylinder_y(figure, centre, 2.1, 15, 16, Color("#E0302A"), "plastic")
	_cylinder_y(figure, centre, 1.5, 17, 18, Color("#E0302A"), "plastic")
	_cylinder_y(figure, centre, 0.8, 19, 20, Color("#E0302A"), "plastic")
	var fin := Color("#2A9A3A")
	_box(figure, Vector3i(1, 5, 5), Vector3i(2, 7, 6), fin, "plastic")
	_box(figure, Vector3i(9, 5, 5), Vector3i(10, 7, 6), fin, "plastic")
	_box(figure, Vector3i(5, 5, 1), Vector3i(6, 7, 2), fin, "plastic")
	_box(figure, Vector3i(5, 5, 9), Vector3i(6, 7, 10), fin, "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 5 and _speckle(cell) < 6, [Color("#F4FAFF")], "plastic")


## A tin of pea soup: a green label with a bowl on it, ridged steel ends and a ring on top.
static func _build_soup_can(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(5.0, 5.0)
	_cylinder_y(figure, centre, 4.4, 0, 0, STEEL, "metal")
	_cylinder_y(figure, centre, 4.6, 1, 1, STEEL_DARK, "metal")
	_cylinder_y(figure, centre, 4.6, 2, 9, Color("#3A7A2E"), "plastic")
	_cylinder_y(figure, centre, 4.6, 10, 10, STEEL_DARK, "metal")
	_cylinder_y(figure, centre, 4.4, 11, 11, STEEL, "metal")
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 8, [Color("#F2C230")], "plastic")
	for column in range(3, 8):
		_paint_front(figure, column, 6, Color("#9AAA30"), "plastic")
	for column in range(3, 8):
		_paint_front(figure, column, 5, Color("#F2F2F2"), "plastic")
	for column in range(4, 7):
		_paint_front(figure, column, 4, Color("#F2F2F2"), "plastic")
	_paint_front(figure, 4, 6, Color("#A8402A"), "plastic")
	_paint_front(figure, 6, 6, Color("#A8402A"), "plastic")
	_box(figure, Vector3i(4, 12, 3), Vector3i(6, 12, 3), STEEL, "metal")
	_box(figure, Vector3i(4, 12, 5), Vector3i(6, 12, 5), STEEL, "metal")
	_box(figure, Vector3i(4, 12, 4), Vector3i(4, 12, 4), STEEL, "metal")
	_box(figure, Vector3i(6, 12, 4), Vector3i(6, 12, 4), STEEL, "metal")


## A carton of half-skimmed milk: white with a light blue band, a gable top and a cap.
static func _build_milk_carton(figure: PlayerModel.VoxelFigure) -> void:
	var carton := Color("#F4F4F2")
	_box(figure, Vector3i(0, 0, 0), Vector3i(7, 13, 7), carton, "plastic")
	for step in 4:
		_box(figure, Vector3i(0, 14 + step, step), Vector3i(7, 14 + step, 7 - step), carton, "plastic")
	_box(figure, Vector3i(0, 18, 3), Vector3i(7, 18, 4), carton, "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 3 and cell.y <= 8, [Color("#5AA0E0")], "plastic")
	for level in range(4, 8):
		_paint_front(figure, 3, level, carton, "plastic")
		_paint_front(figure, 4, level, carton, "plastic")
	for column in range(0, 8):
		_paint_front(figure, column, 10 + int(column % 3 == 0), Color("#2A6AC8"), "plastic")
	_box(figure, Vector3i(5, 16, 0), Vector3i(6, 16, 1), Color("#2A6AC8"), "plastic")


# --- drink containers, bags and other things ------------------------------------------------

## A beer-crate's worth: three empty deposit bottles, brown and green, with labels.
static func _build_deposit_bottles(figure: PlayerModel.VoxelFigure) -> void:
	_beer_bottle(figure, 0, 0, Color("#6A3A14"), Color("#EDE4CC"))
	_beer_bottle(figure, 5, 3, Color("#2E6A2E"), Color("#D8D8D0"))
	_beer_bottle(figure, 10, 1, Color("#5A3010"), Color("#C8242C"))


## A pouch of rolling tobacco: green with a cream label, tobacco sticking out, papers beside it.
static func _build_tobacco(figure: PlayerModel.VoxelFigure) -> void:
	var pouch := Color("#2F5A3C")
	_box(figure, Vector3i(0, 0, 0), Vector3i(13, 9, 3), pouch, "plastic")
	_box(figure, Vector3i(0, 6, 0), Vector3i(13, 9, 0), Color("#24482F"), "plastic")
	_box(figure, Vector3i(3, 2, 0), Vector3i(10, 4, 0), Color("#E8D8A8"), "plastic")
	_box(figure, Vector3i(4, 3, 0), Vector3i(9, 3, 0), Color("#8A5A2E"), "plastic")
	var tobacco := Color("#8A5A30")
	for column in range(1, 13):
		for depth in range(1, 3):
			var speckle := _speckle(Vector3i(column, 10, depth))
			if speckle < 70:
				_box(figure, Vector3i(column, 10, depth), Vector3i(column, 10 + int(speckle < 25), depth),
						tobacco if speckle % 2 == 0 else Color("#6A4020"), "hair")
	_box(figure, Vector3i(15, 0, 0), Vector3i(18, 6, 1), Color("#E8E0D0"), "skin")
	_box(figure, Vector3i(15, 5, 0), Vector3i(18, 6, 0), Color("#C8242C"), "skin")
	_box(figure, Vector3i(16, 7, 1), Vector3i(17, 8, 1), Color("#F4F0E8"), "skin")


## A sleeping bag rolled up: dark blue nylon, the yellow lining spiralling at the ends, two
## straps with buckles.
static func _build_sleeping_bag(figure: PlayerModel.VoxelFigure) -> void:
	var nylon := Color("#2C3E7A")
	var lining := Color("#D8A030")
	var centre := Vector2(5.5, 5.5)
	_cylinder_x(figure, centre, 5.5, 0, 19, nylon, "nylon")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return (cell.x == 0 or cell.x == 19) \
				and floori(Vector2(cell.y + 0.5, cell.z + 0.5).distance_to(centre) * 0.9) % 2 == 1,
		[lining], "knit")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == nylon and _speckle(cell) < 6, [Color("#4A4A3A")], "nylon")
	for strap_column in [4, 15]:
		_cylinder_x(figure, centre, 6.0, strap_column, strap_column, DARK, "leather")
		_cylinder_x(figure, centre, 5.5, strap_column, strap_column, DARK, "leather")
	_box(figure, Vector3i(4, 4, -1), Vector3i(4, 6, -1), STEEL, "metal")
	_box(figure, Vector3i(15, 4, -1), Vector3i(15, 6, -1), STEEL, "metal")


## A blue plastic bucket with water in it, a steel handle and a chamois over the rim.
static func _build_bucket(figure: PlayerModel.VoxelFigure) -> void:
	var blue := Color("#3A7AD0")
	var centre := Vector2(6.0, 6.0)
	for level in 13:
		_cylinder_y(figure, centre, 4.2 + level * 0.12, level, level, blue, "plastic")
	_clear_cylinder_y(figure, centre, 4.4, 9, 12)
	_cylinder_y(figure, centre, 4.4, 8, 8, Color("#6AA8D8"), "glass")
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 12, [Color("#5A9AE8")], "plastic")
	for step in 19:
		var angle := deg_to_rad(step * 10.0)
		_box(figure, Vector3i(roundi(5.5 + 6.0 * cos(angle)), roundi(12.0 + 5.5 * sin(angle)), 6),
				Vector3i(roundi(5.5 + 6.0 * cos(angle)), roundi(12.0 + 5.5 * sin(angle)), 6), STEEL, "metal")
	var chamois := Color("#E8C870")
	_box(figure, Vector3i(3, 13, 0), Vector3i(7, 13, 1), chamois, "leather")
	_box(figure, Vector3i(3, 7, -1), Vector3i(7, 13, -1), chamois, "leather")
	for column in range(3, 8):
		if _speckle(Vector3i(column, 7, -1)) < 50:
			figure.clear(column, 7, -1)
	_box(figure, Vector3i(5, 2, -1), Vector3i(5, 2, -1), Color("#6AA8D8"), "glass")  # the leak


## A fishing rod, slanting up: cork grip, a reel, rings, the line down to a red-white float.
static func _build_fishing_rod(figure: PlayerModel.VoxelFigure) -> void:
	var cork := Color("#C8A070")
	var rod := Color("#2E4A30")
	for step in 21:
		var colour := cork if step < 5 else rod
		_box(figure, Vector3i(2 + step, 2 + step, 2), Vector3i(3 + step, 2 + step, 2), colour,
				"skin" if step < 5 else "plastic")
		if step < 5:
			_box(figure, Vector3i(2 + step, 2 + step, 3), Vector3i(3 + step, 2 + step, 3), cork, "skin")
	_box(figure, Vector3i(1, 1, 2), Vector3i(2, 1, 3), DARK, "plastic")
	_box(figure, Vector3i(7, 4, 1), Vector3i(9, 6, 3), STEEL, "metal")
	_box(figure, Vector3i(8, 5, 0), Vector3i(8, 5, 0), DARK, "plastic")
	for guide_step in [10, 14, 18]:
		_box(figure, Vector3i(3 + guide_step, 1 + guide_step, 2), Vector3i(3 + guide_step, 1 + guide_step, 2),
				STEEL, "metal")
	_box(figure, Vector3i(23, 7, 2), Vector3i(23, 21, 2), Color("#E0E0E0"), "plastic")
	_ellipsoid(figure, Vector3(23.5, 4.5, 2.5), Vector3(1.6, 2.2, 1.6), Color("#F4F4F0"), "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x >= 22 and cell.y >= 5 and cell.y <= 6, [Color("#E0302A")], "plastic")
	_box(figure, Vector3i(23, 0, 2), Vector3i(23, 1, 2), Color("#E0E0E0"), "plastic")
	_box(figure, Vector3i(22, 0, 2), Vector3i(22, 0, 2), STEEL, "metal")


## A box of plasters: white with a red cross, one plaster lying on top.
static func _build_plasters(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(13, 7, 4), WHITE, "plastic")
	_box(figure, Vector3i(0, 8, 0), Vector3i(13, 8, 4), Color("#E4E2DA"), "plastic")
	var red := Color("#D22A2A")
	_box(figure, Vector3i(6, 1, 0), Vector3i(7, 6, 0), red, "plastic")
	_box(figure, Vector3i(4, 3, 0), Vector3i(9, 4, 0), red, "plastic")
	_box(figure, Vector3i(2, 9, 1), Vector3i(11, 9, 3), Color("#E2B890"), "skin")
	_box(figure, Vector3i(5, 9, 1), Vector3i(8, 9, 3), Color("#F4E0CC"), "skin")
	for corner: Vector2i in [Vector2i(2, 1), Vector2i(2, 3), Vector2i(11, 1), Vector2i(11, 3)]:
		figure.clear(corner.x, 9, corner.y)


## A cowboy hat: a wide brim curled up at the sides, a creased crown and a band with a
## silver concho.
static func _build_cowboy_hat(figure: PlayerModel.VoxelFigure) -> void:
	var felt := Color("#9A6A3A")
	var brim_centre := Vector2(11.0, 9.0)
	for column in range(0, 22):
		for depth in range(0, 18):
			var offset := Vector2((column + 0.5 - brim_centre.x) / 11.0, (depth + 0.5 - brim_centre.y) / 9.0)
			var distance := offset.length()
			if distance > 1.0:
				continue
			var level := 1
			if absf(offset.x) > 0.62:
				level = 2 if absf(offset.x) < 0.85 else 3
			elif absf(offset.y) > 0.7:
				level = 0
			_box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), felt, "cloth")
			if level == 3:
				_box(figure, Vector3i(column, 2, depth), Vector3i(column, 2, depth), felt, "cloth")
	for level in range(2, 9):
		var shrink := 1.0 if level < 7 else 0.85
		for column in range(0, 22):
			for depth in range(0, 18):
				var offset := Vector2((column + 0.5 - 11.0) / (5.5 * shrink), (depth + 0.5 - 9.0) / (4.5 * shrink))
				if offset.length() <= 1.0:
					_box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), felt, "cloth")
	_clear_box(figure, Vector3i(10, 8, 6), Vector3i(11, 8, 12))
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 2 and cell.y <= 3 and Vector2((cell.x + 0.5 - 11.0) / 5.5, (cell.z + 0.5 - 9.0) / 4.5).length() <= 1.0,
		[Color("#3A2418")], "leather")
	for column in range(10, 12):
		for level in range(2, 4):
			_paint_front(figure, column, level, Color("#D8DCE2"), "metal")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == felt and _speckle(cell) < 15, [Color("#86582E")], "cloth")


## An old photo, upright: a white border, in sepia a woman, a kotter and the harbour.
static func _build_photo(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(15, 12, 0), PAPER, "skin")
	_box(figure, Vector3i(1, 6, 0), Vector3i(14, 11, 0), Color("#C8B48A"), "skin")
	_box(figure, Vector3i(1, 3, 0), Vector3i(14, 5, 0), Color("#8A7A5A"), "skin")
	_box(figure, Vector3i(1, 1, 0), Vector3i(14, 2, 0), Color("#6A5A44"), "skin")
	var boat := Color("#3E3020")
	_box(figure, Vector3i(8, 4, 0), Vector3i(12, 4, 0), boat, "skin")
	_box(figure, Vector3i(7, 5, 0), Vector3i(13, 5, 0), boat, "skin")
	_box(figure, Vector3i(10, 6, 0), Vector3i(11, 7, 0), boat, "skin")
	_box(figure, Vector3i(9, 6, 0), Vector3i(9, 10, 0), boat, "skin")
	_box(figure, Vector3i(3, 1, 0), Vector3i(3, 2, 0), Color("#2E2418"), "skin")
	_box(figure, Vector3i(2, 3, 0), Vector3i(4, 6, 0), Color("#7A6448"), "skin")
	_box(figure, Vector3i(3, 7, 0), Vector3i(3, 7, 0), Color("#D8C090"), "skin")
	_box(figure, Vector3i(3, 8, 0), Vector3i(3, 8, 0), Color("#4A3A28"), "skin")
	_box(figure, Vector3i(12, 10, 0), Vector3i(12, 10, 0), Color("#5A4A34"), "skin")
	_box(figure, Vector3i(13, 9, 0), Vector3i(13, 9, 0), Color("#5A4A34"), "skin")
	figure.clear(15, 12, 0)
	_box(figure, Vector3i(14, 12, 1), Vector3i(15, 11, 1), Color("#D8D0B8"), "skin")


## Today's newspaper, folded and upright: a black headline, a photo and lines of text.
static func _build_newspaper(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(13, 17, 1), Color("#E8E4D8"), "skin")
	var ink := Color("#2A2A2E")
	_box(figure, Vector3i(1, 15, 0), Vector3i(12, 16, 0), ink, "skin")
	_box(figure, Vector3i(1, 9, 0), Vector3i(6, 13, 0), Color("#8A8E96"), "skin")
	_box(figure, Vector3i(2, 10, 0), Vector3i(4, 11, 0), Color("#5A5E66"), "skin")
	for level in range(1, 14, 2):
		var first_column := 8 if level >= 9 else 1
		for column in range(first_column, 13):
			if _speckle(Vector3i(column, level, 0)) < 82:
				_box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), Color("#6A6A70"), "skin")
	_box(figure, Vector3i(13, 0, 1), Vector3i(13, 17, 1), Color("#D4D0C4"), "skin")


## A puzzle booklet, upright: a yellow cover with a crossword grid, a pencil beside it.
static func _build_puzzle_book(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(11, 15, 1), Color("#F2C230"), "plastic")
	_box(figure, Vector3i(0, 0, 1), Vector3i(0, 15, 1), Color("#C89A20"), "plastic")
	_box(figure, Vector3i(1, 12, 0), Vector3i(10, 14, 0), Color("#D23A2A"), "plastic")
	for column in range(2, 9, 2):
		_box(figure, Vector3i(column, 13, 0), Vector3i(column, 13, 0), WHITE, "plastic")
	for column in range(2, 10):
		for level in range(2, 11):
			var cell_colour := DARK if _speckle(Vector3i(column, level, 0)) < 25 else Color("#F8F8F4")
			_box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), cell_colour, "plastic")
	_box(figure, Vector3i(13, 0, 0), Vector3i(13, 0, 0), DARK, "plastic")
	_box(figure, Vector3i(13, 1, 0), Vector3i(13, 1, 0), Color("#E0B880"), "skin")
	_box(figure, Vector3i(13, 2, 0), Vector3i(13, 12, 0), Color("#F2B020"), "plastic")
	_box(figure, Vector3i(13, 13, 0), Vector3i(13, 13, 0), STEEL, "metal")
	_box(figure, Vector3i(13, 14, 0), Vector3i(13, 14, 0), Color("#E87A90"), "plastic")


## A town map, folded like an accordion: the sea on the left, dunes, streets, parks and a
## red dot.
static func _build_town_map(figure: PlayerModel.VoxelFigure) -> void:
	for column in 20:
		var depth := roundi(absf(posmod(column, 10) - 5.0) * 0.6)
		for level in 14:
			var colour := Color("#E8E4D0")
			if column <= 3:
				colour = Color("#4A8AC8")
			elif column <= 5:
				colour = Color("#E8D49A")
			elif (column >= 7 and column <= 9 and level >= 9 and level <= 11) \
					or (column >= 14 and column <= 16 and level >= 2 and level <= 4):
				colour = Color("#8AC86A")
			elif level % 4 == 0 or column % 5 == 2:
				colour = Color("#F2D24A") if level == 8 else Color("#FAFAF4")
			elif column + level == 22:
				colour = Color("#6AA8D8")
			_box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), colour, "skin")
	figure.put(12, 6, roundi(absf(posmod(12, 10) - 5.0) * 0.6), Color("#D82A2A"))
	figure.put(12, 7, roundi(absf(posmod(12, 10) - 5.0) * 0.6), Color("#D82A2A"))
	figure.mark("plastic", [Color("#D82A2A")])


## A paperback detective: dark blue cover, a yellow title, a red fish, cream pages.
static func _build_paperback(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(10, 15, 2), Color("#1E2A50"), "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool: return cell.z == 1 and cell.x >= 1,
			[Color("#EDE4CC")], "skin")
	_box(figure, Vector3i(2, 12, 0), Vector3i(8, 13, 0), Color("#F2C230"), "plastic")
	for column in range(3, 8, 2):
		_box(figure, Vector3i(column, 10, 0), Vector3i(column, 10, 0), WHITE, "plastic")
	var red := Color("#C82A2A")
	_box(figure, Vector3i(3, 5, 0), Vector3i(7, 5, 0), red, "plastic")
	_box(figure, Vector3i(4, 4, 0), Vector3i(6, 6, 0), red, "plastic")
	_box(figure, Vector3i(8, 4, 0), Vector3i(8, 4, 0), red, "plastic")
	_box(figure, Vector3i(8, 6, 0), Vector3i(8, 6, 0), red, "plastic")
	_box(figure, Vector3i(4, 5, 0), Vector3i(4, 5, 0), WHITE, "plastic")
	for column in range(1, 10):
		_box(figure, Vector3i(column, 2 + int(column % 3 == 0), 0), Vector3i(column, 2 + int(column % 3 == 0), 0),
				Color("#5A8AC8"), "plastic")


## A bunch of tulips, red and yellow, in a paper cone with leaves.
static func _build_tulips(figure: PlayerModel.VoxelFigure) -> void:
	var stems := [Vector3i(3, 17, 7), Vector3i(7, 19, 4), Vector3i(11, 17, 7), Vector3i(5, 16, 10),
			Vector3i(9, 18, 10)]
	var heads := [Color("#D82A2A"), Color("#F2C22A"), Color("#D82A2A"), Color("#F2C22A"), Color("#E8402A")]
	_box(figure, Vector3i(7, 2, 7), Vector3i(7, 9, 7), STEM_GREEN, "plastic")
	for stem_index in stems.size():
		var stem: Vector3i = stems[stem_index]
		for level in range(9, stem.y):
			var progress := (level - 9.0) / (stem.y - 9.0)
			var column := roundi(lerpf(7.0, stem.x, progress))
			var depth := roundi(lerpf(7.0, stem.z, progress))
			_box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), STEM_GREEN, "plastic")
		var head: Color = heads[stem_index]
		_ellipsoid(figure, Vector3(stem.x + 0.5, stem.y + 1.8, stem.z + 0.5), Vector3(1.6, 2.2, 1.6), head, "plastic")
		figure.clear(stem.x, stem.y + 3, stem.z)
		figure.put(stem.x, stem.y + 3, stem.z - 1, head.darkened(0.15))
		figure.mark("plastic", [head.darkened(0.15)])
	_box(figure, Vector3i(2, 10, 7), Vector3i(2, 14, 7), LEAF_GREEN, "plastic")
	_box(figure, Vector3i(1, 13, 7), Vector3i(1, 15, 7), LEAF_GREEN, "plastic")
	_box(figure, Vector3i(12, 10, 6), Vector3i(12, 13, 6), LEAF_GREEN, "plastic")
	var wrap := Color("#D8C49A")
	for level in range(0, 11):
		var radius := 1.6 + level * 0.3
		_cylinder_y(figure, Vector2(7.5, 7.5), radius, level, level, wrap, "skin")
		if level >= 8:
			_clear_cylinder_y(figure, Vector2(7.5, 7.5), radius - 1.0, level, level)
	_cylinder_y(figure, Vector2(7.5, 7.5), 2.6, 4, 4, Color("#C8242C"), "cloth")


## A single red rose in a cellophane sleeve, open at the front, a ribbon round it.
static func _build_rose(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(6, 0, 5), Vector3i(6, 17, 5), STEM_GREEN, "plastic")
	for thorn: Vector3i in [Vector3i(7, 5, 5), Vector3i(5, 9, 5), Vector3i(7, 13, 5)]:
		_box(figure, thorn, thorn, Color("#1E4A1E"), "plastic")
	_box(figure, Vector3i(7, 8, 5), Vector3i(9, 9, 5), LEAF_GREEN, "plastic")
	_box(figure, Vector3i(3, 11, 5), Vector3i(5, 12, 5), LEAF_GREEN, "plastic")
	_box(figure, Vector3i(5, 17, 4), Vector3i(7, 17, 6), STEM_GREEN, "plastic")
	var red := Color("#C81E2E")
	_ellipsoid(figure, Vector3(6.5, 20.0, 5.5), Vector3(2.7, 2.7, 2.7), red, "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == red and (cell.x + cell.z + cell.y) % 3 == 0, [Color("#8A1020")], "plastic")
	var cellophane := Color("#DCEEF4")
	for level in range(2, 19):
		var radius := 1.2 + (level - 2) * 0.2
		for column in range(0, 13):
			for depth in range(5, 12):
				var distance := Vector2(column + 0.5 - 6.5, depth + 0.5 - 5.5).length()
				if distance <= radius and distance > radius - 1.0 and not figure.has(column, level, depth):
					_box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), cellophane, "glass")
	_box(figure, Vector3i(5, 4, 4), Vector3i(7, 4, 4), Color("#E0302A"), "cloth")
	_box(figure, Vector3i(4, 3, 4), Vector3i(4, 3, 4), Color("#E0302A"), "cloth")
	_box(figure, Vector3i(8, 3, 4), Vector3i(8, 3, 4), Color("#E0302A"), "cloth")


## An anonymous OV-chipkaart: blue with a lighter wave and a white field.
static func _build_transit_card(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(15, 9, 0), Color("#1E4EB0"), "plastic")
	for column in 16:
		var wave_level := roundi(3.5 + 1.5 * sin(column * 0.55))
		_box(figure, Vector3i(column, wave_level, 0), Vector3i(column, wave_level, 0), Color("#5A8AE0"), "plastic")
		_box(figure, Vector3i(column, 0, 0), Vector3i(column, wave_level - 1, 0), Color("#2A62C8"), "plastic")
	_box(figure, Vector3i(1, 6, 0), Vector3i(5, 8, 0), Color("#F2F4F8"), "plastic")
	_box(figure, Vector3i(2, 7, 0), Vector3i(4, 7, 0), Color("#1E4EB0"), "plastic")
	_box(figure, Vector3i(12, 7, 0), Vector3i(14, 8, 0), Color("#F2C230"), "plastic")
	_round_card_corners(figure, 15, 9)


## A paper single ticket: off-white, a teal band, lines of print, a QR block and a torn edge.
static func _build_paper_ticket(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(13, 6, 0), Color("#F2EEE2"), "skin")
	_box(figure, Vector3i(0, 6, 0), Vector3i(13, 6, 0), Color("#2A9A9A"), "skin")
	_box(figure, Vector3i(1, 4, 0), Vector3i(7, 4, 0), Color("#4A4A50"), "skin")
	_box(figure, Vector3i(1, 2, 0), Vector3i(5, 2, 0), Color("#4A4A50"), "skin")
	for column in range(9, 13):
		for level in range(1, 5):
			var colour := DARK if _speckle(Vector3i(column, level, 0)) < 50 else WHITE
			_box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), colour, "skin")
	for level in range(0, 7, 2):
		figure.clear(13, level, 0)


## A bank card found on the street: green with a gold chip and contactless waves; on its
## back a magnetic stripe and a white strip with a riddle in blue pen.
static func _build_bank_card(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(15, 9, 1), Color("#1F6E5A"), "plastic")
	_box(figure, Vector3i(2, 4, 0), Vector3i(4, 6, 0), Color("#F2C230"), "metal")
	_box(figure, Vector3i(3, 5, 0), Vector3i(3, 5, 0), Color("#C89A20"), "metal")
	for wave in 3:
		_box(figure, Vector3i(6 + wave, 4, 0), Vector3i(6 + wave, 6, 0), Color("#7ACAB0"), "plastic")
	for column in range(2, 14):
		if column % 4 != 1:
			_box(figure, Vector3i(column, 2, 0), Vector3i(column, 2, 0), Color("#D8DCE2"), "metal")
	_box(figure, Vector3i(10, 7, 0), Vector3i(14, 8, 0), Color("#2E8A72"), "plastic")
	# the back
	_box(figure, Vector3i(0, 6, 1), Vector3i(15, 7, 1), DARK, "plastic")
	_box(figure, Vector3i(1, 2, 1), Vector3i(12, 4, 1), Color("#F4F4F0"), "plastic")
	for column in range(2, 12):
		if _speckle(Vector3i(column, 3, 1)) < 60:
			_box(figure, Vector3i(column, 3, 1), Vector3i(column, 3, 1), Color("#2A4AC8"), "plastic")
	_round_card_corners(figure, 15, 9)



## The slip from the number machine of Burgerzaken: thin white thermal paper, a torn top edge,
## the city's green band, a big black number and a little line of print under it.
static func _build_queue_ticket(figure: PlayerModel.VoxelFigure) -> void:
	var paper := Color("#F6F4EE")
	_box(figure, Vector3i(0, 0, 0), Vector3i(9, 15, 0), paper, "skin")
	# the torn top: every other voxel gone
	for column in range(0, 10, 2):
		figure.clear(column, 15, 0)
	_box(figure, Vector3i(0, 12, 0), Vector3i(9, 13, 0), Color("#2E7D32"), "skin")
	# "B" and two digits, big and black
	for voxel: Vector2i in [Vector2i(1, 9), Vector2i(1, 8), Vector2i(1, 7), Vector2i(1, 6), Vector2i(1, 5),
			Vector2i(2, 9), Vector2i(2, 7), Vector2i(2, 5), Vector2i(3, 8), Vector2i(3, 6),
			Vector2i(5, 9), Vector2i(5, 8), Vector2i(5, 7), Vector2i(6, 9), Vector2i(6, 7), Vector2i(6, 5), Vector2i(5, 6), Vector2i(5, 5),
			Vector2i(8, 9), Vector2i(8, 8), Vector2i(8, 7), Vector2i(8, 6), Vector2i(8, 5)]:
		_box(figure, Vector3i(voxel.x, voxel.y, 0), Vector3i(voxel.x, voxel.y, 0), DARK, "skin")
	for column in range(1, 9):
		if _speckle(Vector3i(column, 2, 0)) < 70:
			_box(figure, Vector3i(column, 2, 0), Vector3i(column, 2, 0), Color("#8A8A86"), "skin")


## A Dutch identity card: light blue-grey, the photo on the left, lines of text, the red-white-
## blue band and the chip; the back plain with the machine-readable lines.
static func _build_id_card(figure: PlayerModel.VoxelFigure) -> void:
	_box(figure, Vector3i(0, 0, 0), Vector3i(15, 9, 1), Color("#C8D4E0"), "plastic")
	# the photo: a grey head and shoulders on a light ground
	_box(figure, Vector3i(1, 1, 0), Vector3i(5, 7, 0), Color("#E8ECF0"), "plastic")
	_box(figure, Vector3i(2, 4, 0), Vector3i(4, 6, 0), Color("#B8A898"), "plastic")
	_box(figure, Vector3i(1, 1, 0), Vector3i(5, 3, 0), Color("#5A6070"), "plastic")
	# the lines of text and the flag band at the top
	for row in [2, 4, 6]:
		_box(figure, Vector3i(7, row, 0), Vector3i(13 if row != 4 else 11, row, 0), Color("#3A4658"), "plastic")
	_box(figure, Vector3i(7, 8, 0), Vector3i(8, 8, 0), Color("#AE1C28"), "plastic")
	_box(figure, Vector3i(9, 8, 0), Vector3i(10, 8, 0), WHITE, "plastic")
	_box(figure, Vector3i(11, 8, 0), Vector3i(12, 8, 0), Color("#21468B"), "plastic")
	_box(figure, Vector3i(13, 6, 0), Vector3i(14, 7, 0), Color("#E0B830"), "metal")
	# the back: two machine-readable lines
	for row in [2, 4]:
		_box(figure, Vector3i(1, row, 1), Vector3i(14, row, 1), Color("#3A4658"), "plastic")
	_round_card_corners(figure, 15, 9)


## The old coat of Ome Wim, as if held up by the shoulders: a long, worn grey-brown coat,
## its sleeves hanging, the collar up, three buttons (one gone), a patch on the elbow and
## the torn red lining showing at the hem.
static func _build_old_coat(figure: PlayerModel.VoxelFigure) -> void:
	var cloth := Color("#4A4438")
	var dark := Color("#2E2A22")
	var patch := Color("#6A5A42")
	var lining := Color("#8A2A2A")
	var button := Color("#1E1A16")
	# the body, wider at the hem, open a little at the front
	_box(figure, Vector3i(3, 0, 0), Vector3i(14, 19, 3), cloth, "cloth")
	_box(figure, Vector3i(2, 0, 0), Vector3i(15, 5, 3), cloth, "cloth")
	_box(figure, Vector3i(8, 0, 0), Vector3i(9, 12, 0), dark, "cloth")
	# the collar up, round the back of the neck
	_box(figure, Vector3i(5, 20, 0), Vector3i(12, 21, 3), dark, "cloth")
	for x in range(7, 11):
		for y in [20, 21]:
			for z in [0, 1]:
				figure.clear(x, y, z)   # the neck opening
	# the sleeves hanging from the shoulders
	for sleeve_x in [0, 15]:
		_box(figure, Vector3i(sleeve_x, 6, 0), Vector3i(sleeve_x + 2, 19, 3), cloth, "cloth")
		_box(figure, Vector3i(sleeve_x, 6, 0), Vector3i(sleeve_x + 2, 7, 3), dark, "cloth")
	_box(figure, Vector3i(15, 12, 0), Vector3i(17, 14, 0), patch, "cloth")
	# buttons down the front (the middle one gone, a thread left) and pockets
	for button_y in [9, 15]:
		_box(figure, Vector3i(10, button_y, 0), Vector3i(10, button_y, 0), button, "plastic")
	_box(figure, Vector3i(10, 12, 0), Vector3i(10, 12, 0), Color("#B9A27A"), "cloth")
	_box(figure, Vector3i(4, 6, 0), Vector3i(6, 7, 0), dark, "cloth")
	_box(figure, Vector3i(11, 6, 0), Vector3i(13, 7, 0), dark, "cloth")
	# the torn lining hanging out under the hem
	_box(figure, Vector3i(4, 0, 0), Vector3i(7, 1, 0), lining, "cloth")
	_box(figure, Vector3i(5, 2, 0), Vector3i(6, 2, 0), lining, "cloth")

# --- shared shapes of the items ------------------------------------------------------------

## A plastic bottle: body, shoulder, neck and cap; water up to `water_level`.
static func _bottle(figure: PlayerModel.VoxelFigure, radius: float, body_top: int, water_level: int,
		water: Color, air: Color, cap: Color) -> void:
	var centre := Vector2(4.0, 4.0)
	for level in range(0, body_top + 1):
		_cylinder_y(figure, centre, radius, level, level, water if level <= water_level else air, "glass")
	_cylinder_y(figure, centre, radius * 0.8, body_top + 1, body_top + 1, air, "glass")
	_cylinder_y(figure, centre, radius * 0.57, body_top + 2, body_top + 2, air, "glass")
	_cylinder_y(figure, centre, 1.2, body_top + 3, body_top + 4, air, "glass")
	_cylinder_y(figure, centre, 1.6, body_top + 5, body_top + 6, cap, "plastic")
	_recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 2 and figure.cells[cell] == water, [water.lightened(0.2)], "glass")


## A can: steel ends, a body in `colour`, a ring on top (`with_ring`).
static func _can(figure: PlayerModel.VoxelFigure, radius: float, body_top: int, colour: Color,
		with_ring := true) -> void:
	var centre := Vector2(3.0, 3.0) if radius < 3.0 else Vector2(3.5, 3.5)
	_cylinder_y(figure, centre, radius - 0.4, 0, 0, STEEL, "metal")
	_cylinder_y(figure, centre, radius, 1, body_top, colour, "metal")
	_cylinder_y(figure, centre, radius - 0.4, body_top + 1, body_top + 1, STEEL, "metal")
	if with_ring:
		var ring_column := floori(centre.x)
		var ring_depth := floori(centre.y) - 1
		_box(figure, Vector3i(ring_column - 1, body_top + 2, ring_depth), Vector3i(ring_column, body_top + 2, ring_depth),
				STEEL_DARK, "metal")


## An empty beer bottle with its label, its corner at (column, depth).
static func _beer_bottle(figure: PlayerModel.VoxelFigure, column: int, depth: int, glass: Color,
		label: Color) -> void:
	var centre := Vector2(column + 2.0, depth + 2.0)
	_cylinder_y(figure, centre, 2.0, 0, 8, glass, "glass")
	_cylinder_y(figure, centre, 1.5, 9, 9, glass, "glass")
	_cylinder_y(figure, centre, 1.0, 10, 13, glass, "glass")
	_cylinder_y(figure, centre, 1.3, 14, 14, glass.lightened(0.15), "glass")
	for label_column in range(column, column + 4):
		for level in range(3, 7):
			if not (level == 3 and (label_column == column or label_column == column + 3)):
				_paint_front(figure, label_column, level, label, "skin")


## A sealed bag of sweets: crimped seams at top and bottom, a band of `accent`, a window on
## its front showing the contents (`contents`: their colours, `fill`: how much of the window
## they cover in percent).
static func _candy_bag(figure: PlayerModel.VoxelFigure, size: Vector3i, bag: Color, accent: Color,
		window: Color, contents: Array, fill: int) -> void:
	var width := size.x
	var height := size.y
	var depth := size.z
	_box(figure, Vector3i(0, 2, 0), Vector3i(width - 1, height - 3, depth - 1), bag, "plastic")
	for level in range(2, height - 2):
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(width - 1, 0), Vector2i(0, depth - 1), Vector2i(width - 1, depth - 1)]:
			figure.clear(corner.x, level, corner.y)
	var middle := floori(depth / 2.0)
	for seam_level in [0, 1, height - 2, height - 1]:
		for column in width:
			var seam_colour := accent if (column + seam_level) % 2 == 0 else bag
			_box(figure, Vector3i(column, seam_level, middle - 1), Vector3i(column, seam_level, middle), seam_colour, "plastic")
	_box(figure, Vector3i(1, height - 5, 0), Vector3i(width - 2, height - 4, 0), accent, "plastic")
	for column in range(2, width - 2):
		for level in range(4, height - 6):
			var block := Vector3i(floori(column / 2.0), floori(level / 2.0), 7)
			var speckle := _speckle(block)
			var colour: Color = contents[speckle % contents.size()] if speckle < fill else window
			_box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), colour, "plastic")


## Clears the four corners of a card (`last_column`, `last_level`: its far edges).
static func _round_card_corners(figure: PlayerModel.VoxelFigure, last_column: int, last_level: int) -> void:
	for depth in range(0, 2):
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(last_column, 0), Vector2i(0, last_level),
				Vector2i(last_column, last_level)]:
			figure.clear(corner.x, corner.y, depth)


## A plain paper bag, folded at the top: the model of an item without one of its own.
static func _fallback_mesh() -> ArrayMesh:
	if not _meshes.has(FALLBACK):
		var figure := PlayerModel.VoxelFigure.new()
		_box(figure, Vector3i(0, 0, 0), Vector3i(9, 11, 6), CARDBOARD, "skin")
		_box(figure, Vector3i(0, 12, 2), Vector3i(9, 13, 4), CARDBOARD.darkened(0.2), "skin")
		_box(figure, Vector3i(3, 5, 0), Vector3i(6, 7, 0), CARDBOARD.darkened(0.35), "skin")
		_meshes[FALLBACK] = _mesh_of(figure, ITEM_VOXEL)
	return _meshes[FALLBACK]


# --- voxel helpers -------------------------------------------------------------------------

static func _box(figure: PlayerModel.VoxelFigure, from: Vector3i, to: Vector3i, colour: Color, kind: String,
		glow := false) -> void:
	figure.box(from, to, colour, glow)
	_mark(figure, kind, colour)


static func _mark(figure: PlayerModel.VoxelFigure, kind: String, colour: Color) -> void:
	figure.mark(kind if kind != "glow" else "plastic", [colour])


static func _clear_box(figure: PlayerModel.VoxelFigure, from: Vector3i, to: Vector3i) -> void:
	for column in range(from.x, to.x + 1):
		for level in range(from.y, to.y + 1):
			for depth in range(from.z, to.z + 1):
				figure.clear(column, level, depth)


## An upright cylinder: the cells whose middle lies within `radius` of `centre` (x, z).
static func _cylinder_y(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_level: int,
		to_level: int, colour: Color, kind: String) -> void:
	for column in range(floori(centre.x - radius) - 1, ceili(centre.x + radius) + 1):
		for depth in range(floori(centre.y - radius) - 1, ceili(centre.y + radius) + 1):
			if Vector2(column + 0.5, depth + 0.5).distance_to(centre) <= radius:
				figure.box(Vector3i(column, from_level, depth), Vector3i(column, to_level, depth), colour)
	_mark(figure, kind, colour)


static func _clear_cylinder_y(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_level: int,
		to_level: int) -> void:
	for column in range(floori(centre.x - radius) - 1, ceili(centre.x + radius) + 1):
		for depth in range(floori(centre.y - radius) - 1, ceili(centre.y + radius) + 1):
			if Vector2(column + 0.5, depth + 0.5).distance_to(centre) <= radius:
				for level in range(from_level, to_level + 1):
					figure.clear(column, level, depth)


## A lying cylinder along x: `centre` is (y, z).
static func _cylinder_x(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_column: int,
		to_column: int, colour: Color, kind: String) -> void:
	for level in range(floori(centre.x - radius) - 1, ceili(centre.x + radius) + 1):
		for depth in range(floori(centre.y - radius) - 1, ceili(centre.y + radius) + 1):
			if Vector2(level + 0.5, depth + 0.5).distance_to(centre) <= radius:
				figure.box(Vector3i(from_column, level, depth), Vector3i(to_column, level, depth), colour)
	_mark(figure, kind, colour)


## A disc facing the front (along z): `centre` is (x, y).
static func _cylinder_z(figure: PlayerModel.VoxelFigure, centre: Vector2, radius: float, from_depth: int,
		to_depth: int, colour: Color, kind: String) -> void:
	for column in range(floori(centre.x - radius) - 1, ceili(centre.x + radius) + 1):
		for level in range(floori(centre.y - radius) - 1, ceili(centre.y + radius) + 1):
			if Vector2(column + 0.5, level + 0.5).distance_to(centre) <= radius:
				figure.box(Vector3i(column, level, from_depth), Vector3i(column, level, to_depth), colour)
	_mark(figure, kind, colour)


## An ellipsoid: the cells whose middle lies within it, none below `lowest_level`.
static func _ellipsoid(figure: PlayerModel.VoxelFigure, centre: Vector3, radii: Vector3, colour: Color,
		kind: String, lowest_level := -1000) -> void:
	for column in range(floori(centre.x - radii.x) - 1, ceili(centre.x + radii.x) + 1):
		for level in range(maxi(floori(centre.y - radii.y) - 1, lowest_level), ceili(centre.y + radii.y) + 1):
			for depth in range(floori(centre.z - radii.z) - 1, ceili(centre.z + radii.z) + 1):
				var offset := (Vector3(column, level, depth) + Vector3(0.5, 0.5, 0.5) - centre) / radii
				if offset.length_squared() <= 1.0:
					figure.put(column, level, depth, colour)
	_mark(figure, kind, colour)


## Gives the cells for which `test` holds one of `colours` (a scattering, by _speckle).
static func _recolour_where(figure: PlayerModel.VoxelFigure, test: Callable, colours: Array, kind: String) -> void:
	for cell: Vector3i in figure.cells.keys():
		if test.call(cell):
			figure.cells[cell] = colours[_speckle(cell + Vector3i(3, 5, 7)) % colours.size()]
	for colour: Color in colours:
		_mark(figure, kind, colour)


## The frontmost cell (lowest z) at (column, level) in `colour`; nothing when there is none.
static func _paint_front(figure: PlayerModel.VoxelFigure, column: int, level: int, colour: Color, kind: String,
		glow := false) -> void:
	for depth in range(-8, 40):
		if figure.has(column, level, depth):
			figure.put(column, level, depth, colour, glow)
			_mark(figure, kind, colour)
			return


## The backmost cell (highest z) at (column, level) in `colour`.
static func _paint_back(figure: PlayerModel.VoxelFigure, column: int, level: int, colour: Color, kind: String) -> void:
	for depth in range(40, -8, -1):
		if figure.has(column, level, depth):
			figure.put(column, level, depth, colour)
			_mark(figure, kind, colour)
			return


## The topmost cell at (column, depth) in `colour`.
static func _paint_top(figure: PlayerModel.VoxelFigure, column: int, depth: int, colour: Color, kind: String) -> void:
	for level in range(40, -8, -1):
		if figure.has(column, level, depth):
			figure.put(column, level, depth, colour, figure.glowing.has(Vector3i(column, level, depth)))
			_mark(figure, kind, colour)
			return


## A stable number 0..99 for a cell: where the speckles, crumbs and currants go.
static func _speckle(cell: Vector3i) -> int:
	var mixed := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)
	return absi(mixed) % 100


static func _mesh_of(figure: PlayerModel.VoxelFigure, voxel: float) -> ArrayMesh:
	var materials := {}
	for kind: String in PlayerModel.CLOTH.keys() + PlayerModel.MATERIALS.keys() + ["glow"]:
		materials[kind] = PlayerModel.material_for(kind)
	var parts: Dictionary = figure.to_parts(voxel, {}, materials, PlayerModel.graded)
	return parts.meshes.body
