extends Node3D
## The trolley or the basket of a supermarket with what is in it (graphics,
## docs/CODE_LAGEN.md): the one the player pushes or carries (the node "Winkelkarretje" or
## "Winkelmandje" on the player, its packs in "Spullen": a little block each, in the colour
## of its shelf), the one a shopper has, and the arms that go with it. It decides nothing:
## the supermarket (supermarket.gd) says which one and what is in it. Where it hangs and
## where the packs lie: supermarket_layout.gd.
##   const SupermarketCarrierView = preload("res://scripts/world/interiors/supermarket_carrier_view.gd")

const SupermarketLayout = preload("res://scripts/world/interiors/supermarket_layout.gd")

const LIBRARY := "res://assets/libraries/binnen.res"
const PROPS_LIBRARY := "res://assets/libraries/props.res"
const PREFIX := "supermarkt/"
const CART_NAME := "Winkelkarretje"
const BASKET_NAME := "Winkelmandje"
const GOODS_NAME := "Spullen"
## The colour of the packs in a trolley or basket, per kind of shelf.
const GOODS_COLOURS := {
	"droog": Color("#E2AA28"), "ontbijt": Color("#E07A20"), "snoep": Color("#E05A9A"), "drank": Color("#3A8A4A"),
	"verzorging": Color("#4A8AD0"), "conserven": Color("#A8302A"), "zuivel": Color("#F0F0EC"), "diepvries": Color("#3A6AD0"),
	"brood": Color("#C08A4A"), "bakkerij": Color("#D8A050"), "groente": Color("#F0D040"), "bloemen": Color("#E03040"),
	"actie": Color("#C88A3A"),
}
const OTHER_GOODS := Color("#C8C4BA")
## The arms of the player (degrees) pushing a trolley, and the right one carrying a basket.
const CART_ARMS := Vector3(-62.0, 0.0, 0.0)
const BASKET_ARM := Vector3(0.0, 0.0, 10.0)

var in_cart := false
var _model: MeshInstance3D


## The trolley (`as_cart`) or the basket of the chain `brand`, as the player has it.
static func create(as_cart: bool, brand: String) -> Node3D:
	var carried: Node3D = (load("res://scripts/world/interiors/supermarket_carrier_view.gd") as GDScript).new()
	carried.call("_build", as_cart, brand)
	return carried


func _build(as_cart: bool, brand: String) -> void:
	in_cart = as_cart
	name = CART_NAME if as_cart else BASKET_NAME
	_model = model(as_cart, brand)
	_model.name = "Model"
	position = SupermarketLayout.carried_at(as_cart)
	add_child(_model)


## The mesh of the trolley (`as_cart`) or the basket in the colours of `brand`, at its own
## origin; without a mesh when the library has none.
static func model(as_cart: bool, brand: String) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var library: MeshLibrary = load(PROPS_LIBRARY if as_cart else LIBRARY)
	var item_name := "winkel/winkelwagen_" + String(SupermarketLayout.CART_COLOURS[brand]) if as_cart else PREFIX + "mandje_" + brand
	var item := library.find_item_by_name(item_name)
	if item >= 0:
		mesh_node.mesh = library.get_item_mesh(item)
		mesh_node.transform = library.get_item_mesh_transform(item)
	return mesh_node


## The trolley or the basket as a shopper has it: before them, or on the arm.
static func shopper_model(as_cart: bool, brand: String) -> MeshInstance3D:
	var mesh_node := model(as_cart, brand)
	mesh_node.name = CART_NAME if as_cart else BASKET_NAME
	mesh_node.position += SupermarketLayout.SHOPPER_CART_AT if as_cart else SupermarketLayout.SHOPPER_BASKET_AT
	return mesh_node


## The box the trolley takes up before the player (in the player's space): it bumps into
## the shelves and the people as the player does. Without size for a basket (or no mesh).
func pushed_box() -> AABB:
	if not in_cart or _model == null or _model.mesh == null:
		return AABB()
	return transform * _model.transform * _model.mesh.get_aabb()


## The packs in it: one for each of `categories` (the kind of shelf it came from).
func show_goods(categories: Array) -> void:
	var holder := get_node_or_null(GOODS_NAME)
	if holder:
		holder.free()
	holder = Node3D.new()
	holder.name = GOODS_NAME
	add_child(holder)
	for index in categories.size():
		var pack := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * SupermarketLayout.pack_size(in_cart)
		var material := StandardMaterial3D.new()
		material.albedo_color = GOODS_COLOURS.get(String(categories[index]), OTHER_GOODS)
		box.material = material
		pack.mesh = box
		pack.position = SupermarketLayout.pack_at(index, in_cart)
		holder.add_child(pack)


## How many packs are shown.
func goods_shown() -> int:
	var holder := get_node_or_null(GOODS_NAME)
	return holder.get_child_count() if holder else 0


## The arms of `model` (PlayerModel.pose_limb) for `carrier`: both on the handle of a
## trolley ("karretje"), the right one out for a basket ("mandje"), down for none.
static func pose_arms(player_model: Node, carrier: String) -> void:
	if player_model == null or not player_model.has_method("pose_limb"):
		return
	player_model.pose_limb("arm_left", CART_ARMS if carrier == "karretje" else Vector3.ZERO)
	player_model.pose_limb("arm_right", CART_ARMS if carrier == "karretje" else (BASKET_ARM if carrier == "mandje" else Vector3.ZERO))


## Both hands of `figure` (TownsfolkFigure) on the handle of the trolley before them.
static func hold_cart(figure: Node3D) -> void:
	for side: String in ["left", "right"]:
		var shoulder: Vector3 = figure.call("rest_joint", "arm_" + side)
		figure.call("aim_arm", side, Vector3(shoulder.x * 0.7, shoulder.y - 0.3, 0.42))
