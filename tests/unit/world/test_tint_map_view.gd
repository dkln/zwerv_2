extends RefCounted
## Unit tests of the picture of the tint map (scripts/world/town/tint_map_view.gd): an empty
## map has no tint, a tint is stored at half intensity with its strength, and it is handed
## to the shaders.

const TintMapView = preload("res://scripts/world/town/tint_map_view.gd")


## True for a pixel without tint (grey, no strength), as 8 bits store it.
func _is_no_tint(pixel: Color) -> bool:
	return absf(pixel.r - TintMapView.NO_TINT.r) < 0.01 and absf(pixel.g - TintMapView.NO_TINT.g) < 0.01 \
			and absf(pixel.b - TintMapView.NO_TINT.b) < 0.01 and pixel.a < 0.01


## A new map has no tint anywhere.
func test_a_new_map_has_no_tint(test) -> void:
	var view := TintMapView.new()
	test.check(view.map_size() == Vector2i.ZERO, "voor het begin: geen kaart")
	view.start(Vector2i(4, 3))
	test.check(view.map_size() == Vector2i(4, 3), "de kaart zo groot als gevraagd")
	test.check(_is_no_tint(view.tint_at(Vector2i(2, 1))), "overal geen tint")


## A tint is stored at half its intensity (so twice as bright still fits), never over 1.
func test_a_tint_is_stored_at_half_intensity(test) -> void:
	var stored := TintMapView.stored_tint(Color(1.0, 0.5, 0.2), 1.0, 0.75)
	test.check(stored.is_equal_approx(Color(0.5, 0.25, 0.1, 0.75)), "de helft, de sterkte in de alfa (%s)" % stored)
	var bright := TintMapView.stored_tint(Color(1.0, 0.5, 0.2), 2.0, 1.0)
	test.check(bright.is_equal_approx(Color(1.0, 0.5, 0.2, 1.0)), "twee keer zo licht past nog (%s)" % bright)
	var too_bright := TintMapView.stored_tint(Color(2.0, 2.0, 2.0), 2.0, 1.0)
	test.check(too_bright.r <= 1.0 and too_bright.g <= 1.0 and too_bright.b <= 1.0, "nooit meer dan 1")


## Only the cells given get the tint; a later tint lies on top.
func test_the_cells_given_get_the_tint(test) -> void:
	var view := TintMapView.new()
	view.start(Vector2i(4, 4))
	view.show_tint([Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i], Color(1.0, 0.0, 0.0), 1.0, 1.0)
	test.check(view.tint_at(Vector2i(1, 1)).r > 0.45 and view.tint_at(Vector2i(1, 1)).g < 0.05, "de cel is rood getint")
	test.check(_is_no_tint(view.tint_at(Vector2i(0, 0))), "de cel ernaast niet")
	view.show_tint([Vector2i(1, 1)] as Array[Vector2i], Color(0.0, 0.0, 1.0), 1.0, 1.0)
	test.check(view.tint_at(Vector2i(1, 1)).b > 0.45 and view.tint_at(Vector2i(1, 1)).r < 0.05, "een latere tint ligt erbovenop")
	view.publish(Vector4(0.0, 0.0, 16.0, 16.0), 0.25)
	view.publish(Vector4(0.0, 0.0, 16.0, 16.0), 0.25)
	test.check(view.map_size() == Vector2i(4, 4), "doorgegeven aan de shaders, twee keer achter elkaar")
