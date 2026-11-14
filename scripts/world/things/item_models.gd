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

const VoxelBrush = preload("res://scripts/world/things/voxel_brush_view.gd")
const ItemModelsFood = preload("res://scripts/world/things/item_models_food_view.gd")
const ItemModelsGoods = preload("res://scripts/world/things/item_models_goods_view.gd")
const ItemLook = preload("res://scripts/world/things/item_models_look.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
## Metres per voxel of the items.
const ITEM_VOXEL := 0.025
## The cache key of the fallback model.
const FALLBACK := "?"

static var _meshes := {}
static var _modelled := {}


## The mesh of an item (every id of Items.ITEMS has its own; another id: a plain paper bag).
static func mesh_for(item_id: String) -> ArrayMesh:
	if _meshes.has(item_id):
		return _meshes[item_id]
	var figure := PlayerModel.VoxelFigure.new()
	var mesh: ArrayMesh
	if _build(item_id, figure):
		mesh = VoxelBrush.mesh_of(figure, ITEM_VOXEL)
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


## Builds the model of `item_id` into `figure`: the food and drink (ItemModelsFood), then the
## other things (ItemModelsGoods); false when it has no model of its own.
static func _build(item_id: String, figure: PlayerModel.VoxelFigure) -> bool:
	return ItemModelsFood.build(item_id, figure) or ItemModelsGoods.build(item_id, figure)


## A plain paper bag, folded at the top: the model of an item without one of its own.
static func _fallback_mesh() -> ArrayMesh:
	if not _meshes.has(FALLBACK):
		var figure := PlayerModel.VoxelFigure.new()
		VoxelBrush.box(figure, Vector3i(0, 0, 0), Vector3i(9, 11, 6), ItemLook.CARDBOARD, "skin")
		VoxelBrush.box(figure, Vector3i(0, 12, 2), Vector3i(9, 13, 4), ItemLook.CARDBOARD.darkened(0.2), "skin")
		VoxelBrush.box(figure, Vector3i(3, 5, 0), Vector3i(6, 7, 0), ItemLook.CARDBOARD.darkened(0.35), "skin")
		_meshes[FALLBACK] = VoxelBrush.mesh_of(figure, ITEM_VOXEL)
	return _meshes[FALLBACK]
