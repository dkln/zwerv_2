extends RefCounted
## Unit tests of UiStyle.faux_3d (scripts/ui/ui_style.gd): the copy under a text, straight down,
## in the text's colour half as light, no outline.

const UiStyle = preload("res://scripts/ui/ui_style.gd")


func test_the_copy_is_the_colour_half_as_light(test) -> void:
	var colour := Color("#FF5D73")
	test.check(UiStyle.faux_3d_colour(colour).is_equal_approx(colour.darkened(0.5)), "50% donkerder")


func test_faux_3d_on_a_label(test) -> void:
	var label := Label.new()
	label.add_theme_color_override("font_color", Color("#E8B83A"))
	UiStyle.faux_3d(label, 3)
	test.check(label.get_theme_constant("shadow_offset_x") == 0 and label.get_theme_constant("shadow_offset_y") == 3, "recht 3 px naar beneden")
	test.check(label.get_theme_constant("outline_size") == 0 and label.get_theme_constant("shadow_outline_size") == 0, "geen rand")
	test.check(label.get_theme_color("font_shadow_color").is_equal_approx(Color("#E8B83A").darkened(0.5)), "kleur van de tekst, donkerder")
	label.free()


func test_faux_3d_on_rich_text(test) -> void:
	var text := RichTextLabel.new()
	text.add_theme_color_override("default_color", Color.WHITE)
	UiStyle.faux_3d(text, 2)
	test.check(text.get_theme_color("font_shadow_color").is_equal_approx(Color.WHITE.darkened(0.5)), "ook voor RichTextLabel")
	text.free()
