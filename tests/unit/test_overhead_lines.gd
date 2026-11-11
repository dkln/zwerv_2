extends RefCounted
## Unit tests of the overhead lines (scripts/world/overhead_lines.gd): where a point lies on a
## piece of wire, the key that joins the pieces, where a mast's span crosses the wires (only
## across, within its reach), and how the carrier wire hangs: carrier_rise above the level
## contact wire at a support, sagging deepest halfway between two supports, none past the last.

const OverheadLines = preload("res://scripts/world/overhead_lines.gd")


func _lines() -> Node3D:
	var lines: Node3D = OverheadLines.new()
	lines.buildings = NodePath()   # no buildings over the track
	return lines


## A straight contact wire along x at `height`, from x 0 to `length`, in pieces of 1 m, by cell.
func _straight_wire(length: int, height: float) -> Dictionary:
	var wire_lines := {}
	for metre in length:
		var cell := Vector3i(floori(metre / RoadNetwork.CELL), 0, 0)
		wire_lines.get_or_add(cell, []).append([Vector3(metre, height, 2.0), Vector3(metre + 1, height, 2.0)])
	return wire_lines


func test_where_a_point_lies_on_a_piece(test) -> void:
	var start := Vector3(0, 5, 0)
	var end := Vector3(4, 5, 0)
	test.check(is_equal_approx(OverheadLines._share_along(start, end, Vector3(1, 5, 0)), 0.25), "een kwart erover")
	test.check(OverheadLines._share_along(start, end, Vector3(5, 5, 0)) < 0.0, "voorbij het eind: niet erop")
	test.check(OverheadLines._share_along(start, end, Vector3(2, 5, 0.5)) < 0.0, "ernaast: niet erop")
	test.check(OverheadLines._share_along(start, start, start) < 0.0, "een stuk zonder lengte: niets")


func test_pieces_meet_on_one_key(test) -> void:
	test.check(OverheadLines._point_key(Vector3(1.0, 5.5, 2.0)) == OverheadLines._point_key(Vector3(1.004, 5.5, 2.003)),
		"bijna hetzelfde punt: dezelfde sleutel")
	test.check(OverheadLines._point_key(Vector3(1.0, 5.5, 2.0)) != OverheadLines._point_key(Vector3(1.1, 5.5, 2.0)),
		"10 cm verder: een andere")


func test_a_span_crosses_the_wires_across(test) -> void:
	var lines := _lines()
	var wire_lines := {Vector3i(0, 0, 1): [[Vector3(0, 5.5, 6.0), Vector3(4, 5.5, 6.0)]],    # across the span, 5 m out
		Vector3i(0, 0, 4): [[Vector3(0, 5.5, 18.0), Vector3(4, 5.5, 18.0)]],                  # across, but 17 m out
		Vector3i(1, 0, 0): [[Vector3(5.0, 5.5, 0.5), Vector3(5.0, 5.5, 3.5)]]}                # along the span
	var crossings: Array = lines._crossings(Vector2(2, 1), Vector2(0, 1), 0.0, wire_lines)
	test.check(crossings.size() == 1, "één draad gekruist (%d)" % crossings.size())
	if crossings.size() == 1:
		test.check((crossings[0] as Vector3).is_equal_approx(Vector3(2, 5.5, 6.0)), "recht tegenover de mast (%s)" % crossings[0])
	lines.free()


func test_the_carrier_wire_sags_between_supports(test) -> void:
	var lines := _lines()
	var height := 5.5
	var wire_lines := _straight_wire(40, height)
	var supports := [Vector3(10, height, 2.0), Vector3(30, height, 2.0)]
	var drawn: Array = lines._hang(wire_lines, supports)
	var carrier_at := {}   # x -> height of the carrier wire there
	var contact_level := true
	for line: Array in drawn:
		var from: Vector3 = line[0]
		var to: Vector3 = line[1]
		if is_equal_approx(from.y, height) and is_equal_approx(to.y, height):
			continue   # the contact wire
		if is_equal_approx(from.x, to.x) and is_equal_approx(from.z, to.z):
			continue   # a dropper
		if from.y < height - 0.01 or to.y < height - 0.01:
			contact_level = false
		carrier_at[roundi(from.x)] = from.y
		carrier_at[roundi(to.x)] = to.y
	test.check(contact_level, "de rijdraad blijft vlak, de draagkabel erboven")
	test.check(carrier_at.has(10) and is_equal_approx(carrier_at[10], height + lines.carrier_rise),
		"bij een ophangpunt %.1f m boven de rijdraad" % lines.carrier_rise)
	var sag_expected: float = 4.0 * lines.sag / (lines.typical_span * lines.typical_span) * 10.0 * 10.0
	test.check(carrier_at.has(20) and is_equal_approx(carrier_at[20], height + lines.carrier_rise - sag_expected),
		"halverwege het diepst (%.2f m doorhang)" % sag_expected)
	test.check(carrier_at.has(15) and carrier_at[15] > carrier_at[20] and carrier_at[15] < carrier_at[10], "ertussen ertussenin")
	var droppers := drawn.filter(func(line: Array) -> bool:
		return is_equal_approx(line[0].x, line[1].x) and not is_equal_approx(line[0].y, line[1].y))
	test.check(droppers.size() >= 5, "hangers tussen draagkabel en rijdraad (%d)" % droppers.size())
	lines.free()


func test_one_support_hangs_no_carrier(test) -> void:
	var lines := _lines()
	var drawn: Array = lines._hang(_straight_wire(12, 5.5), [Vector3(4, 5.5, 2.0)])
	test.check(drawn.all(func(line: Array) -> bool: return is_equal_approx(line[0].y, 5.5) and is_equal_approx(line[1].y, 5.5)),
		"met één ophangpunt alleen de rijdraad")
	lines.free()


func test_no_carrier_wire_past_the_last_support(test) -> void:
	var lines := _lines()
	var height := 5.5
	var drawn: Array = lines._hang(_straight_wire(40, height), [Vector3(10, height, 2.0), Vector3(30, height, 2.0)])
	var carrier_xs := []
	for line: Array in drawn:
		for point: Vector3 in [line[0], line[1]]:
			if point.y > height + 0.01:
				carrier_xs.append(point.x)
	test.check(not carrier_xs.is_empty() and carrier_xs.min() >= 10.0 - 0.01 and carrier_xs.max() <= 30.0 + 0.01,
		"draagkabel alleen tussen de ophangpunten (x %.1f tot %.1f)" % [carrier_xs.min(), carrier_xs.max()])
	lines.free()
