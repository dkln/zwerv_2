extends Control
## Main menu, part 1 (see main_menu.gd): the living 3D map behind the menu: shown when it
## has loaded, laid out in copies left and right so the camera can glide on and on, with
## columns of traffic (protesters, police, fires and crashes), the tram, the helicopter
## flying in, and the moon.

const ProtestFlag = preload("res://scripts/vehicles/protest_flag.gd")
const DeathBlink = preload("res://scripts/effects/death_blink.gd")
const VehicleFire = preload("res://scripts/effects/vehicle_fire.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The baked 3D map behind the menu (tools/build/build_menu_map.gd), loaded in the
## background, and the seconds in which it fades in over the drawn backdrop.
const MAP_SCENE := "res://scenes/menu_kaart.scn"
const MAP_FADE_SECONDS := 1.5

## The skyline glides by on and on: the camera of the map moves sideways at this speed
## (metres a second); the map repeats sideways (its metadata "periode": copies are laid
## left and right of it), and after one period the camera jumps back unseen.
@export var pan_speed := 2.5
## Without a repeating map (no "periode"): the camera sways this many metres each way and
## back in this many seconds.
const SWAY_METRES := 25.0
const SWAY_SECONDS := 90.0
## Copies of the map each side of it (by period): enough to fill the view as it glides.
const COPIES_LEFT := 2
const COPIES_RIGHT := 1
## Nodes of the map that are not copied (there once: light, sky, time, camera, the ground
## plane under it all, the moon, the trams themselves).
const NOT_COPIED := ["Omgeving", "Zon", "Vullicht", "Dagcyclus", "Camera", "Grondvlak", "Maan",
	"Rook", "Tunnelverlichting", "Bovenleiding"]
## The town's helpers that draw in world positions (not by their parent): a copy gets only
## what they made, shared (the wires of the Bovenleiding, overhead_lines.gd).
const COPIED_MADE := {"Bovenleiding": "Draden"}
const MENU_ITEM_HEIGHT := 44.0
const MENU_WIDTH := 360.0

var _loading := false
var _sky: ColorRect               # the drawn night sky (until the 3D map is there)
var _backdrop: Control            # what is drawn before the 3D map is there (now nothing)
var _opened_on_frame := 0

var _map_camera: Camera3D
var _camera_start := Transform3D.IDENTITY
var _panned := 0.0                # metres the camera has glided (0 .. the period)
var _period := 0.0                # metres after which the map repeats (0: no gliding)


## Puts the loaded 3D map behind the menu, its camera drifting, a moon in its sky, and fades
## the night colour out over it; a shade on the left keeps the text readable.
func _show_map(packed: PackedScene) -> void:
	if packed == null or _loading:
		return
	# loaded in the intro (there on the first frame): no fade, it is simply there
	var seconds := MAP_FADE_SECONDS if Engine.get_process_frames() - _opened_on_frame > 2 else 0.0
	var map := packed.instantiate()
	map.name = "Menukaart"
	get_parent().add_child(map)
	get_parent().move_child(map, 0)
	_map_camera = map.get_node_or_null("Camera") as Camera3D
	if _map_camera:
		_map_camera.current = true
		_camera_start = _map_camera.transform

	# time flies in the menu: the whole day in about a minute, starting at sunset
	_day_cycle = map.get_node_or_null("Dagcyclus")
	if _day_cycle:
		_day_cycle.set("speed", MENU_HOURS_PER_SECOND)
		_day_cycle.set("daylight_slowdown", 1.0)   # the menu shows the whole day evenly
		_day_cycle.set("night_speedup", 1.0)
		_day_cycle.call("set_time", MENU_START_HOUR)
	_period = float(map.get_meta("periode", 0.0))
	if _period > 0.0:
		_lay_copies(map)
	_add_moon(map)
	# a police helicopter circling over the skyline (after the copies: there is one)
	_helicopter = PoliceHelicopter.new()
	_helicopter.set("day_cycle", _day_cycle)
	_helicopter.set("circle_radius", HELICOPTER_CIRCLE.x)
	_helicopter.set("circle_height", HELICOPTER_CIRCLE.y)
	_helicopter.set("circle_speed", HELICOPTER_CIRCLE.z)
	map.add_child(_helicopter)
	_place_helicopter_circle()
	# it opens the menu flying in close past the camera (_fly_helicopter_entry)
	_helicopter.set("circling", false)
	_helicopter_entry = 0.0
	_fly_helicopter_entry(0.0)
	_set_up_columns(map)
	# now and then a big fire in the skyline round Centraal (the first after 12 s; more
	# as the chaos grows)
	_fires.clear()
	_menu_seconds = 0.0
	_fires.append(_make_fire(map, -1.0))
	# a floor on the grass for the wrecks of a crash
	var floor_body := StaticBody3D.new()
	floor_body.name = "Vloer"
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_shape.position = Vector3(0, COLUMN_GROUND, 0)
	floor_body.add_child(floor_shape)
	map.add_child(floor_body)
	_trams.clear()
	for line in map.get_children():
		var tram := line.get_node_or_null("Tram") as Node3D
		if tram:
			_trams.append({"tram": tram, "wait": randf_range(TRAM_FIRST_WAIT.x, TRAM_FIRST_WAIT.y) * (_trams.size() + 1),
				"travelled": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO})
	var shade := _left_shade()
	shade.modulate.a = 0.0
	add_child(shade)
	move_child(shade, 1)
	if seconds <= 0.0:
		# loaded in the intro: there at once (the swipe from the intro shows it, no fade of its own)
		_sky.modulate.a = 0.0
		_backdrop.modulate.a = 0.0
		shade.modulate.a = 1.0
		return
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_sky, "modulate:a", 0.0, seconds)
	fade.tween_property(_backdrop, "modulate:a", 0.0, seconds)
	fade.tween_property(shade, "modulate:a", 1.0, seconds)


## Lays copies of the map's geometry (not NOT_COPIED; the rails but not the trams) a period
## left and right of it, so the view stays full as the camera glides on.
func _lay_copies(map: Node) -> void:
	var copies := Node3D.new()
	copies.name = "Herhaling"
	map.add_child(copies)
	for offset in range(-COPIES_LEFT, COPIES_RIGHT + 1):
		if offset == 0:
			continue
		var copy := Node3D.new()
		copy.name = "Kopie%d" % offset
		copy.position = Vector3(offset * _period, 0.0, 0.0)
		copies.add_child(copy)
		for child in map.get_children():
			var made := child.get_node_or_null(NodePath(String(COPIED_MADE.get(String(child.name), "")))) as MeshInstance3D \
				if COPIED_MADE.has(String(child.name)) else null
			if made and made.mesh:
				var shared := MeshInstance3D.new()
				shared.name = String(child.name)
				shared.mesh = made.mesh
				shared.cast_shadow = made.cast_shadow
				copy.add_child(shared)
			if child == copies or String(child.name) in NOT_COPIED:
				continue
			var duplicate := child.duplicate()   # the meshes are shared, not copied
			var tram := duplicate.get_node_or_null("Tram")
			if tram:
				tram.free()
			copy.add_child(duplicate)


## Glides the map's camera sideways on and on (to its right, along the repeating map),
## back by a period when it has gone one.
func _drift(delta: float) -> void:
	if _map_camera == null:
		return
	if _period > 0.0:
		_panned = fposmod(_panned + pan_speed * delta, _period)
		_map_camera.transform = Transform3D(_camera_start.basis, _camera_start.origin + Vector3(-_panned, 0.0, 0.0))
	else:
		# no repeating map: a slow sway from side to side (a sine, slowing at the ends)
		_panned += delta
		var swing := sin(_panned / SWAY_SECONDS * TAU)
		_map_camera.transform = Transform3D(_camera_start.basis, _camera_start.origin + _camera_start.basis.x * swing * SWAY_METRES)
	_place_moon()


# ------------------------------------------------------------------ columns

## Now and then a column comes by on the grass behind the water (the holders of the map,
## baked by tools/build/build_menu_map.gd, with vehicles to copy from): angry farmers with
## their tractors on the way to the Malieveld, or the police with the ME behind it, blue
## lights flashing. Per kind: the holder, the seconds between two columns and before the
## first (from .. to), how many (from .. to), metres apart, speed (m/s), and whether they
## bob (tractors on the grass).
const COLUMN_KINDS := {
	"Hulpdiensten": {"every": Vector2(25.0, 45.0), "first": Vector2(16.0, 20.0), "count": Vector2i(1, 3), "spacing": 13.0, "speed": 15.0, "bob": false},
	"Trekkers": {"every": Vector2(20.0, 35.0), "first": Vector2(0.5, 1.0), "count": Vector2i(6, 12), "spacing": 9.0, "speed": 6.0, "bob": true},
	"Politie": {"every": Vector2(15.0, 30.0), "first": Vector2(1.5, 2.0), "count": Vector2i(2, 5), "spacing": 11.0, "speed": 12.0, "bob": false},
}


## Metres to each side of the camera a column starts and ends (just out of view), and the
## height of the grass they drive on.
const COLUMN_REACH := 60.0


## The first tractors of the menu start this many metres on (of COLUMN_REACH), so the one
## in front comes into view at once (the view is about 21 m to each side on their lane).
const TRACTOR_HEAD_START := 34.0


## Lanes: metres from the line of the map ("z") per column (the ambulances and fire engines
## nearest, then the police, then the tractors); now and then (CRASH_CHANCE, more as the
## chaos grows, when tractors are on their way) the police or the emergency services come
## the other way on the tractors' lane, and where they meet they crash (see _crash).
const LANE_OFFSETS := {"Hulpdiensten": -3.5, "Politie": 0.0, "Trekkers": 4.0}


const CRASH_CHANCE := {"Politie": Vector2(0.65, 1.0), "Hulpdiensten": Vector2(1.0, 1.0)}


## When the tractors set off, the police and the emergency services come soon after (in
## CHASE_WAIT seconds per holder) as long as the tractors are still on their way, so they
## meet them.
## The emergency services come first (they meet the tractors about 7 s after these set
## off), the police after them.
const CHASE_WAIT := {"Politie": Vector2(6.0, 9.0), "Hulpdiensten": Vector2(1.0, 2.5)}


## The blue lights by day: bigger blocks (BEACON_SCALE), glowing BEACON_GLOW times and
## unshaded, so they stand out in the sun too.
const BEACON_SCALE := Vector3(1.8, 2.0, 1.6)


const BEACON_GLOW := 14.0


## The longer the menu is open, the worse it gets behind it: the chaos grows from 0 to 1
## over CHAOS_SECONDS; with it the columns come up to CHAOS_PACE times as often and up to
## CHAOS_CROWD times as long, crashes are likelier, more fires burn at once (a new one at
## each of FIRE_AT) and they burn fiercer (MenuFire.fury up to CHAOS_FURY).
const CHAOS_SECONDS := 120.0


const CHAOS_PACE := 3.0


const CHAOS_CROWD := 1.8


const CHAOS_FURY := 1.6


const FIRE_AT := [0.2, 0.45, 0.7]


## A crash: vehicles become wrecks (RigidBody3D with a box collider their size, their mass
## and speed, a hop and a spin) that bump and slide over the grass (a floor collider), shards
## and dust fly (crash_burst.gd); whatever comes after and drives into a wreck crashes too;
## the wrecks go after WRECK_SECONDS. Masses (kg) by vehicle.
const WRECK_SECONDS := 9.0


## A crash that is too hard sets the vehicles on fire, as in the town (vehicle_fire.gd: by
## the closing speed); they burn a while, the fire dying down, and the smoke drifts on after
## the wreck has gone.
const MASSES := {"trekker": 4500.0, "trekker_rood": 4500.0, "politie": 1300.0, "me_busje": 2500.0, "ambulance": 3000.0, "brandweer": 14000.0}


const CrashBurst = preload("res://scripts/effects/crash_burst.gd")


const MenuFire = preload("res://scripts/effects/menu_fire.gd")


const COLUMN_GROUND := 0.375


## The blue lights: seconds a round of the flashing takes (the left and the right in turn).
const BEACON_CYCLE := 0.5


var _columns: Array[Dictionary] = []


var _wrecks: Array[Dictionary] = []   # per wreck: body, age (s), lasts (s); burning: flames, smoke, light


var _menu_seconds := 0.0


var _fires: Array[Node3D] = []


func _set_up_columns(map: Node) -> void:
	_columns.clear()
	for holder_name: String in COLUMN_KINDS:
		var holder := map.get_node_or_null(holder_name) as Node3D
		if holder == null:
			continue
		var kind: Dictionary = COLUMN_KINDS[holder_name]
		_columns.append({"holder": holder, "kind": kind, "wait": randf_range(kind.first.x, kind.first.y),
			"members": [], "from": Vector3.ZERO, "heading": Vector3.RIGHT, "travelled": 0.0})
		# the protesting farmers fly the upside-down flag
		if holder_name == "Trekkers":
			for model in holder.get_children():
				if model is Node3D and model.get_node_or_null("Protestvlag") == null:
					model.add_child(ProtestFlag.new())
		# the blue lights well visible by day
		for part in holder.find_children("Zwaailicht", "MeshInstance3D", true, false):
			var beacon := part as MeshInstance3D
			beacon.scale = BEACON_SCALE
			var box := beacon.mesh as BoxMesh
			var glow := box.material as StandardMaterial3D if box else null
			if glow:
				glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				glow.albedo_color = Color(0.35, 0.6, 1.0)
				glow.emission_energy_multiplier = BEACON_GLOW


## 0 .. 1: how bad it has got behind the menu (see CHAOS_SECONDS).
func _chaos() -> float:
	return clampf(_menu_seconds / CHAOS_SECONDS, 0.0, 1.0)


## More fires as the chaos grows (one more at each of FIRE_AT), all burning fiercer.
func _spread_fires() -> void:
	if _fires.is_empty():
		return
	var chaos := _chaos()
	var wanted := 1 + FIRE_AT.filter(func(share: float) -> bool: return chaos >= share).size()
	if _fires.size() < wanted:
		var fire := _make_fire(_fires[0].get_parent(), 0.0)
		_fires.append(fire)
	for fire in _fires:
		fire.set("fury", lerpf(1.0, CHAOS_FURY, chaos))


func _make_fire(map: Node, first_wait: float) -> Node3D:
	var fire := MenuFire.new()
	fire.name = "Brand" if _fires.is_empty() else "Brand%d" % (_fires.size() + 1)
	fire.grid = map.get_node_or_null("Gebouwen") as GridMap
	fire.camera = _map_camera
	if first_wait >= 0.0:
		fire.set("first_wait", first_wait)
	map.add_child(fire)
	return fire


func _drive_columns(delta: float) -> void:
	_menu_seconds += delta
	_spread_fires()
	if _map_camera == null:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var beacon_left := fmod(time, BEACON_CYCLE) < BEACON_CYCLE * 0.5
	for column: Dictionary in _columns:
		var kind: Dictionary = column.kind
		var members: Array = column.members
		if members.is_empty():
			column.wait -= delta
			if column.wait <= 0.0:
				_start_column(column)
			continue
		column.travelled += kind.speed * delta
		var heading: Vector3 = column.heading
		for index in members.size():
			var vehicle := members[index] as Node3D
			if vehicle == null:
				continue   # crashed: a wreck now
			var along: float = column.travelled - index * kind.spacing
			var bob := 0.04 * sin(time * 9.0 + index * 1.7) if kind.bob else 0.0
			vehicle.global_transform = Transform3D(Basis.looking_at(-heading, Vector3.UP),
					(column.from as Vector3) + heading * along + Vector3(0, COLUMN_GROUND + bob, 0))
			vehicle.set_meta("snelheid", heading * float(kind.speed))
			vehicle.visible = along > 0.0
			# the blue lights and their light on the surroundings: left and right in turn
			var beacon_index := 0
			var glow_index := 0
			for part in vehicle.get_children():
				var part_name := String(part.name)
				if part_name.begins_with("Zwaailichtgloed"):
					(part as Node3D).visible = (glow_index % 2 == 0) == beacon_left
					glow_index += 1
				elif part_name.begins_with("Zwaailicht"):
					(part as Node3D).visible = (beacon_index % 2 == 0) == beacon_left
					beacon_index += 1
		if column.travelled - (members.size() - 1) * kind.spacing > COLUMN_REACH * 2.0 \
				or members.all(func(member: Variant) -> bool: return member == null):
			for vehicle in members:
				if vehicle != null:
					(vehicle as Node).queue_free()
			members.clear()
			column.wait = randf_range(kind.every.x, kind.every.y) / lerpf(1.0, CHAOS_PACE, _chaos())
	_check_crashes()
	_age_wrecks(delta, beacon_left)


## Vehicles of two columns that meet on one lane crash, and so does a moving vehicle that
## drives into a wreck.
func _check_crashes() -> void:
	var moving: Array[Node3D] = []
	for column: Dictionary in _columns:
		for member in column.members:
			if member != null and (member as Node3D).visible:
				moving.append(member)
	for first_index in moving.size():
		for second_index in range(first_index + 1, moving.size()):
			var first := moving[first_index]
			var second := moving[second_index]
			if first == null or second == null or first.get_parent() == second.get_parent():
				continue   # one column: they keep their distance
			if _touch(first, second):
				var closing := (_speed_of(first) - _speed_of(second)).length()
				_crash(first, closing)
				_crash(second, closing)
				moving[first_index] = null
				moving[second_index] = null
	for vehicle in moving:
		if vehicle == null:
			continue
		for wreck: Dictionary in _wrecks:
			if _touch(vehicle, wreck.body):
				_crash(vehicle, (_speed_of(vehicle) - (wreck.body as RigidBody3D).linear_velocity).length())
				break


## True if the two (vehicles or wrecks) touch: closer along the road than half their
## lengths together, and on one lane.
func _touch(first: Node3D, second: Node3D) -> bool:
	var gap := first.global_position - second.global_position
	var lengths := float(first.get_meta("lengte", 4.0)) + float(second.get_meta("lengte", 4.0))
	return absf(gap.z) < 2.2 and absf(gap.x) < lengths * 0.5


## The speed (m/s, world) of a vehicle of a column.
func _speed_of(vehicle: Node3D) -> Vector3:
	return vehicle.get_meta("snelheid", Vector3.ZERO)


## Turns a driving vehicle into a wreck: a RigidBody3D with a box the size of its body, its
## mass and speed, a hop and a spin, shards and dust where it hit; on fire if the crash, at
## `closing` m/s, was too hard (vehicle_fire.gd).
func _crash(vehicle: Node3D, closing: float) -> void:
	for column: Dictionary in _columns:
		var at: int = (column.members as Array).find(vehicle)
		if at >= 0:
			column.members[at] = null
	var body := RigidBody3D.new()
	body.name = "Wrak"
	body.mass = MASSES.get(String(vehicle.get_meta("model", "")), 1500.0)
	body.set_meta("lengte", vehicle.get_meta("lengte", 4.0))
	var size: Vector3 = vehicle.get_meta("maat", Vector3(1.8, 1.5, 4.0))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	var map := vehicle.get_parent().get_parent()
	map.add_child(body)
	body.global_transform = vehicle.global_transform
	vehicle.reparent(body)
	var velocity: Vector3 = vehicle.get_meta("snelheid", Vector3.ZERO)
	body.linear_velocity = velocity * randf_range(0.6, 1.0) + Vector3(0, randf_range(1.5, 3.5), 0)
	body.angular_velocity = Vector3(randf_range(-1.5, 1.5), randf_range(-4.0, 4.0), randf_range(-1.5, 1.5))
	var wreck := {"body": body, "age": 0.0, "lasts": WRECK_SECONDS}
	if VehicleFire.catches_fire(closing):
		if VehicleFire.explodes(closing):
			VehicleFire.explode(body, size.y * 0.5, map)
		wreck.fire = VehicleFire.ignite(body, size.y * 0.8)
		wreck.lasts = VehicleFire.BURN_SECONDS
	_wrecks.append(wreck)
	CrashBurst.spawn(map, body.global_position + Vector3(0, 1.0, 0), Color(0.8, 0.8, 0.82), 0.8)


## Wrecks keep flashing their blue lights (and burning) and go after their time, blinking
## ever faster in their last seconds (death_blink.gd); the smoke of a burnt-out wreck stays
## a while, drifting off.
func _age_wrecks(delta: float, beacon_left: bool) -> void:
	for wreck: Dictionary in _wrecks.duplicate():
		wreck.age += delta
		var body: RigidBody3D = wreck.body
		if wreck.age > wreck.lasts or not is_instance_valid(body):
			if is_instance_valid(body):
				if wreck.has("fire") and is_instance_valid(wreck.fire):
					# the last smoke drifts off where the wreck was
					(wreck.fire as Node).call("leave_smoke", body.get_parent())
				body.queue_free()
			_wrecks.erase(wreck)
			continue
		# about to go: it blinks, ever faster
		body.visible = DeathBlink.shown(float(wreck.lasts) - float(wreck.age))
		var beacon_index := 0
		for part in body.find_children("Zwaailicht*", "", true, false):
			(part as Node3D).visible = (beacon_index % 2 == 0) == beacon_left
			beacon_index += 1


func _start_column(column: Dictionary) -> void:
	var holder: Node3D = column.holder
	var kind: Dictionary = column.kind
	var models := holder.get_children().filter(func(child: Node) -> bool: return not child.has_meta("rijdt"))
	if models.is_empty():
		return
	var lane := float(holder.get_meta("z")) + float(LANE_OFFSETS.get(holder.name, 0.0))
	column.heading = Vector3.RIGHT if randf() < 0.5 else Vector3.LEFT
	# now and then the police (or the emergency services) come the other way on the
	# tractors' lane: a crash
	var chance: Vector2 = CRASH_CHANCE.get(holder.name, Vector2.ZERO)
	if randf() < lerpf(chance.x, chance.y, _chaos()):
		for other: Dictionary in _columns:
			if other != column and (other.holder as Node).name == "Trekkers" and not (other.members as Array).is_empty():
				lane = float((other.holder as Node3D).get_meta("z")) + float(LANE_OFFSETS.Trekkers)
				column.heading = -(other.heading as Vector3)
	var line := Vector3(_map_camera.global_position.x, 0.0, lane)
	column.from = line - (column.heading as Vector3) * COLUMN_REACH
	column.travelled = 0.0
	if holder.name == "Trekkers" and not column.get("been_out", false):
		column.travelled = TRACTOR_HEAD_START   # the first ones: in view at once
	column.been_out = true
	# the tractors set off: the police and the emergency services follow soon, to meet them
	if holder.name == "Trekkers":
		for other: Dictionary in _columns:
			var chase: Vector2 = CHASE_WAIT.get((other.holder as Node).name, Vector2.ZERO)
			if chase != Vector2.ZERO and (other.members as Array).is_empty():
				other.wait = minf(other.wait, randf_range(chase.x, chase.y))
	var count := roundi(randi_range(kind.count.x, kind.count.y) * lerpf(1.0, CHAOS_CROWD, _chaos()))
	var burning := _fires.any(func(fire: Node3D) -> bool: return fire.call("is_burning"))
	for index in count:
		# the police: a car in front, the vans behind; the farmers: green and red at random;
		# the emergency services: ambulances and fire engines (mostly fire engines when
		# something burns)
		var model: Node3D = models[randi() % models.size()]
		if models.size() == 2 and holder.name == "Politie":
			model = models[0 if index == 0 else 1]
		elif models.size() == 2 and holder.name == "Hulpdiensten":
			model = models[1 if randf() < (0.75 if burning else 0.3) else 0]
		var vehicle := model.duplicate() as Node3D
		vehicle.set_meta("rijdt", true)
		vehicle.set_meta("model", String(model.name))
		var body_part := vehicle.get_node_or_null("Carrosserie") as MeshInstance3D
		if body_part and body_part.mesh:
			var bounds: AABB = body_part.transform * body_part.mesh.get_aabb()
			vehicle.set_meta("lengte", bounds.size.z)
			vehicle.set_meta("maat", bounds.size)
		vehicle.visible = false
		holder.add_child(vehicle)
		(column.members as Array).append(vehicle)


# ------------------------------------------------------------------ the tram

## Now and then a tram rides through the picture on each of the map's tram lines (one in the
## foreground, one in front of the buildings at the back; "Tramlijn<n>/Tram", baked with
## their tracks by tools/build/build_menu_map.gd): every TRAM_EVERY seconds (from .. to),
## this way or the other, at TRAM_SPEED, from TRAM_REACH metres to one side of where the
## camera is to as far to the other.
const TRAM_FIRST_WAIT := Vector2(3.0, 8.0)


const TRAM_EVERY := Vector2(20.0, 40.0)


const TRAM_SPEED := 12.0


const TRAM_REACH := 260.0


## Its wheels on the rails of the tram tiles in the grass (the top of the grass).
const TRAM_RIDE_HEIGHT := 0.375


var _trams: Array[Dictionary] = []   # per line: tram, wait, travelled (< 0 = waiting), from, to


func _ride_tram(delta: float) -> void:
	if _map_camera == null:
		return
	for ride: Dictionary in _trams:
		var tram: Node3D = ride.tram
		if ride.travelled < 0.0:
			ride.wait -= delta
			if ride.wait > 0.0:
				continue
			# a new ride past the camera, from one side or the other
			var line := Vector3(_map_camera.global_position.x, TRAM_RIDE_HEIGHT, float(tram.get_meta("z")))
			var ends: Array = [line - Vector3(TRAM_REACH, 0, 0), line + Vector3(TRAM_REACH, 0, 0)]
			if randf() < 0.5:
				ends.reverse()
			ride.from = ends[0]
			ride.to = ends[1]
			ride.travelled = 0.0
			tram.visible = true
		ride.travelled += TRAM_SPEED * delta
		var from: Vector3 = ride.from
		var to: Vector3 = ride.to
		if ride.travelled >= from.distance_to(to):
			tram.visible = false
			ride.travelled = -1.0
			ride.wait = randf_range(TRAM_EVERY.x, TRAM_EVERY.y)
			continue
		var heading := (to - from).normalized()
		tram.global_transform = Transform3D(Basis.looking_at(-heading, Vector3.UP), from + heading * ride.travelled)


# ------------------------------------------------------------------ the helicopter

## The police helicopter (police_helicopter.gd) circles over the skyline, the middle of its
## circle HELICOPTER_AHEAD metres in front of the camera and HELICOPTER_RIGHT to its right
## (the menu is on the left), going along as the camera glides; its circle: radius, height
## and speed (m, m, m/s).
const HELICOPTER_AHEAD := 150.0


const HELICOPTER_RIGHT := 18.0


const HELICOPTER_CIRCLE := Vector3(35.0, 26.0, 18.0)   # in view all round, from 115 to 185 m off


const PoliceHelicopter = preload("res://scripts/vehicles/police_helicopter.gd")


var _helicopter: Node3D


## The opening: the helicopter starts close before the camera (HELICOPTER_ENTRY_FROM:
## metres right, up and ahead in the camera's own frame; the camera's lens is narrow, 18
## degrees, so at 45 m it fills a good part of the picture), hangs there a moment flying
## slowly away, and swoops off into its circle, joining it at the point nearest the
## camera, in HELICOPTER_ENTRY_SECONDS; then it circles. Its bank follows the swoop.
const HELICOPTER_ENTRY_FROM := Vector3(4.0, 1.0, 45.0)   # right, up, ahead


const HELICOPTER_ENTRY_SECONDS := 11.0


const HELICOPTER_ENTRY_BANK := 22.0   # degrees at most


var _helicopter_entry := -1.0   # seconds into the opening (below 0: none under way)


## On along the opening swoop: a curve (cubic Hermite) from close by the camera, going
## away from it, to the nearest point of the circle, going along it; slow at the start
## (it fills the picture), faster as it goes.
func _fly_helicopter_entry(delta: float) -> void:
	if _helicopter_entry < 0.0 or _helicopter == null or not is_instance_valid(_helicopter) or _map_camera == null:
		return
	_helicopter_entry += delta
	var progress := clampf(_helicopter_entry / HELICOPTER_ENTRY_SECONDS, 0.0, 1.0)
	var along := progress * progress * (3.0 - 2.0 * progress)   # slow off, slow into the circle
	var camera := _map_camera.global_transform
	var start := camera.origin + camera.basis.x * HELICOPTER_ENTRY_FROM.x + camera.basis.y * HELICOPTER_ENTRY_FROM.y \
			- camera.basis.z * HELICOPTER_ENTRY_FROM.z
	var away := -camera.basis.z
	away.y = 0.0
	away = away.normalized()
	# the circle's point nearest the camera, and the way it goes round there
	var centre: Vector3 = _helicopter.get("circle_centre")
	var to_camera := Vector3(camera.origin.x - centre.x, 0.0, camera.origin.z - centre.z).normalized()
	var join_angle := atan2(to_camera.z, to_camera.x)
	var turning := -1.0 if _helicopter.get("anticlockwise") else 1.0
	var join := centre + to_camera * HELICOPTER_CIRCLE.x + Vector3.UP * HELICOPTER_CIRCLE.y
	var join_ahead := Vector3(-to_camera.z, 0.0, to_camera.x) * turning
	var reach := start.distance_to(join)
	var start_tangent := away * reach * 0.6
	var join_tangent := join_ahead * reach * 0.5
	var position_now := _hermite(start, start_tangent, join, join_tangent, along)
	var heading := _hermite(start, start_tangent, join, join_tangent, minf(along + 0.01, 1.0)) - position_now
	if progress >= 1.0 or heading.length() < 0.001:
		heading = join_ahead
	heading.y = 0.0
	# banked into the swoop: by how fast the heading turns
	var heading_later := _hermite(start, start_tangent, join, join_tangent, minf(along + 0.05, 1.0)) \
			- _hermite(start, start_tangent, join, join_tangent, minf(along + 0.04, 1.0))
	heading_later.y = 0.0
	var turn := heading.normalized().cross(heading_later.normalized() if heading_later.length() > 0.001 else heading.normalized()).y
	var bank := Basis(heading.normalized(), clampf(-turn * 20.0, -1.0, 1.0) * deg_to_rad(HELICOPTER_ENTRY_BANK))
	var facing := Basis.looking_at(-heading.normalized(), Vector3.UP)   # its front is +Z
	var nose_down := Basis(Vector3.RIGHT, deg_to_rad(8.0))
	_helicopter.global_position = position_now
	_helicopter.global_basis = bank * facing * nose_down
	if progress >= 1.0:
		_helicopter_entry = -1.0
		_helicopter.set("_circle_angle", join_angle)
		_helicopter.set("circling", true)


static func _hermite(from: Vector3, from_tangent: Vector3, to: Vector3, to_tangent: Vector3, share: float) -> Vector3:
	var share_squared := share * share
	var share_cubed := share_squared * share
	return from * (2.0 * share_cubed - 3.0 * share_squared + 1.0) + from_tangent * (share_cubed - 2.0 * share_squared + share) \
			+ to * (-2.0 * share_cubed + 3.0 * share_squared) + to_tangent * (share_cubed - share_squared)


func _place_helicopter_circle() -> void:
	if _helicopter == null or not is_instance_valid(_helicopter) or _map_camera == null:
		return
	var camera_at := _map_camera.global_position
	_helicopter.set("circle_centre", Vector3(camera_at.x + HELICOPTER_RIGHT, 0.0, camera_at.z + HELICOPTER_AHEAD))


# ------------------------------------------------------------------ the sun and the moon

## The sun and the moon over the 3D map: glowing discs with a soft halo far off in the sky,
## going with the (fast) day of the menu: the sun from its rise to its set (the Dagcyclus'
## SUNRISE, SUNSET), the moon through the night. Each rises at the left of the view, goes
## over in an arc (SKY_ARC_HIGHEST degrees above the horizon at its highest) and sets at
## the right (SKY_ARC_LEFT .. SKY_ARC_RIGHT degrees from where the camera looks); the sun
## takes the colour of the sunlight, red low down and white high up.
@export var sky_arc_left := -14.0


@export var sky_arc_right := 22.0


@export var sky_arc_highest := 11.0


const SKY_DISTANCE := 1800.0


const MOON_RADIUS := 26.0


const SUN_RADIUS := 34.0


const MOON_COLOUR := Color("#F2E8C9")


var _moon: Node3D


var _sun_disc: Node3D


var _day_cycle: Node


## The day in the menu: hours per second (0.4: a day in a minute) and the hour it starts.
const MENU_HOURS_PER_SECOND := 0.4


const MENU_START_HOUR := 21.5


func _add_moon(map: Node) -> void:
	_moon = _sky_disc("Maan", MOON_RADIUS, MOON_COLOUR, 0.35)
	map.add_child(_moon)
	_sun_disc = _sky_disc("Zonneschijf", SUN_RADIUS, Color("#FFF2D0"), 0.5)
	map.add_child(_sun_disc)
	_place_moon()


## A glowing disc of `radius` and `colour` with a soft halo (`glow`: how strong) round it.
static func _sky_disc(disc_name: String, radius: float, colour: Color, glow: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = disc_name
	var disc := MeshInstance3D.new()
	disc.name = "Schijf"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var disc_material := StandardMaterial3D.new()
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_material.albedo_color = colour
	disc_material.disable_fog = true
	sphere.material = disc_material
	disc.mesh = sphere
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	# the halo: a soft round glow behind it, always facing the camera
	var halo := MeshInstance3D.new()
	halo.name = "Gloed"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 7.0
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.albedo_texture = _halo_texture()
	halo_material.albedo_color = Color(colour, glow)
	halo_material.disable_fog = true
	quad.material = halo_material
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(halo)
	return holder


## Puts the sun and the moon where the hour of the menu's day has them.
func _place_moon() -> void:
	if _moon == null or _map_camera == null or _day_cycle == null:
		return
	var hour := float(_day_cycle.get("time_of_day"))
	var sunrise: float = _day_cycle.get("SUNRISE") if _day_cycle.get("SUNRISE") != null else 5.5
	var sunset: float = _day_cycle.get("SUNSET") if _day_cycle.get("SUNSET") != null else 22.0
	# the sun: from its rise to its set
	var day_share := (hour - sunrise) / (sunset - sunrise)
	_sun_disc.visible = day_share > 0.0 and day_share < 1.0
	if _sun_disc.visible:
		_put_on_arc(_sun_disc, day_share)
		var sun := _day_cycle.get_node_or_null(_day_cycle.get("sun_path")) as DirectionalLight3D
		var sunlight := sun.light_color if sun else Color.WHITE
		var colour := sunlight.lerp(Color("#FFF6E4"), 0.3)
		((_sun_disc.get_node("Schijf") as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = colour
		((_sun_disc.get_node("Gloed") as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(colour, 0.5)
	# the moon: through the night, from the sunset to the next sunrise
	var night_hours := 24.0 - (sunset - sunrise)
	var night_share := fposmod(hour - sunset, 24.0) / night_hours
	_moon.visible = night_share > 0.0 and night_share < 1.0
	if _moon.visible:
		_put_on_arc(_moon, night_share)


## Puts a disc on the arc over the view: `share` 0 at its rise (left, on the horizon), 0.5
## at its highest, 1 at its set (right), far off from the camera.
func _put_on_arc(disc: Node3D, share: float) -> void:
	var forward := -_camera_start.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var across := lerpf(sky_arc_left, sky_arc_right, share)
	var height := sky_arc_highest * sin(share * PI) - 1.0
	var direction := forward.rotated(Vector3.UP, deg_to_rad(-across))
	direction = direction.rotated(direction.cross(Vector3.UP).normalized(), deg_to_rad(height))
	disc.global_position = _map_camera.global_position + direction.normalized() * SKY_DISTANCE


## A round soft glow (white in the middle fading out), made once.
static func _halo_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.add_point(0.25, Color(1, 1, 1, 0.45))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


# ------------------------------------------------------------------ the picture

## Darkens the 3D map towards the left edge, where the title and the menu stand.
static func _left_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiStyle.INK, 0.85))
	gradient.set_color(1, Color(UiStyle.INK, 0.0))
	gradient.add_point(0.45, Color(UiStyle.INK, 0.6))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	texture.width = 256
	texture.height = 4
	var shade := TextureRect.new()
	shade.name = "Schaduw"
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_right = 0.7
	shade.anchor_bottom = 1.0
	return shade
