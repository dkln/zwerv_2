class_name GameHud
extends CanvasLayer
## The game HUD (the "HUD" node of the city scene), in the pixel style of the design
## "HUD — open world" (1280 x 720; everything scales with the window, the corners stay in
## the corners):
## The parts of it are scripts of their own in scripts/ui/hud/ (player_frame, notice_banner,
## quest_tracker, minimap, location, waypoint, clock, money_view, crt_view; each in the four
## layers of docs/CODE_LAGEN.md: _rules, _layout, _view and the part itself; where they
## stand: hud_layout.gd) and scripts/ui/screens/. This script makes them, hands on what the
## game tells it, and keeps the order of the screens that hold the game (modal_rules.gd).
## - top left: the player frame (the chosen figure's head in 3D, PlayerCharacter and
##   PlayerModel, with level badge, its name) and the stats as
##   segmented pixel bars with an icon each (STATS: gezondheid, uithoudingsvermogen,
##   honger, overprikkeldheid), set with set_stat(name, value, maximum), and under them the
##   experience: "XP" and a segment bar as the stats, "6.420 / 10.000" under the bar
##   (set_xp(points, points_for_level));
## - top centre: the notice, fading in and out: "nieuw gebied ontdekt" with the name of the
##   area (show_area), or "nieuwe missie" with its title and a jingle (show_mission); one at a
##   time, the next waits until the one before has gone;
## - top right: a minimap of 200 x 200 (north up, the player arrow in the middle) with the
##   day and the time below it. The map is one Image built once from the Grond GridMap (a
##   colour per kind of ground) and the Gebouwen GridMap (dark), no extra camera; it shows
##   the area round the followed vehicle (Volgcamera) or the point the camera looks at. The
##   time comes from the Dagcyclus node (time_of_day; a day passes when it goes round), or
##   from set_time when there is none;
## - right: the quest tracker (set_quests), hidden while there are no quests; the tracked
##   quest (track_quest, chosen in the game menu; else the first) on top with how far its
##   nearest place is, and those places (quest_targets) on the minimap (QuestMarks);
## - under the minimap: where the player is (the followed vehicle, else the point the
##   camera looks at): the neighbourhood (scene metadata "wijken" from the city builder),
##   the street ("straten", with the pavement beside it) and the nearest named place
##   ("places") within place_near metres, in a box as wide as the minimap over it; entering a
##   neighbourhood for the first time shows it as a new area (show_area);
## - bottom right: the money in euros (set_money);
## - bottom left: the context actions (ActionPrompts, set_actions: "[E] Praten" near someone);
## - the pause menu (Escape: the game stands still; scripts/ui/screens/pause_menu.gd);
## - the game menu as a child (Spelmenu, scripts/ui/game_menu.gd: inventory, quests, map);
## - the death screen (show_death, when the player dies; scripts/ui/screens/death_screen.gd);
## - the music of the town and the jingles over it (`music`, scripts/audio/city_music.gd);
## - the story box (show_story, scripts/ui/story_box.gd): story, thoughts and missions
##   appearing word by word, with the player's portrait;
## - the shop screen (show_shop, scripts/ui/shop_screen.gd): talking to someone who sells
##   (a snack bar, the shops of Den Haag Centraal), their goods to buy;
## - the reward screen (show_reward, scripts/ui/reward_screen.gd): what a task, a mission or
##   someone in the street gave you, the item big and turning, with its own jingle; it
##   comes at once, over a conversation or the shop too (they go on after it), only a menu,
##   a machine or the loading screen it waits for;
## - a CRT look over the whole picture: the world bulges like a tube, its edges bending in
##   to black rounded corners (`crt_curvature`); the HUD bends with it, but less
##   (`crt_ui_curvature`), so its corners stay readable.
## Fonts: Silkscreen, Pixelify Sans and JetBrains Mono (assets/fonts, OFL); Rubik when
## one is missing.

const CityMusic = preload("res://scripts/audio/city_music.gd")
const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const StatLook = preload("res://scripts/ui/hud/stat_look.gd")
const MapLook = preload("res://scripts/ui/hud/map_look.gd")
const PlayerFrame = preload("res://scripts/ui/hud/player_frame.gd")
const NoticeBanner = preload("res://scripts/ui/hud/notice_banner.gd")
const QuestRules = preload("res://scripts/ui/hud/quest_rules.gd")
const NoticeRules = preload("res://scripts/ui/hud/notice_rules.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")
const QuestTracker = preload("res://scripts/ui/hud/quest_tracker.gd")
const QuestTrackerView = preload("res://scripts/ui/hud/quest_tracker_view.gd")
const Minimap = preload("res://scripts/ui/hud/minimap.gd")
const Location = preload("res://scripts/ui/hud/location.gd")
const LocationRules = preload("res://scripts/ui/hud/location_rules.gd")
const Waypoint = preload("res://scripts/ui/hud/waypoint.gd")
const WaypointRules = preload("res://scripts/ui/hud/waypoint_rules.gd")
const Clock = preload("res://scripts/ui/hud/clock.gd")
const MoneyView = preload("res://scripts/ui/hud/money_view.gd")
const ModalRules = preload("res://scripts/ui/hud/modal_rules.gd")
const CrtRules = preload("res://scripts/ui/hud/crt_rules.gd")
const CrtView = preload("res://scripts/ui/hud/crt_view.gd")
const FloatingNumbers = preload("res://scripts/ui/widgets/floating_numbers.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

## Where the parts stand: HudLayout.
const DESIGN_SIZE := HudLayout.DESIGN_SIZE
const MARGIN := HudLayout.MARGIN

## How the stats look (StatLook), under the names the other screens know them by.
const STATS := StatLook.STATS
const XP_COLOUR := StatLook.XP_COLOUR
const PIXEL_ICONS := StatLook.PIXEL_ICONS
const LOCKED_STEP_OPACITY := QuestTrackerView.LOCKED_STEP_OPACITY
## The colour of the marker you set on the map (MapLook), under the name the game menu
## knows it by.
const WAYPOINT_COLOUR := MapLook.WAYPOINT_COLOUR
## The colour of the player's thoughts over its head (show_thought), as the "gedachte" pages.
const THOUGHT_COLOUR := Color("#47D6C2")
## Placeholder quests to see the tracker (`show_example_quests`): not story content.
const EXAMPLE_QUESTS := [
	{"kind": "verhaal", "label": "VERHAAL", "title": "Voorbeeldopdracht", "distance": "240M",
		"steps": [{"text": "Eerste stap (klaar)", "done": true}, {"text": "Tweede stap", "done": false}]},
	{"kind": "zij", "label": "ZIJMISSIE", "title": "Voorbeeld zijmissie — 2/5"},
]

## How far the picture bulges like the glass of a CRT tube (0 = flat; the edges bend in by
## about this share of the screen at the corners).
@export_range(0.0, 0.2) var crt_curvature := 0.05:
	set(value):
		crt_curvature = value
		_update_crt()
## How far the HUD bends with it (less than the world, so its corners stay readable;
## at most crt_curvature).
@export_range(0.0, 0.2) var crt_ui_curvature := 0.02:
	set(value):
		crt_ui_curvature = value
		_update_crt()
## Rounding of the black corners of the tube (share of the screen height).
@export_range(0.0, 0.1) var crt_corner := 0.035:
	set(value):
		crt_corner = value
		_update_crt()
@export var player_name := "Speler"
@export var player_level := 1
## Metres across the minimap.
@export var minimap_metres := 160.0:
	set(value):
		minimap_metres = value
		if minimap:
			minimap.metres = value
## Metres within which the nearest named place shows under the neighbourhood.
@export var place_near := 45.0:
	set(value):
		place_near = value
		if location:
			location.place_near = value
## The day the game starts on (the day counter goes up when Dagcyclus goes round midnight).
@export var start_day := 1
## Shows EXAMPLE_QUESTS (to see the tracker).
@export var show_example_quests := false
@export var camera_path := NodePath("../Camera")
@export var follow_camera_path := NodePath("../Volgcamera")
@export var day_cycle_path := NodePath("../Dagcyclus")
@export var ground_path := NodePath("../Grond")
@export var buildings_path := NodePath("../Gebouwen")
## The story (scripts/story/story.gd): its shroud hides the parts of the town not yet open
## on the minimap and the map (Story.shroud, shroud_changed); its "markeringen" stay on the map.
@export var story_path := NodePath("../Verhaal")

## The game menu opened, or went to another tab while open (the story waits for it: "menu_open").
signal menu_opened(tab: String)

## The music of the town and the jingles over it (scripts/audio/city_music.gd, the node "Muziek").
var music: CityMusic
## The player frame, top left (scripts/ui/hud/player_frame.gd): portrait, name, stats, experience.
var player_frame: PlayerFrame
## The notice at the top (scripts/ui/hud/notice_banner.gd): a new area, a new mission.
var notices: NoticeBanner
## The quest tracker on the right (scripts/ui/hud/quest_tracker.gd) and its quests (QuestRules).
var quest_tracker: QuestTracker

## The minimap, top right (scripts/ui/hud/minimap.gd); over it where the player is
## (location.gd), under it the clock (clock.gd) and the marker set on the map (waypoint.gd).
var minimap: Minimap
var location: Location
var clock: Clock
var marker: Waypoint
## The money, bottom right (scripts/ui/hud/money_view.gd).
var money_panel: MoneyView
## The CRT look over the whole picture (scripts/ui/hud/crt_view.gd).
var crt: CrtView

var _font_title: Font        # Pixelify Sans, bold
var _font_pixel: Font        # Silkscreen
var _font_pixel_bold: Font   # Silkscreen bold
var _font_body: Font         # JetBrains Mono

var _root: Control
var _map_column: Control        # top right: the location, the minimap, the clock and the marker
var _floating_numbers: FloatingNumbers
var _numbers_over_story: FloatingNumbers   # the same, drawn over the story box
## How long a number over the story box stays (the text is being read meanwhile).
const NUMBER_OVER_STORY_SECONDS := 2.2
var _ui_viewport: SubViewport   # the HUD's own picture (see _build_crt)
var _action_prompts: ActionPrompts


func _ready() -> void:
	layer = 10
	# it keeps running while the game is paused (the pause menu, the CRT picture)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crt_as_made = Vector3(crt_curvature, crt_ui_curvature, crt_corner)
	_read_menu_settings()
	music = CityMusic.new()
	music.name = "Muziek"
	music.loud_while_paused = is_showing_shop   # its music is the point of the shop
	add_child(music)
	GraphicsSettings.apply(get_tree())   # also when the town is started on its own
	_load_fonts()
	# the HUD is drawn into a picture of its own, which the CRT overlay lays over the world
	# bent a little less than the world (crt_ui_curvature)
	_ui_viewport = SubViewport.new()
	_ui_viewport.name = "HUDBeeld"
	_ui_viewport.transparent_bg = true
	_ui_viewport.disable_3d = true
	_ui_viewport.gui_disable_input = true
	_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_ui_viewport)
	_root = Control.new()
	_root.name = "Ontwerp"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_viewport.add_child(_root)
	# under everything else of the HUD: money picked up and damage, floating up
	_floating_numbers = FloatingNumbers.new()
	_floating_numbers.name = "ZwevendeGetallen"
	_floating_numbers.font = _font_pixel_bold
	_floating_numbers.world_viewport = get_viewport()
	_root.add_child(_floating_numbers)
	player_frame = PlayerFrame.new()
	player_frame.position = HudLayout.player_frame_position()
	_root.add_child(player_frame)
	notices = NoticeBanner.new()
	notices.jingle_wanted.connect(func(path: String) -> void: music.play_jingle(path, MISSION_JINGLE_VOLUME_DB, "MissieDeuntje"))
	_root.add_child(notices)
	_build_map_column()
	_action_prompts = ActionPrompts.new()
	_action_prompts.name = "Acties"
	_root.add_child(_action_prompts)
	quest_tracker = QuestTracker.new()
	_root.add_child(quest_tracker)
	_build_money()
	_build_pause_menu()
	_build_death_screen()
	_build_shop_screen()
	_build_story_box()
	_build_reward_screen()
	_build_level_up_screen()
	# over the story box: money given in a conversation, seen while it is still open
	_numbers_over_story = FloatingNumbers.new()
	_numbers_over_story.name = "ZwevendeGetallenOverVerhaal"
	_numbers_over_story.font = _font_pixel_bold
	_numbers_over_story.world_viewport = get_viewport()
	_numbers_over_story.lifetime = NUMBER_OVER_STORY_SECONDS
	_root.add_child(_numbers_over_story)
	_build_crt()
	# debug builds: F8, to a mission or a step of it (scripts/debug/mission_picker.gd)
	if OS.is_debug_build():
		var picker: CanvasLayer = preload("res://scripts/debug/mission_picker.gd").new()
		picker.name = "Missiekiezer"
		add_child(picker)
		# and F7 money, F9 experience (scripts/debug/debug_keys.gd)
		var debug_keys: Node = preload("res://scripts/debug/debug_keys.gd").new()
		debug_keys.name = "Debugtoetsen"
		add_child(debug_keys)
	# the game menu (Tab/I inventory, J quests, M map; scripts/ui/game_menu.gd)
	var game_menu: CanvasLayer = preload("res://scripts/ui/game_menu.gd").new()
	game_menu.name = "Spelmenu"
	add_child(game_menu)
	# the archetype chosen on the character creation screen (PlayerCharacter): its name,
	# its portrait and the maximum of its stats (hunger starts full, overstimulation empty;
	# the player, scripts/player/player_controller.gd, keeps them up to date)
	var archetype := PlayerCharacter.chosen_archetype()
	player_name = archetype.name
	player_level = archetype.get("level", player_level)
	for stat_name in STATS:
		var maximum := float(archetype.stats.get(stat_name, 100))
		set_stat(stat_name, 0.0 if stat_name == "overprikkeldheid" else maximum, maximum)
	set_player(player_name, player_level)
	set_xp(0.0, PlayerController.XP_FIRST_LEVEL)
	set_money(float(archetype.get("start_money", 0)))
	set_quests(EXAMPLE_QUESTS if show_example_quests else [])
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_build_minimap_picture.call_deferred()
	music.start_with_map_jingle.call_deferred()


## Inside a building (Interiors): its own loop in place of the city's (CityMusic.set_indoor);
## "" back to the city's.
func set_indoor_music(file: String) -> void:
	music.set_indoor(file)


## The loop of the building the player is in ("" outside).
func indoor_music() -> String:
	return music.indoor_file()


## Holds the music down while something else must be heard (CityMusic.duck); every true
## needs a false after it.
func duck_music(ducked: bool) -> void:
	music.duck(ducked)


func _process(delta: float) -> void:
	_lay_modal_over_menu()
	clock.follow(get_node_or_null(day_cycle_path))
	_follow_player()
	if location.tick(delta):
		_look_where_the_player_is()
		_update_quest_distance()
	_open_waiting_reward()
	_open_waiting_level_up()


# ------------------------------------------------------------------ API

## Sets a stat (STATS: "gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"):
## the bar fills to value / maximum; maximum < 0 keeps the last one (PlayerFrame.set_stat).
func set_stat(stat_name: String, value: float, maximum := -1.0) -> void:
	player_frame.set_stat(stat_name, value, maximum)


## The value and maximum of a stat (Vector2).
func get_stat(stat_name: String) -> Vector2:
	return player_frame.get_stat(stat_name)


## The experience: points so far within this level and the points the level takes; the
## bar fills to their share.
func set_xp(points: float, points_for_level: float) -> void:
	player_frame.set_xp(points, points_for_level)


## A step of a mission done (Story): a short triumph; the whole mission: the longer one.
const TASK_JINGLE := "res://assets/audio/muziek/deuntje_taak_klaar.ogg"
const MISSION_DONE_JINGLE := "res://assets/audio/muziek/deuntje_gewonnen.ogg"
const TASK_JINGLE_VOLUME_DB := -4.0


## A task of a mission done: its triumph tune (the whole mission done: the longer one).
func play_task_done(mission_done := false) -> void:
	music.play_jingle(MISSION_DONE_JINGLE if mission_done else TASK_JINGLE, TASK_JINGLE_VOLUME_DB, "TaakDeuntje")


const LEVEL_JINGLE := "res://assets/audio/muziek/deuntje_level_omhoog.ogg"
const LEVEL_JINGLE_VOLUME_DB := -3.0


## A level up: the new level on the badge, and the level-up screen (scripts/ui/level_up_screen.gd)
## with the jingle, where you choose a stat to raise: `choose` gets its name (the player's
## raise_stat), `current` gives (value, maximum) of a stat. It waits as a reward does
## (_open_waiting_level_up), and after the rewards waiting. Without `choose` only the notice.
func show_level_up(level: int, choose := Callable(), current := Callable()) -> void:
	set_player(player_name, level)
	if not choose.is_valid():
		notices.queue(NoticeRules.notice(NoticeRules.LEVEL_HEADING, NoticeRules.level_name(level), 3.5, LEVEL_JINGLE))
		return
	_level_ups_waiting.append({"level": level, "choose": choose, "current": current})
	# a frame later: a reward given with the XP (the same frame) joins it (show_reward)
	_open_waiting_level_up.call_deferred()


func is_showing_level_up() -> bool:
	return _level_up_screen != null and _level_up_screen.is_showing()


## The level ups still waiting for their screen.
func level_ups_waiting() -> Array[Dictionary]:
	return _level_ups_waiting


func set_player(new_name: String, level: int) -> void:
	player_name = new_name
	player_level = level
	player_frame.set_player(new_name, level)


const MISSION_JINGLE := "res://assets/audio/muziek/deuntje_nieuwe_missie.ogg"
const MISSION_JINGLE_VOLUME_DB := -3.0


## Shows "nieuw gebied ontdekt" with the name of the area for a few seconds.
func show_area(area_name: String, seconds := 4.0) -> void:
	notices.queue(NoticeRules.notice(NoticeRules.AREA_HEADING, area_name, seconds))


## Shows a notice of its own at the top ("heading" over "text"): the floor the lift of the
## city hall has brought you to.
func show_notice(heading: String, text: String, seconds := 3.0) -> void:
	notices.queue(NoticeRules.notice(heading, text, seconds))


## Shows "nieuwe missie" with the title of the mission and plays the mission jingle.
func show_mission(title: String, seconds := 4.5) -> void:
	notices.queue(NoticeRules.notice(NoticeRules.MISSION_HEADING, title, seconds, MISSION_JINGLE))


## True while a notice is up (for the tests).
func is_showing_notice() -> bool:
	return notices.is_showing()


## The quests in the tracker, top to bottom; empty = no tracker (what a quest is: QuestRules).
## The followed one stays followed; when it is done or gone the tracker goes on to the first
## open quest after it.
func set_quests(quests: Array) -> void:
	quest_tracker.set_quests(quests)
	_update_quest_distance()


static func is_quest_done(quest: Dictionary) -> bool:
	return QuestRules.is_done(quest)


## The quest to follow once `after_id` is done or gone (QuestRules.next_open_id).
func next_open_quest_id(after_id: String, previous_ids: Array = []) -> String:
	return quest_tracker.next_open_id(after_id, previous_ids)


static func quest_id(quest: Dictionary) -> String:
	return QuestRules.quest_id(quest)


func quest_by_id(id: String) -> Dictionary:
	return quest_tracker.by_id(id)


## Follows this quest (its places on the minimap and the map, on top of the tracker).
func track_quest(id: String) -> void:
	quest_tracker.track(id)
	_update_quest_distance()


func tracked_quest_id() -> String:
	return quest_tracker.tracked_id()


## The steps the tracker shows of `quest` (QuestRules.tracker_steps).
static func tracker_steps(quest: Dictionary) -> Array:
	return QuestRules.tracker_steps(quest)


## Where the tracked quest sends the player now: the targets of its first step not done
## (none while that step is locked), as world x, z.
func quest_targets() -> Array:
	return quest_tracker.targets()


# ------------------------------------------------------------------ the marker of the map

## A marker on `at` (world x, z), named `place_name` (scripts/ui/hud/waypoint.gd): on the
## minimap (an arrow on its edge while it is further), its name and distance under it, a
## beam of light on it in the town. Gone once you are there or with clear_waypoint. One at
## a time.
func set_waypoint(at: Vector2, place_name: String) -> void:
	marker.set_at(at, place_name)


func clear_waypoint() -> void:
	marker.clear()
	minimap.show_waypoint(marker.at())


func has_waypoint() -> bool:
	return marker.is_set()


func waypoint() -> Vector2:
	return marker.at()


func waypoint_name() -> String:
	return marker.place_name()


## The player reached the marker: "Aangekomen" rising over its head.
func _on_waypoint_arrived(place_name: String, focus: Vector3) -> void:
	show_floating_number(focus + Vector3.UP * 2.2, WaypointRules.arrived_text(place_name), WAYPOINT_COLOUR, 14)


## The minimap follows the player (the followed vehicle, else the point the camera looks
## at), the marker with it.
func _follow_player() -> void:
	if not _minimap_in_town().follow(quest_tracker.targets()):
		return
	marker.follow(minimap.focus(), not minimap.is_indoors())
	minimap.show_waypoint(marker.at())


## The minimap, knowing the nodes of the town it reads now (they may come and go).
func _minimap_in_town() -> Minimap:
	minimap.follow_camera = get_node_or_null(follow_camera_path)
	minimap.story = get_node_or_null(story_path)
	return minimap


## Where the player is (world x, z), from the last look of the minimap.
func _player_at() -> Vector2:
	var focus := minimap.focus()
	return Vector2(focus.x, focus.z)


## The location over the minimap: the neighbourhood, the street and the nearest place.
func _look_where_the_player_is() -> void:
	if minimap.is_focus_known():
		location.look(owner if owner else get_parent(), _player_at())


## How far the nearest place of the tracked quest is, in its panel ("120 M").
func _update_quest_distance() -> void:
	if minimap.is_focus_known():
		quest_tracker.show_distance_from(_player_at())


## The quests as last given to set_quests (for the game menu, scripts/ui/game_menu.gd).
func quests() -> Array:
	return quest_tracker.quests()


## The neighbourhoods the player has been in (names as in the "wijken" metadata).
func visited_areas() -> Array:
	return location.visited_areas()


## The minimap's picture of the whole map (one pixel per `minimap_metres_per_pixel()`
## metres, its corner at world x, z `minimap_origin()`), or null while it is not built yet.
func minimap_texture() -> Texture2D:
	return minimap.texture() if minimap else null


func minimap_origin() -> Vector2:
	return minimap.origin()


func minimap_metres_per_pixel() -> float:
	return minimap.metres_per_pixel()


## A number floating up from `world_position` and fading (widgets/floating_numbers.gd): the
## money picked up, the damage taken. `over_story`: drawn over the story box and its dimming
## (money given in a conversation), a while longer.
func show_floating_number(world_position: Vector3, text: String, colour: Color, font_size := 16, over_story := false) -> void:
	var numbers := _numbers_over_story if over_story and _numbers_over_story else _floating_numbers
	if numbers:
		numbers.spawn(world_position, text, colour, font_size)


## The money in the bottom right corner, to the cent (Dutch: "1.284,50"), so a coin of
## 10 cents shows too.
func set_money(euros: float) -> void:
	money_panel.show_amount(MoneyText.amount(euros))   # the euro sign is the icon before it


## The clock, when there is no Dagcyclus (or to override it): hour 0..24, and the day if >= 1.
func set_time(hour: float, day := -1) -> void:
	clock.set_time(hour, day)


# ------------------------------------------------------------------ building

func _load_fonts() -> void:
	var fonts := UiStyle.fonts()
	_font_title = fonts.title
	_font_pixel = fonts.pixel
	_font_pixel_bold = fonts.pixel_bold
	_font_body = fonts.body


## The column top right: where the player is, under it the minimap, the clock and the
## marker set on the map (where each stands: HudLayout).
func _build_map_column() -> void:
	_map_column = Control.new()
	_map_column.name = "Kaartkolom"
	_map_column.size = HudLayout.map_column_size()
	_map_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_map_column)
	minimap = Minimap.new()
	minimap.metres = minimap_metres
	minimap.world_viewport = get_viewport()
	minimap.position = HudLayout.map_in_column()
	_map_column.add_child(minimap)
	clock = Clock.new()
	clock.set_day(start_day)
	clock.position = HudLayout.clock_in_column()
	_map_column.add_child(clock)
	marker = Waypoint.new()
	marker.town = get_parent()
	marker.world_viewport = get_viewport()
	marker.position = HudLayout.waypoint_in_column()
	marker.arrived.connect(_on_waypoint_arrived)
	_map_column.add_child(marker)
	location = Location.new()
	location.place_near = place_near
	location.new_area_entered.connect(show_area)
	_map_column.add_child(location)


func _build_money() -> void:
	money_panel = MoneyView.new()
	money_panel.resized.connect(_place_corners)
	_root.add_child(money_panel)


# ------------------------------------------------------------------ pause menu

const PauseMenu = preload("res://scripts/ui/screens/pause_menu.gd")

## The pause menu (Escape; scripts/ui/screens/pause_menu.gd): the game stands still (the
## tree paused) and its panel offers going on, the settings, the main menu and quitting.
var pause_menu: PauseMenu
var _crt_as_made := Vector3.ZERO   # crt_curvature, crt_ui_curvature, crt_corner before the settings


func _build_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.resume_wanted.connect(set_paused.bind(false))
	pause_menu.crt_changed.connect(_set_crt)
	_root.add_child(pause_menu)


## The CRT look on or off (the settings of the pause menu), at once.
func _set_crt(on: bool) -> void:
	crt_curvature = CrtRules.curvature_when(on, _crt_as_made.x)
	crt_ui_curvature = CrtRules.curvature_when(on, _crt_as_made.y)
	_update_crt()


func _input(event: InputEvent) -> void:
	# a story box or reward screen over the game menu gets every key and click first (else the
	# menu, which takes all input while open, would keep them)
	# the level-up screen always takes the input itself (its rows answer the mouse too)
	if is_showing_level_up():
		_level_up_screen.handle_input(event)
		get_viewport().set_input_as_handled()
		return
	if _modal_over_menu():
		if is_showing_reward():
			_reward_screen.handle_input(event)
		else:
			_story_box.handle_input(event)
		get_viewport().set_input_as_handled()
		return
	# the HUD's picture takes no input of its own; while the pause menu is open the mouse
	# is handed to it (the picture has the size of the window)
	if (pause_menu.is_open() or is_showing_shop()) and event is InputEventMouse:
		_ui_viewport.push_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if is_showing_reward():
		if _reward_screen.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if _story_box and _story_box.is_showing():
		if _story_box.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if is_showing_shop():
		if _shop_screen.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if death_screen.is_open():
		death_screen.handle_input(event)
		return
	if pause_menu.is_open():
		if not pause_menu.handle_input(event):
			return
	elif event.is_action_pressed("ui_cancel"):
		set_paused(true)
	else:
		return
	# HOOFDMENU has taken it out of the tree already
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Pauses the game with the pause menu open, or goes on.
func set_paused(on: bool) -> void:
	pause_menu.set_open(on)
	_ui_viewport.gui_disable_input = not on
	get_tree().paused = on   # the city music follows by itself (CityMusic)


# ------------------------------------------------------------------ story box

const StoryBox = preload("res://scripts/ui/story_box.gd")

var _story_box: Control


func _build_story_box() -> void:
	_story_box = StoryBox.new()
	_story_box.name = "Verhaalvak"
	_story_box.font_title = _font_title
	_story_box.font_pixel = _font_pixel
	_story_box.font_body = _font_body
	_story_box.player_name = player_name if player_name != "" else PlayerCharacter.chosen_archetype().name
	_root.add_child(_story_box)


## Shows story pages, thoughts or a mission in the story box (pages: see story_box.gd);
## the game is paused meanwhile; `done` is called when the last page is closed.
func show_story(pages: Array, done := Callable()) -> void:
	_story_box.player_name = player_name
	_story_box.show_pages(pages, done)


func is_showing_story() -> bool:
	return _story_box != null and _story_box.is_showing()


# ------------------------------------------------------------------ reward screen

const RewardScreen = preload("res://scripts/ui/reward_screen.gd")
## Its own short tune (tools/muziek/derive.py "deuntje_beloning"), as a task done has one.
const REWARD_JINGLE := "res://assets/audio/muziek/deuntje_beloning.ogg"
const REWARD_JINGLE_VOLUME_DB := -4.0

var _reward_screen: Control
var _rewards_waiting: Array[Dictionary] = []


## Over the story box and the shop.
func _build_reward_screen() -> void:
	_reward_screen = RewardScreen.new()
	_reward_screen.name = "Beloningsscherm"
	_reward_screen.font_title = _font_title
	_reward_screen.font_pixel = _font_pixel
	_reward_screen.font_body = _font_body
	_root.add_child(_reward_screen)
	# closing, the game stays paused only while another of these screens is still up (never
	# paused again from a state remembered when it opened: the town would stand still)
	_reward_screen.keep_paused = func() -> bool: return ModalRules.keeps_paused(ModalRules.REWARD, _showing())
	if _story_box:
		_story_box.keep_paused = func() -> bool: return ModalRules.keeps_paused(ModalRules.STORY, _showing())
		# a conversation waits under the reward screen and goes on where it was after it
		_story_box.on_hold = func() -> bool: return ModalRules.is_story_on_hold(_showing())
	if _shop_screen:
		_shop_screen.keep_paused = func() -> bool: return ModalRules.keeps_paused(ModalRules.SHOP, _showing())


## What is showing now, as ModalRules wants it: the screens that hold the game and what
## they wait for.
func _showing() -> Dictionary:
	var showing := ModalRules.nothing_showing()
	showing[ModalRules.REWARD] = is_showing_reward()
	showing[ModalRules.LEVEL_UP] = is_showing_level_up()
	showing[ModalRules.STORY] = is_showing_story()
	showing[ModalRules.SHOP] = is_showing_shop()
	showing["conversation"] = is_showing_story() and _story_box.is_conversation()
	showing["pause_menu"] = pause_menu.is_open()
	showing["death"] = death_screen.is_open()
	showing["game_menu"] = _is_game_menu_open()
	showing["machine"] = is_inside_tree() and get_tree().root.has_node("Automaatscherm")
	showing["loading"] = is_inside_tree() and LoadingScreenScript.showing(get_tree())
	return showing


## A reward got (scripts/ui/reward_screen.gd: {"heading", "title", "xp", "items": [{"item",
## "count"}]}): its screen, once nothing else holds the game (the story box, the shop, the
## pause menu, the game menu, a machine's screen: the game is not paused), one after another;
## `done` is called once it is pressed away (at once when there is nothing to show).
func show_reward(reward: Dictionary, done := Callable()) -> void:
	# the XP that made a level up waiting goes onto the level-up screen (one screen for both):
	# a reward of only XP is then not shown on its own
	var joined_xp := ModalRules.xp_for_level_up(reward, _level_ups_waiting.size())
	if joined_xp > 0:
		var level_up: Dictionary = _level_ups_waiting.back()
		level_up["xp"] = int(level_up.get("xp", 0)) + joined_xp
		reward = reward.duplicate()
		reward["xp"] = 0
	if RewardScreen.pages_of(reward).is_empty():
		if done.is_valid():
			done.call()
		return
	var waiting := reward.duplicate()
	waiting["done"] = done
	_rewards_waiting.append(waiting)
	_open_waiting_reward()


func is_showing_reward() -> bool:
	return _reward_screen != null and _reward_screen.is_showing()


## The rewards still waiting for their screen.
func rewards_waiting() -> Array[Dictionary]:
	return _rewards_waiting


## A reward comes at once, also over a conversation or the shop (which wait under it and go
## on after); not over the pages of a story or a mission (its own pages come first), the
## pause menu, a machine's close-up, the loading screen or the death screen (it waits for
## those). Over the game menu it comes too (_lay_modal_over_menu).
func _open_waiting_reward() -> void:
	if _rewards_waiting.is_empty() or not is_inside_tree():
		return
	if not ModalRules.can_open_reward(_rewards_waiting.size(), _showing()):
		return
	var reward: Dictionary = _rewards_waiting.pop_front()
	_reward_screen.open(reward, reward.get("done", Callable()))
	music.play_jingle(REWARD_JINGLE, REWARD_JINGLE_VOLUME_DB, "Beloningsdeuntje")


# ------------------------------------------------------------------ level-up screen

const LevelUpScreen = preload("res://scripts/ui/level_up_screen.gd")

var _level_up_screen: Control
var _level_ups_waiting: Array[Dictionary] = []


## Over the reward screen.
func _build_level_up_screen() -> void:
	_level_up_screen = LevelUpScreen.new()
	_level_up_screen.name = "LevelOmhoogScherm"
	_level_up_screen.font_title = _font_title
	_level_up_screen.font_pixel = _font_pixel
	_level_up_screen.font_body = _font_body
	_level_up_screen.stat_looks = STATS
	_level_up_screen.pixel_icons = PIXEL_ICONS
	_root.add_child(_level_up_screen)
	_level_up_screen.keep_paused = func() -> bool: return ModalRules.keeps_paused(ModalRules.LEVEL_UP, _showing())


## The next level up, when nothing else needs the screen: as a reward (_open_waiting_reward:
## over a conversation, the shop and the game menu; not over story pages, the pause menu, a
## machine, the loading or death screen) and only once the rewards waiting have been shown.
func _open_waiting_level_up() -> void:
	if _level_ups_waiting.is_empty() or not is_inside_tree():
		return
	if not ModalRules.can_open_level_up(_level_ups_waiting.size(), _rewards_waiting.size(), _showing()):
		return
	var waiting: Dictionary = _level_ups_waiting.pop_front()
	var raise: Dictionary = PlayerController.LEVEL_UP_RAISE
	_level_up_screen.open(int(waiting.level), waiting.choose, waiting.get("current", Callable()), raise, int(waiting.get("xp", 0)))
	music.play_jingle(LEVEL_JINGLE, LEVEL_JINGLE_VOLUME_DB, "LevelDeuntje")


# ------------------------------------------------------------------ over the game menu

var _game_menu_layer := -1                  # the game menu's own layer (over the HUD)
var _hidden_for_modal: Array[CanvasItem] = []   # HUD parts hidden while a screen lies over the game menu


func _is_game_menu_open() -> bool:
	var game_menu := get_node_or_null("Spelmenu")
	return game_menu != null and game_menu.has_method("is_open") and game_menu.call("is_open")


## True while the story box (a conversation, a thought, a mission) or the reward screen shows
## with the game menu open (a thought about opening the inventory, a reward got meanwhile).
func _modal_over_menu() -> bool:
	return ModalRules.is_modal_over_menu(_is_game_menu_open(), is_showing_story(), is_showing_reward(), is_showing_level_up())


## The parts of the HUD hidden while a screen lies over the game menu.
func hidden_for_modal() -> Array[CanvasItem]:
	return _hidden_for_modal


## The game menu is a layer over the HUD; the story box and reward screen are part of the HUD.
## While one of them shows with the menu open the menu goes under the HUD, and the rest of
## the HUD (the bars, the minimap, the tracker) hides, so only that screen lies over the menu;
## after it all goes back.
func _lay_modal_over_menu() -> void:
	var game_menu := get_node_or_null("Spelmenu") as CanvasLayer
	if game_menu == null:
		return
	if _game_menu_layer == -1:
		_game_menu_layer = game_menu.layer
	var over := _modal_over_menu()
	game_menu.layer = ModalRules.menu_layer(over, layer, _game_menu_layer)
	if over and _hidden_for_modal.is_empty():
		for part in _root.get_children():
			if part is CanvasItem and part.visible and not part in [_story_box, _reward_screen, _level_up_screen, _numbers_over_story]:
				part.visible = false
				_hidden_for_modal.append(part)
	elif not over and not _hidden_for_modal.is_empty():
		for part in _hidden_for_modal:
			if is_instance_valid(part):
				part.visible = true
		_hidden_for_modal.clear()


# ------------------------------------------------------------------ shop screen

const ShopScreen = preload("res://scripts/ui/shop_screen.gd")

var _shop_screen: Control


## Under the story box (a mission done by buying shows its pages over the shop).
func _build_shop_screen() -> void:
	_shop_screen = ShopScreen.new()
	_shop_screen.name = "Winkelscherm"
	_shop_screen.font_title = _font_title
	_shop_screen.font_pixel = _font_pixel
	_shop_screen.font_body = _font_body
	_root.add_child(_shop_screen)


## The shop screen (scripts/ui/shop_screen.gd) for `talk`, a Conversations with a seller
## (Conversations.is_merchant), buying for `player`; the game paused meanwhile, the mouse
## handed to it; `done` is called when it closes.
func show_shop(talk: RefCounted, player: Node, done := Callable()) -> void:
	_ui_viewport.gui_disable_input = false
	_shop_screen.open(talk, player, self, func() -> void:
		_ui_viewport.gui_disable_input = not pause_menu.is_open()
		if done.is_valid():
			done.call())


func is_showing_shop() -> bool:
	return _shop_screen != null and _shop_screen.is_showing()


# ------------------------------------------------------------------ death screen

const DeathScreen = preload("res://scripts/ui/screens/death_screen.gd")
const DEATH_JINGLE := "res://assets/audio/muziek/deuntje_dood.ogg"
const DEATH_JINGLE_VOLUME_DB := -5.0

## The death screen (scripts/ui/screens/death_screen.gd), up when the player has died.
var death_screen: DeathScreen


func _build_death_screen() -> void:
	death_screen = DeathScreen.new()
	_root.add_child(death_screen)


## The player died (player_controller.gd): the death screen with how it happened (`cause`: a
## key of DeathScreen.CAUSES, else a general line), the city music fades out and the death
## tune plays once.
func show_death(cause := "") -> void:
	if death_screen.is_open():
		return
	if pause_menu.is_open():
		set_paused(false)
	death_screen.open(cause, player_name)
	music.stop(0.8)
	music.play_jingle(DEATH_JINGLE, DEATH_JINGLE_VOLUME_DB, "DoodDeuntje")


func _build_crt() -> void:
	crt = CrtView.new()
	crt.show_picture(_ui_viewport.get_texture())
	add_child(crt)
	crt.resized.connect(_update_crt)
	_update_crt()


## The settings of the main menu (MainMenu.SETTINGS_PATH): the CRT look off if the player
## turned it off there.
func _read_menu_settings() -> void:
	var config := ConfigFile.new()
	if config.load(MainMenu.SETTINGS_PATH) != OK:
		return
	if not config.get_value("beeld", "crt", true):
		crt_curvature = 0.0
		crt_ui_curvature = 0.0


## Hands the CRT settings to its shader (always drawn: it also lays the HUD's picture over
## the world).
func _update_crt() -> void:
	if crt == null:
		return
	crt.show_crt(crt_curvature, CrtRules.ui_curvature(crt_ui_curvature, crt_curvature),
			CrtRules.corner(crt_corner, crt_curvature), CrtRules.screen_size(crt.size))


# ------------------------------------------------------------------ layout

## Scales the design to the window (the smaller of the two ratios) and keeps the corners
## in the corners. The HUD's own picture is drawn at the window's real pixels (the project
## stretches the design of 1280 x 720 to the window, "canvas_items"), its texts sharp.
func _fit_to_window() -> void:
	var window := get_viewport().get_visible_rect().size
	if _ui_viewport:
		var pixels := Vector2i(window)
		if get_window() and get_window().size.x > 0:
			pixels = get_window().size
		_ui_viewport.size = pixels
		_ui_viewport.size_2d_override = Vector2i(window)
		_ui_viewport.size_2d_override_stretch = true
		if "oversampling_override" in _ui_viewport:
			_ui_viewport.set("oversampling_override", float(pixels.y) / maxf(window.y, 1.0))
	_root.scale = Vector2.ONE * HudLayout.scale_factor(window)
	_root.size = HudLayout.design_area(window)
	_place_corners()


func _place_corners() -> void:
	if _root == null or money_panel == null:
		return
	var area := _root.size
	notices.position = HudLayout.notice_position(area)
	_map_column.position = HudLayout.minimap_position(area)
	quest_tracker.position = HudLayout.tracker_position(area)
	money_panel.position = HudLayout.money_position(area, money_panel.size)
	_place_action_prompts()


func _place_action_prompts() -> void:
	if _action_prompts and _root:
		_action_prompts.reset_size()
		_action_prompts.position = HudLayout.actions_position(_root.size, _action_prompts.size)


## The context actions bottom left: [key text, action text] each; empty hides them.
func set_actions(actions: Array) -> void:
	if _action_prompts == null:
		return
	_action_prompts.set_actions(actions)
	_place_action_prompts.call_deferred()


# ------------------------------------------------------------------ minimap and location

## Inside `interior` (Interiors.enter): the minimap shows its floor plan and its ways out
## (`exits`, world positions; Minimap.show_interior_plan).
func show_interior_plan(interior: Node3D, exits: Array[Vector3]) -> void:
	minimap.show_interior_plan(interior, exits)


## Back outside: the town's map on the minimap again.
func show_town_plan() -> void:
	minimap.show_town_plan()


## The picture of the town on the minimap, from the Grond and Gebouwen GridMaps. Built once.
func _build_minimap_picture() -> void:
	_minimap_in_town().build(get_node_or_null(ground_path) as GridMap, get_node_or_null(buildings_path) as GridMap)


## The shroud over the town's map picture (pixels as minimap_texture), null when all is open.
func shroud_image() -> Image:
	return minimap.shroud_image()


## Whether the world point (x, z) is under the shroud (hidden on the maps).
func is_shrouded(world: Vector2) -> bool:
	return _minimap_in_town().is_shrouded(world)


## The game menu (Tab) closed or open to the player (the story unlocks it: "ontgrendelt").
func set_menu_locked(locked: bool) -> void:
	var game_menu := get_node_or_null("Spelmenu")
	if game_menu:
		game_menu.set("locked", locked)


## A thought of the player, rising over its head (at the edge of the shroud).
func show_thought(text: String) -> void:
	var player := get_tree().get_first_node_in_group("speler") as Node3D
	if player:
		show_floating_number(player.global_position + Vector3.UP * 2.3, text, THOUGHT_COLOUR, 13)


## The name a neighbourhood (a key of the "wijken" metadata) is shown by.
static func area_display_name(wijk: String) -> String:
	return LocationRules.area_display_name(wijk)


## Inside a building (Interiors): the location under the minimap is `wijk` (a key of the
## "wijken" metadata, e.g. "Centraal Station") in place of the spot far off the map; ""
## when going out again.
func set_indoor_location(wijk: String) -> void:
	location.set_indoor(wijk)
