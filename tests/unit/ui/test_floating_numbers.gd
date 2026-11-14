extends RefCounted
## Unit tests of the numbers that float up from a point in the world
## (scripts/ui/widgets/floating_numbers.gd): how they rise, pop and fade, what spawn() makes,
## where a number stands on the screen and when it is gone.
##   tests/run_unit_tests.sh floating_numbers

const FloatingNumbers = preload("res://scripts/ui/widgets/floating_numbers.gd")
const FloatingNumbersLayout = preload("res://scripts/ui/widgets/floating_numbers_layout.gd")
const FloatingNumbersRules = preload("res://scripts/ui/widgets/floating_numbers_rules.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## The numbers in the tree; with a camera at (0, 0, 5) looking at the origin if `with_camera`.
func _numbers(with_camera: bool) -> FloatingNumbers:
	var numbers := FloatingNumbers.new()
	tree.root.add_child(numbers)
	if with_camera:
		var camera := Camera3D.new()
		camera.name = "TestCamera"
		camera.position = Vector3(0.0, 0.0, 5.0)
		numbers.add_child(camera)
		camera.make_current()
	return numbers


static func _labels(numbers: FloatingNumbers) -> Array:
	return numbers.view.numbers()


func test_spawn_makes_a_number_with_its_shadow(test) -> void:
	var numbers := _numbers(false)
	test.check(numbers.mouse_filter == Control.MOUSE_FILTER_IGNORE, "klikken gaan erdoorheen")
	var gold := Color("#E8B83A")
	numbers.spawn(Vector3.ZERO, "+€ 0,50", gold, 20)
	var labels := _labels(numbers)
	test.check(labels.size() == 1, "één getal (%d)" % labels.size())
	var label: Label = labels[0]
	test.check(label.text == "+€ 0,50", "met zijn tekst")
	test.check(label.get_theme_color("font_color") == gold and label.get_theme_font_size("font_size") == 20, "in zijn kleur en maat")
	test.check(label.get_theme_constant("outline_size") == 0, "zonder rand")
	test.check(label.pivot_offset.is_equal_approx(label.size * 0.5), "het krimpt om zijn midden")
	var shadow := label.get_child(0) as Label
	test.check(shadow != null and shadow.text == label.text and shadow.show_behind_parent, "een kopie van de tekst erachter")
	test.check(shadow.position == FloatingNumbersLayout.SHADOW_OFFSET, "een paar pixels lager")
	test.check(shadow.get_theme_color("font_color").is_equal_approx(UiStyle.faux_3d_colour(gold)), "in de kleur half zo licht")
	test.check(not label.visible, "zonder camera is het niet te zien")
	numbers.spawn(Vector3.ZERO, "-12", Color.RED)
	test.check(_labels(numbers).size() == 2 and (_labels(numbers)[1] as Label).get_theme_font_size("font_size") == 16, "een tweede erbij, 16 px als niets gezegd is")
	numbers.free()


func test_a_number_lives_its_lifetime(test) -> void:
	var numbers := _numbers(false)
	numbers.lifetime = 2.0
	numbers.spawn(Vector3.ZERO, "+1", Color.WHITE)
	numbers._process(1.9)
	test.check(_labels(numbers).size() == 1, "binnen zijn tijd: het is er nog")
	numbers._process(0.2)
	test.check(_labels(numbers).is_empty() and numbers._numbers.is_empty(), "daarna is het weg")
	numbers._process(0.2)
	test.check(numbers._numbers.is_empty(), "zonder getallen gebeurt er niets")
	numbers.free()


func test_a_number_stands_over_its_point_on_the_screen(test) -> void:
	var numbers := _numbers(true)
	numbers.world_viewport = tree.root
	var camera: Camera3D = numbers.get_node("TestCamera")
	var from := Vector3(0.5, 0.0, 0.0)
	numbers.spawn(from, "+€ 1,00", Color.WHITE)
	var label: Label = _labels(numbers)[0]
	test.check(label.visible, "voor de camera: te zien")
	test.check(is_equal_approx(label.scale.x, FloatingNumbersRules.POP_SCALE) and label.modulate.a == 1.0, "het begint groot en helder")
	var on_screen := camera.unproject_position(from)
	test.check(is_equal_approx(label.position.y, roundf(on_screen.y - label.size.y * 0.5)), "op de hoogte van het punt (%s bij %s)" % [label.position.y, on_screen.y])
	test.check(absf(label.position.x + label.size.x * 0.5 - on_screen.x) <= FloatingNumbersLayout.SPREAD_PIXELS + 1.0, "er recht boven, hooguit een paar pixels opzij")
	var start_height := label.position.y
	numbers._process(FloatingNumbers.LIFETIME * 0.8)
	test.check(label.position.y < start_height, "het stijgt (%s naar %s)" % [start_height, label.position.y])
	var risen := camera.unproject_position(from + Vector3.UP * FloatingNumbersRules.rise(0.8))
	test.check(is_equal_approx(label.position.y, roundf(risen.y - label.size.y * 0.5)), "zo hoog als rise() zegt")
	test.check(label.scale == Vector2.ONE and label.modulate.a < 1.0 and label.modulate.a > 0.0, "op zijn eigen maat, half vervaagd (%s)" % label.modulate.a)
	numbers.free()


func test_a_number_behind_the_camera_is_hidden(test) -> void:
	var numbers := _numbers(true)
	numbers.world_viewport = tree.root
	numbers.spawn(Vector3(0.0, 0.0, 20.0), "+1", Color.WHITE)
	var label: Label = _labels(numbers)[0]
	test.check(not label.visible, "achter de camera: verborgen")
	numbers._process(0.1)
	test.check(not label.visible, "en dat blijft zo")
	numbers.free()
