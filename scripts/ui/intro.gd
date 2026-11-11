class_name Intro
extends Control
## The intro before the main menu (scenes/intro.tscn, the main scene), in the style of the
## HUD and the menu (scripts/ui/hud.gd, main_menu.gd), opening the way a space saga does:
## 1. on black a line in teal fades in and out (OPENING_LINE);
## 2. then at once a field of stars and the logo, ZWERVR in big amber outlined letters
##    coming in huge, nearly past the edges (LOGO_HUGE_SCALE), shrinking slowly to its
##    normal size (LOGO_START_SCALE) until the music's big entry, and then going away into
##    the depth fast, fading out as it goes (LOGO_SECONDS);
## 3. the story (STORY) in amber, rolling in from below while the logo is still going away
##    and up and away into the distance over the stars: the text is drawn into a picture of
##    its own (a SubViewport) that a shader lays on the screen in perspective, narrow far off
##    at the top, fading out there;
## 4. the main menu (scenes/hoofdmenu.tscn and its 3D map, loaded in the background
##    meanwhile, so it opens complete).
## It all goes by the music (assets/audio/muziek/zwervr_intro.ogg, MUSIC): the clock of the intro is where
## the music is, and the moments are set on its beats (CUES, the composition's MOMENTEN): the logo
## goes away on its first big entry, paragraphs of the story enter at its turns
## (CRAWL_CUES), and the intro ends where it fades. Without the music a clock of its own
## does the same. Where the logo vanishes a star twinkles.
## The space bar (only that: not other keys, the mouse or the volume keys) breaks it off at
## any moment and goes to the main menu; holding Enter (or the down arrow) rolls the story
## faster (CRAWL_FAST); bottom left the context action says so, as in the game (ActionPrompts:
## SPATIE Overslaan), bottom right the secondary action, as in the menu ("[ENTER] SNELLER",
## while the story rolls). The stars twinkle, and now and then something drifts through space:
## one of the zwervers of the game (the characters of the character creation screen) or a
## tractor.
## The CRT look of the HUD lies over it (UiStyle.make_crt_overlay, with the settings of the
## main menu).

const UiSounds = preload("res://scripts/ui/ui_sounds.gd")
const SwipeTransition = preload("res://scripts/ui/swipe_transition.gd")
const ProtestFlag = preload("res://scripts/vehicles/protest_flag.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")
const PlayerCharacter = preload("res://scripts/player/player_character.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const GraphicsSettings = preload("res://scripts/ui/graphics_settings.gd")

const MENU_SCENE := "res://scenes/hoofdmenu.tscn"
## The music of the intro, its volume (dB), and the seconds it fades out in when the intro
## ends or is broken off.
const MUSIC := "res://assets/audio/muziek/zwervr_intro.ogg"
const MUSIC_VOLUME_DB := 0.0
const MUSIC_FADE_OUT := 2.0
const DESIGN_SIZE := Vector2(1280, 720)
const OPENING_LINE := "Niet zo lang geleden, in een stad hier niet ver vandaan…"
## The story that rolls away after the logo, a paragraph per entry (an optional "\n"
## splits a paragraph into lines; a line too long for the picture wraps by itself).
## The count and order matter: CRAWL_CUES points at paragraphs by index.
const STORY := [
	"Den Haag. Hofstad, regeringsstad,\nstad van vrede en recht.",
	"Hier worden de grote besluiten genomen.\nMeestal na de lunch, en altijd pas na een tweede overleg.",
	"Ambtenaren fietsen van vergadering naar vergadering.\nLobbyisten kennen de weg naar binnen beter dan de bodes.",
	"Op het Malieveld staan de trekkers alweer te toeteren.\nWaartegen weet niemand precies, maar het klinkt boos.",
	"En op Scheveningen heersen de meeuwen.\nGeen patatje is er veilig.",
	"Midden in die stad woont een zwerver.\nGeen vast adres, wel een vaste bank aan het Lange Voorhout.",
	"Hij leeft van statiegeld. Twintig blikjes is een broodje bal,\ndertig is een broodje bal met mosterd.",
	"Als het regent zit hij in de bibliotheek\nen leest hij heel langzaam de krant van gisteren.",
	"Hij kent de rondes van elke handhaver,\nontwijkt elke fatbike en kijkt meeuwen nooit recht aan.",
	"Maar vandaag is alles anders. Zijn bank is weg.\nEr staat een hek omheen, met een bordje: Hier komt iets moois.",
	"Hij pakt zijn winkelwagen, trekt zijn jas recht\nen duwt de regen in.",
	"Zo begint zijn zwerftocht door Den Haag.",
]
## The moments of the intro come from the music (scripts/ui/intro_timing.gd, written by
## tools/muziek/build.py from the MOMENTEN of the active composition, so they follow any new
## music): the logo on the first big entry (LOGO_AT), the story rolling from CRAWL_AT,
## paragraphs on the climax, the duel and the crash (CRAWL_CUES), the last one coming to rest on
## the final hit (REST_AT), and the end (END_AT) once that has rung out, where the menu takes
## over. The opening line fades in and out before the logo.
const IntroTiming := preload("res://scripts/ui/intro_timing.gd")
const LINE_IN_AT := 0.4
const LINE_OUT_AT := 3.6    # gone at 4.8, before the logo fades in
## The logo and the stars fade in from LOGO_FADE_IN_AT, stand there whole from LOGO_AT, and
## the logo stands big (LOGO_HOLD) until the exploration theme of the music (CRAWL_AT): there it starts
## to go away and the story comes in.
const LOGO_FADE_IN_AT := IntroTiming.LOGO_AT - 1.0
const LINE_FADE := 1.2
const LOGO_AT := IntroTiming.LOGO_AT
const CRAWL_AT := IntroTiming.CRAWL_AT
## The story rolls to REST_AT (the final hit of the music): the last paragraph does not roll
## off the top but comes to rest there far off at CRAWL_REST (share of the picture's height
## from the top), and fades out while the hit rings out, to END_AT; no travel wasted, so it
## rolls as slowly as the music allows.
const REST_AT := IntroTiming.REST_AT
const END_AT := IntroTiming.END_AT
const CRAWL_REST := 0.35
## Holding Enter (or the down arrow) rolls the story this many times as fast; it then
## reaches its end, and the intro the main menu, sooner (the music goes on into the menu).
const CRAWL_FAST := 12.0
const FAST_KEYS: Array[Key] = [KEY_ENTER, KEY_KP_ENTER, KEY_DOWN]
## Now and then something drifts through space behind the story, tumbling slowly (drawn in
## 3D into a small picture of its own, DRIFTER_PICTURE pixels, shown DRIFTER_SIZE big on
## the screen at most): the first DRIFTER_FIRST seconds after the stars come, then every
## DRIFTER_EVERY (from .. to) seconds, each crossing the screen in DRIFTER_SECONDS (from .. to).
## What drifts: one of the characters (PlayerCharacter.ORDER, CHARACTER_SCALE times their
## size so they show as big as a tractor, flailing as if they swim) with CHARACTER_CHANCE,
## else a tractor (TRACTOR_MODELS); never the same one twice in a row.
const DRIFTER_FIRST := 14.0
const DRIFTER_EVERY := Vector2(10.0, 20.0)
const DRIFTER_SECONDS := Vector2(14.0, 20.0)
const DRIFTER_PICTURE := 96
const DRIFTER_SIZE := 190.0
const TRACTOR_MODELS := ["trekker", "trekker_rood"]
const CHARACTER_CHANCE := 0.7
const CHARACTER_SCALE := 2.2
## Pixels between the paragraphs of the story (in its picture).
const PARAGRAPH_GAP := 26
## Paragraphs of STORY and the moment each comes in at the bottom of the screen: the gulls on
## the chorus, the handhavers on the breakdown, the way out into the rain on the finale (the
## last sentence then comes to rest on the final hit). Chosen so that between them the story
## rolls evenly, at much the same pace throughout (about 3.4 s a paragraph).
const CRAWL_CUES := {4: IntroTiming.CLIMAX_AT, 8: IntroTiming.DUEL_AT, 10: IntroTiming.CRASH_AT}
## The crawl picture: the size the text is drawn in (pixels), the
## width of its far top edge on the screen (share of the bottom edge) and how much of the
## screen it takes from the bottom up.
const CRAWL_PICTURE := Vector2i(900, 1400)
const CRAWL_FAR_WIDTH := 0.22
const CRAWL_SCREEN_TOP := 0.08
const TITLE := "ZWERVR"
## Seconds the logo stands big before it goes (to the first big entry, CRAWL_AT), and that
## it takes to go away.
const LOGO_HOLD := CRAWL_AT - LOGO_AT
const LOGO_SECONDS := 2.5
## The logo: its size at the start (1.3: big, about nine tenths of the width of the screen)
## and at the end, far off.
const LOGO_START_SCALE := 1.3
## Its size as it comes in (nearly past the edges of the screen), shrinking slowly to
## LOGO_START_SCALE until it starts to go.
const LOGO_HUGE_SCALE := 5.0
const LOGO_END_SCALE := 0.02
## Where the logo vanishes in the distance a star twinkles: a four-pointed flash of pixels
## (SPARKLE_ARM long) that flares up, turns an eighth round and dies out, sparks flying
## off it (SPARKLE_SPARKS, out to SPARKLE_REACH pixels); from SPARKLE_AT for SPARKLE_SECONDS.
const SPARKLE_AT := LOGO_AT + LOGO_HOLD + LOGO_SECONDS * 0.92
const SPARKLE_SECONDS := 0.9
const SPARKLE_FLARE := 0.18   # share of it in which it flares up
const SPARKLE_ARM := 34.0
const SPARKLE_SPARKS := 8
const SPARKLE_REACH := 90.0
const STAR_COUNT := 140

var _design: Control
var _prompts: ActionPrompts
var _fast_footer: Label
var _line: Label
var _stars: Control
var _logo_holder: Control
var _crawl_text: VBoxContainer   # the story in its picture, rolled up by _play
var _crawl_screen: ColorRect     # that picture laid on the screen in perspective
var _leaving := false
var _sparkle: Control   # the twinkle where the logo vanishes
var _sparks: Array[ColorRect] = []
var _music: AudioStreamPlayer
var _twinkles: Array[Vector3] = []   # per star: pace (rad/s), phase, how deep it dims
var _clock := 0.0
var _crawl_ahead := 0.0   # seconds the story is ahead of the music (Enter held: CRAWL_FAST)
var _drifter_view: TextureRect   # the picture of what drifts, on the screen
var _drifter_picture: SubViewport
var _drifter_spinner: Node3D     # turned as it tumbles
var _drifter_model: Node3D       # what drifts: a character or a tractor, swapped per flight
var _last_drifter := ""         # its name (character id or tractor model), not twice in a row
var _drifter_flight := {}        # the flight under way: from, to, start, seconds, axis, spin; empty when none
var _next_drifter_at := LOGO_FADE_IN_AT + DRIFTER_FIRST
var _drifter_random := RandomNumberGenerator.new()
## Stars twinkle: each dims and brightens at its own pace (from .. to, radians a second).
const TWINKLE_PACE := Vector2(1.2, 4.5)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_design = Control.new()
	_design.size = DESIGN_SIZE
	_design.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_design)
	_build_stars()
	_build_line()
	_build_logo()
	_build_sparkle()
	_build_drifter()
	_build_crawl()
	_build_prompts()
	GraphicsSettings.apply(get_tree())
	var settings := MainMenu._read_settings()
	var crt := UiStyle.make_crt_overlay(0.05 if settings.crt else 0.0, 0.035 if settings.crt else 0.0,
			UiStyle.SCANLINE_STRENGTH if settings.scanlines else 0.0, get_viewport().get_visible_rect().size)
	add_child(crt)
	# the disturbances of the menu too: a rolling band, now and then VHS tracking
	crt.add_child(load("res://scripts/ui/crt_disturbance.gd").new())
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()
	_start_music()
	ResourceLoader.load_threaded_request(MENU_SCENE)
	# the menu's 3D map too (it is big): the menu then opens with it at once
	if ResourceLoader.exists(MainMenu.MAP_SCENE):
		ResourceLoader.load_threaded_request(MainMenu.MAP_SCENE)


func _process(delta: float) -> void:
	_clock += delta
	if not _leaving:
		var time := _music_time()
		if time >= CRAWL_AT and _fast_held():
			_crawl_ahead += delta * (CRAWL_FAST - 1.0)
		_play(time)
		_update_prompts(time)
	_fly_drifter()
	if not _stars.visible:
		return
	for star_index in _twinkles.size():
		var twinkle := _twinkles[star_index]
		var wave := 0.5 + 0.5 * sin(_clock * twinkle.x + twinkle.y)
		# mostly bright, now and then a short dip (the wave sharpened)
		(_stars.get_child(star_index) as CanvasItem).modulate.a = 1.0 - twinkle.z * pow(wave, 6.0)


func _input(event: InputEvent) -> void:
	# only the space bar skips (other keys, such as the volume keys, do nothing)
	var pressed: bool = event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_SPACE
	if pressed:
		get_viewport().set_input_as_handled()
		if not _leaving:
			UiSounds.play(self, "doe")
		_to_menu()


static func _fast_held() -> bool:
	for key in FAST_KEYS:
		if Input.is_key_pressed(key):
			return true
	return false


## Seconds into the music (where it is now heard; the intro's own clock without it).
func _music_time() -> float:
	if _music and _music.playing:
		return _music.get_playback_position() + AudioServer.get_time_since_last_mix()
	return _clock


## Sets everything as it is at moment `time` of the intro (CUES); at END_AT the main menu.
func _play(time: float) -> void:
	# the opening line
	var line_in := clampf((time - LINE_IN_AT) / LINE_FADE, 0.0, 1.0)
	var line_out := clampf((time - LINE_OUT_AT) / LINE_FADE, 0.0, 1.0)
	_line.modulate.a = line_in * (1.0 - line_out)
	# the stars and the logo all at once on the first big entry; it stands, then goes away
	# as a thing does that flies off ever faster: its distance grows with the square of the
	# time, its size is one over the distance, so it shrinks slowly at first
	var since_logo := time - LOGO_AT
	var fading_in := clampf((time - LOGO_FADE_IN_AT) / (LOGO_AT - LOGO_FADE_IN_AT), 0.0, 1.0)
	_stars.visible = time >= LOGO_FADE_IN_AT
	_stars.modulate.a = fading_in
	_logo_holder.visible = time >= LOGO_FADE_IN_AT and since_logo < LOGO_HOLD + LOGO_SECONDS
	if _logo_holder.visible:
		var going := clampf((since_logo - LOGO_HOLD) / LOGO_SECONDS, 0.0, 1.0)
		var distance := 1.0 + (LOGO_START_SCALE / LOGO_END_SCALE - 1.0) * going * going
		# before it goes: from huge, nearly past the edges, slowly down to its normal size
		# (easing out) by the time it starts to go
		var settling := clampf((time - LOGO_FADE_IN_AT) / (LOGO_AT + LOGO_HOLD - LOGO_FADE_IN_AT), 0.0, 1.0)
		var size := lerpf(LOGO_HUGE_SCALE, LOGO_START_SCALE, 1.0 - pow(1.0 - settling, 2.0))
		_logo_holder.scale = Vector2.ONE * size / distance
		# fading out the whole way as it goes
		_logo_holder.modulate.a = fading_in * (1.0 - going)
	# the story, its paragraphs coming in on their cues
	# (ahead of the music while Enter is held)
	var crawl_time := time + _crawl_ahead
	_crawl_screen.visible = time >= CRAWL_AT and crawl_time < END_AT
	if _crawl_screen.visible:
		_crawl_text.position.y = _crawl_position(crawl_time)
		_crawl_screen.modulate.a = clampf((END_AT - crawl_time) / maxf(END_AT - REST_AT, 0.1), 0.0, 1.0)
	# a star twinkles where the logo vanishes in the distance
	var twinkling := (time - SPARKLE_AT) / SPARKLE_SECONDS
	_sparkle.visible = twinkling >= 0.0 and twinkling < 1.0
	if _sparkle.visible:
		var flare := twinkling / SPARKLE_FLARE if twinkling < SPARKLE_FLARE \
				else 1.0 - (twinkling - SPARKLE_FLARE) / (1.0 - SPARKLE_FLARE)
		_sparkle.scale = Vector2.ONE * (0.2 + 0.8 * sqrt(flare))
		_sparkle.rotation = twinkling * PI * 0.25
		_sparkle.modulate.a = flare
		for spark_index in _sparks.size():
			var direction := Vector2.RIGHT.rotated(TAU * (spark_index + 0.5) / _sparks.size())
			var spark := _sparks[spark_index]
			spark.position = DESIGN_SIZE * 0.5 + direction * SPARKLE_REACH * (1.0 - pow(1.0 - twinkling, 2.0)) - spark.size * 0.5
			spark.modulate.a = 1.0 - twinkling
			spark.visible = true
	else:
		for spark in _sparks:
			spark.visible = false
	if crawl_time >= END_AT:
		_to_menu()


## Where the story stands at `time`: rolled evenly between the cues, each cue a paragraph
## of STORY coming in at the bottom of the picture (its top there), from the whole text
## under the picture at CRAWL_AT to the last paragraph at rest far off (CRAWL_REST) at REST_AT,
## where it stays.
func _crawl_position(time: float) -> float:
	var stops: Array = [[CRAWL_AT, float(CRAWL_PICTURE.y)]]
	var paragraphs := _crawl_text.get_children()
	var cue_paragraphs := CRAWL_CUES.keys()
	cue_paragraphs.sort()
	for paragraph_index: int in cue_paragraphs:
		if paragraph_index < paragraphs.size():
			var paragraph_top: float = (paragraphs[paragraph_index] as Control).position.y
			stops.append([CRAWL_CUES[paragraph_index], CRAWL_PICTURE.y - paragraph_top])
	stops.append([REST_AT, CRAWL_PICTURE.y * CRAWL_REST - _crawl_text.size.y])
	for stop_index in range(1, stops.size()):
		var earlier: Array = stops[stop_index - 1]
		var later: Array = stops[stop_index]
		if time <= later[0]:
			return lerpf(earlier[1], later[1], clampf((time - earlier[0]) / (later[0] - earlier[0]), 0.0, 1.0))
	return stops[-1][1]


## To the main menu (loaded in the background meanwhile). Broken off before the menu's 3D
## map is loaded, the intro stays (stars and all) until it is, so the menu never opens
## empty.
func _to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	# the music goes on into the menu, fading out there (the menu's own fades in meanwhile):
	# it moves to the root of the tree, which stays, and is freed when it is silent
	if _music and _music.playing:
		var music := _music
		_music = null
		music.reparent(get_tree().root)
		var fade := get_tree().create_tween()
		fade.tween_property(music, "volume_db", -60.0, MUSIC_FADE_OUT)
		fade.tween_callback(music.queue_free)
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


## Plays the intro music (imported by the editor; if it has not been imported yet, read
## straight from the file).
func _start_music() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(MUSIC):
		stream = load(MUSIC)
	elif FileAccess.file_exists(MUSIC):
		stream = AudioStreamOggVorbis.load_from_file(MUSIC)
	if stream == null:
		push_warning("intro: no music at %s" % MUSIC)
		return
	_music = AudioStreamPlayer.new()
	_music.name = "Muziek"
	_music.stream = stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()


## The twinkle where the logo vanishes: two crossing bars of pixels (long and thin, as the
## rays of a star), a bright core, and the sparks round it.
func _build_sparkle() -> void:
	_sparkle = Control.new()
	_sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle.position = DESIGN_SIZE * 0.5
	_sparkle.visible = false
	_design.add_child(_sparkle)
	for ray: Vector2 in [Vector2(4.0, SPARKLE_ARM * 2.0), Vector2(SPARKLE_ARM * 2.0, 4.0),
			Vector2(8.0, SPARKLE_ARM), Vector2(SPARKLE_ARM, 8.0)]:
		var bar := ColorRect.new()
		bar.size = ray
		bar.position = -ray * 0.5
		bar.color = MainMenu.STAR_BRIGHT
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sparkle.add_child(bar)
	var core := ColorRect.new()
	core.size = Vector2.ONE * 10.0
	core.position = -core.size * 0.5
	core.color = Color.WHITE
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparkle.add_child(core)
	for _spark_index in SPARKLE_SPARKS:
		var spark := ColorRect.new()
		spark.size = Vector2.ONE * 3.0
		spark.color = MainMenu.STAR_BRIGHT
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.visible = false
		_design.add_child(spark)
		_sparks.append(spark)


func _build_stars() -> void:
	_stars = Control.new()
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.visible = false
	_design.add_child(_stars)
	var random := RandomNumberGenerator.new()
	random.seed = 11
	for _star_index in STAR_COUNT:
		var big := random.randf() > 0.88
		var star := ColorRect.new()
		star.position = Vector2(random.randi_range(0, int(DESIGN_SIZE.x) - 1), random.randi_range(0, int(DESIGN_SIZE.y) - 1))
		star.size = Vector2.ONE * (3.0 if big else 2.0)
		star.color = MainMenu.STAR_BRIGHT if big else MainMenu.STAR_DIM
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stars.add_child(star)
		# each its own pace and moment of twinkling
		_twinkles.append(Vector3(random.randf_range(TWINKLE_PACE.x, TWINKLE_PACE.y), random.randf() * TAU, 0.35 if big else 0.6))


func _build_line() -> void:
	_line = Label.new()
	_line.text = OPENING_LINE
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # too wide for the picture: two lines
	_line.size = DESIGN_SIZE
	_line.add_theme_font_override("font", _font(UiStyle.FONT_TITLE, 500))
	_line.add_theme_font_size_override("font_size", 30)
	_line.add_theme_color_override("font_color", UiStyle.SIDE_ACCENT)
	_line.modulate.a = 0.0
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_line)


## The logo: ZWERVR in amber outline (dark inside, as the letters of a space saga), with a
## hard ink shadow, filling the width of the screen; scaled about the middle.
func _build_logo() -> void:
	_logo_holder = Control.new()
	_logo_holder.size = DESIGN_SIZE
	_logo_holder.pivot_offset = DESIGN_SIZE * 0.5
	_logo_holder.visible = false
	_logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_logo_holder)
	var logo := Label.new()
	logo.text = TITLE
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.size = DESIGN_SIZE
	logo.add_theme_font_override("font", UiStyle.spaced(_font(UiStyle.FONT_TITLE, 700), 8))
	logo.add_theme_font_size_override("font_size", 230)
	logo.add_theme_color_override("font_color", Color.BLACK)
	logo.add_theme_color_override("font_outline_color", UiStyle.ACCENT)
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", UiStyle.INK)
	logo.add_theme_constant_override("shadow_offset_x", 10)
	logo.add_theme_constant_override("shadow_offset_y", 10)
	logo.add_theme_constant_override("shadow_outline_size", 14)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_holder.add_child(logo)
	var subtitle := Label.new()
	subtitle.text = "EEN ZWERFTOCHT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(DESIGN_SIZE.x, 40)
	subtitle.position = Vector2(0, DESIGN_SIZE.y * 0.5 + 130)
	subtitle.add_theme_font_override("font", UiStyle.spaced(UiStyle.font(UiStyle.FONT_PIXEL), 8))
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", UiStyle.ACCENT)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_holder.add_child(subtitle)


## The story: drawn into a picture of its own (crawl_picture, a SubViewport) in amber, a
## paragraph per entry; a shader lays that picture on the screen as a plane going away
## from the viewer: the bottom edge the width of the screen, the far top edge
## CRAWL_FAR_WIDTH of it, the rows squeezed with distance as perspective does, fading out
## far off.
const CRAWL_SHADER := """shader_type canvas_item;
uniform sampler2D crawl : filter_linear, repeat_disable;
uniform float far_width = 0.22;
uniform float screen_top = 0.08;

void fragment() {
	// 0 at the far top edge of the plane, 1 at the bottom of the screen
	float down = clamp((UV.y - screen_top) / (1.0 - screen_top), 0.0, 1.0);
	float row_width = mix(far_width, 1.0, down);
	float across = (UV.x - 0.5) / row_width + 0.5;
	// distance along the plane: 1 / width, from 1 at the bottom to 1 / far_width far off
	float depth = (1.0 / row_width - 1.0) / (1.0 / far_width - 1.0);
	vec2 picture_uv = vec2(across, 1.0 - depth);
	vec4 text = texture(crawl, picture_uv);
	float inside = step(0.0, across) * step(across, 1.0) * step(screen_top, UV.y);
	float fade = smoothstep(0.0, 0.35, down);
	COLOR = vec4(text.rgb, text.a * inside * fade);
}
"""


func _build_crawl() -> void:
	var picture := SubViewport.new()
	picture.name = "Verhaalbeeld"
	picture.size = CRAWL_PICTURE
	picture.transparent_bg = true
	picture.disable_3d = true
	picture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(picture)
	_crawl_text = VBoxContainer.new()
	_crawl_text.add_theme_constant_override("separation", PARAGRAPH_GAP)
	_crawl_text.size = Vector2(CRAWL_PICTURE.x, 0)
	_crawl_text.position = Vector2(0, CRAWL_PICTURE.y)
	picture.add_child(_crawl_text)
	var font := _font(UiStyle.FONT_TITLE, 700)
	for paragraph: String in STORY:
		var label := Label.new()
		label.text = paragraph
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(CRAWL_PICTURE.x, 0)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 46)
		label.add_theme_color_override("font_color", UiStyle.ACCENT)
		label.add_theme_constant_override("line_spacing", 4)
		_crawl_text.add_child(label)
	_crawl_screen = ColorRect.new()
	_crawl_screen.name = "Verhaal"
	_crawl_screen.size = DESIGN_SIZE
	_crawl_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crawl_screen.visible = false
	var shader := Shader.new()
	shader.code = CRAWL_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("crawl", picture.get_texture())
	material.set_shader_parameter("far_width", CRAWL_FAR_WIDTH)
	material.set_shader_parameter("screen_top", CRAWL_SCREEN_TOP)
	_crawl_screen.material = material
	_design.add_child(_crawl_screen)


## Bottom left, the context action of the game (ActionPrompts): SPATIE skips. Bottom right,
## as the footer of the main menu, the secondary action in small pixel text: once the story
## rolls, "[ENTER] SNELLER". Both PROMPT_MARGIN px in from the side and up from the bottom.
const PROMPT_MARGIN := 48
const SKIP_ACTION := ["SPATIE", "Overslaan"]
const FAST_TEXT := "[ENTER] SNELLER"
const FOOTER_COLOUR := Color("#C9CCE6")


func _build_prompts() -> void:
	_prompts = ActionPrompts.new()
	_prompts.name = "Toetsen"
	_prompts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_prompts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompts.offset_left = PROMPT_MARGIN
	_prompts.offset_bottom = -PROMPT_MARGIN
	_design.add_child(_prompts)
	_prompts.set_actions([SKIP_ACTION])
	_fast_footer = Label.new()
	_fast_footer.name = "Sneller"
	_fast_footer.text = FAST_TEXT
	_fast_footer.add_theme_font_override("font", UiStyle.font(UiStyle.FONT_PIXEL))
	_fast_footer.add_theme_font_size_override("font_size", 11)
	_fast_footer.add_theme_color_override("font_color", FOOTER_COLOUR)
	_fast_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fast_footer.size = Vector2(600, 16)
	_fast_footer.position = Vector2(DESIGN_SIZE.x - PROMPT_MARGIN - 600, DESIGN_SIZE.y - PROMPT_MARGIN)
	_fast_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fast_footer.visible = false
	_design.add_child(_fast_footer)


## The secondary action shows while the story rolls (`time`: seconds into the music).
func _update_prompts(time: float) -> void:
	if _fast_footer:
		_fast_footer.visible = time >= CRAWL_AT and time < END_AT


## What drifts: a small 3D world of its own (a camera, a sun and some ambient light, the
## character or tractor tumbling in the middle) drawn into a picture with a clear background,
## laid over the stars and under the story, pixel-sharp like the rest.
func _build_drifter() -> void:
	_drifter_random.randomize()
	_drifter_picture = SubViewport.new()
	_drifter_picture.name = "Trekkerbeeld"
	_drifter_picture.size = Vector2i(DRIFTER_PICTURE, DRIFTER_PICTURE)
	_drifter_picture.transparent_bg = true
	_drifter_picture.own_world_3d = true
	_drifter_picture.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_drifter_picture)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 8.5)   # room for the flag as it tumbles
	camera.fov = 40.0
	_drifter_picture.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	sun.light_energy = 1.2
	_drifter_picture.add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.8)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_drifter_picture.add_child(world_environment)
	_drifter_spinner = Node3D.new()
	_drifter_picture.add_child(_drifter_spinner)
	_drifter_view = TextureRect.new()
	_drifter_view.name = "Trekker"
	_drifter_view.texture = _drifter_picture.get_texture()
	_drifter_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drifter_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drifter_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drifter_view.visible = false
	_design.add_child(_drifter_view)


## A tractor of model `model_name` (assets/tiles/props/voertuigen) with its wheels and the
## upside-down protest flag, as scripts/vehicles/tractor.gd puts them (the hubs, the big rear and small front wheels),
## its middle at the origin; null if the model is missing.
static func _make_tractor(model_name: String) -> Node3D:
	var body_path := "res://assets/tiles/props/voertuigen/%s.gox" % model_name
	if not ResourceLoader.exists(body_path):
		return null
	var tractor := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = load(body_path)
	body.position = Vector3(0.0, 0.25, 0.0)   # model_lift of the tractor
	tractor.add_child(body)
	# [hub, wheel model, radius]: the small front wheels, the big rear ones
	var wheels := [
		[Vector3(-0.5625, 0.375, 1.25), "auto_wiel", 0.375], [Vector3(0.5625, 0.375, 1.25), "auto_wiel", 0.375],
		[Vector3(-0.75, 0.625, -0.875), "tractor_wiel", 0.625], [Vector3(0.75, 0.625, -0.875), "tractor_wiel", 0.625]]
	for wheel: Array in wheels:
		var wheel_path := "res://assets/tiles/props/voertuigen/%s.gox" % wheel[1]
		if not ResourceLoader.exists(wheel_path):
			continue
		var wheel_instance := MeshInstance3D.new()
		wheel_instance.mesh = load(wheel_path)
		# the wheel meshes stand on their lowest point, round the axle
		wheel_instance.position = (wheel[0] as Vector3) - Vector3(0.0, float(wheel[2]), 0.0)
		tractor.add_child(wheel_instance)
	# the upside-down flag of the protesting farmers on the cab roof, as in the menu
	tractor.add_child(ProtestFlag.new())
	# its middle (about 1.4 m up) at the origin, so it tumbles round itself
	var holder := Node3D.new()
	tractor.position = Vector3(0.0, -1.4, 0.0)
	holder.add_child(tractor)
	return holder


## The next one to drift: a character with CHARACTER_CHANCE, else a tractor; not the last one.
func _pick_drifter() -> String:
	var choices: Array = PlayerCharacter.ORDER if _drifter_random.randf() < CHARACTER_CHANCE else TRACTOR_MODELS
	var others := choices.filter(func(choice: String) -> bool: return choice != _last_drifter)
	return others[_drifter_random.randi() % others.size()]


## One of the characters (`archetype_id`) as the game draws them (PlayerModel), bigger
## (CHARACTER_SCALE), flailing its arms and legs as if it swims through space.
static func _make_character(archetype_id: String) -> Node3D:
	var holder := Node3D.new()
	var figure := PlayerModel.new()
	figure.archetype_id = archetype_id
	figure.idle = true
	figure.walking = 1.0
	figure.scale = Vector3.ONE * CHARACTER_SCALE
	holder.add_child(figure)
	return holder


## Its middle at the origin, so it tumbles round itself (its height is known once it is built).
static func _centre_character(holder: Node3D) -> void:
	var figure := holder.get_child(0) as Node3D
	figure.position = Vector3(0.0, -figure.call("height") * 0.5 * CHARACTER_SCALE, 0.0)


## Starts something drifting across now and then, and moves the one under way: in a
## straight line from one side of the screen to the other (a little up or down), smaller
## or bigger as it is further or nearer, tumbling round an axis of its own.
func _fly_drifter() -> void:
	if _drifter_view == null or not _stars.visible:
		return
	if _drifter_flight.is_empty():
		if _clock < _next_drifter_at or _clock > END_AT - 6.0:
			return
		var drifter_name := _pick_drifter()
		if _drifter_model:
			_drifter_model.queue_free()
		_drifter_model = _make_character(drifter_name) if PlayerCharacter.ARCHETYPES.has(drifter_name) \
			else _make_tractor(drifter_name)
		if _drifter_model == null:
			_next_drifter_at = INF
			return
		_last_drifter = drifter_name
		_drifter_spinner.add_child(_drifter_model)
		if PlayerCharacter.ARCHETYPES.has(drifter_name):
			_centre_character(_drifter_model)
		var shown := DRIFTER_SIZE * _drifter_random.randf_range(0.45, 1.0)
		var from_left := _drifter_random.randf() < 0.5
		var start_height := _drifter_random.randf_range(0.1, 0.75) * DESIGN_SIZE.y
		var end_height := clampf(start_height + _drifter_random.randf_range(-160.0, 160.0), 0.0, DESIGN_SIZE.y - shown)
		var left := Vector2(-shown, start_height)
		var right := Vector2(DESIGN_SIZE.x, end_height)
		_drifter_flight = {
			"from": left if from_left else right,
			"to": right if from_left else left,
			"start": _clock,
			"seconds": _drifter_random.randf_range(DRIFTER_SECONDS.x, DRIFTER_SECONDS.y),
			"axis": Vector3(_drifter_random.randf_range(-1.0, 1.0), _drifter_random.randf_range(-1.0, 1.0), _drifter_random.randf_range(-0.5, 0.5)).normalized(),
			"spin": deg_to_rad(_drifter_random.randf_range(18.0, 45.0)) * (1.0 if _drifter_random.randf() < 0.5 else -1.0),
		}
		_drifter_spinner.basis = Basis.from_euler(Vector3(_drifter_random.randf_range(0.0, TAU), _drifter_random.randf_range(0.0, TAU), 0.0))
		_drifter_view.size = Vector2.ONE * shown
		# the nearer ones (bigger) a little brighter, the far ones dimmer
		_drifter_view.modulate = Color(1, 1, 1).lerp(Color(0.55, 0.6, 0.75), 1.0 - shown / DRIFTER_SIZE)
		_drifter_picture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_drifter_view.visible = true
	var flown := (_clock - float(_drifter_flight.start)) / float(_drifter_flight.seconds)
	if flown >= 1.0:
		_drifter_flight = {}
		_drifter_view.visible = false
		_drifter_picture.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_next_drifter_at = _clock + _drifter_random.randf_range(DRIFTER_EVERY.x, DRIFTER_EVERY.y)
		return
	_drifter_view.position = (_drifter_flight.from as Vector2).lerp(_drifter_flight.to as Vector2, flown)
	_drifter_spinner.basis = Basis(_drifter_flight.axis as Vector3, float(_drifter_flight.spin) * get_process_delta_time()) * _drifter_spinner.basis


## The font at `path` (Rubik when it is missing) at this weight.
static func _font(path: String, weight: int) -> Font:
	return UiStyle.weighted(UiStyle.font(path), weight)


func _fit_to_window() -> void:
	var window := get_viewport().get_visible_rect().size
	var factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	_design.scale = Vector2(factor, factor)
	_design.position = (window - DESIGN_SIZE * factor) * 0.5
