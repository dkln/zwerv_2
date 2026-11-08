class_name PlayerController
extends Node3D
## The player in the town (the node "Speler" of scenes/stad.tscn): the zwerver chosen on the
## character creation screen (PlayerCharacter), walking round with its stats. The camera
## follows it (Volgcamera, follow_camera.gd); the HUD shows its stats (set_stat) and the game
## menu its inventory (scripts/ui/game_menu.gd).
##
## Walking: WASD or the arrow keys, along the iso view (up = into the screen); Shift runs
## while there is stamina. There is no CharacterBody: every physics step it tries the
## move with the town's own colliders (the GridMap shapes the wrecks use too):
## - the ground: a ray straight down from `max_step` above the feet to `max_drop` below
##   them; a step up of at most `max_step` (kerbs, stairs) is taken, a drop of more than
##   `max_drop` (a quay, the edge of a viaduct) is not, and neither is water (Grond tiles
##   in water/) nor a slope steeper than `max_slope`;
## - what stands in the way: a cylinder as wide as the figure from `max_step` above the feet
##   up to its head may not touch anything (walls, lampposts, bins). Blocked, it slides
##   along the wall (the move split in x and z).
## The figure (PlayerModel) walks with its speed, turns towards where it goes, and its height
## follows steps smoothly (the node itself snaps, the figure glides).
## The collider: an AnimatableBody3D box with the outer size of the figure (Botsvorm), so
## the wrecks of the traffic bump into it; the player's own tests leave it out.
##
## Stats (the names of GameHud.STATS; the maximum from the archetype):
## - honger: starts full and always runs out slowly (`hunger_per_minute`, faster while
##   running); empty, it costs `starvation_damage` health every `starvation_interval` s;
## - uithoudingsvermogen: running costs it, standing or walking it comes back after
##   `stamina_recovery_delay` s; run empty you are exhausted and walk until it is back
##   at `exhausted_until` of the maximum;
## - gezondheid: at 0 the player is dead (died, the HUD shows the death screen);
## - overprikkeldheid: starts at 0 (of 100), only items change it so far.
## Every hurt makes the figure blink as in old games (`hurt_blink_time`).
##
## Hit by a vehicle: when its footprint (Vehicle.footprints) overlaps the player's at more
## than `hit_speed_threshold` m/s closing speed, the player loses
## `damage_per_speed` * v + `damage_per_speed_squared` * v^2 health, a burst of shards and
## dust flies (CrashBurst), the view shakes (Vehicle.last_crash) and the figure becomes a
## RigidBody3D (Valpartij) with the box of the figure, thrown along with the vehicle's speed,
## tumbling. Once it lies still (`knock_down_time` at least) it stands up on the nearest
## walkable spot and blinks for `invulnerable_time` s, in which nothing hits it again.
##
## Start: on the square by Centraal Station (START_PLACE, a key of the scene's "places"
## metadata; on a square tile, else pavement, else anything walkable), asleep: the figure
## lies on its back with z's rising over it, and once the town is loaded (the DetailNiveau
## has merged) and `sleep_seconds` have passed, or a key is pressed, it wakes and gets up
## (`wake_time`). Asleep it cannot walk, and hunger and stamina stand still.
## Inventory: `inventory` (item id -> count, scripts/player/items.gd), use_item applies an
## item's effect to the stats.

signal stats_changed
signal inventory_changed
signal hurt(amount: float)
signal died(cause: String)
## Got up after sleeping at the start (or placed, when it does not start asleep).
signal woke_up
signal money_changed

const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const Items = preload("res://scripts/player/items.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")

const STAT_NAMES := ["gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"]
const OVERSTIMULATION_MAXIMUM := 100.0
## Where every zwerver starts: the square by Centraal Station (a key of the "places" metadata).
const START_PLACE := "centraal"
## Ground tile folders a start spot is looked for on, best first.
const PREFERRED_GROUND := [["plein/"], ["plein/", "stoep/"]]
## Collision layer of the town (GridMaps) and of the wrecks.
const TOWN_LAYER := 1
## Colour of the shards when the player is hit (cloth and dirt).
const HIT_SHARD_COLOUR := Color("#6B5844")

@export_group("Walking")
## Metres a second walking and running.
@export var walk_speed := 3.0
@export var run_speed := 6.5
## Seconds the figure takes to turn towards where it goes (about).
@export var turn_time := 0.08
## Highest step up and deepest step down (metres) it walks over.
@export var max_step := 0.6
@export var max_drop := 1.3
## Steepest ground it walks on (degrees).
@export var max_slope := 50.0
## Seconds a step up or down takes the figure (the node snaps at once).
@export var step_glide_time := 0.06
@export_group("Stats")
@export var hunger_per_minute := 10.0
@export var running_hunger_factor := 2.0
@export var starvation_damage := 2.0
@export var starvation_interval := 3.0
@export var run_stamina_per_second := 10.0
@export var stamina_recovery_per_second := 12.0
@export var stamina_recovery_delay := 0.8
@export_range(0.0, 1.0) var exhausted_until := 0.25
@export var hurt_blink_time := 0.8
@export_group("Being hit")
@export var hit_speed_threshold := 1.2
@export var damage_per_speed := 2.2
@export var damage_per_speed_squared := 0.12
@export var knock_down_time := 2.2
@export var invulnerable_time := 1.6
@export var body_mass := 70.0
@export_group("Scene")
## A key of the scene's "places" metadata to start at; empty = START_PLACE.
@export var start_place := ""
## Starts asleep on the ground and wakes up (off: starts standing).
@export var start_asleep := true
## Seconds it sleeps once the town is there (a key wakes it sooner) and the getting up takes.
@export var sleep_seconds := 3.0
@export var wake_time := 1.1
@export var detail_path := NodePath("../DetailNiveau")
@export var hud_path := NodePath("../HUD")
@export var ground_path := NodePath("../Grond")
@export var buildings_path := NodePath("../Gebouwen")

var archetype_id := ""
var level := 1
var money := 0.0
## Euros found or earned since the start (not what it started with).
var money_earned := 0.0
var xp := 0.0
var xp_for_level := 1000.0
## Item id -> how many (scripts/player/items.gd).
var inventory := {}
## Metres a second it moved over the last physics step.
var velocity := Vector3.ZERO

var _stats := {}                 # stat name -> Vector2(value, maximum)
var _shown_stats := {}           # stat name -> Vector2 last given to the HUD
var _model: Node3D
var _figure_box := AABB(Vector3(-0.3, 0.0, -0.2), Vector3(0.6, 1.9, 0.4))
var _body: AnimatableBody3D
var _body_shape: CollisionShape3D
var _walk_shape := CylinderShape3D.new()
var _hud: Node
var _ground: GridMap
var _buildings: GridMap
var _placed := false             # put on the ground by physics (the first physics step)
var _sleeping := false
var _sleep_left := 0.0
var _snore: Label3D
var _dead := false
var _running := false
var _exhausted := false
var _seconds_since_running := 0.0
var _starvation_clock := 0.0
var _blink_left := 0.0
var _invulnerable_left := 0.0
var _ragdoll: RigidBody3D
var _ragdoll_clock := 0.0
var _figure_height := 0.0        # where the figure is drawn (gliding after steps), world y
var _last_safe_position := Vector3.ZERO
var _water_items := {}           # Grond item -> is it water
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	archetype_id = PlayerCharacter.current_id()
	var archetype := PlayerCharacter.chosen_archetype()
	level = int(archetype.get("level", 1))
	money = float(archetype.get("start_money", 0))
	for stat_name: String in STAT_NAMES:
		if stat_name == "overprikkeldheid":
			_stats[stat_name] = Vector2(0.0, OVERSTIMULATION_MAXIMUM)
		else:
			var maximum := float(archetype.stats.get(stat_name, 100))
			_stats[stat_name] = Vector2(maximum, maximum)
	inventory = Items.START_ITEMS.get(archetype_id, {}).duplicate()
	_model = PlayerModel.new()
	_model.name = "Figuur"
	_model.archetype_id = archetype_id
	add_child(_model)
	_figure_box = _outer_box(_model)
	_build_collider()
	var radius := maxf(_figure_box.size.x, _figure_box.size.z) * 0.5
	_walk_shape.radius = clampf(radius, 0.2, 0.45)
	_walk_shape.height = maxf(_figure_box.size.y - max_step - 0.05, 0.4)
	_hud = get_node_or_null(hud_path)
	_ground = get_node_or_null(ground_path) as GridMap
	_buildings = get_node_or_null(buildings_path) as GridMap
	global_position = _estimated_start()
	_figure_height = global_position.y
	_last_safe_position = global_position
	_push_stats(true)
	if _hud and _hud.has_method("set_money"):
		_hud.set_money(money)


# ------------------------------------------------------------------ API

## (value, maximum) of a stat ("gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid").
func stat(stat_name: String) -> Vector2:
	return _stats.get(stat_name, Vector2.ZERO)


## Changes a stat by `amount`, kept between 0 and its maximum (health going down hurts).
func change_stat(stat_name: String, amount: float) -> void:
	if not _stats.has(stat_name) or _dead:
		return
	if stat_name == "gezondheid" and amount < 0.0:
		_hurt(-amount, "gewond")
		return
	var current: Vector2 = _stats[stat_name]
	_stats[stat_name] = Vector2(clampf(current.x + amount, 0.0, current.y), current.y)
	_push_stats()


## True while it lies asleep at the start (or is getting up).
func is_asleep() -> bool:
	return _sleeping or not _placed


## Adds euros (a coin found, a sale; negative = paying).
func add_money(euros: float) -> void:
	money = maxf(money + euros, 0.0)
	if euros > 0.0:
		money_earned += euros
	if _hud and _hud.has_method("set_money"):
		_hud.set_money(money)
	money_changed.emit()


func is_dead() -> bool:
	return _dead


func add_item(item_id: String, count := 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	inventory_changed.emit()


func drop_item(item_id: String) -> void:
	if not inventory.has(item_id):
		return
	inventory[item_id] = int(inventory[item_id]) - 1
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()


## Uses one of an item (eats, drinks...): its effect on the stats; false if it cannot.
func use_item(item_id: String) -> bool:
	if _dead or int(inventory.get(item_id, 0)) <= 0 or not Items.can_use(item_id):
		return false
	var effect: Dictionary = Items.item(item_id).effect
	for stat_name: String in effect:
		change_stat(stat_name, float(effect[stat_name]))
	drop_item(item_id)
	return true


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	if _sleeping:
		if _snore:
			_update_sleep(delta)
	elif not _dead:
		_update_stats(delta)
	if _blink_left > 0.0:
		_blink_left = maxf(_blink_left - delta, 0.0)
		_model.visible = _blink_left <= 0.0 or fmod(_blink_left, 0.14) > 0.07
	else:
		_model.visible = true
	if _ragdoll == null and not _dead and not _sleeping:
		# steps: the node is on the new height at once, the figure glides after it
		_figure_height = lerpf(_figure_height, global_position.y, 1.0 - exp(-delta / maxf(step_glide_time, 0.001)))
		_model.position.y = _figure_height - global_position.y


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if not _placed:
		_place_on_ground()
		return
	if _ragdoll:
		_follow_ragdoll(delta)
		return
	if _dead or _sleeping:
		return
	_walk(delta)
	_check_vehicles()


# ------------------------------------------------------------------ walking

func _walk(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	var start := global_position
	var direction := Vector3.ZERO
	if input != Vector2.ZERO:
		input = input.normalized()
		var into_screen := -Vector3(Iso.DIRECTION.x, 0.0, Iso.DIRECTION.z).normalized()
		var screen_right := into_screen.cross(Vector3.UP)
		direction = screen_right * input.x - into_screen * input.y
	var stamina: Vector2 = _stats.uithoudingsvermogen
	_running = direction != Vector3.ZERO and Input.is_physical_key_pressed(KEY_SHIFT) \
		and not _exhausted and stamina.x > 0.0
	var speed := run_speed if _running else walk_speed
	if direction != Vector3.ZERO:
		var step := direction * speed * delta
		if not _try_move(step):
			if not _try_move(Vector3(step.x, 0.0, 0.0)):
				_try_move(Vector3(0.0, 0.0, step.z))
		var facing := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-delta / maxf(turn_time, 0.001)))
	velocity = (global_position - start) / maxf(delta, 0.0001)
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var walking := clampf(flat_speed / walk_speed, 0.0, 1.7)
	_model.walking = lerpf(_model.walking, walking, 1.0 - exp(-delta / 0.08))
	if flat_speed > 0.01:
		_last_safe_position = global_position


## Moves by `offset` if the ground there can be walked on and the figure fits; true if so.
func _try_move(offset: Vector3) -> bool:
	if offset.length_squared() < 0.00000001:
		return false
	var goal := global_position + offset
	var height := _ground_height(goal, global_position.y)
	if is_nan(height):
		return false
	var feet := Vector3(goal.x, height, goal.z)
	# stuck in something already (pushed, stood up in it): let it walk out
	if not _fits(feet) and _fits(global_position):
		return false
	global_position = feet
	return true


## Height of walkable ground under `point`, searched from `max_step` above `from_height` to
## `max_drop` below it; NAN if there is none (a drop, water, too steep).
func _ground_height(point: Vector3, from_height: float, drop := -1.0) -> float:
	var space := get_world_3d().direct_space_state
	var depth := max_drop if drop < 0.0 else drop
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, from_height + max_step, point.z), Vector3(point.x, from_height - depth, point.z), TOWN_LAYER)
	query.exclude = _own_bodies()
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	if (hit.normal as Vector3).y < cos(deg_to_rad(max_slope)):
		return NAN
	if _is_water(hit):
		return NAN
	return (hit.position as Vector3).y


## True if nothing of the town stands in the figure's way with its feet at `feet`.
func _fits(feet: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _walk_shape
	query.collision_mask = TOWN_LAYER
	query.exclude = _own_bodies()
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (max_step + 0.05 + _walk_shape.height * 0.5))
	return space.intersect_shape(query, 1).is_empty()


func _is_water(hit: Dictionary) -> bool:
	if _ground == null or hit.collider != _ground:
		return false
	var point: Vector3 = hit.position
	var cell := _ground.local_to_map(_ground.to_local(point + Vector3.UP * 0.05))
	for level_below in [0, -1, 1]:
		var item := _ground.get_cell_item(Vector3i(cell.x, cell.y + level_below, cell.z))
		if item == GridMap.INVALID_CELL_ITEM:
			continue
		if not _water_items.has(item):
			var item_name := _ground.mesh_library.get_item_name(item)
			_water_items[item] = item_name.begins_with("water/") and not item_name.contains("kademuur")
		return _water_items[item]
	return false


func _own_bodies() -> Array[RID]:
	var bodies: Array[RID] = [_body.get_rid()]
	if _ragdoll:
		bodies.append(_ragdoll.get_rid())
	return bodies


# ------------------------------------------------------------------ starting spot

## A first guess from the GridMaps (physics is not there before the first step): the
## middle of the nearest pavement or square cell round the archetype's place, at street
## level; _place_on_ground then puts it on the ground and out of what stands there.
func _estimated_start() -> Vector3:
	var world := owner if owner else get_parent()
	var places: Dictionary = world.get_meta("places", {}) if world else {}
	var place_key := start_place if start_place != "" else START_PLACE
	var centre: Vector2 = places.get(place_key, places.values()[0] if not places.is_empty() else Vector2.ZERO)
	if _ground == null:
		return Vector3(centre.x, 0.0, centre.y)
	var centre_cell := _ground.local_to_map(_ground.to_local(Vector3(centre.x, 0.0, centre.y)))
	for preferred: Array in PREFERRED_GROUND + [[]]:
		for ring in range(0, 25):
			for cell_x in range(centre_cell.x - ring, centre_cell.x + ring + 1):
				for cell_z in range(centre_cell.z - ring, centre_cell.z + ring + 1):
					if maxi(absi(cell_x - centre_cell.x), absi(cell_z - centre_cell.z)) != ring:
						continue
					if _is_open_cell(cell_x, cell_z, preferred):
						var middle := _ground.to_global(_ground.map_to_local(Vector3i(cell_x, 0, cell_z)))
						return Vector3(middle.x, 0.3, middle.z)
	return Vector3(centre.x, 0.3, centre.y)


## True if cell (x, z) has walkable ground at street level, no building, and (unless
## `folders` is empty) ground from one of these tile folders.
func _is_open_cell(cell_x: int, cell_z: int, folders: Array) -> bool:
	var item := _ground.get_cell_item(Vector3i(cell_x, 0, cell_z))
	if item == GridMap.INVALID_CELL_ITEM:
		return false
	var item_name := _ground.mesh_library.get_item_name(item)
	if item_name.begins_with("water/") or item_name.contains("tunnel"):
		return false
	if not folders.is_empty() and not folders.any(func(folder: String) -> bool: return item_name.begins_with(folder)):
		return false
	if _buildings:
		for building_level in [0, 1]:
			if _buildings.get_cell_item(Vector3i(cell_x, building_level, cell_z)) != GridMap.INVALID_CELL_ITEM:
				return false
	return true


## The first physics step: onto the ground at the guessed spot, or the nearest spot round
## it where the figure fits.
func _place_on_ground() -> void:
	var spot := _walkable_near(global_position, 3.0, 12.0)
	if spot == Vector3.INF:
		return   # the town's colliders are not there yet: try again next step
	global_position = spot
	_figure_height = spot.y
	_last_safe_position = spot
	_placed = true
	if start_asleep:
		_fall_asleep()
	else:
		woke_up.emit()


# ------------------------------------------------------------------ sleeping

## Lies down on its back (at once) with z's rising over it.
func _fall_asleep() -> void:
	_sleeping = true
	_sleep_left = sleep_seconds
	_model.idle = false
	_model.walking = 0.0
	# on its back (face up, head towards -z), its back on the ground, the middle of the body
	# about where it stood
	_model.rotation_degrees.x = -90.0
	_model.position = Vector3(0.0, -_figure_box.position.z, _figure_box.size.y * 0.45)
	_snore = Label3D.new()
	_snore.name = "Snurken"
	_snore.text = "z"
	_snore.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_snore.no_depth_test = true
	_snore.font_size = 64
	_snore.pixel_size = 0.006
	_snore.outline_size = 12
	_snore.modulate = Color("#E8E6F0")
	_snore.outline_modulate = Color("#0B0D1A")
	add_child(_snore)


func _update_sleep(delta: float) -> void:
	var town_ready := true
	var level_of_detail := get_node_or_null(detail_path)
	if level_of_detail and level_of_detail.has_method("is_merging") and level_of_detail.is_merging():
		town_ready = false
	if town_ready:
		_sleep_left -= delta
	# the z's: rising and growing over the head, one after the other
	var cycle := fmod(Time.get_ticks_msec() / 1000.0, 1.6) / 1.6
	_snore.text = ["z", "zZ", "zZz"][int(cycle * 3.0)]
	_snore.position = Vector3(0.0, 0.7 + cycle * 0.5, -_figure_box.size.y * 0.5)
	_snore.modulate.a = 1.0 - cycle * cycle
	var key_pressed := false
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_ENTER]:
		if Input.is_physical_key_pressed(key):
			key_pressed = true
	if _sleep_left <= 0.0 or (town_ready and key_pressed):
		_wake_up()


## Gets up: sits up and stands, then can walk.
func _wake_up() -> void:
	_sleep_left = INF
	_snore.queue_free()
	_snore = null
	var rise := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(_model, "rotation_degrees:x", 0.0, wake_time)
	rise.parallel().tween_property(_model, "position", Vector3.ZERO, wake_time)
	rise.tween_callback(func() -> void:
		_sleeping = false
		_model.idle = true
		woke_up.emit())


## The nearest spot round `around` (searched from `above` metres over it, `max_drop` + 6 m
## down, out to `reach` metres) where the ground can be walked on and the figure fits;
## Vector3.INF if none.
func _walkable_near(around: Vector3, above: float, reach: float) -> Vector3:
	var distance := 0.0
	while distance <= reach:
		var tries := 1 if distance == 0.0 else int(ceil(TAU * distance / 0.75))
		for attempt in tries:
			var angle := TAU * attempt / tries
			var point := around + Vector3(cos(angle), 0.0, sin(angle)) * distance
			var height := _ground_height(point, around.y + above - max_step, above + 6.0)
			if not is_nan(height) and _fits(Vector3(point.x, height, point.z)):
				return Vector3(point.x, height, point.z)
		distance += 0.75
	return Vector3.INF


# ------------------------------------------------------------------ stats

func _update_stats(delta: float) -> void:
	var hunger: Vector2 = _stats.honger
	var hunger_rate := hunger_per_minute / 60.0 * (running_hunger_factor if _running else 1.0)
	_stats.honger = Vector2(maxf(hunger.x - hunger_rate * delta, 0.0), hunger.y)
	if _stats.honger.x <= 0.0:
		_starvation_clock += delta
		if _starvation_clock >= starvation_interval:
			_starvation_clock -= starvation_interval
			_hurt(starvation_damage, "honger")
	else:
		_starvation_clock = 0.0
	var stamina: Vector2 = _stats.uithoudingsvermogen
	if _running:
		_seconds_since_running = 0.0
		stamina.x = maxf(stamina.x - run_stamina_per_second * delta, 0.0)
		if stamina.x <= 0.0:
			_exhausted = true
	else:
		_seconds_since_running += delta
		if _seconds_since_running >= stamina_recovery_delay:
			stamina.x = minf(stamina.x + stamina_recovery_per_second * delta, stamina.y)
		if _exhausted and stamina.x >= stamina.y * exhausted_until:
			_exhausted = false
	_stats.uithoudingsvermogen = stamina
	_push_stats()


## Gives the HUD the stats that changed (in whole points; all of them when `everything`).
func _push_stats(everything := false) -> void:
	var changed := false
	for stat_name: String in STAT_NAMES:
		var value: Vector2 = _stats[stat_name]
		var shown: Vector2 = _shown_stats.get(stat_name, Vector2(-1.0, -1.0))
		if everything or roundf(shown.x) != roundf(value.x) or shown.y != value.y:
			_shown_stats[stat_name] = value
			changed = true
			if _hud and _hud.has_method("set_stat"):
				_hud.set_stat(stat_name, value.x, value.y)
	if changed:
		stats_changed.emit()


func _hurt(amount: float, cause: String) -> void:
	if _dead or amount <= 0.0:
		return
	var health: Vector2 = _stats.gezondheid
	_stats.gezondheid = Vector2(maxf(health.x - amount, 0.0), health.y)
	_blink_left = maxf(_blink_left, hurt_blink_time)
	hurt.emit(amount)
	_push_stats()
	if _stats.gezondheid.x <= 0.0:
		_die(cause)


func _die(cause: String) -> void:
	_dead = true
	_running = false
	_model.walking = 0.0
	_model.idle = false
	if _ragdoll == null:
		# falls over backwards where it stands
		var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(_model, "rotation_degrees:x", -90.0, 0.45)
		fall.parallel().tween_property(_model, "position:y", _model.position.y + _figure_box.size.z * 0.5, 0.45)
	died.emit(cause)
	if _hud and _hud.has_method("show_death"):
		_hud.show_death(cause)


# ------------------------------------------------------------------ being hit

func _check_vehicles() -> void:
	if _invulnerable_left > 0.0:
		return
	var frame := Transform3D(Basis(Vector3.UP, rotation.y), global_position)
	var mine := Vehicle.rectangle(frame, frame * _figure_box.get_center(), _figure_box.size.x, _figure_box.size.z, 0.0)
	for vehicle: Vehicle in Vehicle.all_vehicles:
		if not is_instance_valid(vehicle) or vehicle.crashed:
			continue
		var offset := vehicle.global_position - global_position
		if absf(offset.y) > 2.5 or Vector2(offset.x, offset.z).length_squared() > 60.0 * 60.0:
			continue
		for footprint: Array in vehicle.footprints(0.0):
			if Vehicle.rectangles_overlap(mine, footprint):
				_hit_by(vehicle)
				return


func _hit_by(vehicle: Vehicle) -> void:
	var closing := vehicle.velocity - velocity
	var impact := closing.length()
	if impact < hit_speed_threshold:
		# a slow nudge: stepped out of its way
		var away := global_position - vehicle.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_try_move(away.normalized() * 0.08)
		return
	var damage := damage_per_speed * impact + damage_per_speed_squared * impact * impact
	var strength := clampf(impact / 20.0, 0.15, 1.0)
	var contact := global_position + Vector3.UP * _figure_box.get_center().y
	CrashBurst.spawn(get_parent(), contact, HIT_SHARD_COLOUR, strength)
	Vehicle.last_crash = {"at": contact, "strength": strength, "time": Time.get_ticks_msec() / 1000.0}
	_knock_down(vehicle.velocity, impact)
	_hurt(damage, "aangereden")
	_invulnerable_left = maxf(_invulnerable_left, knock_down_time)


## The figure becomes a RigidBody3D with its own box, thrown along with `push`.
func _knock_down(push: Vector3, impact: float) -> void:
	_ragdoll = RigidBody3D.new()
	_ragdoll.name = "Valpartij"
	_ragdoll.mass = body_mass
	_ragdoll.continuous_cd = true
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.2
	_ragdoll.physics_material_override = material
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _figure_box.size
	shape.shape = box
	shape.position = _figure_box.get_center()
	_ragdoll.add_child(shape)
	get_parent().add_child(_ragdoll)
	_ragdoll.global_transform = Transform3D(Basis(Vector3.UP, rotation.y), global_position + Vector3.UP * 0.05)
	_ragdoll.add_collision_exception_with(_body)
	_body_shape.set_deferred("disabled", true)
	var flat_push := Vector3(push.x, 0.0, push.z)
	var thrown_towards := flat_push.normalized() if flat_push.length_squared() > 0.01 else global_basis.z
	_ragdoll.linear_velocity = flat_push * 1.1 + Vector3.UP * minf(1.5 + impact * 0.22, 7.0)
	_ragdoll.angular_velocity = Vector3.UP.cross(thrown_towards) * minf(impact * 0.6, 14.0) \
		+ Vector3.UP * _random.randf_range(-3.0, 3.0)
	_model.walking = 0.0
	_model.idle = false
	_model.position = Vector3.ZERO
	_model.reparent(_ragdoll, true)
	_ragdoll_clock = 0.0


## While knocked down: the node (and so the camera) stays with the body; once it lies still
## it stands up, unless dead.
func _follow_ragdoll(delta: float) -> void:
	_ragdoll_clock += delta
	global_position = _ragdoll.global_position
	if _dead:
		return
	var lies_still := _ragdoll.sleeping or _ragdoll.linear_velocity.length() < 0.3
	if (_ragdoll_clock >= knock_down_time and lies_still) or _ragdoll_clock >= knock_down_time * 3.0:
		_stand_up()


func _stand_up() -> void:
	var lying_at := _ragdoll.global_position
	var heading := _ragdoll.global_basis.z
	var spot := _walkable_near(lying_at, 1.5, 10.0)
	if spot == Vector3.INF:
		spot = _last_safe_position
	_model.reparent(self, false)
	_model.transform = Transform3D.IDENTITY
	_model.idle = true
	_ragdoll.queue_free()
	_ragdoll = null
	_body_shape.set_deferred("disabled", false)
	global_position = spot
	_figure_height = spot.y
	if Vector2(heading.x, heading.z).length_squared() > 0.01:
		rotation.y = atan2(heading.x, heading.z)
	_invulnerable_left = invulnerable_time
	_blink_left = maxf(_blink_left, invulnerable_time)


# ------------------------------------------------------------------ building

## The collider with the outer size of the figure, for the wrecks to bump into.
func _build_collider() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "Botsvorm"
	_body.sync_to_physics = false
	_body.collision_layer = TOWN_LAYER
	_body.collision_mask = 0
	_body_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _figure_box.size
	_body_shape.shape = box
	_body_shape.position = _figure_box.get_center()
	_body.add_child(_body_shape)
	add_child(_body)


## The box round all meshes of the figure, in its own space (feet at y = 0, facing +z).
static func _outer_box(figure: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var to_figure := figure.global_transform.affine_inverse()
	for mesh_node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box := (to_figure * mesh_instance.global_transform) * mesh_instance.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first or bounds.size.y < 0.5:
		return AABB(Vector3(-0.3, 0.0, -0.2), Vector3(0.6, 1.9, 0.4))
	return bounds
