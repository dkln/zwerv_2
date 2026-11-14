extends RefCounted
## The pixel look shared by the HUD (hud.gd), the main menu, the intro, the action prompts
## and the loading screen: the palette of the design ("HUD — open world"), the fonts and
## how they are varied, the bordered panels and the CRT overlay.
##   const UiStyle = preload("res://scripts/ui/ui_style.gd")
##   label.add_theme_color_override("font_color", UiStyle.TEXT)
## Fonts: Silkscreen, Pixelify Sans and JetBrains Mono (assets/fonts, OFL); Rubik when one
## is missing.

## The size of the announcements on screen (the station's and the supermarkets' loudspeaker:
## station.gd, supermarket_announcer.gd): big enough to read over the town.
const ANNOUNCEMENT_FONT_SIZE := 32

const INK := Color("#0B0D1A")
const PANEL := Color("#141831")
const BORDER := Color("#343B70")
const TEXT := Color("#E8E6F0")
const MUTED := Color("#9AA0C8")
const ACCENT := Color("#FFB547")
## A chosen button, row or choice (lighter than PANEL), with an ACCENT border.
const RAISED := Color("#1C2142")
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


## OpenType features switched off in every UI font: ligatures and contextual alternates
## (JetBrains Mono turns runs of digits and signs into other shapes with them).
const FEATURES_OFF := ["liga", "clig", "calt", "dlig"]


## The font at `path` (ligatures off, FEATURES_OFF), or Rubik (FONT_FALLBACK) when it is missing.
static func font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var loaded: Font = load(path)
		if loaded is FontFile:
			var overrides := {}
			var text_server := TextServerManager.get_primary_interface()
			for feature: String in FEATURES_OFF:
				overrides[text_server.name_to_tag(feature)] = 0
			(loaded as FontFile).opentype_feature_overrides = overrides
		return loaded
	push_warning("ui: font %s missing, using Rubik" % path)
	return load(FONT_FALLBACK)


## Static weights of JetBrains Mono with their overlapping contours merged
## (tools/fonts/static_body_font.py): the fonts are drawn as MSDF, which smears the "8" of
## the variable font (two overlapping loops). Weight -> file.
const BODY_WEIGHTS := {
	400: "res://assets/fonts/JetBrainsMono-Regular.ttf",
	600: "res://assets/fonts/JetBrainsMono-SemiBold.ttf",
}


## A variable font at this weight (100..900); JetBrains Mono at a weight in BODY_WEIGHTS
## comes from its static file instead.
static func weighted(base_font: Font, weight: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = base_font
	if base_font.resource_path == FONT_BODY and BODY_WEIGHTS.has(weight) and ResourceLoader.exists(BODY_WEIGHTS[weight]):
		var static_font := load(BODY_WEIGHTS[weight]) as FontFile
		if static_font:   # not yet imported: the variable font below
			static_font.opentype_feature_overrides = (base_font as FontFile).opentype_feature_overrides
			static_font.fallbacks = base_font.fallbacks
			variation.base_font = static_font
			return variation
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return variation


## The fonts every screen is set in: {"title": Pixelify Sans bold, "title_medium": the same
## semibold, "pixel": Silkscreen, "pixel_bold": Silkscreen bold, "body": JetBrains Mono}.
## Glyphs the pixel fonts lack (→, ◆, €, ·) come from JetBrains Mono.
static func fonts() -> Dictionary:
	var fallback: Font = load(FONT_FALLBACK)
	var body := font(FONT_BODY)
	var pixel := font(FONT_PIXEL)
	var pixel_bold := font(FONT_PIXEL_BOLD)
	var title := font(FONT_TITLE)
	if body != fallback:
		var fallback_fonts: Array[Font] = [body]
		for pixel_font: Font in [pixel, pixel_bold, title]:
			if pixel_font != fallback:
				pixel_font.fallbacks = fallback_fonts
	return {"title": weighted(title, 700), "title_medium": weighted(title, 600), "pixel": pixel,
		"pixel_bold": pixel_bold, "body": weighted(body, 400)}


## A line of text as the screens write it: this font (none: the default), size and colour,
## deaf to the mouse; `shadow` > 0 gives it a hard shadow of that many pixels (faux_3d).
static func label(text: String, label_font: Font, size: int, colour := TEXT, shadow := 0) -> Label:
	var made := Label.new()
	made.text = text
	if label_font:
		made.add_theme_font_override("font", label_font)
	made.add_theme_font_size_override("font_size", size)
	made.add_theme_color_override("font_color", colour)
	if shadow > 0:
		faux_3d(made, shadow)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A panel of `size` with a border and a hard shadow `shadow` px down and to the right.
static func shadowed_panel(size: Vector2, border: Color, border_width: int, shadow := SHADOW_OFFSET) -> Control:
	var holder := Control.new()
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_rect := ColorRect.new()
	shadow_rect.color = INK
	shadow_rect.position = Vector2(shadow, shadow)
	shadow_rect.size = size
	shadow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(shadow_rect)
	var panel := Panel.new()
	panel.size = size
	panel.add_theme_stylebox_override("panel", box_style(PANEL, border, border_width))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	return holder


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


## The faux 3D of the texts of the game (no outlines round text): a copy of the text
## `pixels` straight under it, in the text's own colour FAUX_3D_DARKEN darker. For a Label
## (its "font_color") and a RichTextLabel (its "default_color"); set the colour first.
const FAUX_3D_DARKEN := 0.5


static func faux_3d(text: Control, pixels: int) -> void:
	var colour_name := "default_color" if text is RichTextLabel else "font_color"
	text.add_theme_color_override("font_shadow_color", faux_3d_colour(text.get_theme_color(colour_name)))
	text.add_theme_constant_override("shadow_offset_x", 0)
	text.add_theme_constant_override("shadow_offset_y", pixels)
	text.add_theme_constant_override("shadow_outline_size", 0)
	text.add_theme_constant_override("outline_size", 0)


## The colour of the copy under a text of `colour` (faux_3d).
static func faux_3d_colour(colour: Color) -> Color:
	return colour.darkened(FAUX_3D_DARKEN)


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
static func make_crt_overlay(curvature: float, corner: float, screen_size: Vector2) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "CRT"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = CRT_SHADER
	material.set_shader_parameter("curvature", curvature)
	material.set_shader_parameter("ui_curvature", 0.0)
	material.set_shader_parameter("corner", corner)
	material.set_shader_parameter("screen_size", screen_size)
	overlay.material = material
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	return overlay
