extends VBoxContainer
## What the notice at the top of the HUD looks like (graphics; docs/CODE_LAGEN.md): a
## heading in small spaced capitals over a name in the big title font, centred, fading in,
## staying and fading out. It shows what notice_banner.gd hands it (show_notice) and tells
## it when the notice has gone (the `gone` of show_notice); its width comes from
## hud_layout.gd.
##   const NoticeBannerView = preload("res://scripts/ui/hud/notice_banner_view.gd")

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const HudLayout = preload("res://scripts/ui/hud/hud_layout.gd")
const FADE_IN := 0.6
const FADE_OUT := 0.9

var _heading: Label
var _name: Label
var _fade: Tween


func _init() -> void:
	name = "Beeld"
	add_theme_constant_override("separation", 4)
	size = Vector2(HudLayout.NOTICE_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonts := UiStyle.fonts()
	_heading = UiStyle.label("", UiStyle.spaced(fonts.pixel, 3), 12, UiStyle.ACCENT, 2)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_heading)
	_name = UiStyle.label("", fonts.title, 34, UiStyle.TEXT, 3)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name)


## `heading` over `text`, fading in, up for `seconds` and fading out; then `gone` is called.
## A notice still fading is cut off. Not in the tree: it only shows the texts.
func show_notice(heading: String, text: String, seconds: float, gone: Callable) -> void:
	stop()
	_heading.text = heading
	_name.text = text
	modulate.a = 0.0
	if not is_inside_tree():
		return
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_fade.tween_interval(seconds)
	_fade.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_fade.tween_callback(gone)


## Cuts the fade of the notice that is up off.
func stop() -> void:
	if _fade:
		_fade.kill()
		_fade = null


func heading_text() -> String:
	return _heading.text


func name_text() -> String:
	return _name.text
