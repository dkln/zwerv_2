extends "res://tests/integration/support/town_test.gd"
## The seller at the snack cart on the Stationsplein (scripts/world/things/street_vendors.gd,
## node Straatverkopers): it stands behind the cart, talked to from before it the shop screen
## opens with a kroket on the menu, and buying one puts it in the pockets (the first mission's
## kroket, close to the start).
##   tests/run_integration_tests.sh street_vendor

const Iso = preload("res://scripts/camera/iso_camera.gd")


func _seller() -> Node3D:
	var vendors: Node = scene.get_node_or_null("Straatverkopers")
	if vendors == null or vendors.vendors().is_empty():
		return null
	var places: Dictionary = scene.get_meta("places")
	var cart: Vector2 = places.get("frietkar_centraal", Vector2.INF)
	var best: Node3D = null
	for seller: Node3D in vendors.vendors():
		if best == null or Vector2(seller.global_position.x, seller.global_position.z).distance_to(cart) \
				< Vector2(best.global_position.x, best.global_position.z).distance_to(cart):
			best = seller
	return best


## Someone stands behind the cart on the Stationsplein and sells from it.
func test_a_seller_behind_the_snack_cart(test) -> void:
	await frames(3)
	var seller := _seller()
	test.check(seller != null, "een verkoper bij de frietkar")
	if seller == null:
		return
	var cart: Vector2 = scene.get_meta("places").get("frietkar_centraal")
	var at := Vector2(seller.global_position.x, seller.global_position.z)
	print("verkoper op %s, kar op %s (%.1f m)" % [at, cart, at.distance_to(cart)])
	test.check(at.distance_to(cart) < 3.0, "vlak achter de kar")


## Talked to from before the cart: the shop screen with a kroket, and a kroket bought.
func test_the_seller_sells_a_kroket(test) -> void:
	await frames(3)
	var seller := _seller()
	if seller == null:
		test.check(false, "een verkoper bij de frietkar")
		return
	var front := Vector3(sin(seller.rotation.y), 0.0, cos(seller.rotation.y))
	var counter: Vector3 = seller.talk_position()
	player.global_position = Vector3(counter.x, player.global_position.y, counter.z) + front * 1.0
	player.add_money(5.0)
	player.talk_to(seller)
	await frames(2)
	test.check(hud.is_showing_shop(), "praten met de verkoper: het winkelscherm")
	var shop: Control = hud._shop_screen
	var goods: Array = shop._rows.filter(func(row: Dictionary) -> bool: return row.kind == "kopen")
	var kroket := -1
	for index in goods.size():
		if String(goods[index].item) == "kroket":
			kroket = index
	test.check(kroket >= 0, "een kroket op de kaart")
	if kroket >= 0:
		var before := int(player.inventory.get("kroket", 0))
		shop.buy(kroket)
		test.check(int(player.inventory.get("kroket", 0)) == before + 1, "een kroket gekocht")


## The cart's hatch to the north (the side the camera sees that the sun lights), the seller
## inside it on its floor facing out; standing before the counter the seller is the one to talk
## to ("[E]"), and the arrow bobs above the cart, never behind it.
func test_the_cart_faces_north_with_its_seller_inside(test) -> void:
	await frames(3)
	var seller := _seller()
	var vendors: Node = scene.get_node_or_null("Straatverkopers")
	if seller == null or vendors == null or vendors.carts().is_empty():
		test.check(false, "een frietkar met een verkoper")
		return
	var cart: Node3D = vendors.carts()[0]
	var facing := cart.global_basis.z
	var to_camera := Vector3(Iso.DIRECTION.x, 0.0, Iso.DIRECTION.z).normalized()
	test.check(facing.dot(Vector3.FORWARD) > 0.99, "het luik op het noorden (%s)" % facing)
	test.check(facing.dot(to_camera) > 0.5, "een kant die de camera ziet")
	test.check(seller.global_basis.z.dot(facing) > 0.99, "de verkoper kijkt het luik uit")
	var inside := cart.to_local(seller.global_position)
	var box: AABB = (cart.get_node("Model") as MeshInstance3D).mesh.get_aabb()
	test.check(absf(inside.x) < box.size.x * 0.4 and absf(inside.z) < box.size.z * 0.4 and inside.y > 0.5,
		"de verkoper staat ín de kar, op de vloer (%s)" % inside)
	var counter: Vector3 = seller.talk_position()
	test.check((counter - cart.global_position).dot(facing) > 0.9, "besteld wordt vóór de kar")
	# before the counter, a passer-by close by: still the seller
	player.global_position = Vector3(counter.x, player.global_position.y, counter.z) + facing * 1.0
	player.rotation.y = atan2(-facing.x, -facing.z)
	await frames(3)
	test.check(player._talk_partner == seller, "voor de toonbank: [E] bij de verkoper")
	var mark: Node3D = seller._mark
	var top := (cart.get_node("Model") as MeshInstance3D).mesh.get_aabb().end.y
	test.check(mark != null and mark.bottom + seller.global_position.y > top + cart.global_position.y
		and (mark.global_position - cart.global_position).dot(facing) > -0.1,
		"de pijl boven de kar, niet erachter")
