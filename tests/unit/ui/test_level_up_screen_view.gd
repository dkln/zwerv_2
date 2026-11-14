extends RefCounted
## Unit tests of how the level-up screen looks (scripts/ui/screens/level_up_screen_view.gd):
## what it builds and what it shows when told, without the behaviour around it.
##   tests/run_unit_tests.sh level_up_screen_view

const LevelUpScreenView = preload("res://scripts/ui/screens/level_up_screen_view.gd")
const LevelUpScreenLayout = preload("res://scripts/ui/screens/level_up_screen_layout.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

const OPTIONS := [{"stat": "gezondheid", "name": "GEZONDHEID", "text": "Je kunt meer hebben."},
	{"stat": "honger", "name": "GROTERE MAAG", "text": "Je houdt het langer uit."}]
const LOOKS := {"gezondheid": {"colour": Color("#FF5D73"), "icon": "hart"}}
const ICONS := {"hart": ["0110", "1111", "0110"]}

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _view() -> LevelUpScreenView:
	var fonts := UiStyle.fonts()
	var view := LevelUpScreenView.new(fonts.title, fonts.pixel, fonts.body, OPTIONS, LOOKS, ICONS)
	tree.root.add_child(view)
	return view


static func _texts(view: Node) -> Array:
	return view.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func test_it_builds_a_row_per_option(test) -> void:
	var view := _view()
	var texts := _texts(view)
	test.check(view.name == "Beeld" and view.rows.size() == 2 and view.row_values.size() == 2, "een rij per stat")
	test.check(texts.has(LevelUpScreenView.HEADING) and texts.has(LevelUpScreenView.ASK) and texts.has(LevelUpScreenView.KEYS), "de kop, de vraag en de toetsen (%s)" % [texts])
	test.check(texts.has("GEZONDHEID") and texts.has("Je houdt het langer uit.") and texts.has("1") and texts.has("2"), "per rij zijn nummer, naam en uitleg")
	test.check(view.rows[0].name == "Keuze1" and view.rows[1].name == "Keuze2", "de rijen bij naam")
	var panel := view.find_child("LevelOmhoog", true, false) as PanelContainer
	test.check(panel != null and panel.custom_minimum_size == LevelUpScreenLayout.PANEL_SIZE, "het paneel in de maat van de layout")
	var icons := view.rows[0].find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node.get("bitmap") != null)
	test.check(icons.size() == 1 and icons[0].bitmap == ICONS.hart and icons[0].colour == Color("#FF5D73"), "het icoon van de stat in zijn kleur")
	test.check(not view.xp_label.visible and view.level_label.text == "", "nog geen level en geen XP")
	view.free()


func test_without_anything_it_is_an_empty_panel(test) -> void:
	var view := LevelUpScreenView.new()
	test.check(view.rows.is_empty() and view.level_label != null, "zonder stats: geen rijen, wel het paneel")
	view.show_rows(0, [])
	test.check(view.rows.is_empty(), "en niets te tonen")
	view.free()


func test_show_level_and_xp(test) -> void:
	var view := _view()
	view.show_level("LEVEL 7")
	test.check(view.level_label.text == "LEVEL 7", "het level groot")
	view.show_xp("+40 XP", true)
	test.check(view.xp_label.visible and view.xp_label.text == "+40 XP" and view.xp_label.get_theme_color("font_color") == LevelUpScreenView.XP_COLOUR, "de XP in het groen")
	view.show_xp("+0 XP", false)
	test.check(not view.xp_label.visible, "of verborgen")
	view.free()


func test_show_rows_lights_the_selected(test) -> void:
	var view := _view()
	view.show_rows(0, ["70 → 80", "140 → 160"])
	test.check(view.row_values[0].text == "70 → 80" and view.row_values[1].text == "140 → 160", "de waarden per rij")
	test.check(view.row_values[0].get_theme_color("font_color") == Color("#FF5D73") and view.row_values[1].get_theme_color("font_color") == UiStyle.MUTED, "de gekozen rij in de kleur van zijn stat, de andere gedimd")
	var chosen_style := view.rows[0].get_theme_stylebox("panel") as StyleBoxFlat
	var other_style := view.rows[1].get_theme_stylebox("panel") as StyleBoxFlat
	test.check(chosen_style.border_color == Color("#FF5D73") and is_equal_approx(chosen_style.bg_color.a, LevelUpScreenView.CHOSEN_FILL_ALPHA), "de gekozen rij met een rand en een waas in zijn kleur")
	test.check(other_style.bg_color == UiStyle.INK and is_equal_approx(other_style.border_color.a, LevelUpScreenView.OTHER_BORDER_ALPHA), "de andere op inkt met een vage rand")
	view.show_rows(1, ["1 → 2"])
	test.check(view.row_values[1].get_theme_color("font_color") == UiStyle.ACCENT and view.row_values[0].get_theme_color("font_color") == UiStyle.MUTED, "een stat zonder eigen kleur: de accentkleur")
	test.check(view.row_values[0].text == "1 → 2" and view.row_values[1].text == "140 → 160", "een waarde die er niet bij is blijft staan")
	view.show_rows(-1, [])
	test.check(view.row_values[1].get_theme_color("font_color") == UiStyle.MUTED, "-1: geen gekozen")
	view.free()


func test_fade_in_and_row_at(test) -> void:
	var view := _view()
	view.fade_in()
	test.check(view.modulate.a == 0.0, "het komt op vanuit niets")
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(LevelUpScreenView.FADE_IN)
	test.check(is_equal_approx(view.modulate.a, 1.0), "tot het er helemaal staat")
	test.check(view.row_at(Vector2(-500, -500)) == -1, "geen rij onder een punt ver weg")
	view.rows[1].position = Vector2(300, 300)
	view.rows[1].size = Vector2(200, 40)
	var inside := view.rows[1].get_global_transform() * Vector2(10, 10)
	test.check(view.row_at(inside) == 1, "het punt in een rij: die rij (%d)" % view.row_at(inside))
	view.free()
