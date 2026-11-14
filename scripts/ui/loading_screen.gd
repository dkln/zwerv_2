extends CanvasLayer
## Full-screen loading screen in the style of the HUD (ink blue, pixel fonts, a bordered
## panel): the title, the loading text ("— STAD LADEN —") and a segmented bar with the
## percentage, under the CRT look of the HUD (with the HUD's settings when there is one).
## Shown by the DetailNiveau (scripts/world/town/level_of_detail.gd) while it merges the map.
## Waiting music under it (MUSIC: laden_loop.ogg, made from the composition by tools/muziek/), fading in when
## it opens and out when it goes; meanwhile nothing else of the town is heard (GROUP).
## This is the behaviour layer: up or gone (the group), the waiting music, how far it is,
## fading out and freeing itself. screens/loading_screen_rules.gd has the logic (the texts,
## the setting it takes of the HUD), screens/loading_screen_layout.gd the sizes,
## screens/loading_screen_view.gd builds the screen and shows what it is handed.
##   var screen := LoadingScreen.new()
##   screen.text = "Stad laden…"
##   screen.hud = get_node_or_null("../HUD")
##   add_child(screen)
##   screen.set_progress(0.5)
##   screen.fade_out()   # and it frees itself

const LoadingScreenRules = preload("res://scripts/ui/screens/loading_screen_rules.gd")
const LoadingScreenLayout = preload("res://scripts/ui/screens/loading_screen_layout.gd")
const LoadingScreenView = preload("res://scripts/ui/screens/loading_screen_view.gd")
const MusicFade = preload("res://scripts/audio/music_fade.gd")
## The numbers and the title of the layers, here for whoever has the screen at hand.
const SEGMENTS := LoadingScreenLayout.SEGMENTS
const TITLE := LoadingScreenRules.TITLE
const FADE_SECONDS := LoadingScreenView.FADE_SECONDS
const MUSIC := "res://assets/audio/muziek/laden_loop.ogg"
## While a loading screen is up (this group) only its waiting music plays: the sounds of the
## town (RuimtelijkGeluid, scripts/audio/spatial_audio.gd) and its music (the HUD) wait.
const GROUP := "laadscherm"
const MUSIC_VOLUME_DB := -6.0   # in and out as MusicFade does it

## What is loading (shown in capitals, without the ellipsis).
var text := "Stad laden…"
## The HUD whose CRT settings it copies (crt_curvature, crt_corner), if any.
var hud: Node

var _view: LoadingScreenView
var _music: AudioStreamPlayer


## True while a loading screen is up (or fading out).
static func showing(tree: SceneTree) -> bool:
	return tree != null and tree.get_first_node_in_group(GROUP) != null


func _ready() -> void:
	add_to_group(GROUP)
	layer = LoadingScreenLayout.LAYER
	_start_music()
	_view = LoadingScreenView.new(TITLE, LoadingScreenRules.heading(text),
		_hud_setting("crt_curvature", LoadingScreenView.CRT_CURVATURE), _hud_setting("crt_corner", LoadingScreenView.CRT_CORNER),
		get_viewport().get_visible_rect().size)
	add_child(_view)


## Shows how far it is (0..1) on the bar and as a percentage.
func set_progress(share_done: float) -> void:
	if _view == null:
		return
	_view.show_progress(share_done, LoadingScreenRules.percentage_text(share_done))


## Fades the screen out and frees it.
func fade_out() -> void:
	var tween := _view.fade_out()
	if _music:
		MusicFade.fade_out(_music)   # into the city's music (MusicFade)
		_music = null
	tween.chain().tween_callback(queue_free)


## What the screen looks like (the view; null before it is in the tree), for whoever looks
## at what is shown.
func view() -> LoadingScreenView:
	return _view


## The waiting music, looping, fading in (nothing without the file).
func _start_music() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(MUSIC):
		stream = load(MUSIC)
	elif FileAccess.file_exists(MUSIC):
		stream = AudioStreamOggVorbis.load_from_file(MUSIC)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music = AudioStreamPlayer.new()
	_music.name = "Wachtmuziek"
	_music.stream = stream
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)
	MusicFade.fade_in(_music, MUSIC_VOLUME_DB)   # as the character choice's goes out


## A setting of the HUD, or `default` without a HUD (or without that setting).
func _hud_setting(setting: String, default: float) -> float:
	return LoadingScreenRules.setting(hud.get(setting) if hud else null, default)
