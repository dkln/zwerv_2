class_name Intro
extends Control
## The intro before the main menu (scenes/intro.tscn, the main scene), in the style of the
## HUD and the menu (scripts/ui/hud.gd, main_menu.gd), opening the way a space saga does:
## 1. on black a line in teal fades in and out (IntroRules.OPENING_LINE);
## 2. then at once a field of stars and the logo, ZWERVR in big amber outlined letters
##    coming in huge, nearly past the edges, shrinking slowly to its normal size until the
##    music's big entry, and then going away into the depth fast, fading out as it goes;
## 3. the story (IntroRules.STORY) in amber, rolling in from below while the logo is still
##    going away and up and away into the distance over the stars;
## 4. the main menu (scenes/hoofdmenu.tscn and its 3D map, loaded in the background
##    meanwhile, so it opens complete).
## It all goes by the music (assets/audio/muziek/zwervr_intro.ogg, MUSIC): the clock of the intro is where
## the music is, and the moments are set on its beats (scripts/ui/intro_timing.gd): the logo
## goes away on its first big entry, paragraphs of the story enter at its turns, and the
## intro ends where it fades. Without the music a clock of its own does the same. Where the
## logo vanishes a star twinkles.
## The space bar (only that: not other keys, the mouse or the volume keys) breaks it off at
## any moment and goes to the main menu; holding Enter (or the down arrow) rolls the story
## faster; bottom left the context action says so, as in the game (ActionPrompts:
## SPATIE Overslaan), bottom right the secondary action, as in the menu ("[ENTER] SNELLER",
## while the story rolls). The stars twinkle, and now and then something drifts through space:
## one of the zwervers of the game or a tractor (scripts/ui/intro/drifter.gd).
## The CRT look of the HUD lies over it (with the settings of the main menu).
## This is the behaviour layer: the clock on the music, the keys, the way to the menu.
## scripts/ui/intro/intro_rules.gd has the logic (the texts, the moments, what shows when),
## intro_layout.gd the sizes, intro_view.gd builds the picture and shows what it is handed.

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")
const QuickStart = preload("res://scripts/debug/quick_start.gd")
const MusicFade = preload("res://scripts/audio/music_fade.gd")
const ScreenMusic = preload("res://scripts/ui/menu/screen_music.gd")
const IntroRules = preload("res://scripts/ui/intro/intro_rules.gd")
const IntroLayout = preload("res://scripts/ui/intro/intro_layout.gd")
const IntroView = preload("res://scripts/ui/intro/intro_view.gd")
const Drifter = preload("res://scripts/ui/intro/drifter.gd")
const DrifterRules = preload("res://scripts/ui/intro/drifter_rules.gd")

const MENU_SCENE := "res://scenes/hoofdmenu.tscn"
## Debug: straight into the game (scripts/debug/quick_start.gd), with `-- --snel`.
const QUICK_START_SCENE := "res://scenes/snel_starten.tscn"
## The music of the intro and its volume (dB); it fades into the menu's (MusicFade).
const MUSIC := "res://assets/audio/muziek/zwervr_intro.ogg"
const MUSIC_VOLUME_DB := -2.0

var _view: IntroView
var _drifter: Drifter
var _stars: Array[Dictionary] = []   # per star its pace, phase and depth of twinkling (IntroLayout.stars)
var _leaving := false
var _music: AudioStreamPlayer
var _clock := 0.0
var _crawl_ahead := 0.0   # seconds the story is ahead of the music (Enter held: CRAWL_FAST)


func _ready() -> void:
	# debug: `-- --snel` goes straight into the game as Martin (scenes/snel_starten.tscn)
	if "--snel" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(QUICK_START_SCENE)
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	GraphicsSettings.apply(get_tree())
	_view.show_crt(MainMenu.read_settings().crt)
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_start_music()
	ResourceLoader.load_threaded_request(MENU_SCENE)
	# the menu's 3D map too (it is big): the menu then opens with it at once
	if ResourceLoader.exists(MainMenu.MAP_SCENE):
		ResourceLoader.load_threaded_request(MainMenu.MAP_SCENE)


func _process(delta: float) -> void:
	if _view == null:
		return
	_clock += delta
	if not _leaving:
		var time := music_time()
		if IntroRules.crawl_started(time) and _fast_held():
			_crawl_ahead += IntroRules.crawl_gain(delta)
		play(time)
	if not _view.stars_visible():
		return
	_drifter.advance(_clock, delta)
	_view.show_twinkles(_stars.map(func(star: Dictionary) -> float:
		return IntroRules.twinkle_alpha(_clock, star.pace, star.phase, star.depth)))


func _input(event: InputEvent) -> void:
	# debug: F8 straight into the town as Martin (scripts/debug/quick_start.gd)
	if QuickStart.skip_on_key(self, event):
		return
	# only the space bar (or Enter: A on a controller, pad_keys.gd) skips (other keys, such as
	# the volume keys, do nothing)
	if IntroRules.is_skip_key(event):
		get_viewport().set_input_as_handled()
		if not _leaving:
			UiSounds.play(self, "doe")
		to_menu()


## Seconds into the music (where it is now heard; the intro's own clock without it).
func music_time() -> float:
	if _music and _music.playing:
		return _music.get_playback_position() + AudioServer.get_time_since_last_mix()
	return _clock


## Sets everything as it is at moment `time` of the intro; at its end the main menu.
func play(time: float) -> void:
	_view.show_line(IntroRules.line_alpha(time))
	# the stars and the logo all at once on the first big entry; it stands, then goes away
	_view.show_stars(IntroRules.stars_shown(time), IntroRules.fade_in(time))
	_view.show_logo(IntroRules.logo_shown(time), IntroRules.logo_scale(time), IntroRules.logo_alpha(time))
	# the story, its paragraphs coming in on their cues (ahead of the music while Enter is held)
	var crawl_time := time + _crawl_ahead
	var story_top := IntroRules.crawl_position(crawl_time, _view.paragraph_tops(), _view.story_height(),
			IntroLayout.CRAWL_PICTURE.y, IntroLayout.CRAWL_REST)
	_view.show_story_at(IntroRules.crawl_started(time) and not IntroRules.crawl_ended(crawl_time), story_top,
			IntroRules.crawl_alpha(crawl_time))
	# a star twinkles where the logo vanishes in the distance
	var twinkling := IntroRules.sparkle_share(time)
	_view.show_sparkle(IntroRules.sparkle_shown(twinkling), twinkling, IntroRules.sparkle_flare(twinkling))
	# the secondary action shows while the story rolls
	_view.show_fast_offer(IntroRules.fast_offered(time))
	if IntroRules.crawl_ended(crawl_time):
		to_menu()


## To the main menu (loaded in the background meanwhile). Broken off before the menu's 3D
## map is loaded, the intro stays (stars and all) until it is, so the menu never opens
## empty.
func to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	# the music goes on into the menu, fading out there (the menu's own fades in meanwhile):
	# it moves to the root of the tree, which stays, and is freed when it is silent
	# (MusicFade: equal power, so it runs into the menu's music instead of over it)
	MusicFade.fade_out(_music)
	_music = null
	# the swipe (the one transition of the game) over it, the menu behind it
	await SwipeTransition.swipe(get_tree()).covered
	while ResourceLoader.exists(MainMenu.MAP_SCENE) \
			and ResourceLoader.load_threaded_get_status(MainMenu.MAP_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(MENU_SCENE) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(MENU_SCENE)


## Whether the intro is on its way to the main menu.
func is_leaving() -> bool:
	return _leaving


## Seconds the story is ahead of the music (Enter held).
func crawl_ahead() -> float:
	return _crawl_ahead


func view() -> IntroView:
	return _view


func drifter() -> Drifter:
	return _drifter


## The picture, its texts and stars, and what drifts through it.
func _build() -> void:
	_view = IntroView.new()
	add_child(_view)
	var star_random := RandomNumberGenerator.new()
	star_random.seed = IntroLayout.STAR_SEED
	_stars = IntroLayout.stars(star_random)
	_view.show_star_field(_stars)
	_view.show_texts(IntroRules.OPENING_LINE, IntroRules.STORY)
	_view.show_actions([IntroRules.SKIP_ACTION], IntroRules.FAST_TEXT)
	_drifter = Drifter.new()
	_drifter.first_at = IntroRules.LOGO_FADE_IN_AT + DrifterRules.FIRST
	_drifter.last_at = IntroRules.END_AT - DrifterRules.STOP_BEFORE_END
	_view.add_behind_story(_drifter)


static func _fast_held() -> bool:
	for key in IntroRules.FAST_KEYS:
		if Input.is_key_pressed(key):
			return true
	return false


## Plays the intro music (ScreenMusic: imported, or read straight from the file).
func _start_music() -> void:
	_music = ScreenMusic.player(self, "intro", MUSIC, false)
	if _music:
		_music.volume_db = MUSIC_VOLUME_DB
		_music.play()


func _fit_to_window() -> void:
	_view.show_window(get_viewport().get_visible_rect().size)
