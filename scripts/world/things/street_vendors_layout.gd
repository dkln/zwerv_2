extends RefCounted
## Where a snack cart, its seller and the arrow over it stand (layout; docs/CODE_LAGEN.md;
## street_vendors.gd): the way the cart faces, the place of the seller in it, how far before
## the seller its counter is and how high over the cart the arrow bobs. `box` is the box of
## the cart's tile (its front at box.end.z, its top at box.end.y).
##   const StreetVendorsLayout = preload("res://scripts/world/things/street_vendors_layout.gd")

## The way the cart's front (its hatch) faces: north. Of the two sides the iso camera sees
## (north and east) the one the sun lights.
const CART_YAW := PI
## Where the seller stands in the cart (metres from its pivot, the front +z): on the floor of
## its room (0.625 m, tools/voxgen/tiles/street_carts.py chip_van), a little before the middle.
const SELLER_IN_CART := Vector3(0.0, 0.625, 0.15)
## Within how many metres of the front of the cart the player can order.
const ORDER_REACH := 2.0
## The arrow over the cart: its point between these heights above the top of the cart.
const MARK_ABOVE := Vector2(0.4, 1.0)


## Where a cart stands: at `origin`, its hatch to the north.
static func cart_place(origin: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, CART_YAW), origin)


## Where the seller stands, in a cart standing at `cart` (world).
static func seller_place(cart: Transform3D) -> Vector3:
	return cart * SELLER_IN_CART


## How far before the seller the front of the cart is: where you order.
static func to_front(box: AABB) -> float:
	return box.end.z - SELLER_IN_CART.z


## How far before the seller the arrow bobs: over the front half of the cart.
static func mark_ahead(box: AABB) -> float:
	return to_front(box) * 0.5


## Between which heights the point of the arrow bobs (x the lowest, y the highest), from
## the seller's feet: above the top of the cart.
static func mark_heights(box: AABB) -> Vector2:
	var top := box.end.y - SELLER_IN_CART.y
	return Vector2(top + MARK_ABOVE.x, top + MARK_ABOVE.y)
