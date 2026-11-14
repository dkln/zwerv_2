extends RefCounted
## Unit tests of the portrait (scripts/ui/widgets/player_portrait.gd) on its own: a figure in
## a picture: the framing by `zoom`, what it passes on to the figure, the townsperson in its
## place, the talking mouth, the blink.
##   tests/run_unit_tests.sh player_portrait

const PlayerPortrait = preload("res://scripts/ui/widgets/player_portrait.gd")
const PlayerModel = preload("res://scripts/player/player_model.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Counts the cues of a portrait's gesture.
class Listener:
	var cues := 0

	func on_cue() -> void:
		cues += 1


func _portrait(picture_size: Vector2) -> PlayerPortrait:
	var portrait := PlayerPortrait.new()
	tree.root.add_child(portrait)
	portrait.size = picture_size
	return portrait


func test_mouth_opening_per_letter(test) -> void:
	for letter: String in ["a", "o", "u", "A", "ö", "á"]:
		test.check(PlayerPortrait.mouth_opening(letter) == PlayerPortrait.MOUTH_WIDE, "%s: wijd open" % letter)
	for letter: String in ["e", "i", "y", "E", "ë"]:
		test.check(PlayerPortrait.mouth_opening(letter) == PlayerPortrait.MOUTH_HALF, "%s: half open" % letter)
	for letter: String in ["k", "Z", "m", "ç"]:
		test.check(PlayerPortrait.mouth_opening(letter) == PlayerPortrait.MOUTH_LITTLE, "%s: een beetje open" % letter)
	for sign: String in [" ", "!", ".", "3", "€"]:
		test.check(PlayerPortrait.mouth_opening(sign) == 0.0, "'%s': dicht" % sign)


func test_zoom_frames_from_the_whole_figure_to_the_face(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	var camera := portrait._camera
	test.check(portrait.zoom == 0.0 and is_equal_approx(camera.size, PlayerPortrait.FULL_HEIGHT * 1.08), "eerst het hele figuur (%s m)" % camera.size)
	test.check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "zonder perspectief")
	portrait.zoom = 1.0
	var face := PlayerModel.face_height("jos")
	test.check(is_equal_approx(camera.size, portrait.face_view), "helemaal ingezoomd: het gezicht (%s m)" % camera.size)
	test.check(camera.position.is_equal_approx(Vector3(0.0, face + 0.3, 3.0)), "de camera op de hoogte van het gezicht (%s)" % camera.position)
	portrait.face_view = 1.2
	test.check(is_equal_approx(camera.size, 1.2), "een wijder gezicht als dat gevraagd is")
	portrait.zoom = 0.5
	test.check(is_equal_approx(camera.size, (PlayerPortrait.FULL_HEIGHT * 1.08 + 1.2) * 0.5), "halverwege: er tussenin")
	portrait.zoom = 7.0
	test.check(portrait.zoom == 1.0, "meer dan 1 wordt 1")
	portrait.zoom = -2.0
	test.check(portrait.zoom == 0.0, "minder dan 0 wordt 0")
	portrait.free()


func test_a_narrow_picture_shows_more_so_the_figure_fits(test) -> void:
	var portrait := _portrait(Vector2(150, 300))
	test.check(is_equal_approx(portrait._camera.size, PlayerPortrait.FULL_HEIGHT * 1.08 * 0.75 / 0.5), "smaller dan 3 op 4: meer meters in beeld (%s)" % portrait._camera.size)
	portrait.size = Vector2(300, 300)
	test.check(is_equal_approx(portrait._camera.size, PlayerPortrait.FULL_HEIGHT * 1.08), "weer vierkant: de gewone maat")
	portrait.free()


func test_the_face_height_follows_the_archetype(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	portrait.zoom = 1.0
	portrait.archetype_id = "willem"
	test.check(portrait._model.archetype_id == "willem", "het figuur wordt die ander")
	test.check(is_equal_approx(portrait._camera.position.y, PlayerModel.face_height("willem") + 0.3), "de camera op zijn gezicht (%s)" % portrait._camera.position.y)
	test.check(PlayerModel.face_height("willem") < PlayerModel.face_height("jos"), "dat lager zit dan dat van Jos")
	portrait.free()


func test_what_the_portrait_passes_on_to_its_figure(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	var model := portrait._model
	portrait.spin = 40.0
	test.check(model.spin == 40.0, "het draaien")
	portrait.spin = 0.0
	test.check(model.spin == 0.0, "en weer stil")
	portrait.walking = 1.0
	test.check(model.walking == 1.0, "het lopen")
	var outline := Color(1.0, 1.0, 1.0, 0.8)
	portrait.silhouette = outline
	test.check(model.silhouette == outline, "het silhouet")
	portrait.free()


func test_head_point_is_over_the_figure(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	var head := portrait.head_point()
	test.check(absf(head.x - 150.0) < 2.0, "midden boven het figuur (%s)" % head)
	test.check(head.y > 0.0 and head.y < 150.0, "in de bovenste helft van het plaatje (%s)" % head)
	portrait.zoom = 1.0
	test.check(portrait.head_point().y < head.y, "ingezoomd op het gezicht: de kruin staat hoger in beeld")
	portrait.free()


func test_gesture_starts_and_its_cue_comes_through(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	var listener := Listener.new()
	portrait.gesture_cue.connect(listener.on_cue)
	test.check(not portrait._model.is_gesturing(), "eerst geen gebaar")
	portrait.play_gesture()
	test.check(portrait._model.is_gesturing(), "het figuur doet zijn gebaar")
	portrait._model.gesture_cue.emit()
	test.check(listener.cues == 1, "het moment van zijn kreet komt door")
	portrait.free()


func test_a_townsperson_takes_the_place_of_the_figure(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	portrait.zoom = 1.0
	var look := TownsfolkFigure.look_for(7)
	portrait.townsfolk_look = look
	var figure := portrait._townsfolk as TownsfolkFigure
	test.check(figure != null and not portrait._model.visible, "de stadsbewoner in beeld, het spelersfiguur niet")
	if figure == null:
		portrait.free()
		return
	test.check(figure.has_face(), "met een mond en oogleden")
	test.check(is_equal_approx(figure.scale.x, portrait._townsfolk_scale) and portrait._townsfolk_scale > 0.5, "zo groot als een spelersfiguur hier is (%s)" % portrait._townsfolk_scale)
	test.check(is_equal_approx(portrait._camera.position.y, portrait._townsfolk_face + 0.3), "de camera op zijn gezicht")
	test.check(portrait._townsfolk_face > 1.0 and portrait._townsfolk_face < float(portrait._model.height()), "dat onder de kruin zit (%s m)" % portrait._townsfolk_face)
	portrait.townsfolk_look = {}
	test.check(portrait._townsfolk == null and portrait._model.visible, "zonder uiterlijk: weer het spelersfiguur")
	test.check(is_equal_approx(portrait._camera.position.y, PlayerModel.face_height("jos") + 0.3), "en de camera op diens gezicht")
	portrait.free()


func test_the_mouth_follows_the_letters_while_speaking(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	portrait.townsfolk_look = TownsfolkFigure.look_for(7)
	var figure := portrait._townsfolk as TownsfolkFigure
	portrait.speech = "a ek"
	portrait._process(0.01)
	test.check(figure.mouth_opening() == 0.0, "het spreekt niet: de mond dicht")
	portrait.speaking = true
	portrait._process(0.01)
	test.check(is_equal_approx(figure.mouth_opening(), PlayerPortrait.MOUTH_WIDE), "op de a: wijd open (%s)" % figure.mouth_opening())
	# MOUTH_LETTERS a second: a letter further every 1/14 s
	portrait._process(1.0 / PlayerPortrait.MOUTH_LETTERS)
	test.check(figure.mouth_opening() == 0.0, "op de spatie: dicht")
	portrait._process(1.0 / PlayerPortrait.MOUTH_LETTERS)
	test.check(is_equal_approx(figure.mouth_opening(), PlayerPortrait.MOUTH_HALF), "op de e: half open")
	portrait._process(1.0 / PlayerPortrait.MOUTH_LETTERS)
	test.check(is_equal_approx(figure.mouth_opening(), PlayerPortrait.MOUTH_LITTLE), "op de k: een beetje")
	portrait._process(1.0 / PlayerPortrait.MOUTH_LETTERS)
	test.check(is_equal_approx(figure.mouth_opening(), PlayerPortrait.MOUTH_WIDE), "aan het eind begint de regel opnieuw")
	portrait.speech = "k"
	portrait._process(0.01)
	test.check(is_equal_approx(figure.mouth_opening(), PlayerPortrait.MOUTH_LITTLE), "een nieuwe regel: vanaf zijn eerste letter")
	portrait.speaking = false
	portrait._process(0.01)
	test.check(figure.mouth_opening() == 0.0, "uitgesproken: weer dicht")
	portrait.speaking = true
	portrait.speech = ""
	portrait._process(0.01)
	test.check(figure.mouth_opening() == 0.0, "niets te zeggen: dicht")
	portrait.free()


func test_the_townsperson_blinks_now_and_then(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	portrait.townsfolk_look = TownsfolkFigure.look_for(7)
	var figure := portrait._townsfolk as TownsfolkFigure
	portrait._process(portrait._next_blink - 0.1)
	test.check(not figure.is_blinking(), "eerst de ogen open")
	portrait._process(0.1)
	test.check(figure.is_blinking(), "op zijn tijd: de ogen dicht")
	portrait._process(PlayerPortrait.BLINK_SECONDS * 0.5)
	test.check(figure.is_blinking(), "even dicht")
	portrait._process(PlayerPortrait.BLINK_SECONDS)
	test.check(not figure.is_blinking(), "en weer open")
	test.check(portrait._next_blink >= PlayerPortrait.BLINK_EVERY.x and portrait._next_blink <= PlayerPortrait.BLINK_EVERY.y, "de volgende knipper over 2 tot 5 s (%s)" % portrait._next_blink)
	portrait.visible = false
	portrait._process(10.0)
	test.check(not figure.is_blinking(), "verborgen: er gebeurt niets")
	portrait.free()


func test_the_close_up_follows_the_figure_in_the_world(test) -> void:
	var portrait := _portrait(Vector2(300, 300))
	var look := TownsfolkFigure.look_for(7)
	portrait.townsfolk_look = look
	var figure := portrait._townsfolk as TownsfolkFigure
	var grow := portrait._townsfolk_scale
	portrait._process(PlayerPortrait.BREATH_SECONDS * 0.25)
	test.check(is_equal_approx(figure.transform.basis.get_scale().y, grow * (1.0 + PlayerPortrait.BREATH_SHARE)), "het ademt: op zijn hoogst een fractie langer")
	test.check(is_equal_approx(figure.transform.basis.get_scale().x, grow) and figure.transform.origin.is_zero_approx(), "en staat verder stil")
	var in_the_world := TownsfolkFigure.create(look)
	in_the_world.position = Vector3(30.0, 0.0, -12.0)
	portrait.source_figure = in_the_world
	in_the_world.walk(0.25, 1.0)
	portrait._process(0.01)
	var arm: Node3D = figure._joints["arm_left"]
	var source_arm: Node3D = in_the_world._joints["arm_left"]
	test.check(arm.transform.is_equal_approx(source_arm.transform), "de houding van wie er in de wereld staat")
	test.check(figure.transform.origin.is_zero_approx(), "waar die staat doet er niet toe: in het midden van het plaatje")
	in_the_world.position += Vector3(0.0, 0.0, 0.5)
	portrait._process(0.01)
	test.check(figure.transform.origin.is_equal_approx(Vector3(0.0, 0.0, 0.5 * grow)), "een beweging vanaf daar doet het mee (%s)" % figure.transform.origin)
	portrait.source_figure = null
	portrait._process(0.01)
	test.check(figure.transform.origin.is_zero_approx(), "zonder bron: weer stil in het midden")
	in_the_world.free()
	portrait.free()
