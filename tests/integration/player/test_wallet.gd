extends "res://tests/integration/support/town_test.gd"
## The wallet and a money goal ("geld_verdiend", Story.money_towards_goal: a mission of the test),
## without the town (fast): the real PlayerController and the real Story, with a stand-in
## HUD that only remembers what it was told. Checks that the mission and the wallet in the
## corner always say the same amount:
## - coins picked up count, for both;
## - money spent counts off again (found € 1,50, spent € 0,50: both say € 1,00; the step is
##   not ticked off before there is € 2 in the wallet again);
## - coins that make € 2 count as € 2 (in floats they can add up to 1.9999...);
## - the money a character starts with never counts, also not after spending some of it;
## - a step once done stays done when the money is spent on the kroket.
##   tests/run_integration_tests.sh wallet

const PlayerController = preload("res://scripts/player/player_controller.gd")
const Story = preload("res://scripts/story/story.gd")
const MoneyText = preload("res://scripts/common/money_text.gd")
const GameHud = preload("res://scripts/ui/hud.gd")

## A mission of its own with a money goal first (the first missions of the game have none).
const MISSION := "test_kleingeld"
const MONEY_STEP := "kleingeld"
const TEST_MISSION := {"id": MISSION, "label": "TEST", "titel": "Twee euro voor een kroket", "start": "nooit",
	"stappen": [{"id": MONEY_STEP, "tekst": "Bemachtig € 2 kleingeld ({voortgang})", "xp": 50,
		"doel": {"soort": "geld_verdiend", "bedrag": 2.0}},
		{"id": "kroket", "tekst": "Koop een kroket", "xp": 100, "doel": {"soort": "kopen", "item": "kroket"}}]}
## Coins (as LooseChange gives them) whose sum in floats is just under 2.
const COINS_UNDER_TWO: Array[float] = [0.2, 0.5, 0.1, 0.5, 0.2, 0.5]

## A HUD that remembers the last money and quests it was given, and nothing more.
const STAND_IN_HUD := """extends Node
var money := -1.0
var quests: Array = []
func set_money(euros: float) -> void:
	money = euros
func set_quests(given: Array) -> void:
	quests = given
func show_mission(_title: String) -> void:
	pass
func show_story(_pages: Array, _done := Callable()) -> void:
	pass
func play_task_done(_whole: bool) -> void:
	pass
"""


static func world_options() -> Dictionary:
	return {"town": false}


## A town of three nodes (Speler, HUD, Verhaal) with mission 1 under way, the player a
## character that starts without money: {"player", "hud", "story"}. The reset frees it.
func _small_town() -> Dictionary:
	PlayerCharacter.choose("jos")
	var town := Node3D.new()
	town.name = "Stad"
	var hud_script := GDScript.new()
	hud_script.source_code = STAND_IN_HUD
	hud_script.reload()
	var stand_in_hud := Node.new()
	stand_in_hud.name = "HUD"
	stand_in_hud.set_script(hud_script)
	town.add_child(stand_in_hud)
	var wallet_owner := PlayerController.new()
	wallet_owner.name = "Speler"
	town.add_child(wallet_owner)
	var story := Story.new()
	story.name = "Verhaal"
	town.add_child(story)
	add_to_root(town)
	await frames(1)
	story.missions.append(TEST_MISSION.duplicate(true))
	story.start_mission(story.mission(MISSION), false)
	return {"player": wallet_owner, "hud": stand_in_hud, "story": story}


## The wallet in the corner, the progress in the step's text and money_towards_goal all
## say `euros` (the step's text only while the step is open: it shows "(€ 1,50)").
func _same_amount(test, parts: Dictionary, euros: float, what: String) -> void:
	var story: Node = parts.story
	var wallet := MoneyText.amount(parts.hud.money)
	var wanted := MoneyText.amount(euros)
	var step_text := ""
	if not parts.hud.quests.is_empty():
		step_text = String((parts.hud.quests[0].steps[0] as Dictionary).text)
	var goal := MoneyText.amount(story.money_towards_goal())
	print("  %s: portemonnee %s, missie \"%s\", doel %s" % [what, wallet, step_text, goal])
	test.check(wallet == wanted, "%s: portemonnee %s" % [what, wanted])
	test.check(goal == wanted, "%s: missie telt %s" % [what, wanted])
	if not story.step_done(MISSION, MONEY_STEP):
		test.check(step_text.contains("€ " + wanted), "%s: missietekst zegt € %s" % [what, wanted])
	test.check(is_equal_approx(parts.player.money, euros), "%s: geld %.2f" % [what, euros])


## Money spent counts off again, for the wallet and the mission alike: the money step is
## only ticked off once there is € 2 in the wallet.
func test_spending_counts_off(test) -> void:
	var parts := await _small_town()
	var wallet_owner: Node = parts.player
	var story: Node = parts.story
	for coin in 3:
		wallet_owner.add_money(0.5)
	_same_amount(test, parts, 1.5, "drie munten van € 0,50")
	test.check(not story.step_done(MISSION, MONEY_STEP), "nog geen € 2: stap open")
	test.check(wallet_owner.buy("kauwgom", 0.5) == "ok", "pakje kauwgom gekocht voor € 0,50")
	_same_amount(test, parts, 1.0, "na € 0,50 uitgeven")
	wallet_owner.add_money(0.5)
	_same_amount(test, parts, 1.5, "weer een munt")
	test.check(not story.step_done(MISSION, MONEY_STEP), "€ 1,50 op zak (€ 2 gevonden): stap nog open")
	wallet_owner.add_money(0.5)
	_same_amount(test, parts, 2.0, "€ 2 op zak")
	test.check(story.step_done(MISSION, MONEY_STEP), "€ 2 op zak: stap afgevinkt")


## Coins whose sum in floats comes out just under 2 (1.9999999999999998) still count as € 2.
func test_coins_that_make_two_euros_count_as_two(test) -> void:
	var parts := await _small_town()
	var wallet_owner: Node = parts.player
	for coin: float in COINS_UNDER_TWO:
		wallet_owner.add_money(coin)
	print("  (in floats: %.17f)" % wallet_owner.money)
	test.check(wallet_owner.money < 2.0, "de som in floats is net onder 2 (zo raap je ze ook in het spel op)")
	_same_amount(test, parts, 2.0, "zes munten, samen € 2")
	test.check((parts.story as Node).step_done(MISSION, MONEY_STEP), "stap afgevinkt bij € 2,00 in de portemonnee")


## The money a character starts with never counts towards the goal, also not after
## spending some of it.
func test_start_money_never_counts(test) -> void:
	var parts := await _small_town()
	var wallet_owner: Node = parts.player
	var story: Node = parts.story
	# as a character that starts with € 1 (it is set before anything was found)
	wallet_owner.money = 1.0
	wallet_owner.add_money(0.5)
	test.check(is_equal_approx(story.money_towards_goal(), 0.5), "€ 1 start, € 0,50 gevonden: telt € 0,50 (%.2f)" % story.money_towards_goal())
	wallet_owner.add_money(-1.2)
	test.check(is_equal_approx(story.money_towards_goal(), 0.3), "€ 1,20 uitgegeven: € 0,30 over, telt € 0,30 (%.2f)" % story.money_towards_goal())
	wallet_owner.add_money(5.0)
	test.check(is_equal_approx(story.money_towards_goal(), 5.3), "€ 5 gekregen: telt € 5,30 (%.2f)" % story.money_towards_goal())
	test.check(story.step_done(MISSION, MONEY_STEP), "en de stap is afgevinkt")


## A step once done stays done when the money is spent on the kroket, which finishes mission 1.
func test_done_stays_done(test) -> void:
	var parts := await _small_town()
	var wallet_owner: Node = parts.player
	var story: Node = parts.story
	wallet_owner.add_money(2.0)
	test.check(story.step_done(MISSION, MONEY_STEP), "€ 2: stap afgevinkt")
	test.check(wallet_owner.buy("kroket", 2.0) == "ok", "kroket gekocht")
	test.check(story.step_done(MISSION, MONEY_STEP), "geldstap blijft afgevinkt na het uitgeven")
	test.check(story.step_done(MISSION, "kroket"), "kroketstap afgevinkt")
	test.check(story.is_finished(MISSION), "missie 1 klaar")
