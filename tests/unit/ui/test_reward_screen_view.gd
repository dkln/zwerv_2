extends RefCounted
## Unit tests of how the reward screen looks (scripts/ui/screens/reward_screen_view.gd):
## what it builds and the pages it shows when told, without the behaviour around it.
##   tests/run_unit_tests.sh reward_screen_view

const RewardScreenView = preload("res://scripts/ui/screens/reward_screen_view.gd")
const RewardScreenLayout = preload("res://scripts/ui/screens/reward_screen_layout.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

const RARE := Color("#4FA3FF")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _view() -> RewardScreenView:
	var fonts := UiStyle.fonts()
	var view := RewardScreenView.new(fonts.title, fonts.pixel, fonts.body)
	tree.root.add_child(view)
	return view


func test_it_builds_the_panel_and_the_stage(test) -> void:
	var view := _view()
	var panel := view.find_child("Beloning", true, false) as PanelContainer
	test.check(view.name == "Beeld" and panel != null and panel.custom_minimum_size == RewardScreenLayout.PANEL_SIZE, "het paneel in de maat van de layout")
	test.check(view.stage_frame.custom_minimum_size == RewardScreenLayout.STAGE_SIZE and view.stage_frame.clip_contents, "het podium")
	test.check(view.item_view.name == "Itembeeld" and view.rays.get_index() < view.item_view.get_index(), "het item voor de stralen")
	test.check(view.text.custom_minimum_size == RewardScreenLayout.text_size() and view.footer.text == "[ENTER] OK", "de regel en de voet")
	test.check(view.chip_texts().is_empty(), "nog geen chips")
	view.free()


func test_show_item_page(test) -> void:
	var view := _view()
	view.show_item_page({"heading": "◆ GEKREGEN", "title": "Van iemand", "name": "WARME KROKET", "rarity": "BIJZONDER",
		"text": "Vers uit de muur.", "big_xp": "", "chips": [["2 x", "count"], ["+25 XP", "xp"]]}, "kroket", RARE)
	test.check(view.heading.text == "◆ GEKREGEN" and view.title.text == "Van iemand" and view.title.visible, "de kop en van wie")
	test.check(view.item_view.visible and not view.big_xp.visible and view.item_view.mesh() != null, "het model van het item in beeld, geen grote XP")
	test.check(view.name_label.text == "WARME KROKET" and view.name_label.get_theme_color("font_color") == RARE, "de naam in de kleur van zijn zeldzaamheid")
	test.check(view.rarity.visible and view.rarity.text == "BIJZONDER" and view.rarity.get_theme_color("font_color") == RARE, "de zeldzaamheid ook")
	test.check((view.stage_frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color == RARE and is_equal_approx(view.rays.colour.a, RewardScreenView.RAYS_ALPHA), "de lijst en de stralen in die kleur")
	test.check(view.text.text == "Vers uit de muur.", "het tekstje")
	test.check(view.chips.visible and view.chip_texts() == ["2 x", "+25 XP"], "de chips (%s)" % [view.chip_texts()])
	var chip_nodes := view.chips.get_children()
	test.check((chip_nodes[0].get_child(0) as Label).get_theme_color("font_color") == UiStyle.TEXT
		and (chip_nodes[1].get_child(0) as Label).get_theme_color("font_color") == RewardScreenView.XP_COLOUR, "het aantal in de tekstkleur, de XP in het groen")
	view.free()


func test_show_xp_page(test) -> void:
	var view := _view()
	view.show_item_page({"heading": "A", "title": "B", "name": "C", "rarity": "D", "text": "E", "chips": [["3 x", "count"]]}, "appel", RARE)
	view.show_xp_page({"heading": "◆ TAAK VOLBRACHT", "title": "", "name": "ERVARING", "rarity": "", "text": "Wijzer.", "big_xp": "+75 XP", "chips": []})
	test.check(view.big_xp.visible and view.big_xp.text == "+75 XP" and not view.item_view.visible, "de XP groot, geen item")
	test.check(view.name_label.text == "ERVARING" and view.name_label.get_theme_color("font_color") == RewardScreenView.XP_COLOUR, "ERVARING in de kleur van XP")
	test.check(not view.rarity.visible and not view.title.visible and not view.chips.visible and view.chip_texts().is_empty(), "zonder zeldzaamheid, titel of chips")
	test.check((view.stage_frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color == RewardScreenView.XP_COLOUR, "de lijst in de kleur van XP")
	view.free()


func test_show_footer_and_fade_in(test) -> void:
	var view := _view()
	view.show_footer("[ENTER] VERDER  1 / 2")
	test.check(view.footer.text == "[ENTER] VERDER  1 / 2", "de voet zoals gegeven")
	view.fade_in()
	test.check(view.modulate.a == 0.0, "het komt op vanuit niets")
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(RewardScreenView.FADE_IN)
	test.check(is_equal_approx(view.modulate.a, 1.0), "tot het er helemaal staat")
	view.free()
