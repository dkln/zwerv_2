extends RefCounted
## Unit tests of the picture of the CRT look (scripts/ui/hud/crt_view.gd).
##   tests/run_unit_tests.sh crt_view

const CrtView = preload("res://scripts/ui/hud/crt_view.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")


func test_a_layer_with_the_crt_shader(test) -> void:
	var view := CrtView.new()
	test.check(view.name == "CRT" and view.mouse_filter == Control.MOUSE_FILTER_IGNORE, "een laag die klikken doorlaat")
	test.check((view.material as ShaderMaterial).shader == UiStyle.CRT_SHADER, "met de CRT-shader")
	test.check(view.anchor_right == 1.0 and view.anchor_bottom == 1.0, "over het hele venster")
	view.free()


func test_hands_the_numbers_to_the_shader(test) -> void:
	var view := CrtView.new()
	view.show_crt(0.05, 0.02, 0.035, Vector2(1920.0, 1080.0))
	test.check(view.shown("curvature") == 0.05 and view.shown("ui_curvature") == 0.02 and view.shown("corner") == 0.035, "de bolling en de hoeken")
	test.check(view.shown("screen_size") == Vector2(1920.0, 1080.0), "de maat van het scherm")
	var picture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	view.show_picture(picture)
	test.check(view.shown("ui_texture") == picture, "het beeld van de HUD")
	view.free()
