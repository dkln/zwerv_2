extends RefCounted
## Unit tests of the loading screen (scripts/ui/loading_screen.gd): showing(), what it puts
## on the screen (the title, what is loading, the bar and the percentage, the CRT look with
## the HUD's settings), set_progress and fade_out.
##   tests/run_unit_tests.sh loading_screen

const LoadingScreen = preload("res://scripts/ui/loading_screen.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## A HUD with CRT settings of its own.
class HudWithSettings extends Node:
	var crt_curvature := 0.2
	var crt_corner := 0.1


## Steps every running tween of the tree `seconds` on (a test has no frames of its own).
func _step_tweens(seconds: float) -> void:
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(seconds)


## Frees the screen and its waiting music (which fade_out moves to the root), its fades
## run to their end first (so none is left running on something that is gone).
func _discard(screen: LoadingScreen) -> void:
	_step_tweens(10.0)
	for child in tree.root.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("Wachtmuziek"):
			(child as AudioStreamPlayer).stop()
			child.free()
	screen.free()


static func _texts(screen: LoadingScreen) -> Array:
	return screen.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func test_showing_while_a_screen_is_up(test) -> void:
	test.check(not LoadingScreen.showing(tree), "eerst geen laadscherm")
	test.check(not LoadingScreen.showing(null), "zonder boom: ook niet")
	var screen := LoadingScreen.new()
	test.check(not LoadingScreen.showing(tree), "gemaakt maar nog niet in de boom: nog niet")
	tree.root.add_child(screen)
	test.check(LoadingScreen.showing(tree), "in de boom: ja")
	test.check(screen.is_in_group(LoadingScreen.GROUP) and screen.layer == 100, "in zijn groep, boven het spel")
	_discard(screen)
	test.check(not LoadingScreen.showing(tree), "weg: nee")


func test_it_shows_the_title_what_loads_and_an_empty_bar(test) -> void:
	var screen := LoadingScreen.new()
	tree.root.add_child(screen)
	var texts := _texts(screen)
	test.check(texts.has(LoadingScreen.TITLE), "de titel (%s)" % [texts])
	test.check(texts.has("— STAD LADEN —"), "wat er laadt, in hoofdletters zonder puntjes")
	test.check(screen._percentage.text == "0%" and screen._bar.fill == 0.0, "nog niets gedaan")
	test.check(screen._bar.segments == LoadingScreen.SEGMENTS and screen._bar.full_colour == UiStyle.ACCENT, "een balk van dertig amber blokjes")
	test.check(screen._panel.color == UiStyle.INK, "op inkt")
	_discard(screen)
	var other := LoadingScreen.new()
	other.text = "Wijk laden…"
	tree.root.add_child(other)
	test.check(_texts(other).has("— WIJK LADEN —"), "een andere tekst")
	_discard(other)


func test_set_progress_fills_the_bar(test) -> void:
	var screen := LoadingScreen.new()
	screen.set_progress(0.5)
	test.check(screen._percentage == null, "nog niet in de boom: er gebeurt niets")
	tree.root.add_child(screen)
	screen.set_progress(0.5)
	test.check(screen._percentage.text == "50%" and is_equal_approx(screen._bar.fill, 0.5), "halverwege")
	screen.set_progress(0.999)
	test.check(screen._percentage.text == "99%", "naar beneden afgerond: pas 100% als het af is")
	screen.set_progress(1.0)
	test.check(screen._percentage.text == "100%" and screen._bar.fill == 1.0, "af")
	_discard(screen)


func test_the_crt_look_takes_the_settings_of_the_hud(test) -> void:
	var plain := LoadingScreen.new()
	tree.root.add_child(plain)
	var plain_material := plain._crt.material as ShaderMaterial
	test.check(is_equal_approx(plain_material.get_shader_parameter("curvature"), 0.05) and is_equal_approx(plain_material.get_shader_parameter("corner"), 0.035), "zonder HUD: de gewone bolling")
	test.check(plain._crt.get_parent() == plain and plain._crt.get_index() > plain._panel.get_index(), "het CRT-beeld over het scherm heen")
	_discard(plain)
	var hud := HudWithSettings.new()
	var screen := LoadingScreen.new()
	screen.hud = hud
	tree.root.add_child(screen)
	var material := screen._crt.material as ShaderMaterial
	test.check(is_equal_approx(material.get_shader_parameter("curvature"), 0.2) and is_equal_approx(material.get_shader_parameter("corner"), 0.1), "met een HUD: die van de HUD")
	_discard(screen)
	var other_hud := Node.new()
	var third := LoadingScreen.new()
	third.hud = other_hud
	tree.root.add_child(third)
	test.check(is_equal_approx((third._crt.material as ShaderMaterial).get_shader_parameter("curvature"), 0.05), "een HUD zonder die instelling: de gewone")
	_discard(third)
	hud.free()
	other_hud.free()


func test_the_waiting_music_plays_and_fades(test) -> void:
	var screen := LoadingScreen.new()
	tree.root.add_child(screen)
	var music := screen._music
	if not ResourceLoader.exists(LoadingScreen.MUSIC):
		test.check(music == null, "zonder het bestand: geen muziek")
		_discard(screen)
		return
	test.check(music != null and music.playing and music.get_parent() == screen, "de wachtmuziek speelt")
	test.check(music.volume_db < -60.0, "en komt op vanuit stilte (%s dB)" % music.volume_db)
	test.check((music.stream as AudioStreamOggVorbis) == null or (music.stream as AudioStreamOggVorbis).loop, "in een lus")
	_step_tweens(5.0)
	test.check(is_equal_approx(music.volume_db, LoadingScreen.MUSIC_VOLUME_DB), "tot zijn eigen sterkte (%s dB)" % music.volume_db)
	screen.fade_out()
	test.check(screen._music == null and music.get_parent() == tree.root, "bij het weggaan gaat de muziek los van het scherm")
	_step_tweens(5.0)
	test.check(music.volume_db < -60.0 and music.is_queued_for_deletion(), "en dooft uit")
	_discard(screen)


func test_fade_out_fades_and_frees_the_screen(test) -> void:
	var screen := LoadingScreen.new()
	tree.root.add_child(screen)
	_step_tweens(5.0)
	screen.fade_out()
	var material := screen._crt.material as ShaderMaterial
	_step_tweens(LoadingScreen.FADE_SECONDS * 0.5)
	test.check(is_equal_approx(screen._panel.modulate.a, 0.5) and is_equal_approx(material.get_shader_parameter("opacity"), 0.5), "halverwege: half doorzichtig, ook het CRT-beeld")
	test.check(not screen.is_queued_for_deletion() and LoadingScreen.showing(tree), "en nog niet weg")
	_step_tweens(LoadingScreen.FADE_SECONDS)
	test.check(is_zero_approx(screen._panel.modulate.a), "daarna helemaal doorzichtig")
	_step_tweens(0.1)
	test.check(screen.is_queued_for_deletion(), "en het ruimt zichzelf op")
	_discard(screen)
