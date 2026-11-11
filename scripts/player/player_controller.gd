class_name PlayerController
extends Node3D
## The player in the town (the node "Speler" of scenes/stad.tscn): the zwerver chosen on the
## character creation screen (PlayerCharacter), walking round with its stats. The camera
## follows it (Volgcamera, follow_camera.gd); the HUD shows its stats (set_stat) and the game
## menu its inventory (scripts/ui/game_menu.gd).
##
## Walking (`controls`): "tank" (the default): A/D or left/right turn the figure round
## (`turn_speed`), W/S or up/down walk forwards or backwards the way it faces (backwards at
## `backward_share` of the speed, no running); so a turning camera never changes where a key
## takes you. "scherm": along the iso view (up = into the screen). Shift runs forwards while
## there is stamina. There is no CharacterBody: every physics step it tries the
## move with the town's own colliders (the GridMap shapes the wrecks use too):
## - the ground: a ray straight down from `max_step` above the feet to `max_drop` below
##   them; a step up of at most `max_step` (kerbs, stairs) is taken, a step down of at most
##   `max_drop` is walked; a deeper drop (a platform edge, a quay, a wall, a roof) is
##   walked off: the figure falls (`jump_gravity`) onto the ground below, down to
##   `max_fall` m. Water (Grond tiles in water/) is never walked or fallen onto, nor a slope
##   steeper than `max_slope`;
## - what stands in the way: a cylinder as wide as the figure from `max_step` above the feet
##   up to its head may not touch anything (walls, lampposts, bins). Blocked, it slides
##   along the wall (the move split in x and z).
## The figure (PlayerModel) walks with its speed, turns towards where it goes, and its height
## follows steps smoothly (the node itself snaps, the figure glides).
## Talking: someone on foot or in a chair within `talk_reach` m (and before it; the group
## TALKABLE_GROUP: pedestrians and the people in an interior) shows "[E] Praten" bottom left
## (GameHud.set_actions); E starts a conversation with them (Conversations, in the story box:
## the game stands still meanwhile), they turn to you. A door (DOORS_GROUP: a snack bar's
## entrance, the way out of an interior; Interiors) shows its own action ("[E] Naar binnen")
## and E goes through it; teleport puts the player on the other side.
## Space jumps (`jump_height` m, falling back at `jump_gravity`; it costs `jump_stamina`, not
## when exhausted): in the air it still steers, may come down on something up to its jump
## higher than where it left (a bench, a low wall, a raised square) or anywhere lower (off a
## platform), or into the water (it jumps in: the splash); the figure tucks its legs and
## throws up its arms meanwhile.
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
## Water: it cannot be walked on, but running into it, or pushing against it for
## `water_push_time` s, makes the figure jump in (a cry, a hop over the edge, a splash and
## the "plons", WaterSplash), and it sinks for `drown_time` s, waving its arms over its head
## and kicking (_flail) while bubbles rise, and drowns
## ("verdronken"). Knocked into the water by a vehicle it drowns too.
## A hit sounds like an old beat-'em-up: the thud of the body (BODY_HIT_SOUND) and a cry of
## pain in the character's voice ("voice" of the archetype: pijn_<voice>_1..3, never the same
## one twice in a row; pijn_<voice>_hard from `hard_cry_strength` or when the hit kills),
## through RuimtelijkGeluid (tools/megadrive/stemmen.py makes them).
##
## Start: on the square by Centraal Station (START_PLACE, a key of the scene's "places"
## metadata; on a square tile, else pavement, else anything walkable), asleep: the figure
## lies on its back, and once the town is loaded (the DetailNiveau
## has merged) and `sleep_seconds` have passed, or a key is pressed, it wakes and gets up
## (`wake_time`). Asleep it cannot walk, and hunger and stamina stand still.
## Experience: add_xp (missions and their steps give it, scripts/story/story.gd); a full
## bar (`xp_for_level`) is a level up: the next level takes XP_GROWTH times as much, the HUD
## shows the new level and plays the level jingle (GameHud.show_level_up).
## Inventory: `inventory` (item id -> count, scripts/player/items.gd), use_item applies an
## item's effect to the stats. Room for only Items.BASE_SLOTS kinds of item (inventory_slots);
## a rucksack picked up in the town (pick_up_backpack, scripts/world/backpacks.gd) adds
## Items.BACKPACK_SLOTS and is worn on the figure's back (PlayerModel.backpack; the collider
## grows with it). Nobody starts with one.

signal stats_changed
signal inventory_changed
signal hurt(amount: float)
signal died(cause: String)
## Got up after sleeping at the start (or placed, when it does not start asleep).
signal woke_up
signal money_changed
## Something bought (buy: at a snack bar), its item id.
signal bought(item_id: String)
## A conversation started with someone (talk_to), the kind of person (Conversations.persona).
signal talked(persona: String)

const KnockDown = preload("res://scripts/world/knock_down.gd")
const GroundShadow = preload("res://scripts/effects/ground_shadow.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const Items = preload("res://scripts/player/items.gd")
const WaterSplash = preload("res://scripts/effects/water_splash.gd")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const Conversations = preload("res://scripts/story/conversations.gd")
## Who can be talked to (InteriorPerson.TALKABLE_GROUP) and the doors (Interiors.DOORS_GROUP).
const TALKABLE_GROUP := "aanspreekbaar"
const DOORS_GROUP := "deuren"
## The player alone (what the world looks for to show things near it: InteractionMark).
const PLAYER_GROUP := "speler"
## How much more XP each next level takes, and the colour of "+50 XP".
const XP_GROWTH := 1.5
const XP_TEXT_COLOUR := Color("#47D6C2")

const STAT_NAMES := ["gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"]
const OVERSTIMULATION_MAXIMUM := 100.0
## Where every zwerver starts: the square by Centraal Station (a key of the "places" metadata).
const START_PLACE := "centraal"
## Ground tile folders a start spot is looked for on, best first.
const PREFERRED_GROUND := [["plein/"], ["plein/", "stoep/"]]
## Collision layer of the town (GridMaps) and of the wrecks.
const TOWN_LAYER := 1
## Size of the figure in the town (PlayerModel.figure_scale): about 1.8 m tall (hair and
## hats included), in proportion to the townspeople (TownsfolkFigure, 1.75 m), the
## two-wheelers and the cars.
const FIGURE_SCALE := 0.78
const NightGlow = preload("res://scripts/player/night_glow.gd")
## Colour of the shards when the player is hit (cloth and dirt).
const HIT_SHARD_COLOUR := Color("#6B5844")
const BODY_HIT_SOUND := "lichaam_klap"
const SPLASH_SOUND := "plons"
## The blip of a jump (RuimtelijkGeluid, an event: right by you).
const JUMP_SOUND := "springen"
const SHORT_CRY_COUNT := 3

@export_group("Walking")
## Metres a second walking and running.
@export var walk_speed := 3.0
@export var run_speed := 6.5
## Seconds the figure takes to turn towards where it goes (about).
## "tank": turn and walk the way you face; "scherm": the keys along the screen (see the top).
@export_enum("tank", "scherm") var controls := "tank"
## Degrees a second the figure turns (tank), and how fast backwards is (share of walking).
@export var turn_speed := 200.0
@export_range(0.1, 1.0) var backward_share := 0.55
@export var turn_time := 0.08
## Highest step up and deepest step down (metres) it walks over.
@export var max_step := 0.6
@export var max_drop := 1.3
## Deepest drop (metres) it walks or jumps off and falls down; deeper it stops at the edge.
@export var max_fall := 30.0
## Steepest ground it walks on (degrees).
@export var max_slope := 50.0
## Seconds a step up or down takes the figure (the node snaps at once).
@export var step_glide_time := 0.06
@export_group("Talking")
@export var talk_reach := 2.2
## Seconds someone you talk to takes to turn round to you.
const TALK_TURN_SECONDS := 0.35
@export_group("Jumping")
@export var jump_height := 1.4
@export var jump_gravity := 24.0
@export var jump_stamina := 6.0
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
## From this hit strength (0..1, the impact / 20 m/s) the long cry instead of a short one.
@export var hard_cry_strength := 0.55
@export var damage_per_speed := 2.2
@export var damage_per_speed_squared := 0.12
@export var knock_down_time := 2.2
@export var invulnerable_time := 1.6
## Into the water: running into it, or pushing against it this many seconds, makes the figure
## fall in; it then sinks for `drown_time` s and drowns.
@export var water_push_time := 0.5
@export var drown_time := 2.6
@export var body_mass := 70.0
@export_group("Scene")
## A key of the scene's "places" metadata to start at; empty = START_PLACE.
@export var start_place := ""
## Starts asleep on the ground and wakes up (off: starts standing).
@export var start_asleep := true
## Seconds it sleeps once the town is there (a key wakes it sooner) and the getting up takes.
@export var sleep_seconds := 0.8
@export var wake_time := 1.1
## How far the view's coming down (FollowCamera.arrival_progress) has to be for it to wake.
const WAKE_AT_ARRIVAL := 0.8
@export var detail_path := NodePath("../DetailNiveau")
## The follow camera: while it still comes down from the sky at the start (its arrival) the
## player sleeps on, so it wakes (and the story starts) once you see it.
@export var follow_camera_path := NodePath("../Volgcamera")
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
## Wears a rucksack (picked up in the town): more room in the inventory.
var has_backpack := false
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
var _water_push := 0.0            # seconds pushed against water
var _airborne := false            # in a jump
var _vertical_speed := 0.0        # metres a second up (in a jump)
var _takeoff_height := 0.0        # world y it jumped from
var _jump_key_was_down := false
var _talk_key_was_down := false
var _talk_partner: Node3D          # who "[E] Praten" is for now
var _drowning := false
var _voice := "man"               # the voice of the cries of pain: man, oude_man, vrouw
var _last_cry := 0


func _ready() -> void:
	archetype_id = PlayerCharacter.current_id()
	add_to_group(Vehicle.WALKERS_GROUP)   # vehicles brake, swerve and hoot for it
	add_to_group(PLAYER_GROUP)
	var archetype := PlayerCharacter.chosen_archetype()
	level = int(archetype.get("level", 1))
	_voice = String(archetype.get("voice", "man"))
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
	_model.simple = true   # seen from afar in the town: fewer details
	_model.figure_scale = FIGURE_SCALE
	add_child(_model)
	_figure_box = _with_pose_room(_outer_box(_model))
	# a soft light over the figure in the dark, so it can be made out (night_glow.gd)
	var night_light := OmniLight3D.new()
	night_light.name = "Nachtlicht"
	night_light.set_script(NightGlow)
	add_child(night_light)
	# a soft patch on the ground under it, so it stands apart from the street (ground_shadow.gd)
	add_child(GroundShadow.new())
	_build_collider()
	_fit_collider(_figure_box)
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
## More experience: "+50 XP" rising over the figure, the bar in the HUD; past the end of the
## bar the next level (as often as it takes).
func add_xp(points: float) -> void:
	if points <= 0.0:
		return
	xp += points
	var levelled := false
	while xp >= xp_for_level:
		xp -= xp_for_level
		level += 1
		xp_for_level = roundf(xp_for_level * XP_GROWTH / 50.0) * 50.0
		levelled = true
	if _hud:
		if _hud.has_method("show_floating_number"):
			_hud.show_floating_number(global_position + Vector3.UP * 2.3, "+%d XP" % roundi(points), XP_TEXT_COLOUR, 18)
		if _hud.has_method("set_xp"):
			_hud.set_xp(xp, xp_for_level)
		if levelled and _hud.has_method("show_level_up"):
			_hud.show_level_up(level)


## Buys `item_id` for `price` euros (a snack bar: Conversations): "ok" (paid, in the pockets,
## `bought` fires), "geld" (not enough money) or "vol" (no room in the pockets: not paid).
func buy(item_id: String, price: float) -> String:
	if money + 0.001 < price:
		return "geld"
	if not add_item(item_id):
		return "vol"
	add_money(-price)
	bought.emit(item_id)
	return "ok"


func add_money(euros: float) -> void:
	money = maxf(money + euros, 0.0)
	if euros > 0.0:
		money_earned += euros
	if _hud and _hud.has_method("set_money"):
		_hud.set_money(money)
	money_changed.emit()


func is_dead() -> bool:
	return _dead


## How many kinds of item it can carry: its pockets, and more with a rucksack.
func inventory_slots() -> int:
	return Items.BASE_SLOTS + (Items.BACKPACK_SLOTS if has_backpack else 0)


## True if there is room for one more of `item_id`: it has some already, or a slot is free.
func has_room_for(item_id: String) -> bool:
	return int(inventory.get(item_id, 0)) > 0 or inventory.size() < inventory_slots()


## Adds items; false (and nothing added) if there is no room for them: the pockets full.
func add_item(item_id: String, count := 1) -> bool:
	if not has_room_for(item_id):
		if _hud and _hud.has_method("show_floating_number"):
			_hud.show_floating_number(global_position + Vector3.UP * 2.0, "Zakken vol", Color("#FF5D73"), 14)
		return false
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	inventory_changed.emit()
	return true


## Puts on a rucksack found in the town: more room (Items.BACKPACK_SLOTS), worn on the back,
## the collider round the figure grown with it. False if it wears one already.
func pick_up_backpack() -> bool:
	if has_backpack or _dead:
		return false
	has_backpack = true
	_model.backpack = true
	_fit_collider(_with_pose_room(_model.rest_bounds()))
	inventory_changed.emit()
	return true


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
		if _sleep_left < INF:   # not yet getting up
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
		if _airborne:
			_figure_height = global_position.y
		else:
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
	if _dead or _sleeping or _drowning:
		return
	if _rising_left > 0.0:
		# still getting up: no walking yet (it can be hit, though)
		_rising_left = maxf(_rising_left - delta, 0.0)
		_check_vehicles()
		return
	_walk(delta)
	_check_vehicles()
	_look_for_someone_to_talk_to()


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
	var backwards := false
	if controls == "tank":
		# turn round the own axis; forwards or backwards the way it faces
		rotation.y -= input.x * deg_to_rad(turn_speed) * delta
		if input.y != 0.0:
			backwards = input.y > 0.0
			direction = Vector3(sin(rotation.y), 0.0, cos(rotation.y)) * (-1.0 if backwards else 1.0)
	elif input != Vector2.ZERO:
		input = input.normalized()
		# into the screen as the follow camera looks now (it turns a little round buildings)
		var follow := get_node_or_null(follow_camera_path)
		var towards_camera := Iso.direction(follow.view_yaw()) if follow and follow.has_method("view_yaw") else Iso.DIRECTION
		var into_screen := -Vector3(towards_camera.x, 0.0, towards_camera.z).normalized()
		var screen_right := into_screen.cross(Vector3.UP)
		direction = screen_right * input.x - into_screen * input.y
	var stamina: Vector2 = _stats.uithoudingsvermogen
	_running = direction != Vector3.ZERO and not backwards and Input.is_physical_key_pressed(KEY_SHIFT) \
		and not _exhausted and stamina.x > 0.0
	var speed := run_speed if _running else walk_speed
	if backwards:
		speed *= backward_share
	var jump_key := Input.is_physical_key_pressed(KEY_SPACE)
	if jump_key and not _jump_key_was_down and not _airborne:
		_start_jump()
	_jump_key_was_down = jump_key
	if direction != Vector3.ZERO:
		var step := direction * speed * delta
		var move := _try_move_in_air if _airborne else _try_move
		if not move.call(step):
			if not move.call(Vector3(step.x, 0.0, 0.0)):
				move.call(Vector3(0.0, 0.0, step.z))
		# pushing against water: in it goes, at once when running
		var water := _water_point(global_position + direction * 0.6) if global_position.distance_squared_to(start) < 0.0001 and not _airborne else Vector3.INF
		if water != Vector3.INF:
			_water_push += delta
			if _running or _water_push >= water_push_time:
				_fall_into_water(water)
				return
		else:
			_water_push = 0.0
		if controls != "tank":
			var facing := atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-delta / maxf(turn_time, 0.001)))
	else:
		_water_push = 0.0
	if _airborne:
		_fall(delta)
	velocity = (global_position - start) / maxf(delta, 0.0001)
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var walking := 0.0 if _airborne else clampf(flat_speed / walk_speed, 0.0, 1.7)
	_model.walking = lerpf(_model.walking, walking, 1.0 - exp(-delta / 0.08))
	if flat_speed > 0.01 and not _airborne:
		_last_safe_position = global_position


## Someone near enough to talk to (the nearest in reach, rather the one it faces), shown as
## "[E] Praten"; E starts the conversation.
func _look_for_someone_to_talk_to() -> void:
	var nearest: Node3D = null
	var best := INF
	var facing := Vector2(sin(rotation.y), cos(rotation.y))
	if not _airborne:
		# who can be talked to (pedestrians, the people in an interior) and the doors
		var candidates: Array = get_tree().get_nodes_in_group(TALKABLE_GROUP) + get_tree().get_nodes_in_group(DOORS_GROUP)
		for candidate in candidates:
			var thing := candidate as Node3D
			if thing == null or thing == self or not thing.is_visible_in_tree() or thing.get("_ragdoll") != null:
				continue
			# who sells behind a counter only from its front (InteriorPerson.can_talk_from)
			if thing.has_method("can_talk_from") and not thing.call("can_talk_from", global_position):
				continue
			var reach: float = thing.call("reach") if thing.has_method("reach") else talk_reach
			var offset := Vector2(thing.global_position.x - global_position.x, thing.global_position.z - global_position.z)
			var distance := offset.length()
			if distance > reach or absf(thing.global_position.y - global_position.y) > 1.2:
				continue
			# the one before it counts as nearer
			var score := distance - 0.8 * maxf(facing.dot(offset / maxf(distance, 0.001)), 0.0)
			if score < best:
				best = score
				nearest = thing
	if nearest != _talk_partner:
		_talk_partner = nearest
		if _hud and _hud.has_method("set_actions"):
			var action := String(nearest.call("action_text")) if nearest and nearest.has_method("action_text") else "Praten"
			_hud.set_actions([["E", action]] if nearest else [])
	var talk_key := Input.is_physical_key_pressed(KEY_E)
	if talk_key and not _talk_key_was_down and _talk_partner:
		if _talk_partner.has_method("go_through"):
			_talk_partner.call("go_through")
			_talk_partner = null
			if _hud and _hud.has_method("set_actions"):
				_hud.set_actions([])
		else:
			talk_to(_talk_partner)
	_talk_key_was_down = talk_key


## Puts the player at `at` (on the ground there), facing `yaw`: going into or out of a
## building (Interiors). Standing, not in a jump, the figure there at once.
func teleport(at: Vector3, yaw: float) -> void:
	var ground := _ground_height(at, at.y + 1.0, 4.0)
	global_position = Vector3(at.x, at.y if is_nan(ground) else ground, at.z)
	rotation.y = yaw
	_airborne = false
	_vertical_speed = 0.0
	_jump_pose(false)
	velocity = Vector3.ZERO
	_figure_height = global_position.y
	_last_safe_position = global_position
	_water_push = 0.0


## A conversation with `person` (Conversations) in the story box, or with someone who sells
## (Conversations.is_merchant) the shop screen (GameHud.show_shop); they stand still and
## straight first (stand_neutral), then turn to face you.
func talk_to(person: Node3D) -> void:
	if _hud == null or not _hud.has_method("show_story"):
		return
	# whoever was walking stands still and straight first (no leg left in the air)
	if person.has_method("stand_neutral"):
		person.stand_neutral()
	var towards := global_position - person.global_position
	# someone sitting at a table stays on its chair (only you turn to them)
	var stays_seated: bool = person.get("sitting") == true
	if stays_seated and Vector2(towards.x, towards.z).length_squared() > 0.0001:
		rotation.y = atan2(-towards.x, -towards.z)
	elif Vector2(towards.x, towards.z).length_squared() > 0.0001:
		# they turn round to you (smoothly, also while the story box holds the game), you to them
		var from: float = person.rotation.y
		var to := from + angle_difference(from, atan2(towards.x, towards.z))
		var turn := person.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		turn.tween_property(person, "rotation:y", to, TALK_TURN_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rotation.y = atan2(-towards.x, -towards.z)
	var talk := Conversations.new(person, self, _hud)
	talked.emit(talk.persona)
	# the view glides in on the two of you, and back after
	var follow := get_node_or_null(follow_camera_path)
	if follow and follow.has_method("talk_close_up"):
		follow.talk_close_up(person)
	var done := func() -> void:
		talk.finish()
		if follow and follow.has_method("talk_close_up"):
			follow.talk_close_up(null)
	# someone who sells: the shop screen (their goods), everyone else the story box
	if talk.is_shop() and _hud.has_method("show_shop"):
		_hud.show_shop(talk, self, done)
	else:
		_hud.show_story(talk.opening(), done)


## Off the ground, if there is the stamina for it (not when exhausted).
func _start_jump() -> void:
	var stamina: Vector2 = _stats.uithoudingsvermogen
	if _exhausted or stamina.x < jump_stamina:
		return
	_stats.uithoudingsvermogen = Vector2(stamina.x - jump_stamina, stamina.y)
	_seconds_since_running = 0.0
	_airborne = true
	_takeoff_height = global_position.y
	_vertical_speed = sqrt(2.0 * jump_gravity * jump_height)
	_jump_pose(true)
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and audio.has_method("play_event"):
		audio.play_event(global_position, JUMP_SOUND)
	_push_stats()


## Up and down in a jump; lands on the ground under it (also higher than where it left).
func _fall(delta: float) -> void:
	_vertical_speed -= jump_gravity * delta
	var height := global_position.y + _vertical_speed * delta
	var ground := _ground_height(global_position, global_position.y, global_position.y - _takeoff_height + max_fall)
	if is_nan(ground):
		# coming down over water: in it goes
		var water := _water_point(global_position)
		if water != Vector3.INF and _vertical_speed <= 0.0 and height <= water.y + 0.3:
			_fall_into_water(water)
			return
		ground = water.y if water != Vector3.INF else _takeoff_height
	if _vertical_speed <= 0.0 and height <= ground:
		global_position.y = ground
		_airborne = false
		_vertical_speed = 0.0
		_jump_pose(false)
		return
	global_position.y = maxf(height, ground)


## Moves by `offset` in a jump, at its height: where there is ground it could come down on
## (at most `max_fall` below where it jumped, no water) and nothing in the way.
func _try_move_in_air(offset: Vector3) -> bool:
	if offset.length_squared() < 0.00000001:
		return false
	var goal := global_position + offset
	var ground := _ground_height(goal, global_position.y, global_position.y - _takeoff_height + max_fall)
	if is_nan(ground):
		# over water it may fly on too: it comes down in it (_fall)
		if _water_point(goal) == Vector3.INF:
			return false
		global_position = Vector3(goal.x, global_position.y, goal.z)
		return true
	var feet := Vector3(goal.x, maxf(global_position.y, ground), goal.z)
	if not _fits(feet) and _fits(global_position):
		return false
	global_position = feet
	return true


## The jump pose, as in the old platform games (on), or back to normal (off): the right arm
## straight up, the left down and back bent square at the elbow; the left leg forward with
## the knee bent, the right back with the foot kicked up.
const JUMP_POSE := {
	"arm_right": Vector3(-165.0, 0.0, 10.0), "forearm_right": Vector3(-10.0, 0.0, 0.0),
	"arm_left": Vector3(40.0, 0.0, -12.0), "forearm_left": Vector3(-90.0, 0.0, 0.0),
	"leg_left": Vector3(-60.0, 0.0, 0.0), "shin_left": Vector3(55.0, 0.0, 0.0),
	"leg_right": Vector3(30.0, 0.0, 0.0), "shin_right": Vector3(70.0, 0.0, 0.0),
}


func _jump_pose(on: bool) -> void:
	for limb: String in JUMP_POSE:
		_model.pose_limb(limb, JUMP_POSE[limb] if on else Vector3.ZERO)


## Moves by `offset` if the ground there can be walked on and the figure fits; true if so.
## Down more than `max_step` (a platform edge, a wall; ground within `max_fall`) it steps off
## and falls instead of stepping down.
func _try_move(offset: Vector3) -> bool:
	if offset.length_squared() < 0.00000001:
		return false
	var goal := global_position + offset
	var height := _ground_height(goal, global_position.y)
	if is_nan(height) or height < global_position.y - max_step:
		return _step_off_edge(goal, offset)
	var feet := Vector3(goal.x, height, goal.z)
	# stuck in something already (pushed, stood up in it): let it walk out
	if not _fits(feet) and _fits(global_position):
		return false
	global_position = feet
	return true


## Walks off an edge towards `goal` (moving by `offset`) when there is walkable ground more
## than `max_step` below it within `max_fall` (not water, not too steep) and the figure fits
## there: then it falls. Right at the edge the ray may hit its upright side, so it also looks
## up to EDGE_HOP metres further on and hops that far over the edge.
const EDGE_HOP := 0.4

func _step_off_edge(goal: Vector3, offset: Vector3) -> bool:
	var onwards := Vector3(offset.x, 0.0, offset.z).normalized()
	var feet := Vector3.INF
	for hop in [0.0, EDGE_HOP * 0.5, EDGE_HOP]:
		var spot: Vector3 = goal + onwards * hop
		var landing := _ground_height(spot, global_position.y, max_fall)
		if not is_nan(landing) and landing < global_position.y - max_step:
			feet = Vector3(spot.x, global_position.y, spot.z)
			break
	if feet == Vector3.INF or not _fits(feet):
		return false
	global_position = feet
	_airborne = true
	_takeoff_height = global_position.y
	_vertical_speed = 0.0
	_jump_pose(true)
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


## The surface of the water under `point` (searched from a step above the figure to well
## below a quay), or INF when there is no water there.
func _water_point(point: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, global_position.y + max_step + 0.5, point.z), Vector3(point.x, global_position.y - max_drop - 4.0, point.z), TOWN_LAYER)
	query.exclude = _own_bodies()
	var hit := space.intersect_ray(query)
	if hit.is_empty() or not _is_water(hit):
		return Vector3.INF
	return hit.position


## Jumps into the water at `water`: a cry, a hop over the edge, then the splash and sinking.
func _fall_into_water(water: Vector3) -> void:
	_airborne = false
	_jump_pose(false)
	_drowning = true
	_running = false
	_model.walking = 0.0
	_model.idle = false
	cry_out(true, global_position)
	rotation.y = atan2(water.x - global_position.x, water.z - global_position.z)
	var from := global_position
	var hop := create_tween()
	hop.tween_method(func(share: float) -> void:
		global_position = from.lerp(water, share) + Vector3.UP * sin(share * PI) * 0.6, 0.0, 1.0, 0.4)
	hop.tween_callback(_sink.bind(water))


## Under it goes at `water`: the splash, bubbles, sinking out of sight, drowned.
func _sink(water: Vector3) -> void:
	_drowning = true
	global_position = water
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio:
		audio.play_event(water, SPLASH_SOUND)
	var splash := WaterSplash.new()
	splash.bubble_seconds = drown_time
	get_parent().add_child(splash)
	splash.global_position = water
	_hurt(_stats.gezondheid.x * 0.5, "verdronken")
	var down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# flailing: both arms up over the head, waving wildly, the legs kicking, fading at the end
	var flail := create_tween()
	flail.tween_method(_flail, 0.0, drown_time, drown_time)
	down.tween_property(_model, "position:y", -_figure_box.size.y - 0.5, drown_time)
	down.parallel().tween_property(_model, "rotation_degrees:z", _random.randf_range(-25.0, 25.0), drown_time)
	down.tween_callback(func() -> void:
		if not _dead:
			_stats.gezondheid = Vector2(0.0, _stats.gezondheid.y)
			_push_stats()
			_die("verdronken"))


## The arms and legs while drowning, `time` seconds in: waving over the head, kicking.
func _flail(time: float) -> void:
	var tiring := clampf(1.0 - time / drown_time, 0.0, 1.0) * 0.6 + 0.4
	_model.pose_limb("arm_left", Vector3(sin(time * 13.0) * 30.0, 0.0, (-150.0 + sin(time * 17.0) * 35.0) * tiring))
	_model.pose_limb("arm_right", Vector3(-sin(time * 13.0 + 1.3) * 30.0, 0.0, (150.0 - sin(time * 17.0 + 0.8) * 35.0) * tiring))
	_model.pose_limb("leg_left", Vector3(sin(time * 9.0) * 25.0 * tiring, 0.0, 0.0))
	_model.pose_limb("leg_right", Vector3(-sin(time * 9.0) * 25.0 * tiring, 0.0, 0.0))


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

## Lies down on its back (at once).
func _fall_asleep() -> void:
	_sleeping = true
	_sleep_left = sleep_seconds
	_model.idle = false
	_model.walking = 0.0
	# on its back (face up, head towards -z), its back on the ground, the middle of the body
	# about where it stood
	_model.rotation_degrees.x = -90.0
	_model.position = Vector3(0.0, -_figure_box.position.z, _figure_box.size.y * 0.45)


func _update_sleep(delta: float) -> void:
	var town_ready := true
	var level_of_detail := get_node_or_null(detail_path)
	if level_of_detail and level_of_detail.has_method("is_merging") and level_of_detail.is_merging():
		town_ready = false
	var follow_camera := get_node_or_null(follow_camera_path)
	# awake as the view comes down onto the player (before it has quite settled)
	if follow_camera and follow_camera.has_method("arrival_progress") and follow_camera.arrival_progress() < WAKE_AT_ARRIVAL:
		town_ready = false
	if town_ready:
		_sleep_left -= delta
	var key_pressed := false
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_ENTER]:
		if Input.is_physical_key_pressed(key):
			key_pressed = true
	if _sleep_left <= 0.0 or (town_ready and key_pressed):
		_wake_up()


## Gets up: sits up and stands, then can walk.
func _wake_up() -> void:
	_sleep_left = INF
	var rise := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(_model, "rotation_degrees:x", 0.0, wake_time)
	rise.parallel().tween_property(_model, "position", Vector3.ZERO, wake_time)
	# up on its feet facing the camera (its face to you, not its back)
	var facing_camera := _yaw_towards_camera()
	if not is_nan(facing_camera):
		var from_yaw := rotation.y
		var to_yaw := from_yaw + angle_difference(from_yaw, facing_camera)
		rise.parallel().tween_property(self, "rotation:y", to_yaw, wake_time).set_trans(Tween.TRANS_SINE)
	rise.tween_callback(func() -> void:
		_sleeping = false
		_model.idle = true
		woke_up.emit())


## The heading (rotation.y) that turns the figure's face to the camera; NAN without one.
func _yaw_towards_camera() -> float:
	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	if camera == null:
		return NAN
	var towards := camera.global_position - global_position
	towards.y = 0.0
	if towards.length_squared() < 0.0001:
		return NAN
	return atan2(towards.x, towards.z)


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


## The damage indicator: the health lost, in red, floating up from over the head.
const DAMAGE_COLOUR := Color("#FF4D5E")
const DAMAGE_NUMBER_HEIGHT := 2.1


func _hurt(amount: float, cause: String) -> void:
	if _dead or amount <= 0.0:
		return
	var health: Vector2 = _stats.gezondheid
	_stats.gezondheid = Vector2(maxf(health.x - amount, 0.0), health.y)
	_blink_left = maxf(_blink_left, hurt_blink_time)
	hurt.emit(amount)
	if _hud and _hud.has_method("show_floating_number"):
		_hud.show_floating_number(global_position + Vector3.UP * DAMAGE_NUMBER_HEIGHT,
				"-%d" % maxi(roundi(amount), 1), DAMAGE_COLOUR, 18)
	_push_stats()
	if _stats.gezondheid.x <= 0.0:
		_die(cause)


## Run over and killed: the hit in slow motion. The game runs at DEATH_SLOW_MOTION of its
## speed (the physics stepping as often in real time, so the figure flies smoothly; the sound
## slowed down with it, at least DEATH_SLOWEST_SOUND) while the follow camera zooms in on the
## figure, for DEATH_SLOW_SECONDS real seconds; then the speed comes back over
## DEATH_SPEED_UP seconds and the death screen comes up.
const DEATH_SLOW_MOTION := 0.15
const DEATH_SLOWEST_SOUND := 0.45
const DEATH_SLOW_SECONDS := 2.2
const DEATH_SPEED_UP := 0.5
var _normal_physics_ticks := 60


func _die(cause: String) -> void:
	_dead = true
	_running = false
	_model.walking = 0.0
	_model.idle = false
	# the dramatic cry as it goes down (pijn_<voice>_dood: long, falling, with the echo of a
	# fighting game's KO); not under water
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio and not _drowning:
		audio.play_event(global_position + Vector3.UP * 0.8, "pijn_%s_dood" % _voice)
	if _ragdoll == null and not _drowning:
		# falls over backwards where it stands
		var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(_model, "rotation_degrees:x", -90.0, 0.45)
		fall.parallel().tween_property(_model, "position:y", _model.position.y + _figure_box.size.z * 0.5, 0.45)
	died.emit(cause)
	# run over or starved: the dramatic slow motion with the view zooming in on the player
	if cause in SLOW_MOTION_DEATHS:
		_slow_motion_death(cause)
	elif _hud and _hud.has_method("show_death"):
		_hud.show_death(cause)


## The deaths that get the slow motion and the close-up (_slow_motion_death).
const SLOW_MOTION_DEATHS := ["aangereden", "honger"]


func _slow_motion_death(cause: String) -> void:
	var camera := get_parent().get_node_or_null("Volgcamera")
	if camera and camera.has_method("dramatic_close_up"):
		camera.dramatic_close_up(true)
	_normal_physics_ticks = Engine.physics_ticks_per_second
	_set_game_speed(DEATH_SLOW_MOTION)
	var speed_up := create_tween().set_ignore_time_scale(true)
	speed_up.tween_interval(DEATH_SLOW_SECONDS)
	speed_up.tween_method(_set_game_speed, DEATH_SLOW_MOTION, 1.0, DEATH_SPEED_UP).set_trans(Tween.TRANS_SINE)
	speed_up.tween_callback(func() -> void:
		if _hud and _hud.has_method("show_death"):
			_hud.show_death(cause))


## The speed of the game (Engine.time_scale), the physics stepping with it and the sound.
func _set_game_speed(speed: float) -> void:
	Engine.time_scale = speed
	Engine.physics_ticks_per_second = roundi(_normal_physics_ticks / speed)
	AudioServer.playback_speed_scale = maxf(speed, DEATH_SLOWEST_SOUND) if speed < 1.0 else 1.0


func _exit_tree() -> void:
	# never leaves the game slowed down (a restart, back to the menu)
	if Engine.time_scale != 1.0:
		_set_game_speed(1.0)


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
	if hit_by_moving(vehicle.velocity, vehicle.global_position):
		vehicle.shout_after_hit()


## Hit by something moving at `mover_velocity` from `from` (a vehicle, a train in the station):
## a slow nudge only steps aside; else damage by the speed, shards, knocked over along its way,
## a cry, and a moment no one can hit it again. Returns whether it was a real hit.
func hit_by_moving(mover_velocity: Vector3, from: Vector3) -> bool:
	if _ragdoll or _dead or _invulnerable_left > 0.0:
		return false
	var closing := mover_velocity - velocity
	var impact := closing.length()
	if impact < hit_speed_threshold:
		# a slow nudge: stepped out of its way
		var away := global_position - from
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_try_move(away.normalized() * 0.08)
		return false
	var damage := damage_per_speed * impact + damage_per_speed_squared * impact * impact
	var strength := clampf(impact / 20.0, 0.15, 1.0)
	var contact := global_position + Vector3.UP * _figure_box.get_center().y
	CrashBurst.spawn(get_parent(), contact, HIT_SHARD_COLOUR, strength)
	Vehicle.last_crash = {"at": contact, "strength": strength, "time": Time.get_ticks_msec() / 1000.0}
	_knock_down(mover_velocity, impact)
	_hurt(damage, "aangereden")
	if _dead:
		_thud(contact)   # the hit that kills: its thud; the death cry comes with the fall (_die)
	else:
		cry_out(strength >= hard_cry_strength, contact)
	_invulnerable_left = maxf(_invulnerable_left, knock_down_time)
	return true


## The thud of the hit and a cry of pain at `at`: the long one if `heavy`, else one of the
## short ones, never the same twice in a row.
func _thud(at: Vector3) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio:
		audio.play_event(at, BODY_HIT_SOUND)


func cry_out(heavy: bool, at: Vector3) -> void:
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio == null:
		return
	var cry_name := "pijn_%s_hard" % _voice
	if not heavy:
		var cry_number := _random.randi_range(1, SHORT_CRY_COUNT)
		if cry_number == _last_cry:
			cry_number = cry_number % SHORT_CRY_COUNT + 1
		_last_cry = cry_number
		cry_name = "pijn_%s_%d" % [_voice, cry_number]
	audio.play_event(at, BODY_HIT_SOUND)
	audio.play_event(at, cry_name)


## Thrown out of a building (Interiors.throw_out): out of the door with `push` (m/s, the way
## out) in a pike dive, tumbling over the pavement as it lands, THROW_DAMAGE health off; it
## gets up again by itself.
func thrown_out(push: Vector3) -> void:
	if _ragdoll or _dead:
		return
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio:
		audio.play_event(global_position + Vector3.UP * 1.0, KICK_SOUND)
	# flung out head first, a pike dive, tumbling over as it lands; it hurts when it lands
	_knock_down(push, push.length(), true)
	_invulnerable_left = maxf(_invulnerable_left, knock_down_time)
	_thrown_groan_pending = true
	if _ragdoll.has_signal("hit_hard"):
		_ragdoll.connect("hit_hard", _land_after_throw, CONNECT_ONE_SHOT)
	_thrown_close_up = true
	# dramatic: the camera in close, the flight in slow motion, then up to speed again
	var camera := get_parent().get_node_or_null("Volgcamera")
	if camera and camera.has_method("dramatic_close_up"):
		camera.dramatic_close_up(true)
	_normal_physics_ticks = Engine.physics_ticks_per_second
	_set_game_speed(THROW_SLOW_MOTION)
	var speed_up := create_tween().set_ignore_time_scale(true)
	speed_up.tween_interval(THROW_SLOW_SECONDS)
	speed_up.tween_method(_set_game_speed, THROW_SLOW_MOTION, 1.0, THROW_SPEED_UP).set_trans(Tween.TRANS_SINE)


## Getting up after being knocked over (_stand_up): seconds from lying to standing, in which
## it cannot walk yet.
const STAND_UP_SECONDS := 0.9
var _rising_left := 0.0


## Thrown out (thrown_out): the kick, the slow motion (game speed, real seconds it holds and
## takes to come back), and when the groan comes (seconds of game time after the kick: about
## when it lands, at the latest three times this).
const KICK_SOUND := "schop"
## How much health being thrown out costs (it hurts).
const THROW_DAMAGE := 12.0
const THROW_SLOW_MOTION := 0.3
const THROW_SLOW_SECONDS := 1.4
const THROW_SPEED_UP := 0.6
const THROW_GROAN_AFTER := 0.5
var _thrown_groan_pending := false
var _thrown_close_up := false


## Thrown out and landing (the body's first hard blow, KnockDownBody.hit_hard): only now it
## hurts (THROW_DAMAGE off, the figure blinks) and it groans.
func _land_after_throw(_speed: float) -> void:
	if not _thrown_groan_pending:
		return
	_thrown_groan_pending = false
	_hurt(THROW_DAMAGE, "eruit_gegooid")
	var audio := get_node_or_null("/root/RuimtelijkGeluid")
	if audio:
		audio.play_event(global_position + Vector3.UP * 0.4, "pijn_%s_kreun" % _voice)


## The figure becomes a RigidBody3D with its own box, thrown along with `push`.
func _knock_down(push: Vector3, impact: float, dive := false) -> void:
	_airborne = false
	_jump_pose(false)
	var box := BoxShape3D.new()
	box.size = _figure_box.size
	_ragdoll = KnockDown.throw(get_parent(), Transform3D(Basis(Vector3.UP, rotation.y), global_position),
			box, _figure_box.get_center(), body_mass, push, impact, _random, 1.1, 0.0, -1, dive)
	_ragdoll.add_collision_exception_with(_body)
	_body_shape.set_deferred("disabled", true)
	_model.walking = 0.0
	_model.idle = false
	_model.position = Vector3.ZERO
	_model.reparent(_ragdoll, not dive)
	if dive:
		# the figure lies along the body from the start (head first, flat)
		_model.transform = Transform3D.IDENTITY
	_ragdoll_clock = 0.0


## While knocked down: the node (and so the camera) stays with the body; once it lies still
## it stands up, unless dead.
func _follow_ragdoll(delta: float) -> void:
	_ragdoll_clock += delta
	global_position = _ragdoll.global_position
	# thrown out of a building and it never hit hard: still the landing, a little later
	if _thrown_groan_pending and _ragdoll_clock >= THROW_GROAN_AFTER * 3.0:
		_land_after_throw(0.0)
	if _dead:
		return
	var lies_still := _ragdoll.sleeping or _ragdoll.linear_velocity.length() < 0.3
	# thrown into the water: it drowns
	if _ragdoll_clock > 0.3 and _ragdoll.linear_velocity.y <= 0.5:
		var water := _water_point(_ragdoll.global_position)
		if water != Vector3.INF and _ragdoll.global_position.y - water.y < 0.8:
			_drown_from_ragdoll(water)
			return
	if (_ragdoll_clock >= knock_down_time and lies_still) or _ragdoll_clock >= knock_down_time * 3.0:
		_stand_up()


## The thrown body lands in the water: the figure back from the rigid body, then it sinks.
func _drown_from_ragdoll(water: Vector3) -> void:
	_model.reparent(self, false)
	_model.transform = Transform3D.IDENTITY
	_model.idle = false
	_model.walking = 0.0
	_ragdoll.queue_free()
	_ragdoll = null
	_body_shape.set_deferred("disabled", false)
	_sink(water)


func _stand_up() -> void:
	if _thrown_close_up:
		_thrown_close_up = false
		var camera := get_parent().get_node_or_null("Volgcamera")
		if camera and camera.has_method("dramatic_close_up"):
			camera.dramatic_close_up(false)
	var lying_at := _ragdoll.global_position
	var heading := _ragdoll.global_basis.z
	var spot := _walkable_near(lying_at, 1.5, 10.0)
	if spot == Vector3.INF:
		spot = _last_safe_position
	var lying := _model.global_transform
	_ragdoll.queue_free()
	_ragdoll = null
	_body_shape.set_deferred("disabled", false)
	global_position = spot
	_figure_height = spot.y
	if Vector2(heading.x, heading.z).length_squared() > 0.01:
		rotation.y = atan2(heading.x, heading.z)
	_invulnerable_left = invulnerable_time
	_blink_left = maxf(_blink_left, invulnerable_time)
	# up again from how it lies: the figure turns and rises to standing (not in one frame)
	_model.reparent(self, false)
	_model.global_transform = lying
	var from := _model.transform
	_model.idle = false
	_rising_left = STAND_UP_SECONDS
	var rise := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_method(func(share: float) -> void: _model.transform = from.interpolate_with(Transform3D.IDENTITY, share),
			0.0, 1.0, STAND_UP_SECONDS)
	rise.tween_callback(func() -> void:
		_model.transform = Transform3D.IDENTITY
		_model.idle = true)


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


## Fits the collider (Botsvorm) and the shape it walks with to `box` round the figure (in its
## own space): at the start, and again when it puts on a rucksack.
## The figure is never quite still (breathing, the arms: PlayerModel's idle movement): standing
## it reaches up to some 3 cm further to the sides and 9 cm further forward than at rest. The
## collider gets that room round the box at rest (metres; -x/-z on the low side, +x/+z on the
## high side; the figure faces +z).
const POSE_ROOM_LOW := Vector3(0.04, 0.0, 0.02)
const POSE_ROOM_HIGH := Vector3(0.04, 0.02, 0.1)


## `rest` (the box round the figure at rest) with the room for its idle movement.
static func _with_pose_room(rest: AABB) -> AABB:
	return AABB(rest.position - POSE_ROOM_LOW, rest.size + POSE_ROOM_LOW + POSE_ROOM_HIGH)


func _fit_collider(box: AABB) -> void:
	_figure_box = box
	(_body_shape.shape as BoxShape3D).size = box.size
	_body_shape.position = box.get_center()
	var radius := maxf(box.size.x, box.size.z) * 0.5
	_walk_shape.radius = clampf(radius, 0.2, 0.45)
	_walk_shape.height = maxf(box.size.y - max_step - 0.05, 0.4)


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
