extends RefCounted
## Unit tests of UiStyle (scripts/ui/ui_style.gd): faux_3d (the copy under a text, straight
## down, in the text's colour half as light, no outline), the fonts (font, weighted, spaced,
## fonts), label(), the panel and menu item styles and the CRT overlay.
##   tests/run_unit_tests.sh ui_style

const UiStyle = preload("res://scripts/ui/ui_style.gd")


## The colour of the copy under a text is the text's colour half as light.
func test_the_copy_is_the_colour_half_as_light(test) -> void:
	var colour := Color("#FF5D73")
	test.check(UiStyle.faux_3d_colour(colour).is_equal_approx(colour.darkened(0.5)), "50% donkerder")


## On a Label: the copy 3 px straight down, no outline, in the text's colour darker.
func test_faux_3d_on_a_label(test) -> void:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("#E8B83A"))
	UiStyle.faux_3d(label, 3)
	test.check(label.get_theme_constant("shadow_offset_x") == 0 and label.get_theme_constant("shadow_offset_y") == 3, "recht 3 px naar beneden")
	test.check(label.get_theme_constant("outline_size") == 0 and label.get_theme_constant("shadow_outline_size") == 0, "geen rand")
	test.check(label.get_theme_color("font_shadow_color").is_equal_approx(Color("#E8B83A").darkened(0.5)), "kleur van de tekst, donkerder")
	label.free()


## The same works on a RichTextLabel.
func test_faux_3d_on_rich_text(test) -> void:
	var text := RichTextLabel.new()
	text.add_theme_color_override("default_color", Color.WHITE)
	UiStyle.faux_3d(text, 2)
	test.check(text.get_theme_color("font_shadow_color").is_equal_approx(Color.WHITE.darkened(0.5)), "ook voor RichTextLabel")
	text.free()


## A font of the UI comes with its ligatures off; a missing one is Rubik.
func test_font_loads_with_ligatures_off(test) -> void:
	var text_server := TextServerManager.get_primary_interface()
	for path: String in [UiStyle.FONT_TITLE, UiStyle.FONT_PIXEL, UiStyle.FONT_PIXEL_BOLD, UiStyle.FONT_BODY]:
		var loaded := UiStyle.font(path)
		test.check(loaded != null and loaded.resource_path == path, "%s bestaat" % path.get_file())
		var overrides: Dictionary = (loaded as FontFile).opentype_feature_overrides if loaded is FontFile else {}
		var all_off := UiStyle.FEATURES_OFF.all(func(feature: String) -> bool: return overrides.get(text_server.name_to_tag(feature), 1) == 0)
		test.check(all_off, "%s: ligaturen uit" % path.get_file())
	test.check(UiStyle.font(UiStyle.FONT_BODY) == UiStyle.font(UiStyle.FONT_BODY), "twee keer vragen: hetzelfde font")


## A weight of a variable font is a variation of it; JetBrains Mono at 400 and 600 comes
## from its static file.
func test_weighted(test) -> void:
	var title := UiStyle.font(UiStyle.FONT_TITLE)
	var bold := UiStyle.weighted(title, 700) as FontVariation
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	test.check(bold != null and bold.base_font == title, "een variatie van het font zelf")
	test.check(bold.variation_opentype.get(weight_tag) == 700, "op het gevraagde gewicht (%s)" % [bold.variation_opentype])
	var body := UiStyle.font(UiStyle.FONT_BODY)
	for weight: int in UiStyle.BODY_WEIGHTS:
		var static_path: String = UiStyle.BODY_WEIGHTS[weight]
		var weighted := UiStyle.weighted(body, weight) as FontVariation
		if ResourceLoader.exists(static_path):
			test.check(weighted.base_font.resource_path == static_path, "JetBrains Mono %d: uit zijn eigen bestand" % weight)
			test.check((weighted.base_font as FontFile).opentype_feature_overrides == (body as FontFile).opentype_feature_overrides, "%d: ook met de ligaturen uit" % weight)
		else:
			test.check(weighted.base_font == body, "JetBrains Mono %d: zonder bestand het variabele font" % weight)
	var other := UiStyle.weighted(body, 500) as FontVariation
	test.check(other.base_font == body and other.variation_opentype.get(weight_tag) == 500, "een ander gewicht: het variabele font")


func test_spaced(test) -> void:
	var pixel := UiStyle.font(UiStyle.FONT_PIXEL)
	var spaced := UiStyle.spaced(pixel, 3) as FontVariation
	test.check(spaced != null and spaced.base_font == pixel and spaced.spacing_glyph == 3, "3 px tussen de letters")
	test.check((UiStyle.spaced(pixel, 0) as FontVariation).spacing_glyph == 0, "of geen")


## fonts(): the five fonts of the screens, the pixel fonts falling back on JetBrains Mono.
func test_fonts(test) -> void:
	var fonts := UiStyle.fonts()
	test.check(fonts.keys() == ["title", "title_medium", "pixel", "pixel_bold", "body"], "de vijf fonts (%s)" % [fonts.keys()])
	for font_name: String in fonts:
		test.check(fonts[font_name] is Font, "%s is een font" % font_name)
	test.check((fonts.pixel as Font).resource_path == UiStyle.FONT_PIXEL and (fonts.pixel_bold as Font).resource_path == UiStyle.FONT_PIXEL_BOLD, "Silkscreen gewoon en vet")
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	var title := fonts.title as FontVariation
	var title_medium := fonts.title_medium as FontVariation
	test.check(title.base_font.resource_path == UiStyle.FONT_TITLE and title.variation_opentype.get(weight_tag) == 700, "de titel vet")
	test.check(title_medium.base_font.resource_path == UiStyle.FONT_TITLE and title_medium.variation_opentype.get(weight_tag) == 600, "en halfvet")
	test.check((fonts.body as FontVariation).base_font.resource_path in [UiStyle.FONT_BODY, UiStyle.BODY_WEIGHTS[400]], "de broodtekst in JetBrains Mono")
	var body := UiStyle.font(UiStyle.FONT_BODY)
	for pixel_font: Font in [fonts.pixel, fonts.pixel_bold, title.base_font]:
		test.check(pixel_font.fallbacks.has(body), "%s: tekens die het mist komen uit JetBrains Mono" % pixel_font.resource_path.get_file())
	test.check(not body.fallbacks.has(body), "JetBrains Mono valt niet op zichzelf terug")


## label(): a line of text in a font, a size and a colour, deaf to the mouse.
func test_label(test) -> void:
	var pixel := UiStyle.font(UiStyle.FONT_PIXEL)
	var plain := UiStyle.label("Hoi", pixel, 14)
	test.check(plain.text == "Hoi" and plain.get_theme_font("font") == pixel and plain.get_theme_font_size("font_size") == 14, "de tekst in zijn font en maat")
	test.check(plain.get_theme_color("font_color") == UiStyle.TEXT, "in de gewone tekstkleur als niets gezegd is")
	test.check(plain.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	test.check(not plain.has_theme_color_override("font_shadow_color"), "zonder schaduw als die niet gevraagd is")
	var shadowed := UiStyle.label("ZWERVR", pixel, 56, UiStyle.ACCENT, 4)
	test.check(shadowed.get_theme_color("font_color") == UiStyle.ACCENT, "een eigen kleur")
	test.check(shadowed.get_theme_constant("shadow_offset_y") == 4 and shadowed.get_theme_constant("shadow_offset_x") == 0, "met een schaduw van 4 px recht eronder")
	test.check(shadowed.get_theme_color("font_shadow_color").is_equal_approx(UiStyle.faux_3d_colour(UiStyle.ACCENT)), "in de kleur half zo licht")
	var default_font := UiStyle.label("Hoi", null, 12)
	test.check(not default_font.has_theme_font_override("font") and default_font.get_theme_font_size("font_size") == 12, "zonder font: het gewone, wel in de maat")
	plain.free()
	shadowed.free()
	default_font.free()


## A chosen menu item is amber with a hard shadow; the padding is the same chosen or not.
func test_menu_item_style(test) -> void:
	var chosen := UiStyle.menu_item_style(true)
	var other := UiStyle.menu_item_style(false)
	test.check(chosen.bg_color == UiStyle.ACCENT and chosen.shadow_color == Color.BLACK and chosen.shadow_offset == Vector2(4, 4), "gekozen: amber met een harde schaduw")
	test.check(other.bg_color.a == 0.0 and other.shadow_color.a == 0.0 and other.shadow_offset == Vector2.ZERO, "niet gekozen: niets erachter")
	test.check(chosen.shadow_size == 0 and not chosen.anti_aliasing and not other.anti_aliasing, "pixelhard")
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		test.check(chosen.get_content_margin(side) == other.get_content_margin(side), "kant %d: dezelfde ruimte, de tekst verschuift niet" % side)
	test.check(chosen.get_content_margin(SIDE_LEFT) == UiStyle.MENU_ITEM_PADDING.x and chosen.get_content_margin(SIDE_TOP) == UiStyle.MENU_ITEM_PADDING.y, "MENU_ITEM_PADDING")


func test_box_style(test) -> void:
	var box := UiStyle.box_style(UiStyle.PANEL, UiStyle.BORDER, 3)
	test.check(box.bg_color == UiStyle.PANEL and box.border_color == UiStyle.BORDER and not box.anti_aliasing, "een vlak paneel met een rand, pixelhard")
	test.check(box.border_width_left == 3 and box.border_width_right == 3 and box.border_width_top == 3 and box.border_width_bottom == 3, "de rand rondom")
	var left := UiStyle.box_style(UiStyle.PANEL, UiStyle.ACCENT, 4, true)
	test.check(left.border_width_left == 4 and left.border_width_right == 0 and left.border_width_top == 0 and left.border_width_bottom == 0, "of alleen links")


## shadowed_panel(): a bordered panel with an ink copy of it down and to the right, behind it.
func test_shadowed_panel(test) -> void:
	var holder := UiStyle.shadowed_panel(Vector2(200, 80), UiStyle.ACCENT, 3)
	test.check(holder.size == Vector2(200, 80) and holder.mouse_filter == Control.MOUSE_FILTER_IGNORE, "zo groot als gevraagd, klikken gaan erdoorheen")
	test.check(holder.get_child_count() == 2, "een schaduw en een paneel")
	var shadow := holder.get_child(0) as ColorRect
	var panel := holder.get_child(1) as Panel
	test.check(shadow != null and shadow.color == UiStyle.INK and shadow.size == Vector2(200, 80), "de schaduw: een inkt vlak zo groot als het paneel")
	test.check(shadow.position == Vector2(UiStyle.SHADOW_OFFSET, UiStyle.SHADOW_OFFSET), "SHADOW_OFFSET px naar rechts en omlaag")
	test.check(panel != null and panel.size == Vector2(200, 80) and panel.position == Vector2.ZERO, "het paneel ervoor, op zijn plek")
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	test.check(style.bg_color == UiStyle.PANEL and style.border_color == UiStyle.ACCENT and style.border_width_top == 3, "met de gevraagde rand")
	test.check(shadow.mouse_filter == Control.MOUSE_FILTER_IGNORE and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ook die laten klikken door")
	var further := UiStyle.shadowed_panel(Vector2(50, 50), UiStyle.BORDER, 2, 9.0)
	test.check((further.get_child(0) as Control).position == Vector2(9, 9), "een eigen afstand voor de schaduw")
	holder.free()
	further.free()


func test_make_crt_overlay(test) -> void:
	var overlay := UiStyle.make_crt_overlay(0.07, 0.04, Vector2(1280, 720))
	var material := overlay.material as ShaderMaterial
	test.check(overlay.name == "CRT" and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "een laag die klikken doorlaat")
	test.check(material != null and material.shader == UiStyle.CRT_SHADER, "met de CRT-shader")
	test.check(is_equal_approx(material.get_shader_parameter("curvature"), 0.07) and is_equal_approx(material.get_shader_parameter("corner"), 0.04), "de bolling en de hoeken")
	test.check(material.get_shader_parameter("screen_size") == Vector2(1280, 720) and material.get_shader_parameter("ui_curvature") == 0.0, "de maat van het scherm, geen eigen HUD-bolling")
	test.check(overlay.anchor_right == 1.0 and overlay.anchor_bottom == 1.0, "over het hele venster")
	var second := UiStyle.make_crt_overlay(0.0, 0.0, Vector2(640, 360))
	test.check(second.material != overlay.material, "elke laag zijn eigen instellingen")
	overlay.free()
	second.free()
