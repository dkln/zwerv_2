extends RefCounted
## The plan of the city hall on the Spui (scenes/binnen/stadhuis.tscn): five floors, each a
## size and a layout of its own, joined by one lift. One source for the builder
## (tools/build/build_interiors.gd, which puts it into the scene, editable by hand after) and
## the checks (tests/integration/interiors/test_city_hall.gd).
##   0  the hall: the entrance, the reception desk with the coat of arms behind it, a waiting
##      corner, an information pillar, the security guard by the door;
##   1  Burgerzaken: four counters along the back wall, rows of waiting chairs before them,
##      the machine you take a number from, the board of who is next;
##   2  the open-plan office: islands of four desks, filing cabinets, a copier, the coffee
##      machine with people standing at it;
##   3  the meeting rooms behind glass along the back (one in a meeting), the archive in
##      front (rows of cabinets);
##   4  the council chamber, smaller (the top of the building steps back): the chair's
##      bench with the coat of arms and the flags, the council's desks in a U, the public
##      gallery at the front.
## Every floor: x from -width/2 (the high left wall) to +width/2 (the low right one), z from
## -depth/2 (the low front, where the camera looks in from) to +depth/2 (the high back). The
## lift stands against the back wall at LIFT_X on every floor (it is one shaft), you call it
## at its spot before its doors. Tiles of the library binnen (without "stadhuis/"), on the
## 0.5 m grid, turned by `turn` (their front then faces (sin turn, 0, cos turn)).

const FLOORS := 5
## Where the floors lie in the scene, side by side (one is shown at a time): floor n at
## x = n * FLOOR_SPACING.
const FLOOR_SPACING := 80.0
const CELL := 4.0
const LIFT_X := -8.0
## The lift tile is 2 m deep against the back wall; you stand this far before its front.
const LIFT_DEPTH := 2.0
const LIFT_STAND := 1.1
## The seats (metres): a waiting bench, an office chair, the chair behind a counter, the
## front and back row of the public gallery.
const BENCH_SEAT := 0.625
const CHAIR_SEAT := 0.625
const COUNTER_SEAT := 0.5
const GALLERY_SEATS := [0.5, 0.75]
const NAMES := ["Hal en receptie", "Burgerzaken", "Kantoortuin", "Vergaderzalen en archief", "Raadzaal"]


## Every floor: {"number", "name", "width", "depth", "floor" (its tile), "tiles": [[tile, at,
## turn]], "wall_tiles": [[tile, at (on the wall's grid line), turn]] (hung by WallMount),
## "lift": Vector3 (the lift tile), "lift_spot": Vector3 (where you call it),
## "people": [{"role", "at", "turn", "sit", "seat"}], "signs": [{"at", "turn", "text"}],
## "counters": [{"number", "board_at"}] (Burgerzaken: the number boards), "dispenser":
## Vector3 (where you take a number, or none), "door": Vector3 (floor 0: inside the
## entrance, facing in), "lamps": [Vector3]}.
static func floors() -> Array[Dictionary]:
	var all: Array[Dictionary] = [_hall(), _civil_affairs(), _office(), _meeting_rooms(), _council_chamber()]
	return all


static func _floor(number: int, width: float, depth: float, floor_tile: String) -> Dictionary:
	var plan := {"number": number, "name": NAMES[number], "width": width, "depth": depth, "floor": floor_tile,
		"tiles": [], "wall_tiles": [], "people": [], "signs": [], "counters": [], "lamps": []}
	var left := -width * 0.5
	var back := depth * 0.5
	var front := -depth * 0.5
	var lift := Vector3(LIFT_X, 0.0, back - LIFT_DEPTH * 0.5)
	plan["lift"] = lift
	plan["lift_spot"] = Vector3(LIFT_X, 0.0, back - LIFT_DEPTH - LIFT_STAND)
	_tile(plan, "lift", lift, PI)
	for column in int(width / CELL):
		var x := left + CELL * 0.5 + column * CELL
		if absf(x - LIFT_X) > 0.1:
			_tile(plan, "muur", Vector3(x, 0.0, back), PI)
		if not (number == 0 and absf(x) < 0.1):
			_tile(plan, "muur_laag", Vector3(x, 0.0, front), 0.0)
	for row in int(depth / CELL):
		var z := front + CELL * 0.5 + row * CELL
		_tile(plan, "muur", Vector3(left, 0.0, z), PI * 0.5)
		_tile(plan, "muur_laag", Vector3(-left, 0.0, z), -PI * 0.5)
	var across := maxi(2, roundi(width / 8.0))
	var deep := maxi(2, roundi(depth / 8.0))
	for column in across:
		for row in deep:
			plan.lamps.append(Vector3(left + width * (column + 0.5) / across, 3.6, front + depth * (row + 0.5) / deep))
	return plan


## 0: the hall, 40 x 28 m, white stone.
static func _hall() -> Dictionary:
	var plan := _floor(0, 40.0, 28.0, "vloer_steen")
	var left := -20.0
	var right := 20.0
	var front := -14.0
	var back := 14.0
	# the entrance in the middle of the front, the mat inside it
	for side in [-1.0, 1.0]:
		_tile(plan, "muur_laag_half", Vector3(side * 1.5, 0.0, front), 0.0)
	_tile(plan, "deurmat", Vector3(0.0, 0.0, front + 0.75), 0.0)
	plan["door"] = Vector3(0.0, 0.0, front + 0.9)
	# the reception desk in the middle facing the entrance, the coat of arms and the flags on
	# the back wall behind it
	for x in [-2.0, 2.0]:
		_tile(plan, "receptie", Vector3(x, 0.0, 0.5), PI)
	_person(plan, "receptioniste", Vector3(-1.5, 0.0, 1.6), PI)
	_person(plan, "receptioniste", Vector3(2.5, 0.0, 1.6), PI)
	_wall_tile(plan, "wapen", Vector3(0.0, 1.5, back), PI)
	for x in [-3.0, 3.0]:
		_tile(plan, "vlag", Vector3(x, 0.0, back - 0.5), PI)
	plan.signs.append({"at": Vector3(0.0, 2.9, 0.0), "turn": PI, "text": "RECEPTIE"})
	# the guard by the door
	_person(plan, "beveiliger", Vector3(3.0, 0.0, front + 2.0), -PI * 0.5)
	# the waiting corner on the right: benches facing the middle, people on some
	var seats := 0
	for row in 4:
		var z := -8.0 + row * 3.0
		for x in [10.0, 14.0]:
			_tile(plan, "wachtbank", Vector3(x, 0.0, z), 0.0)
			for seat in [-0.75, 0.25]:
				seats += 1
				if seats % 3 != 0:
					_person(plan, "klant", Vector3(x + seat, 0.0, z), 0.0, true, BENCH_SEAT)
	for corner in [Vector3(right - 1.5, 0.0, front + 1.5), Vector3(right - 1.5, 0.0, back - 1.5), Vector3(left + 1.5, 0.0, front + 1.5)]:
		_tile(plan, "plant", corner, 0.0)
	_tile(plan, "infozuil", Vector3(-3.5, 0.0, front + 3.0), 0.0)
	_tile(plan, "infozuil", Vector3(-12.0, 0.0, -4.0), 0.0)
	for z in [-6.0, 0.0, 6.0]:
		_wall_tile(plan, "schilderij", Vector3(left, 1.5, z), PI * 0.5)
	# visitors about in the hall
	_person(plan, "klant", Vector3(-1.0, 0.0, -2.2), 0.0)
	_person(plan, "klant", Vector3(-8.0, 0.0, 7.5), PI)
	_person(plan, "klant", Vector3(6.0, 0.0, -9.0), PI * 0.5)
	plan.signs.append({"at": Vector3(LIFT_X, 3.3, back - LIFT_DEPTH - 0.1), "turn": PI, "text": "LIFT"})
	return plan


## 1: Burgerzaken, 48 x 30 m (busy): eight counters along the back (round the lift), five rows of
## waiting benches before them, most seats taken (the visitors wait for their number:
## CityHall's queue), a number machine at the front on the left and the waiting board on the
## left wall (CityHall makes it).
const COUNTERS_X := [-20.0, -15.5, -3.5, 1.0, 5.5, 10.0, 14.5, 19.0]
const BENCH_ROWS_Z := [-11.0, -8.5, -6.0, -3.5, -1.0]
const BENCHES_X := [-12.0, -6.0, 0.0, 6.0, 12.0]
static func _civil_affairs() -> Dictionary:
	var plan := _floor(1, 48.0, 30.0, "vloer_steen")
	var left := -24.0
	var right := 24.0
	var front := -15.0
	var back := 15.0
	var number := 1
	for x: float in COUNTERS_X:
		_tile(plan, "loket", Vector3(x, 0.0, back - 1.0), PI)
		# at the counter: the clerk of Burgerzaken (personeel.json "loketmedewerker": the ID card)
		_person(plan, "loketmedewerker", Vector3(x, 0.0, back - 0.4), PI, true, COUNTER_SEAT)
		plan.counters.append({"number": number, "board_at": Vector3(x, 2.0, back - 1.62)})
		number += 1
	# the waiting benches in rows facing the counters, three of every four seats taken
	var seats := 0
	for z: float in BENCH_ROWS_Z:
		for x: float in BENCHES_X:
			_tile(plan, "wachtbank", Vector3(x, 0.0, z), 0.0)
			for seat in [-0.75, 0.25]:
				seats += 1
				if seats % 4 != 0:
					_person(plan, "klant", Vector3(x + seat, 0.0, z), 0.0, true, BENCH_SEAT)
	# a few standing about, waiting too
	_person(plan, "klant", Vector3(-18.0, 0.0, -2.0), PI * 0.5)
	_person(plan, "klant", Vector3(18.5, 0.0, -4.0), -PI * 0.5)
	_person(plan, "klant", Vector3(17.0, 0.0, -9.0), -PI * 0.5)
	plan["dispenser"] = Vector3(-20.0, 0.0, -12.1)
	_tile(plan, "nummerautomaat", Vector3(-20.0, 0.0, -13.0), 0.0)
	plan.signs.append({"at": Vector3(-20.0, 2.2, -13.0), "turn": PI, "text": "NUMMERTJE"})
	plan.signs.append({"at": Vector3(5.5, 3.2, 8.0), "turn": PI, "text": "BURGERZAKEN"})
	# a coffee corner at the front on the right: the machine, a table, benches round it
	_tile(plan, "koffieautomaat", Vector3(right - 1.0, 0.0, front + 4.0), -PI * 0.5)
	_tile(plan, "bureau", Vector3(right - 4.5, 0.0, front + 4.0), 0.0)
	_tile(plan, "wachtbank", Vector3(right - 4.5, 0.0, front + 2.0), 0.0)
	_tile(plan, "wachtbank", Vector3(right - 4.5, 0.0, front + 6.0), PI)
	_person(plan, "klant", Vector3(right - 4.75, 0.0, front + 2.0), 0.0, true, BENCH_SEAT)
	_person(plan, "klant", Vector3(right - 3.5, 0.0, front + 6.25), PI)
	# bins: by the coffee machine, by the number machine and at the ends of the bench rows
	for spot: Vector3 in [Vector3(right - 1.0, 0.0, front + 2.5), Vector3(-18.5, 0.0, -13.0),
			Vector3(-15.0, 0.0, -6.0), Vector3(15.0, 0.0, -6.0), Vector3(-15.0, 0.0, -1.0), Vector3(15.0, 0.0, -1.0)]:
		_tile(plan, "prullenbak", spot, 0.0)
	# an information pillar by the way in from the lift, where you look for your way
	_tile(plan, "infozuil", Vector3(-12.0, 0.0, 9.0), PI * 0.75)
	# more benches along the left wall, empty: room enough to wait
	for z: float in [-6.0, -1.0, 4.0]:
		_tile(plan, "wachtbank", Vector3(left + 1.2, 0.0, z), PI * 0.5)
	# plants along the walls and between the counters
	for spot: Vector3 in [Vector3(right - 1.5, 0.0, front + 1.5), Vector3(left + 1.5, 0.0, front + 1.5),
			Vector3(-8.0 + 2.5, 0.0, back - 1.2), Vector3(-8.0 - 2.5, 0.0, back - 1.2), Vector3(right - 1.2, 0.0, 6.0),
			Vector3(right - 1.2, 0.0, -1.0), Vector3(left + 1.2, 0.0, 9.0), Vector3(0.0, 0.0, front + 1.2),
			Vector3(-14.0, 0.0, front + 1.2), Vector3(14.0, 0.0, front + 1.2)]:
		_tile(plan, "plant", spot, 0.0)
	_tile(plan, "kast", Vector3(left + 0.5, 0.0, 12.5), PI * 0.5)
	_wall_tile(plan, "schilderij", Vector3(left, 1.5, -4.0), PI * 0.5)
	return plan


## 2: the open-plan office, 40 x 32 m, carpet: nine islands of four desks.
static func _office() -> Dictionary:
	var plan := _floor(2, 40.0, 32.0, "vloer_tapijt")
	var left := -20.0
	var right := 20.0
	var front := -16.0
	var back := 16.0
	var taken := 0
	for island_x in [-2.0, 6.0, 14.0]:
		for island_z in [-9.0, -1.0, 7.0]:
			for side in [-1.0, 1.0]:
				var desk_x: float = island_x + side * 1.0
				# the desk on the front side faces +z with its person on the front, the one
				# behind faces -z: back to back, screen to screen
				_tile(plan, "bureau", Vector3(desk_x, 0.0, island_z - 0.5), PI)
				_tile(plan, "bureau", Vector3(desk_x, 0.0, island_z + 0.5), 0.0)
				_tile(plan, "bureaustoel", Vector3(desk_x, 0.0, island_z - 1.5), 0.0)
				_tile(plan, "bureaustoel", Vector3(desk_x, 0.0, island_z + 1.5), PI)
				taken += 1
				if taken % 4 != 0:
					_person(plan, "ambtenaar", Vector3(desk_x, 0.0, island_z - 1.5), 0.0, true, CHAIR_SEAT)
				if taken % 3 != 1:
					_person(plan, "ambtenaar", Vector3(desk_x, 0.0, island_z + 1.5), PI, true, CHAIR_SEAT)
	for z in [-12.0, -8.0, -4.0, 0.0]:
		_tile(plan, "kast", Vector3(left + 0.5, 0.0, z), PI * 0.5)
	_tile(plan, "printer", Vector3(-8.0, 0.0, front + 1.5), 0.0)
	# the coffee corner by the lift, two people standing there
	_tile(plan, "koffieautomaat", Vector3(left + 4.0, 0.0, back - 1.5), PI)
	_person(plan, "ambtenaar", Vector3(left + 4.5, 0.0, back - 3.2), PI * 0.8)
	_person(plan, "ambtenaar", Vector3(left + 3.4, 0.0, back - 3.6), PI * 0.6)
	plan.signs.append({"at": Vector3(left + 4.0, 2.3, back - 1.4), "turn": PI, "text": "KOFFIE"})
	for corner in [Vector3(right - 1.5, 0.0, front + 1.5), Vector3(right - 1.5, 0.0, back - 1.5), Vector3(-11.5, 0.0, front + 1.5)]:
		_tile(plan, "plant", corner, 0.0)
	return plan


## 3: the meeting rooms (behind glass along the back) and the archive in front, 40 x 28 m.
static func _meeting_rooms() -> Dictionary:
	var plan := _floor(3, 40.0, 28.0, "vloer_tapijt")
	var left := -20.0
	var right := 20.0
	var front := -14.0
	var glass_z := 4.0
	# the glass fronts of the rooms (x -4..20), each with a door, and the walls between them
	for room_left in [-4.0, 4.0, 12.0]:
		# 4 m of glass, then 1.25 m, the door of 1.5 m, 1.25 m
		_tile(plan, "glaswand", Vector3(room_left + 2.0, 0.0, glass_z), 0.0)
		_tile(plan, "glaswand_kort", Vector3(room_left + 4.625, 0.0, glass_z), 0.0)
		_tile(plan, "glaswand_kort", Vector3(room_left + 7.375, 0.0, glass_z), 0.0)
	for divider_x in [-4.0, 4.0, 12.0]:
		for z in [glass_z + 2.0, glass_z + 6.0]:
			_tile(plan, "glaswand", Vector3(divider_x, 0.0, z), PI * 0.5)
	# room A: a meeting under way; room B: empty but for one; room C: empty
	for room_middle in [0.0, 8.0, 16.0]:
		_tile(plan, "vergadertafel", Vector3(room_middle, 0.0, glass_z + 4.0), 0.0)
		for seat_x in [-1.5, 0.0, 1.5]:
			_tile(plan, "bureaustoel", Vector3(room_middle + seat_x, 0.0, glass_z + 2.75), 0.0)
			_tile(plan, "bureaustoel", Vector3(room_middle + seat_x, 0.0, glass_z + 5.25), PI)
	for seat_x in [-1.5, 0.0, 1.5]:
		_person(plan, "ambtenaar", Vector3(seat_x, 0.0, glass_z + 2.75), 0.0, true, CHAIR_SEAT)
	for seat_x in [-1.5, 1.5]:
		_person(plan, "ambtenaar", Vector3(seat_x, 0.0, glass_z + 5.25), PI, true, CHAIR_SEAT)
	_person(plan, "ambtenaar", Vector3(9.5, 0.0, glass_z + 5.25), PI, true, CHAIR_SEAT)
	plan.signs.append({"at": Vector3(0.0, 2.95, glass_z - 0.1), "turn": PI, "text": "ZAAL HOFVIJVER"})
	plan.signs.append({"at": Vector3(8.0, 2.95, glass_z - 0.1), "turn": PI, "text": "ZAAL SPUI"})
	plan.signs.append({"at": Vector3(16.0, 2.95, glass_z - 0.1), "turn": PI, "text": "ZAAL PLEIN"})
	# the archive in front: rows of cabinets, an aisle between each pair
	for row_z in [-11.5, -8.25, -7.75, -4.5]:
		for x in [2.0, 6.0, 10.0, 14.0]:
			_tile(plan, "kast", Vector3(x, 0.0, row_z), PI if row_z == -8.25 else 0.0)
	_tile(plan, "kast", Vector3(left + 2.0, 0.0, front + 0.5), 0.0)
	_person(plan, "ambtenaar", Vector3(8.0, 0.0, -10.0), PI)
	plan.signs.append({"at": Vector3(8.0, 2.8, -10.0), "turn": PI, "text": "ARCHIEF"})
	_tile(plan, "printer", Vector3(left + 1.5, 0.0, -2.0), PI * 0.5)
	_tile(plan, "plant", Vector3(-6.5, 0.0, 2.5), 0.0)
	_tile(plan, "plant", Vector3(right - 1.5, 0.0, 1.0), 0.0)
	return plan


## 4: the council chamber, 28 x 28 m, oak: the chair's bench at the back, the council's
## desks in a U before it, the public gallery at the front.
static func _council_chamber() -> Dictionary:
	var plan := _floor(4, 28.0, 28.0, "vloer_parket")
	var left := -14.0
	var back := 14.0
	var front := -14.0
	_tile(plan, "voorzittersbank", Vector3(0.0, 0.0, back - 2.25), PI)
	_person(plan, "burgemeester", Vector3(0.0, 0.25, back - 1.9), PI)
	_wall_tile(plan, "wapen", Vector3(0.0, 1.5, back), PI)
	for x in [-3.5, 3.5]:
		_tile(plan, "vlag", Vector3(x, 0.0, back - 0.5), PI)
	# the U: a row each side facing the middle, one across the front facing the bench
	for z in [-0.5, 3.5, 7.5]:
		_tile(plan, "raadstafel", Vector3(-6.5, 0.0, z), PI * 0.5)
		_tile(plan, "raadstafel", Vector3(6.5, 0.0, z), -PI * 0.5)
		for seat in [-1.375, 0.0, 1.375]:
			_tile(plan, "bureaustoel", Vector3(-7.5, 0.0, z + seat), PI * 0.5)
			_tile(plan, "bureaustoel", Vector3(7.5, 0.0, z + seat), -PI * 0.5)
			_person(plan, "raadslid", Vector3(-7.5, 0.0, z + seat), PI * 0.5, true, CHAIR_SEAT)
			_person(plan, "raadslid", Vector3(7.5, 0.0, z + seat), -PI * 0.5, true, CHAIR_SEAT)
	var front_seat := 0
	for x in [-4.0, 0.0, 4.0]:
		_tile(plan, "raadstafel", Vector3(x, 0.0, -3.5), 0.0)
		for seat in [-1.375, 0.0, 1.375]:
			_tile(plan, "bureaustoel", Vector3(x + seat, 0.0, -4.5), 0.0)
			front_seat += 1
			if front_seat % 4 != 3:
				_person(plan, "raadslid", Vector3(x + seat, 0.0, -4.5), 0.0, true, CHAIR_SEAT)
	# the public gallery
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_tile(plan, "tribune", Vector3(x, 0.0, front + 4.0), 0.0)
	# the front row of the gallery (low) is 0.75 m before its middle, the back row (on a step)
	# 0.25 m behind it
	for index in 8:
		var row := index % 2
		_person(plan, "klant", Vector3(-9.0 + index * 2.6, 0.0, front + 4.75 - row * 1.0), 0.0, true, GALLERY_SEATS[row])
	plan.signs.append({"at": Vector3(0.0, 3.4, front + 5.1), "turn": PI, "text": "PUBLIEKE TRIBUNE"})
	for z in [2.0, 8.0]:
		_wall_tile(plan, "schilderij", Vector3(left, 1.5, z), PI * 0.5)
	return plan


## Where the lift (scenes/binnen/lift.tscn, scripts/world/interiors/lift_ride.gd) stands in the scene:
## beside the floors, out of sight of them.
const CABIN_AT := Vector3(FLOORS * FLOOR_SPACING, 0.0, 0.0)


static func _tile(plan: Dictionary, tile_name: String, at: Vector3, turn: float) -> void:
	plan.tiles.append([tile_name, at, turn])


## A tile that hangs on the wall whose grid line runs through `at` (WallMount: just before
## its inner surface, not half in it).
static func _wall_tile(plan: Dictionary, tile_name: String, at: Vector3, turn: float) -> void:
	plan.wall_tiles.append([tile_name, at, turn])


static func _person(plan: Dictionary, role: String, at: Vector3, turn: float, sit := false, seat := 0.0) -> void:
	plan.people.append({"role": role, "at": at, "turn": turn, "sit": sit, "seat": seat})
