extends CanvasLayer
## Full-screen loading screen in the style of the HUD (ink blue, pixel fonts, a bordered
## panel): the title, the loading text ("— STAD LADEN —") and a segmented bar with the
## percentage, under the CRT look of the HUD (with the HUD's settings when there is one).
## Shown by the DetailNiveau (scripts/world/town/level_of_detail.gd) while it merges the map.
## Waiting music under it (MUSIC: laden_loop.ogg, made from the composition by tools/muziek/), fading in when
## it opens and out when it goes; meanwhile nothing else of the town is heard (GROUP).
##   var screen := LoadingScreen.new()
##   screen.text = "Stad laden…"
##   screen.hud = get_node_or_null("../HUD")
##   add_child(screen)
##   screen.set_progress(0.5)
##   screen.fade_out()   # and it frees itself

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const SegmentBar = preload("res://scripts/ui/widgets/segment_bar.gd")
## Segments of the progress bar, and the title over it.
const SEGMENTS := 30
const TITLE := "ZWERVR"
## Seconds of the fade when it is done.
const FADE_SECONDS := 0.35
const MUSIC := "res://assets/audio/muziek/laden_loop.ogg"
const MusicFade = preload("res://scripts/audio/music_fade.gd")
## While a loading screen is up (this group) only its waiting music plays: the sounds of the
## town (RuimtelijkGeluid, scripts/audio/spatial_audio.gd) and its music (the HUD) wait.
const GROUP := "laadscherm"
const MUSIC_VOLUME_DB := -6.0   # in and out as MusicFade does it

## What is loading (shown in capitals, without the ellipsis).
var text := "Stad laden…"
## The HUD whose CRT settings it copies (crt_curvature, crt_corner), if any.
var hud: Node

var _panel: ColorRect
var _percentage: Label
var _bar: SegmentBar
var _crt: ColorRect
var _music: AudioStreamPlayer


## True while a loading screen is up (or fading out).
static func showing(tree: SceneTree) -> bool:
	return tree != null and tree.get_first_node_in_group(GROUP) != null


func _ready() -> void:
	add_to_group(GROUP)
	layer = 100
	_start_music()
	_panel = ColorRect.new()
	_panel.color = UiStyle.INK
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_child(column)
	column.add_child(_label(TITLE, UiStyle.FONT_TITLE, 56, UiStyle.TEXT, 4))
	column.add_child(_label("— " + text.trim_suffix("…").to_upper() + " —", UiStyle.FONT_PIXEL, 14, UiStyle.ACCENT, 2))
	# the bar on a panel with a border, the percentage beside it
	var box := PanelContainer.new()
	var style := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, 3)
	style.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_bar = SegmentBar.new()
	_bar.segments = SEGMENTS
	_bar.segment_height = 14
	_bar.full_colour = UiStyle.ACCENT
	_bar.empty_colour = UiStyle.INK.lightened(0.08)
	_bar.fill = 0.0
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	_percentage = _label("0%", UiStyle.FONT_PIXEL, 14, UiStyle.TEXT, 2)
	_percentage.custom_minimum_size = Vector2(48, 0)
	_percentage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_percentage)
	column.add_child(box)
	var curvature: float = _hud_setting("crt_curvature", 0.05)
	var corner: float = _hud_setting("crt_corner", 0.035)
	_crt = UiStyle.make_crt_overlay(curvature, corner, get_viewport().get_visible_rect().size)
	add_child(_crt)


## Shows how far it is (0..1) on the bar and as a percentage.
func set_progress(share_done: float) -> void:
	if _percentage == null:
		return
	_percentage.text = "%d%%" % floori(100.0 * share_done)
	_bar.fill = share_done


## Fades the screen out and frees it.
func fade_out() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)
	var crt_material := _crt.material as ShaderMaterial
	tween.tween_method(func(value: float) -> void: crt_material.set_shader_parameter("opacity", value), 1.0, 0.0, FADE_SECONDS)
	if _music:
		MusicFade.fade_out(_music)   # into the city's music (MusicFade)
		_music = null
	tween.chain().tween_callback(queue_free)


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
	if hud and hud.get(setting) != null:
		return hud.get(setting)
	return default


## A label of the loading screen: this font, size and colour, with the hard ink text
## shadow of the HUD (`shadow` pixels).
static func _label(label_text: String, font_path: String, font_size: int, colour: Color, shadow: int) -> Label:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiStyle.font(font_path))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if shadow > 0:
		UiStyle.faux_3d(label, shadow)
	return label
