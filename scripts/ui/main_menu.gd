class_name MainMenu
extends Control
const ProtestFlag = preload("res://scripts/vehicles/protest_flag.gd")
const DeathBlink = preload("res://scripts/effects/death_blink.gd")
const VehicleFire = preload("res://scripts/effects/vehicle_fire.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")

## The title screen before the town opens (scenes/hoofdmenu.tscn, the main scene), after
## the design "Titelscherm" in the style of the HUD (scripts/ui/hud.gd): at once the night
## colour; meanwhile the small 3D map of the skyline round Centraal at night loads in the
## background (scenes/menu_kaart.scn, baked
## by tools/build/build_menu_map.gd from scenes/menu_kaart_bron.tscn, which you edit) and
## fades in over it, shaded towards the left where the text is. Then the title, the menu, a footer with the keys and the
## version, and the CRT look over all of it (GameHud.make_crt_overlay).
## The menu (keys up/down, Enter, Escape; or the mouse):
## - VERDERGAAN and LADEN: greyed out and skipped until there are saved games;
## - NIEUW SPEL: opens the town (scenes/stad.tscn; "LADEN…" while it loads, then the town's
##   own loading screen);
## - INSTELLINGEN: the CRT effect and the scanlines on or off (user://instellingen.cfg, read
##   by the HUD);
## - CREDITS: who made it, rolling (every role, the same name);
## - AFSLUITEN: quits.
## The design is laid out at 1280 x 720 and scales with the window.

const CITY_SCENE := "res://scenes/stad.tscn"
## The baked 3D map behind the menu (tools/build/build_menu_map.gd), loaded in the
## background, and the seconds in which it fades in over the drawn backdrop.
const MAP_SCENE := "res://scenes/menu_kaart.scn"
const MAP_FADE_SECONDS := 1.5
## Seconds the menu takes to come up out of the black of the intro.
const UP_FROM_BLACK := 3.5
## The music of the menu, played whole and looped, at full volume from the first moment
## the menu opens (no fade in: it starts with a bang); its volume (dB) and the seconds it
## fades out when the town opens.
const MUSIC := "res://assets/audio/muziek/menu.mp3"
const MUSIC_VOLUME_DB := 0.0
const MUSIC_FADE_OUT := 2.0
const DESIGN_SIZE := Vector2(1280, 720)
const VERSION := "v0.1.0"
## Settings shared with the HUD (GameHud reads them in _ready).
const SETTINGS_PATH := "user://instellingen.cfg"

const SKY := Color("#0E1130")
## Star colours (the intro draws its stars with them).
const STAR_BRIGHT := Color("#F2E8C9")
const STAR_DIM := Color("#8A90C0")
const TITLE_COLOUR := Color("#F4EEDD")
const SOFT_TEXT := Color("#C9CCE6")

## The menu: label, whether it can be chosen now, and what it does.
const ITEMS := [
	["VERDERGAAN", false, "continue"],
	["NIEUW SPEL", true, "new_game"],
	["LADEN", false, "load"],
	["INSTELLINGEN", true, "settings"],
	["CREDITS", true, "credits"],
	["AFSLUITEN", true, "quit"],
]
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

var _design: Control             # everything laid out at DESIGN_SIZE, scaled to the window
var _buttons: Array[Button] = []
var _selected := 1
var _panel: Control              # the open settings or credits panel, if any
var _loading := false
var _font_title: Font
var _font_title_medium: Font
var _font_pixel: Font
var _font_body: Font
var _crt: ColorRect
var _sky: ColorRect               # the drawn night sky (until the 3D map is there)
var _backdrop: Control            # what is drawn before the 3D map is there (now nothing)
var _map_loading := false
var _opened_on_frame := 0
var _music: AudioStreamPlayer

var _title_column: Control
var _menu_box: Control
var _footer: Array = []
var _map_camera: Camera3D
var _camera_start := Transform3D.IDENTITY
var _panned := 0.0                # metres the camera has glided (0 .. the period)
var _period := 0.0                # metres after which the map repeats (0: no gliding)


func _ready() -> void:
	_opened_on_frame = Engine.get_process_frames()
	_load_fonts()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# the night colour shows at once; the 3D map loads meanwhile (it is big) and fades in
	# over it when it is there (_process, _show_map)
	_sky = ColorRect.new()
	_sky.color = SKY
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_design = Control.new()
	_design.name = "Ontwerp"
	_design.size = DESIGN_SIZE
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design)
	_backdrop = Control.new()
	_backdrop.name = "Achtergrond"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_backdrop)
	if ResourceLoader.exists(MAP_SCENE):
		# the intro has loaded it already, as a rule: then it is there at once
		if ResourceLoader.load_threaded_get_status(MAP_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(MAP_SCENE)
		_map_loading = true
	_build_title()
	_build_menu()
	_build_footer()
	var settings := _read_settings()
	_crt = GameHud.make_crt_overlay(0.05 if settings.crt else 0.0, 0.035 if settings.crt else 0.0,
			0.1 if settings.scanlines else 0.0, get_viewport().get_visible_rect().size)
	add_child(_crt)
	# now and then the picture is disturbed (a rolling band, VHS tracking)
	_crt.add_child(load("res://scripts/ui/crt_disturbance.gd").new())
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_select(_selected, false)
	_play_entrance()
	_start_music()


## Fades the menu music out as the menu is left: it moves to the root of the tree (which
## stays when the town opens), fades there, and is freed when silent.
func _fade_out_music() -> void:
	if _music == null or not _music.playing:
		return
	var music := _music
	_music = null
	music.reparent(get_tree().root)
	var fade := get_tree().create_tween()
	fade.tween_property(music, "volume_db", -60.0, MUSIC_FADE_OUT)
	fade.tween_callback(music.queue_free)


## Plays the menu music, looped as a whole, at once at full volume (imported by the editor; if it has not
## been imported yet, read straight from the file).
func _start_music() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(MUSIC):
		stream = load(MUSIC)
	elif FileAccess.file_exists(MUSIC):
		stream = AudioStreamMP3.load_from_file(MUSIC)
	if stream == null:
		push_warning("main menu: no music at %s" % MUSIC)
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	_music = AudioStreamPlayer.new()
	_music.name = "Muziek"
	_music.stream = stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()


## The menu comes in, slowly, in two parts: first the logo (the title column) slides in from
## the left as it fades in (TITLE_SECONDS); when it is nearly there (MENU_AFTER) the items
## follow one by one (ENTRANCE_ITEM_DELAY apart), then the footer; the picture loses its
## tracking for a moment as if the tape just started. The menu works at once (keys during it
## count).
const ENTRANCE_SLIDE := 40.0
const TITLE_SECONDS := 2.4
const MENU_AFTER := 1.8
const ENTRANCE_SECONDS := 1.6
const ENTRANCE_ITEM_DELAY := 0.22


func _play_entrance() -> void:
	var entrance := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var title_at := _title_column.position
	_title_column.position = title_at - Vector2(ENTRANCE_SLIDE, 0)
	_title_column.modulate.a = 0.0
	entrance.tween_property(_title_column, "position", title_at, TITLE_SECONDS)
	entrance.tween_property(_title_column, "modulate:a", 1.0, TITLE_SECONDS)
	var menu_at := _menu_box.position
	_menu_box.position = menu_at - Vector2(ENTRANCE_SLIDE, 0)
	_menu_box.modulate.a = 0.0
	entrance.tween_property(_menu_box, "modulate:a", 1.0, 0.3).set_delay(MENU_AFTER)
	entrance.tween_property(_menu_box, "position", menu_at, ENTRANCE_SECONDS + ENTRANCE_ITEM_DELAY * _buttons.size()).set_delay(MENU_AFTER)
	for index in _buttons.size():
		_buttons[index].modulate.a = 0.0
		entrance.tween_property(_buttons[index], "modulate:a", 1.0, ENTRANCE_SECONDS * 0.8).set_delay(MENU_AFTER + ENTRANCE_ITEM_DELAY * index)
	for footer_label: CanvasItem in _footer:
		footer_label.modulate.a = 0.0
		entrance.tween_property(footer_label, "modulate:a", 1.0, ENTRANCE_SECONDS).set_delay(MENU_AFTER + 0.3 + ENTRANCE_ITEM_DELAY * _buttons.size())
	# the tape starting: a short loss of tracking that settles
	var material := _crt.material as ShaderMaterial
	material.set_shader_parameter("tracking", 0.8)
	entrance.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), 0.8, 0.0, 1.6)


func _process(delta: float) -> void:
	_drift(delta)
	_drive_columns(delta)
	_ride_tram(delta)
	_place_helicopter_circle()
	if _map_loading:
		var status := ResourceLoader.load_threaded_get_status(MAP_SCENE)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_map_loading = false
			_show_map(ResourceLoader.load_threaded_get(MAP_SCENE) as PackedScene)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_map_loading = false   # no map: the drawn backdrop stays


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
		# loaded in the intro: the menu comes up out of the intro's black
		_sky.color = Color.BLACK
		_sky.modulate.a = 1.0
		shade.modulate.a = 1.0
		var up := create_tween()
		up.tween_property(_sky, "modulate:a", 0.0, UP_FROM_BLACK)
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


func _unhandled_input(event: InputEvent) -> void:
	if _loading:
		return
	if _panel != null:
		# a sub menu works as the main one: up/down, Enter, Escape (back)
		if event.is_action_pressed("ui_cancel"):
			_close_panel()
		elif event.is_action_pressed("ui_down"):
			_select_in_panel(posmod(_panel_selected + 1, _panel_buttons.size()))
		elif event.is_action_pressed("ui_up"):
			_select_in_panel(posmod(_panel_selected - 1, _panel_buttons.size()))
		elif event.is_action_pressed("ui_accept"):
			_choose_in_panel(_panel_selected)
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		return
	elif event.is_action_pressed("ui_down"):
		_select(_next_choosable(_selected, 1))
	elif event.is_action_pressed("ui_up"):
		_select(_next_choosable(_selected, -1))
	elif event.is_action_pressed("ui_accept"):
		_choose(_selected)
	else:
		return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ the menu

func _next_choosable(from: int, step: int) -> int:
	var index := from
	for _attempt in ITEMS.size():
		index = posmod(index + step, ITEMS.size())
		if ITEMS[index][1]:
			return index
	return from


func _select(index: int, audible := true) -> void:
	if audible and index != _selected:
		UiSounds.play(self, "kies")
	_selected = index
	for button_index in _buttons.size():
		_style_button(_buttons[button_index], button_index == index, ITEMS[button_index][1])


func _choose(index: int) -> void:
	if not ITEMS[index][1] or _loading:
		return
	UiSounds.play(self, "doe")
	match ITEMS[index][2]:
		"new_game":
			_open_city()
		"settings":
			_open_settings()
		"credits":
			_open_credits()
		"quit":
			_fade_out_music()
			_loading = true
			await get_tree().create_timer(MUSIC_FADE_OUT * 0.6).timeout
			get_tree().quit()


## Opens the town: "LADEN…" on the item, two frames so it shows, then the town; its own
## loading screen takes over from there. (The 3D map is baked, scenes/menu_kaart.scn, and
## shares nothing with the town: with the town's tile libraries in the menu, starting the
## town crashed Godot.)
func _open_city() -> void:
	_loading = true
	_buttons[1].text = _caret(true) + "LADEN…"
	if _map_loading:
		# the 3D map is still loading in the background: let it finish first, so no
		# background load runs while the town starts
		ResourceLoader.load_threaded_get(MAP_SCENE)
		_map_loading = false
	await _play_exit()
	# the 3D map goes first, wholly: with it still in memory while the town loads its huge
	# tile libraries, the memory ran out ("mem is null") and Godot crashed
	_free_map()
	for frame_index in 3:
		await get_tree().process_frame
	get_tree().change_scene_to_file(CITY_SCENE)


## Frees the 3D map and everything that holds on to it (camera, sun and moon, trams).
func _free_map() -> void:
	var map := get_parent().get_node_or_null("Menukaart")
	_map_camera = null
	_moon = null
	_sun_disc = null
	_day_cycle = null
	_trams.clear()
	_columns.clear()
	_wrecks.clear()
	if map:
		map.queue_free()


## The menu goes: the items fade out one by one, the title slides off to the left, then all
## fades to ink (the colour of the town's loading screen, which takes over) while the
## picture loses its tracking. Awaited before the town is opened.
const EXIT_SECONDS := 0.9


func _play_exit() -> void:
	var exit := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_out_music()
	for index in _buttons.size():
		exit.tween_property(_buttons[index], "modulate:a", 0.0, EXIT_SECONDS * 0.7).set_delay(ENTRANCE_ITEM_DELAY * 0.6 * index)
	exit.tween_property(_title_column, "position", _title_column.position - Vector2(ENTRANCE_SLIDE * 2.0, 0), EXIT_SECONDS)
	exit.tween_property(_title_column, "modulate:a", 0.0, EXIT_SECONDS)
	for footer_label: CanvasItem in _footer:
		exit.tween_property(footer_label, "modulate:a", 0.0, EXIT_SECONDS * 0.6)
	# to ink over everything (the night colour of the start, now in front)
	_sky.color = GameHud.INK
	move_child(_sky, get_child_count() - 2)   # under the CRT overlay, over the rest
	exit.tween_property(_sky, "modulate:a", 1.0, EXIT_SECONDS).set_delay(EXIT_SECONDS * 0.6)
	var material := _crt.material as ShaderMaterial
	exit.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), 0.0, 1.0, EXIT_SECONDS * 1.6)
	await exit.finished


static func _caret(on: bool) -> String:
	return "▶  " if on else "    "


func _style_button(button: Button, on: bool, choosable: bool) -> void:
	var label: String = ITEMS[_buttons.find(button)][0]
	_style_menu_button(button, on, choosable, label)


## The look of an item of a menu: amber with a hard shadow and a caret when chosen, else
## plain text (dimmed when it cannot be chosen); `label` its text.
func _style_menu_button(button: Button, on: bool, choosable: bool, label: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameHud.ACCENT if on else Color(0, 0, 0, 0)
	style.shadow_color = Color.BLACK if on else Color(0, 0, 0, 0)
	style.shadow_offset = Vector2(4, 4) if on else Vector2.ZERO
	style.shadow_size = 0
	style.anti_aliasing = false
	style.content_margin_left = 12
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	var colour := GameHud.INK if on else (GameHud.TEXT if choosable else GameHud.BORDER.lightened(0.15))
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(colour_name, colour)
	if not (_loading and on):
		button.text = _caret(on) + label


func _build_menu() -> void:
	var menu := VBoxContainer.new()
	menu.name = "Menu"
	menu.position = Vector2(96, 360)
	menu.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	menu.add_theme_constant_override("separation", 4)
	_design.add_child(menu)
	_menu_box = menu
	for index in ITEMS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(MENU_WIDTH, MENU_ITEM_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", _font_title_medium)
		button.add_theme_font_size_override("font_size", 22)
		button.disabled = not ITEMS[index][1]
		button.mouse_entered.connect(func() -> void:
			if ITEMS[index][1] and _panel == null and not _loading:
				_select(index))
		button.pressed.connect(func() -> void:
			_select(index)
			_choose(index))
		menu.add_child(button)
		_buttons.append(button)


# ------------------------------------------------------------------ panels

func _open_settings() -> void:
	var settings := _read_settings()
	var column := _open_panel("INSTELLINGEN")
	for entry: Array in [["CRT-BEELD", "crt"], ["SCANLIJNEN", "scanlines"]]:
		var setting: String = entry[1]
		var label := func() -> String: return "%s: %s" % [entry[0], "AAN" if settings[setting] else "UIT"]
		_add_panel_item(column, label, func() -> void:
			settings[setting] = not settings[setting]
			_write_settings(settings)
			_apply_crt(settings))
	_add_panel_item(column, func() -> String: return "TERUG", _close_panel)
	_select_in_panel(0, false)


## The credits roll: every role in the making of the game, each with the same name under
## it, rolling up through a window of the panel (CREDITS_HEIGHT high) at CREDITS_SPEED
## pixels a second, over and over; the fonts and the engine at the end.
const CREDITS_NAME := "Diederick Lawson"
const CREDITS_ROLES := [
	"Bedacht door", "Geschreven door", "Regie", "Spelontwerp", "Programmering",
	"Voxelkunst", "Stadsplanning", "Tramdienstregeling", "Verkeerslichten",
	"Trekkerchoreografie", "Politie-inzet", "Brandweer en blusmiddelen", "Meeuwengedrag",
	"Muziekkeuze", "Geluidseffecten", "Plat Haags", "Statiegeldadministratie",
	"Winkelwagenonderhoud", "Stuntzwerver", "Catering (broodjes bal)", "Kwaliteitscontrole",
	"Koffie", "Met dank aan",
]
const CREDITS_HEIGHT := 240.0
const CREDITS_SPEED := 28.0


func _open_credits() -> void:
	var column := _open_panel("CREDITS")
	_panel.position.y = 250   # higher than the settings: the roll is tall
	var window := Control.new()
	window.custom_minimum_size = Vector2(PANEL_WIDTH, CREDITS_HEIGHT)
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(window)
	var roll := VBoxContainer.new()
	roll.add_theme_constant_override("separation", 4)
	roll.position = Vector2(0, CREDITS_HEIGHT)
	roll.size = Vector2(PANEL_WIDTH, 0)
	window.add_child(roll)
	for role: String in CREDITS_ROLES:
		roll.add_child(_credits_line(role.to_upper(), _font_pixel, 11, MUTED_TEXT))
		roll.add_child(_credits_line(CREDITS_NAME, _font_body, 15, SOFT_TEXT))
		roll.add_child(_credits_gap(14))
	for line in ["Lettertypen: Silkscreen, Pixelify Sans,", "JetBrains Mono (SIL Open Font License)",
			"Engine: Godot (MIT-licentie)"]:
		roll.add_child(_credits_line(line, _font_body, 12, MUTED_TEXT))
	_add_panel_item(column, func() -> String: return "TERUG", _close_panel)
	_select_in_panel(0, false)
	# once laid out (its height known): roll it from under the window to above it, again
	# and again, as long as the panel is open (the tween goes with the roll)
	await get_tree().process_frame
	if not is_instance_valid(roll):
		return
	var travel := CREDITS_HEIGHT + roll.get_combined_minimum_size().y
	var rolling := roll.create_tween().set_loops()
	rolling.tween_property(roll, "position:y", -roll.get_combined_minimum_size().y, travel / CREDITS_SPEED).from(CREDITS_HEIGHT)


func _credits_line(line: String, font: Font, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = line
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _credits_gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


## A panel beside the menu (as the save preview of the design): a bordered ink box with a
## hard shadow and a title; returns the column to fill.
func _open_panel(title: String) -> VBoxContainer:
	_close_panel()
	_panel_selected = 0
	var holder := Control.new()
	holder.position = Vector2(500, 360)
	_design.add_child(holder)
	var shadow := ColorRect.new()
	shadow.color = Color.BLACK
	shadow.position = Vector2(6, 6)
	holder.add_child(shadow)
	var box := PanelContainer.new()
	var style := GameHud._box_style(Color(11.0 / 255.0, 13.0 / 255.0, 26.0 / 255.0, 0.92), GameHud.BORDER, 3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = Vector2(340, 0)
	holder.add_child(box)
	box.resized.connect(func() -> void: shadow.size = box.size)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	box.add_child(column)
	column.add_child(_small(title, MUTED_TEXT))
	_panel = holder
	return column


const MUTED_TEXT := Color("#9AA0C8")


func _close_panel() -> void:
	if _panel:
		UiSounds.play(self, "terug")
		_panel.queue_free()
		_panel = null
		_panel_buttons.clear()
		_panel_labels.clear()
		_panel_actions.clear()


# ------------------------------------------------------------------ sub menus

## The items of the open sub menu (settings, credits): buttons styled as the main menu's,
## their text (a Callable: it may change, "AAN"/"UIT") and what choosing them does.
var _panel_buttons: Array[Button] = []
var _panel_labels: Array[Callable] = []
var _panel_actions: Array[Callable] = []
var _panel_selected := 0
const PANEL_WIDTH := 300.0


func _add_panel_item(column: VBoxContainer, label: Callable, action: Callable) -> void:
	var index := _panel_buttons.size()
	var button := Button.new()
	button.custom_minimum_size = Vector2(PANEL_WIDTH, MENU_ITEM_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", _font_title_medium)
	button.add_theme_font_size_override("font_size", 20)
	button.mouse_entered.connect(func() -> void: _select_in_panel(index))
	button.pressed.connect(func() -> void:
		_select_in_panel(index, false)
		_choose_in_panel(index))
	column.add_child(button)
	_panel_buttons.append(button)
	_panel_labels.append(label)
	_panel_actions.append(action)


func _select_in_panel(index: int, audible := true) -> void:
	if audible and index != _panel_selected:
		UiSounds.play(self, "kies")
	_panel_selected = index
	for button_index in _panel_buttons.size():
		_style_menu_button(_panel_buttons[button_index], button_index == index, true, _panel_labels[button_index].call())


func _choose_in_panel(index: int) -> void:
	if index < 0 or index >= _panel_actions.size():
		return
	var action := _panel_actions[index]
	var closes: bool = _panel_labels[index].call() == "TERUG"
	if not closes:
		UiSounds.play(self, "doe")
	action.call()
	if _panel != null and not closes:
		_select_in_panel(_panel_selected, false)   # the text may have changed (AAN/UIT)


# ------------------------------------------------------------------ settings

static func _read_settings() -> Dictionary:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return {"crt": config.get_value("beeld", "crt", true), "scanlines": config.get_value("beeld", "scanlijnen", true)}


static func _write_settings(settings: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("beeld", "crt", settings.crt)
	config.set_value("beeld", "scanlijnen", settings.scanlines)
	config.save(SETTINGS_PATH)


func _apply_crt(settings: Dictionary) -> void:
	var material := _crt.material as ShaderMaterial
	material.set_shader_parameter("curvature", 0.05 if settings.crt else 0.0)
	material.set_shader_parameter("corner", 0.035 if settings.crt else 0.0)
	material.set_shader_parameter("scanline_strength", 0.1 if settings.scanlines else 0.0)


# ------------------------------------------------------------------ the picture

## Darkens the 3D map towards the left edge, where the title and the menu stand.
static func _left_shade() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(GameHud.INK, 0.85))
	gradient.set_color(1, Color(GameHud.INK, 0.0))
	gradient.add_point(0.45, Color(GameHud.INK, 0.6))
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


func _build_title() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(96, 96)
	column.add_theme_constant_override("separation", 10)
	_design.add_child(column)
	_title_column = column
	column.add_child(_small("EEN ZWERFTOCHT", GameHud.ACCENT, 13, 6))
	var title := Label.new()
	title.text = "ZWERVR"
	title.add_theme_font_override("font", _font_title)
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", TITLE_COLOUR)
	title.add_theme_color_override("font_shadow_color", GameHud.INK)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_outline_size", 0)
	column.add_child(title)


func _build_footer() -> void:
	var keys := _small("[↑↓] KIEZEN      [ENTER] KIES      [ESC] TERUG", SOFT_TEXT)
	keys.position = Vector2(96, 720 - 32 - 16)
	_design.add_child(keys)
	var version := _small("%s - ZWERVR" % VERSION, MUTED_TEXT)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.size = Vector2(400, 16)
	version.position = Vector2(1280 - 32 - 400, 720 - 32 - 16)
	_design.add_child(version)
	_footer = [keys, version]


## A line of small pixel text (Silkscreen), optionally letter-spaced.
func _small(text: String, colour: Color, size := 11, spacing := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", GameHud._spaced(_font_pixel, spacing) if spacing > 0 else _font_pixel)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fit_to_window() -> void:
	var window := get_viewport().get_visible_rect().size
	var factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	_design.scale = Vector2(factor, factor)
	_design.position = (window - DESIGN_SIZE * factor) * 0.5
	if _crt:
		(_crt.material as ShaderMaterial).set_shader_parameter("screen_size", window)


func _load_fonts() -> void:
	var fallback: Font = load("res://assets/fonts/Rubik.ttf")
	var title: Font = load("res://assets/fonts/PixelifySans.ttf") if ResourceLoader.exists("res://assets/fonts/PixelifySans.ttf") else fallback
	_font_title = GameHud._weighted(title, 700)
	_font_title_medium = GameHud._weighted(title, 600)
	_font_pixel = load("res://assets/fonts/Silkscreen-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/Silkscreen-Regular.ttf") else fallback
	var body: Font = load("res://assets/fonts/JetBrainsMono.ttf") if ResourceLoader.exists("res://assets/fonts/JetBrainsMono.ttf") else fallback
	_font_body = GameHud._weighted(body, 400)
	# the ▶ and arrows the pixel fonts may lack come from JetBrains Mono
	if body != fallback:
		var fallbacks: Array[Font] = [body]
		for font: Font in [title, _font_pixel]:
			if font != fallback:
				font.fallbacks = fallbacks
