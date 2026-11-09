extends RefCounted
## The pixel look shared by the HUD (hud.gd), the main menu, the intro, the action prompts
## and the loading screen: the palette of the design ("HUD — open world"), the fonts and
## how they are varied, the bordered panels and the CRT overlay.
##   const UiStyle = preload("res://scripts/ui/ui_style.gd")
##   label.add_theme_color_override("font_color", UiStyle.TEXT)
## Fonts: Silkscreen, Pixelify Sans and JetBrains Mono (assets/fonts, OFL); Rubik when one
## is missing.

const INK := Color("#0B0D1A")
const PANEL := Color("#141831")
const BORDER := Color("#343B70")
const TEXT := Color("#E8E6F0")
const MUTED := Color("#9AA0C8")
const ACCENT := Color("#FFB547")
const SIDE_ACCENT := Color("#47D6C2")
const TRANSLUCENT_INK := Color(11.0 / 255.0, 13.0 / 255.0, 26.0 / 255.0, 0.82)
## Pixels a hard panel shadow lies down and to the right.
const SHADOW_OFFSET := 5.0

const FONT_TITLE := "res://assets/fonts/PixelifySans.ttf"
const FONT_PIXEL := "res://assets/fonts/Silkscreen-Regular.ttf"
const FONT_PIXEL_BOLD := "res://assets/fonts/Silkscreen-Bold.ttf"
const FONT_BODY := "res://assets/fonts/JetBrainsMono.ttf"
const FONT_FALLBACK := "res://assets/fonts/Rubik.ttf"

## The CRT look (see crt.gdshader).
const CRT_SHADER := preload("res://scripts/ui/crt.gdshader")


## The font at `path`, or Rubik (FONT_FALLBACK) when it is missing.
static func font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("ui: font %s missing, using Rubik" % path)
	return load(FONT_FALLBACK)


## A variable font at this weight (100..900).
static func weighted(base_font: Font, weight: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return variation


## Extra space between letters (pixels), as letter-spacing in the design.
static func spaced(base_font: Font, spacing: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.spacing_glyph = spacing
	return variation


## A flat panel style without anti-aliasing: this background with a border of
## `border_width` pixels all round (or only on the left).
## The look of an item of a menu (main menu, pause menu): amber with a hard shadow when
## chosen, else nothing behind it; MENU_ITEM_PADDING px inside on the left and right (and
## top and bottom), chosen or not, so the text does not shift when the choice moves.
const MENU_ITEM_PADDING := Vector2(16, 4)


static func menu_item_style(on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT if on else Color(0, 0, 0, 0)
	style.shadow_color = Color.BLACK if on else Color(0, 0, 0, 0)
	style.shadow_offset = Vector2(4, 4) if on else Vector2.ZERO
	style.shadow_size = 0
	style.anti_aliasing = false
	style.content_margin_left = MENU_ITEM_PADDING.x
	style.content_margin_right = MENU_ITEM_PADDING.x
	style.content_margin_top = MENU_ITEM_PADDING.y
	style.content_margin_bottom = MENU_ITEM_PADDING.y
	return style


static func box_style(background: Color, border: Color, border_width: int, left_only := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	if left_only:
		style.border_width_left = border_width
	else:
		style.set_border_width_all(border_width)
	style.anti_aliasing = false
	return style


## A full-window CRT overlay of its own (the menu, the intro, the loading screen): the CRT
## shader with these settings, without a HUD picture over it; it bends what is drawn
## before it.
static func make_crt_overlay(curvature: float, corner: float, scanline_strength: float, screen_size: Vector2) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "CRT"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = CRT_SHADER
	material.set_shader_parameter("curvature", curvature)
	material.set_shader_parameter("ui_curvature", 0.0)
	material.set_shader_parameter("corner", corner)
	material.set_shader_parameter("scanline_strength", scanline_strength)
	material.set_shader_parameter("screen_size", screen_size)
	overlay.material = material
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	return overlay
