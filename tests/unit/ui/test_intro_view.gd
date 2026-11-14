extends RefCounted
## Unit tests of how the intro looks (scripts/ui/intro/intro_view.gd): what it builds and
## what it shows when told, without the behaviour around it.
##   tests/run_unit_tests.sh intro_view

const IntroView = preload("res://scripts/ui/intro/intro_view.gd")
const IntroLayout = preload("res://scripts/ui/intro/intro_layout.gd")
const MenuLook = preload("res://scripts/ui/menu/menu_look.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _view() -> IntroView:
	var view := IntroView.new()
	tree.root.add_child(view)
	return view


func test_it_builds_the_picture_hidden(test) -> void:
	var view := _view()
	test.check(view.design().size == IntroLayout.DESIGN_SIZE, "het ontwerp op zijn maat")
	test.check(not view.stars_visible() and not view.logo().visible and not view.sparkle().visible and not view.story_screen().visible and not view.fast_footer().visible,
		"sterren, logo, twinkeling, verhaal en de regel rechtsonder nog weg")
	test.check(view.line().modulate.a == 0.0 and view.line().get_theme_color("font_color") == UiStyle.SIDE_ACCENT, "de openingszin in teal, nog onzichtbaar")
	var logo := view.logo().get_child(0) as Label
	test.check(logo.text == IntroView.TITLE and logo.get_theme_color("font_outline_color") == UiStyle.ACCENT and logo.get_theme_color("font_color") == Color.BLACK,
		"het logo: donker met een amber rand")
	test.check((view.logo().get_child(1) as Label).text == IntroView.SUBTITLE and view.logo().pivot_offset == IntroLayout.DESIGN_SIZE * 0.5, "met de ondertitel, geschaald om het midden")
	test.check(view.sparkle().get_child_count() == 5 and view.sparks().size() == IntroLayout.SPARKLE_SPARKS, "de twinkeling: vier stralen, een kern en de vonken")
	test.check(view.story_screen().material is ShaderMaterial
		and is_equal_approx((view.story_screen().material as ShaderMaterial).get_shader_parameter("far_width"), IntroLayout.CRAWL_FAR_WIDTH), "het verhaal in perspectief gelegd")
	test.check(view.prompts().name == "Toetsen" and view.crt() != null and view.crt().get_index() == view.get_child_count() - 1, "de contextactie, en het CRT-beeld over alles")
	view.free()


func test_show_star_field_and_twinkles(test) -> void:
	var view := _view()
	view.show_star_field([{"position": Vector2(10, 20), "size": Vector2(3, 3), "big": true}, {"position": Vector2(30, 40), "size": Vector2(2, 2), "big": false}])
	var stars := view.stars().get_children()
	test.check(stars.size() == 2 and (stars[0] as ColorRect).position == Vector2(10, 20) and (stars[1] as ColorRect).size == Vector2(2, 2), "een ster per opgave, op zijn plek en maat")
	test.check((stars[0] as ColorRect).color == MenuLook.STAR_BRIGHT and (stars[1] as ColorRect).color == MenuLook.STAR_DIM, "de grote helder, de kleine dof")
	view.show_twinkles([0.25, 0.75, 0.5])
	test.check(is_equal_approx((stars[0] as CanvasItem).modulate.a, 0.25) and is_equal_approx((stars[1] as CanvasItem).modulate.a, 0.75), "elke ster zo helder als gezegd (een te veel deert niet)")
	view.show_star_field([{"position": Vector2.ZERO, "size": Vector2.ONE, "big": false}])
	test.check(view.stars().get_child_count() == 1, "nieuwe sterren vervangen de oude")
	view.show_stars(true, 0.5)
	test.check(view.stars_visible() and is_equal_approx(view.stars().modulate.a, 0.5), "de sterren half opgekomen")
	view.show_stars(false, 0.0)
	test.check(not view.stars_visible(), "en weer weg")
	view.free()


func test_show_texts_and_actions(test) -> void:
	var view := _view()
	view.show_texts("Er was eens", ["Eerste alinea.", "Tweede\nalinea."])
	test.check(view.line().text == "Er was eens", "de openingszin")
	var paragraphs := view.story_text().get_children()
	test.check(paragraphs.size() == 2 and (paragraphs[1] as Label).text == "Tweede\nalinea.", "een label per alinea")
	test.check((paragraphs[0] as Label).get_theme_color("font_color") == UiStyle.ACCENT and (paragraphs[0] as Label).custom_minimum_size.x == IntroLayout.CRAWL_PICTURE.x, "in amber, zo breed als het beeld")
	view.show_texts("Opnieuw", ["Eén."])
	test.check(view.story_text().get_child_count() == 1 and view.paragraph_tops().size() == 1, "nieuwe tekst vervangt de oude")
	test.check(view.story_height() >= 0.0, "de hoogte van de tekst is op te vragen")
	view.show_actions([["SPATIE", "Overslaan"]], "[ENTER] SNELLER")
	test.check(view.prompts().actions() == [["SPATIE", "Overslaan"]] and view.fast_footer().text == "[ENTER] SNELLER", "de acties in de hoeken")
	view.show_fast_offer(true)
	test.check(view.fast_footer().visible, "de regel rechtsonder getoond")
	view.show_fast_offer(false)
	test.check(not view.fast_footer().visible, "en weer weg")
	view.free()


func test_show_line_logo_and_story(test) -> void:
	var view := _view()
	view.show_line(0.6)
	test.check(is_equal_approx(view.line().modulate.a, 0.6), "de openingszin zo ver te zien")
	view.show_logo(true, 2.5, 0.8)
	test.check(view.logo().visible and view.logo().scale == Vector2.ONE * 2.5 and is_equal_approx(view.logo().modulate.a, 0.8), "het logo op zijn maat en helderheid")
	view.show_logo(false, 9.0, 0.1)
	test.check(not view.logo().visible and view.logo().scale == Vector2.ONE * 2.5, "weg: zijn maat blijft staan")
	view.show_story_at(true, 321.0, 0.4)
	test.check(view.story_screen().visible and view.story_text().position.y == 321.0 and is_equal_approx(view.story_screen().modulate.a, 0.4), "het verhaal op zijn plek en helderheid")
	view.show_story_at(false, 5.0, 1.0)
	test.check(not view.story_screen().visible and view.story_text().position.y == 321.0, "weg: het blijft staan waar het stond")
	view.free()


func test_show_sparkle(test) -> void:
	var view := _view()
	view.show_sparkle(true, 0.5, 0.64)
	test.check(view.sparkle().visible and is_equal_approx(view.sparkle().modulate.a, 0.64), "de twinkeling zo fel als gezegd")
	test.check(view.sparkle().scale.is_equal_approx(Vector2.ONE * IntroLayout.sparkle_scale(0.64)) and is_equal_approx(view.sparkle().rotation, IntroLayout.sparkle_rotation(0.5)), "op de maat en draai van de layout")
	var spark := view.sparks()[3]
	test.check(spark.visible and is_equal_approx(spark.modulate.a, 0.5) and spark.position.is_equal_approx(IntroLayout.spark_position(3, view.sparks().size(), 0.5, spark.size)),
		"de vonken onderweg, half vervaagd")
	view.show_sparkle(false, 2.0, 0.0)
	test.check(not view.sparkle().visible and view.sparks().all(func(each: ColorRect) -> bool: return not each.visible), "en alles weer weg")
	view.free()


func test_show_window_and_crt(test) -> void:
	var view := _view()
	view.show_window(Vector2(2560, 1440))
	test.check(view.design().scale == Vector2(2, 2) and view.design().position == Vector2.ZERO, "het ontwerp twee keer zo groot in een dubbel venster")
	view.show_window(Vector2(1280, 920))
	test.check(view.design().scale == Vector2.ONE and view.design().position == Vector2(0, 100), "in een hoger venster: in het midden")
	test.check(view.crt().shown("screen_size") == Vector2(1280, 920), "het CRT-beeld kent het venster")
	view.show_crt(true)
	test.check(float(view.crt().shown("curvature")) > 0.0, "het CRT-beeld aan")
	view.show_crt(false)
	test.check(float(view.crt().shown("curvature")) == 0.0, "en uit")
	view.free()


func test_add_behind_story(test) -> void:
	var view := _view()
	var drifter := Control.new()
	view.add_behind_story(drifter)
	test.check(drifter.get_parent() == view.design() and drifter.get_index() == view.story_screen().get_index() - 1, "vlak onder het verhaal")
	test.check(drifter.get_index() > view.sparkle().get_index() and drifter.get_index() > view.stars().get_index(), "boven de sterren en de twinkeling")
	view.free()
