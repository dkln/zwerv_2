extends RefCounted
## Unit tests of the shop screen (scripts/ui/shop_screen.gd) on its own: a stand-in seller
## (what Conversations gives a shop), a stand-in player (money, pockets) and a stand-in HUD
## (its indoor music). Opening (the header, the rows, the greeting, the music, the pause),
## choosing and buying with the keys and the mouse, the notices (too little money, full
## pockets), asking for the tip, leaving (goodbye, then closed), and the pure calculations
## (what a good does, what you can pay, the look of a row).
##   tests/run_unit_tests.sh shop_screen

const ShopScreen = preload("res://scripts/ui/shop_screen.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const Items = preload("res://scripts/player/items.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## What the screen asks of a Conversations with a seller.
class TestSeller:
	extends RefCounted
	var person: Node3D = null
	var buyer: Node
	var goods: Array = [{"item": "kroket", "prijs": 2.5}, {"item": "patat", "prijs": 3.0}, {"item": "water", "prijs": 1.0}]
	var tip_question := "Nog nieuws?"
	var logo := {}
	var moods: Array[String] = []

	func shop_kind_label() -> String:
		return "SNACKBAR"

	func shop_logo() -> Dictionary:
		return logo

	func shop_name() -> String:
		return "Frietje Fatsoen"

	func speaker() -> String:
		return "OME WIM"

	func look() -> Dictionary:
		return {}

	func voice() -> String:
		return "man"

	func show_mood(mood: String) -> void:
		moods.append(mood)

	func shop_goods() -> Array:
		return goods

	func shop_greeting() -> Dictionary:
		return {"text": "Zeg het maar.", "mood": "begroeting"}

	func shop_tip_question() -> String:
		return tip_question

	func shop_tip() -> Dictionary:
		return {"text": "Bij het station liggen blikjes.", "mood": "tip"}

	func shop_goodbye() -> Dictionary:
		return {"text": "Dag!", "mood": "dag"}

	func shop_buy(good_index: int) -> Dictionary:
		if good_index < 0 or good_index >= goods.size():
			return {}
		var entry: Dictionary = goods[good_index]
		var result := String(buyer.buy(String(entry.item), float(entry.prijs)))
		var lines := {"ok": "Alsjeblieft.", "geld": "Dat is te weinig.", "vol": "Waar laat je het?"}
		return {"result": result, "text": String(lines[result]), "mood": "blij" if result == "ok" else "boos"}


## Money and pockets, as the screen reads them of the player.
class TestPlayer:
	extends Node
	var money := 6.0
	var inventory := {}
	var slots := 2

	func inventory_slots() -> int:
		return slots

	func buy(item_id: String, price: float) -> String:
		if money + 0.001 < price:
			return "geld"
		if not inventory.has(item_id) and inventory.size() >= slots:
			return "vol"
		money -= price
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
		return "ok"


## The indoor music of the HUD, and whether a story page is over the shop.
class TestHud:
	extends Node
	var music := "supermarkt_muzak_1.ogg"
	var music_changes: Array[String] = []
	var story_showing := false

	func indoor_music() -> String:
		return music

	func set_indoor_music(file_name: String) -> void:
		music = file_name
		music_changes.append(file_name)

	func is_showing_story() -> bool:
		return story_showing


## A shop set up: the screen, its seller, the player and the HUD, and what `done` counted.
class Shop:
	var screen: ShopScreen
	var seller := TestSeller.new()
	var player := TestPlayer.new()
	var hud := TestHud.new()
	var done_calls := 0
	var was_paused := false

	func on_done() -> void:
		done_calls += 1

	func open() -> void:
		screen.open(seller, player, hud, on_done)

	func free_all() -> void:
		screen.get_tree().paused = was_paused
		screen.free()
		player.free()
		hud.free()


func _shop() -> Shop:
	var shop := Shop.new()
	shop.was_paused = tree.paused
	shop.seller.buyer = shop.player
	shop.screen = ShopScreen.new()
	shop.screen.font_title = UiStyle.font(UiStyle.FONT_TITLE)
	shop.screen.font_pixel = UiStyle.font(UiStyle.FONT_PIXEL)
	shop.screen.font_body = UiStyle.font(UiStyle.FONT_BODY)
	tree.root.add_child(shop.screen)
	return shop


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


static func _row_kinds(screen: ShopScreen) -> Array:
	return screen._rows.map(func(row: Dictionary) -> String: return String(row.kind))


func test_effect_text_of_a_good(test) -> void:
	test.check(ShopScreen.effect_text({"effect": {"honger": 25}}) == "+25 HONGER", "een plus bij wat erbij komt")
	test.check(ShopScreen.effect_text({"effect": {"honger": 40, "gezondheid": -2}}) == "+40 HONGER   -2 GEZONDHEID", "meer effecten naast elkaar, min zonder plus")
	test.check(ShopScreen.effect_text({"effect": {"honger": Items.FULL, "overprikkeldheid": -5}}) == "HONGER VOL   -5 OVERPRIKKELD", "helemaal vol: VOL")
	test.check(ShopScreen.effect_text({"effect": {"uithoudingsvermogen": 25}}) == "+25 UITHOUDING", "de korte naam van uithoudingsvermogen")
	test.check(ShopScreen.effect_text({"effect": {"geluk": 3}}) == "+3 GELUK", "een onbekende stat in hoofdletters")
	test.check(ShopScreen.effect_text({"rarity": "zeldzaam"}) == "ZELDZAAM", "zonder effect: hoe zeldzaam het is")
	test.check(ShopScreen.effect_text({}) == "", "niets bekend: leeg")


func test_can_afford(test) -> void:
	test.check(ShopScreen.can_afford(2.5, 2.5), "precies genoeg is genoeg")
	test.check(ShopScreen.can_afford(0.1 + 0.2, 0.3), "afronding van centen telt niet")
	test.check(not ShopScreen.can_afford(2.49, 2.5), "een cent te weinig is te weinig")
	test.check(ShopScreen.can_afford(0.0, 0.0), "gratis kan altijd")


func test_row_style(test) -> void:
	var chosen := ShopScreen._row_style(true)
	var other := ShopScreen._row_style(false)
	test.check(chosen.border_width_left == ShopScreen.ROW_STRIP and other.border_width_left == 2, "de gekozen rij heeft de strook links")
	test.check(chosen.border_color == UiStyle.ACCENT and other.border_color == UiStyle.BORDER, "en de rand in de accentkleur")


func test_set_icon_picks_the_items_own_or_that_of_its_kind(test) -> void:
	test.check(GameMenu.ITEM_ICONS.has(String(Items.item("ov_chipkaart").get("icon", ""))), "de OV-chipkaart heeft een eigen icoon")
	var icon := ShopScreen.PixelIcon.new()
	ShopScreen._set_icon(icon, "ov_chipkaart")
	test.check(icon.bitmap == GameMenu.ITEM_ICONS[String(Items.item("ov_chipkaart").icon)].rows, "het eigen icoon van het item")
	ShopScreen._set_icon(icon, "bestaat_niet")
	test.check(icon.bitmap == GameMenu.ITEM_ICONS[String(GameMenu.KIND_ICONS["spullen"])].rows, "een onbekend item: het icoon van spullen")
	icon.free()


func test_opening_shows_the_shop_and_plays_its_music(test) -> void:
	var shop := _shop()
	test.check(not shop.screen.is_showing() and not shop.screen.handle_input(_key(KEY_ENTER)), "eerst dicht: toetsen zijn niet voor de winkel")
	shop.open()
	var screen := shop.screen
	test.check(screen.is_showing() and tree.paused, "open, het spel staat stil")
	test.check(screen._kind_label.text == "SNACKBAR" and screen._name_label.text == "FRIETJE FATSOEN", "de soort zaak en de naam in hoofdletters")
	test.check(screen._speaker_label.text == "OME WIM", "de naam van de verkoper")
	test.check(_row_kinds(screen) == ["kopen", "kopen", "kopen", "tip", "weg"], "de waren, vragen en weggaan (%s)" % [_row_kinds(screen)])
	test.check((screen._rows[0].name as Label).text == "Warme kroket" and (screen._rows[0].price_label as Label).text == "€ 2,50", "een rij: de naam en de prijs")
	test.check((screen._rows[3].name as Label).text == "Nog nieuws?" and (screen._rows[4].name as Label).text == "Weggaan", "de vraag en weggaan")
	test.check(screen._money_label.text == "6,00" and screen._pockets_label.text == "0 / 2 VAKJES", "je geld en je zakken")
	test.check(screen.spoken_text() == "Zeg het maar." and shop.seller.moods == ["begroeting"], "de begroeting, met de stemming erbij")
	test.check(screen.notice_text() == "" and not screen._logo_badge.visible, "geen melding, geen logo")
	test.check(shop.hud.music == ShopScreen.SHOP_MUSIC, "de muziek van de handelaar")
	test.check(screen._chosen == 0 and screen._detail_text.text == String(Items.item("kroket").text)
		and screen._detail_effect.text == "HONGER VOL   -5 OVERPRIKKELD", "de eerste gekozen, met wat het is en doet")
	shop.seller.goods = []
	shop.open()
	test.check(_row_kinds(screen).size() == 5, "nog een keer openen terwijl hij open is: er gebeurt niets")
	shop.free_all()


func test_arrows_choose_and_wrap(test) -> void:
	var shop := _shop()
	shop.open()
	var screen := shop.screen
	test.check(screen.handle_input(_key(KEY_DOWN)) and screen._chosen == 1, "omlaag: de tweede")
	test.check(screen._detail_text.text == String(Items.item("patat").text), "met de tekst van de patat")
	test.check((screen._rows[1].name as Label).get_theme_color("font_color") == UiStyle.TEXT
		and (screen._rows[0].name as Label).get_theme_color("font_color") == UiStyle.MUTED, "de gekozen rij licht op")
	screen.handle_input(_key(KEY_W))
	screen.handle_input(_key(KEY_UP))
	test.check(screen._chosen == 4 and screen._detail_text.text.begins_with("De winkel uit"), "bovenaan omhoog: weggaan onderaan")
	screen.handle_input(_key(KEY_S))
	test.check(screen._chosen == 0, "onderaan omlaag: weer de eerste")
	screen._choose(3)
	test.check(screen._detail_text.text.begins_with("Even een praatje") and screen._detail_effect.text == "", "de vraag: kost niks")
	screen._choose(99)
	test.check(screen._chosen == 4, "voorbij het eind: de laatste")
	screen._choose(-5)
	test.check(screen._chosen == 0, "voor het begin: de eerste")
	var released := _key(KEY_DOWN)
	released.pressed = false
	test.check(screen.handle_input(released) and screen._chosen == 0, "een losgelaten toets is van de winkel maar doet niets")
	test.check(not screen.handle_input(InputEventMouseMotion.new()), "de muis bewegen is niet voor handle_input")
	test.check(shop.player.money == 6.0, "kiezen kost niets")
	shop.free_all()


func test_buying_with_enter_and_a_number(test) -> void:
	var shop := _shop()
	shop.open()
	var screen := shop.screen
	screen.handle_input(_key(KEY_ENTER))
	test.check(is_equal_approx(shop.player.money, 3.5) and int(shop.player.inventory.get("kroket", 0)) == 1, "Enter koopt de gekozen kroket")
	test.check(screen._money_label.text == "3,50" and screen._pockets_label.text == "1 / 2 VAKJES", "je geld en zakken bijgewerkt")
	test.check(screen.spoken_text() == "Alsjeblieft." and screen.notice_text() == "", "de verkoper zegt wat, geen melding")
	screen.handle_input(_key(KEY_3))
	test.check(is_equal_approx(shop.player.money, 2.5) and int(shop.player.inventory.get("water", 0)) == 1 and screen._chosen == 2, "3 koopt meteen het derde")
	test.check((screen._rows[1].price_label as Label).get_theme_color("font_color") == ShopScreen.WARNING.darkened(0.15)
		and (screen._rows[0].price_label as Label).get_theme_color("font_color") == UiStyle.TEXT, "wat je niet meer kunt betalen staat rood")
	screen.handle_input(_key(KEY_9))
	test.check(is_equal_approx(shop.player.money, 2.5) and screen._chosen == 2, "een cijfer voorbij de rijen doet niets")
	screen._choose(0)
	screen.handle_input(_key(KEY_SPACE))
	test.check(is_equal_approx(shop.player.money, 0.0) and int(shop.player.inventory.get("kroket", 0)) == 2, "Spatie koopt ook")
	shop.free_all()


func test_too_little_money_and_full_pockets_show_a_notice(test) -> void:
	var shop := _shop()
	shop.player.money = 1.0
	shop.open()
	var screen := shop.screen
	test.check(screen.buy(0) == "geld", "te weinig geld voor de kroket")
	test.check(screen.notice_text() == "TE WEINIG GELD" and screen.spoken_text() == "Dat is te weinig.", "de melding en wat de verkoper zegt")
	test.check(screen._money_label.get_theme_color("font_color") == ShopScreen.WARNING, "je geld even rood")
	test.check(shop.player.money == 1.0 and shop.player.inventory.is_empty(), "niets gekocht")
	screen._process(ShopScreen.NOTICE_SECONDS * 0.5)
	test.check(screen.notice_text() == "TE WEINIG GELD", "de melding blijft even")
	screen._process(ShopScreen.NOTICE_SECONDS * 0.6)
	test.check(screen.notice_text() == "", "en gaat dan weg")
	shop.player.money = 20.0
	shop.player.slots = 1
	test.check(screen.buy(2) == "ok" and screen.notice_text() == "", "water past nog")
	test.check(screen.buy(0) == "vol" and screen.notice_text() == "ZAKKEN VOL", "de kroket niet meer: zakken vol")
	test.check(screen.buy(2) == "ok" and screen.notice_text() == "", "nog een water (zelfde vakje): de melding weg")
	test.check(screen.buy(99) == "" and screen.buy(-1) == "", "iets dat er niet ligt: niets")
	test.check(is_equal_approx(shop.player.money, 18.0), "alleen de twee waters betaald")
	shop.free_all()


func test_asking_for_the_tip(test) -> void:
	var shop := _shop()
	shop.open()
	var screen := shop.screen
	screen.handle_input(_key(KEY_4))
	test.check(screen.spoken_text() == "Bij het station liggen blikjes." and shop.seller.moods.back() == "tip", "de tip, met zijn stemming")
	test.check(screen.is_showing() and shop.player.money == 6.0, "kost niks, de winkel blijft open")
	shop.free_all()
	var quiet := _shop()
	quiet.seller.tip_question = ""
	quiet.open()
	test.check(_row_kinds(quiet.screen) == ["kopen", "kopen", "kopen", "weg"], "zonder tip: geen rij om te vragen")
	quiet.free_all()


func test_leaving_says_goodbye_then_a_key_closes(test) -> void:
	var shop := _shop()
	shop.open()
	var screen := shop.screen
	screen.handle_input(_key(KEY_ESCAPE))
	test.check(screen.is_showing() and screen.spoken_text() == "Dag!" and shop.done_calls == 0, "Escape: eerst gedag zeggen")
	screen.leave()
	test.check(shop.seller.moods.count("dag") == 1, "nog een keer weggaan: er gebeurt niets")
	test.check(screen.buy(0) == "ok", "buy zelf werkt nog (de toetsen niet meer)")
	var money_after := shop.player.money
	screen.handle_input(_key(KEY_ENTER))
	test.check(not screen.is_showing() and shop.done_calls == 1, "een toets daarna sluit meteen")
	test.check(shop.player.money == money_after, "en koopt niets meer")
	test.check(tree.paused == shop.was_paused, "de pauze terug zoals hij was")
	test.check(shop.hud.music == "supermarkt_muzak_1.ogg" and shop.hud.music_changes.size() == 2, "de muziek van ervoor terug")
	test.check(screen._portrait == null, "het portret is weg")
	screen.leave()
	test.check(not screen.is_showing() and shop.done_calls == 1, "weggaan uit een dichte winkel: niets")
	shop.free_all()


func test_goodbye_closes_by_itself_but_not_under_a_story_page(test) -> void:
	var shop := _shop()
	shop.open()
	var screen := shop.screen
	screen._choose(4)
	screen.handle_input(_key(KEY_ENTER))
	test.check(screen._leaving, "Enter op Weggaan: gedag")
	shop.hud.story_showing = true
	screen._typewriter.finish()
	screen._process(ShopScreen.GOODBYE_WAIT * 2.0)
	test.check(screen.is_showing(), "een verhaal over de winkel: hij blijft staan")
	shop.hud.story_showing = false
	screen._process(ShopScreen.GOODBYE_WAIT * 0.5)
	test.check(screen.is_showing(), "even wachten na het gedag")
	screen._process(ShopScreen.GOODBYE_WAIT * 0.6)
	test.check(not screen.is_showing() and shop.done_calls == 1, "dan sluit hij vanzelf")
	shop.free_all()


func test_backspace_leaves_too(test) -> void:
	var shop := _shop()
	shop.open()
	shop.screen.handle_input(_key(KEY_BACKSPACE))
	test.check(shop.screen._leaving and shop.screen.spoken_text() == "Dag!", "Backspace: ook gedag")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	test.check(shop.screen.handle_input(click) and not shop.screen.is_showing(), "een klik daarna sluit")
	shop.free_all()


func test_the_mouse_chooses_and_buys(test) -> void:
	var shop := _shop()
	shop.open()
	var screen := shop.screen
	(screen._rows[1].button as Button).mouse_entered.emit()
	test.check(screen._chosen == 1, "de muis erover: gekozen")
	(screen._rows[2].button as Button).pressed.emit()
	test.check(screen._chosen == 2 and int(shop.player.inventory.get("water", 0)) == 1, "een klik op een rij koopt hem")
	(screen._rows[4].button as Button).pressed.emit()
	test.check(screen._leaving, "een klik op Weggaan: gedag")
	(screen._rows[0].button as Button).pressed.emit()
	test.check(not shop.player.inventory.has("kroket"), "tijdens het gedag koopt een klik niets meer")
	screen.handle_input(_key(KEY_ENTER))
	shop.free_all()


func test_a_snack_bar_keeps_its_own_music(test) -> void:
	var shop := _shop()
	shop.hud.music = ShopScreen.SHOP_MUSIC
	shop.open()
	shop.screen.leave()
	shop.screen.handle_input(_key(KEY_ENTER))
	test.check(shop.hud.music_changes.is_empty() and shop.hud.music == ShopScreen.SHOP_MUSIC, "de snackbar speelt het al: niets gewisseld")
	shop.free_all()


func test_the_logo_of_the_shop(test) -> void:
	var shop := _shop()
	shop.seller.logo = {"icoon": "pinpas", "kleur": "#AA2200", "tekst": "#FFEE00"}
	shop.open()
	test.check(shop.screen._logo_badge.visible and shop.screen._logo_icon.colour == Color("#FFEE00")
		and shop.screen._logo_icon.bitmap == GameMenu.ITEM_ICONS["pinpas"].rows, "het logo: het icoon in de kleur van de tekst")
	test.check((shop.screen._logo_badge.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Color("#AA2200"), "op een bord in de kleur van de zaak")
	shop.screen.leave()
	shop.screen.handle_input(_key(KEY_ENTER))
	shop.seller.logo = {"icoon": "bestaat_niet"}
	shop.open()
	test.check(not shop.screen._logo_badge.visible, "een onbekend icoon: geen logo")
	shop.free_all()


func test_keep_paused_decides_the_pause_after_closing(test) -> void:
	var shop := _shop()
	shop.screen.keep_paused = func() -> bool: return true
	shop.open()
	shop.screen.leave()
	shop.screen.handle_input(_key(KEY_ENTER))
	test.check(not shop.screen.is_showing() and tree.paused, "een ander scherm staat nog open: het spel blijft stil")
	shop.free_all()
	test.check(tree.paused == shop.was_paused, "en na de test weer zoals het was")


func test_the_seller_talks_while_the_line_types_out(test) -> void:
	var shop := _shop()
	shop.open()
	var screen := shop.screen
	screen._process(0.05)
	test.check(screen._portrait.speaking and screen._portrait.speech == "Zeg het maar.", "de mond beweegt met de begroeting")
	screen._typewriter.finish()
	screen._process(0.05)
	test.check(not screen._portrait.speaking, "uitgetypt: de mond stil")
	shop.free_all()
