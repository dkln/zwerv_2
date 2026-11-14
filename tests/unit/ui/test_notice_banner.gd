extends RefCounted
## Unit tests of the notice at the top of the HUD (scripts/ui/hud/notice_banner.gd): one
## notice at a time, the next waiting, the same name not twice, a jingle asked for.
##   tests/run_unit_tests.sh test_notice_banner.gd

const NoticeBanner = preload("res://scripts/ui/hud/notice_banner.gd")
const NoticeRules = preload("res://scripts/ui/hud/notice_rules.gd")

## The tree of the run (tests/run_unit_tests.gd sets it).
var tree: SceneTree


## Keeps the jingles the banner asks for.
class Listener:
	var jingles: Array = []

	func on_jingle(path: String) -> void:
		jingles.append(path)


func _banner(listener: Listener) -> NoticeBanner:
	var banner := NoticeBanner.new()
	banner.jingle_wanted.connect(listener.on_jingle)
	tree.root.add_child(banner)
	return banner


func test_a_notice_comes_up_at_once(test) -> void:
	var listener := Listener.new()
	var banner := _banner(listener)
	test.check(banner.name == "NieuwGebied" and not banner.is_showing() and banner.waiting() == 0, "eerst niets te zien")
	test.check(banner.queue(NoticeRules.notice(NoticeRules.AREA_HEADING, "Zeeheldenkwartier", 4.0)), "een melding wordt aangenomen")
	test.check(banner.is_showing() and banner.waiting() == 0, "en staat er meteen")
	test.check(banner.view.heading_text() == NoticeRules.AREA_HEADING and banner.view.name_text() == "Zeeheldenkwartier", "met kop en naam")
	test.check(listener.jingles.is_empty(), "een gebied heeft geen deuntje")
	banner.free()


func test_the_next_waits_and_the_same_name_is_dropped(test) -> void:
	var listener := Listener.new()
	var banner := _banner(listener)
	banner.queue(NoticeRules.notice(NoticeRules.AREA_HEADING, "Centrum", 4.0))
	test.check(not banner.queue(NoticeRules.notice(NoticeRules.AREA_HEADING, "Centrum", 4.0)), "hetzelfde gebied nog eens: één melding")
	test.check(banner.queue(NoticeRules.notice(NoticeRules.MISSION_HEADING, "Lege maag", 4.5, "res://deun.ogg")), "een andere wacht")
	test.check(banner.waiting() == 1 and banner.view.name_text() == "Centrum", "de eerste staat er nog")
	test.check(listener.jingles.is_empty(), "het deuntje pas als de missie in beeld komt")
	banner.show_next()
	test.check(banner.is_showing() and banner.view.name_text() == "Lege maag" and banner.view.heading_text() == NoticeRules.MISSION_HEADING, "dan de volgende")
	test.check(listener.jingles == ["res://deun.ogg"], "met zijn deuntje (%s)" % [listener.jingles])
	banner.show_next()
	test.check(not banner.is_showing() and banner.waiting() == 0, "niets meer: de melding weg")
	test.check(banner.queue(NoticeRules.notice(NoticeRules.AREA_HEADING, "Lege maag", 4.0)), "dezelfde naam mag weer als de melding weg is")
	banner.free()


func test_notices_keep_their_order(test) -> void:
	var listener := Listener.new()
	var banner := _banner(listener)
	for area_name: String in ["Een", "Twee", "Drie"]:
		banner.queue(NoticeRules.notice(NoticeRules.AREA_HEADING, area_name, 1.0))
	var shown: Array = [banner.view.name_text()]
	banner.show_next()
	shown.append(banner.view.name_text())
	banner.show_next()
	shown.append(banner.view.name_text())
	test.check(shown == ["Een", "Twee", "Drie"], "in de volgorde waarin ze kwamen (%s)" % [shown])
	banner.free()
