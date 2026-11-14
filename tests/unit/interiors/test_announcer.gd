extends RefCounted
## Unit tests of the loudspeakers (scripts/world/interiors/announcer.gd, shared by the station,
## the supermarkets and the city hall) and what a supermarket says (supermarket_announcer.gd).
##   tests/run_unit_tests.sh announcer

const Announcer = preload("res://scripts/world/interiors/announcer.gd")
const SupermarketAnnouncer = preload("res://scripts/world/interiors/supermarket_announcer.gd")

## A HUD with only what the announcer uses: the music down and up.
const STAND_IN_HUD := """extends Node
var ducked := false
func duck_music(down: bool) -> void:
	ducked = down
"""

## A supermarket with what its announcer asks: brand, plan (shelves, checkouts), product().
const STAND_IN_MARKET := """extends Node
var brand := "derrek"
var plan := {"shelves": [{"category": "kaas"}, {"category": "brood"}], "checkouts": [{"number": 4}]}
func product(category: String) -> Dictionary:
	return {"name": "Jong belegen" if category == "kaas" else "Volkoren", "price": 2.5, "bonus": false}
"""

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


func _stand_in(source: String) -> Node:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	var node := Node.new()
	node.set_script(script)
	return node


func test_say_ducks_the_music_and_stop_lifts_it(test) -> void:
	var hud := _stand_in(STAND_IN_HUD)
	tree.root.add_child(hud)
	var announcer := Announcer.new(func() -> Node: return hud)
	tree.root.add_child(announcer)
	test.check(not announcer.is_speaking() and announcer.shown_text() == "", "eerst stil")
	announcer.say("")
	test.check(not announcer.is_speaking(), "niets te zeggen: stil")
	announcer.say("Nummer B 047, loket 3.")
	test.check(announcer.is_speaking(), "spreekt")
	test.check(bool(hud.get("ducked")), "muziek zachter")
	announcer.say("Nummer B 048, loket 1.")
	test.check(announcer._queue.size() == 1, "de tweede wacht")
	announcer.stop()
	test.check(not announcer.is_speaking() and announcer._queue.is_empty(), "stop: stil en wachtrij leeg")
	test.check(not bool(hud.get("ducked")), "muziek weer omhoog")
	test.check(not announcer.is_typing(), "geen tekst op het scherm")
	announcer.free()
	hud.free()


func test_without_hud_nothing_is_ducked(test) -> void:
	var announcer := Announcer.new()
	tree.root.add_child(announcer)
	announcer.say("Let op.")
	test.check(announcer.is_speaking(), "spreekt ook zonder HUD")
	test.check(announcer.get_node_or_null("Omroeptekst") is CanvasLayer, "de onderregel is er")
	announcer.hide_subtitle()
	test.check(not announcer.is_typing(), "onderregel weg")
	announcer.stop()
	announcer.free()


func test_supermarket_says_offers_and_notices(test) -> void:
	var market := _stand_in(STAND_IN_MARKET)
	tree.root.add_child(market)
	var announcer := SupermarketAnnouncer.new(market)
	market.add_child(announcer)
	test.check(announcer.voice_clips == 3 and announcer.most_clips == 12, "eigen instellingen van de supermarkt")
	var texts := {}
	for attempt in 20:
		var text: String = announcer._next_text()
		test.check(text != "" and not text.contains("{"), "een ingevulde tekst (%s)" % text)
		texts[text] = true
	test.check(texts.size() > 3, "afwisselend (%d)" % texts.size())
	var notice: String = announcer._notice()
	test.check(not notice.contains("{kassa}") and not notice.contains("{gang}"), "mededeling ingevuld")
	announcer.start()
	test.check(announcer._inside and announcer._clock > 0.0, "binnen: de eerste even later")
	announcer.stop()
	test.check(not announcer._inside and not announcer.is_speaking(), "buiten: stil")
	market.free()
