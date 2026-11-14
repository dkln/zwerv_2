extends RefCounted
## Unit tests of the logic of the reward screen (scripts/ui/screens/reward_screen_rules.gd):
## the pages of a reward, what a page says, the chips, the footer and the wait for the keys.
##   tests/run_unit_tests.sh reward_screen_rules

const RewardScreenRules = preload("res://scripts/ui/screens/reward_screen_rules.gd")

const KROKET := {"name": "Warme kroket", "rarity": "bijzonder", "text": "Vers uit de muur."}


func test_pages_of(test) -> void:
	var two := RewardScreenRules.pages_of({"heading": "GEKREGEN", "title": "Van de toerist", "xp": 25,
		"items": [{"item": "appel", "count": 1}, {"item": "koffie", "count": 3}]})
	test.check(two.size() == 2, "één bladzijde per item")
	test.check(int(two[0].xp) == 25 and int(two[1].xp) == 0, "de XP op de eerste")
	test.check(two[1].item == "koffie" and int(two[1].count) == 3, "met hoeveel")
	test.check(two[0].heading == "GEKREGEN" and two[1].title == "Van de toerist", "de kop en de titel op elke bladzijde")
	var only_xp := RewardScreenRules.pages_of({"xp": 100})
	test.check(only_xp.size() == 1 and only_xp[0].item == "" and int(only_xp[0].count) == 0, "alleen XP: één bladzijde zonder item")
	test.check(RewardScreenRules.pages_of({}).is_empty(), "niets: geen bladzijde")


func test_pages_of_edge_cases(test) -> void:
	var pages := RewardScreenRules.pages_of({"xp": 10, "items": [{"item": ""}, {"count": 2}, {"item": "appel"}]})
	test.check(pages.size() == 1 and pages[0].item == "appel" and int(pages[0].count) == 1 and int(pages[0].xp) == 10,
		"items zonder naam overgeslagen, één stuk als er niets staat, de XP op de eerste echte")
	test.check(pages[0].heading == RewardScreenRules.DEFAULT_HEADING and pages[0].title == "", "zonder kop: BELONING, zonder titel")
	test.check(RewardScreenRules.pages_of({"xp": 0}).is_empty() and RewardScreenRules.pages_of({"xp": -5}).is_empty(), "geen of negatieve XP zonder items: geen bladzijde")
	var only_empty := RewardScreenRules.pages_of({"xp": 30, "items": [{"item": ""}]})
	test.check(only_empty.size() == 1 and only_empty[0].item == "" and int(only_empty[0].xp) == 30, "alleen lege items: de bladzijde met alleen XP")
	var no_xp := RewardScreenRules.pages_of({"items": [{"item": "appel"}]})
	test.check(no_xp.size() == 1 and int(no_xp[0].xp) == 0, "een item zonder XP: een bladzijde zonder XP")


func test_keys_work_after_a_moment(test) -> void:
	test.check(not RewardScreenRules.keys_work(0.0) and not RewardScreenRules.keys_work(RewardScreenRules.KEYS_AFTER - 0.01), "eerst nog niet")
	test.check(RewardScreenRules.keys_work(RewardScreenRules.KEYS_AFTER) and RewardScreenRules.keys_work(5.0), "na de wachttijd wel")


func test_footer_text(test) -> void:
	test.check(RewardScreenRules.footer_text(0, 1) == "[ENTER] OK", "een bladzijde: OK")
	test.check(RewardScreenRules.footer_text(0, 3) == "[ENTER] VERDER  1 / 3", "de eerste van drie: verder, 1 / 3")
	test.check(RewardScreenRules.footer_text(1, 3) == "[ENTER] VERDER  2 / 3", "de tweede van drie")
	test.check(RewardScreenRules.footer_text(2, 3) == "[ENTER] OK", "de laatste van drie: OK")


func test_xp_text_and_rarity_label(test) -> void:
	test.check(RewardScreenRules.xp_text(50) == "+50 XP" and RewardScreenRules.xp_text(0) == "+0 XP", "XP met een plus")
	test.check(RewardScreenRules.rarity_label({"rarity": "episch"}) == "EPISCH", "de zeldzaamheid in hoofdletters")
	test.check(RewardScreenRules.rarity_label({}) == "GEWOON", "zonder zeldzaamheid: gewoon")
	test.check(RewardScreenRules.rarity_label({"rarity": "bestaat_niet"}) == "GEWOON", "een onbekende: gewoon")
	for rarity: String in RewardScreenRules.RARITY_LABELS:
		test.check(RewardScreenRules.rarity_label({"rarity": rarity}) == rarity.to_upper(), "%s heeft zijn eigen woord" % rarity)


func test_chips(test) -> void:
	test.check(RewardScreenRules.chips({"item": "appel", "count": 1, "xp": 0}).is_empty(), "een stuk zonder XP: geen chips")
	test.check(RewardScreenRules.chips({"item": "appel", "count": 3, "xp": 0}) == [["3 x", RewardScreenRules.CHIP_COUNT]], "meer dan een: het aantal")
	test.check(RewardScreenRules.chips({"item": "appel", "count": 1, "xp": 50}) == [["+50 XP", RewardScreenRules.CHIP_XP]], "XP erbij: de XP")
	test.check(RewardScreenRules.chips({"item": "appel", "count": 2, "xp": 50}) == [["2 x", RewardScreenRules.CHIP_COUNT], ["+50 XP", RewardScreenRules.CHIP_XP]], "allebei: eerst het aantal, dan de XP")
	test.check(RewardScreenRules.chips({"item": "", "count": 0, "xp": 50}).is_empty(), "alleen XP: geen chips (de XP staat groot)")


func test_page_texts_of_an_item(test) -> void:
	var texts := RewardScreenRules.page_texts({"heading": "GEKREGEN", "title": "Van iemand", "xp": 25, "item": "kroket", "count": 2}, KROKET)
	test.check(texts.heading == "◆ GEKREGEN" and texts.title == "Van iemand", "de kop met een ruitje, en van wie")
	test.check(texts.name == "WARME KROKET" and texts.rarity == "BIJZONDER" and texts.text == "Vers uit de muur.", "de naam in hoofdletters, de zeldzaamheid en het tekstje")
	test.check(texts.big_xp == "" and texts.chips.size() == 2, "geen grote XP, wel de chips")
	var nameless := RewardScreenRules.page_texts({"heading": "X", "title": "", "xp": 0, "item": "ding", "count": 1}, {})
	test.check(nameless.name == "DING" and nameless.rarity == "GEWOON" and nameless.text == "" and nameless.chips.is_empty(), "een item zonder gegevens: zijn id, gewoon, geen tekst")


func test_page_texts_of_only_xp(test) -> void:
	var texts := RewardScreenRules.page_texts({"heading": "TAAK VOLBRACHT", "title": "", "xp": 75, "item": "", "count": 0}, {})
	test.check(texts.heading == "◆ TAAK VOLBRACHT" and texts.title == "", "de kop, geen titel")
	test.check(texts.name == RewardScreenRules.XP_NAME and texts.rarity == "" and texts.text == RewardScreenRules.XP_TEXT, "ERVARING, zonder zeldzaamheid, met zijn eigen regel")
	test.check(texts.big_xp == "+75 XP" and texts.chips.is_empty(), "de XP groot, geen chips")
