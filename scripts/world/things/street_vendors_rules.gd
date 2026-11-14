extends RefCounted
## The rules of the sellers at the snack carts (logic; docs/CODE_LAGEN.md;
## street_vendors.gd): which prop tiles get a seller and what their stall is called, who
## sells there, the names of the cart and the seller and the seed the seller is made from,
## and which layers of the town hold a copy of the cart.
##   const StreetVendorsRules = preload("res://scripts/world/things/street_vendors_rules.gd")

## Prop tiles that get a seller -> the name of the stall ("shop_name").
const VENDOR_CARTS := {"markt/frietkar": "de frietkar"}
## Who sells from a cart (Conversations: the role).
const SELLER_ROLE := "snackbarhouder"
## The seed of seller `number` is SEED_BASE + number * SEED_STEP.
const SEED_BASE := 7100
const SEED_STEP := 13


## The name of the stall of the cart tile `tile_name` ("" when it gets no seller).
static func shop_name(tile_name: String) -> String:
	return String(VENDOR_CARTS.get(tile_name, ""))


## The seed seller `number` (1, 2, ...) is made from: always the same face at the same cart.
static func seller_seed(number: int) -> int:
	return SEED_BASE + number * SEED_STEP


## The names of the nodes of cart and seller `number`.
static func cart_name(number: int) -> String:
	return "Kar%d" % number


static func seller_name(number: int) -> String:
	return "Verkoper%d" % number


## Whether the layer `layer_name` holds the carts of the props layer `props_name`: that
## layer itself or one of its LOD copies ("Props_lod...").
static func holds_carts(layer_name: String, props_name: String) -> bool:
	return layer_name == props_name or layer_name.begins_with(props_name + "_lod")
