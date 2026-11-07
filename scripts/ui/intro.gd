class_name Intro
extends Control
const UiSounds = preload("res://scripts/ui/ui_sounds.gd")

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
## It all goes by the music (assets/audio/muziek/intro.mp3, MUSIC): the clock of the intro is where
## the music is, and the moments are set on its beats (CUES, measured in the mp3): the logo
## comes on its first big entry, paragraphs of the story enter at its turns (CRAWL_CUES),
## and the intro ends where it fades. Without the music a clock of its own does the same.
## The space bar (only that: not other keys, the mouse or the volume keys) breaks it off at
## any moment and goes to the main menu; bottom left a prompt says so ("SPATIE  Intro
## overslaan"). The stars twinkle.
## The CRT look of the HUD lies over it (GameHud.make_crt_overlay, with the settings of the
## main menu).

const MENU_SCENE := "res://scenes/hoofdmenu.tscn"
## The music of the intro, its volume (dB), and the seconds it fades out in when the intro
## ends or is broken off.
const MUSIC := "res://assets/audio/muziek/intro.mp3"
const MUSIC_VOLUME_DB := -4.0
const MUSIC_FADE_OUT := 2.0
## Seconds the picture fades to black on the way to the menu.
const FADE_TO_MENU := 1.4
const DESIGN_SIZE := Vector2(1280, 720)
const OPENING_LINE := "Niet zo lang geleden, kortgeleden, recent en laatst…"
## The story that rolls away after the logo, a paragraph per entry (each a sentence of its
## own; the lines wrap by themselves).
const STORY := [
	"Den Haag, een stad achter de duinen, waar de zee 's nachts komt luisteren aan de deuren van de macht.",
	"Vies, lelijk en ambtelijk: de stad van de gele hesjes, die in de mist branden als verdwaalde zonnen.",
	"Een centrum zo klein dat het past in één zucht, en toch mooier dan Zoetermeer ooit zal dromen.",
	"Hier staat de wind altijd tegen, welke kant je ook op fietst; hij kent je naam en fluistert hem verkeerd.",
	"Meeuwen cirkelen boven het Plein als ministers zonder portefeuille, en de ministers cirkelen eronder als meeuwen.",
	"Het Binnenhof slaapt al jaren onder zijn steigers, en de steigers dromen inmiddels dat zij het Binnenhof zijn.",
	"De tram komt nooit op tijd, behalve als jij te laat bent: dan is hij al vertrokken, als een herinnering.",
	"In de Hofvijver drijft een eend die zweert dat hij ooit staatssecretaris was, en niemand durft hem tegen te spreken.",
	"Parkeren kost er meer dan een leven in Zoetermeer, en op Scheveningen draag je in juli een jas tegen de zomer.",
	"Hier zijn de dagen grijs als oud papier, de kroketten heet als beloften en de vergaderingen eeuwig als de zee.",
	"Op de Grote Markt drinken werkloze kunstacademiestudenten speciaalbier in de schemering, en noemen hun dorst een installatie.",
	"Ambtenaren dragen hun dossiers als heilige boeken van de vergadering naar de lunch en weer terug, en dat heet daar werk.",
	"Op het Malieveld staat altijd iets: een kermis, een circus, of een boze menigte die vergeten is waartegen.",
	"Op zondag stromen de supporters zingend door de straten, en de tokkies op de stoep zingen mee, zonder te weten waarom, met heel hun hart.",
	"En als het jaar verbrandt, staat op Scheveningen een toren van pallets in vuur, zo hoog dat de sterren er even van schrikken.",
	"Daar leefde eens een zwerver, van dag tot dag, en soms, als het meezat, van dag tot middag.",
	"Zijn adres was een bankje aan het Malieveld, zijn tweede huis de wachtkamer van Centraal, zijn zomerhuis een portiek aan het Spui.",
	"Hij kende elke duif bij naam, en de duiven kenden hem nog beter: zij wisten waar zijn korsten sliepen.",
	"Hij sprak met lantaarnpalen, want die bleven tenminste staan als hij iets zei, en gaven licht als hij zweeg.",
	"Maar niets haatte hij zo hartgrondig als het draaiorgel: elke zaterdag datzelfde deuntje, en een man met een bakje centen die rammelt tot je betaalt voor de stilte.",
	"Of de boeren die het Malieveld kwamen bezetten met hun tractoren, toeterend, hooi in het haar, een spandoek tegen alles, ook tegen spandoeken.",
	"Of de fatbikes, die geluidloos achter hem opdoken op de stoep, haaien op wielen, met een jongen van twaalf erop die nooit remt.",
	"Hij had geen huis, geen haast en geen OV-chipkaart, maar wel een winkelwagen van de DERREK, een halve kroket en een plattegrond van een stad die niet meer bestaat.",
	"In die wagen lag zijn hele wereld: een paraplu zonder doek, een radio die alleen het weer van gisteren ontving, en een foto van de zee.",
	"Want de zee, zei hij, is het enige in Den Haag dat nooit een vergunning heeft aangevraagd.",
	"Op een ochtend, overprikkeld door de toeters, hongerig naar een broodje bal en moe van de regen die van opzij komt, ontwaakt hij op Centraal Station.",
	"De klok in de hal wijst een uur aan dat niemand ooit heeft geleefd.",
	"Waar ben ik nu?\nWaar ga ik heen?",
	"De meeuwen weten het niet. De tram weet het niet. Zelfs het ministerie heeft er nog geen standpunt over ingenomen.",
	"Maar ergens tussen de duinen en de stoeptegels ligt een dag te wachten die nog niemand heeft gebruikt.",
	"De stad wacht niet op hem. Toch gaat hij op weg: met zijn winkelwagen, zijn halve kroket en het beetje trots dat hem nog rest.",
	"Dit is het verhaal van zijn zwerftocht door Den Haag.",
]
## The moments of the intro (seconds into intro.mp3, which is 177 s: the theme begins at
## 1.1, its first big entry at 15.8, a second at 63.9, a near silence 109.8-111.4, the calm
## end from 142.2, fading out from 172.5): the opening line fading in and out, the logo,
## the start of the crawl, the end of the crawl and of the intro.
const LINE_IN_AT := 1.1
const LINE_OUT_AT := 4.4    # gone at 5.6, before the logo fades in
## The logo and the stars fade in from LOGO_FADE_IN_AT, stand there whole from LOGO_AT, and
## the logo stands big (LOGO_HOLD) until the music's first big entry (16.0): there it starts
## to go away and the story comes in.
const LOGO_FADE_IN_AT := 6.0
const LINE_FADE := 1.2
const LOGO_AT := 8.0
const CRAWL_AT := 16.0
## The story rolls to END_AT (where the music fades): the last paragraph does not roll off
## the top but comes to rest far off at CRAWL_REST (share of the picture's height from the
## top) and the story fades out over the last CRAWL_FADE seconds; no travel wasted, so it
## rolls as slowly as the music allows.
const END_AT := 172.5
const CRAWL_REST := 0.35
const CRAWL_FADE := 4.0
## Pixels between the paragraphs of the story (in its picture).
const PARAGRAPH_GAP := 26
## Paragraphs of STORY and the moment each comes in at the bottom of the screen: the
## zwerver on the second big entry, his questions right after the silence, the last
## sentence on the calm end. Between them the story rolls evenly.
const CRAWL_CUES := {15: 63.9, 27: 111.5, 31: 142.2}
## The crawl picture: the size the text is drawn in (pixels), the
## width of its far top edge on the screen (share of the bottom edge) and how much of the
## screen it takes from the bottom up.
const CRAWL_PICTURE := Vector2i(900, 1400)
const CRAWL_FAR_WIDTH := 0.22
const CRAWL_SCREEN_TOP := 0.08
const TITLE := "ZWERVR"
## Seconds the logo stands big before it goes, and that it takes to go away.
const LOGO_HOLD := 8.0
const LOGO_SECONDS := 2.5
## The logo: its size at the start (1.3: big, about nine tenths of the width of the screen)
## and at the end, far off.
const LOGO_START_SCALE := 1.3
## Its size as it comes in (nearly past the edges of the screen), shrinking slowly to
## LOGO_START_SCALE until it starts to go.
const LOGO_HUGE_SCALE := 5.0
const LOGO_END_SCALE := 0.02
const STAR_COUNT := 140

var _design: Control
var _line: Label
var _stars: Control
var _logo_holder: Control
var _crawl_text: VBoxContainer   # the story in its picture, rolled up by _play
var _crawl_screen: ColorRect     # that picture laid on the screen in perspective
var _leaving := false
var _plopped := false   # the plop of the vanishing logo has sounded
var _music: AudioStreamPlayer
var _twinkles: Array[Vector3] = []   # per star: pace (rad/s), phase, how deep it dims
var _clock := 0.0
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
	_build_crawl()
	_build_skip_hint()
	var settings := MainMenu._read_settings()
	var crt := GameHud.make_crt_overlay(0.05 if settings.crt else 0.0, 0.035 if settings.crt else 0.0,
			0.1 if settings.scanlines else 0.0, get_viewport().get_visible_rect().size)
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
		_play(_music_time())
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
	_crawl_screen.visible = time >= CRAWL_AT and time < END_AT
	if _crawl_screen.visible:
		_crawl_text.position.y = _crawl_position(time)
		_crawl_screen.modulate.a = clampf((END_AT - time) / CRAWL_FADE, 0.0, 1.0)
	# a plop as the logo vanishes in the distance
	if not _plopped and time >= LOGO_AT + LOGO_HOLD + LOGO_SECONDS * 0.92:
		_plopped = true
		if time < LOGO_AT + LOGO_HOLD + LOGO_SECONDS + 0.5:
			UiSounds.play(self, "plop")
	if time >= END_AT:
		_to_menu()


## Where the story stands at `time`: rolled evenly between the cues, each cue a paragraph
## of STORY coming in at the bottom of the picture (its top there), from the whole text
## under the picture at CRAWL_AT to the last paragraph at rest far off (CRAWL_REST) at END_AT.
func _crawl_position(time: float) -> float:
	var stops: Array = [[CRAWL_AT, float(CRAWL_PICTURE.y)]]
	var paragraphs := _crawl_text.get_children()
	var cue_paragraphs := CRAWL_CUES.keys()
	cue_paragraphs.sort()
	for paragraph_index: int in cue_paragraphs:
		if paragraph_index < paragraphs.size():
			var paragraph_top: float = (paragraphs[paragraph_index] as Control).position.y
			stops.append([CRAWL_CUES[paragraph_index], CRAWL_PICTURE.y - paragraph_top])
	stops.append([END_AT, CRAWL_PICTURE.y * CRAWL_REST - _crawl_text.size.y])
	for stop_index in range(1, stops.size()):
		var earlier: Array = stops[stop_index - 1]
		var later: Array = stops[stop_index]
		if time <= later[0]:
			return lerpf(earlier[1], later[1], clampf((time - earlier[0]) / (later[0] - earlier[0]), 0.0, 1.0))
	return -_crawl_text.size.y


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
	# the picture fades to black (the menu comes up out of it), the tape losing its tracking
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	move_child(black, get_child_count() - 2)   # under the CRT overlay, over the rest
	var out := create_tween().set_parallel(true)
	out.tween_property(black, "modulate:a", 1.0, FADE_TO_MENU)
	var crt := get_child(get_child_count() - 1) as CanvasItem
	if crt and crt.material is ShaderMaterial:
		var material := crt.material as ShaderMaterial
		out.tween_method(func(amount: float) -> void: material.set_shader_parameter("tracking", amount), 0.0, 0.7, FADE_TO_MENU)
	await out.finished
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
		stream = AudioStreamMP3.load_from_file(MUSIC)
	if stream == null:
		push_warning("intro: no music at %s" % MUSIC)
		return
	_music = AudioStreamPlayer.new()
	_music.name = "Muziek"
	_music.stream = stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()


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
	_line.size = DESIGN_SIZE
	_line.add_theme_font_override("font", _font("res://assets/fonts/PixelifySans.ttf", 500))
	_line.add_theme_font_size_override("font_size", 30)
	_line.add_theme_color_override("font_color", GameHud.SIDE_ACCENT)
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
	logo.add_theme_font_override("font", GameHud._spaced(_font("res://assets/fonts/PixelifySans.ttf", 700), 8))
	logo.add_theme_font_size_override("font_size", 230)
	logo.add_theme_color_override("font_color", Color.BLACK)
	logo.add_theme_color_override("font_outline_color", GameHud.ACCENT)
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", GameHud.INK)
	logo.add_theme_constant_override("shadow_offset_x", 10)
	logo.add_theme_constant_override("shadow_offset_y", 10)
	logo.add_theme_constant_override("shadow_outline_size", 14)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_holder.add_child(logo)
	var subtitle := Label.new()
	subtitle.text = "EEN HAAGSE ZWERFTOCHT"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(DESIGN_SIZE.x, 40)
	subtitle.position = Vector2(0, DESIGN_SIZE.y * 0.5 + 130)
	subtitle.add_theme_font_override("font", GameHud._spaced(load("res://assets/fonts/Silkscreen-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/Silkscreen-Regular.ttf") else _fallback(), 8))
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", GameHud.ACCENT)
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
	var font := _font("res://assets/fonts/PixelifySans.ttf", 700)
	for paragraph: String in STORY:
		var label := Label.new()
		label.text = paragraph
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(CRAWL_PICTURE.x, 0)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 46)
		label.add_theme_color_override("font_color", GameHud.ACCENT)
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


## Bottom left, as the action prompt of the design: a key cap and "Intro overslaan" on an
## ink panel with a border (any key, click or touch skips; this says so).
func _build_skip_hint() -> void:
	var panel := PanelContainer.new()
	var style := GameHud._box_style(GameHud.TRANSLUCENT_INK, GameHud.BORDER, 2)
	style.content_margin_left = 10
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var key := PanelContainer.new()
	var key_style := GameHud._box_style(GameHud.TEXT, GameHud.TEXT, 0)
	key_style.content_margin_left = 8
	key_style.content_margin_right = 8
	key_style.content_margin_top = 4
	key_style.content_margin_bottom = 4
	key_style.shadow_color = GameHud.MUTED
	key_style.shadow_offset = Vector2(0, 3)
	key.add_theme_stylebox_override("panel", key_style)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_label := Label.new()
	key_label.text = "SPATIE"
	key_label.add_theme_font_override("font", _font_or_fallback("res://assets/fonts/Silkscreen-Bold.ttf"))
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_color", GameHud.INK)
	key.add_child(key_label)
	row.add_child(key)
	var text := Label.new()
	text.text = "Intro overslaan"
	text.add_theme_font_override("font", _font("res://assets/fonts/JetBrainsMono.ttf", 400))
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_color", GameHud.TEXT)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	# bottom left of the design (24 px in, 28 px up), whatever size the panel takes: a
	# margin container the size of the design with the panel at its end
	var corner := MarginContainer.new()
	corner.size = DESIGN_SIZE
	corner.add_theme_constant_override("margin_left", 24)
	corner.add_theme_constant_override("margin_bottom", 28)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	corner.add_child(panel)
	_design.add_child(corner)


static func _font_or_fallback(path: String) -> Font:
	return load(path) if ResourceLoader.exists(path) else _fallback()


static func _font(path: String, weight: int) -> Font:
	var font: Font = load(path) if ResourceLoader.exists(path) else _fallback()
	return GameHud._weighted(font, weight)


static func _fallback() -> Font:
	return load("res://assets/fonts/Rubik.ttf")


func _fit_to_window() -> void:
	var window := get_viewport().get_visible_rect().size
	var factor := minf(window.x / DESIGN_SIZE.x, window.y / DESIGN_SIZE.y)
	_design.scale = Vector2(factor, factor)
	_design.position = (window - DESIGN_SIZE * factor) * 0.5
