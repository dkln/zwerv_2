class_name GameHud
extends CanvasLayer
## The game HUD (the "HUD" node of the city scene), in the pixel style of the design
## "HUD — open world" (1280 x 720; everything scales with the window, the corners stay in
## the corners):
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
## - the pause menu (Escape: the game stands still; VERDER SPELEN, HOOFDMENU, AFSLUITEN);
## - the game menu as a child (Spelmenu, scripts/ui/game_menu.gd: inventory, quests, map);
## - the death screen (show_death, when the player dies);
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

## The tune that opens the map when the game starts (max 6 s), and how loud.
const LoadingScreenScript = preload("res://scripts/ui/loading_screen.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const MAP_JINGLE := "res://assets/audio/muziek/deuntje_kaart_start.ogg"
const MAP_JINGLE_VOLUME_DB := -5.0
## The music while roaming the city: one loop everywhere (CITY_MUSIC, tools/muziek/: made from
## the composition, docs/MUZIEK.md). It starts when the jingle ends, fading in. Going into a
## building with music of its own (set_indoor_music: the merchant's) crossfades to that and
## back (equal power: the amplitudes follow a quarter sine and cosine, so the sum stays as loud
## and there is no dip halfway), and going back to a loop that is still fading out fades that
## one in again. Softer while the game is paused (pause menu, game menu, story box):
## CITY_MUSIC_PAUSED_DB.
const MUSIC_FOLDER := "res://assets/audio/muziek/"
const CITY_MUSIC := "spel_loop.ogg"
## Inside a building: how fast its music takes over; how much softer the music is under a jingle.
const INDOOR_MUSIC_FADE := 1.2
const JINGLE_DUCK_DB := 6.0
const CITY_MUSIC_VOLUME_DB := -7.0
const CITY_MUSIC_PAUSED_DB := -13.0
## The city's own loop (CITY_MUSIC) plays this much softer still: it runs quietly in the
## background, under the sounds of the town; music of a building (the merchant's) does not.
const CITY_LOOP_SOFTER_DB := 3.0
## The muzak of a supermarket (Interiors SUPERMARKET_MUZAK, files starting with this) plays
## softer still: background music in a shop, about as loud as the shop's own sound.
const MUZAK_PREFIX := "supermarkt_muzak_"
const MUZAK_SOFTER_DB := 6.0
const CITY_MUSIC_FADE_IN := 3.0
## How fast (dB per second) the level follows pausing and going on.
const CITY_MUSIC_LEVEL_SPEED := 30.0
## Neighbourhoods shown under another name than their key in the "wijken" metadata (the key
## stays what the crowds (data/drukte.json) and the visited list go by).
const AREA_DISPLAY_NAMES := {"Centraal Station": "Station Den Haag Centraal"}
## The neighbourhood's name under the minimap: this size, smaller (down to the smallest) for
## a long name, so it fits the box whole.
const LOCATION_WIJK_FONT_SIZE := 11
const LOCATION_WIJK_SMALLEST_FONT_SIZE := 8
## The DetailNiveau of the city scene: the jingle waits until it has merged the map.
const DETAIL_PATH := NodePath("../DetailNiveau")
const Iso = preload("res://scripts/camera/iso_camera.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const PixelIcon = preload("res://scripts/ui/widgets/pixel_icon.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
const CheckSquare = preload("res://scripts/ui/widgets/check_square.gd")
const PlayerArrow = preload("res://scripts/ui/widgets/player_arrow.gd")
const QuestMarks = preload("res://scripts/ui/widgets/quest_marks.gd")
const InteriorPlan = preload("res://scripts/ui/widgets/interior_plan.gd")
## Inside a building the minimap shows its floor plan (show_interior_plan) with its exits in
## this colour, at least this many metres across (a snack bar would be a speck at 160 m).
const EXIT_MARK_COLOUR := Color("#5BE37A")
const INTERIOR_MINIMAP_MIN_METRES := 28.0
## Inside a building a quest place within this many metres is in it and marked on its plan
## (the cans of mission 1 in the station); farther off it is in the town and left out.
const INDOOR_TARGET_REACH := 150.0
const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const FloatingNumbers = preload("res://scripts/ui/widgets/floating_numbers.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")

## Size of the design; the HUD is laid out at this size and scaled to the window.
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const MARGIN := 24.0

## The stats in the order they are shown: label (for the value text), colour of a full and of
## an empty segment, number of segments, segment height and the icon (PIXEL_ICONS).
const STATS := {
	"gezondheid": {"colour": Color("#FF5D73"), "empty": Color("#3A2340"), "segments": 20, "height": 12, "icon": "heart"},
	"uithoudingsvermogen": {"colour": Color("#8BE36B"), "empty": Color("#22352A"), "segments": 20, "height": 8, "icon": "bolt"},
	"honger": {"colour": Color("#FFB547"), "empty": Color("#3D2E14"), "segments": 20, "height": 8, "icon": "chomp"},
	"overprikkeldheid": {"colour": Color("#C08BFF"), "empty": Color("#2E2340"), "segments": 20, "height": 8, "icon": "burst"},
}
## The experience bar: a segment bar as the stats (their segments, the height of the
## slimmer ones), its colours (teal: the purple of the design is taken by overprikkeldheid).
const XP_COLOUR := Color("#47D6C2")
## How see-through a quest step is that cannot be done yet (the one before it first).
const LOCKED_STEP_OPACITY := 0.35
const XP_EMPTY_COLOUR := Color("#173733")
const XP_SEGMENTS := 20
const XP_SEGMENT_HEIGHT := 8
## Icons of 7 x 7 pixels ("#" = coloured), drawn at 2 x 2 screen pixels per pixel.
const PIXEL_ICONS := {
	"heart": [".##.##.", "#######", "#######", ".#####.", "..###..", "...#...", "......."],
	"bolt": ["....##.", "...##..", "..##...", ".######", "...##..", "..##...", ".##...."],
	"chomp": ["..###..", ".#####.", "####...", "###....", "####...", ".#####.", "..###.."],
	"burst": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	"person": ["..###..", ".#####.", ".#####.", "..###..", ".......", ".#####.", "#######"],
}
## Minimap: colour per kind of ground (MINIMAP_KINDS, by the folder of the Grond tile) and
## of a building, and of an empty cell.
const MINIMAP_COLOURS := {
	"road": Color("#6B6A8E"),
	"cycle_path": Color("#7E5A72"),
	"water": Color("#24306A"),
	"grass": Color("#3E6150"),
	"pavement": Color("#4A5378"),
	"rail": Color("#555170"),
	"land": Color("#3A4A6E"),
	"building": Color("#141729"),
}
const MINIMAP_EMPTY := Color("#0B0D1A")
## The colour of the player's thoughts over its head (show_thought), as the "gedachte" pages.
const THOUGHT_COLOUR := Color("#47D6C2")
## Folder of a Grond tile (the start of its library name) -> kind of ground on the minimap.
const MINIMAP_KINDS := {
	"weg": "road", "snelweg": "road", "bocht": "road", "parkeren": "road", "tunnel": "road", "brug": "road",
	"fietspad": "cycle_path", "water": "water", "zwembad": "water", "natuur": "grass", "heuvel": "grass",
	"stoep": "pavement", "plein": "pavement", "spoor": "rail", "tram": "rail", "waterkant": "pavement",
}
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
@export var minimap_metres := 160.0
## Metres within which the nearest named place shows under the neighbourhood.
@export var place_near := 45.0
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

var _location_wijk: Label
var _location_place: Label
var _location_street: Label
var _location_box: Control
var _location_clock := 0.0
var _city_music: AudioStreamPlayer     # the loop that is (fading) in
var _city_music_file := ""              # its file; "" fades them all out (death)
var _city_music_on := false   # the jingle is over: the city music plays
var _city_players := {}                 # file -> AudioStreamPlayer, also the ones fading out
var _city_weights := {}                 # file -> 0..1, where in its fade it is
var _city_fade := CITY_MUSIC_FADE_IN    # seconds of the running fade
var _city_level_db := CITY_MUSIC_VOLUME_DB
var _indoor_music := ""          # the loop of the building the player is in (set_indoor_music)
var _jingles_playing := 0
var _focus := Vector3.ZERO       # where the player is, from the last minimap update
var _has_focus := false
var _current_wijk := ""
var _indoor_wijk := ""           # inside a building: the neighbourhood it counts as (set_indoor_location)
var _visited_wijken := {}
var _quests: Array = []
var _stat_rows := {}      # stat name -> its row (icon, bar, value)
var _stat_shakes := {}    # stat name -> the running shake tween
var _font_title: Font        # Pixelify Sans, bold
var _font_title_medium: Font # Pixelify Sans, semibold
var _font_pixel: Font        # Silkscreen
var _font_pixel_bold: Font   # Silkscreen bold
var _font_body: Font         # JetBrains Mono

var _root: Control
var _floating_numbers: FloatingNumbers
var _numbers_over_story: FloatingNumbers   # the same, drawn over the story box
## How long a number over the story box stays (the text is being read meanwhile).
const NUMBER_OVER_STORY_SECONDS := 2.2
var _ui_viewport: SubViewport   # the HUD's own picture (see _build_crt)
var _player_frame: Control
var _portrait: PlayerPortrait
var _level_badge: Label
var _xp_bar: SegmentBar
var _xp_text: Label
var _name_label: Label
var _stat_bars := {}         # stat name -> SegmentBar
var _stat_texts := {}        # stat name -> Label
var _stat_values := {}       # stat name -> Vector2(value, maximum)
var _area_banner: Control
var _area_heading: Label
var _area_name: Label
var _area_tween: Tween
var _notices: Array[Dictionary] = []   # waiting: {"heading", "name", "seconds", "jingle"}
var _minimap_box: Control
var _minimap_map: TextureRect
var _minimap_shroud: TextureRect     # over the map: what the story has not opened yet, hidden
var _shroud_image: Image              # the same size as the map picture, opaque where shrouded
var _shroud_texture: ImageTexture
var _map_lowest := Vector2i.ZERO      # the cell of the map picture's first pixel
var _minimap_arrow: PlayerArrow
var _minimap_origin := Vector2.ZERO   # world x, z of the map image's corner
var _minimap_cell := 4.0              # metres per map pixel
var _day_label: Label
var _time_label: Label
var _time_icon: PixelIcon
var _quest_list: VBoxContainer
var _tracked_quest_id := ""
var _tracked_distance: Label         # the distance in the tracked quest's panel
var _minimap_marks: QuestMarks
var _minimap_exits: QuestMarks       # the ways out on the floor plan of an interior
var _minimap_waypoint: QuestMarks    # the marker set on the map (set_waypoint)
var _waypoint := Vector2.INF         # where it is (world x, z), INF: none
var _waypoint_name := ""
var _waypoint_chip: Control
var _waypoint_label: Label
var _beacon: Node3D                  # its beam of light in the town (WaypointBeacon)
var _exit_points: Array[Vector3] = []
var _town_map := {}                  # the town's map while an interior's plan is shown
var _interior_plans := {}            # interior instance id -> its plan (InteriorPlan.build)
var _minimap_metres_now := 0.0       # metres across now (0: minimap_metres)
var _action_prompts: ActionPrompts
var _money_panel: Control
var _money_label: Label
var _crt_overlay: ColorRect

var _day := 1
var _hour := 12.0
var _last_cycle_hour := -1.0
var _clock_from_api := false


func _ready() -> void:
	layer = 10
	# it keeps running while the game is paused (the pause menu, the CRT picture)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_day = start_day
	_read_menu_settings()
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
	_build_player_frame()
	_build_area_banner()
	_build_minimap()
	_action_prompts = ActionPrompts.new()
	_action_prompts.name = "Acties"
	_root.add_child(_action_prompts)
	_build_quest_tracker()
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
	_build_minimap_image.call_deferred()
	_play_map_jingle_when_ready.call_deferred()


## The short tune that opens the map (MAP_JINGLE): once, as soon as
## the map is there; while the DetailNiveau is still merging (the loading screen) it waits for that.
func _play_map_jingle_when_ready() -> void:
	var level_of_detail := get_node_or_null(DETAIL_PATH)
	if level_of_detail and level_of_detail.has_method("is_merging") and level_of_detail.is_merging():
		await level_of_detail.merge_finished
	# and until the loading screen is gone: meanwhile only its waiting music plays
	while LoadingScreenScript.showing(get_tree()):
		await get_tree().process_frame
	var stream: AudioStream = null
	if ResourceLoader.exists(MAP_JINGLE):
		stream = load(MAP_JINGLE)
	elif FileAccess.file_exists(MAP_JINGLE):
		stream = AudioStreamOggVorbis.load_from_file(MAP_JINGLE)
	if stream == null:
		push_warning("hud: no map jingle at %s" % MAP_JINGLE)
		_play_city_music()
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	var player := AudioStreamPlayer.new()
	player.name = "KaartDeuntje"
	player.stream = stream
	player.volume_db = MAP_JINGLE_VOLUME_DB
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	player.finished.connect(_play_city_music)


## Starts the city music (after the jingle).
func _play_city_music() -> void:
	if _city_music_on:
		return
	_city_music_on = true
	_fade_city_music_to(CITY_MUSIC, CITY_MUSIC_FADE_IN)


## Inside a building (Interiors): its own loop (`file`, in MUSIC_FOLDER; the merchant's for a
## snack bar) in place of the city's, fading over INDOOR_MUSIC_FADE s; "" back to the city's.
func set_indoor_music(file: String) -> void:
	_indoor_music = file
	if file != "":
		_fade_city_music_to(file, INDOOR_MUSIC_FADE)
	elif _city_music_on:
		_fade_city_music_to(CITY_MUSIC, INDOOR_MUSIC_FADE)


## Holds the music down as under a jingle (JINGLE_DUCK_DB) while something else must be heard
## (an announcement in a supermarket: SupermarketAnnouncer); every true needs a false after it.
func duck_music(ducked: bool) -> void:
	_jingles_playing = maxi(_jingles_playing + (1 if ducked else -1), 0)


## Makes `file` the loop that fades in over `fade` s (the others fade out); "" fades all out.
func _fade_city_music_to(file: String, fade: float) -> void:
	_city_music_file = file
	_city_fade = maxf(fade, 0.05)
	if file == "":
		_city_music = null
		return
	if not _city_players.has(file):
		var stream := _load_loop(file)
		if stream == null:
			push_warning("hud: no city music %s" % file)
			return
		var player := AudioStreamPlayer.new()
		player.name = "StadMuziek"
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		# the same point in the bar as the loudest loop now (they all share one length)
		var playback_at := 0.0
		var loudest := -1.0
		for other_file: String in _city_players:
			var other: AudioStreamPlayer = _city_players[other_file]
			if other.playing and _city_weights[other_file] > loudest:
				loudest = _city_weights[other_file]
				playback_at = other.get_playback_position() + AudioServer.get_time_since_last_mix()
		player.play(fmod(playback_at, maxf(stream.get_length(), 0.01)))
		_city_players[file] = player
		_city_weights[file] = 0.0
	_city_music = _city_players[file]


## Each frame: every loop moves along its fade (equal power) at the level of the moment
## (softer while paused).
func _update_city_music(delta: float) -> void:
	# the shop screen pauses the game but its music is the point of it: full volume then
	var level_target := CITY_MUSIC_PAUSED_DB if get_tree().paused and not is_showing_shop() else CITY_MUSIC_VOLUME_DB
	# softer while a jingle plays over it, so the jingle is heard
	if _jingles_playing > 0:
		level_target -= JINGLE_DUCK_DB
	_city_level_db = move_toward(_city_level_db, level_target, CITY_MUSIC_LEVEL_SPEED * delta)
	# slow motion slows every sound down (AudioServer.playback_speed_scale), but not the music
	var music_pitch := 1.0 / maxf(AudioServer.playback_speed_scale, 0.01)
	for file: String in _city_players.keys():
		var player: AudioStreamPlayer = _city_players[file]
		player.pitch_scale = music_pitch
		var weight: float = move_toward(_city_weights[file], 1.0 if file == _city_music_file else 0.0, delta / _city_fade)
		_city_weights[file] = weight
		if weight <= 0.0 and file != _city_music_file:
			player.queue_free()
			_city_players.erase(file)
			_city_weights.erase(file)
			continue
		var amplitude := sin(weight * PI * 0.5)
		var own_level := -CITY_LOOP_SOFTER_DB if file == CITY_MUSIC else 0.0
		if file.begins_with(MUZAK_PREFIX):
			own_level = -MUZAK_SOFTER_DB
		player.volume_db = _city_level_db + own_level + linear_to_db(maxf(amplitude, 0.0001))


static func _load_loop(file: String) -> AudioStream:
	var path := MUSIC_FOLDER + file
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func _process(delta: float) -> void:
	_lay_modal_over_menu()
	_update_city_music(delta)
	_update_clock()
	_update_minimap()
	_location_clock -= delta
	if _location_clock <= 0.0:
		_location_clock = LOCATION_INTERVAL
		_update_location()
		_update_quest_distance()
	_open_waiting_reward()
	_open_waiting_level_up()


# ------------------------------------------------------------------ API

## Sets a stat (STATS: "gezondheid", "uithoudingsvermogen", "honger", "overprikkeldheid"):
## the bar fills to value / maximum; maximum < 0 keeps the last one.
func set_stat(stat_name: String, value: float, maximum := -1.0) -> void:
	if not _stat_bars.has(stat_name):
		push_warning("hud: unknown stat '%s'" % stat_name)
		return
	var previous: Vector2 = _stat_values.get(stat_name, Vector2(0.0, 100.0))
	var top := maximum if maximum > 0.0 else previous.y
	var clamped := clampf(value, 0.0, top)
	_stat_values[stat_name] = Vector2(clamped, top)
	if _stat_values_set.has(stat_name) and absf(clamped - previous.x) >= STAT_SHAKE_FROM:
		_shake_stat(stat_name, clamped > previous.x)
	_stat_values_set[stat_name] = true
	(_stat_bars[stat_name] as SegmentBar).fill = clamped / top
	(_stat_texts[stat_name] as Label).text = "%d/%d" % [roundi(clamped), roundi(top)]


## A change of a stat of at least this many points in one go lights its value up (a hit,
## eating, hunger biting); the slow running down and filling up of the meters does not.
const STAT_SHAKE_FROM := 1.5
const STAT_FLASH_SECONDS := 0.6
var _stat_values_set := {}


## Lights the value of a stat up for a moment: brighter when it went up, reddish when it
## went down (the bar itself shows what changed, scripts/ui/widgets/segment_bar.gd).
func _shake_stat(stat_name: String, gained: bool) -> void:
	var text: Label = _stat_texts.get(stat_name)
	if text == null:
		return
	var running: Tween = _stat_shakes.get(stat_name)
	if running and running.is_valid():
		running.kill()
	text.modulate = Color(1.7, 1.7, 1.7) if gained else Color(1.6, 0.45, 0.4)
	var flash := create_tween()
	flash.tween_property(text, "modulate", Color.WHITE, STAT_FLASH_SECONDS)
	_stat_shakes[stat_name] = flash


## The value and maximum of a stat (Vector2).
func get_stat(stat_name: String) -> Vector2:
	return _stat_values.get(stat_name, Vector2.ZERO)


## The experience: points so far within this level and the points the level takes; the
## bar fills to their share.
func set_xp(points: float, points_for_level: float) -> void:
	var top := maxf(points_for_level, 1.0)
	var clamped := clampf(points, 0.0, top)
	_xp_bar.fill = clamped / top
	_xp_text.text = "%s / %s" % [_thousands(roundi(clamped)), _thousands(roundi(top))]


## A step of a mission done (Story): a short triumph; the whole mission: the longer one.
const TASK_JINGLE := "res://assets/audio/muziek/deuntje_taak_klaar.ogg"
const MISSION_DONE_JINGLE := "res://assets/audio/muziek/deuntje_gewonnen.ogg"
const TASK_JINGLE_VOLUME_DB := -4.0


## A task of a mission done: its triumph tune (the whole mission done: the longer one).
func play_task_done(mission_done := false) -> void:
	_play_jingle(MISSION_DONE_JINGLE if mission_done else TASK_JINGLE, TASK_JINGLE_VOLUME_DB, "TaakDeuntje")


const LEVEL_JINGLE := "res://assets/audio/muziek/deuntje_level_omhoog.ogg"
const LEVEL_JINGLE_VOLUME_DB := -3.0


## A level up: the new level on the badge, and the level-up screen (scripts/ui/level_up_screen.gd)
## with the jingle, where you choose a stat to raise: `choose` gets its name (the player's
## raise_stat), `current` gives (value, maximum) of a stat. It waits as a reward does
## (_open_waiting_level_up), and after the rewards waiting. Without `choose` only the notice.
func show_level_up(level: int, choose := Callable(), current := Callable()) -> void:
	set_player(player_name, level)
	if not choose.is_valid():
		_queue_notice({"heading": "— LEVEL OMHOOG —", "name": "Level %d" % level, "seconds": 3.5, "jingle": LEVEL_JINGLE})
		return
	_level_ups_waiting.append({"level": level, "choose": choose, "current": current})
	_open_waiting_level_up()


func is_showing_level_up() -> bool:
	return _level_up_screen != null and _level_up_screen.is_showing()


## The level ups still waiting for their screen.
func level_ups_waiting() -> Array[Dictionary]:
	return _level_ups_waiting


func set_player(new_name: String, level: int) -> void:
	player_name = new_name
	player_level = level
	_name_label.text = new_name
	_level_badge.text = "LEVEL %d" % level


const AREA_HEADING := "— NIEUW GEBIED ONTDEKT —"
const MISSION_HEADING := "— NIEUWE MISSIE —"
const MISSION_JINGLE := "res://assets/audio/muziek/deuntje_nieuwe_missie.ogg"
const MISSION_JINGLE_VOLUME_DB := -3.0
## Width of the notice (a mission title is longer than an area name).
const NOTICE_WIDTH := 720.0


## Shows "nieuw gebied ontdekt" with the name of the area for a few seconds.
func show_area(area_name: String, seconds := 4.0) -> void:
	_queue_notice({"heading": AREA_HEADING, "name": area_name, "seconds": seconds, "jingle": ""})


## Shows a notice of its own at the top ("heading" over "text"): the floor the lift of the
## city hall has brought you to.
func show_notice(heading: String, text: String, seconds := 3.0) -> void:
	_queue_notice({"heading": heading, "name": text, "seconds": seconds, "jingle": ""})


## Shows "nieuwe missie" with the title of the mission and plays the mission jingle.
func show_mission(title: String, seconds := 4.5) -> void:
	_queue_notice({"heading": MISSION_HEADING, "name": title, "seconds": seconds, "jingle": MISSION_JINGLE})


## True while a notice is up (for the tests).
func is_showing_notice() -> bool:
	return _area_banner.visible


func _queue_notice(notice: Dictionary) -> void:
	# the same area twice in a row is one notice
	if _area_banner.visible and _area_name.text == notice["name"]:
		return
	_notices.append(notice)
	if not _area_banner.visible:
		_next_notice()


func _next_notice() -> void:
	if _notices.is_empty():
		_area_banner.visible = false
		return
	var notice: Dictionary = _notices.pop_front()
	_area_heading.text = notice["heading"]
	_area_name.text = notice["name"]
	if notice["jingle"] != "":
		_play_jingle(notice["jingle"], MISSION_JINGLE_VOLUME_DB, "MissieDeuntje")
	if _area_tween:
		_area_tween.kill()
	_area_banner.visible = true
	_area_banner.modulate.a = 0.0
	_area_tween = create_tween()
	_area_tween.tween_property(_area_banner, "modulate:a", 1.0, 0.6)
	_area_tween.tween_interval(notice["seconds"])
	_area_tween.tween_property(_area_banner, "modulate:a", 0.0, 0.9)
	_area_tween.tween_callback(_next_notice)


## Plays a jingle once over the music (nothing without the file).
func _play_jingle(path: String, volume_db: float, player_name: String) -> void:
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)   # not imported yet
	if stream == null:
		push_warning("hud: no jingle at %s" % path)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	var jingle := AudioStreamPlayer.new()
	jingle.name = player_name
	jingle.stream = stream
	jingle.volume_db = volume_db
	jingle.process_mode = Node.PROCESS_MODE_ALWAYS   # also while the story box holds the game
	add_child(jingle)
	jingle.play()
	_jingles_playing += 1
	jingle.finished.connect(func() -> void:
		_jingles_playing = maxi(_jingles_playing - 1, 0)
		jingle.queue_free())


## The quests in the tracker, top to bottom; empty = no tracker. Each a Dictionary:
## "kind": "verhaal" (a main quest: "label", "title", "distance", "steps" = [{"text",
## "done"}]) or "zij" (a side quest: "label" and "title" on one line); "id" names it (else
## its title). A step may have "targets" (Array of world x, z: where to go for it, shown on
## the minimap and the map while it is the step under way of the tracked quest) and
## "locked" (it can only be done after the steps before it: shown muted, no targets yet).
## "done": the whole quest is finished; it can no longer be followed: the tracker then goes
## on to the first open quest after it (next_open_quest_id).
func set_quests(quests: Array) -> void:
	var previous_ids: Array = _quests.map(func(quest: Dictionary) -> String: return quest_id(quest))
	_quests = quests.duplicate(true)
	var tracked := quest_by_id(_tracked_quest_id)
	if tracked.is_empty() or tracked.get("done", false):
		_tracked_quest_id = next_open_quest_id(_tracked_quest_id, previous_ids)
	_rebuild_quest_tracker()


static func is_quest_done(quest: Dictionary) -> bool:
	return quest.get("done", false)


## The quest to follow once `after_id` is done (or gone): the first open (not done) one after
## it in the list (`previous_ids`: the order before, as a quest that is gone is no longer in
## the list), else the first open one at all; "" when none is open.
func next_open_quest_id(after_id: String, previous_ids: Array = []) -> String:
	var start := 0
	var at := -1
	for index in _quests.size():
		if quest_id(_quests[index]) == after_id:
			at = index
	if at == -1 and previous_ids.has(after_id):
		# gone from the list: start where it stood
		for later_id: String in previous_ids.slice(previous_ids.find(after_id) + 1):
			var later := quest_by_id(later_id)
			if not later.is_empty() and not is_quest_done(later):
				return later_id
	if at != -1:
		start = at + 1
	for offset in _quests.size():
		var quest: Dictionary = _quests[(start + offset) % _quests.size()]
		if not is_quest_done(quest):
			return quest_id(quest)
	return ""


func _rebuild_quest_tracker() -> void:
	for child in _quest_list.get_children():
		child.queue_free()
	_tracked_distance = null
	# only the quest you follow is in view (the others are in the quest log of the game menu)
	var tracked := quest_by_id(_tracked_quest_id)
	if not tracked.is_empty():
		_quest_list.add_child(_main_quest_panel(tracked) if tracked.get("kind", "verhaal") == "verhaal" else _side_quest_panel(tracked))
	_quest_list.visible = not tracked.is_empty()
	_update_quest_distance()


static func quest_id(quest: Dictionary) -> String:
	return str(quest.get("id", quest.get("title", "")))


func quest_by_id(id: String) -> Dictionary:
	for quest: Dictionary in _quests:
		if quest_id(quest) == id:
			return quest
	return {}


## Follows this quest (its places on the minimap and the map, on top of the tracker).
func track_quest(id: String) -> void:
	var quest := quest_by_id(id)
	if quest.is_empty() or is_quest_done(quest) or id == _tracked_quest_id:
		return
	_tracked_quest_id = id
	_rebuild_quest_tracker()


func tracked_quest_id() -> String:
	return _tracked_quest_id


## Where the tracked quest sends the player now: the targets of its first step not done
## (none while that step is locked), as world x, z.
func quest_targets() -> Array:
	var quest := quest_by_id(_tracked_quest_id)
	for step: Dictionary in quest.get("steps", []):
		if step.get("done", false):
			continue
		if step.get("optional", false):
			continue   # an optional step never holds up the one under way
		if step.get("locked", false):
			return []
		return step.get("targets", [])
	return []


# ------------------------------------------------------------------ the marker of the map

## The colour of the marker you set on the map (the game menu's KAART: Enter on a place),
## on the minimap, its chip and its beam in the town; how close counts as there (metres).
const WAYPOINT_COLOUR := Color("#FF5ACD")
const WAYPOINT_ARRIVED := 8.0
const WaypointBeacon = preload("res://scripts/world/town/waypoint_beacon.gd")


## A marker on `at` (world x, z), named `place_name`: on the minimap (an arrow on its edge
## while it is further), its name and distance under it, a beam of light on it in the town.
## Gone once you are there (WAYPOINT_ARRIVED) or with clear_waypoint. One at a time.
func set_waypoint(at: Vector2, place_name: String) -> void:
	_waypoint = at
	_waypoint_name = place_name
	if _beacon == null or not is_instance_valid(_beacon):
		_beacon = WaypointBeacon.new()
		var town := get_parent()
		if town:
			town.add_child(_beacon)
	if _beacon.is_inside_tree():
		_beacon.place(Vector3(at.x, _ground_height(at), at.y))
	_waypoint_chip.visible = true
	_waypoint_label.text = place_name.to_upper()


func clear_waypoint() -> void:
	_waypoint = Vector2.INF
	_waypoint_name = ""
	if _beacon and is_instance_valid(_beacon):
		_beacon.queue_free()
	_beacon = null
	_waypoint_chip.visible = false
	_minimap_waypoint.points = []


func has_waypoint() -> bool:
	return _waypoint != Vector2.INF


func waypoint() -> Vector2:
	return _waypoint


func waypoint_name() -> String:
	return _waypoint_name


## The marker on the minimap and its distance; there: "Aangekomen" and it is gone. Inside a
## building (the minimap a floor plan) it waits, its beam hidden.
func _update_waypoint(focus: Vector3, pixels_per_metre: float) -> void:
	if not has_waypoint():
		return
	var outdoors := _town_map.is_empty()
	if _beacon and is_instance_valid(_beacon):
		_beacon.visible = outdoors
	if not outdoors:
		_minimap_waypoint.points = []
		return
	var here := Vector2(focus.x, focus.z)
	_minimap_waypoint.points = [_minimap_arrow.position + (_waypoint - here) * pixels_per_metre]
	var distance := _waypoint.distance_to(here)
	_waypoint_label.text = "%s · %d M" % [_waypoint_name.to_upper(), roundi(distance)]
	if distance <= WAYPOINT_ARRIVED:
		show_floating_number(focus + Vector3.UP * 2.2, "Aangekomen: " + _waypoint_name, WAYPOINT_COLOUR, 14)
		clear_waypoint()


## The height of the ground at `at` (world x, z), for the foot of the beam; 0 when unknown.
func _ground_height(at: Vector2) -> float:
	var world := get_viewport().world_3d if get_viewport() else null
	if world == null:
		return 0.0
	# from just over street level, not from the sky: a place often lies against a facade,
	# whose roof would be hit first
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 1.5, at.y), Vector3(at.x, -20.0, at.y), 1)
	var hit := world.direct_space_state.intersect_ray(query)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


## How far the nearest place of the tracked quest is, in its panel ("120 M").
func _update_quest_distance() -> void:
	if _tracked_distance == null or not is_instance_valid(_tracked_distance) or not _has_focus:
		return
	var nearest := INF
	for target: Vector2 in quest_targets():
		nearest = minf(nearest, target.distance_to(Vector2(_focus.x, _focus.z)))
	_tracked_distance.text = "%d M" % roundi(nearest) if nearest < INF else ""


## The quests as last given to set_quests (for the game menu, scripts/ui/game_menu.gd).
func quests() -> Array:
	return _quests


## The neighbourhoods the player has been in (names as in the "wijken" metadata).
func visited_areas() -> Array:
	return _visited_wijken.keys()


## The minimap's picture of the whole map (one pixel per `minimap_metres_per_pixel()`
## metres, its corner at world x, z `minimap_origin()`), or null while it is not built yet.
func minimap_texture() -> Texture2D:
	return _minimap_map.texture if _minimap_map else null


func minimap_origin() -> Vector2:
	return _minimap_origin


func minimap_metres_per_pixel() -> float:
	return _minimap_cell


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
	_money_label.text = money_text(euros)   # the euro sign is the icon before it


## Euros as Dutch write them, without the sign: thousands with a point, cents after a comma.
static func money_text(euros: float) -> String:
	var cents := roundi(euros * 100.0)
	return ("-" if cents < 0 else "") + _thousands(absi(cents) / 100) + ",%02d" % (absi(cents) % 100)


## The clock, when there is no Dagcyclus (or to override it): hour 0..24, and the day if >= 1.
func set_time(hour: float, day := -1) -> void:
	_clock_from_api = true
	_hour = fposmod(hour, 24.0)
	if day >= 1:
		_day = day
	_show_clock()


# ------------------------------------------------------------------ building

func _load_fonts() -> void:
	var fallback: Font = load(UiStyle.FONT_FALLBACK)
	var body := UiStyle.font(UiStyle.FONT_BODY)
	_font_body = UiStyle.weighted(body, 400)
	var pixel := UiStyle.font(UiStyle.FONT_PIXEL)
	var pixel_bold := UiStyle.font(UiStyle.FONT_PIXEL_BOLD)
	var title := UiStyle.font(UiStyle.FONT_TITLE)
	# glyphs the pixel fonts lack (◆, €) come from JetBrains Mono
	if body != fallback:
		var fallback_fonts: Array[Font] = [body]
		for font: Font in [pixel, pixel_bold, title]:
			if font != fallback:
				font.fallbacks = fallback_fonts
	_font_pixel = pixel
	_font_pixel_bold = pixel_bold
	_font_title = UiStyle.weighted(title, 700)
	_font_title_medium = UiStyle.weighted(title, 600)


func _label(text: String, font: Font, size: int, colour := UiStyle.TEXT, shadow := 2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if shadow > 0:
		UiStyle.faux_3d(label, shadow)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A panel of `size` with a border and a hard shadow SHADOW_OFFSET down and to the right.
func _shadowed_panel(size: Vector2, border: Color, border_width: int, shadow := UiStyle.SHADOW_OFFSET) -> Control:
	var holder := Control.new()
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_rect := ColorRect.new()
	shadow_rect.color = UiStyle.INK
	shadow_rect.position = Vector2(shadow, shadow)
	shadow_rect.size = size
	shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow_rect)
	var panel := Panel.new()
	panel.size = size
	panel.add_theme_stylebox_override("panel", UiStyle.box_style(UiStyle.PANEL, border, border_width))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	return holder


func _build_player_frame() -> void:
	_player_frame = Control.new()
	_player_frame.name = "Speler"
	_player_frame.position = Vector2(MARGIN, MARGIN)
	_player_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_player_frame)
	var portrait := _shadowed_panel(Vector2(76, 76), UiStyle.ACCENT, 3)
	_player_frame.add_child(portrait)
	# the head and shoulders of the chosen figure (PlayerModel), in 3D, on ink
	var portrait_back := ColorRect.new()
	portrait_back.color = UiStyle.INK
	portrait_back.position = Vector2(3, 3)
	portrait_back.size = Vector2(70, 70)
	portrait_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(portrait_back)
	_portrait = PlayerPortrait.new()
	_portrait.name = "Portret"
	_portrait.archetype_id = PlayerCharacter.current_id()
	_portrait.zoom = 1.0
	_portrait.face_view = 1.15
	_portrait.position = Vector2(3, 3)
	_portrait.size = Vector2(70, 70)
	portrait.add_child(_portrait)
	var badge_shadow := ColorRect.new()
	badge_shadow.color = UiStyle.INK
	badge_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(badge_shadow)
	var badge := PanelContainer.new()
	var badge_style := UiStyle.box_style(UiStyle.ACCENT, UiStyle.ACCENT, 0)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 3
	badge_style.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_badge = _label("LEVEL 1", _font_pixel_bold, 12, UiStyle.INK, 0)
	badge.add_child(_level_badge)
	portrait.add_child(badge)
	# right and bottom edge 10 px outside the portrait, with a 3 px shadow
	badge.resized.connect(func() -> void:
		badge.position = Vector2(76 + 10, 76 + 10) - badge.size
		badge_shadow.position = badge.position + Vector2(3, 3)
		badge_shadow.size = badge.size)
	var column := VBoxContainer.new()
	column.position = Vector2(76 + 14, 2)
	column.add_theme_constant_override("separation", 7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(column)
	_name_label = _label("", _font_title, 22)
	column.add_child(_name_label)
	for stat_name in STATS:
		var stat: Dictionary = STATS[stat_name]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := PixelIcon.new()
		icon.bitmap = PIXEL_ICONS[stat.icon]
		icon.colour = stat.colour
		icon.pixel = 2.0
		icon.tooltip_text = stat_name
		row.add_child(_in_icon_column(icon))
		var bar := SegmentBar.new()
		bar.segments = stat.segments
		bar.segment_height = stat.height
		bar.full_colour = stat.colour
		bar.empty_colour = stat.empty
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var value_text := _label("", _font_pixel, 12)
		value_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(value_text)
		column.add_child(row)
		_stat_bars[stat_name] = bar
		_stat_texts[stat_name] = value_text
		_stat_rows[stat_name] = row
	# experience: a row as the stats, "XP" where they have their icon and a segment bar as
	# theirs, and the points under the bar, starting where it starts
	var experience := VBoxContainer.new()
	experience.add_theme_constant_override("separation", 5)
	experience.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_row.add_child(_in_icon_column(_label("XP", _font_pixel_bold, 11, XP_COLOUR, 0)))
	# a segment bar as the stats', as wide and as high as the slimmer of them
	_xp_bar = SegmentBar.new()
	_xp_bar.segments = XP_SEGMENTS
	_xp_bar.segment_height = XP_SEGMENT_HEIGHT
	_xp_bar.full_colour = XP_COLOUR
	_xp_bar.empty_colour = XP_EMPTY_COLOUR
	_xp_bar.fill = 0.0
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(_xp_bar)
	experience.add_child(xp_row)
	var points_row := HBoxContainer.new()
	points_row.add_theme_constant_override("separation", 8)
	points_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var under_icon := Control.new()
	under_icon.custom_minimum_size = Vector2(ICON_COLUMN_WIDTH, 0)
	under_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	points_row.add_child(under_icon)
	_xp_text = _label("0 / 0", _font_pixel, 11)
	points_row.add_child(_xp_text)
	experience.add_child(points_row)
	column.add_child(experience)


## The column of the stat icons (and "XP"): this wide, the thing in it in the middle, so
## the bars after it all start at the same place.
const ICON_COLUMN_WIDTH := 18.0


func _in_icon_column(item: Control) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(ICON_COLUMN_WIDTH, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(item)
	return holder


func _build_area_banner() -> void:
	_area_banner = VBoxContainer.new()
	_area_banner.name = "NieuwGebied"
	_area_banner.add_theme_constant_override("separation", 4)
	_area_banner.size = Vector2(NOTICE_WIDTH, 0)
	_area_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_heading = _label(AREA_HEADING, UiStyle.spaced(_font_pixel, 3), 12, UiStyle.ACCENT)
	_area_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_banner.add_child(_area_heading)
	_area_name = _label("", _font_title, 34, UiStyle.TEXT, 3)
	_area_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_banner.add_child(_area_name)
	_area_banner.visible = false
	_root.add_child(_area_banner)


func _build_minimap() -> void:
	_minimap_box = Control.new()
	_minimap_box.name = "Kaartje"
	_minimap_box.size = Vector2(200, MAP_TOP + 270)
	_minimap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_minimap_box)
	var frame := _shadowed_panel(Vector2(200, 200), UiStyle.BORDER, 3)
	frame.position = Vector2(0, MAP_TOP)
	_minimap_box.add_child(frame)
	var clip := Control.new()
	clip.position = Vector2(3, 3)
	clip.size = Vector2(194, 194)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(clip)
	_minimap_map = TextureRect.new()
	_minimap_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minimap_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap_map.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_minimap_map)
	_minimap_shroud = TextureRect.new()
	_minimap_shroud.name = "Sluier"
	_minimap_shroud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_minimap_shroud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_minimap_shroud.stretch_mode = TextureRect.STRETCH_SCALE
	_minimap_shroud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_minimap_shroud)
	_minimap_marks = QuestMarks.new()
	_minimap_marks.size = clip.size
	clip.add_child(_minimap_marks)
	_minimap_exits = QuestMarks.new()
	_minimap_exits.colour = EXIT_MARK_COLOUR
	_minimap_exits.size = clip.size
	clip.add_child(_minimap_exits)
	_minimap_waypoint = QuestMarks.new()
	_minimap_waypoint.colour = WAYPOINT_COLOUR
	_minimap_waypoint.size = clip.size
	clip.add_child(_minimap_waypoint)
	_minimap_arrow = PlayerArrow.new()
	_minimap_arrow.position = clip.size * 0.5
	clip.add_child(_minimap_arrow)
	var north := _label("N", _font_pixel_bold, 12, UiStyle.TEXT, 1)
	north.position = Vector2(90, 4)
	frame.add_child(north)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_box.add_child(chips)
	_day_label = _label("DAG 1", _font_pixel, 11, UiStyle.TEXT, 0)
	chips.add_child(_chip([_day_label]))
	_time_icon = PixelIcon.new()
	_time_icon.bitmap = ["..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.."]
	_time_icon.colour = UiStyle.ACCENT
	_time_icon.pixel = 12.0 / 7.0
	_time_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_time_label = _label("12:00", _font_pixel, 11, UiStyle.TEXT, 0)
	chips.add_child(_chip([_time_icon, _time_label]))
	# right-aligned under the map, 8 px below it
	chips.resized.connect(func() -> void: chips.position = Vector2(200 - chips.size.x, MAP_TOP + 200 + 8))
	# under them the marker set on the map: its name and how far it is
	var marker_icon := PixelIcon.new()
	marker_icon.bitmap = ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."]
	marker_icon.colour = WAYPOINT_COLOUR
	marker_icon.pixel = 12.0 / 7.0
	marker_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_waypoint_label = _label("", _font_pixel, 11, UiStyle.TEXT, 0)
	_waypoint_label.clip_text = true
	_waypoint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_waypoint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waypoint_chip = _chip([marker_icon, _waypoint_label])
	_waypoint_chip.custom_minimum_size = Vector2(200, 0)
	_waypoint_chip.position = Vector2(0, MAP_TOP + 200 + 8 + 30)
	_waypoint_chip.visible = false
	_minimap_box.add_child(_waypoint_chip)
	# where the player is: over the map, as wide as it, its height fixed (long names end
	# in an ellipsis)
	var pin := PixelIcon.new()
	pin.bitmap = [".###.", "#####", "##.##", "#####", ".###.", "..#..", "..#.."]
	pin.colour = UiStyle.SIDE_ACCENT
	pin.pixel = 14.0 / 7.0
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_location_wijk = _label("DEN HAAG", _font_pixel, 11, UiStyle.SIDE_ACCENT, 0)
	_location_street = _label("", _font_body, 12, UiStyle.TEXT, 0)
	_location_street.visible = false
	_location_place = _label("", _font_body, 11, UiStyle.MUTED, 0)
	_location_place.visible = false
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	for line: Label in [_location_wijk, _location_street, _location_place]:
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.add_child(line)
	_location_box = _chip([pin, lines])
	_location_box.custom_minimum_size = Vector2(200, LOCATION_HEIGHT)
	_location_box.size = Vector2(200, LOCATION_HEIGHT)
	_minimap_box.add_child(_location_box)


func _chip(contents: Array) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, 2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in contents:
		row.add_child(item)
	chip.add_child(row)
	return chip


func _build_quest_tracker() -> void:
	_quest_list = VBoxContainer.new()
	_quest_list.name = "Opdrachten"
	_quest_list.add_theme_constant_override("separation", 10)
	_quest_list.custom_minimum_size = Vector2(300, 0)
	_quest_list.size = Vector2(300, 0)
	_quest_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_quest_list)


func _quest_panel(accent: Color, background_alpha: float, vertical_margin: int, separation: int) -> Array:
	var panel := PanelContainer.new()
	var style := UiStyle.box_style(Color(UiStyle.INK, background_alpha), accent, 4, true)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	return [panel, column]


func _main_quest_panel(quest: Dictionary) -> Control:
	var parts := _quest_panel(UiStyle.ACCENT, 0.82, 12, 8)
	var column: VBoxContainer = parts[1]
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label("◆ " + str(quest.get("label", "VERHAAL")), UiStyle.spaced(_font_pixel, 2), 11, UiStyle.ACCENT, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var distance := _label(str(quest.get("distance", "")), _font_pixel, 11, UiStyle.MUTED, 0)
	header.add_child(distance)
	if quest_id(quest) == _tracked_quest_id:
		_tracked_distance = distance
	column.add_child(header)
	var title := _label(str(quest.get("title", "")), _font_title_medium, 19, UiStyle.TEXT, 0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	steps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for step: Dictionary in quest.get("steps", []):
		var done: bool = step.get("done", false)
		var locked: bool = step.get("locked", false) and not done
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := CheckSquare.new()
		box.done = done
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_override("normal_font", _font_body)
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_color_override("default_color", UiStyle.MUTED if done else UiStyle.TEXT)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var escaped := str(step.get("text", "")).replace("[", "[lb]")
		text.text = "[s]%s[/s]" % escaped if done else escaped
		row.add_child(text)
		if int(step.get("xp", 0)) > 0:
			var points := _label("+%d XP" % int(step.xp), _font_pixel, 10, UiStyle.MUTED if done else XP_COLOUR, 0)
			points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(points)
		# a step that cannot be done yet: see-through
		if locked:
			row.modulate.a = LOCKED_STEP_OPACITY
		steps.add_child(row)
	column.add_child(steps)
	return parts[0]


func _side_quest_panel(quest: Dictionary) -> Control:
	var parts := _quest_panel(UiStyle.SIDE_ACCENT, 0.7, 10, 4)
	var column: VBoxContainer = parts[1]
	var label := _label("! " + str(quest.get("label", "ZIJMISSIE")), UiStyle.spaced(_font_pixel, 2), 11, UiStyle.SIDE_ACCENT, 0)
	column.add_child(label)
	var title := _label(str(quest.get("title", "")), _font_body, 13, UiStyle.TEXT, 0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	return parts[0]


func _build_money() -> void:
	_money_panel = PanelContainer.new()
	_money_panel.name = "Geld"
	var style := UiStyle.box_style(UiStyle.TRANSLUCENT_INK, UiStyle.BORDER, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_money_panel.add_theme_stylebox_override("panel", style)
	_money_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := PixelIcon.new()
	# a euro sign: a C open to the right with two bars through it
	coin.bitmap = ["...####", "..#....", "######.", ".#.....", "######.", "..#....", "...####"]
	coin.colour = UiStyle.ACCENT
	coin.pixel = 16.0 / 7.0
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_money_label = _label("0", _font_pixel, 14, UiStyle.TEXT, 0)
	row.add_child(_money_label)
	_money_panel.add_child(row)
	_money_panel.resized.connect(_place_corners)
	_root.add_child(_money_panel)


# ------------------------------------------------------------------ pause menu

## The pause menu (Escape): the game stands still (the tree paused) and a panel in the
## middle offers these; up/down, Enter, Escape (back to the game) or the mouse.
const PAUSE_ITEMS := [["VERDER SPELEN", "resume"], ["HOOFDMENU", "menu"], ["AFSLUITEN", "quit"]]
const MAIN_MENU_SCENE := "res://scenes/hoofdmenu.tscn"
const PAUSE_WIDTH := 300.0

var _pause_layer: Control
var _pause_buttons: Array[Button] = []
var _pause_selected := 0


func _build_pause_menu() -> void:
	_pause_layer = Control.new()
	_pause_layer.name = "Pauze"
	_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.visible = false
	_root.add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(dim)
	var box := PanelContainer.new()
	var style := UiStyle.box_style(Color(UiStyle.INK, 0.94), UiStyle.BORDER, 3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 18
	box.add_theme_stylebox_override("panel", style)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause_layer.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	var title := _label("— PAUZE —", _font_pixel, 12, UiStyle.ACCENT, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for index in PAUSE_ITEMS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(PAUSE_WIDTH, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", _font_title_medium)
		button.add_theme_font_size_override("font_size", 22)
		button.mouse_entered.connect(func() -> void: _select_pause_item(index))
		button.pressed.connect(func() -> void: _choose_pause_item(index))
		column.add_child(button)
		_pause_buttons.append(button)
	var keys := _label("[↑↓] KIEZEN   [ENTER] KIES   [ESC] TERUG", _font_pixel, 10, UiStyle.MUTED, 0)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(keys)
	_select_pause_item(0)


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
	if ((_pause_layer and _pause_layer.visible) or is_showing_shop()) and event is InputEventMouse:
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
	if _death_layer and _death_layer.visible:
		_death_input(event)
		return
	if event.is_action_pressed("ui_cancel"):
		set_paused(not _pause_layer.visible)
	elif not _pause_layer.visible:
		return
	elif event.is_action_pressed("ui_down"):
		_select_pause_item(posmod(_pause_selected + 1, PAUSE_ITEMS.size()))
	elif event.is_action_pressed("ui_up"):
		_select_pause_item(posmod(_pause_selected - 1, PAUSE_ITEMS.size()))
	elif event.is_action_pressed("ui_accept"):
		_choose_pause_item(_pause_selected)
	else:
		return
	# HOOFDMENU has taken it out of the tree already
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Pauses the game with the pause menu open, or goes on.
func set_paused(on: bool) -> void:
	if on != _pause_layer.visible:
		UiSounds.play(self, "doe" if on else "terug")
	_pause_layer.visible = on
	_ui_viewport.gui_disable_input = not on
	get_tree().paused = on   # the city music follows by itself (_update_city_music)
	if on:
		_select_pause_item(0)


func _select_pause_item(index: int) -> void:
	if index != _pause_selected and _pause_layer.visible:
		UiSounds.play(self, "kies")
	_pause_selected = index
	for button_index in _pause_buttons.size():
		var on := button_index == index
		var button := _pause_buttons[button_index]
		var style := UiStyle.menu_item_style(on)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(colour_name, UiStyle.INK if on else UiStyle.TEXT)
		button.text = ("→  " if on else "    ") + PAUSE_ITEMS[button_index][0]


func _choose_pause_item(index: int) -> void:
	if PAUSE_ITEMS[index][1] != "resume":   # going on sounds as closing the menu (set_paused)
		UiSounds.play(self, "doe")
	match PAUSE_ITEMS[index][1]:
		"resume":
			set_paused(false)
		"menu":
			# the swipe (the one transition of the game) over it, then the menu
			await SwipeTransition.swipe(get_tree()).covered
			get_tree().paused = false
			get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		"quit":
			get_tree().quit()


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
	_reward_screen.keep_paused = func() -> bool:
		return is_showing_story() or is_showing_shop() or is_showing_level_up() or (_pause_layer != null and _pause_layer.visible) or _is_game_menu_open()
	if _story_box:
		_story_box.keep_paused = func() -> bool:
			return is_showing_reward() or is_showing_level_up() or is_showing_shop() or (_pause_layer != null and _pause_layer.visible) or _is_game_menu_open()
		# a conversation waits under the reward screen and goes on where it was after it
		_story_box.on_hold = func() -> bool:
			return is_showing_reward() or is_showing_level_up()
	if _shop_screen:
		_shop_screen.keep_paused = func() -> bool:
			return is_showing_reward() or is_showing_level_up() or is_showing_story() or (_pause_layer != null and _pause_layer.visible)


## A reward got (scripts/ui/reward_screen.gd: {"heading", "title", "xp", "items": [{"item",
## "count"}]}): its screen, once nothing else holds the game (the story box, the shop, the
## pause menu, the game menu, a machine's screen: the game is not paused), one after another;
## `done` is called once it is pressed away (at once when there is nothing to show).
func show_reward(reward: Dictionary, done := Callable()) -> void:
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
	if _rewards_waiting.is_empty() or is_showing_reward() or is_showing_level_up() or not is_inside_tree():
		return
	if is_showing_story() and not _story_box.is_conversation():
		return
	if (_death_layer and _death_layer.visible) or (_pause_layer and _pause_layer.visible):
		return
	if get_tree().root.has_node("Automaatscherm") or LoadingScreenScript.showing(get_tree()):
		return
	var reward: Dictionary = _rewards_waiting.pop_front()
	_reward_screen.open(reward, reward.get("done", Callable()))
	_play_jingle(REWARD_JINGLE, REWARD_JINGLE_VOLUME_DB, "Beloningsdeuntje")


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
	_level_up_screen.keep_paused = func() -> bool:
		return is_showing_reward() or is_showing_story() or is_showing_shop() \
				or (_pause_layer != null and _pause_layer.visible) or _is_game_menu_open()


## The next level up, when nothing else needs the screen: as a reward (_open_waiting_reward:
## over a conversation, the shop and the game menu; not over story pages, the pause menu, a
## machine, the loading or death screen) and only once the rewards waiting have been shown.
func _open_waiting_level_up() -> void:
	if _level_ups_waiting.is_empty() or is_showing_level_up() or is_showing_reward() or not is_inside_tree():
		return
	if not _rewards_waiting.is_empty():
		return
	if is_showing_story() and not _story_box.is_conversation():
		return
	if (_death_layer and _death_layer.visible) or (_pause_layer and _pause_layer.visible):
		return
	if get_tree().root.has_node("Automaatscherm") or LoadingScreenScript.showing(get_tree()):
		return
	var waiting: Dictionary = _level_ups_waiting.pop_front()
	var raise: Dictionary = PlayerController.LEVEL_UP_RAISE
	_level_up_screen.open(int(waiting.level), waiting.choose, waiting.get("current", Callable()), raise)
	_play_jingle(LEVEL_JINGLE, LEVEL_JINGLE_VOLUME_DB, "LevelDeuntje")


# ------------------------------------------------------------------ over the game menu

var _game_menu_layer := -1                  # the game menu's own layer (over the HUD)
var _hidden_for_modal: Array[CanvasItem] = []   # HUD parts hidden while a screen lies over the game menu


func _is_game_menu_open() -> bool:
	var game_menu := get_node_or_null("Spelmenu")
	return game_menu != null and game_menu.has_method("is_open") and game_menu.call("is_open")


## True while the story box (a conversation, a thought, a mission) or the reward screen shows
## with the game menu open (a thought about opening the inventory, a reward got meanwhile).
func _modal_over_menu() -> bool:
	return _is_game_menu_open() and (is_showing_story() or is_showing_reward() or is_showing_level_up())


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
	game_menu.layer = layer - 1 if over else _game_menu_layer
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
		_ui_viewport.gui_disable_input = not _pause_layer.visible
		if done.is_valid():
			done.call())


func is_showing_shop() -> bool:
	return _shop_screen != null and _shop_screen.is_showing()


# ------------------------------------------------------------------ death screen

## When the player dies (show_death, from player_controller.gd): the town goes on behind a
## dark red veil, "JE BENT DOOD" big in the middle with how it happened, the city music
## fades out and the death tune plays once. Enter starts again with the same zwerver
## (the scene reloaded), Escape goes to the main menu.
const DEATH_JINGLE := "res://assets/audio/muziek/deuntje_dood.ogg"
const DEATH_JINGLE_VOLUME_DB := -5.0
const DEATH_CAUSES := {
	"honger": "%s is van de honger omgekomen.",
	"aangereden": "%s is aangereden en niet meer opgestaan.",
	"verdronken": "%s is in het water gevallen en verdronken.",
	"eruit_gegooid": "%s is een gebouw uit gesmeten en niet meer opgestaan.",
}
## Seconds before the keys work (so a key held while dying does not skip it).
const DEATH_KEYS_AFTER := 1.2

var _death_layer: Control
var _death_reason: Label
var _death_keys: Label
var _death_since := 0.0


func _build_death_screen() -> void:
	_death_layer = Control.new()
	_death_layer.name = "Dood"
	_death_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_layer.visible = false
	_root.add_child(_death_layer)
	var veil := ColorRect.new()
	veil.color = Color(0.25, 0.02, 0.06, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_layer.add_child(veil)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_layer.add_child(column)
	var title := _label("JE BENT DOOD", _font_title, 72, Color("#FF5D73"), 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.faux_3d(title, 7)
	column.add_child(title)
	_death_reason = _label("", _font_body, 18, UiStyle.TEXT, 0)
	_death_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.faux_3d(_death_reason, 3)
	column.add_child(_death_reason)
	_death_keys = _label("[ENTER] OPNIEUW   [ESC] HOOFDMENU", _font_pixel, 12, UiStyle.MUTED, 2)
	_death_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_death_keys)


## Shows the death screen; `cause` is a key of DEATH_CAUSES (else a general line).
func show_death(cause := "") -> void:
	if _death_layer.visible:
		return
	if _pause_layer.visible:
		set_paused(false)
	_death_reason.text = String(DEATH_CAUSES.get(cause, "%s heeft het niet gered.")) % player_name
	_death_layer.visible = true
	_death_layer.modulate.a = 0.0
	_death_keys.modulate.a = 0.0
	_death_since = Time.get_ticks_msec() / 1000.0
	var fade := create_tween()
	fade.tween_property(_death_layer, "modulate:a", 1.0, 0.6)
	fade.tween_property(_death_keys, "modulate:a", 1.0, 0.4).set_delay(DEATH_KEYS_AFTER - 0.6)
	_city_music_on = false
	_fade_city_music_to("", 0.8)
	_play_jingle(DEATH_JINGLE, DEATH_JINGLE_VOLUME_DB, "DoodDeuntje")


func _death_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() / 1000.0 - _death_since < DEATH_KEYS_AFTER:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		UiSounds.play(self, "doe")
		await SwipeTransition.swipe(get_tree()).covered
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UiSounds.play(self, "doe")
		await SwipeTransition.swipe(get_tree()).covered
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _build_crt() -> void:
	_crt_overlay = ColorRect.new()
	_crt_overlay.name = "CRT"
	_crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = UiStyle.CRT_SHADER
	_crt_overlay.material = material
	# outside the scaled design: always the whole window, in real screen lines
	_crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	material.set_shader_parameter("ui_texture", _ui_viewport.get_texture())
	add_child(_crt_overlay)
	_crt_overlay.resized.connect(_update_crt)
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


## Hands the CRT settings to its shader; off altogether when it would change nothing.
func _update_crt() -> void:
	if _crt_overlay == null:
		return
	var material := _crt_overlay.material as ShaderMaterial
	material.set_shader_parameter("curvature", crt_curvature)
	material.set_shader_parameter("ui_curvature", minf(crt_ui_curvature, crt_curvature))
	material.set_shader_parameter("corner", crt_corner if crt_curvature > 0.0 else 0.0)
	material.set_shader_parameter("screen_size", _crt_overlay.size if _crt_overlay.size.x > 0.0 else Vector2(1280, 720))
	# always drawn: it also lays the HUD's picture over the world


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
	var factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	_root.scale = Vector2(factor, factor)
	_root.size = window / factor
	_place_corners()


func _place_corners() -> void:
	if _root == null or _money_panel == null:
		return
	var area := _root.size
	_area_banner.position = Vector2((area.x - NOTICE_WIDTH) * 0.5, 34.0)
	_minimap_box.position = Vector2(area.x - MARGIN - 200.0, MARGIN)
	_quest_list.position = Vector2(area.x - MARGIN - 300.0, 290.0 + MAP_TOP)
	_money_panel.position = area - Vector2(MARGIN, 28.0) - _money_panel.size
	_place_action_prompts()


func _place_action_prompts() -> void:
	if _action_prompts and _root:
		_action_prompts.reset_size()
		_action_prompts.position = Vector2(MARGIN, _root.size.y - 28.0 - _action_prompts.size.y)


## The context actions bottom left: [key text, action text] each; empty hides them.
func set_actions(actions: Array) -> void:
	if _action_prompts == null:
		return
	_action_prompts.set_actions(actions)
	_place_action_prompts.call_deferred()


static func _thousands(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


# ------------------------------------------------------------------ clock

func _update_clock() -> void:
	var day_cycle := get_node_or_null(day_cycle_path)
	if day_cycle != null and not _clock_from_api and "time_of_day" in day_cycle:
		var hour: float = day_cycle.time_of_day
		if _last_cycle_hour >= 0.0 and hour < _last_cycle_hour - 12.0:
			_day += 1   # it went round midnight
		_last_cycle_hour = hour
		_hour = hour
	_show_clock()


func _show_clock() -> void:
	var minutes := int(_hour * 60.0) % (24 * 60)
	_time_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	_day_label.text = "DAG %d" % _day
	var night := _hour < 6.5 or _hour > 21.0
	_time_icon.colour = UiStyle.MUTED if night else UiStyle.ACCENT


# ------------------------------------------------------------------ minimap

## One pixel per 4 m cell: the kind of ground of the top Grond tile at street level, and
## dark where the Gebouwen GridMap has a building. Built once.
## Inside `interior` (Interiors.enter): the minimap shows its floor plan, read from its
## colliders (InteriorPlan; made once per interior, a physics step after it is live), and
## its ways out (`exits`, world positions) as green marks, or arrows on the edge.
func show_interior_plan(interior: Node3D, exits: Array[Vector3]) -> void:
	_exit_points = exits
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _exit_points != exits or not is_instance_valid(interior):
		return   # out again meanwhile
	# an interior can say which part of it is the plan (the floor you are on in the city hall,
	# the layout of this branch of a supermarket: plan_root); a new part is a new plan
	var plan_source: Node3D = interior.call("plan_root") if interior.has_method("plan_root") else interior
	if plan_source == null:
		plan_source = interior
	var key := plan_source.get_instance_id()
	if not _interior_plans.has(key):
		_interior_plans[key] = InteriorPlan.build(plan_source)
	var plan: Dictionary = _interior_plans[key]
	if plan.is_empty() or _minimap_map == null:
		return
	if _town_map.is_empty():
		_town_map = {"texture": _minimap_map.texture, "origin": _minimap_origin, "metres_per_pixel": _minimap_cell}
	_minimap_map.texture = plan.texture
	_minimap_origin = plan.origin
	_minimap_cell = plan.metres_per_pixel
	var extent: Vector2 = plan.extent
	_minimap_metres_now = clampf(maxf(extent.x, extent.y) * 1.1, INTERIOR_MINIMAP_MIN_METRES, minimap_metres)


## Back outside: the town's map on the minimap again.
func show_town_plan() -> void:
	_exit_points = []
	_minimap_metres_now = 0.0
	if _town_map.is_empty():
		return
	_minimap_map.texture = _town_map.texture
	_minimap_origin = _town_map.origin
	_minimap_cell = _town_map.metres_per_pixel
	_town_map = {}


func _build_minimap_image() -> void:
	var ground := get_node_or_null(ground_path) as GridMap
	if ground == null or ground.mesh_library == null:
		return
	var cells := ground.get_used_cells()
	if cells.is_empty():
		return
	var lowest := Vector2i(1 << 30, 1 << 30)
	var highest := -lowest
	var top := {}   # Vector2i -> the highest cell at street level or below
	for cell in cells:
		if cell.y > 0:
			continue
		var column := Vector2i(cell.x, cell.z)
		if not top.has(column) or cell.y > top[column].y:
			top[column] = cell
		lowest = Vector2i(mini(lowest.x, cell.x), mini(lowest.y, cell.z))
		highest = Vector2i(maxi(highest.x, cell.x), maxi(highest.y, cell.z))
	if top.is_empty():
		return
	var size := highest - lowest + Vector2i.ONE
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(MINIMAP_EMPTY)
	var kind_of_item := {}
	for column: Vector2i in top:
		var item := ground.get_cell_item(top[column])
		if not kind_of_item.has(item):
			kind_of_item[item] = _minimap_kind(ground.mesh_library.get_item_name(item))
		image.set_pixel(column.x - lowest.x, column.y - lowest.y, MINIMAP_COLOURS[kind_of_item[item]])
	var buildings := get_node_or_null(buildings_path) as GridMap
	if buildings != null:
		for cell in buildings.get_used_cells():
			var pixel := Vector2i(cell.x, cell.z) - lowest
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < size.x and pixel.y < size.y:
				image.set_pixelv(pixel, MINIMAP_COLOURS["building"])
	_minimap_cell = ground.cell_size.x
	# cell (x, z) spans x*4 .. x*4+4 (the GridMap centres its tiles in their cells)
	_minimap_origin = Vector2(lowest) * _minimap_cell + Vector2(ground.position.x, ground.position.z)
	_minimap_map.texture = ImageTexture.create_from_image(image)
	_map_lowest = lowest
	var story := get_node_or_null(story_path)
	if story and story.has_signal("shroud_changed") and not story.shroud_changed.is_connected(_refresh_shroud):
		story.shroud_changed.connect(_refresh_shroud)
	_refresh_shroud()


## The shroud of the story painted over the map: every cell it has not opened in the colour
## of the empty map (opaque), the open ones clear; the minimap and the game menu's map use it
## (shroud_image). Again whenever the story opens more (Story.shroud_changed).
func _refresh_shroud() -> void:
	var story := get_node_or_null(story_path)
	var map_texture: Texture2D = _town_map.get("texture", _minimap_map.texture) if _minimap_map else null
	if story == null or not "shroud" in story or map_texture == null:
		_shroud_image = null
		_shroud_texture = null
		return
	var shroud = story.shroud
	var size := Vector2i(map_texture.get_size())
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var hidden := Color(MINIMAP_EMPTY, 1.0)
	var any := false
	for y in size.y:
		for x in size.x:
			if not shroud.is_open_cell(x + _map_lowest.x, y + _map_lowest.y):
				image.set_pixel(x, y, hidden)
				any = true
	_shroud_image = image if any else null
	if _shroud_image == null:
		_shroud_texture = null
	elif _shroud_texture and Vector2i(_shroud_texture.get_size()) == size:
		_shroud_texture.update(image)
	else:
		_shroud_texture = ImageTexture.create_from_image(image)
	if _minimap_shroud:
		_minimap_shroud.texture = _shroud_texture


## The shroud over the town's map picture (pixels as minimap_texture), null when all is open.
func shroud_image() -> Image:
	return _shroud_image


## Whether the world point (x, z) is under the shroud (hidden on the maps).
func is_shrouded(world: Vector2) -> bool:
	var story := get_node_or_null(story_path)
	return story != null and "shroud" in story and not story.shroud.is_open(world.x, world.y)


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


static func _minimap_kind(item_name: String) -> String:
	var folder := item_name.get_slice("/", 0)
	if item_name.contains("gras") or item_name.contains("park"):
		return "grass"
	if folder == "natuur" and (item_name.contains("pad") or item_name.contains("grind")):
		return "pavement"
	return MINIMAP_KINDS.get(folder, "land")


## Moves the map so the player (the followed vehicle, else the point the camera looks at)
## is in the middle, and turns the arrow its way.
func _update_minimap() -> void:
	if _minimap_map.texture == null:
		return
	var heading := Vector3.FORWARD
	var focus := Vector3.ZERO
	var follow := get_node_or_null(follow_camera_path)
	var followed: Node3D = null
	if follow != null and follow.has_method("is_following") and follow.is_following():
		followed = follow.get("target_node")
	var camera := get_viewport().get_camera_3d()
	if followed != null:
		focus = followed.global_position
		heading = followed.global_basis.z   # vehicles drive along +Z
	elif camera != null:
		focus = Iso.ground_focus(camera)
		heading = -camera.global_basis.z
	else:
		return
	var pixels_per_metre := (_minimap_arrow.get_parent() as Control).size.x / (_minimap_metres_now if _minimap_metres_now > 0.0 else minimap_metres)
	var scale_per_cell := pixels_per_metre * _minimap_cell
	var texture_size := _minimap_map.texture.get_size()
	_minimap_map.size = texture_size * scale_per_cell
	_focus = focus
	_has_focus = true
	var focus_on_map := (Vector2(focus.x, focus.z) - _minimap_origin) * pixels_per_metre
	_minimap_map.position = _minimap_arrow.position - focus_on_map
	if _minimap_shroud:
		_minimap_shroud.visible = _town_map.is_empty() and _shroud_texture != null
		_minimap_shroud.size = _minimap_map.size
		_minimap_shroud.position = _minimap_map.position
	var flat := Vector2(heading.x, heading.z)
	if flat.length_squared() > 0.0001:
		_minimap_arrow.rotation = atan2(flat.x, -flat.y)
	var marks := []
	# inside a building: its ways out, not the quest places in the town; only a place in the
	# building itself (INDOOR_TARGET_REACH: the cans of mission 1 in the station, Story)
	var indoors := not _town_map.is_empty()
	for target: Vector2 in quest_targets():
		var offset := target - Vector2(focus.x, focus.z)
		if indoors and offset.length() > INDOOR_TARGET_REACH:
			continue
		if not indoors and is_shrouded(target):
			continue
		marks.append(_minimap_arrow.position + offset * pixels_per_metre)
	_minimap_marks.points = marks
	_update_waypoint(focus, pixels_per_metre)
	var exits := []
	for exit_point in _exit_points:
		exits.append(_minimap_arrow.position + Vector2(exit_point.x - focus.x, exit_point.z - focus.z) * pixels_per_metre)
	_minimap_exits.points = exits


## Height of the box with where the player is, over the minimap, and where the map starts
## under it (8 px lower).
const LOCATION_HEIGHT := 58.0
const MAP_TOP := LOCATION_HEIGHT + 8.0
## Seconds between looks at where the player is.
const LOCATION_INTERVAL := 0.5
## Map cells are 4 m (the "wijken" table counts in cells).
const CELL_METRES := 4.0


## Shows the neighbourhood and the nearest named place under the minimap; a neighbourhood
## entered for the first time (not the one it starts in) is announced as a new area.
func _update_location() -> void:
	if not _has_focus:
		return
	var world := owner if owner else get_parent()
	if world == null:
		return
	var cell := Vector2(_focus.x, _focus.z) / CELL_METRES
	var wijk := "Den Haag"
	for area: Array in world.get_meta("wijken", []):
		if cell.x >= area[1] and cell.y >= area[2] and cell.x < area[3] + 1 and cell.y < area[4] + 1:
			wijk = area[0]
			break
	var street := _street_at(world, cell)
	var nearest := ""
	var nearest_distance := place_near
	var places: Dictionary = world.get_meta("places", {})
	for place_key: String in places:
		if place_key.begins_with("verkeerslichten"):
			continue   # a test spot of the builder, not a place
		var distance := (places[place_key] as Vector2).distance_to(Vector2(_focus.x, _focus.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = _place_name(place_key)
	if _indoor_wijk != "":
		# inside (far off the map): the neighbourhood of the building, no street or place
		wijk = _indoor_wijk
		street = ""
		nearest = ""
	var shown_name := area_display_name(wijk)
	_location_wijk.text = shown_name.to_upper()
	_fit_location_font(_location_wijk.text)
	_location_street.text = street
	_location_street.visible = street != ""
	_location_place.text = nearest
	_location_place.visible = nearest != "" and nearest.to_lower() != wijk.to_lower() \
		and nearest.to_lower() != shown_name.to_lower() and nearest.to_lower() != street.to_lower()
	if wijk != _current_wijk:
		if _current_wijk != "" and not _visited_wijken.has(wijk):
			show_area(shown_name)
		_current_wijk = wijk
		_visited_wijken[wijk] = true


## The name a neighbourhood (a key of the "wijken" metadata) is shown by.
static func area_display_name(wijk: String) -> String:
	return String(AREA_DISPLAY_NAMES.get(wijk, wijk))


## Inside a building (Interiors): the location under the minimap is `wijk` (a key of the
## "wijken" metadata, e.g. "Centraal Station") in place of the spot far off the map; ""
## when going out again.
func set_indoor_location(wijk: String) -> void:
	_indoor_wijk = wijk
	_location_clock = 0.0   # at once (next frame)


## The neighbourhood line in its usual size, or smaller when `shown` would not fit whole.
func _fit_location_font(shown: String) -> void:
	var font := _location_wijk.get_theme_font("font")
	var room := _location_wijk.size.x
	if font == null or room <= 0.0:
		return
	var font_size := LOCATION_WIJK_FONT_SIZE
	while font_size > LOCATION_WIJK_SMALLEST_FONT_SIZE and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	_location_wijk.add_theme_font_size_override("font_size", font_size)


## Cells beside a street that still count as on it (the pavement).
const STREET_MARGIN_CELLS := 1.0


## The name of the street at this map cell (fractional), from the scene metadata
## "straten"; on the lanes before the pavement beside them; "" if none.
static func _street_at(world: Node, cell: Vector2) -> String:
	var beside := ""
	for street: Array in world.get_meta("straten", []):
		var across := cell.x if street[1] == "x" else cell.y
		var along := cell.y if street[1] == "x" else cell.x
		if along < street[4] or along >= street[5] + 1:
			continue
		if across >= street[2] and across < street[3] + 1:
			return street[0]
		if beside == "" and across >= street[2] - STREET_MARGIN_CELLS and across < street[3] + 1 + STREET_MARGIN_CELLS:
			beside = street[0]
	return beside


## A key of "places" as a name: "ministerie_van_financien" -> "Ministerie van Financien",
## "a12_koningskade" -> "A12 Koningskade".
static func _place_name(place_key: String) -> String:
	var words := place_key.split("_", false)
	# a second one of the same (a supermarket chain: "derrek_3") is just its name
	if words.size() > 1 and words[-1].is_valid_int():
		words.resize(words.size() - 1)
	for index in words.size():
		var word := words[index]
		if index > 0 and word in ["van", "de", "het", "en", "der", "den", "op"]:
			continue
		words[index] = word.substr(0, 1).to_upper() + word.substr(1)
	return " ".join(words)
