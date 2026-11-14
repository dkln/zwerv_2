extends RefCounted
## The voxel models of the things among the items that are not food (graphics;
## docs/CODE_LAGEN.md): bottles with deposit, tobacco, the sleeping bag, the bucket, the
## rod, papers, flowers, cards, the old coat. One builder per item, painted into a figure
## with the voxel brush (voxel_brush_view.gd), the shapes several share from
## item_models_shapes_view.gd, the colours from item_models_look.gd. item_models.gd asks
## build() for an item and makes its mesh.
##   const ItemModelsGoods = preload("res://scripts/world/things/item_models_goods_view.gd")
##   ItemModelsGoods.build("slaapzak", figure)   # true: the sleeping bag is in the figure

const PlayerModel = preload("res://scripts/player/player_model.gd")
const VoxelBrush = preload("res://scripts/world/things/voxel_brush_view.gd")
const VoxelBrushLayout = preload("res://scripts/world/things/voxel_brush_layout.gd")
const ItemShapes = preload("res://scripts/world/things/item_models_shapes_view.gd")
const ItemLook = preload("res://scripts/world/things/item_models_look.gd")


## Builds the model of `item_id` into `figure`; false when it is not one of the other things.
static func build(item_id: String, figure: PlayerModel.VoxelFigure) -> bool:
	match item_id:
		"sigaretten": _build_tobacco(figure)
		"slaapzak": _build_sleeping_bag(figure)
		"emmer": _build_bucket(figure)
		"hengel": _build_fishing_rod(figure)
		"pleister": _build_plasters(figure)
		"statiegeld": _build_deposit_bottles(figure)
		"hoed": _build_cowboy_hat(figure)
		"foto": _build_photo(figure)
		"krant": _build_newspaper(figure)
		"tulpen": _build_tulips(figure)
		"roos": _build_rose(figure)
		"puzzelboek": _build_puzzle_book(figure)
		"stadskaart": _build_town_map(figure)
		"pocketboek": _build_paperback(figure)
		"ov_chipkaart": _build_transit_card(figure)
		"los_kaartje": _build_paper_ticket(figure)
		"wachtnummer": _build_queue_ticket(figure)
		"straatnieuws": _build_street_paper(figure)
		"pinpas": _build_bank_card(figure)
		"id_kaart": _build_id_card(figure)
		"oude_jas": _build_old_coat(figure)
		_:
			return false
	return true


## The ids of the items this script has a model of.
static func item_ids() -> Array[String]:
	return ["sigaretten", "slaapzak", "emmer", "hengel", "pleister", "statiegeld", "hoed", "foto", "krant", "tulpen", "roos", "puzzelboek", "stadskaart", "pocketboek", "ov_chipkaart", "los_kaartje", "wachtnummer", "straatnieuws", "pinpas", "id_kaart", "oude_jas"]


## A beer-crate's worth: three empty deposit bottles, brown and green, with labels.
static func _build_deposit_bottles(figure: PlayerModel.VoxelFigure) -> void:
	ItemShapes.beer_bottle(figure, 0, 0, Color("#6A3A14"), Color("#EDE4CC"))
	ItemShapes.beer_bottle(figure, 5, 3, Color("#2E6A2E"), Color("#D8D8D0"))
	ItemShapes.beer_bottle(figure, 10, 1, Color("#5A3010"), Color("#C8242C"))


## A pouch of rolling tobacco: green with a cream label, tobacco sticking out, papers beside it.
static func _build_tobacco(figure: PlayerModel.VoxelFigure) -> void:
	var pouch := Color("#2F5A3C")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(13, 9, 3), pouch, "plastic")
	VoxelBrush.box(figure, Vector3i(0, 6, 0), Vector3i(13, 9, 0), Color("#24482F"), "plastic")
	VoxelBrush.box(figure, Vector3i(3, 2, 0), Vector3i(10, 4, 0), Color("#E8D8A8"), "plastic")
	VoxelBrush.box(figure, Vector3i(4, 3, 0), Vector3i(9, 3, 0), Color("#8A5A2E"), "plastic")
	var tobacco := Color("#8A5A30")
	for column in range(1, 13):
		for depth in range(1, 3):
			var speckle := VoxelBrushLayout.speckle(Vector3i(column, 10, depth))
			if speckle < 70:
				VoxelBrush.box(figure, Vector3i(column, 10, depth), Vector3i(column, 10 + int(speckle < 25), depth),
						tobacco if speckle % 2 == 0 else Color("#6A4020"), "hair")
	VoxelBrush.box(figure, Vector3i(15, 0, 0), Vector3i(18, 6, 1), Color("#E8E0D0"), "skin")
	VoxelBrush.box(figure, Vector3i(15, 5, 0), Vector3i(18, 6, 0), Color("#C8242C"), "skin")
	VoxelBrush.box(figure, Vector3i(16, 7, 1), Vector3i(17, 8, 1), Color("#F4F0E8"), "skin")


## A sleeping bag rolled up: dark blue nylon, the yellow lining spiralling at the ends, two
## straps with buckles.
static func _build_sleeping_bag(figure: PlayerModel.VoxelFigure) -> void:
	var nylon := Color("#2C3E7A")
	var lining := Color("#D8A030")
	var centre := Vector2(5.5, 5.5)
	VoxelBrush.cylinder_x(figure, centre, 5.5, 0, 19, nylon, "nylon")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return (cell.x == 0 or cell.x == 19) \
				and floori(Vector2(cell.y + 0.5, cell.z + 0.5).distance_to(centre) * 0.9) % 2 == 1,
		[lining], "knit")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == nylon and VoxelBrushLayout.speckle(cell) < 6, [Color("#4A4A3A")], "nylon")
	for strap_column in [4, 15]:
		VoxelBrush.cylinder_x(figure, centre, 6.0, strap_column, strap_column, ItemLook.DARK, "leather")
		VoxelBrush.cylinder_x(figure, centre, 5.5, strap_column, strap_column, ItemLook.DARK, "leather")
	VoxelBrush.box(figure, Vector3i(4, 4, -1), Vector3i(4, 6, -1), ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(15, 4, -1), Vector3i(15, 6, -1), ItemLook.STEEL, "metal")


## A blue plastic bucket with water in it, a steel handle and a chamois over the rim.
static func _build_bucket(figure: PlayerModel.VoxelFigure) -> void:
	var blue := Color("#3A7AD0")
	var centre := Vector2(6.0, 6.0)
	for level in 13:
		VoxelBrush.cylinder_y(figure, centre, 4.2 + level * 0.12, level, level, blue, "plastic")
	VoxelBrush.clear_cylinder_y(figure, centre, 4.4, 9, 12)
	VoxelBrush.cylinder_y(figure, centre, 4.4, 8, 8, Color("#6AA8D8"), "glass")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.y == 12, [Color("#5A9AE8")], "plastic")
	for step in 19:
		var angle := deg_to_rad(step * 10.0)
		VoxelBrush.box(figure, Vector3i(roundi(5.5 + 6.0 * cos(angle)), roundi(12.0 + 5.5 * sin(angle)), 6),
				Vector3i(roundi(5.5 + 6.0 * cos(angle)), roundi(12.0 + 5.5 * sin(angle)), 6), ItemLook.STEEL, "metal")
	var chamois := Color("#E8C870")
	VoxelBrush.box(figure, Vector3i(3, 13, 0), Vector3i(7, 13, 1), chamois, "leather")
	VoxelBrush.box(figure, Vector3i(3, 7, -1), Vector3i(7, 13, -1), chamois, "leather")
	for column in range(3, 8):
		if VoxelBrushLayout.speckle(Vector3i(column, 7, -1)) < 50:
			figure.clear(column, 7, -1)
	VoxelBrush.box(figure, Vector3i(5, 2, -1), Vector3i(5, 2, -1), Color("#6AA8D8"), "glass")  # the leak


## A fishing rod, slanting up: cork grip, a reel, rings, the line down to a red-white float.
static func _build_fishing_rod(figure: PlayerModel.VoxelFigure) -> void:
	var cork := Color("#C8A070")
	var rod := Color("#2E4A30")
	for step in 21:
		var colour := cork if step < 5 else rod
		VoxelBrush.box(figure, Vector3i(2 + step, 2 + step, 2), Vector3i(3 + step, 2 + step, 2), colour,
				"skin" if step < 5 else "plastic")
		if step < 5:
			VoxelBrush.box(figure, Vector3i(2 + step, 2 + step, 3), Vector3i(3 + step, 2 + step, 3), cork, "skin")
	VoxelBrush.box(figure, Vector3i(1, 1, 2), Vector3i(2, 1, 3), ItemLook.DARK, "plastic")
	VoxelBrush.box(figure, Vector3i(7, 4, 1), Vector3i(9, 6, 3), ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(8, 5, 0), Vector3i(8, 5, 0), ItemLook.DARK, "plastic")
	for guide_step in [10, 14, 18]:
		VoxelBrush.box(figure, Vector3i(3 + guide_step, 1 + guide_step, 2), Vector3i(3 + guide_step, 1 + guide_step, 2),
				ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(23, 7, 2), Vector3i(23, 21, 2), Color("#E0E0E0"), "plastic")
	VoxelBrush.ellipsoid(figure, Vector3(23.5, 4.5, 2.5), Vector3(1.6, 2.2, 1.6), Color("#F4F4F0"), "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.x >= 22 and cell.y >= 5 and cell.y <= 6, [Color("#E0302A")], "plastic")
	VoxelBrush.box(figure, Vector3i(23, 0, 2), Vector3i(23, 1, 2), Color("#E0E0E0"), "plastic")
	VoxelBrush.box(figure, Vector3i(22, 0, 2), Vector3i(22, 0, 2), ItemLook.STEEL, "metal")


## A box of plasters: white with a red cross, one plaster lying on top.
static func _build_plasters(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(13, 7, 4), ItemLook.WHITE, "plastic")
	VoxelBrush.box(figure, Vector3i(0, 8, 0), Vector3i(13, 8, 4), Color("#E4E2DA"), "plastic")
	var red := Color("#D22A2A")
	VoxelBrush.box(figure, Vector3i(6, 1, 0), Vector3i(7, 6, 0), red, "plastic")
	VoxelBrush.box(figure, Vector3i(4, 3, 0), Vector3i(9, 4, 0), red, "plastic")
	VoxelBrush.box(figure, Vector3i(2, 9, 1), Vector3i(11, 9, 3), Color("#E2B890"), "skin")
	VoxelBrush.box(figure, Vector3i(5, 9, 1), Vector3i(8, 9, 3), Color("#F4E0CC"), "skin")
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
			VoxelBrush.box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), felt, "cloth")
			if level == 3:
				VoxelBrush.box(figure, Vector3i(column, 2, depth), Vector3i(column, 2, depth), felt, "cloth")
	for level in range(2, 9):
		var shrink := 1.0 if level < 7 else 0.85
		for column in range(0, 22):
			for depth in range(0, 18):
				var offset := Vector2((column + 0.5 - 11.0) / (5.5 * shrink), (depth + 0.5 - 9.0) / (4.5 * shrink))
				if offset.length() <= 1.0:
					VoxelBrush.box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), felt, "cloth")
	VoxelBrush.clear_box(figure, Vector3i(10, 8, 6), Vector3i(11, 8, 12))
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return cell.y >= 2 and cell.y <= 3 and Vector2((cell.x + 0.5 - 11.0) / 5.5, (cell.z + 0.5 - 9.0) / 4.5).length() <= 1.0,
		[Color("#3A2418")], "leather")
	for column in range(10, 12):
		for level in range(2, 4):
			VoxelBrush.paint_front(figure, column, level, Color("#D8DCE2"), "metal")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == felt and VoxelBrushLayout.speckle(cell) < 15, [Color("#86582E")], "cloth")


## An old photo, upright: a white border, in sepia a woman, a kotter and the harbour.
static func _build_photo(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(15, 12, 0), ItemLook.PAPER, "skin")
	VoxelBrush.box(figure, Vector3i(1, 6, 0), Vector3i(14, 11, 0), Color("#C8B48A"), "skin")
	VoxelBrush.box(figure, Vector3i(1, 3, 0), Vector3i(14, 5, 0), Color("#8A7A5A"), "skin")
	VoxelBrush.box(figure, Vector3i(1, 1, 0), Vector3i(14, 2, 0), Color("#6A5A44"), "skin")
	var boat := Color("#3E3020")
	VoxelBrush.box(figure, Vector3i(8, 4, 0), Vector3i(12, 4, 0), boat, "skin")
	VoxelBrush.box(figure, Vector3i(7, 5, 0), Vector3i(13, 5, 0), boat, "skin")
	VoxelBrush.box(figure, Vector3i(10, 6, 0), Vector3i(11, 7, 0), boat, "skin")
	VoxelBrush.box(figure, Vector3i(9, 6, 0), Vector3i(9, 10, 0), boat, "skin")
	VoxelBrush.box(figure, Vector3i(3, 1, 0), Vector3i(3, 2, 0), Color("#2E2418"), "skin")
	VoxelBrush.box(figure, Vector3i(2, 3, 0), Vector3i(4, 6, 0), Color("#7A6448"), "skin")
	VoxelBrush.box(figure, Vector3i(3, 7, 0), Vector3i(3, 7, 0), Color("#D8C090"), "skin")
	VoxelBrush.box(figure, Vector3i(3, 8, 0), Vector3i(3, 8, 0), Color("#4A3A28"), "skin")
	VoxelBrush.box(figure, Vector3i(12, 10, 0), Vector3i(12, 10, 0), Color("#5A4A34"), "skin")
	VoxelBrush.box(figure, Vector3i(13, 9, 0), Vector3i(13, 9, 0), Color("#5A4A34"), "skin")
	figure.clear(15, 12, 0)
	VoxelBrush.box(figure, Vector3i(14, 12, 1), Vector3i(15, 11, 1), Color("#D8D0B8"), "skin")


## Today's newspaper, folded and upright: a black headline, a photo and lines of text.
static func _build_newspaper(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(13, 17, 1), Color("#E8E4D8"), "skin")
	var ink := Color("#2A2A2E")
	VoxelBrush.box(figure, Vector3i(1, 15, 0), Vector3i(12, 16, 0), ink, "skin")
	VoxelBrush.box(figure, Vector3i(1, 9, 0), Vector3i(6, 13, 0), Color("#8A8E96"), "skin")
	VoxelBrush.box(figure, Vector3i(2, 10, 0), Vector3i(4, 11, 0), Color("#5A5E66"), "skin")
	for level in range(1, 14, 2):
		var first_column := 8 if level >= 9 else 1
		for column in range(first_column, 13):
			if VoxelBrushLayout.speckle(Vector3i(column, level, 0)) < 82:
				VoxelBrush.box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), Color("#6A6A70"), "skin")
	VoxelBrush.box(figure, Vector3i(13, 0, 1), Vector3i(13, 17, 1), Color("#D4D0C4"), "skin")


## A puzzle booklet, upright: a yellow cover with a crossword grid, a pencil beside it.
static func _build_puzzle_book(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(11, 15, 1), Color("#F2C230"), "plastic")
	VoxelBrush.box(figure, Vector3i(0, 0, 1), Vector3i(0, 15, 1), Color("#C89A20"), "plastic")
	VoxelBrush.box(figure, Vector3i(1, 12, 0), Vector3i(10, 14, 0), Color("#D23A2A"), "plastic")
	for column in range(2, 9, 2):
		VoxelBrush.box(figure, Vector3i(column, 13, 0), Vector3i(column, 13, 0), ItemLook.WHITE, "plastic")
	for column in range(2, 10):
		for level in range(2, 11):
			var cell_colour := ItemLook.DARK if VoxelBrushLayout.speckle(Vector3i(column, level, 0)) < 25 else Color("#F8F8F4")
			VoxelBrush.box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), cell_colour, "plastic")
	VoxelBrush.box(figure, Vector3i(13, 0, 0), Vector3i(13, 0, 0), ItemLook.DARK, "plastic")
	VoxelBrush.box(figure, Vector3i(13, 1, 0), Vector3i(13, 1, 0), Color("#E0B880"), "skin")
	VoxelBrush.box(figure, Vector3i(13, 2, 0), Vector3i(13, 12, 0), Color("#F2B020"), "plastic")
	VoxelBrush.box(figure, Vector3i(13, 13, 0), Vector3i(13, 13, 0), ItemLook.STEEL, "metal")
	VoxelBrush.box(figure, Vector3i(13, 14, 0), Vector3i(13, 14, 0), Color("#E87A90"), "plastic")


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
			VoxelBrush.box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), colour, "skin")
	figure.put(12, 6, roundi(absf(posmod(12, 10) - 5.0) * 0.6), Color("#D82A2A"))
	figure.put(12, 7, roundi(absf(posmod(12, 10) - 5.0) * 0.6), Color("#D82A2A"))
	figure.mark("plastic", [Color("#D82A2A")])


## A paperback detective: dark blue cover, a yellow title, a red fish, cream pages.
static func _build_paperback(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(10, 15, 2), Color("#1E2A50"), "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool: return cell.z == 1 and cell.x >= 1,
			[Color("#EDE4CC")], "skin")
	VoxelBrush.box(figure, Vector3i(2, 12, 0), Vector3i(8, 13, 0), Color("#F2C230"), "plastic")
	for column in range(3, 8, 2):
		VoxelBrush.box(figure, Vector3i(column, 10, 0), Vector3i(column, 10, 0), ItemLook.WHITE, "plastic")
	var red := Color("#C82A2A")
	VoxelBrush.box(figure, Vector3i(3, 5, 0), Vector3i(7, 5, 0), red, "plastic")
	VoxelBrush.box(figure, Vector3i(4, 4, 0), Vector3i(6, 6, 0), red, "plastic")
	VoxelBrush.box(figure, Vector3i(8, 4, 0), Vector3i(8, 4, 0), red, "plastic")
	VoxelBrush.box(figure, Vector3i(8, 6, 0), Vector3i(8, 6, 0), red, "plastic")
	VoxelBrush.box(figure, Vector3i(4, 5, 0), Vector3i(4, 5, 0), ItemLook.WHITE, "plastic")
	for column in range(1, 10):
		VoxelBrush.box(figure, Vector3i(column, 2 + int(column % 3 == 0), 0), Vector3i(column, 2 + int(column % 3 == 0), 0),
				Color("#5A8AC8"), "plastic")


## A bunch of tulips, red and yellow, in a paper cone with leaves.
static func _build_tulips(figure: PlayerModel.VoxelFigure) -> void:
	var stems := [Vector3i(3, 17, 7), Vector3i(7, 19, 4), Vector3i(11, 17, 7), Vector3i(5, 16, 10),
			Vector3i(9, 18, 10)]
	var heads := [Color("#D82A2A"), Color("#F2C22A"), Color("#D82A2A"), Color("#F2C22A"), Color("#E8402A")]
	VoxelBrush.box(figure, Vector3i(7, 2, 7), Vector3i(7, 9, 7), ItemLook.STEM_GREEN, "plastic")
	for stem_index in stems.size():
		var stem: Vector3i = stems[stem_index]
		for level in range(9, stem.y):
			var progress := (level - 9.0) / (stem.y - 9.0)
			var column := roundi(lerpf(7.0, stem.x, progress))
			var depth := roundi(lerpf(7.0, stem.z, progress))
			VoxelBrush.box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), ItemLook.STEM_GREEN, "plastic")
		var head: Color = heads[stem_index]
		VoxelBrush.ellipsoid(figure, Vector3(stem.x + 0.5, stem.y + 1.8, stem.z + 0.5), Vector3(1.6, 2.2, 1.6), head, "plastic")
		figure.clear(stem.x, stem.y + 3, stem.z)
		figure.put(stem.x, stem.y + 3, stem.z - 1, head.darkened(0.15))
		figure.mark("plastic", [head.darkened(0.15)])
	VoxelBrush.box(figure, Vector3i(2, 10, 7), Vector3i(2, 14, 7), ItemLook.LEAF_GREEN, "plastic")
	VoxelBrush.box(figure, Vector3i(1, 13, 7), Vector3i(1, 15, 7), ItemLook.LEAF_GREEN, "plastic")
	VoxelBrush.box(figure, Vector3i(12, 10, 6), Vector3i(12, 13, 6), ItemLook.LEAF_GREEN, "plastic")
	var wrap := Color("#D8C49A")
	for level in range(0, 11):
		var radius := 1.6 + level * 0.3
		VoxelBrush.cylinder_y(figure, Vector2(7.5, 7.5), radius, level, level, wrap, "skin")
		if level >= 8:
			VoxelBrush.clear_cylinder_y(figure, Vector2(7.5, 7.5), radius - 1.0, level, level)
	VoxelBrush.cylinder_y(figure, Vector2(7.5, 7.5), 2.6, 4, 4, Color("#C8242C"), "cloth")


## A single red rose in a cellophane sleeve, open at the front, a ribbon round it.
static func _build_rose(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(6, 0, 5), Vector3i(6, 17, 5), ItemLook.STEM_GREEN, "plastic")
	for thorn: Vector3i in [Vector3i(7, 5, 5), Vector3i(5, 9, 5), Vector3i(7, 13, 5)]:
		VoxelBrush.box(figure, thorn, thorn, Color("#1E4A1E"), "plastic")
	VoxelBrush.box(figure, Vector3i(7, 8, 5), Vector3i(9, 9, 5), ItemLook.LEAF_GREEN, "plastic")
	VoxelBrush.box(figure, Vector3i(3, 11, 5), Vector3i(5, 12, 5), ItemLook.LEAF_GREEN, "plastic")
	VoxelBrush.box(figure, Vector3i(5, 17, 4), Vector3i(7, 17, 6), ItemLook.STEM_GREEN, "plastic")
	var red := Color("#C81E2E")
	VoxelBrush.ellipsoid(figure, Vector3(6.5, 20.0, 5.5), Vector3(2.7, 2.7, 2.7), red, "plastic")
	VoxelBrush.recolour_where(figure, func(cell: Vector3i) -> bool:
		return figure.cells[cell] == red and (cell.x + cell.z + cell.y) % 3 == 0, [Color("#8A1020")], "plastic")
	var cellophane := Color("#DCEEF4")
	for level in range(2, 19):
		var radius := 1.2 + (level - 2) * 0.2
		for column in range(0, 13):
			for depth in range(5, 12):
				var distance := Vector2(column + 0.5 - 6.5, depth + 0.5 - 5.5).length()
				if distance <= radius and distance > radius - 1.0 and not figure.has(column, level, depth):
					VoxelBrush.box(figure, Vector3i(column, level, depth), Vector3i(column, level, depth), cellophane, "glass")
	VoxelBrush.box(figure, Vector3i(5, 4, 4), Vector3i(7, 4, 4), Color("#E0302A"), "cloth")
	VoxelBrush.box(figure, Vector3i(4, 3, 4), Vector3i(4, 3, 4), Color("#E0302A"), "cloth")
	VoxelBrush.box(figure, Vector3i(8, 3, 4), Vector3i(8, 3, 4), Color("#E0302A"), "cloth")


## An anonymous OV-chipkaart: blue with a lighter wave and a white field.
static func _build_transit_card(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(15, 9, 0), Color("#1E4EB0"), "plastic")
	for column in 16:
		var wave_level := roundi(3.5 + 1.5 * sin(column * 0.55))
		VoxelBrush.box(figure, Vector3i(column, wave_level, 0), Vector3i(column, wave_level, 0), Color("#5A8AE0"), "plastic")
		VoxelBrush.box(figure, Vector3i(column, 0, 0), Vector3i(column, wave_level - 1, 0), Color("#2A62C8"), "plastic")
	VoxelBrush.box(figure, Vector3i(1, 6, 0), Vector3i(5, 8, 0), Color("#F2F4F8"), "plastic")
	VoxelBrush.box(figure, Vector3i(2, 7, 0), Vector3i(4, 7, 0), Color("#1E4EB0"), "plastic")
	VoxelBrush.box(figure, Vector3i(12, 7, 0), Vector3i(14, 8, 0), Color("#F2C230"), "plastic")
	ItemShapes.round_card_corners(figure, 15, 9)


## A paper single ticket: off-white, a teal band, lines of print, a QR block and a torn edge.
static func _build_paper_ticket(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(13, 6, 0), Color("#F2EEE2"), "skin")
	VoxelBrush.box(figure, Vector3i(0, 6, 0), Vector3i(13, 6, 0), Color("#2A9A9A"), "skin")
	VoxelBrush.box(figure, Vector3i(1, 4, 0), Vector3i(7, 4, 0), Color("#4A4A50"), "skin")
	VoxelBrush.box(figure, Vector3i(1, 2, 0), Vector3i(5, 2, 0), Color("#4A4A50"), "skin")
	for column in range(9, 13):
		for level in range(1, 5):
			var colour := ItemLook.DARK if VoxelBrushLayout.speckle(Vector3i(column, level, 0)) < 50 else ItemLook.WHITE
			VoxelBrush.box(figure, Vector3i(column, level, 0), Vector3i(column, level, 0), colour, "skin")
	for level in range(0, 7, 2):
		figure.clear(13, level, 0)


## A bank card found on the street: green with a gold chip and contactless waves; on its
## back a magnetic stripe and a white strip with a riddle in blue pen.
static func _build_bank_card(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(15, 9, 1), Color("#1F6E5A"), "plastic")
	VoxelBrush.box(figure, Vector3i(2, 4, 0), Vector3i(4, 6, 0), Color("#F2C230"), "metal")
	VoxelBrush.box(figure, Vector3i(3, 5, 0), Vector3i(3, 5, 0), Color("#C89A20"), "metal")
	for wave in 3:
		VoxelBrush.box(figure, Vector3i(6 + wave, 4, 0), Vector3i(6 + wave, 6, 0), Color("#7ACAB0"), "plastic")
	for column in range(2, 14):
		if column % 4 != 1:
			VoxelBrush.box(figure, Vector3i(column, 2, 0), Vector3i(column, 2, 0), Color("#D8DCE2"), "metal")
	VoxelBrush.box(figure, Vector3i(10, 7, 0), Vector3i(14, 8, 0), Color("#2E8A72"), "plastic")
	# the back
	VoxelBrush.box(figure, Vector3i(0, 6, 1), Vector3i(15, 7, 1), ItemLook.DARK, "plastic")
	VoxelBrush.box(figure, Vector3i(1, 2, 1), Vector3i(12, 4, 1), Color("#F4F4F0"), "plastic")
	for column in range(2, 12):
		if VoxelBrushLayout.speckle(Vector3i(column, 3, 1)) < 60:
			VoxelBrush.box(figure, Vector3i(column, 3, 1), Vector3i(column, 3, 1), Color("#2A4AC8"), "plastic")
	ItemShapes.round_card_corners(figure, 15, 9)



## Straatnieuws folded once: newsprint, the red masthead with its white letters, columns of
## grey text and a photo block.
static func _build_street_paper(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(11, 15, 1), Color("#ECE8DC"), "skin")
	VoxelBrush.box(figure, Vector3i(0, 12, 0), Vector3i(11, 15, 0), Color("#C83A2A"), "skin")
	for column in range(1, 11, 2):
		VoxelBrush.box(figure, Vector3i(column, 13, 0), Vector3i(column, 14, 0), Color("#F4F4F0"), "skin")
	VoxelBrush.box(figure, Vector3i(1, 6, 0), Vector3i(5, 10, 0), Color("#6A6A70"), "skin")
	for row in range(1, 11, 2):
		VoxelBrush.box(figure, Vector3i(7, row, 0), Vector3i(10, row, 0), Color("#8A8A86"), "skin")
	for row in range(1, 5, 2):
		VoxelBrush.box(figure, Vector3i(1, row, 0), Vector3i(5, row, 0), Color("#8A8A86"), "skin")


## The slip from the number machine of Burgerzaken: thin white thermal paper, a torn top edge,
## the city's green band, a big black number and a little line of print under it.
static func _build_queue_ticket(figure: PlayerModel.VoxelFigure) -> void:
	var paper := Color("#F6F4EE")
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(9, 15, 0), paper, "skin")
	# the torn top: every other voxel gone
	for column in range(0, 10, 2):
		figure.clear(column, 15, 0)
	VoxelBrush.box(figure, Vector3i(0, 12, 0), Vector3i(9, 13, 0), Color("#2E7D32"), "skin")
	# "B" and two digits, big and black
	for voxel: Vector2i in [Vector2i(1, 9), Vector2i(1, 8), Vector2i(1, 7), Vector2i(1, 6), Vector2i(1, 5),
			Vector2i(2, 9), Vector2i(2, 7), Vector2i(2, 5), Vector2i(3, 8), Vector2i(3, 6),
			Vector2i(5, 9), Vector2i(5, 8), Vector2i(5, 7), Vector2i(6, 9), Vector2i(6, 7), Vector2i(6, 5), Vector2i(5, 6), Vector2i(5, 5),
			Vector2i(8, 9), Vector2i(8, 8), Vector2i(8, 7), Vector2i(8, 6), Vector2i(8, 5)]:
		VoxelBrush.box(figure, Vector3i(voxel.x, voxel.y, 0), Vector3i(voxel.x, voxel.y, 0), ItemLook.DARK, "skin")
	for column in range(1, 9):
		if VoxelBrushLayout.speckle(Vector3i(column, 2, 0)) < 70:
			VoxelBrush.box(figure, Vector3i(column, 2, 0), Vector3i(column, 2, 0), Color("#8A8A86"), "skin")


## A Dutch identity card: light blue-grey, the photo on the left, lines of text, the red-white-
## blue band and the chip; the back plain with the machine-readable lines.
static func _build_id_card(figure: PlayerModel.VoxelFigure) -> void:
	VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(15, 9, 1), Color("#C8D4E0"), "plastic")
	# the photo: a grey head and shoulders on a light ground
	VoxelBrush.box(figure, Vector3i(1, 1, 0), Vector3i(5, 7, 0), Color("#E8ECF0"), "plastic")
	VoxelBrush.box(figure, Vector3i(2, 4, 0), Vector3i(4, 6, 0), Color("#B8A898"), "plastic")
	VoxelBrush.box(figure, Vector3i(1, 1, 0), Vector3i(5, 3, 0), Color("#5A6070"), "plastic")
	# the lines of text and the flag band at the top
	for row in [2, 4, 6]:
		VoxelBrush.box(figure, Vector3i(7, row, 0), Vector3i(13 if row != 4 else 11, row, 0), Color("#3A4658"), "plastic")
	VoxelBrush.box(figure, Vector3i(7, 8, 0), Vector3i(8, 8, 0), Color("#AE1C28"), "plastic")
	VoxelBrush.box(figure, Vector3i(9, 8, 0), Vector3i(10, 8, 0), ItemLook.WHITE, "plastic")
	VoxelBrush.box(figure, Vector3i(11, 8, 0), Vector3i(12, 8, 0), Color("#21468B"), "plastic")
	VoxelBrush.box(figure, Vector3i(13, 6, 0), Vector3i(14, 7, 0), Color("#E0B830"), "metal")
	# the back: two machine-readable lines
	for row in [2, 4]:
		VoxelBrush.box(figure, Vector3i(1, row, 1), Vector3i(14, row, 1), Color("#3A4658"), "plastic")
	ItemShapes.round_card_corners(figure, 15, 9)


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
	VoxelBrush.box(figure, Vector3i(3, 0, 0), Vector3i(14, 19, 3), cloth, "cloth")
	VoxelBrush.box(figure, Vector3i(2, 0, 0), Vector3i(15, 5, 3), cloth, "cloth")
	VoxelBrush.box(figure, Vector3i(8, 0, 0), Vector3i(9, 12, 0), dark, "cloth")
	# the collar up, round the back of the neck
	VoxelBrush.box(figure, Vector3i(5, 20, 0), Vector3i(12, 21, 3), dark, "cloth")
	for x in range(7, 11):
		for y in [20, 21]:
			for z in [0, 1]:
				figure.clear(x, y, z)   # the neck opening
	# the sleeves hanging from the shoulders
	for sleeve_x in [0, 15]:
		VoxelBrush.box(figure, Vector3i(sleeve_x, 6, 0), Vector3i(sleeve_x + 2, 19, 3), cloth, "cloth")
		VoxelBrush.box(figure, Vector3i(sleeve_x, 6, 0), Vector3i(sleeve_x + 2, 7, 3), dark, "cloth")
	VoxelBrush.box(figure, Vector3i(15, 12, 0), Vector3i(17, 14, 0), patch, "cloth")
	# buttons down the front (the middle one gone, a thread left) and pockets
	for button_y in [9, 15]:
		VoxelBrush.box(figure, Vector3i(10, button_y, 0), Vector3i(10, button_y, 0), button, "plastic")
	VoxelBrush.box(figure, Vector3i(10, 12, 0), Vector3i(10, 12, 0), Color("#B9A27A"), "cloth")
	VoxelBrush.box(figure, Vector3i(4, 6, 0), Vector3i(6, 7, 0), dark, "cloth")
	VoxelBrush.box(figure, Vector3i(11, 6, 0), Vector3i(13, 7, 0), dark, "cloth")
	# the torn lining hanging out under the hem
	VoxelBrush.box(figure, Vector3i(4, 0, 0), Vector3i(7, 1, 0), lining, "cloth")
	VoxelBrush.box(figure, Vector3i(5, 2, 0), Vector3i(6, 2, 0), lining, "cloth")
