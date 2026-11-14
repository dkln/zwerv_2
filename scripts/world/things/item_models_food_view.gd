extends RefCounted
## The voxel models of the food and drink among the items (graphics; docs/CODE_LAGEN.md):
## one builder per item, painted into a figure with the voxel brush (voxel_brush_view.gd),
## the shapes several share from item_models_shapes_view.gd, the colours several share from
## item_models_look.gd. item_models.gd asks build() for an item and makes its mesh.
##   const ItemModelsFood = preload("res://scripts/world/things/item_models_food_view.gd")
##   ItemModelsFood.build("kroket", figure)   # true: the kroket is in the figure

const PlayerModel = preload("res://scripts/player/player_model.gd")
const VoxelBrush = preload("res://scripts/world/things/voxel_brush_view.gd")
const VoxelBrushLayout = preload("res://scripts/world/things/voxel_brush_layout.gd")
const ItemShapes = preload("res://scripts/world/things/item_models_shapes_view.gd")
const ItemLook = preload("res://scripts/world/things/item_models_look.gd")


## Builds the model of `item_id` into `figure`; false when it is not one of the food and drink.
static func build(item_id: String, figure: PlayerModel.VoxelFigure) -> bool:
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
		"koffie": _build_coffee(figure)
		"cappuccino": _build_cappuccino(figure)
		"gevulde_koek": _build_filled_cookie(figure)
		"broodje_kaas": _build_cheese_roll(figure)
		"broodje_kroket": _build_kroket_roll(figure)
		"krentenbol": _build_currant_bun(figure)
		"mineraalwater": _build_mineral_water(figure)
		"kauwgom": _build_chewing_gum(figure)
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
		"blikje": _build_empty_can(figure)
		_:
			return false
	return true


## The ids of the items this script has a model of.
static func item_ids() -> Array[String]:
	return ["brood", "frikandel", "kroket", "patat", "appel", "vis", "water", "energiedrank", "jenever", "bier", "koffie", "cappuccino", "gevulde_koek", "broodje_kaas", "broodje_kroket", "krentenbol", "mineraalwater", "kauwgom", "stroopwafel", "pak_stroopwafels", "drop", "winegums", "chocoladereep", "crackers", "ontbijtkoek", "zak_chips", "blik_soep", "pak_melk", "ijsje", "vers_brood", "croissant", "banaan", "blikje"]


## A see-through bag of old crusts, tied at the top with a red tie.
static func _build_bag_of_crusts(figure: PlayerModel.VoxelFigure) -> void:
	var bag := Color("#DCE2E6")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(11, 13, 7), bag, "plastic")
	for level in 14:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(11, 0), Vector2i(0, 7), Vector2i(11, 7)]:
			figure.clear(corner.x, level, corner.y)
	# the crusts against the plastic
	var crust_tones := [ItemLook.CRUST, Color("#8E4E1E"), Color("#D49A58")]
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == bag and cell.y <= 10 and VoxelBrushLayout.speckle(cell) < 45,
		crust_tones, "skin")
	VoxelBrush.box(figure, Vector3i(4, 14, 3), Vector3i(7, 15, 4), bag, "plastic")
	VoxelBrush.box(figure, Vector3i(3, 14, 2), Vector3i(8, 14, 5), Color("#D23A2A"), "plastic")
	VoxelBrush.box(figure, Vector3i(3, 16, 2), Vector3i(8, 17, 5), bag, "plastic")
	figure.clear(3, 17, 2)
	figure.clear(8, 17, 5)


## A long dark frikandel on a paper napkin, a bite out of one end.
static func _build_frikandel(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(21, 0, 8), ItemLook.PAPER, "skin")
	var sausage := Color("#7A3B22")
	VoxelBrush.cylinder_x(figure, Vector2(3.0, 4.5), 2.1, 1, 20, sausage, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == sausage and VoxelBrushLayout.speckle(cell) < 35,
		[Color("#5E2B18"), Color("#8C4A2C")], "skin")
	for level in range(1, 6):
		for depth in range(2, 8):
			if absf(level - 2.5) > 1.0 or absf(depth - 4.0) > 1.0:
				figure.clear(1, level, depth)
				figure.clear(20, level, depth)
	VoxelBrush.clear_box(figure, Vector3i(18, 3, 0), Vector3i(20, 5, 8))
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x == 17 and cell.y >= 1, [Color("#A86448")], "skin")


## A kroket: a fat cylinder with round ends in crisp crust tones, the ragout showing at the
## broken end.
static func _build_kroket(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.cylinder_x(figure, Vector2(3.5, 3.5), 3.5, 2, 13, ItemLook.CRUST, "skin")
	VoxelBrush.cylinder_x(figure, Vector2(3.5, 3.5), 2.6, 1, 1, ItemLook.CRUST, "skin")
	VoxelBrush.cylinder_x(figure, Vector2(3.5, 3.5), 2.6, 14, 14, ItemLook.CRUST, "skin")
	VoxelBrush.cylinder_x(figure, Vector2(3.5, 3.5), 1.5, 0, 0, ItemLook.CRUST, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == ItemLook.CRUST and VoxelBrushLayout.speckle(cell) < 60,
		[Color("#C9823A"), Color("#9A5220"), Color("#D89A4A"), Color("#8A4818")], "skin")
	VoxelBrush.box(figure, Vector3i(14, 2, 2), Vector3i(14, 4, 4), Color("#E2BE84"), "skin")
	VoxelBrush.box(figure, Vector3i(14, 3, 3), Vector3i(14, 3, 3), Color("#F0D4A0"), "skin")


## A paper cone with a red band, chips sticking out, a dollop of mayo and a little fork.
static func _build_patat(figure: PlayerModel.VoxelFigure) -> void:
	var cone := Color("#F4F0E4")
	var band := Color("#D23A2A")
	for level in 13:
		VoxelBrush.cylinder_y(figure, Vector2(6.0, 6.0), 1.4 + level * 0.33, level, level, cone, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 8 and cell.y <= 9, [band], "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y <= 6 and (cell.x + cell.y) % 4 == 0, [band], "skin")
	var chip := Color("#F2C14E")
	var chip_tip := Color("#D89A30")
	for column in range(2, 10):
		for depth in range(2, 10):
			if Vector2(column + 0.5 - 6.0, depth + 0.5 - 6.0).length() > 4.0:
				continue
			var speckle := VoxelBrushLayout.speckle(Vector3i(column, 0, depth))
			if speckle < 25:
				continue
			var top := 13 + speckle % 5
			VoxelBrush.box(figure, Vector3i(column, 12, depth), Vector3i(column, top - 1, depth), chip, "skin")
			VoxelBrush.box(figure, Vector3i(column, top, depth), Vector3i(column, top, depth), chip_tip, "skin")
	VoxelBrush.ellipsoid(figure, Vector3(5.5, 16.0, 4.5), Vector3(2.6, 1.8, 2.3), Color("#FFF4C8"), "plastic")
	VoxelBrush.box(figure, Vector3i(8, 14, 6), Vector3i(8, 19, 6), Color("#E0302A"), "plastic")
	VoxelBrush.box(figure, Vector3i(8, 19, 5), Vector3i(8, 19, 7), Color("#E0302A"), "plastic")


## A red apple with a yellow blush, a bruise on its front, a stem and a leaf.
static func _build_apple(figure: PlayerModel.VoxelFigure) -> void:
	var red := Color("#C8242C")
	VoxelBrush.ellipsoid(figure, Vector3(7.0, 6.5, 7.0), Vector3(7.0, 6.5, 7.0), red, "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x >= 9 and cell.y >= 5 and VoxelBrushLayout.speckle(cell) < 55,
		[Color("#E8A030"), Color("#D86A2A")], "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == red and VoxelBrushLayout.speckle(cell) < 20, [Color("#A81820")], "plastic")
	for column in range(3, 7):
		for level in range(3, 7):
			VoxelBrush.paint_front(figure, column, level, Color("#6A2A1A"), "skin")
	VoxelBrush.clear_box(figure, Vector3i(6, 12, 6), Vector3i(7, 12, 7))
	VoxelBrush.box(figure, Vector3i(7, 11, 7), Vector3i(7, 15, 7), Color("#5A3A1A"), "skin")
	VoxelBrush.box(figure, Vector3i(8, 14, 7), Vector3i(10, 14, 8), ItemLook.LEAF_GREEN, "plastic")
	VoxelBrush.box(figure, Vector3i(9, 15, 8), Vector3i(10, 15, 8), ItemLook.LEAF_GREEN, "plastic")


## A fish seen from its side: a dark back, silver flanks, a white belly, fins and an eye.
static func _build_fish(figure: PlayerModel.VoxelFigure) -> void:
	var silver := Color("#A8B4BC")
	var back := Color("#5C6A78")
	var belly := Color("#E4E8EA")
	VoxelBrush.ellipsoid(figure, Vector3(9.0, 5.0, 2.0), Vector3(9.0, 4.5, 2.0), silver, "metal")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y >= 7, [back], "metal")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y <= 2, [belly], "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 3 and cell.y <= 6 and VoxelBrushLayout.speckle(cell) < 20, [Color("#C8D2D8")], "metal")
	for tail_column in range(17, 22):
		var spread := tail_column - 16
		VoxelBrush.box(figure, Vector3i(tail_column, 5 - spread, 1), Vector3i(tail_column, 5 + spread, 2), back, "metal")
	VoxelBrush.box(figure, Vector3i(7, 10, 1), Vector3i(12, 10, 2), back, "metal")
	VoxelBrush.box(figure, Vector3i(8, 11, 1), Vector3i(10, 11, 2), back, "metal")
	VoxelBrush.box(figure, Vector3i(9, 0, 1), Vector3i(11, 0, 2), back, "metal")
	for level in range(3, 8):
		VoxelBrush.paint_front(figure, 5, level, Color("#7A8894"), "metal")
		VoxelBrush.paint_back(figure, 5, level, Color("#7A8894"), "metal")
	VoxelBrush.paint_front(figure, 2, 6, Color("#F4F4F0"), "eye")
	VoxelBrush.paint_back(figure, 2, 6, Color("#F4F4F0"), "eye")
	VoxelBrush.paint_front(figure, 2, 5, ItemLook.DARK, "eye")
	VoxelBrush.paint_back(figure, 2, 5, ItemLook.DARK, "eye")
	VoxelBrush.paint_front(figure, 0, 4, Color("#C86A6A"), "plastic")


## A bottle of tap water, refilled: no cap's seal, a torn bit of label.
static func _build_tap_water(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.bottle(figure, 3.5, 13, 8, ItemLook.GLASS_WATER, Color("#C8E6F2"), Color("#2E6FD0"))
	for column in range(1, 4):
		for level in range(5, 8):
			if column + level != 9:
				VoxelBrush.paint_front(figure, column, level, Color("#E8E8E0"), "plastic")


## A small bottle of spring water from the kiosk: full, a blue label with a white wave.
static func _build_mineral_water(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.bottle(figure, 3.0, 10, 13, Color("#7FC0E4"), Color("#C8E6F2"), Color("#1C4FA0"))
	var label := Color("#2F7FD8")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 4 and cell.y <= 8, [label], "plastic")
	for column in range(0, 8):
		VoxelBrush.paint_front(figure, column, 6 + int(column % 3 == 1), Color("#F4F8FC"), "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == Color("#7FC0E4") and VoxelBrushLayout.speckle(cell) < 12, [Color("#E4F4FC")], "glass")


## A tall slim energy can: dark with a green lightning bolt that glows.
static func _build_energy_drink(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.can(figure, 2.6, 17, Color("#1C1C2A"))
	var green := Color("#8CFF3A")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 15 or cell.y == 3, [green], "plastic")
	var bolt := [Vector2i(4, 13), Vector2i(3, 13), Vector2i(3, 12), Vector2i(3, 11), Vector2i(2, 11),
			Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10), Vector2i(3, 9), Vector2i(3, 8),
			Vector2i(2, 7), Vector2i(2, 6), Vector2i(1, 5)]
	for point: Vector2i in bolt:
		VoxelBrush.paint_front(figure, point.x, point.y, green, "glow", true)


## A can of beer: gold, a white label with a red stripe and green leaves of hops.
static func _build_beer(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.can(figure, 3.2, 11, Color("#D8A63A"))
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 5 and cell.y <= 8, [Color("#F2EEE2")], "plastic")
	for column in range(1, 6):
		VoxelBrush.paint_front(figure, column, 7, Color("#C8242C"), "plastic")
	VoxelBrush.paint_front(figure, 3, 5, ItemLook.LEAF_GREEN, "plastic")
	VoxelBrush.paint_front(figure, 2, 6, ItemLook.LEAF_GREEN, "plastic")
	VoxelBrush.paint_front(figure, 4, 6, ItemLook.LEAF_GREEN, "plastic")


## An empty can out of a bin: red with a white wave, dented, no ring.
static func _build_empty_can(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.can(figure, 2.6, 10, Color("#C8242C"), false)
	for column in range(0, 6):
		VoxelBrush.paint_front(figure, column, 5 + int(column % 4 >= 2), Color("#F4F4F0"), "plastic")
	# the dents
	for cell: Vector3i in [Vector3i(5, 7, 2), Vector3i(5, 7, 3), Vector3i(5, 8, 2), Vector3i(0, 3, 3),
			Vector3i(1, 3, 0), Vector3i(2, 9, 0)]:
		figure.clear(cell.x, cell.y, cell.z)
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == Color("#C8242C") and VoxelBrushLayout.speckle(cell) < 18, [Color("#8A1A1E")], "metal")


## A stone kruik of jenever: brown below, cream above, a cork, an ear and a label.
static func _build_jenever(figure: PlayerModel.VoxelFigure) -> void:
	var lower := Color("#8A5A30")
	var upper := Color("#C8A060")
	var centre := Vector2(5.0, 5.0)
	VoxelBrush.cylinder_y(figure, centre, 4.5, 0, 4, lower, "leather")
	VoxelBrush.cylinder_y(figure, centre, 4.5, 5, 9, upper, "leather")
	VoxelBrush.cylinder_y(figure, centre, 3.8, 10, 10, upper, "leather")
	VoxelBrush.cylinder_y(figure, centre, 3.0, 11, 11, upper, "leather")
	VoxelBrush.cylinder_y(figure, centre, 2.0, 12, 12, upper, "leather")
	VoxelBrush.cylinder_y(figure, centre, 1.2, 13, 14, upper, "leather")
	VoxelBrush.cylinder_y(figure, centre, 1.6, 15, 15, upper, "leather")
	VoxelBrush.cylinder_y(figure, centre, 1.0, 16, 17, Color("#B08A5A"), "skin")
	# the ear
	VoxelBrush.box(figure, Vector3i(6, 13, 4), Vector3i(10, 13, 5), upper, "leather")
	VoxelBrush.box(figure, Vector3i(10, 9, 4), Vector3i(10, 12, 5), upper, "leather")
	VoxelBrush.box(figure, Vector3i(9, 9, 4), Vector3i(9, 9, 5), upper, "leather")
	# the label
	for column in range(3, 7):
		for level in range(5, 9):
			VoxelBrush.paint_front(figure, column, level, Color("#EDE4CC"), "skin")
	for column in range(4, 6):
		VoxelBrush.paint_front(figure, column, 7, Color("#3A2A1A"), "skin")
		VoxelBrush.paint_front(figure, column, 6, Color("#3A2A1A"), "skin")


## A paper coffee cup with a cardboard sleeve, black coffee inside and a wisp of steam.
static func _build_coffee(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(4.0, 4.0)
	for level in 12:
		var cup_colour := Color("#A8743E") if level >= 4 and level <= 7 else ItemLook.WHITE
		VoxelBrush.cylinder_y(figure, centre, 2.6 + level * 0.09, level, level, cup_colour, "skin")
	var top_radius := 2.6 + 11 * 0.09
	VoxelBrush.clear_cylinder_y(figure, centre, top_radius - 1.0, 11, 11)
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 10 and Vector2(cell.x + 0.5, cell.z + 0.5).distance_to(centre) <= top_radius - 1.0,
		[Color("#2A1810")], "glass")
	for point: Vector3i in [Vector3i(4, 13, 4), Vector3i(3, 14, 4), Vector3i(3, 15, 4), Vector3i(4, 16, 4),
			Vector3i(5, 17, 4)]:
		VoxelBrush.box(figure, point, point, Color("#E4EAEE"), "plastic")


## A cappuccino in a white cup on a saucer: a dome of foam with cacao and a spoon.
static func _build_cappuccino(figure: PlayerModel.VoxelFigure) -> void:
	var porcelain := Color("#F4F2EE")
	var centre := Vector2(6.0, 6.0)
	VoxelBrush.cylinder_y(figure, centre, 5.8, 0, 0, porcelain, "plastic")
	VoxelBrush.cylinder_y(figure, centre, 5.8, 1, 1, porcelain, "plastic")
	VoxelBrush.clear_cylinder_y(figure, centre, 4.6, 1, 1)
	for level in range(1, 8):
		VoxelBrush.cylinder_y(figure, centre, 3.0 + (level - 1) * 0.15, level, level, porcelain, "plastic")
	var foam := Color("#F0E2C4")
	VoxelBrush.cylinder_y(figure, centre, 2.9, 7, 7, foam, "cloth")
	VoxelBrush.cylinder_y(figure, centre, 2.0, 8, 8, foam, "cloth")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == foam and VoxelBrushLayout.speckle(cell) < 30, [Color("#6A3A1A")], "cloth")
	# the handle
	VoxelBrush.box(figure, Vector3i(10, 3, 6), Vector3i(11, 3, 6), porcelain, "plastic")
	VoxelBrush.box(figure, Vector3i(11, 4, 6), Vector3i(11, 5, 6), porcelain, "plastic")
	VoxelBrush.box(figure, Vector3i(10, 6, 6), Vector3i(11, 6, 6), porcelain, "plastic")
	# the spoon on the saucer
	VoxelBrush.box(figure, Vector3i(7, 2, 1), Vector3i(10, 2, 1), ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(5, 2, 1), Vector3i(6, 2, 2), ItemLook.STEEL, "metal")


## A round gevulde koek, upright: glazed, half an almond on top, a bite showing the spijs.
static func _build_filled_cookie(figure: PlayerModel.VoxelFigure) -> void:
	var cookie := Color("#D89A48")
	var centre := Vector2(7.0, 7.0)
	VoxelBrush.cylinder_z(figure, centre, 7.0, 0, 2, cookie, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(centre) > 6.0, [Color("#B87830")], "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == cookie and cell.z == 0, [Color("#E2A452")], "leather")
	var bite := Vector2(12.5, 12.0)
	for cell: Vector3i in figure.cells.keys():
		if Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(bite) < 3.2:
			figure.clear(cell.x, cell.y, cell.z)
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.z == 1 and Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(bite) < 4.4,
		[Color("#E8D49A")], "skin")
	VoxelBrush.ellipsoid(figure, Vector3(6.5, 6.5, -0.2), Vector3(2.4, 1.5, 1.0), Color("#F0DCB0"), "skin")


## A white roll cut open with a slice of young cheese, its corners sticking out.
static func _build_cheese_roll(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(7.0, 7.0)
	VoxelBrush.cylinder_y(figure, centre, 6.0, 0, 0, Color("#C8964E"), "skin")
	VoxelBrush.cylinder_y(figure, centre, 6.5, 1, 2, Color("#E2BC80"), "skin")
	VoxelBrush.box(figure, Vector3i(2, 3, 2), Vector3i(11, 3, 11), Color("#F2C84A"), "skin")
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(12, 1), Vector2i(1, 12), Vector2i(12, 12)]:
		VoxelBrush.box(figure, Vector3i(corner.x, 2, corner.y), Vector3i(corner.x, 2, corner.y), Color("#F2C84A"), "skin")
	var top := Color("#D8A860")
	VoxelBrush.ellipsoid(figure, Vector3(7.0, 3.5, 7.0), Vector3(6.6, 5.0, 6.6), top, "skin", 4)
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == top and cell.y >= 7, [Color("#C8904A")], "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 5 and VoxelBrushLayout.speckle(cell) < 10 and figure.cells[cell] != Color("#F2C84A"),
		[Color("#F4EEE0")], "skin")


## A soft roll with a kroket sticking out at both ends and mustard on it.
static func _build_kroket_roll(figure: PlayerModel.VoxelFigure) -> void:
	var bun := Color("#F0D8A8")
	VoxelBrush.ellipsoid(figure, Vector3(8.0, 3.0, 6.0), Vector3(6.0, 3.0, 5.5), Color("#E4C48C"), "skin")
	VoxelBrush.clear_box(figure, Vector3i(0, 3, 0), Vector3i(16, 8, 12))
	VoxelBrush.cylinder_x(figure, Vector2(3.5, 6.0), 2.2, 0, 15, ItemLook.CRUST, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == ItemLook.CRUST and VoxelBrushLayout.speckle(cell) < 50, [Color("#C9823A"), Color("#9A5220")], "skin")
	VoxelBrush.ellipsoid(figure, Vector3(8.0, 3.5, 6.0), Vector3(6.0, 5.0, 5.5), bun, "skin", 4)
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == bun and VoxelBrushLayout.speckle(cell) < 22, [Color("#FBF4E6")], "skin")
	var mustard := Color("#E0B020")
	for column in [0, 1, 2, 13, 14, 15]:
		for depth in range(5, 7):
			VoxelBrush.paint_top(figure, column, depth, mustard, "plastic")
	for column in range(4, 12):
		if column % 3 != 0:
			VoxelBrush.paint_front(figure, column, 3, mustard, "plastic")


## A round currant bun, shiny brown, full of dark currants.
static func _build_currant_bun(figure: PlayerModel.VoxelFigure) -> void:
	var bun := Color("#B8702E")
	VoxelBrush.ellipsoid(figure, Vector3(7.0, 0.0, 7.0), Vector3(7.0, 7.5, 7.0), bun, "leather", 0)
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 0, [Color("#D8A060")], "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == bun and VoxelBrushLayout.speckle(cell) < 22,
		[Color("#3A1A1A"), Color("#2A1010"), Color("#C8902E")], "leather")


## A whole wholemeal loaf, fresh: dark crust, light score cuts and oats on top.
static func _build_fresh_loaf(figure: PlayerModel.VoxelFigure) -> void:
	var crust := Color("#8A5428")
	VoxelBrush.ellipsoid(figure, Vector3(10.0, 0.0, 6.0), Vector3(10.0, 7.0, 6.0), crust, "skin", 0)
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 0, [Color("#B07A44")], "skin")
	for column in range(0, 20):
		for depth in range(0, 12):
			if (column + floori(depth / 2.0)) % 5 == 0 and column > 2 and column < 18:
				VoxelBrush.paint_top(figure, column, depth, Color("#C89A60"), "skin")
			elif VoxelBrushLayout.speckle(Vector3i(column, 1, depth)) < 10:
				VoxelBrush.paint_top(figure, column, depth, Color("#E8D8B0"), "skin")


## A loaf of ontbijtkoek: shiny dark top, cut open at one end.
static func _build_spice_cake(figure: PlayerModel.VoxelFigure) -> void:
	var side := Color("#8A4A20")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(17, 6, 7), side, "skin")
	VoxelBrush.box(figure, Vector3i(0, 7, 1), Vector3i(17, 7, 6), Color("#6A3414"), "leather")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 6, [Color("#6A3414")], "leather")
	var crumb := Color("#B8743A")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x == 17 and cell.y >= 1 and cell.y <= 5 and cell.z >= 1 and cell.z <= 6,
		[crumb, crumb, Color("#A86430")], "skin")
	# a slice, cut off and leaning against it
	VoxelBrush.box(figure, Vector3i(19, 0, 1), Vector3i(19, 5, 6), crumb, "skin")
	VoxelBrush.box(figure, Vector3i(19, 6, 2), Vector3i(19, 6, 5), Color("#6A3414"), "leather")


## A croissant: a crescent of puffed segments, light and dark golden layers.
static func _build_croissant(figure: PlayerModel.VoxelFigure) -> void:
	var tones := [Color("#D8902E"), Color("#EAB050")]
	var segments := 9
	for segment in segments:
		var angle := deg_to_rad(-72.0 + 144.0 * segment / (segments - 1))
		var from_middle := absf(segment - (segments - 1) / 2.0) / ((segments - 1) / 2.0)
		var radius := 3.8 * (1.0 - 0.55 * from_middle)
		var at := Vector3(11.5 + 9.0 * sin(angle), radius * 0.85, 1.0 + 9.0 * cos(angle))
		VoxelBrush.ellipsoid(figure, at, Vector3(radius, radius * 0.85, radius), tones[segment % 2], "leather")


## A banana, curved like a smile: yellow with brown spots and brown tips.
static func _build_banana(figure: PlayerModel.VoxelFigure) -> void:
	var yellow := Color("#F2D040")
	for step in 31:
		var angle := deg_to_rad(208.0 + step * 4.0)
		var from_middle := absf(step - 15.0) / 15.0
		var radius := 2.4 * (1.0 - 0.55 * from_middle * from_middle)
		var at := Vector3(11.5 + 11.0 * cos(angle), 14.0 + 11.0 * sin(angle), 3.0)
		VoxelBrush.ellipsoid(figure, at, Vector3(radius, radius, radius), yellow, "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == yellow and VoxelBrushLayout.speckle(cell) < 9, [Color("#6A4A1A")], "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == yellow and cell.y > 6 and cell.y <= 7 and VoxelBrushLayout.speckle(cell) < 50,
		[Color("#C8D040")], "plastic")
	var stem := Color("#6A5A2A")
	VoxelBrush.box(figure, Vector3i(21, 8, 3), Vector3i(22, 9, 3), stem, "skin")
	VoxelBrush.box(figure, Vector3i(22, 10, 3), Vector3i(22, 10, 3), stem, "skin")
	VoxelBrush.box(figure, Vector3i(1, 8, 3), Vector3i(1, 8, 3), Color("#3A2A12"), "skin")


## A stroopwafel, upright: two thin waffles with a diamond grid, syrup between them.
static func _build_stroopwafel(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(7.0, 7.0)
	VoxelBrush.cylinder_z(figure, centre, 7.0, 0, 2, ItemLook.WAFFLE, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.z == 1, [ItemLook.SYRUP], "leather")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.z != 1 and ((cell.x + cell.y) % 3 == 0 or (cell.x - cell.y + 30) % 3 == 0),
		[ItemLook.WAFFLE_GROOVE], "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.z != 1 and Vector2(cell.x + 0.5, cell.y + 0.5).distance_to(centre) > 6.2,
		[Color("#C08840")], "skin")
	VoxelBrush.box(figure, Vector3i(10, 3, -1), Vector3i(10, 5, -1), ItemLook.SYRUP, "leather")
	VoxelBrush.box(figure, Vector3i(10, 2, 0), Vector3i(10, 2, 0), ItemLook.SYRUP, "leather")


## A pack of stroopwafels: a stack of waffles with syrup lines and a red label.
static func _build_stroopwafel_pack(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(6.5, 6.5)
	for level in 12:
		VoxelBrush.cylinder_y(figure, centre, 6.3, level, level, ItemLook.WAFFLE if level % 2 == 0 else ItemLook.SYRUP,
				"skin" if level % 2 == 0 else "leather")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 11 and ((cell.x + cell.z) % 3 == 0 or (cell.x - cell.z + 30) % 3 == 0),
		[ItemLook.WAFFLE_GROOVE], "skin")
	VoxelBrush.cylinder_y(figure, centre, 6.3, 11, 11, ItemLook.WAFFLE, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == 11 and ((cell.x + cell.z) % 3 == 0 or (cell.x - cell.z + 30) % 3 == 0),
		[ItemLook.WAFFLE_GROOVE], "skin")
	var label := Color("#C8242C")
	for column in range(3, 10):
		for level in range(3, 9):
			VoxelBrush.paint_front(figure, column, level, label, "plastic")
	for column in range(4, 9):
		VoxelBrush.paint_front(figure, column, 6, Color("#F2C230"), "plastic")
	VoxelBrush.paint_front(figure, 6, 4, Color("#F2C230"), "plastic")


## A chocolate bar, upright: a red wrapper with a gold band, torn open, a bite out of it.
static func _build_chocolate_bar(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(9, 11, 1), Color("#B0242C"), "plastic")
	VoxelBrush.box(figure, Vector3i(0, 5, 0), Vector3i(9, 6, 0), Color("#E0B040"), "metal")
	VoxelBrush.box(figure, Vector3i(0, 12, 0), Vector3i(9, 12, 1), Color("#C8CCD2"), "metal")
	var chocolate := Color("#5A3218")
	VoxelBrush.box(figure, Vector3i(0, 13, 0), Vector3i(9, 17, 1), chocolate, "leather")
	var groove := Color("#3E200E")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 13 and cell.z == 0 and (cell.x == 3 or cell.x == 6 or cell.y == 15),
		[groove], "leather")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == chocolate and VoxelBrushLayout.speckle(cell) < 12, [Color("#A8703A")], "skin")
	VoxelBrush.clear_box(figure, Vector3i(7, 17, 0), Vector3i(9, 17, 1))
	VoxelBrush.clear_box(figure, Vector3i(8, 16, 0), Vector3i(9, 16, 1))
	figure.clear(0, 12, 0)
	figure.clear(4, 12, 0)


## A stack of square crackers with holes, half in a blue paper sleeve.
static func _build_crackers(figure: PlayerModel.VoxelFigure) -> void:
	var cracker := Color("#E8C27A")
	var shifts := [0, 1, 0, -1, 0, 1, 0]
	for layer in shifts.size():
		var shift: int = shifts[layer]
		VoxelBrush.box(figure, Vector3i(1 + shift, layer, 1), Vector3i(10 + shift, layer, 10), cracker, "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y == shifts.size() - 1 and posmod(cell.x, 3) == 1 and cell.z % 3 == 1,
		[Color("#B88A40")], "skin")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y < shifts.size() - 1 and figure.cells[cell] == cracker and VoxelBrushLayout.speckle(cell) < 40,
		[Color("#D4A860")], "skin")
	var sleeve := Color("#3A6AC0")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(11, 3, 0), sleeve, "plastic")
	VoxelBrush.box(figure, Vector3i(0, 0, 11), Vector3i(11, 3, 11), sleeve, "plastic")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(0, 3, 11), sleeve, "plastic")
	VoxelBrush.box(figure, Vector3i(11, 0, 0), Vector3i(11, 3, 11), sleeve, "plastic")
	VoxelBrush.box(figure, Vector3i(3, 1, 0), Vector3i(8, 2, 0), Color("#F2F0EA"), "plastic")
	VoxelBrush.box(figure, Vector3i(4, 1, 0), Vector3i(4, 2, 0), Color("#E8C27A"), "plastic")


## A bag of salty liquorice: black, a window full of black drops, white seals.
static func _build_liquorice_bag(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.candy_bag(figure, Vector3i(12, 17, 5), Color("#222226"), Color("#E8E8E8"), Color("#D8D8DC"),
			[Color("#101010"), Color("#2E2E30"), Color("#4A4A4E")], 82)


## A bag of winegums: pink, a window of red, green, yellow, orange and black gums.
static func _build_winegum_bag(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.candy_bag(figure, Vector3i(12, 17, 5), Color("#E84A8A"), Color("#F2C230"), Color("#F4F0F4"),
			[Color("#D8242C"), Color("#3AA83A"), Color("#F2C230"), Color("#F07A20"), Color("#1A1A1A")], 72)


## The big bag of crisps: yellow, puffed out, chips on its front.
static func _build_crisps_bag(figure: PlayerModel.VoxelFigure) -> void:
	var bag := Color("#F2C230")
	ItemShapes.candy_bag(figure, Vector3i(14, 20, 6), bag, Color("#D23A2A"), bag,
			[Color("#F2D88A"), Color("#E8B850"), Color("#F8E4A8")], 45)
	VoxelBrush.box(figure, Vector3i(2, 4, -1), Vector3i(11, 13, -1), bag, "plastic")
	for cell: Vector3i in figure.cells.keys():
		if cell.z == -1 and VoxelBrushLayout.speckle(cell) < 40:
			figure.cells[cell] = Color("#E8B850")
	VoxelBrush.box(figure, Vector3i(3, 15, 0), Vector3i(10, 16, 0), Color("#D23A2A"), "plastic")


## A pack of chewing gum: white with a green band, a stick in foil pulled out.
static func _build_chewing_gum(figure: PlayerModel.VoxelFigure) -> void:
	var pack := Color("#EEF6F0")
	var band := Color("#2EB060")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(11, 6, 2), pack, "plastic")
	VoxelBrush.box(figure, Vector3i(0, 2, 0), Vector3i(11, 4, 2), band, "plastic")
	for column in range(1, 11, 3):
		VoxelBrush.box(figure, Vector3i(column, 3, 0), Vector3i(column, 3, 0), pack, "plastic")
	VoxelBrush.box(figure, Vector3i(4, 7, 1), Vector3i(6, 9, 1), Color("#C8CCD2"), "metal")
	VoxelBrush.box(figure, Vector3i(5, 10, 1), Vector3i(5, 10, 1), Color("#C8CCD2"), "metal")
	VoxelBrush.box(figure, Vector3i(7, 7, 1), Vector3i(8, 8, 1), Color("#B8E8C8"), "plastic")


## A raketje: a lolly in three colours, green, yellow and red, fins and a wooden stick.
static func _build_ice_lolly(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(6.0, 6.0)
	VoxelBrush.box(figure, Vector3i(5, 0, 5), Vector3i(6, 4, 5), Color("#E0C08A"), "skin")
	var green := Color("#3AC04A")
	VoxelBrush.cylinder_y(figure, centre, 3.0, 5, 9, green, "plastic")
	VoxelBrush.cylinder_y(figure, centre, 2.6, 10, 14, Color("#F2D23A"), "plastic")
	VoxelBrush.cylinder_y(figure, centre, 2.1, 15, 16, Color("#E0302A"), "plastic")
	VoxelBrush.cylinder_y(figure, centre, 1.5, 17, 18, Color("#E0302A"), "plastic")
	VoxelBrush.cylinder_y(figure, centre, 0.8, 19, 20, Color("#E0302A"), "plastic")
	var fin := Color("#2A9A3A")
	VoxelBrush.box(figure, Vector3i(1, 5, 5), Vector3i(2, 7, 6), fin, "plastic")
	VoxelBrush.box(figure, Vector3i(9, 5, 5), Vector3i(10, 7, 6), fin, "plastic")
	VoxelBrush.box(figure, Vector3i(5, 5, 1), Vector3i(6, 7, 2), fin, "plastic")
	VoxelBrush.box(figure, Vector3i(5, 5, 9), Vector3i(6, 7, 10), fin, "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 5 and VoxelBrushLayout.speckle(cell) < 6, [Color("#F4FAFF")], "plastic")


## A tin of pea soup: a green label with a bowl on it, ridged steel ends and a ring on top.
static func _build_soup_can(figure: PlayerModel.VoxelFigure) -> void:
	var centre := Vector2(5.0, 5.0)
	VoxelBrush.cylinder_y(figure, centre, 4.4, 0, 0, ItemLook.STEEL, "metal")
	VoxelBrush.cylinder_y(figure, centre, 4.6, 1, 1, ItemLook.STEEL_DARK, "metal")
	VoxelBrush.cylinder_y(figure, centre, 4.6, 2, 9, Color("#3A7A2E"), "plastic")
	VoxelBrush.cylinder_y(figure, centre, 4.6, 10, 10, ItemLook.STEEL_DARK, "metal")
	VoxelBrush.cylinder_y(figure, centre, 4.4, 11, 11, ItemLook.STEEL, "metal")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 8, [Color("#F2C230")], "plastic")
	for column in range(3, 8):
		VoxelBrush.paint_front(figure, column, 6, Color("#9AAA30"), "plastic")
	for column in range(3, 8):
		VoxelBrush.paint_front(figure, column, 5, Color("#F2F2F2"), "plastic")
	for column in range(4, 7):
		VoxelBrush.paint_front(figure, column, 4, Color("#F2F2F2"), "plastic")
	VoxelBrush.paint_front(figure, 4, 6, Color("#A8402A"), "plastic")
	VoxelBrush.paint_front(figure, 6, 6, Color("#A8402A"), "plastic")
	VoxelBrush.box(figure, Vector3i(4, 12, 3), Vector3i(6, 12, 3), ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(4, 12, 5), Vector3i(6, 12, 5), ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(4, 12, 4), Vector3i(4, 12, 4), ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(6, 12, 4), Vector3i(6, 12, 4), ItemLook.STEEL, "metal")


## A carton of half-skimmed milk: white with a light blue band, a gable top and a cap.
static func _build_milk_carton(figure: PlayerModel.VoxelFigure) -> void:
	var carton := Color("#F4F4F2")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(7, 13, 7), carton, "plastic")
	for step in 4:
		VoxelBrush.box(figure, Vector3i(0, 14 + step, step), Vector3i(7, 14 + step, 7 - step), carton, "plastic")
	VoxelBrush.box(figure, Vector3i(0, 18, 3), Vector3i(7, 18, 4), carton, "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 3 and cell.y <= 8, [Color("#5AA0E0")], "plastic")
	for level in range(4, 8):
		VoxelBrush.paint_front(figure, 3, level, carton, "plastic")
		VoxelBrush.paint_front(figure, 4, level, carton, "plastic")
	for column in range(0, 8):
		VoxelBrush.paint_front(figure, column, 10 + int(column % 3 == 0), Color("#2A6AC8"), "plastic")
	VoxelBrush.box(figure, Vector3i(5, 16, 0), Vector3i(6, 16, 1), Color("#2A6AC8"), "plastic")
